import PimPoPomCore
import XCTest

@testable import PimPoPom

@MainActor
final class MultiplayerPresentationTests: XCTestCase {
    func testAvailabilityDoesNotRequireGameCenter() {
        XCTAssertEqual(
            MultiplayerPresentation.Availability.resolve(isSignedIn: false, nicknameConfirmed: true), .signInRequired)
        XCTAssertEqual(
            MultiplayerPresentation.Availability.resolve(isSignedIn: true, nicknameConfirmed: false),
            .confirmedNameRequired)
        XCTAssertEqual(
            MultiplayerPresentation.Availability.resolve(isSignedIn: true, nicknameConfirmed: true), .available)
    }

    func testUnknownSessionDoesNotAskAnAlreadySignedInPlayerToLogin() {
        let controller = MultiplayerController(
            backend: BackendClient(), gameCenter: GameCenterService(), audio: AudioController())
        XCTAssertEqual(controller.availability, .checkingSession)
    }

    func testOlderServiceIsNotSilentlyUsedForNewGameplay() {
        let controller = makeController()
        controller.receive(.welcome(playerID: "p0", connectionID: "old", serverTimeMs: now))
        controller.createMatch(capacity: 2)
        XCTAssertFalse(controller.hubState.isCreating)
        XCTAssertTrue(controller.hubState.message?.contains("updating") == true)
    }

    func testQuickCreateLeaveWaitsForAcknowledgmentBeforeNewCreate() {
        let controller = makeController()
        controller.receive(.welcome(playerID: "p0", connectionID: "c", serverTimeMs: now, gameplayRevision: 2))
        controller.createMatch(capacity: 2)
        controller.leaveMatch()
        controller.createMatch(capacity: 2)
        controller.receive(.resumeCredential(roomID: "r", credential: "old", generation: 1))
        controller.receive(.room(room()))
        XCTAssertEqual(controller.phase, .hub)
        XCTAssertNil(controller.waitingState)
        controller.receive(.left)
        controller.createMatch(capacity: 2)
        var fresh = room()
        fresh.id = "new"
        controller.receive(.room(fresh))
        XCTAssertEqual(controller.waitingState?.matchID, "new")
        controller.leaveMatch()
    }

    func testDirectoryIgnoresFullFinishedAndIncompatibleGames() {
        let controller = makeController()
        controller.receive(
            .list([
                .init(
                    id: "open", hostName: "Pim", capacity: 2, playerCount: 1, revision: 1, phase: .waiting,
                    gameplayRevision: 2),
                .init(
                    id: "full", hostName: "Pom", capacity: 2, playerCount: 2, revision: 1, phase: .waiting,
                    gameplayRevision: 2),
                .init(
                    id: "done", hostName: "Pom", capacity: 2, playerCount: 1, revision: 1, phase: .finished,
                    gameplayRevision: 2),
                .init(id: "old", hostName: "Pim", capacity: 2, playerCount: 1, revision: 1, phase: .waiting),
            ]))
        XCTAssertEqual(controller.hubState.lobbies.map(\.id), ["open"])
        controller.receive(.list([]))
        XCTAssertTrue(controller.hubState.lobbies.isEmpty)
    }

    func testReconnectReleasesLostCreateAndLeaveAcknowledgments() {
        for leaveBeforeDisconnect in [false, true] {
            let controller = makeController()
            controller.receive(.welcome(playerID: "p0", connectionID: "first", serverTimeMs: now, gameplayRevision: 2))
            controller.createMatch(capacity: 2)
            if leaveBeforeDisconnect { controller.leaveMatch() }
            controller.receive(.welcome(playerID: "p0", connectionID: "new", serverTimeMs: now, gameplayRevision: 2))
            XCTAssertFalse(controller.hubState.isCreating)
            controller.createMatch(capacity: 2)
            XCTAssertTrue(controller.hubState.isCreating)
            controller.receive(.room(room()))
            XCTAssertEqual(controller.phase, .waiting)
            controller.leaveMatch()
        }
    }

    func testReplacedLobbyDoesNotResumeOnTheOldSocket() {
        let controller = makeController()
        controller.receive(.welcome(playerID: "p0", connectionID: "old", serverTimeMs: now, gameplayRevision: 2))
        controller.joinMatch("r")
        controller.receive(.room(room()))
        controller.receive(.resumeCredential(roomID: "r", credential: "old-token", generation: 1))
        controller.receive(.error(code: "room_replaced", message: "Opened on another connection."))
        XCTAssertEqual(controller.phase, .hub)
        XCTAssertNil(controller.waitingState)
        controller.receive(.welcome(playerID: "p0", connectionID: "new", serverTimeMs: now, gameplayRevision: 2))
        controller.createMatch(capacity: 2)
        XCTAssertTrue(controller.hubState.isCreating)
        controller.leaveMatch()
    }

    func testHeartTapGivesImmediateFeedbackWithoutPredictingLifeOrMistake() {
        let controller = makeController()
        let time = now
        controller.receive(.welcome(playerID: "p0", connectionID: "c", serverTimeMs: time, gameplayRevision: 2))
        controller.joinMatch("r")
        var playing = room()
        playing.phase = .playing
        playing.matchID = "m"
        playing.startsAtServerMs = time
        playing.players[0].lives = 2
        controller.receive(.room(playing))
        controller.receive(
            .snapshot(
                .init(
                    matchID: "m", revision: 2, elapsedMs: 0, phase: .playing, gridDimension: 2,
                    players: playing.players, targets: [], decoys: [],
                    hearts: [.init(id: 1, cell: 2, activateAtMs: 0, expiresAtMs: 3_000)], gameplayRevision: 2)))
        controller.gameScene(controller.scene, didAdvanceTo: Double(time + 120))
        XCTAssertTrue(controller.liveState?.cells[2].isHeart == true)
        controller.handleTap(cell: 2, localMonotonicMilliseconds: time + 210, normalizedLocation: .zero)
        XCTAssertFalse(controller.liveState?.cells[2].isHeart == true)
        XCTAssertEqual(controller.liveState?.localPlayer?.lives, 2)
        XCTAssertEqual(controller.liveState?.isRecovering, false)
        controller.handleTap(cell: 2, localMonotonicMilliseconds: time + 211, normalizedLocation: .zero)
        XCTAssertEqual(controller.liveState?.isRecovering, false)
        controller.leaveMatch()
    }

    func testReadyIsImmediateAndAuthoritativeConfirmationClearsPending() {
        let controller = makeController()
        controller.receive(.welcome(playerID: "p0", connectionID: "c", serverTimeMs: now, gameplayRevision: 2))
        controller.joinMatch("r")
        controller.receive(.room(room()))
        controller.toggleReady(true)
        XCTAssertEqual(controller.waitingState?.displayedCurrentPlayerReady, true)
        XCTAssertEqual(controller.waitingState?.currentPlayer?.ready, false)
        XCTAssertEqual(controller.waitingState?.canStart, false)
        var confirmed = room()
        confirmed.revision += 1
        confirmed.players[0].ready = true
        confirmed.players[0].readyIntentID = 1
        controller.receive(.room(confirmed))
        XCTAssertNil(controller.waitingState?.pendingReadyIntent)
        XCTAssertEqual(controller.waitingState?.canStart, true)
        controller.leaveMatch()
    }

    func testStaleRoomSnapshotCannotUndoReady() {
        let controller = makeController()
        controller.receive(.welcome(playerID: "p0", connectionID: "c", serverTimeMs: now, gameplayRevision: 2))
        controller.joinMatch("r")
        var confirmed = room()
        confirmed.revision = 10
        confirmed.players[0].ready = true
        controller.receive(.room(confirmed))
        controller.receive(.room(room()))
        XCTAssertEqual(controller.waitingState?.currentPlayer?.ready, true)
        controller.leaveMatch()
    }

    func testOwnTapUpdatesScoreWithoutAnyReceiptOrOpponentMessage() {
        let controller = makeController()
        let time = now
        controller.receive(.welcome(playerID: "p0", connectionID: "c", serverTimeMs: time, gameplayRevision: 2))
        controller.joinMatch("r")
        var playing = room()
        playing.phase = .playing
        playing.matchID = "m"
        playing.startsAtServerMs = time
        controller.receive(.room(playing))
        controller.receive(
            .snapshot(
                .init(
                    matchID: "m", revision: 2, elapsedMs: 0, phase: .playing,
                    gridDimension: 1, players: playing.players,
                    targets: [
                        .init(id: 1, cell: 0, ownerSeat: 0, colorIndex: 0, activateAtMs: 0, responseWindowMs: 1_000)
                    ], decoys: [])))
        controller.gameScene(controller.scene, didAdvanceTo: Double(time + 10))
        controller.handleTap(cell: 0, localMonotonicMilliseconds: time + 210, normalizedLocation: .init(x: 0.5, y: 0.5))
        XCTAssertGreaterThan(controller.liveState?.localPlayer?.points ?? 0, 0)
        XCTAssertNotNil(controller.liveState?.hitFeedbackEvent)
        XCTAssertEqual(controller.phase, .live)
        XCTAssertEqual(controller.liveState?.orderedCells.count, 1)
        controller.leaveMatch()
    }

    func testDynamicSharedBoardDimensionsAndLayout() {
        for dimension in [1, 2, 4] {
            let state = MultiplayerPresentation.LiveMatchState(
                matchID: "m", elapsedMilliseconds: 0, cells: [],
                players: [], localSeat: 0, streakSteps: 0, isRecovering: false, announcement: nil,
                gridDimension: dimension)
            XCTAssertEqual(state.orderedCells.map(\.id), Array(0..<(dimension * dimension)))
            let layout = MultiplayerLiveLayoutMetrics.resolve(
                availableSize: CGSize(width: 430, height: 932), playerCount: 4)
            XCTAssertGreaterThan(layout.boardSide, 300)
        }
    }

    func testLeaveIgnoresInFlightRoomSnapshotAndResumeCredential() {
        let controller = makeController()
        controller.receive(.welcome(playerID: "p0", connectionID: "c", serverTimeMs: now, gameplayRevision: 2))
        controller.joinMatch("r")
        var playing = room()
        playing.phase = .playing
        playing.matchID = "m"
        controller.receive(.room(playing))
        controller.leaveMatch()
        controller.receive(.resumeCredential(roomID: "r", credential: "retired", generation: 1))
        controller.receive(.room(playing))
        controller.receive(
            .snapshot(
                .init(
                    matchID: "m", revision: 2, elapsedMs: 0, phase: .playing,
                    gridDimension: 1, players: playing.players, targets: [], decoys: [])))
        XCTAssertEqual(controller.phase, .hub)
        XCTAssertNil(controller.waitingState)
        XCTAssertNil(controller.liveState)

        controller.receive(.left)

        controller.createMatch(capacity: 2)
        controller.receive(.room(playing))
        XCTAssertEqual(controller.phase, .hub)
        var created = room()
        created.id = "new-room"
        controller.receive(.room(created))
        XCTAssertEqual(controller.waitingState?.matchID, "new-room")
        controller.leaveMatch()
        controller.receive(.left)
        controller.joinMatch("r")
        controller.receive(.room(room()))
        XCTAssertEqual(controller.phase, .waiting)
        controller.leaveMatch()
    }

    func testSharedRendererHasNoDecoyWarningAndHeartsSurviveGlyphsOff() {
        let scene = GameScene()
        scene.size = CGSize(width: 320, height: 320)
        scene.applyGlyphsEnabled(false)
        scene.applySharedBoard(
            dimension: 2, cells: [.init(kind: .decoy, colorIndex: 1), .init(), .init(), .init()], hearts: [2])
        XCTAssertNil(scene.childNode(withName: "cell-trap-0"))
        XCTAssertNotNil(scene.childNode(withName: "cell-heart-2"))
        XCTAssertNotNil(scene.tapPoint(forCellAt: 3, horizontalFraction: 0.5, verticalFraction: 0.5))
        XCTAssertNil(scene.tapPoint(forCellAt: 4, horizontalFraction: 0.5, verticalFraction: 0.5))
    }

    func testDelayedContactUsesGridVisibleBeforeExpansion() throws {
        let scene = GameScene()
        scene.size = CGSize(width: 320, height: 320)
        scene.applySharedBoard(dimension: 1, cells: [.init(kind: .target, colorIndex: 0)])
        scene.recordSharedBoardPresentation(at: 100)
        let contact = try XCTUnwrap(scene.tapPoint(forCellAt: 0, horizontalFraction: 0.9, verticalFraction: 0.9))
        scene.applySharedBoard(dimension: 2, cells: Array(repeating: .init(), count: 4))
        scene.recordSharedBoardPresentation(at: 200)
        XCTAssertEqual(scene.sharedCellIndex(at: contact, inputAt: 199), 0)
        XCTAssertEqual(scene.sharedCellIndex(at: contact, inputAt: 200), 3)
        scene.applySharedBoard(dimension: 4, cells: Array(repeating: .init(), count: 16))
        scene.recordSharedBoardPresentation(at: 300)
        XCTAssertEqual(scene.sharedCellIndex(at: contact, inputAt: 299), 3)
        XCTAssertEqual(scene.sharedCellIndex(at: contact, inputAt: 300), 15)
    }

    private var now: Int { Int(ProcessInfo.processInfo.systemUptime * 1_000) }
    private func makeController() -> MultiplayerController {
        MultiplayerController(
            backend: BackendClient(isUITestOffline: true), gameCenter: GameCenterService(), audio: AudioController())
    }
    private func room() -> MP2Room {
        .init(
            id: "r", revision: 1, rosterRevision: 1, hostPlayerID: "p0", capacity: 2, phase: .waiting,
            players: [
                .init(id: "p0", seat: 0, colorIndex: 0, name: "Pim"),
                .init(id: "p1", seat: 1, colorIndex: 1, name: "Pom", ready: true),
            ])
    }
}
