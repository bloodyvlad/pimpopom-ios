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

    func testReadyIsImmediateAndAuthoritativeConfirmationClearsPending() {
        let controller = makeController()
        controller.receive(.welcome(playerID: "p0", connectionID: "c", serverTimeMs: now))
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
        controller.receive(.welcome(playerID: "p0", connectionID: "c", serverTimeMs: now))
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
        controller.receive(.welcome(playerID: "p0", connectionID: "c", serverTimeMs: time))
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
        controller.receive(.welcome(playerID: "p0", connectionID: "c", serverTimeMs: now))
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

        controller.createMatch(capacity: 2)
        controller.receive(.room(playing))
        XCTAssertEqual(controller.phase, .hub)
        var created = room()
        created.id = "new-room"
        controller.receive(.room(created))
        XCTAssertEqual(controller.waitingState?.matchID, "new-room")
        controller.leaveMatch()
        controller.joinMatch("r")
        controller.receive(.room(room()))
        XCTAssertEqual(controller.phase, .waiting)
        controller.leaveMatch()
    }

    func testSharedRendererShowsMandatoryTrapMarkerAndUsesArcadeGeometry() {
        let scene = GameScene()
        scene.size = CGSize(width: 320, height: 320)
        scene.applyGlyphsEnabled(false)
        scene.applySharedBoard(dimension: 2, cells: [.init(kind: .decoy, colorIndex: 1), .init(), .init(), .init()])
        XCTAssertNotNil(scene.childNode(withName: "cell-trap-0"))
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
