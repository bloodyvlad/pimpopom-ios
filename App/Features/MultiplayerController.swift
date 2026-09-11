import Combine
import Foundation
import PimPoPomCore

enum MultiplayerFlowPhase: Equatable { case hub, waiting, live, results }

/// UI projection only. Socket I/O and authority never block the UIKit touch path.
@MainActor
final class MultiplayerController: ObservableObject, GameSceneEventDelegate {
    @Published private(set) var phase: MultiplayerFlowPhase = .hub
    @Published private(set) var hubState = MultiplayerPresentation.HubState(availability: .signInRequired)
    @Published private(set) var waitingState: MultiplayerPresentation.WaitingRoomState?
    @Published private(set) var liveState: MultiplayerPresentation.LiveMatchState?
    @Published private(set) var resultsState = MultiplayerPresentation.ResultsState(
        settlement: .settled(leaderboardEligible: false), results: [], isRefreshing: false,
        localSubmissionAccepted: false, message: nil)
    let scene = GameScene()
    private let backend: BackendClient
    private let audio: AudioController
    private let socket = MultiplayerSocket()
    private var connectionTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var sendTask: Task<Void, Never>?
    private var sessionCheckTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var searchRequestID = 0
    private var sessionCheckGeneration = 0
    private var connectionEpoch = 0
    private var connected = false
    private var roomSynchronized = false
    private var needsInputReplay = false
    private var active = true
    private var opened = false
    private var identityID: String?
    private var room: MP2Room?
    private enum RoomAdmission {
        case create
        case join(String)
        case leaving
    }
    private var roomAdmission: RoomAdmission?
    private var lastLeftRoomID: String?
    private var snapshot: MP2Snapshot?
    private var resumeCredential: (roomID: String, credential: String, generation: Int)?
    private var readyIntentID = 0
    private var pendingReady: (value: Bool, id: Int)?
    private var inputID = 0
    private var serverOffsetMs = 0
    private var bestRTT = Int.max
    private var matchStartUptimeMs: Int?
    private var lastMessageUptimeMs = 0
    private var lastHUDUptimeMs = 0
    private var presentation = MP2PresentationLedger()
    private var pendingInputs: [Int: PendingInput] = [:]
    private var feedback: GameplayHitFeedbackEvent?
    private var feedbackUntilMs = 0
    private var localRecoveryUntilMs = 0
    private var maximumMultipliers: [String: Int] = [:]
    private var fixtureEnabled = false
    private struct PresentedHeart {
        let heart: MP2Heart
        let firstVisibleAtMs: Int
        var hiddenAtMs: Int?
    }
    private var presentedHearts: [Int: PresentedHeart] = [:]
    private var claimedHeartIDs: Set<Int> = []

    private struct PendingInput {
        var input: MP2Input
        var points: Int
        var receipt: MP2InputReceipt?
    }

    var availability: MultiplayerPresentation.Availability {
        if developmentIdentity != nil || fixtureEnabled { return .available }
        guard backend.sessionState != nil else { return .checkingSession }
        return .resolve(
            isSignedIn: backend.sessionState?.authenticated == true,
            nicknameConfirmed: backend.sessionState?.profile?.nicknameConfirmed == true)
    }

    // Existing app composition is retained; Game Center is not a live dependency.
    init(backend: BackendClient, gameCenter _: GameCenterService, audio: AudioController) {
        self.backend = backend
        self.audio = audio
        scene.eventDelegate = self
        installFixtureIfRequested()
    }

    func open() {
        guard !fixtureEnabled else { return }
        opened = true
        refreshAvailability()
        if backend.sessionState == nil, developmentIdentity == nil { checkSession() }
        if availability.isAvailable, connectionTask == nil { connect() }
        if connected { requestDirectory() }
    }

    func close() {
        guard !fixtureEnabled else { return }
        opened = false
        sessionCheckGeneration += 1
        sessionCheckTask?.cancel()
        sessionCheckTask = nil
        searchTask?.cancel()
        searchTask = nil
        searchRequestID += 1
        hubState.searchQuery = ""
        hubState.lobbies = []
        if room != nil || roomAdmission != nil { leaveMatch() }
        // Reuse the authenticated socket on a quick return to the hub. Backgrounding
        // closes it; reopening the screen alone must not consume another PHP ticket.
    }

    private func checkSession() {
        guard sessionCheckTask == nil else { return }
        sessionCheckGeneration += 1
        let generation = sessionCheckGeneration
        hubState.isRefreshing = true
        sessionCheckTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if generation == self.sessionCheckGeneration { self.sessionCheckTask = nil }
            }
            do {
                _ = try await self.backend.loadSession()
                guard !Task.isCancelled else { return }
                self.hubState.message = nil
                self.refreshAvailability()
            } catch {
                guard !Task.isCancelled else { return }
                self.showConnectionMessage("Could not check your sign-in. Please refresh to try again.")
            }
            self.hubState.isRefreshing = false
        }
    }

    func refreshAvailability() {
        guard !fixtureEnabled else { return }
        hubState.availability = availability
        let currentIdentity = developmentIdentity ?? backend.sessionState?.profile?.id
        if let identityID, identityID != currentIdentity || !availability.isAvailable {
            closeConnection()
            clearMatch()
            self.identityID = nil
            phase = .hub
        }
        if opened, active, availability.isAvailable, connectionTask == nil { connect() }
    }

    func setApplicationActive(_ value: Bool) {
        guard active != value else { return }
        active = value
        guard !fixtureEnabled else { return }
        if value {
            guard opened else { return }
            refreshAvailability()
            if availability.isAvailable, connectionTask == nil { connect() }
        } else {
            closeConnection()
            showConnectionMessage("Reconnecting when you return…")
        }
    }

    func refreshLobbies() {
        guard !fixtureEnabled else { return }
        hubState.isRefreshing = true
        if connected { requestDirectory() } else if backend.sessionState == nil { checkSession() } else { open() }
    }
    func searchLobbies(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != hubState.searchQuery else { return }
        searchTask?.cancel()
        searchRequestID += 1
        hubState.searchQuery = trimmed
        hubState.lobbies = []
        hubState.message = nil
        hubState.isRefreshing = true
        guard hubState.supportsRoomCodes else {
            hubState.isRefreshing = false
            hubState.message = "Room search is unavailable while the multiplayer service updates."
            return
        }
        guard trimmed.utf8.count <= 128 else {
            hubState.isRefreshing = false
            hubState.message = "Enter a game code or a shorter creator nickname."
            return
        }
        let requestID = searchRequestID
        searchTask = Task { [weak self] in
            guard let self, self.searchRequestID == requestID else { return }
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            guard !Task.isCancelled, self.searchRequestID == requestID else { return }
            self.refreshLobbies()
        }
    }
    private func requestDirectory() {
        if hubState.searchQuery.isEmpty {
            send(.list)
        } else {
            guard hubState.supportsRoomCodes, hubState.searchQuery.utf8.count <= 128 else {
                hubState.isRefreshing = false
                return
            }
            searchRequestID += 1
            send(.search(query: hubState.searchQuery, requestID: searchRequestID))
        }
    }
    func createMatch(capacity: Int, isPrivate: Bool = false) {
        guard connected, room == nil, roomAdmission == nil, (2...4).contains(capacity) else { return }
        guard !isPrivate || hubState.supportsRoomCodes else {
            hubState.message = "Private games are unavailable while the multiplayer service updates."
            return
        }
        searchTask?.cancel()
        roomAdmission = .create
        hubState.isCreating = true
        hubState.message = nil
        send(.create(capacity: capacity, isPrivate: isPrivate))
    }
    func joinMatch(_ matchID: String) {
        guard connected, room == nil, roomAdmission == nil else { return }
        searchTask?.cancel()
        roomAdmission = .join(matchID)
        hubState.joiningLobbyID = matchID
        hubState.message = nil
        send(.join(roomID: matchID))
    }
    func toggleReady(_ value: Bool) {
        guard let room, room.phase == .waiting, connected else { return }
        readyIntentID += 1
        pendingReady = (value, readyIntentID)
        projectWaitingRoom()  // Same synchronous turn as the press.
        send(.ready(value: value, intentID: readyIntentID, rosterRevision: room.rosterRevision))
    }
    func startMatch() {
        guard waitingState?.canStart == true else { return }
        send(.start)
    }
    func leaveMatch() {
        lastLeftRoomID = room?.id ?? resumeCredential?.roomID
        if connected { send(.leave) }
        clearMatch()
        phase = .hub
        // Wait for the ordered Leave acknowledgement before allowing another create.
        // This also fences a create response whose room ID wasn't known when leaving.
        if connected { roomAdmission = .leaving }
        if connected { requestDirectory() }
    }
    func retryConnection() { connect() }
    func refreshSettlement() { if connected { send(.list) } }
    func returnToMenuFromResults() { leaveMatch() }

    private func connect() {
        guard active, availability.isAvailable, !fixtureEnabled else { return }
        closeConnection()
        let epoch = connectionEpoch
        let closed = sendTask
        showConnectionMessage("Connecting to multiplayer…")
        connectionTask = Task { [weak self] in
            guard let self else { return }
            await closed?.value
            var retry = 0
            while !Task.isCancelled, self.active, epoch == self.connectionEpoch {
                do {
                    let ticket: String
                    let url: URL
                    if let identity = self.developmentIdentity {
                        ticket = "dev:\(identity)"
                        url = self.developmentURL
                    } else {
                        let credential = try await self.backend.createMultiplayerV2Ticket()
                        ticket = credential.ticket
                        url = credential.realtimeURL
                    }
                    guard !Task.isCancelled, epoch == self.connectionEpoch else { return }
                    let events = await self.socket.connect(url: url, ticket: ticket)
                    guard !Task.isCancelled, epoch == self.connectionEpoch else { return }
                    self.lastMessageUptimeMs = Self.now
                    self.startHeartbeat(epoch: epoch)
                    for await event in events {
                        guard !Task.isCancelled, epoch == self.connectionEpoch else { return }
                        switch event {
                        case .message(let message): self.receive(message)
                        case .disconnected(let message): self.showConnectionMessage(message)
                        }
                    }
                } catch {
                    guard !Task.isCancelled, epoch == self.connectionEpoch else { return }
                    self.showConnectionMessage(error.localizedDescription)
                }
                guard !Task.isCancelled, epoch == self.connectionEpoch else { return }
                self.connected = false
                self.heartbeatTask?.cancel()
                self.pendingReady = nil
                self.projectWaitingRoom()
                retry += 1
                do { try await Task.sleep(for: .seconds(min(5, retry))) } catch { return }
            }
        }
    }

    private func closeConnection() {
        connectionEpoch += 1
        connectionTask?.cancel()
        connectionTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        connected = false
        roomSynchronized = false
        let previous = sendTask
        sendTask = Task {
            await previous?.value
            await socket.disconnect()
        }
    }
    private func send(_ message: MP2ClientMessage) {
        let previous = sendTask
        sendTask = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            await socket.send(message)
        }
    }
    private func startHeartbeat(epoch: Int) {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            var sequence = 0
            while !Task.isCancelled {
                guard let self, epoch == self.connectionEpoch else { return }
                if Self.now - self.lastMessageUptimeMs > 8_000 {
                    await self.socket.disconnect()
                    self.showConnectionMessage("Reconnecting…")
                    return
                }
                sequence += 1
                self.send(.ping(id: sequence, clientTimeMs: Self.now))
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }

    func receive(_ message: MP2ServerMessage) {
        lastMessageUptimeMs = Self.now
        switch message {
        case .welcome(let playerID, _, let serverTimeMs, let gameplayRevision, let roomDiscoveryRevision):
            guard gameplayRevision == MP2Protocol.gameplayRevision else {
                closeConnection()
                showConnectionMessage("The multiplayer service is updating. Please try again shortly.")
                return
            }
            connected = true
            hubState.supportsRoomCodes = roomDiscoveryRevision == MP2Protocol.roomDiscoveryRevision
            if !hubState.supportsRoomCodes {
                searchTask?.cancel()
                searchRequestID += 1
                hubState.searchQuery = ""
            }
            identityID = playerID
            serverOffsetMs = serverTimeMs - Self.now
            bestRTT = Int.max
            hubState.message = nil
            if !hubState.supportsRoomCodes {
                hubState.message = "Room codes and private games will be available when the service update finishes."
            }
            if let resumeCredential {
                needsInputReplay = true
                send(
                    .resume(
                        roomID: resumeCredential.roomID, credential: resumeCredential.credential,
                        generation: resumeCredential.generation))
            } else {
                // A fresh socket cannot acknowledge the old socket's pending action.
                // Its generation already fences those responses; release the UI intent.
                roomAdmission = nil
                hubState.isCreating = false
                hubState.joiningLobbyID = nil
                requestDirectory()
            }
        case .resumeCredential(let roomID, let credential, let generation):
            guard acceptsRoom(roomID) else { return }
            resumeCredential = (roomID, credential, generation)
        case .left:
            if case .leaving = roomAdmission { roomAdmission = nil }
        case .list(let rooms):
            guard hubState.searchQuery.isEmpty else { return }
            hubState.isRefreshing = false
            hubState.lobbies = projectLobbies(rooms.filter { $0.isPrivate != true })
        case .searchResults(let query, let requestID, let rooms):
            guard requestID == searchRequestID, query == hubState.searchQuery, !query.isEmpty else { return }
            hubState.isRefreshing = false
            hubState.message = nil
            hubState.lobbies = projectLobbies(rooms)
        case .room(let updated):
            guard acceptsRoom(updated.id), updated.players.contains(where: { $0.id == identityID }) else { return }
            guard room?.id != updated.id || updated.revision >= (room?.revision ?? -1) else { return }
            if let oldRoom = room, oldRoom.id != updated.id { clearMatch() }
            if room?.matchID != updated.matchID || updated.phase == .waiting {
                snapshot = nil
                matchStartUptimeMs = nil
                presentation.reset()
                pendingInputs.removeAll()
                inputID = 0
                localRecoveryUntilMs = 0
            }
            room = updated
            roomAdmission = nil
            roomSynchronized = true
            hubState.isCreating = false
            hubState.joiningLobbyID = nil
            if let local = updated.players.first(where: { $0.id == identityID }) {
                readyIntentID = max(readyIntentID, local.readyIntentID)
                if let pendingReady, local.readyIntentID >= pendingReady.id { self.pendingReady = nil }
            }
            if let start = updated.startsAtServerMs, matchStartUptimeMs == nil {
                matchStartUptimeMs = start - serverOffsetMs
                audio.setMusicContext(.gameplay)
            }
            if updated.phase == .waiting || updated.phase == .countdown {
                phase = .waiting
                projectWaitingRoom()
            }
            if needsInputReplay, updated.phase == .playing {
                needsInputReplay = false
                replayPendingInputs()
            }
        case .snapshot(let updated):
            guard room?.matchID == updated.matchID,
                snapshot == nil || updated.revision >= snapshot!.revision
            else { return }
            snapshot = updated
            reconcileInputs()
            for player in updated.players {
                maximumMultipliers[player.id] = max(maximumMultipliers[player.id] ?? 1, player.multiplier)
            }
            if updated.phase == .finished {
                showResults(updated)
            } else {
                phase = .live
                projectLive(at: Self.now, force: true)
            }
        case .receipt(let receipt):
            pendingInputs[receipt.id]?.receipt = receipt
            reconcileInputs()
            projectLive(at: Self.now, force: true)
        case .error(let code, let message):
            roomAdmission = nil
            pendingReady = nil
            hubState.isCreating = false
            hubState.joiningLobbyID = nil
            hubState.isRefreshing = false
            showConnectionMessage(message)
            if code == "room_replaced" {
                clearMatch()
                phase = .hub
                closeConnection()
                return
            }
            if code == "session_revoked" || code == "authentication_failed" {
                closeConnection()
                // Socket credentials can expire independently of the primary login.
                // Revalidate that login before asking the player to authenticate again.
                checkSession()
                return
            }
            if code.contains("resume") || code == "room-not-found" {
                clearMatch()
                phase = .hub
                requestDirectory()
            }
        case .pong(_, let sentAt, let serverTimeMs):
            let rtt = max(0, Self.now - sentAt)
            if rtt < bestRTT {
                bestRTT = rtt
                serverOffsetMs = serverTimeMs - sentAt - rtt / 2
                if phase != .live, let start = room?.startsAtServerMs {
                    matchStartUptimeMs = start - serverOffsetMs
                }
            }
        }
    }

    private func acceptsRoom(_ id: String) -> Bool {
        if let room { return room.id == id }
        switch roomAdmission {
        case .create: return id != lastLeftRoomID
        case .join(let requested): return id == requested
        case .leaving: return false
        case nil: return false
        }
    }

    private func projectLobbies(_ rooms: [MP2RoomSummary]) -> [MultiplayerPresentation.Lobby] {
        rooms.filter {
            $0.phase == .waiting && $0.playerCount < $0.capacity
                && $0.gameplayRevision == MP2Protocol.gameplayRevision
        }.map {
            .init(
                id: $0.id, capacity: $0.capacity, playerCount: $0.playerCount, hostName: $0.hostName,
                hostPetID: nil, roomCode: $0.roomCode, isPrivate: $0.isPrivate == true)
        }
    }

    private func reconcileInputs() {
        guard let snapshot else { return }
        pendingInputs = pendingInputs.filter { _, pending in
            if let receipt = pending.receipt { return snapshot.revision < receipt.revision }
            return elapsed(at: Self.now) - pending.input.contactAtMs <= MP2Protocol.lateInputGraceMs + 1_000
        }
    }
    private func replayPendingInputs() {
        guard let room, let resumeCredential, roomSynchronized else { return }
        let replay = pendingInputs.values.filter {
            $0.receipt == nil && elapsed(at: Self.now) - $0.input.contactAtMs <= MP2Protocol.lateInputGraceMs
        }.sorted { $0.input.id < $1.input.id }
        for pending in replay {
            pendingInputs[pending.input.id] = nil
            inputID += 1
            let original = pending.input
            let input = MP2Input(
                id: inputID, seat: original.seat, targetID: original.targetID,
                cell: original.cell, presentedAtMs: original.presentedAtMs, contactAtMs: original.contactAtMs,
                lastServerRevision: snapshot?.revision ?? original.lastServerRevision,
                roomEpoch: room.epoch, sessionGeneration: resumeCredential.generation, heartID: original.heartID)
            pendingInputs[inputID] = .init(input: input, points: pending.points)
            send(.input(input))
        }
    }
    private func projectWaitingRoom() {
        guard let room else { return }
        waitingState = .init(
            matchID: room.id, capacity: room.capacity, isCreator: room.hostPlayerID == identityID,
            participants: room.players.sorted { $0.seat < $1.seat }.map {
                .init(
                    id: $0.id, seat: $0.seat, colorIndex: $0.colorIndex, name: $0.name, petID: $0.petID,
                    ready: $0.ready, isCurrentPlayer: $0.id == identityID,
                    isCreator: $0.id == room.hostPlayerID, isConnected: $0.connected)
            }, connection: connected ? .ready : .connectionFailed("Reconnecting…"),
            isMutationPending: room.phase != .waiting,
            message: room.phase == .countdown ? "Get ready…" : nil, pendingReadyIntent: pendingReady?.value,
            roomCode: room.roomCode, isPrivate: room.isPrivate == true)
    }

    private func projectLive(at now: Int, force: Bool = false, renderFrame: Bool = false) {
        guard let snapshot, let local = snapshot.players.first(where: { $0.id == identityID }) else { return }
        let elapsed = elapsed(at: now)
        if renderFrame {
            presentation.presented(
                targets: snapshot.targets, at: elapsed, localSeat: local.seat,
                predictedRecoveryUntil: localRecoveryUntilMs)
            let visibleHearts = snapshot.hearts.filter {
                $0.activateAtMs <= elapsed && elapsed < $0.expiresAtMs
                    && presentation.currentCells[$0.cell] == nil
            }
            let visibleIDs = Set(visibleHearts.map(\.id))
            for heart in visibleHearts where presentedHearts[heart.id] == nil {
                presentedHearts[heart.id] = .init(heart: heart, firstVisibleAtMs: elapsed)
            }
            for id in presentedHearts.keys where !visibleIDs.contains(id) && presentedHearts[id]?.hiddenAtMs == nil {
                presentedHearts[id]?.hiddenAtMs = elapsed
            }
            presentedHearts = presentedHearts.filter {
                $0.value.heart.expiresAtMs + MP2Protocol.lateInputGraceMs >= elapsed
            }
            claimedHeartIDs.formIntersection(presentedHearts.keys)
        }
        var cells = Array(repeating: Cell(), count: snapshot.gridDimension * snapshot.gridDimension)
        for target in presentation.currentTargets {
            guard cells.indices.contains(target.cell) else { continue }
            cells[target.cell] = Cell(kind: .target, colorIndex: target.colorIndex)
        }
        for decoy in snapshot.decoys where decoy.activateAtMs <= elapsed && elapsed < decoy.expiresAtMs {
            if cells.indices.contains(decoy.cell), cells[decoy.cell].kind == .idle {
                cells[decoy.cell] = Cell(kind: .decoy, colorIndex: decoy.colorIndex)
            }
        }
        let heartCells = Set(
            presentedHearts.values.filter {
                $0.hiddenAtMs == nil && elapsed < $0.heart.expiresAtMs
                    && !claimedHeartIDs.contains($0.heart.id) && cells.indices.contains($0.heart.cell)
                    && cells[$0.heart.cell].kind == .idle
            }.map { $0.heart.cell })
        scene.applySharedBoard(dimension: snapshot.gridDimension, cells: cells, hearts: heartCells)
        guard force || now - lastHUDUptimeMs >= 100 else { return }
        lastHUDUptimeMs = now
        let points = pendingInputs.values.reduce(0) { $0 + $1.points }
        let leadingScore = snapshot.players.map(\.score).max() ?? 0
        let players = snapshot.players.sorted { $0.seat < $1.seat }.map { player in
            MultiplayerPresentation.LivePlayer(
                id: player.id, seat: player.seat, colorIndex: player.colorIndex,
                name: player.name, petID: player.petID, points: player.score + (player.id == identityID ? points : 0),
                multiplier: player.multiplier, lives: player.lives, isLeader: player.score == leadingScore,
                isCurrentPlayer: player.id == identityID, isConnected: player.connected)
        }
        liveState = .init(
            matchID: snapshot.matchID, elapsedMilliseconds: elapsed,
            cells: cells.enumerated().map { index, cell in
                .init(
                    id: index, colorIndex: cell.colorIndex,
                    ownerSeat: presentation.currentCells[index]?.ownerSeat,
                    glyph: cell.colorIndex.map { gameColors[$0].glyph } ?? "●",
                    isTarget: cell.kind == .target, isDecoy: cell.kind == .decoy, isHeart: heartCells.contains(index))
            }, players: players, localSeat: local.seat, streakSteps: local.streakProgress,
            isRecovering: elapsed < max(local.recoveryUntilMs, localRecoveryUntilMs),
            networkStatus: connected ? (snapshot.phase == .finishing ? .finalizing : nil) : .reconnecting,
            announcement: nil, hitFeedbackEvent: now < feedbackUntilMs ? feedback : nil,
            inputMode: local.isOut ? .spectating : .interactive, gridDimension: snapshot.gridDimension,
            roomCode: room?.roomCode)
    }

    func handleTap(cell: Int, localMonotonicMilliseconds: Int, normalizedLocation: CGPoint) {
        guard phase == .live, let snapshot, let room,
            let local = snapshot.players.first(where: { $0.id == identityID })
        else { return }
        let contact = elapsed(at: localMonotonicMilliseconds)
        guard contact >= localRecoveryUntilMs else { return }
        let visible = presentation.lookup(cell: cell, contactAt: contact)
        let target = visible?.target
        // A still-visible own target may correct even a provisional third expiry.
        let ownTarget = target?.ownerSeat == local.seat ? target : nil
        let heart = presentedHearts.values.first {
            $0.heart.cell == cell && $0.firstVisibleAtMs <= contact
                && contact < min($0.heart.expiresAtMs, $0.hiddenAtMs ?? Int.max)
        }
        if let heart, claimedHeartIDs.contains(heart.heart.id) { return }
        guard ownTarget != nil || (!local.isOut && contact >= max(local.recoveryUntilMs, localRecoveryUntilMs)) else {
            return
        }
        inputID += 1
        let presented = visible?.firstVisibleAtMs ?? heart?.firstVisibleAtMs ?? contact
        var points = 0
        if let ownTarget {
            presentation.consumeOwn(targetID: ownTarget.id, at: contact)
            let reaction = contact - presented
            points =
                ReactionScoring.points(
                    reactionMilliseconds: Double(reaction),
                    responseWindowMilliseconds: Double(ownTarget.responseWindowMs)) * local.multiplier
            feedback = .init(
                id: inputID, rating: SpeedRating.classify(reactionMilliseconds: Double(reaction)).rating,
                milliseconds: reaction, pointsAwarded: points, normalizedLocation: normalizedLocation)
            feedbackUntilMs = Self.now + 700
            audio.playTap(hitNumber: local.hits + 1)
        } else if let heart {
            // Immediate local collection feedback; only the server awards the life.
            // A competing claim is harmless and never becomes an empty-cell mistake.
            claimedHeartIDs.insert(heart.heart.id)
            audio.playTap(hitNumber: local.hits + 1)
        } else {
            localRecoveryUntilMs = contact + 1_500
            audio.playLifeLoss()
        }
        let input = MP2Input(
            id: inputID, seat: local.seat, targetID: target?.id, cell: cell,
            presentedAtMs: presented, contactAtMs: contact, lastServerRevision: snapshot.revision,
            roomEpoch: room.epoch, sessionGeneration: resumeCredential?.generation ?? 0,
            heartID: ownTarget == nil ? heart?.heart.id : nil)
        pendingInputs[inputID] = .init(input: input, points: points)
        projectLive(at: Self.now, force: true)
        if connected && roomSynchronized {
            send(.input(input))  // Feedback and score are already visible.
        }
    }

    private func showResults(_ snapshot: MP2Snapshot) {
        let ordered = snapshot.players.sorted { $0.score == $1.score ? $0.seat < $1.seat : $0.score > $1.score }
        resultsState = .init(
            settlement: .settled(leaderboardEligible: false),
            results: ordered.enumerated().map { offset, player in
                .init(
                    id: player.id, place: offset + 1, playerCount: ordered.count, name: player.name,
                    petID: player.petID,
                    score: player.score, survivalMilliseconds: player.outAtMs ?? snapshot.elapsedMs, hits: player.hits,
                    misses: player.misses, dodges: player.dodges, fastestReactionMilliseconds: player.fastestReactionMs,
                    averageReactionMilliseconds: player.averageReactionMs,
                    maxMultiplier: maximumMultipliers[player.id] ?? player.multiplier,
                    isCurrentPlayer: player.id == identityID)
            }, isRefreshing: false, localSubmissionAccepted: true,
            message: "Multiplayer v2 playtest · unranked · no coins or achievements.", roomCode: room?.roomCode)
        phase = .results
        audio.setMusicContext(.silent)
    }
    private func showConnectionMessage(_ message: String) {
        hubState.message = message
        hubState.isRefreshing = false
        hubState.isCreating = false
        hubState.joiningLobbyID = nil
        projectWaitingRoom()
        waitingState?.message = message
        projectLive(at: Self.now, force: true)
    }
    private func clearMatch() {
        roomAdmission = nil
        roomSynchronized = false
        needsInputReplay = false
        room = nil
        snapshot = nil
        resumeCredential = nil
        pendingReady = nil
        pendingInputs.removeAll()
        presentedHearts.removeAll()
        claimedHeartIDs.removeAll()
        presentation.reset()
        maximumMultipliers.removeAll()
        inputID = 0
        readyIntentID = 0
        localRecoveryUntilMs = 0
        matchStartUptimeMs = nil
        waitingState = nil
        liveState = nil
        audio.setMusicContext(.silent)
    }
    private static var now: Int { Int(ProcessInfo.processInfo.systemUptime * 1_000) }
    private func elapsed(at uptime: Int) -> Int { max(0, uptime - (matchStartUptimeMs ?? uptime)) }
    private var developmentIdentity: String? {
        #if DEBUG
            let prefix = "--mp2-local-player="
            guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }),
                let id = UUID(uuidString: String(argument.dropFirst(prefix.count)))
            else { return nil }
            return id.uuidString.lowercased()
        #else
            return nil
        #endif
    }
    private var developmentURL: URL {
        var port = 8080
        #if DEBUG
            let prefix = "--mp2-local-port="
            if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }),
                let value = Int(argument.dropFirst(prefix.count)), (1024...65535).contains(value)
            {
                port = value
            }
        #endif
        return URL(string: "ws://127.0.0.1:\(port)/multiplayer/v2")!
    }
    func gameScene(_ scene: GameScene, requestsRoundActivationAt milliseconds: Double) {}
    func gameScene(_ scene: GameScene, requestsDecoyActivationAt milliseconds: Double) {}
    func gameScene(_ scene: GameScene, didPointAt normalizedLocation: CGPoint) {}
    func gameScene(_ scene: GameScene, didAdvanceTo milliseconds: Double) {
        guard !fixtureEnabled else { return }
        projectLive(at: Int(milliseconds), renderFrame: true)
    }
    func gameScene(
        _ scene: GameScene, didTapCell index: Int, normalizedLocation: CGPoint,
        inputAt milliseconds: Double, handledAt: Double
    ) {
        handleTap(cell: index, localMonotonicMilliseconds: Int(milliseconds), normalizedLocation: normalizedLocation)
    }
    private func installFixtureIfRequested() {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            guard arguments.contains("--uitesting"),
                arguments.contains(where: { $0.hasPrefix("--ui-test-multiplayer-") })
            else { return }
            fixtureEnabled = true
            connected = true
            hubState.supportsRoomCodes = true
            identityID = "fixture-player-0"
            let names = ["pimpovlad", "alenka", "PixelPilot", "TapMaster"]
            let pets = ["foka", "kesha", "misha", "pancake"]
            var players = (0..<4).map {
                MP2Player(
                    id: "fixture-player-\($0)", seat: $0,
                    colorIndex: $0, name: names[$0], petID: pets[$0], ready: true)
            }
            room = .init(
                id: "fixture-match", revision: 1, rosterRevision: 1, hostPlayerID: identityID!, capacity: 4,
                phase: .waiting, players: players, matchID: "fixture-match",
                roomCode: "BCDF2345", isPrivate: true)
            if arguments.contains("--ui-test-multiplayer-hub-fixture") {
                hubState = .init(
                    availability: .available,
                    lobbies: [
                        .init(
                            id: "fixture-lobby", capacity: 4,
                            playerCount: 2, hostName: "PixelPilot", hostPetID: "foka", roomCode: "GHJK6789")
                    ])
                hubState.supportsRoomCodes = true
            } else if arguments.contains("--ui-test-multiplayer-waiting-fixture") {
                phase = .waiting
                projectWaitingRoom()
            } else {
                phase = .live
                if arguments.contains("--ui-test-multiplayer-spectating-fixture") {
                    players[0].lives = 0
                    players[0].outAtMs = 45_000
                }
                matchStartUptimeMs = Self.now - 46_000
                snapshot = .init(
                    matchID: "fixture-match", revision: 1, elapsedMs: 46_000, phase: .playing,
                    gridDimension: 4, players: players,
                    targets: [
                        .init(
                            id: 1, cell: 6, ownerSeat: 0, colorIndex: 0, activateAtMs: 46_000, responseWindowMs: 10_000)
                    ],
                    decoys: [
                        .init(
                            id: 1, cell: 12, colorIndex: 5, beneficiarySeat: 0, activateAtMs: 45_000,
                            expiresAtMs: 55_000)
                    ],
                    hearts: [.init(id: 1, cell: 9, activateAtMs: 45_000, expiresAtMs: 60_000)],
                    gameplayRevision: MP2Protocol.gameplayRevision)
                feedback = .init(
                    id: 9, rating: .godlike, milliseconds: 200, pointsAwarded: 541,
                    normalizedLocation: CGPoint(x: 0.625, y: 0.375))
                feedbackUntilMs = Self.now + 60_000
                if arguments.contains("--ui-test-multiplayer-catch-up-fixture") { connected = false }
                projectLive(at: Self.now, force: true, renderFrame: true)
            }
        #endif
    }
}
