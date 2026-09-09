import Foundation
import PimPoPomCore

/// All room, membership and engine changes are synchronous actor operations.
/// Socket writers, ticket HTTP requests, and durable disk writes never execute here.
public actor RoomService {
    struct Connection {
        var player: AuthenticatedPlayer?
        let output: OutboundMessages
        let openedAt: Int
        var lastSeen: Int
        var lastValidated: Int
        var roomID: String?
        var rateWindow: Int
        var rateCount = 0
    }
    struct Presence {
        var connectionID: String?
        var generation: Int
        var credential: String
        var disconnectedAt: Int?
    }
    struct Room {
        var value: MP2Room
        var presence: [String: Presence]
        var engine: MP2Engine?
        var startedAt: Int?
        var lastSnapshotAt = 0
        var finishedAt: Int?
        var resultQueued = false
        var resultPersisted = false
    }

    public struct Validation: Sendable {
        public let connectionID: String
        public let player: AuthenticatedPlayer
    }
    let configuration: ServerConfiguration
    let resultOutput: AsyncStream<CompletedMatch>.Continuation
    var connections: [String: Connection] = [:]
    var rooms: [String: Room] = [:]

    public init(configuration: ServerConfiguration, resultOutput: AsyncStream<CompletedMatch>.Continuation) {
        self.configuration = configuration
        self.resultOutput = resultOutput
    }

    public func connect(id: String, output: OutboundMessages, now: Int) -> Bool {
        guard connections.count < configuration.maximumConnections else {
            output.yield(.error(code: "service_capacity", message: "The service is full. Try again shortly."))
            output.finish()
            return false
        }
        connections[id] = Connection(
            output: output, openedAt: now, lastSeen: now,
            lastValidated: now, rateWindow: now)
        return true
    }

    public func authenticated(id: String, player: AuthenticatedPlayer, now: Int) {
        guard var connection = connections[id], connection.player == nil else { return }
        connection.player = player
        connection.lastValidated = now
        connection.lastSeen = now
        connections[id] = connection
        send(.welcome(playerID: player.playerID, connectionID: id, serverTimeMs: now), to: id)
        sendDirectory(to: id)
    }

    public func authenticationFailed(id: String, now: Int) {
        sendError("authentication_failed", "Sign in again to connect.", to: id)
        disconnect(id: id, now: now)
    }

    public func touch(id: String, now: Int) { connections[id]?.lastSeen = now }

    public func receive(_ message: MP2ClientMessage, from id: String, now: Int) {
        guard var connection = connections[id], let player = connection.player else {
            sendError("authentication_required", "Authenticate before sending room actions.", to: id)
            return
        }
        if now - connection.rateWindow >= 1_000 {
            connection.rateWindow = now
            connection.rateCount = 0
        }
        connection.rateCount += 1
        connection.lastSeen = now
        connections[id] = connection
        guard connection.rateCount <= 120 else {
            sendError("rate_limited", "Too many messages. Reconnect shortly.", to: id)
            disconnect(id: id, now: now)
            return
        }
        switch message {
        case .hello:
            sendError("already_authenticated", "This connection is already authenticated.", to: id)
        case .ping(let pingID, let clientTime):
            send(.pong(id: pingID, clientTimeMs: clientTime, serverTimeMs: now), to: id)
        case .list:
            sendDirectory(to: id)
        case .create(let capacity):
            guard (2...4).contains(capacity), connection.roomID == nil,
                rooms.count < configuration.maximumRooms, !hasMembership(player.playerID)
            else {
                sendError("cannot_create", "Leave your current room, or try another capacity.", to: id)
                return
            }
            let roomID = UUID().uuidString.lowercased()
            let member = MP2Player(id: player.playerID, seat: 0, colorIndex: 0, name: player.name, petID: player.petID)
            let value = MP2Room(
                id: roomID, revision: 1, rosterRevision: 1, hostPlayerID: player.playerID,
                capacity: capacity, phase: .waiting, players: [member], epoch: UUID().uuidString)
            rooms[roomID] = Room(value: value, presence: [player.playerID: freshPresence(id: id)])
            connections[id]?.roomID = roomID
            sendCredential(roomID: roomID, playerID: player.playerID, to: id)
            broadcastRoom(roomID)
        case .join(let roomID):
            guard connection.roomID == nil, !hasMembership(player.playerID), var room = rooms[roomID],
                room.value.phase == .waiting, room.value.players.count < room.value.capacity,
                let seat = (0..<room.value.capacity).first(where: { seat in
                    !room.value.players.contains { $0.seat == seat }
                })
            else {
                sendError("cannot_join", "That room is unavailable. Refresh the list.", to: id)
                return
            }
            room.value.players.append(
                MP2Player(
                    id: player.playerID, seat: seat, colorIndex: seat,
                    name: player.name, petID: player.petID))
            room.value.players.sort { $0.seat < $1.seat }
            room.presence[player.playerID] = freshPresence(id: id)
            room.value.rosterRevision += 1
            room.value.revision += 1
            rooms[roomID] = room
            connections[id]?.roomID = roomID
            sendCredential(roomID: roomID, playerID: player.playerID, to: id)
            broadcastRoom(roomID)
        case .resume(let roomID, let credential, let generation):
            guard connection.roomID == nil, var room = rooms[roomID],
                !credential.isEmpty, var presence = room.presence[player.playerID], presence.credential == credential,
                presence.generation == generation, room.value.phase != .finished,
                presence.disconnectedAt == nil
                    || now - (presence.disconnectedAt ?? now) <= configuration.reconnectGraceMs
            else {
                sendError("resume_rejected", "This reconnect credential has expired. Return to the game list.", to: id)
                return
            }
            if let oldID = presence.connectionID, oldID != id {
                connections[oldID]?.roomID = nil
                connections[oldID]?.output.finish()
                connections.removeValue(forKey: oldID)
            }
            presence.connectionID = id
            presence.disconnectedAt = nil
            presence.generation += 1
            presence.credential = makeCredential()
            room.presence[player.playerID] = presence
            if let index = room.value.players.firstIndex(where: { $0.id == player.playerID }) {
                room.value.players[index].connected = true
                let time = elapsed(room, now)
                room.engine?.reconnect(seat: room.value.players[index].seat, at: time)
            }
            room.value.revision += 1
            room.value.rosterRevision += 1
            rooms[roomID] = room
            connections[id]?.roomID = roomID
            sendCredential(roomID: roomID, playerID: player.playerID, to: id)
            broadcastRoom(roomID)
            if let snapshot = room.engine?.snapshot { send(.snapshot(snapshot), to: id) }
        case .leave:
            leave(id: id, playerID: player.playerID, now: now)
            sendDirectory(to: id)
        case .ready(let ready, let intentID, let rosterRevision):
            guard let roomID = connection.roomID, var room = rooms[roomID], room.value.phase == .waiting,
                let index = room.value.players.firstIndex(where: { $0.id == player.playerID }),
                intentID > 0, intentID <= MP2Protocol.maximumInputID
            else {
                sendError("ready_unavailable", "Ready can be changed only in the waiting room.", to: id)
                return
            }
            if intentID <= room.value.players[index].readyIntentID {
                send(.room(room.value), to: id)
                return
            }
            guard rosterRevision == room.value.rosterRevision else {
                sendError("roster_changed", "The player list changed. Set Ready again.", to: id)
                send(.room(room.value), to: id)
                return
            }
            room.value.players[index].ready = ready
            room.value.players[index].readyIntentID = intentID
            room.value.revision += 1
            rooms[roomID] = room
            broadcastRoom(roomID)
        case .start:
            guard let roomID = connection.roomID, var room = rooms[roomID], room.value.hostPlayerID == player.playerID
            else {
                sendError("host_required", "Only the room creator can start.", to: id)
                return
            }
            if room.value.phase != .waiting {
                send(.room(room.value), to: id)
                return
            }
            guard room.value.players.count == room.value.capacity,
                room.value.players.allSatisfy({ $0.ready && $0.connected })
            else {
                sendError(
                    "players_not_ready", "Fill every seat and wait for all players to be connected and Ready.", to: id)
                return
            }
            room.value.phase = .countdown
            room.value.matchID = UUID().uuidString.lowercased()
            room.value.startsAtServerMs = now + 1_000
            room.value.revision += 1
            rooms[roomID] = room
            broadcastRoom(roomID)
        case .input(let input):
            guard let roomID = connection.roomID, var room = rooms[roomID], room.value.phase == .playing,
                let member = room.value.players.first(where: { $0.id == player.playerID }),
                input.seat == member.seat, input.roomEpoch == room.value.epoch,
                input.sessionGeneration == room.presence[player.playerID]?.generation,
                input.id > 0, input.id <= MP2Protocol.maximumInputID,
                input.presentedAtMs >= 0, input.presentedAtMs <= MP2Protocol.maximumDurationMs + 10_000,
                input.contactAtMs >= 0, input.contactAtMs <= MP2Protocol.maximumDurationMs + 10_000,
                input.lastServerRevision >= 0,
                var engine = room.engine
            else {
                sendError("invalid_input_context", "This input does not belong to the active seat and room.", to: id)
                return
            }
            let receipt = engine.submit(input, receivedAt: elapsed(room, now))
            room.engine = engine
            rooms[roomID] = room
            send(.receipt(receipt), to: id)
            if let latest = rooms[roomID]?.engine?.snapshot { broadcast(.snapshot(latest), roomID: roomID) }
        }
    }

    public func malformed(id: String, now: Int) {
        sendError("invalid_message", "The message format is not supported.", to: id)
        // Invalid wire data affects only this socket, never another participant.
        disconnect(id: id, now: now)
    }

    public func disconnect(id: String, now: Int) {
        guard let connection = connections.removeValue(forKey: id) else { return }
        connection.output.finish()
        guard let roomID = connection.roomID, let playerID = connection.player?.playerID,
            var room = rooms[roomID], room.presence[playerID]?.connectionID == id
        else { return }
        room.presence[playerID]?.connectionID = nil
        room.presence[playerID]?.disconnectedAt = now
        if let index = room.value.players.firstIndex(where: { $0.id == playerID }) {
            room.value.players[index].connected = false
            let time = elapsed(room, now)
            room.engine?.disconnect(seat: room.value.players[index].seat, at: time)
        }
        cancelCountdown(&room)
        room.value.rosterRevision += 1
        room.value.revision += 1
        rooms[roomID] = room
        broadcastRoom(roomID)
    }

    /// Caller schedules at 60 Hz. No socket/HTTP/disk await can stall this method.
    public func tick(now: Int) {
        for (id, connection) in connections {
            let timeout =
                connection.player == nil ? configuration.authenticationTimeoutMs : configuration.idleConnectionMs
            if now - connection.lastSeen > timeout { disconnect(id: id, now: now) }
        }
        for roomID in Array(rooms.keys) {
            guard var room = rooms[roomID] else { continue }
            for (playerID, presence) in room.presence {
                if let disconnectedAt = presence.disconnectedAt, now - disconnectedAt > configuration.reconnectGraceMs,
                    let member = room.value.players.first(where: { $0.id == playerID })
                {
                    if room.engine != nil {
                        let time = elapsed(room, now)
                        room.engine?.eliminateDisconnected(seat: member.seat, at: time)
                        room.presence[playerID]?.disconnectedAt = nil
                        room.presence[playerID]?.credential = ""
                    } else {
                        room.value.players.removeAll { $0.id == playerID }
                        room.presence.removeValue(forKey: playerID)
                        room.value.revision += 1
                        room.value.rosterRevision += 1
                    }
                }
            }
            if room.value.players.isEmpty {
                rooms.removeValue(forKey: roomID)
                continue
            }
            if !room.value.players.contains(where: { $0.id == room.value.hostPlayerID }) {
                room.value.hostPlayerID = room.value.players[0].id
            }
            if room.value.phase == .countdown, let start = room.value.startsAtServerMs, now >= start {
                if room.value.players.count == room.value.capacity,
                    room.value.players.allSatisfy({ $0.ready && $0.connected }),
                    let matchID = room.value.matchID,
                    let engine = try? MP2Engine(
                        matchID: matchID, players: room.value.players, seed: UInt64.random(in: 1...UInt64.max))
                {
                    room.engine = engine
                    room.startedAt = start
                    room.value.phase = .playing
                    room.value.revision += 1
                } else {
                    cancelCountdown(&room)
                }
            }
            let before = room.engine?.snapshot
            let time = elapsed(room, now)
            room.engine?.advance(to: time)
            let after = room.engine?.snapshot
            if let after, after.phase == .finished {
                if room.finishedAt == nil {
                    room.finishedAt = now
                    room.value.phase = .finished
                    room.value.revision += 1
                }
                if !room.resultQueued {
                    switch resultOutput.yield(CompletedMatch(snapshot: after)) {
                    case .enqueued: room.resultQueued = true
                    case .dropped, .terminated: break  // Retain and retry next tick; never restart a match.
                    @unknown default: break
                    }
                }
            }
            let critical =
                before?.targets != after?.targets || before?.decoys != after?.decoys || before?.phase != after?.phase
            let sendSnapshot = after != nil && (critical || now - room.lastSnapshotAt >= 100)
            if sendSnapshot { room.lastSnapshotAt = now }
            let oldRoom = rooms[roomID]?.value
            rooms[roomID] = room
            if oldRoom != room.value { broadcastRoom(roomID) }
            if sendSnapshot, let after { broadcast(.snapshot(after), roomID: roomID, coalescible: !critical) }
            if let finished = room.finishedAt, now - finished > 60_000, room.resultPersisted {
                for presence in room.presence.values {
                    if let id = presence.connectionID { connections[id]?.roomID = nil }
                }
                rooms.removeValue(forKey: roomID)
            }
        }
    }

    public func validationsDue(now: Int) -> [Validation] {
        var due: [Validation] = []
        for (id, var connection) in connections {
            guard let player = connection.player, now - connection.lastValidated >= configuration.validationIntervalMs
            else { continue }
            connection.lastValidated = now
            connections[id] = connection
            due.append(Validation(connectionID: id, player: player))
        }
        return due
    }

    public func validated(_ validation: Validation, refreshed: AuthenticatedPlayer?, now: Int) {
        guard connections[validation.connectionID]?.player == validation.player else { return }
        guard let refreshed else {
            sendError("session_revoked", "Your session ended. Sign in again.", to: validation.connectionID)
            disconnect(id: validation.connectionID, now: now)
            return
        }
        connections[validation.connectionID]?.player = refreshed
    }

    public func counts() -> (connections: Int, rooms: Int) { (connections.count, rooms.count) }

    public func resultStored(matchID: String) {
        if let roomID = rooms.first(where: { $0.value.value.matchID == matchID })?.key {
            rooms[roomID]?.resultPersisted = true
        }
    }

    func elapsed(_ room: Room, _ now: Int) -> Int { max(0, now - (room.startedAt ?? now)) }
    func hasMembership(_ playerID: String) -> Bool {
        rooms.values.contains { room in
            guard let presence = room.presence[playerID] else { return false }
            return presence.connectionID != nil || !presence.credential.isEmpty
        }
    }
    func makeCredential() -> String { UUID().uuidString + UUID().uuidString }
    func freshPresence(id: String) -> Presence {
        Presence(connectionID: id, generation: 1, credential: makeCredential())
    }
    func cancelCountdown(_ room: inout Room) {
        if room.value.phase == .countdown {
            room.value.phase = .waiting
            room.value.startsAtServerMs = nil
            room.value.matchID = nil
        }
    }
    func sendCredential(roomID: String, playerID: String, to id: String) {
        if let presence = rooms[roomID]?.presence[playerID] {
            send(
                .resumeCredential(roomID: roomID, credential: presence.credential, generation: presence.generation),
                to: id)
        }
    }
    func sendError(_ code: String, _ message: String, to id: String) {
        send(.error(code: code, message: message), to: id)
    }
    func send(_ message: MP2ServerMessage, to id: String, coalescible: Bool = false) {
        guard let connection = connections[id] else { return }
        if case .dropped = connection.output.yield(message, coalescible: coalescible), !coalescible {
            // A slow peer cannot hold a room hostage; bounded queue saturation closes only it.
            disconnect(id: id, now: ServerClock.milliseconds())
        }
    }
    func broadcast(_ message: MP2ServerMessage, roomID: String, coalescible: Bool = false) {
        let recipients = rooms[roomID]?.presence.values.compactMap(\.connectionID) ?? []
        for id in recipients { send(message, to: id, coalescible: coalescible) }
    }
    func broadcastRoom(_ roomID: String) {
        if let value = rooms[roomID]?.value { broadcast(.room(value), roomID: roomID) }
    }
    func sendDirectory(to id: String) {
        let directory = rooms.values.filter { $0.value.phase == .waiting }.map { room in
            MP2RoomSummary(
                id: room.value.id,
                hostName: room.value.players.first(where: { $0.id == room.value.hostPlayerID })?.name ?? "",
                capacity: room.value.capacity, playerCount: room.value.players.count, revision: room.value.revision,
                phase: room.value.phase)
        }.sorted { $0.id < $1.id }
        send(.list(directory), to: id)
    }
    func leave(id: String, playerID: String, now: Int) {
        guard let roomID = connections[id]?.roomID, var room = rooms[roomID] else { return }
        connections[id]?.roomID = nil
        if let member = room.value.players.first(where: { $0.id == playerID }), room.engine != nil {
            let time = elapsed(room, now)
            room.engine?.disconnect(seat: member.seat, at: time)
            room.engine?.eliminateDisconnected(seat: member.seat, at: time)
            room.presence[playerID]?.connectionID = nil
            room.presence[playerID]?.credential = ""
            room.presence[playerID]?.disconnectedAt = nil
            if let index = room.value.players.firstIndex(where: { $0.id == playerID }) {
                room.value.players[index].connected = false
            }
        } else {
            room.value.players.removeAll { $0.id == playerID }
            room.presence.removeValue(forKey: playerID)
        }
        cancelCountdown(&room)
        room.value.revision += 1
        room.value.rosterRevision += 1
        if room.value.players.isEmpty {
            rooms.removeValue(forKey: roomID)
        } else {
            if !room.value.players.contains(where: { $0.id == room.value.hostPlayerID }) {
                room.value.hostPlayerID = room.value.players[0].id
            }
            rooms[roomID] = room
            broadcastRoom(roomID)
        }
    }
}
