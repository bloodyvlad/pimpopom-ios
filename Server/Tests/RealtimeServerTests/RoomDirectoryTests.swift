import Foundation
import PimPoPomCore
import Testing

@testable import RealtimeServer

struct RoomDirectoryTests {
    func service() throws -> RoomService {
        var config = try ServerConfiguration(environment: ["MP2_DEV_AUTH": "1"])
        config.idleConnectionMs = 1_000_000
        let results = AsyncStream<CompletedMatch>.makeStream(bufferingPolicy: .bufferingOldest(128))
        return RoomService(configuration: config, resultOutput: results.continuation, randomSeed: { 42 })
    }

    func connect(
        _ service: RoomService, id: String, playerID: String? = nil,
        revision: Int = MP2Protocol.legacyGameplayRevision
    ) async throws -> OutboundMessages {
        let output = OutboundMessages(capacity: 1_000)
        #expect(await service.connect(id: id, output: output, now: 0))
        await service.authenticated(
            id: id,
            player: AuthenticatedPlayer(
                playerID: playerID ?? id, name: id, sessionBinding: "binding-" + id,
                expiresAt: Int(Date().timeIntervalSince1970) + 3_600),
            now: 0, gameplayRevision: revision)
        return output
    }

    func lists(_ output: OutboundMessages) async -> [[MP2RoomSummary]] {
        output.finish()
        var values: [[MP2RoomSummary]] = []
        for await message in output {
            if case .list(let directory) = message { values.append(directory) }
        }
        return values
    }

    @Test func createQuickLeaveAndCreatePushesLatestDirectoryWithoutPolling() async throws {
        let service = try service()
        let observer = try await connect(service, id: "observer")
        _ = try await connect(service, id: "host")
        await service.receive(.create(capacity: 2), from: "host", now: 1)
        let oldRoom = try #require(await service.connections["host"]?.roomID)
        #expect(await service.directory().map(\.id) == [oldRoom])
        await service.receive(.leave, from: "host", now: 2)
        #expect(await service.rooms[oldRoom] == nil)
        #expect(await service.directory().isEmpty == true)
        await service.receive(.create(capacity: 2), from: "host", now: 3)
        let newRoom = try #require(await service.connections["host"]?.roomID)
        #expect(newRoom != oldRoom)
        let observed = await lists(observer)
        #expect(observed.last?.map(\.id) == [newRoom])
        #expect(observed.last?.contains { $0.id == oldRoom } == false)
    }

    @Test func disconnectedCreatorIsHiddenAndMayCreateFreshLobbyWithoutWaitingForGrace() async throws {
        let service = try service()
        let observer = try await connect(service, id: "observer")
        _ = try await connect(service, id: "old", playerID: "host")
        await service.receive(.create(capacity: 2), from: "old", now: 1)
        let oldRoom = try #require(await service.connections["old"]?.roomID)
        await service.disconnect(id: "old", now: 2)
        #expect(await service.directory().isEmpty == true)
        #expect(await service.rooms[oldRoom] != nil)  // Reconnect still has its grace.
        _ = try await connect(service, id: "new", playerID: "host")
        await service.receive(.create(capacity: 2), from: "new", now: 3)
        let newRoom = try #require(await service.connections["new"]?.roomID)
        #expect(newRoom != oldRoom)
        #expect(await service.rooms[oldRoom] == nil)
        await service.disconnect(id: "old", now: 4)  // Late closure cannot detach the new room.
        #expect(await service.connections["new"]?.roomID == newRoom)
        #expect(await lists(observer).last?.map(\.id) == [newRoom])
    }

    @Test func freshCreateRecoversLostCreateReplyBeforeOldSocketClosure() async throws {
        let service = try service()
        let oldOutput = try await connect(service, id: "old", playerID: "host", revision: 2)
        _ = try await connect(service, id: "new", playerID: "host", revision: 2)
        await service.receive(.create(capacity: 2), from: "old", now: 1)
        let oldRoom = try #require(await service.connections["old"]?.roomID)
        let credential = try #require(await service.rooms[oldRoom]?.presence["host"]?.credential)
        // Do not consume the old socket's room/credential messages and do not
        // disconnect it: the network can delay both delivery and close detection.
        await service.receive(.create(capacity: 2), from: "new", now: 2)
        let newRoom = try #require(await service.connections["new"]?.roomID)
        #expect(newRoom != oldRoom)
        #expect(await service.rooms[oldRoom] == nil)
        #expect(await service.connections["old"] == nil)
        var errors: [String] = []
        for await message in oldOutput {
            if case .error(let code, _) = message { errors.append(code) }
        }
        #expect(errors == ["room_replaced"])
        _ = try await connect(service, id: "late", playerID: "host", revision: 2)
        await service.receive(.resume(roomID: oldRoom, credential: credential, generation: 1), from: "late", now: 3)
        #expect(await service.connections["late"]?.roomID == nil)
        await service.disconnect(id: "old", now: 4)
        #expect(await service.connections["new"]?.roomID == newRoom)
        await service.receive(.create(capacity: 2), from: "new", now: 5)
        #expect(await service.connections["new"]?.roomID == newRoom)  // Same-socket duplicate is not replacement.
    }

    @Test func freshCreateCannotReplaceAnAlreadyStartedMatch() async throws {
        let (service, ids, roomID) = try await RoomServiceTests().fixture()
        let revision = try #require(await service.rooms[roomID]?.value.rosterRevision)
        for id in ids {
            await service.receive(.ready(value: true, intentID: 1, rosterRevision: revision), from: id, now: 0)
        }
        await service.receive(.start, from: ids[0], now: 0)
        await service.tick(now: 1_000)
        let before = await service.rooms[roomID]?.engine?.snapshot
        _ = try await connect(service, id: "fresh", playerID: ids[0])
        await service.receive(.create(capacity: 2), from: "fresh", now: 1_001)
        #expect(await service.connections["fresh"]?.roomID == nil)
        #expect(await service.connections[ids[0]]?.roomID == roomID)
        #expect(await service.rooms[roomID]?.engine?.snapshot == before)
        #expect(await service.rooms[roomID]?.value.players.allSatisfy(\.connected) == true)
    }

    @Test func freshJoinTransfersOldLobbyHostWithoutDisconnectingOtherPlayers() async throws {
        let service = try service()
        for (id, player) in [("old", "host"), ("guest", "guest"), ("destination", "destination"), ("fresh", "host")] {
            _ = try await connect(service, id: id, playerID: player, revision: 2)
        }
        await service.receive(.create(capacity: 3), from: "old", now: 1)
        let oldRoom = try #require(await service.connections["old"]?.roomID)
        await service.receive(.join(roomID: oldRoom), from: "guest", now: 2)
        await service.receive(.join(roomID: "missing"), from: "fresh", now: 3)
        #expect(await service.connections["old"]?.roomID == oldRoom)  // Invalid target cannot evict a lobby.
        await service.receive(.create(capacity: 2), from: "destination", now: 4)
        let destination = try #require(await service.connections["destination"]?.roomID)
        await service.receive(.join(roomID: destination), from: "fresh", now: 5)
        #expect(await service.connections["fresh"]?.roomID == destination)
        #expect(await service.connections["old"] == nil)
        #expect(await service.connections["guest"]?.roomID == oldRoom)
        #expect(await service.rooms[oldRoom]?.value.hostPlayerID == "guest")
        #expect(await service.rooms[oldRoom]?.value.players.map(\.id) == ["guest"])
        #expect(await service.rooms[oldRoom]?.value.players[0].connected == true)
        #expect(await service.directory(gameplayRevision: 2).map(\.id) == [oldRoom])
    }

    @Test func fullRoomsDisappearAndASeatLeavingRestoresJoinabilityImmediately() async throws {
        let service = try service()
        let observer = try await connect(service, id: "observer")
        _ = try await connect(service, id: "host")
        _ = try await connect(service, id: "guest")
        await service.receive(.create(capacity: 2), from: "host", now: 1)
        let room = try #require(await service.connections["host"]?.roomID)
        await service.receive(.join(roomID: room), from: "guest", now: 2)
        #expect(await service.directory().isEmpty == true)
        await service.receive(.leave, from: "guest", now: 3)
        #expect(await service.directory().first?.playerCount == 1)
        #expect(await lists(observer).last?.map(\.id) == [room])
    }

    @Test func disconnectedGuestGraceExpiryPublishesOpenSeatAndTransfersMissingHost() async throws {
        let service = try service()
        let observer = try await connect(service, id: "observer")
        _ = try await connect(service, id: "host")
        _ = try await connect(service, id: "guest")
        await service.receive(.create(capacity: 3), from: "host", now: 1)
        let room = try #require(await service.connections["host"]?.roomID)
        await service.receive(.join(roomID: room), from: "guest", now: 2)
        await service.disconnect(id: "host", now: 3)
        #expect(await service.directory().isEmpty == true)
        await service.tick(now: 15_004)
        #expect(await service.rooms[room]?.value.hostPlayerID == "guest")
        #expect(await service.directory().first?.playerCount == 1)
        #expect(await lists(observer).last?.first?.hostName == "guest")
    }

    @Test func finishedRoomDoesNotBlockNewCreateAndEvidenceSurvivesUntilJournaled() async throws {
        let service = try service()
        _ = try await connect(service, id: "host")
        _ = try await connect(service, id: "guest")
        await service.receive(.create(capacity: 2), from: "host", now: 0)
        let roomID = try #require(await service.connections["host"]?.roomID)
        await service.receive(.join(roomID: roomID), from: "guest", now: 0)
        let revision = try #require(await service.rooms[roomID]?.value.rosterRevision)
        for id in ["host", "guest"] {
            await service.receive(.ready(value: true, intentID: 1, rosterRevision: revision), from: id, now: 0)
        }
        await service.receive(.start, from: "host", now: 0)
        #expect(await service.directory().isEmpty == true)
        for now in stride(from: 1_000, through: 60_000, by: 100) { await service.tick(now: now) }
        let terminal = try #require(await service.rooms[roomID]?.engine?.snapshot)
        #expect(terminal.phase == .finished)
        await service.receive(.create(capacity: 2), from: "host", now: 60_001)
        let newRoom = try #require(await service.connections["host"]?.roomID)
        #expect(newRoom != roomID)
        let retained = await service.rooms[roomID]?.engine?.snapshot
        #expect(retained == terminal)
        await service.tick(now: 100_000)
        #expect(await service.rooms[roomID] != nil)  // No outbox acknowledgment yet.
        #expect(await service.connections["host"]?.roomID == newRoom)
        await service.resultStored(matchID: terminal.matchID)
        await service.tick(now: 100_001)
        #expect(await service.rooms[roomID] == nil)
        #expect(await service.connections["host"]?.roomID == newRoom)
    }

    @Test func newGameplayNeverAppearsToLegacyClientOrAcceptsLegacyJoin() async throws {
        let service = try service()
        let oldObserver = try await connect(service, id: "old")
        let newObserver = try await connect(service, id: "new", revision: MP2Protocol.gameplayRevision)
        _ = try await connect(service, id: "host", revision: MP2Protocol.gameplayRevision)
        await service.receive(.create(capacity: 2), from: "host", now: 1)
        let roomID = try #require(await service.connections["host"]?.roomID)
        #expect(await service.directory().isEmpty == true)
        #expect(await service.directory(gameplayRevision: MP2Protocol.gameplayRevision).map(\.id) == [roomID])
        await service.receive(.join(roomID: roomID), from: "old", now: 2)
        #expect(await service.connections["old"]?.roomID == nil)
        #expect(await lists(oldObserver).last?.isEmpty == true)
        #expect(await lists(newObserver).last?.map(\.id) == [roomID])
    }

    @Test(arguments: [MP2Protocol.legacyGameplayRevision, MP2Protocol.gameplayRevision])
    func leaveAcknowledgementFencesPendingCreateOnlyForNewClients(_ revision: Int) async throws {
        let service = try service()
        let output = try await connect(service, id: "host", revision: revision)
        // Wire ordering makes this safe even if the client leaves before it has
        // received the room/resume messages from its Create request.
        await service.receive(.create(capacity: 2), from: "host", now: 1)
        let roomID = try #require(await service.connections["host"]?.roomID)
        await service.receive(.leave, from: "host", now: 2)
        #expect(await service.connections["host"]?.roomID == nil)
        #expect(await service.rooms[roomID] == nil)
        output.finish()
        var messages: [MP2ServerMessage] = []
        for await message in output { messages.append(message) }
        let leftIndex = messages.firstIndex(of: .left)
        if revision == MP2Protocol.gameplayRevision {
            let roomIndex = try #require(messages.firstIndex { if case .room = $0 { true } else { false } })
            #expect(try #require(leftIndex) > roomIndex)
        } else {
            #expect(leftIndex == nil)  // Build25 cannot decode an unknown case.
        }
    }

    @Test(arguments: [MP2Protocol.legacyGameplayRevision, MP2Protocol.gameplayRevision])
    func startInstallsNegotiatedGameplayEngine(_ gameplayRevision: Int) async throws {
        let service = try service()
        _ = try await connect(service, id: "host", revision: gameplayRevision)
        _ = try await connect(service, id: "guest", revision: gameplayRevision)
        await service.receive(.create(capacity: 2), from: "host", now: 0)
        let roomID = try #require(await service.connections["host"]?.roomID)
        await service.receive(.join(roomID: roomID), from: "guest", now: 0)
        let roster = try #require(await service.rooms[roomID]?.value.rosterRevision)
        for id in ["host", "guest"] {
            await service.receive(.ready(value: true, intentID: 1, rosterRevision: roster), from: id, now: 0)
        }
        await service.receive(.start, from: "host", now: 0)
        await service.tick(now: 1_000)
        #expect(await service.rooms[roomID]?.engine?.snapshot.gameplayRevision == gameplayRevision)
    }
}
