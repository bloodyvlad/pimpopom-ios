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
}
