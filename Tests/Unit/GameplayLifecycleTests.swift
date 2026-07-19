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
        XCTAssertTrue(scene.children.contains { $0.name?.hasPrefix("cell-glyph-") == true })
        XCTAssertTrue(
            scene.children
                .filter { $0.name?.hasPrefix("cell-glyph-") == true }
                .allSatisfy { $0 is SKShapeNode }
        )

        scene.applyGlyphsEnabled(false)
        XCTAssertFalse(scene.children.contains { $0.name?.hasPrefix("cell-glyph-") == true })
    }

    func testGameSceneAppliesDensityScaleToRenderedGlyphBounds() throws {
        let oneByOneEngine = GameEngine(random: { 0 })
        _ = oneByOneEngine.start(now: 0, mode: .arcade)
        let oneByOne = oneByOneEngine.activateRound(now: 1_000).snapshot

        let twoByTwoEngine = GameEngine(random: { 0 })
        _ = twoByTwoEngine.start(now: 0, mode: .arcade)
        var twoByTwoNow = 1_000.0
        for _ in 0..<twoByTwoEngine.configuration.twoByTwoStartsAtHits {
            let active = twoByTwoEngine.activateRound(now: twoByTwoNow).snapshot
            let targetIndex = try XCTUnwrap(active.targetIndex)
            _ = twoByTwoEngine.tap(
                cellIndex: targetIndex,
                now: twoByTwoNow + 100,
                resolvedAt: twoByTwoNow + 100
            )
            twoByTwoNow += 1_000
        }
        let twoByTwo = twoByTwoEngine.activateRound(now: twoByTwoNow).snapshot

        let fourByFourEngine = GameEngine(random: { 0 })
        _ = fourByFourEngine.start(now: 0, mode: .arcade)
        let fourByFour = fourByFourEngine.activateRound(
            now: Double(fourByFourEngine.configuration.phases.fourByFourStartsAtMilliseconds)
        ).snapshot

        for snapshot in [oneByOne, twoByTwo, fourByFour] {
            let dimension = snapshot.difficulty.gridDimension
            let scene = GameScene()
            scene.apply(snapshot)
            let glyph = try XCTUnwrap(
                scene.children.first { $0.name?.hasPrefix("cell-glyph-") == true }
                    as? SKShapeNode
            )
            let path = try XCTUnwrap(glyph.path)
            let layout = GameBoardLayout(size: scene.size, dimension: dimension)
            let expectedSide = GameCellVisualMetrics.glyphBoxSide(
                side: layout.cellSide,
                minimumBaseSide: 24,
                scale: GameCellVisualMetrics.liveGlyphScale(gridDimension: dimension)
            )

            XCTAssertEqual(path.boundingBox.width, expectedSide, accuracy: 0.001)
            XCTAssertEqual(path.boundingBox.height, expectedSide, accuracy: 0.001)
        }
    }

    func testGameSceneSharesThemeEffectsAndPixelGlyphPathsWithPreviews() throws {
        let engine = GameEngine(random: { 0 })
        _ = engine.start(now: 0, mode: .arcade)
        let active = engine.activateRound(now: 1_000).snapshot
        let scene = GameScene()
        scene.apply(active)

        scene.applyTheme("disco")
        let discoCell = try XCTUnwrap(
            scene.children.first { $0.name == "cell-0" } as? SKShapeNode
        )
        XCTAssertFalse(scene.children.contains { $0.name?.contains("corner-underlay") == true })
        XCTAssertFalse(
            scene.children.contains { $0.name?.contains("disco-outgoing-glow") == true }
        )
        XCTAssertEqual(discoCell.glowWidth, 0)
        let discoBorder = try XCTUnwrap(
            scene.children.first { $0.name == "cell-0-disco-border" } as? SKShapeNode
        )
        let discoGlyph = try XCTUnwrap(
            scene.children.first { $0.name == "cell-glyph-0" } as? SKShapeNode
        )
        XCTAssertLessThan(discoCell.zPosition, discoBorder.zPosition)
        XCTAssertLessThan(discoBorder.zPosition, discoGlyph.zPosition)
        XCTAssertTrue(scene.children.contains { $0.name?.contains("disco-active-glaze") == true })
        XCTAssertTrue(scene.children.contains { $0.name?.contains("disco-active-depth") == true })

        scene.applyTheme("light")
        XCTAssertTrue(scene.children.contains { $0.name?.contains("light-glass") == true })

        scene.applyTheme("pixel")
        XCTAssertTrue(scene.children.contains { $0.name?.contains("pixel-noise") == true })
        let noise = try XCTUnwrap(
            scene.children.first { $0.name?.contains("pixel-noise") == true }
        )
        let noiseCrop = try XCTUnwrap(noise as? SKCropNode)
        let noiseSprite = try XCTUnwrap(noiseCrop.children.first as? SKSpriteNode)
        XCTAssertEqual(noiseSprite.blendMode, .alpha)
        XCTAssertEqual(noiseSprite.texture?.filteringMode, .nearest)
        let pixelBorder = try XCTUnwrap(
            scene.children.first { $0.name?.contains("pixel-border") == true } as? SKShapeNode
        )
        let pixelCell = try XCTUnwrap(
            scene.children.first { $0.name == "cell-0" } as? SKShapeNode
        )
        XCTAssertEqual(pixelCell.strokeColor.cgColor.alpha, 0, accuracy: 0.001)
        XCTAssertGreaterThan(pixelBorder.strokeColor.cgColor.alpha, 0)
        let glyph = try XCTUnwrap(
            scene.children.first { $0.name?.hasPrefix("cell-glyph-") == true } as? SKShapeNode
        )
        XCTAssertFalse(glyph.isAntialiased)
    }

    func testBoardTapReachesPetFollowBeforeGameplayAcceptance() {
        let coordinator = GameCoordinator(mode: .arcade)
        var received: [CGPoint] = []
        coordinator.onBoardTap = { received.append($0) }
        let now = ProcessInfo.processInfo.systemUptime * 1_000
        let location = CGPoint(x: 0.91, y: 0.30)

        coordinator.gameScene(coordinator.scene, didPointAt: location)
        coordinator.gameScene(
            coordinator.scene,
            didTapCell: 0,
            normalizedLocation: location,
            inputAt: now,
            handledAt: now
        )

        XCTAssertEqual(received, [location])
    }

    func testGameBoardGapTapStillReachesPetFollow() throws {
        let engine = GameEngine(random: { 0 })
        _ = engine.start(now: 0, mode: .arcade)
        var now = 1_000.0
        for _ in 0..<engine.configuration.twoByTwoStartsAtHits {
            let active = engine.activateRound(now: now).snapshot
            let targetIndex = try XCTUnwrap(active.targetIndex)
            _ = engine.tap(
                cellIndex: targetIndex,
                now: now + 100,
                resolvedAt: now + 100
            )
            now += 1_000
        }
        let twoByTwo = engine.activateRound(now: now).snapshot
        XCTAssertEqual(twoByTwo.difficulty.gridDimension, 2)

        let coordinator = GameCoordinator(mode: .arcade)
        var received: [CGPoint] = []
        coordinator.onBoardTap = { received.append($0) }
        coordinator.scene.apply(twoByTwo)
        coordinator.scene.handleBoardTouch(
            at: CGPoint(x: 160, y: 160),
            inputAt: now,
            handledAt: now
        )

        XCTAssertEqual(received, [CGPoint(x: 0.5, y: 0.5)])
    }

    func testGameBoardGapTapBecomesAProtocolValidMiss() throws {
        let coordinator = GameCoordinator(mode: .arcade)
        var soundEvents: [GameplaySoundEvent] = []
        coordinator.onSoundEvent = { soundEvents.append($0) }
        coordinator.startNewRun()

        var now = ProcessInfo.processInfo.systemUptime * 1_000 + 1_000
        for _ in 0..<GameConfiguration.standard.twoByTwoStartsAtHits {
            coordinator.gameScene(coordinator.scene, requestsRoundActivationAt: now)
            let target = try XCTUnwrap(coordinator.snapshot.targetIndex)
            coordinator.gameScene(
                coordinator.scene,
                didTapCell: target,
                normalizedLocation: CGPoint(x: 0.5, y: 0.5),
                inputAt: now + 100,
                handledAt: now + 100
            )
            now += 1_000
        }

        coordinator.gameScene(coordinator.scene, requestsRoundActivationAt: now)
        XCTAssertEqual(coordinator.snapshot.difficulty.gridDimension, 2)
        let activeTarget = try XCTUnwrap(coordinator.snapshot.targetIndex)
        let livesBefore = coordinator.snapshot.lives

        coordinator.scene.handleBoardTouch(
            at: CGPoint(x: 160, y: 160),
            inputAt: now + 200,
            handledAt: now + 200
        )

        XCTAssertEqual(coordinator.feedback, "Missed")
        XCTAssertEqual(coordinator.snapshot.lives, livesBefore - 1)
        XCTAssertEqual(soundEvents.last, .lifeLoss)
        let miss = try XCTUnwrap(coordinator.proofEvents().last)
        XCTAssertEqual(miss.first, 2)
        XCTAssertNotEqual(miss[4], activeTarget)
        XCTAssertTrue((0..<4).contains(miss[4]))
        coordinator.stop()
    }

    func testEveryAcceptedHitPublishesRoundedTwoLineTapFeedbackData() {
        let godlike = hitFeedback(reactionMilliseconds: 249.4)
        XCTAssertEqual(godlike?.rating, .godlike)
        XCTAssertEqual(godlike?.milliseconds, 249)

        let perfect = hitFeedback(reactionMilliseconds: 300.4)
        XCTAssertEqual(perfect?.rating, .perfect)
        XCTAssertEqual(perfect?.milliseconds, 300)

        XCTAssertEqual(hitFeedback(reactionMilliseconds: 375)?.rating, .great)
        let good = hitFeedback(reactionMilliseconds: 500)
        XCTAssertEqual(good?.rating, .good)
        XCTAssertGreaterThan(good?.pointsAwarded ?? 0, 0)
        XCTAssertEqual(good?.normalizedLocation, CGPoint(x: 0.25, y: 0.75))
    }

    func testDeadlineExpiryPublishesTheSameTargetVisibilityAsSpriteKit() throws {
        let coordinator = GameCoordinator(mode: .arcade)
        coordinator.startNewRun()
        let activeAt = ProcessInfo.processInfo.systemUptime * 1_000 + 1_000
        coordinator.gameScene(coordinator.scene, requestsRoundActivationAt: activeAt)
        let responseWindow = coordinator.snapshot.difficulty.responseWindowMilliseconds
        let deadline = activeAt + Double(responseWindow)

        coordinator.gameScene(coordinator.scene, didAdvanceTo: deadline)
        XCTAssertTrue(coordinator.isRoundPresentationExpired)
        coordinator.gameScene(coordinator.scene, didAdvanceTo: deadline + 1)
        XCTAssertTrue(coordinator.isRoundPresentationExpired)
        coordinator.gameScene(coordinator.scene, didAdvanceTo: deadline + 2)

        XCTAssertFalse(coordinator.isRoundPresentationExpired)
        XCTAssertEqual(coordinator.feedback, "Too slow")
        coordinator.stop()
    }

    func testMissedRecoveryDoesNotReintroduceGetReadyOrRestartLifecycle() {
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
        XCTAssertEqual(coordinator.feedback, "Missed")
        XCTAssertEqual(soundEvents, [.lifeLoss])
        XCTAssertEqual(coordinator.snapshot.lives, 2)

        coordinator.gameScene(coordinator.scene, requestsRoundActivationAt: now + 2_000)
        XCTAssertTrue(coordinator.feedback.hasPrefix("Tap "))
        XCTAssertEqual(events, [.started])
        coordinator.stop()
    }

    func testEmptyAndWrongTapsShareMissedCopyWhileLateKeepsTooSlow() {
        XCTAssertEqual(GameplayMissPresentation.copy(for: nil), "Missed")
        XCTAssertEqual(GameplayMissPresentation.copy(for: "empty"), "Missed")
        XCTAssertEqual(GameplayMissPresentation.copy(for: "wrong"), "Missed")
        XCTAssertEqual(GameplayMissPresentation.copy(for: "late"), "Too slow")
    }

    private func hitFeedback(reactionMilliseconds: Double) -> GameplayHitFeedbackEvent? {
        let coordinator = GameCoordinator(mode: .arcade)
        coordinator.startNewRun()
        let activeAt = ProcessInfo.processInfo.systemUptime * 1_000 + 1_000
        coordinator.gameScene(coordinator.scene, requestsRoundActivationAt: activeAt)
        coordinator.gameScene(
            coordinator.scene,
            didTapCell: 0,
            normalizedLocation: CGPoint(x: 0.25, y: 0.75),
            inputAt: activeAt + reactionMilliseconds,
            handledAt: activeAt + reactionMilliseconds
        )
        coordinator.stop()
        return coordinator.hitFeedbackEvent
    }

    private func assertColor(
        _ actual: UIColor,
        equals expected: UIColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var actualRed: CGFloat = 0
        var actualGreen: CGFloat = 0
        var actualBlue: CGFloat = 0
        var actualAlpha: CGFloat = 0
        var expectedRed: CGFloat = 0
        var expectedGreen: CGFloat = 0
        var expectedBlue: CGFloat = 0
        var expectedAlpha: CGFloat = 0
        XCTAssertTrue(
            actual.getRed(
                &actualRed,
                green: &actualGreen,
                blue: &actualBlue,
                alpha: &actualAlpha
            ),
            file: file,
            line: line
        )
        XCTAssertTrue(
            expected.getRed(
                &expectedRed,
                green: &expectedGreen,
                blue: &expectedBlue,
                alpha: &expectedAlpha
            ),
            file: file,
            line: line
        )
        for (actualComponent, expectedComponent) in zip(
            [actualRed, actualGreen, actualBlue, actualAlpha],
            [expectedRed, expectedGreen, expectedBlue, expectedAlpha]
        ) {
            XCTAssertEqual(actualComponent, expectedComponent, accuracy: 0.001, file: file, line: line)
        }
    }
}
