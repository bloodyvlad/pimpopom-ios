import Foundation
import PimPoPomCore
import XCTest

@testable import PimPoPom

@MainActor
final class MultiplayerSocketTests: XCTestCase {
    func testNativeTextTransportReadyStartInputAndIndependentDisconnect() async throws {
        try await Self.requireLocalService()
        let url = try XCTUnwrap(URL(string: "ws://127.0.0.1:18080/multiplayer/v2"))
        let hostID = UUID().uuidString.lowercased()
        let guestID = UUID().uuidString.lowercased()
        let host = MultiplayerSocket()
        let guest = MultiplayerSocket()
        let hostEvents = await host.connect(url: url, ticket: "dev:" + hostID)
        let guestEvents = await guest.connect(url: url, ticket: "dev:" + guestID)

        do {
            let welcomedHost: String = try await Self.nextValue(from: hostEvents) {
                if case .welcome(let playerID, _, _, let revision, _) = $0, revision == 2 { return playerID }
                return nil
            }
            let welcomedGuest: String = try await Self.nextValue(from: guestEvents) {
                if case .welcome(let playerID, _, _, let revision, _) = $0, revision == 2 { return playerID }
                return nil
            }
            XCTAssertEqual(welcomedHost, hostID)
            XCTAssertEqual(welcomedGuest, guestID)

            await host.send(.create(capacity: 2))
            let credential: (roomID: String, generation: Int) = try await Self.nextValue(from: hostEvents) {
                if case .resumeCredential(let roomID, _, let generation) = $0 { return (roomID, generation) }
                return nil
            }
            let created = try await Self.room(from: hostEvents) { $0.players.count == 1 }
            XCTAssertEqual(created.id, credential.roomID)
            await guest.send(.join(roomID: created.id))
            let roster = try await Self.room(from: hostEvents) { $0.players.count == 2 }
            let guestRoster = try await Self.room(from: guestEvents) { $0.players.count == 2 }
            XCTAssertEqual(roster.rosterRevision, guestRoster.rosterRevision)
            XCTAssertEqual(Set(roster.players.map(\.id)), Set([hostID, guestID]))

            await host.send(.ready(value: true, intentID: 1, rosterRevision: roster.rosterRevision))
            await guest.send(.ready(value: true, intentID: 1, rosterRevision: roster.rosterRevision))
            let ready = try await Self.room(from: hostEvents) { $0.players.allSatisfy(\.ready) }
            _ = try await Self.room(from: guestEvents) { $0.players.allSatisfy(\.ready) }
            XCTAssertTrue(ready.players.allSatisfy(\.connected))
            XCTAssertGreaterThan(ready.revision, roster.revision)

            await host.send(.start)
            await host.send(.start)
            let countdown = try await Self.room(from: hostEvents) { $0.phase == .countdown }
            let duplicateStart = try await Self.room(from: hostEvents) { $0.phase == .countdown }
            XCTAssertNotNil(countdown.matchID)
            XCTAssertEqual(countdown.matchID, duplicateStart.matchID)
            XCTAssertEqual(countdown.startsAtServerMs, duplicateStart.startsAtServerMs)

            let initial = try await Self.snapshot(from: hostEvents) { $0.phase == .playing }
            _ = try await Self.snapshot(from: guestEvents) { $0.phase == .playing }
            XCTAssertEqual(initial.matchID, countdown.matchID)
            XCTAssertEqual(initial.gameplayRevision, 2)
            XCTAssertTrue(initial.players.allSatisfy { $0.score == 0 && $0.hits == 0 })
            let hostSeat = try XCTUnwrap(initial.players.first { $0.id == hostID }?.seat)
            let input = MP2Input(
                id: 1, seat: hostSeat, targetID: nil, cell: -1,
                presentedAtMs: initial.elapsedMs, contactAtMs: initial.elapsedMs,
                lastServerRevision: initial.revision, roomEpoch: created.epoch,
                sessionGeneration: credential.generation)
            await host.send(.input(input))
            let receipt: MP2InputReceipt = try await Self.nextValue(from: hostEvents) {
                if case .receipt(let receipt) = $0, receipt.id == input.id { return receipt }
                return nil
            }
            XCTAssertTrue(receipt.accepted, receipt.reason)
            let confirmed = try await Self.snapshot(from: hostEvents) {
                $0.revision >= receipt.revision && $0.players.contains { $0.id == hostID && $0.misses == 1 }
            }
            XCTAssertEqual(confirmed.players.first { $0.id == hostID }?.lives, 2)
            XCTAssertEqual(confirmed.players.first { $0.id == guestID }?.lives, 3)

            await guest.disconnect()
            _ = try await Self.room(from: hostEvents) {
                $0.players.contains { $0.id == guestID && !$0.connected }
            }
            await host.send(.ping(id: 91, clientTimeMs: 17))
            let echoed: Int = try await Self.nextValue(from: hostEvents) {
                if case .pong(let id, let clientTimeMs, _) = $0, id == 91 { return clientTimeMs }
                return nil
            }
            XCTAssertEqual(echoed, 17)
            let continuing = try await Self.snapshot(from: hostEvents) {
                $0.elapsedMs > confirmed.elapsedMs && $0.players.contains { $0.id == guestID && !$0.connected }
            }
            XCTAssertEqual(continuing.phase, .playing)
            XCTAssertTrue(continuing.players.first { $0.id == hostID }?.connected == true)
        } catch {
            await host.disconnect()
            await guest.disconnect()
            throw error
        }
        await host.disconnect()
        await guest.disconnect()
    }

    /// Fixed loopback URLs prevent a test configuration from touching production.
    /// Absence is an explicit XCTest skip, not a passing transport assertion.
    private nonisolated static func requireLocalService() async throws {
        struct Health: Decodable {
            let status: String
            let protocolVersion: Int
            let ruleset: String
            let rankingEnabled: Bool
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 1.5
        configuration.timeoutIntervalForResource = 2
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let endpoint = URL(string: "http://127.0.0.1:18080/health")!
        do {
            let (data, response) = try await session.data(from: endpoint)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                data.count <= 4_096,
                let health = try? JSONDecoder().decode(Health.self, from: data),
                health.status == "ok", health.protocolVersion == MP2Protocol.version,
                health.ruleset == MP2Protocol.ruleset, !health.rankingEnabled
            else { throw XCTSkip("Local Multiplayer v2 fixture service is unavailable on port 18080.") }
        } catch {
            throw XCTSkip("Start the local MP2_DEV_AUTH=1 service on port 18080 to run native WebSocket coverage.")
        }
    }

    private nonisolated static func room(
        from events: AsyncStream<MultiplayerSocketEvent>,
        matching predicate: @escaping @Sendable (MP2Room) -> Bool
    ) async throws -> MP2Room {
        try await nextValue(from: events) {
            if case .room(let room) = $0, predicate(room) { return room }
            return nil
        }
    }

    private nonisolated static func snapshot(
        from events: AsyncStream<MultiplayerSocketEvent>,
        matching predicate: @escaping @Sendable (MP2Snapshot) -> Bool
    ) async throws -> MP2Snapshot {
        try await nextValue(from: events) {
            if case .snapshot(let snapshot) = $0, predicate(snapshot) { return snapshot }
            return nil
        }
    }

    private nonisolated static func nextValue<Value: Sendable>(
        from events: AsyncStream<MultiplayerSocketEvent>,
        extract: @escaping @Sendable (MP2ServerMessage) -> Value?
    ) async throws -> Value {
        try await withThrowingTaskGroup(of: Value.self) { group in
            group.addTask {
                for await event in events {
                    switch event {
                    case .message(let message):
                        if case .error(let code, let description) = message {
                            throw MultiplayerSocketTestError.serverError(code + ": " + description)
                        }
                        if let value = extract(message) { return value }
                    case .disconnected(let reason):
                        throw MultiplayerSocketTestError.disconnected(reason)
                    }
                }
                throw MultiplayerSocketTestError.streamEnded
            }
            group.addTask {
                try await Task.sleep(for: .seconds(5))
                throw MultiplayerSocketTestError.timedOut
            }
            defer { group.cancelAll() }
            guard let value = try await group.next() else { throw MultiplayerSocketTestError.streamEnded }
            return value
        }
    }
}

private enum MultiplayerSocketTestError: Error {
    case timedOut
    case streamEnded
    case disconnected(String)
    case serverError(String)
}
