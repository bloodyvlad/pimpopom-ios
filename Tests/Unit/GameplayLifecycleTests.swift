import PimPoPomCore
import SpriteKit
import XCTest

@testable import PimPoPom

@MainActor
final class GameplayLifecycleTests: XCTestCase {
    func testArcadeAccessibilityCellsKeepIdentityAndRefreshContentAndGeometry() throws {
        let view = ArcadeSKView(frame: CGRect(x: 0, y: 0, width: 380, height: 380))
        view.renderer.presentScene(GameScene())
        view.boardState = ArcadeBoardAccessibilityState(
            dimension: 2, cells: Array(repeating: Cell(), count: 4),
            pickups: [ArcadePickup(id: 1, kind: .heart, cellIndex: 0, visibleAt: 0, expiresAt: 3_000)],
            roundPresentationExpired: false, enabled: true)
        view.refreshAccessibility()
        let initial = try XCTUnwrap(view.accessibilityElements as? [UIAccessibilityElement])
        XCTAssertEqual(initial.count, 4)
        XCTAssertEqual(initial[0].accessibilityLabel, "Heart, restores one life, cell 1")
        let initialFrame = initial[0].accessibilityFrameInContainerSpace
        XCTAssertGreaterThan(initialFrame.width, 0)

        view.boardState = ArcadeBoardAccessibilityState(
            dimension: 2, cells: Array(repeating: Cell(), count: 4),
            pickups: [ArcadePickup(id: 2, kind: .clock, cellIndex: 1, visibleAt: 0, expiresAt: 3_000)],
            roundPresentationExpired: false, enabled: false)
        view.refreshAccessibility()
        let refreshed = try XCTUnwrap(view.accessibilityElements as? [UIAccessibilityElement])
        for index in initial.indices { XCTAssertTrue(initial[index] === refreshed[index]) }
        XCTAssertEqual(refreshed[0].accessibilityLabel, "Inactive cell 1")
        XCTAssertEqual(refreshed[1].accessibilityLabel, "Clock, slows pace by 30 percent, cell 2")
        XCTAssertTrue(refreshed[1].accessibilityTraits.contains(.notEnabled))
        XCTAssertFalse(refreshed[1].accessibilityActivate())

        view.boardState = ArcadeBoardAccessibilityState(
            dimension: 4, cells: Array(repeating: Cell(), count: 16), pickups: [],
            roundPresentationExpired: false, enabled: true)
        view.refreshAccessibility()
        let expanded = try XCTUnwrap(view.accessibilityElements as? [UIAccessibilityElement])
        XCTAssertEqual(expanded.count, 16)
        XCTAssertTrue(initial[0] === expanded[0])
        XCTAssertLessThan(expanded[0].accessibilityFrameInContainerSpace.width, initialFrame.width)
        XCTAssertFalse(expanded[0].accessibilityTraits.contains(.notEnabled))
        view.boardState = ArcadeBoardAccessibilityState(
            dimension: 1, cells: [Cell()], pickups: [], roundPresentationExpired: false, enabled: true)
        view.refreshAccessibility()
        XCTAssertEqual(view.accessibilityElements?.count, 1)
    }

    func testStoppedRunCannotAdvanceOrAcceptInputAndRestartResumes() throws {
        let engine = GameEngine(ruleset: .v4, random: { 0 })
        let coordinator = GameCoordinator(mode: .arcade, engine: engine)
        defer { coordinator.stop() }
        coordinator.startNewRun()
        try advanceToTwoByTwo(coordinator, base: try XCTUnwrap(engine.startedAt) + 1_000)
        let opportunity = try XCTUnwrap(engine.nextPickupOpportunityAt)
        coordinator.gameScene(coordinator.scene, requestsRoundActivationAt: opportunity - 100)
        coordinator.stop()
        let proof = coordinator.proofEvents()
        let snapshot = coordinator.snapshot
        coordinator.gameScene(coordinator.scene, didAdvanceTo: opportunity)
        coordinator.gameScene(coordinator.scene, requestsDecoyActivationAt: opportunity)
        coordinator.gameScene(coordinator.scene, requestsRoundActivationAt: opportunity)
        coordinator.gameScene(
            coordinator.scene, didTapCell: try XCTUnwrap(engine.targetIndex), normalizedLocation: .zero,
            inputAt: opportunity, handledAt: opportunity)
        for frame in 0..<4 {
            coordinator.gameScene(coordinator.scene, didAdvanceTo: opportunity + 10_000 + Double(frame) * 17)
        }
        XCTAssertEqual(coordinator.proofEvents(), proof)
        XCTAssertEqual(coordinator.snapshot, snapshot)
        XCTAssertTrue(engine.activePickups.isEmpty)
        XCTAssertFalse(coordinator.isFinished)
        coordinator.startNewRun()
        let nextStart = try XCTUnwrap(engine.startedAt)
        try advanceToTwoByTwo(coordinator, base: nextStart + 1_000)
        coordinator.gameScene(coordinator.scene, didAdvanceTo: try XCTUnwrap(engine.nextPickupOpportunityAt))
        XCTAssertEqual(coordinator.snapshot.activePickups.count, 1)
    }

    func testDelayedHeartContactUsesOriginalGridAcrossFourByFourExpansion() throws {
        let engine = GameEngine(ruleset: .v4, random: { 0 })
        let coordinator = GameCoordinator(mode: .arcade, engine: engine)
        defer { coordinator.stop() }
        coordinator.startNewRun()
        let base = try XCTUnwrap(engine.startedAt)
        try advanceToTwoByTwo(coordinator, base: base + 1_000)
        coordinator.gameScene(coordinator.scene, didAdvanceTo: base + 39_900)
        let heart = try XCTUnwrap(engine.activePickups.first)
        XCTAssertEqual(coordinator.snapshot.difficulty.gridDimension, 2)
        let oldContact = try XCTUnwrap(
            coordinator.scene.tapPoint(forCellAt: heart.cellIndex, horizontalFraction: 0.75, verticalFraction: 0.75))
        coordinator.scene.recordSharedBoardPresentation(at: base + 39_900)
        coordinator.gameScene(coordinator.scene, requestsRoundActivationAt: base + 40_001)
        XCTAssertEqual(coordinator.snapshot.difficulty.gridDimension, 4)
        coordinator.scene.recordSharedBoardPresentation(at: base + 40_001)
        let currentTarget = engine.targetIndex
        coordinator.scene.handleBoardTouch(at: oldContact, inputAt: base + 39_990, handledAt: base + 40_010)
        XCTAssertTrue(engine.activePickups.isEmpty)
        XCTAssertEqual(coordinator.proofEvents().last?.first, 8)
        XCTAssertEqual(engine.targetIndex, currentTarget)
        XCTAssertEqual(engine.misses, 0)
    }

    func testArcadeHeartRestoresLifeWithoutReplacingANewerTarget() throws {
        let engine = GameEngine(ruleset: .v4, random: { 0 })
        let coordinator = GameCoordinator(mode: .arcade, engine: engine)
        defer { coordinator.stop() }
        coordinator.startNewRun()
        let base = try XCTUnwrap(engine.startedAt)
        coordinator.gameScene(
            coordinator.scene, didTapCell: 0, normalizedLocation: .zero,
            inputAt: base + 100, handledAt: base + 100)
        XCTAssertEqual(engine.lives, 2)
        try advanceToTwoByTwo(coordinator, base: base + 2_000)
        let opportunity = try XCTUnwrap(engine.nextPickupOpportunityAt)
        coordinator.gameScene(coordinator.scene, didAdvanceTo: opportunity)
        let heart = try XCTUnwrap(coordinator.snapshot.activePickups.first)
        XCTAssertEqual(heart.kind, .heart)
        coordinator.gameScene(coordinator.scene, requestsRoundActivationAt: opportunity + 100)
        let target = engine.targetIndex
        let hits = engine.hits
        coordinator.gameScene(
            coordinator.scene, didTapCell: heart.cellIndex, normalizedLocation: .zero,
            inputAt: opportunity + 50, handledAt: opportunity + 150)
        XCTAssertEqual(engine.lives, 3)
        XCTAssertEqual(engine.targetIndex, target)
        XCTAssertEqual(engine.hits, hits)
        XCTAssertEqual(coordinator.proofEvents().last?.first, 8)
        XCTAssertNil(coordinator.scene.childNode(withName: "cell-heart-\(heart.cellIndex)"))
    }

    func testArcadeClockPreservesActiveWindowAndRestartClearsItsEffect() throws {
        let engine = GameEngine(ruleset: .v4, random: { 0.99 })
        let coordinator = GameCoordinator(mode: .arcade, engine: engine)
        defer { coordinator.stop() }
        coordinator.startNewRun()
        let base = try XCTUnwrap(engine.startedAt)
        try advanceToTwoByTwo(coordinator, base: base + 1_000)
        let opportunity = try XCTUnwrap(engine.nextPickupOpportunityAt)
        coordinator.gameScene(coordinator.scene, didAdvanceTo: opportunity)
        let clock = try XCTUnwrap(coordinator.snapshot.activePickups.first)
        XCTAssertEqual(clock.kind, .clock)
        XCTAssertNotNil(coordinator.scene.childNode(withName: "cell-clock-\(clock.cellIndex)"))
        coordinator.gameScene(coordinator.scene, requestsRoundActivationAt: opportunity + 100)
        let window = engine.roundDifficulty?.responseWindowMilliseconds
        coordinator.gameScene(
            coordinator.scene, didTapCell: clock.cellIndex, normalizedLocation: .zero,
            inputAt: opportunity + 150, handledAt: opportunity + 150)
        XCTAssertEqual(engine.roundDifficulty?.responseWindowMilliseconds, window)
        XCTAssertEqual(coordinator.snapshot.speedRate, 0.7, accuracy: 0.0001)
        XCTAssertEqual(engine.speedRate(now: opportunity + 5_150), 0.85, accuracy: 0.0001)
        XCTAssertEqual(engine.speedRate(now: opportunity + 10_150), 1, accuracy: 0.0001)
        coordinator.startNewRun()
        XCTAssertEqual(coordinator.snapshot.speedRate, 1)
        XCTAssertTrue(coordinator.snapshot.activePickups.isEmpty)
    }

    func testPickupExpiryHidesImmediatelyButDrainsPreDeadlineContact() throws {
        let engine = GameEngine(ruleset: .v4, random: { 0 })
        let coordinator = GameCoordinator(mode: .arcade, engine: engine)
        defer { coordinator.stop() }
        coordinator.startNewRun()
        try advanceToTwoByTwo(coordinator, base: try XCTUnwrap(engine.startedAt) + 1_000)
        coordinator.gameScene(coordinator.scene, didAdvanceTo: try XCTUnwrap(engine.nextPickupOpportunityAt))
        let heart = try XCTUnwrap(engine.activePickups.first)
        coordinator.gameScene(coordinator.scene, didAdvanceTo: heart.expiresAt)
        XCTAssertNil(coordinator.scene.childNode(withName: "cell-heart-\(heart.cellIndex)"))
        XCTAssertEqual(engine.activePickups.count, 1)
        coordinator.gameScene(
            coordinator.scene, didTapCell: heart.cellIndex, normalizedLocation: .zero,
            inputAt: heart.expiresAt - 1, handledAt: heart.expiresAt + 10)
        XCTAssertTrue(engine.activePickups.isEmpty)
        XCTAssertEqual(coordinator.proofEvents().last?.first, 8)
        XCTAssertEqual(engine.misses, 0)
    }

    private func advanceToTwoByTwo(_ coordinator: GameCoordinator, base: Double) throws {
        for offset in 0..<4 {
            let now = base + Double(offset) * 1_000
            coordinator.gameScene(coordinator.scene, requestsRoundActivationAt: now)
            coordinator.gameScene(
                coordinator.scene, didTapCell: try XCTUnwrap(coordinator.snapshot.targetIndex),
                normalizedLocation: .zero, inputAt: now + 100, handledAt: now + 100)
        }
    }

    func testSharedBoardHeartUsesCachedHUDArtworkInEveryTheme() throws {
        for theme in ThemePalette.all {
            let scene = GameScene()
            scene.applyTheme(theme.id)
            scene.applySharedBoard(dimension: 2, cells: Array(repeating: Cell(), count: 4), hearts: [1])
            let heart = try XCTUnwrap(scene.childNode(withName: "cell-heart-1") as? SKSpriteNode)
            XCTAssertTrue(heart.texture === GameplayPickupTextureFactory.texture(symbol: .heart, theme: theme))
            XCTAssertEqual(heart.texture?.filteringMode, theme.isPixel ? .nearest : .linear)
            XCTAssertGreaterThan(try XCTUnwrap(heart.texture).size().width, 0)
            XCTAssertNil(scene.childNode(withName: "cell-clock-1"))
            scene.applySharedBoard(dimension: 2, cells: Array(repeating: Cell(), count: 4))
            XCTAssertNil(scene.childNode(withName: "cell-heart-1"))
        }
    }

    func testPickupTexturesAreThemeSpecificAndPreparedOnce() {
        for theme in ThemePalette.all {
            GameplayPickupTextureFactory.prewarm(theme: theme)
            for symbol in GameplayPickupSymbol.allCases {
                let first = GameplayPickupTextureFactory.texture(symbol: symbol, theme: theme)
                let second = GameplayPickupTextureFactory.texture(symbol: symbol, theme: theme)
                XCTAssertTrue(first === second)
                XCTAssertEqual(first.size(), CGSize(width: 84, height: 84))
            }
        }
        XCTAssertFalse(
            GameplayPickupTextureFactory.texture(symbol: .heart, theme: .classic)
                === GameplayPickupTextureFactory.texture(symbol: .heart, theme: .resolve("pixel")))
    }

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

    func testEveryStartedRunReceivesADistinctCompletionIdentity() {
        let coordinator = GameCoordinator(mode: .zen)

        coordinator.startNewRun()
        let first = coordinator.gameplaySessionID
        coordinator.endZenRun()

        coordinator.startNewRun()
        let second = coordinator.gameplaySessionID
        coordinator.endZenRun()

        XCTAssertNotEqual(first, second)
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

    func testScreenshotAutoplayPointStaysInsideCellWithoutUsingItsCenter() throws {
        let engine = GameEngine(random: { 0 })
        _ = engine.start(now: 0, mode: .arcade)
        let active = engine.activateRound(now: 1_000).snapshot
        let scene = GameScene()
        scene.apply(active)

        let point = try XCTUnwrap(
            scene.tapPoint(
                forCellAt: 0,
                horizontalFraction: 0.23,
                verticalFraction: 0.77
            )
        )
        let cellFrame = GameBoardLayout(size: scene.size, dimension: 1)
            .cellFrame(at: 0, yAxis: .up)

        XCTAssertTrue(cellFrame.contains(point))
        XCTAssertNotEqual(point.x, cellFrame.midX, accuracy: 0.001)
        XCTAssertNotEqual(point.y, cellFrame.midY, accuracy: 0.001)
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

    func testMissedRecoveryIgnoresRapidBoardTapsWithoutDrainingLives() {
        let coordinator = GameCoordinator(mode: .arcade)
        var soundEvents: [GameplaySoundEvent] = []
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
        let proofAfterAcceptedMiss = coordinator.proofEvents()

        for offset in [10.0, 20.0, 30.0] {
            coordinator.gameScene(
                coordinator.scene,
                didTapCell: 0,
                normalizedLocation: CGPoint(x: 0.5, y: 0.5),
                inputAt: now + offset,
                handledAt: now + offset
            )
        }

        XCTAssertEqual(coordinator.snapshot.lives, 2)
        XCTAssertEqual(coordinator.snapshot.misses, 1)
        XCTAssertEqual(soundEvents, [.lifeLoss])
        XCTAssertEqual(coordinator.proofEvents(), proofAfterAcceptedMiss)
        XCTAssertEqual(coordinator.feedback, "Missed")
        coordinator.stop()
    }

    func testBoardInteractionIsDisabledWhilePreparingOrRecovering() {
        XCTAssertFalse(
            GameplayBoardInteraction.allowsHitTesting(
                preparing: true,
                recoveryRemainingMilliseconds: 0
            )
        )
        XCTAssertFalse(
            GameplayBoardInteraction.allowsHitTesting(
                preparing: false,
                recoveryRemainingMilliseconds: 1
            )
        )
        XCTAssertTrue(
            GameplayBoardInteraction.allowsHitTesting(
                preparing: false,
                recoveryRemainingMilliseconds: 0
            )
        )
    }

    func testCoordinatorKeepsDecoyAcrossHitAndTargetUntilIndependentExpiry() throws {
        let coordinator = GameCoordinator(mode: .arcade)
        coordinator.startNewRun()
        let base = ProcessInfo.processInfo.systemUptime * 1_000

        coordinator.gameScene(
            coordinator.scene,
            requestsRoundActivationAt: base + 70_000
        )
        let firstTarget = try XCTUnwrap(coordinator.snapshot.targetIndex)
        coordinator.gameScene(
            coordinator.scene,
            requestsDecoyActivationAt: base + 70_050
        )
        let decoy = try XCTUnwrap(coordinator.snapshot.activeDecoys.first)
        coordinator.gameScene(
            coordinator.scene,
            didTapCell: firstTarget,
            normalizedLocation: CGPoint(x: 0.5, y: 0.5),
            inputAt: base + 70_100,
            handledAt: base + 70_100
        )

        XCTAssertEqual(coordinator.snapshot.activeDecoys, [decoy])
        XCTAssertNotEqual(coordinator.snapshot.playerColorIndex, decoy.colorIndex)

        coordinator.gameScene(
            coordinator.scene,
            requestsRoundActivationAt: base + 70_200
        )
        XCTAssertEqual(coordinator.snapshot.activeDecoys, [decoy])
        XCTAssertNotEqual(coordinator.snapshot.targetIndex, decoy.cellIndex)

        coordinator.gameScene(
            coordinator.scene,
            didAdvanceTo: decoy.expiresAt
        )
        XCTAssertTrue(coordinator.snapshot.activeDecoys.isEmpty)
        XCTAssertEqual(coordinator.snapshot.dodges, 1)
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
