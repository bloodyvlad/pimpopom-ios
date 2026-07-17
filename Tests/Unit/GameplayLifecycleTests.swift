import PimPoPomCore
import SpriteKit
import XCTest

@testable import PimPoPom

@MainActor
final class GameplayLifecycleTests: XCTestCase {
    func testLifecycleMusicRoutingSilencesEveryTerminalPathBeforeMenuReturns() {
        XCTAssertEqual(GameplayMusicRouting.context(for: .started), .gameplay)
        XCTAssertEqual(GameplayMusicRouting.context(for: .finished), .silent)
        XCTAssertEqual(GameplayMusicRouting.context(for: .abandoned), .silent)

        let contexts =
            [GameplayLifecycleEvent.started, .finished].map(GameplayMusicRouting.context(for:))
            + [MusicContext.menu]
        XCTAssertEqual(contexts, [.gameplay, .silent, .menu])
    }

    func testZenCompletionEmitsSynchronousTerminalLifecycle() {
        let coordinator = GameCoordinator(mode: .zen)
        var events: [GameplayLifecycleEvent] = []
        coordinator.onLifecycleEvent = { events.append($0) }

        coordinator.startNewRun()
        coordinator.endZenRun()

        XCTAssertEqual(events, [.started, .finished])
        XCTAssertTrue(coordinator.isFinished)
        coordinator.stop()
    }

    func testBackgroundAbandonmentEmitsOnce() {
        let coordinator = GameCoordinator(mode: .arcade)
        var events: [GameplayLifecycleEvent] = []
        coordinator.onLifecycleEvent = { events.append($0) }

        coordinator.startNewRun()
        coordinator.abandonForBackground()
        coordinator.abandonForBackground()

        XCTAssertEqual(events, [.started, .abandoned])
        XCTAssertTrue(coordinator.wasAbandoned)
        coordinator.stop()
    }

    func testGameSceneRemovesGlyphNodesWhenGlyphsAreDisabled() {
        let engine = GameEngine(random: { 0 })
        _ = engine.start(now: 0, mode: .arcade)
        let active = engine.activateRound(now: 1_000).snapshot
        let scene = GameScene()

        scene.apply(active)
        XCTAssertTrue(scene.children.contains { $0 is SKLabelNode })

        scene.applyGlyphsEnabled(false)
        XCTAssertFalse(scene.children.contains { $0 is SKLabelNode })
    }

    func testOnlyPerfectAndGodlikeHitsPublishRoundedStampEvents() {
        let godlike = ratingStamp(reactionMilliseconds: 249.4)
        XCTAssertEqual(godlike?.rating, .godlike)
        XCTAssertEqual(godlike?.milliseconds, 249)

        let perfect = ratingStamp(reactionMilliseconds: 300.4)
        XCTAssertEqual(perfect?.rating, .perfect)
        XCTAssertEqual(perfect?.milliseconds, 300)

        XCTAssertNil(ratingStamp(reactionMilliseconds: 375))
    }

    func testTooEarlyRecoveryDoesNotReintroduceGetReadyOrRestartLifecycle() {
        let coordinator = GameCoordinator(mode: .arcade)
        var events: [GameplayLifecycleEvent] = []
        var soundEvents: [GameplaySoundEvent] = []
        coordinator.onLifecycleEvent = { events.append($0) }
        coordinator.onSoundEvent = { soundEvents.append($0) }
        coordinator.startNewRun()

        let now = ProcessInfo.processInfo.systemUptime * 1_000
        coordinator.gameScene(
            coordinator.scene,
            didTapCell: 0,
            normalizedLocation: CGPoint(x: 0.5, y: 0.5),
            inputAt: now,
            handledAt: now
        )
        XCTAssertEqual(coordinator.feedback, "Too early")
        XCTAssertEqual(soundEvents, [.lifeLoss])
        XCTAssertEqual(coordinator.snapshot.lives, 2)

        coordinator.gameScene(coordinator.scene, requestsRoundActivationAt: now + 2_000)
        XCTAssertTrue(coordinator.feedback.hasPrefix("Tap "))
        XCTAssertEqual(events, [.started])
        coordinator.stop()
    }

    private func ratingStamp(reactionMilliseconds: Double) -> GameplayRatingStampEvent? {
        let coordinator = GameCoordinator(mode: .arcade)
        coordinator.startNewRun()
        let activeAt = ProcessInfo.processInfo.systemUptime * 1_000 + 1_000
        coordinator.gameScene(coordinator.scene, requestsRoundActivationAt: activeAt)
        coordinator.gameScene(
            coordinator.scene,
            didTapCell: 0,
            normalizedLocation: CGPoint(x: 0.5, y: 0.5),
            inputAt: activeAt + reactionMilliseconds,
            handledAt: activeAt + reactionMilliseconds
        )
        coordinator.stop()
        return coordinator.ratingStampEvent
    }
}
