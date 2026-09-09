import Foundation
import PimPoPomCore
import Testing

@testable import RealtimeServer

struct RoomServiceTests {
    func fixture(_ count: Int = 2) async throws -> (RoomService, [String], String) {
        let config = try ServerConfiguration(environment: ["MP2_DEV_AUTH": "1"])
        let results = AsyncStream<CompletedMatch>.makeStream(bufferingPolicy: .bufferingOldest(128))
        let service = RoomService(configuration: config, resultOutput: results.continuation)
        var ids: [String] = []
        for _ in 0..<count {
            let id = UUID().uuidString
            let output = OutboundMessages(capacity: 1_000)
            #expect(await service.connect(id: id, output: output, now: 0))
            await service.authenticated(
                id: id,
                player: AuthenticatedPlayer(
                    playerID: id, name: "Local",
                    sessionBinding: UUID().uuidString, expiresAt: Int(Date().timeIntervalSince1970) + 3_600), now: 0)
            ids.append(id)
        }
        await service.receive(.create(capacity: count), from: ids[0], now: 0)
        let roomID = try #require(await service.connections[ids[0]]?.roomID)
        for id in ids.dropFirst() { await service.receive(.join(roomID: roomID), from: id, now: 0) }
        return (service, ids, roomID)
    }

    @Test(arguments: [2, 3, 4]) func zeroInputStartAndExpiryAreIndependent(_ count: Int) async throws {
        let (service, ids, roomID) = try await fixture(count)
        let revision = try #require(await service.rooms[roomID]?.value.rosterRevision)
        for id in ids {
            await service.receive(.ready(value: true, intentID: 1, rosterRevision: revision), from: id, now: 0)
        }
        await service.receive(.start, from: ids[0], now: 0)
        let originalMatch = await service.rooms[roomID]?.value.matchID
        await service.receive(.start, from: ids[0], now: 1)
        #expect(await service.rooms[roomID]?.value.matchID == originalMatch)
        await service.tick(now: 1_000)
        #expect(await service.rooms[roomID]?.value.phase == .playing)
        for now in stride(from: 1_100, through: 28_000, by: 100) { await service.tick(now: now) }
        let snapshot = try #require(await service.rooms[roomID]?.engine?.snapshot)
        #expect(snapshot.players.allSatisfy { $0.hits == 0 && $0.score == 0 })
        #expect(snapshot.players.contains { $0.misses > 0 })
        #expect(snapshot.phase == .finished)
    }

    @Test func readyRevisionDuplicateAndRosterChange() async throws {
        let (service, ids, roomID) = try await fixture()
        let revision = try #require(await service.rooms[roomID]?.value.rosterRevision)
        await service.receive(.ready(value: true, intentID: 2, rosterRevision: revision), from: ids[0], now: 0)
        await service.receive(.ready(value: false, intentID: 1, rosterRevision: revision), from: ids[0], now: 0)
        #expect(await service.rooms[roomID]?.value.players[0].ready == true)
        await service.receive(.ready(value: true, intentID: 1, rosterRevision: revision - 1), from: ids[1], now: 0)
        #expect(await service.rooms[roomID]?.value.players[1].ready == false)
        await service.receive(.start, from: ids[0], now: 0)
        #expect(await service.rooms[roomID]?.value.phase == .waiting)
        await service.receive(.ready(value: true, intentID: 2, rosterRevision: revision), from: ids[1], now: 0)
        await service.receive(.start, from: ids[0], now: 0)
        await service.disconnect(id: ids[1], now: 100)
        await service.tick(now: 1_200)
        #expect(await service.rooms[roomID]?.value.phase == .waiting)
        #expect(await service.rooms[roomID]?.engine == nil)
    }

    @Test func reconnectRotatesCredentialAndOnlyDisconnectsAffectedSeat() async throws {
        let (service, ids, roomID) = try await fixture()
        let revision = try #require(await service.rooms[roomID]?.value.rosterRevision)
        for id in ids {
            await service.receive(.ready(value: true, intentID: 1, rosterRevision: revision), from: id, now: 0)
        }
        await service.receive(.start, from: ids[0], now: 0)
        await service.tick(now: 1_000)
        let credential = try #require(await service.rooms[roomID]?.presence[ids[1]]?.credential)
        await service.disconnect(id: ids[1], now: 1_100)
        await service.tick(now: 2_000)
        #expect(await service.rooms[roomID]?.engine?.snapshot.players[0].connected == true)
        let replacement = UUID().uuidString
        let output = OutboundMessages(capacity: 100)
        #expect(await service.connect(id: replacement, output: output, now: 2_000))
        await service.authenticated(
            id: replacement,
            player: AuthenticatedPlayer(
                playerID: ids[1], name: "Local",
                sessionBinding: "new-ticket", expiresAt: Int(Date().timeIntervalSince1970) + 3_600), now: 2_000)
        await service.receive(
            .resume(roomID: roomID, credential: credential, generation: 1), from: replacement, now: 2_001)
        #expect(await service.rooms[roomID]?.presence[ids[1]]?.generation == 2)
        #expect(await service.rooms[roomID]?.presence[ids[1]]?.credential != credential)
        #expect(await service.rooms[roomID]?.engine?.snapshot.players[1].connected == true)
        await service.disconnect(id: replacement, now: 2_100)
        await service.tick(now: 17_101)
        #expect(await service.rooms[roomID]?.engine?.snapshot.players[1].lives == 0)
        let finalConnection = UUID().uuidString
        let finalOutput = OutboundMessages()
        #expect(await service.connect(id: finalConnection, output: finalOutput, now: 17_102))
        await service.authenticated(
            id: finalConnection,
            player: AuthenticatedPlayer(
                playerID: ids[1], name: "Local",
                sessionBinding: "another-ticket", expiresAt: Int(Date().timeIntervalSince1970) + 3_600), now: 17_102)
        await service.receive(
            .resume(roomID: roomID, credential: "", generation: 2), from: finalConnection, now: 17_103)
        #expect(await service.connections[finalConnection]?.roomID == nil)
    }

    @Test func authAndConfigurationFailClosed() async throws {
        #expect(throws: ServerConfiguration.ConfigurationError.self) { try ServerConfiguration(environment: [:]) }
        #expect(throws: ServerConfiguration.ConfigurationError.self) {
            try ServerConfiguration(environment: ["MP2_DEV_AUTH": "1", "MP2_BIND": "0.0.0.0"])
        }
        let config = try ServerConfiguration(environment: ["MP2_DEV_AUTH": "1"])
        let auth = TicketAuthenticator(configuration: config)
        await #expect(throws: AuthenticationFailure.self) { try await auth.redeem("dev:anonymous") }
        let id = UUID().uuidString
        #expect(try await auth.redeem("dev:" + id).playerID == id.lowercased())
    }

    @Test func resultOutboxIsDurableAndIdempotent() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mp2-outbox-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let outbox = ResultOutbox(directory: directory)
        let snapshot = MP2Snapshot(
            matchID: UUID().uuidString, revision: 1, elapsedMs: 1_000, phase: .finished,
            gridDimension: 1, players: [MP2Player(id: UUID().uuidString, seat: 0, colorIndex: 0, name: "Local")],
            targets: [], decoys: [])
        let match = CompletedMatch(snapshot: snapshot)
        try await outbox.store(match)
        try await outbox.store(match)
        let restarted = ResultOutbox(directory: directory)
        let files = try await restarted.pending()
        #expect(files.count == 1)
        #expect(try JSONDecoder().decode(CompletedMatch.self, from: Data(contentsOf: files[0])) == match)
        #expect(match.rankingEligible == false)
    }

    @Test func periodicSnapshotsCoalesceWithoutReorderingReceipts() async throws {
        let output = OutboundMessages(capacity: 3)
        let first = MP2ServerMessage.pong(id: 1, clientTimeMs: 1, serverTimeMs: 1)
        let second = MP2ServerMessage.pong(id: 2, clientTimeMs: 2, serverTimeMs: 2)
        let receipt = MP2ServerMessage.receipt(MP2InputReceipt(id: 3, accepted: true, reason: "hit", revision: 3))
        output.yield(first, coalescible: true)
        output.yield(second, coalescible: true)
        output.yield(receipt)
        output.yield(first, coalescible: true)
        if case .dropped = output.yield(receipt) {
        } else {
            Issue.record("A full critical queue must reject another critical event")
        }
        output.finish()
        var iterator = output.makeAsyncIterator()
        #expect(await iterator.next() == second)
        #expect(await iterator.next() == receipt)
        #expect(await iterator.next() == first)
        #expect(await iterator.next() == nil)
    }

    @Test func revokedSessionDisconnectsOnlyItsConnection() async throws {
        let (service, ids, roomID) = try await fixture()
        let validations = await service.validationsDue(now: 15_000)
        let validation = try #require(validations.first { $0.connectionID == ids[1] })
        await service.validated(validation, refreshed: nil, now: 15_001)
        #expect(await service.connections[ids[1]] == nil)
        #expect(await service.connections[ids[0]] != nil)
        #expect(await service.rooms[roomID]?.value.players[1].connected == false)
    }

    @Test func leavingLiveRoomEliminatesSeatAndAllowsAnotherRoom() async throws {
        let (service, ids, roomID) = try await fixture()
        let revision = try #require(await service.rooms[roomID]?.value.rosterRevision)
        for id in ids {
            await service.receive(.ready(value: true, intentID: 1, rosterRevision: revision), from: id, now: 0)
        }
        await service.receive(.start, from: ids[0], now: 0)
        await service.tick(now: 1_000)
        await service.receive(.leave, from: ids[1], now: 1_100)
        #expect(await service.rooms[roomID]?.engine?.snapshot.players[1].lives == 0)
        #expect(await service.rooms[roomID]?.engine?.snapshot.players[0].lives == 3)
        await service.receive(.create(capacity: 2), from: ids[1], now: 1_101)
        let nextRoom = try #require(await service.connections[ids[1]]?.roomID)
        #expect(nextRoom != roomID)
    }
}
