import PimPoPomCore
import XCTest

@testable import PimPoPom

@MainActor
final class MultiplayerExperienceTests: XCTestCase {
    private var now: Int { Int(ProcessInfo.processInfo.systemUptime * 1_000) }

    private func controllerAndRoom() -> (MultiplayerController, MP2Room) {
        let controller = MultiplayerController(
            backend: BackendClient(isUITestOffline: true), gameCenter: GameCenterService(), audio: AudioController())
        controller.receive(
            .welcome(
                playerID: "p0", connectionID: "c", serverTimeMs: now,
                gameplayRevision: MP2Protocol.gameplayRevision, roomDiscoveryRevision: 2))
        controller.createMatch(capacity: 2)
        let room = MP2Room(
            id: "room", revision: 1, rosterRevision: 1, hostPlayerID: "p0", capacity: 2,
            phase: .waiting,
            players: [
                .init(id: "p0", seat: 0, colorIndex: 0, name: "Pim", ready: true),
                .init(id: "p1", seat: 1, colorIndex: 1, name: "Pom", ready: true),
            ], roomCode: "BCDF2345", isPrivate: false)
        controller.receive(.room(room))
        return (controller, room)
    }

    func testPrivacyIsImmediateFencedAndFailureRollsBackWithoutLosingReady() {
        let (controller, initial) = controllerAndRoom()
        defer { controller.leaveMatch() }
        XCTAssertTrue(controller.waitingState?.canTogglePrivacy == true)
        controller.togglePrivacy(true)
        XCTAssertTrue(controller.waitingState?.displayedPrivate == true)
        XCTAssertFalse(controller.waitingState?.canStart == true)
        controller.receive(.room(initial))
        XCTAssertTrue(controller.waitingState?.displayedPrivate == true, "Old room echoes must not undo pending intent")
        controller.receive(.error(code: "stale_room", message: "Try again"))
        XCTAssertFalse(controller.waitingState?.displayedPrivate == true)
        XCTAssertTrue(controller.waitingState?.displayedCurrentPlayerReady == true)
        controller.togglePrivacy(true)
        var updated = initial
        updated.revision += 1
        updated.isPrivate = true
        controller.receive(.room(updated))
        XCTAssertTrue(controller.waitingState?.displayedPrivate == true)
        XCTAssertNil(controller.waitingState?.pendingPrivacyIntent)
        XCTAssertTrue(controller.waitingState?.canStart == true)
    }

    func testPrivacyWaitsForPendingReadyRoomRevision() {
        let (controller, initial) = controllerAndRoom()
        defer { controller.leaveMatch() }
        controller.toggleReady(false)
        XCTAssertFalse(controller.waitingState?.canTogglePrivacy == true)
        controller.togglePrivacy(true)
        XCTAssertNil(controller.waitingState?.pendingPrivacyIntent)
        var acknowledged = initial
        acknowledged.revision += 1
        acknowledged.players[0].ready = false
        acknowledged.players[0].readyIntentID = 1
        controller.receive(.room(acknowledged))
        XCTAssertTrue(controller.waitingState?.canTogglePrivacy == true)
        controller.togglePrivacy(true)
        XCTAssertTrue(controller.waitingState?.displayedPrivate == true)
    }

    func testLastLivingPlayerIsInteractiveAndFinalizingNeverSaysSpectating() {
        let (controller, initial) = controllerAndRoom()
        defer { controller.leaveMatch() }
        var room = initial
        room.phase = .playing
        room.matchID = "match"
        room.startsAtServerMs = now
        controller.receive(.room(room))
        var players = room.players
        players[1].lives = 0
        players[1].score = 1_000
        func publish(_ revision: Int, phase: MP2MatchPhase) {
            controller.receive(
                .snapshot(
                    .init(
                        matchID: "match", revision: revision, elapsedMs: revision * 100,
                        phase: phase, gridDimension: 1, players: players, targets: [], decoys: [])))
        }
        publish(1, phase: .playing)
        XCTAssertEqual(controller.liveState?.inputMode, .interactive)
        XCTAssertFalse(controller.liveState?.isSpectating == true)
        players[0].lives = 0
        players[0].misses = 3
        publish(2, phase: .finishing)
        XCTAssertEqual(controller.liveState?.inputMode, .finalizing)
        XCTAssertFalse(controller.liveState?.isSpectating == true)
        publish(3, phase: .finished)
        XCTAssertEqual(controller.resultsState.outcomeTitle, "You lose")
    }

    func testEarlyEliminatedHighestScoreWinsAndTiesDoNotUseSurvival() {
        let (controller, initial) = controllerAndRoom()
        defer { controller.leaveMatch() }
        var room = initial
        room.phase = .playing
        room.matchID = "match"
        controller.receive(.room(room))
        var players = room.players
        players[0].lives = 0
        players[0].score = 2_000
        players[0].outAtMs = 10_000
        players[1].score = 1_000
        func publish(_ revision: Int, phase: MP2MatchPhase) {
            controller.receive(
                .snapshot(
                    .init(
                        matchID: "match", revision: revision, elapsedMs: 60_000,
                        phase: phase, gridDimension: 1, players: players, targets: [], decoys: [])))
        }
        publish(1, phase: .playing)
        XCTAssertTrue(controller.liveState?.isSpectating == true)
        XCTAssertTrue(controller.liveState?.localPlayer?.isLeader == true)
        players[1].lives = 0
        players[1].outAtMs = 60_000
        publish(2, phase: .finished)
        XCTAssertEqual(controller.resultsState.outcomeTitle, "You win")
        let settled = controller.resultsState
        publish(3, phase: .finished)
        XCTAssertEqual(controller.resultsState, settled, "Repeated final snapshots must not reset saved-result UI")
        var tied = settled
        tied = .init(
            settlement: .settled(leaderboardEligible: true),
            results: settled.results.map {
                .init(
                    id: $0.id, place: 1, playerCount: 2, name: $0.name, petID: nil,
                    score: 2_000, survivalMilliseconds: $0.survivalMilliseconds, hits: 1, misses: 3,
                    dodges: 0, fastestReactionMilliseconds: nil, averageReactionMilliseconds: nil,
                    maxMultiplier: 1, isCurrentPlayer: $0.isCurrentPlayer)
            }, isRefreshing: false, localSubmissionAccepted: true, message: nil)
        XCTAssertEqual(tied.results.map(\.place), [1, 1])
        XCTAssertEqual(tied.outcomeTitle, "Draw")
    }

    func testServerMissShowsStampWithoutWaitingForLocalTap() {
        let (controller, initial) = controllerAndRoom()
        defer { controller.leaveMatch() }
        var room = initial
        room.phase = .playing
        room.matchID = "match"
        room.startsAtServerMs = now
        controller.receive(.room(room))
        controller.receive(
            .snapshot(
                .init(
                    matchID: "match", revision: 1, elapsedMs: 0, phase: .playing,
                    gridDimension: 1, players: room.players, targets: [], decoys: [])))
        room.players[0].misses += 1
        room.players[0].lives -= 1
        controller.receive(
            .snapshot(
                .init(
                    matchID: "match", revision: 2, elapsedMs: 100, phase: .playing,
                    gridDimension: 1, players: room.players, targets: [], decoys: [])))
        XCTAssertEqual(controller.liveState?.stampEvent?.kind, .missed)
        let stamp = controller.liveState?.stampEvent
        controller.receive(
            .snapshot(
                .init(
                    matchID: "match", revision: 3, elapsedMs: 200, phase: .playing,
                    gridDimension: 1, players: room.players, targets: [], decoys: [])))
        XCTAssertEqual(controller.liveState?.stampEvent, stamp)
    }

    func testDelayedWrongTapAcknowledgementDoesNotRepeatMissedStamp() {
        let (controller, initial) = controllerAndRoom()
        defer { controller.leaveMatch() }
        let oldContact = now - 2_000
        var room = initial
        room.phase = .playing
        room.matchID = "match"
        room.startsAtServerMs = oldContact
        controller.receive(.room(room))
        controller.receive(
            .snapshot(
                .init(
                    matchID: "match", revision: 1, elapsedMs: 0, phase: .playing,
                    gridDimension: 1, players: room.players, targets: [], decoys: [])))
        controller.handleTap(cell: -1, localMonotonicMilliseconds: oldContact + 10, normalizedLocation: .zero)
        let predictedStamp = controller.liveState?.stampEvent
        XCTAssertEqual(predictedStamp?.kind, .missed)
        room.players[0].misses = 1
        room.players[0].lives = 2
        controller.receive(
            .snapshot(
                .init(
                    matchID: "match", revision: 2, elapsedMs: 2_000, phase: .playing,
                    gridDimension: 1, players: room.players, targets: [], decoys: [])))
        XCTAssertEqual(controller.liveState?.stampEvent, predictedStamp)
    }

    func testPixelMenuIconsHavePixelArtworkAndOtherSymbolsKeepTheirFallback() {
        for icon in ["pawprint.fill", "paintpalette.fill"] {
            let rows = ThemedMenuFeatureIcon.pixelPattern(for: icon)
            XCTAssertEqual(rows?.count, 13)
            XCTAssertTrue(rows?.allSatisfy { $0.count == 13 && $0.allSatisfy { $0 == "0" || $0 == "1" } } == true)
        }
        XCTAssertNil(ThemedMenuFeatureIcon.pixelPattern(for: "trophy.fill"))
        XCTAssertEqual(GameplayStampKind.extraLife.text, "+1UP")
        XCTAssertEqual(GameplayStampKind.slowingDown.text, "Slowing down")
    }
}
