import PimPoPomCore
import XCTest

@testable import PimPoPom

@MainActor
final class MultiplayerRoomSearchTests: XCTestCase {
    func testSearchIgnoresStaleResponsesAndUnsolicitedDirectory() {
        let controller = makeController()
        defer { controller.close() }
        controller.searchLobbies("  Alice  ")
        XCTAssertEqual(controller.hubState.searchQuery, "Alice")
        controller.searchLobbies("BCDF2345")
        controller.receive(.searchResults(query: "Alice", requestID: 1, rooms: [room("old")]))
        controller.receive(.list([room("public")]))
        XCTAssertTrue(controller.hubState.lobbies.isEmpty)
        controller.receive(.searchResults(query: "BCDF2345", requestID: 2, rooms: [room("private", isPrivate: true)]))
        XCTAssertEqual(controller.hubState.lobbies.map(\.id), ["private"])
        XCTAssertEqual(controller.hubState.lobbies.first?.roomCode, "BCDF2345")
        XCTAssertEqual(controller.hubState.lobbies.first?.isPrivate, true)
        XCTAssertFalse(controller.hubState.isRefreshing)
        controller.searchLobbies("")
        controller.receive(.searchResults(query: "BCDF2345", requestID: 2, rooms: [room("private", isPrivate: true)]))
        XCTAssertTrue(controller.hubState.lobbies.isEmpty)
        controller.receive(.list([room("public"), room("private", isPrivate: true)]))
        XCTAssertEqual(controller.hubState.lobbies.map(\.id), ["public"])
    }

    func testWaitingRoomProjectsStableCodeAndPrivateFlag() {
        let controller = makeController()
        defer { controller.close() }
        controller.receive(
            .welcome(
                playerID: "p0", connectionID: "c0", serverTimeMs: 0, gameplayRevision: MP2Protocol.gameplayRevision,
                roomDiscoveryRevision: 1)
        )
        controller.createMatch(capacity: 4, isPrivate: true)
        var value = MP2Room(
            id: "room", revision: 1, rosterRevision: 1, hostPlayerID: "p0", capacity: 4,
            phase: .waiting, players: [.init(id: "p0", seat: 0, colorIndex: 0, name: "Alice")],
            gameplayRevision: MP2Protocol.gameplayRevision, roomCode: "BCDF2345", isPrivate: true)
        controller.receive(.room(value))
        XCTAssertEqual(controller.waitingState?.roomCode, "BCDF2345")
        XCTAssertEqual(controller.waitingState?.isPrivate, true)
        controller.toggleReady(true)
        XCTAssertEqual(controller.waitingState?.displayedCurrentPlayerReady, true)
        value.revision += 1
        value.players[0].ready = true
        value.players[0].readyIntentID = 1
        controller.receive(.room(value))
        XCTAssertEqual(controller.waitingState?.roomCode, "BCDF2345")
        XCTAssertEqual(controller.waitingState?.isPrivate, true)
    }

    func testOversizedSearchIsRejectedLocallyAndCloseInvalidatesResults() {
        let controller = makeController()
        controller.searchLobbies(String(repeating: "a", count: 129))
        XCTAssertFalse(controller.hubState.isRefreshing)
        XCTAssertNotNil(controller.hubState.message)
        controller.searchLobbies("Alice")
        controller.close()
        controller.receive(.searchResults(query: "Alice", requestID: 2, rooms: [room("old")]))
        XCTAssertTrue(controller.hubState.lobbies.isEmpty)
        XCTAssertEqual(controller.hubState.searchQuery, "")
    }

    func testOldServerCannotSilentlyCreateAPublicGameForAPrivateRequest() {
        let controller = makeController()
        defer { controller.close() }
        controller.receive(
            .welcome(
                playerID: "p0", connectionID: "old", serverTimeMs: 0, gameplayRevision: MP2Protocol.gameplayRevision))
        XCTAssertFalse(controller.hubState.supportsRoomCodes)
        controller.createMatch(capacity: 2, isPrivate: true)
        XCTAssertFalse(controller.hubState.isCreating)
        XCTAssertEqual(controller.phase, .hub)
        XCTAssertNotNil(controller.hubState.message)
        controller.receive(
            .room(
                .init(
                    id: "public", revision: 1, rosterRevision: 1,
                    hostPlayerID: "p0", capacity: 2, phase: .waiting,
                    players: [.init(id: "p0", seat: 0, colorIndex: 0, name: "Alice")],
                    gameplayRevision: MP2Protocol.gameplayRevision)))
        XCTAssertNil(controller.waitingState)
        controller.createMatch(capacity: 2)
        XCTAssertTrue(controller.hubState.isCreating, "Public legacy rooms remain compatible")
    }

    func testFailedResumeRefreshesRetainedSearchWithAFreshRequestID() {
        let controller = makeController()
        defer { controller.close() }
        controller.searchLobbies("Alice")
        controller.receive(.error(code: "resume_rejected", message: "Return to the game list."))
        XCTAssertEqual(controller.hubState.searchQuery, "Alice")
        controller.receive(.searchResults(query: "Alice", requestID: 1, rooms: [room("old")]))
        XCTAssertTrue(controller.hubState.lobbies.isEmpty)
        controller.receive(.searchResults(query: "Alice", requestID: 2, rooms: [room("fresh")]))
        XCTAssertEqual(controller.hubState.lobbies.map(\.id), ["fresh"])
    }

    private func makeController() -> MultiplayerController {
        let controller = MultiplayerController(
            backend: BackendClient(isUITestOffline: true), gameCenter: GameCenterService(), audio: AudioController())
        controller.receive(
            .welcome(
                playerID: "p0", connectionID: "c0", serverTimeMs: 0, gameplayRevision: MP2Protocol.gameplayRevision,
                roomDiscoveryRevision: 1)
        )
        return controller
    }

    private func room(_ id: String, isPrivate: Bool = false) -> MP2RoomSummary {
        .init(
            id: id, hostName: "Alice", capacity: 4, playerCount: 1, revision: 1, phase: .waiting,
            gameplayRevision: MP2Protocol.gameplayRevision, roomCode: "BCDF2345", isPrivate: isPrivate)
    }
}
