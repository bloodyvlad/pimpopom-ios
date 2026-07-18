import UIKit
import XCTest

@testable import PimPoPom

final class CosmeticsTests: XCTestCase {
    func testFallbackCatalogMatchesDeployedPrices() {
        XCTAssertEqual(
            CosmeticCatalog.themes,
            [
                CosmeticCatalogItem(id: "classic", name: "Default", priceCoins: 0),
                CosmeticCatalogItem(id: "disco", name: "Disco", priceCoins: 0),
                CosmeticCatalogItem(id: "light", name: "Light", priceCoins: 50),
                CosmeticCatalogItem(id: "pixel", name: "Pixel", priceCoins: 100),
            ]
        )
        XCTAssertEqual(
            CosmeticCatalog.pets,
            [
                CosmeticCatalogItem(id: "foka", name: "Foka", priceCoins: 10),
                CosmeticCatalogItem(id: "kesha", name: "Kesha", priceCoins: 20),
                CosmeticCatalogItem(id: "tauta", name: "Tauta", priceCoins: 50),
                CosmeticCatalogItem(id: "misha", name: "Misha", priceCoins: 100),
                CosmeticCatalogItem(id: "pancake", name: "Pancake", priceCoins: 500),
            ]
        )
    }

    func testThemeActionMatrix() {
        let owned: Set<String> = ["classic", "disco", "light"]
        XCTAssertEqual(
            CosmeticCatalog.themeAction(themeID: "classic", owned: owned, selectedID: "classic"),
            .selected
        )
        XCTAssertEqual(
            CosmeticCatalog.themeAction(themeID: "light", owned: owned, selectedID: "classic"),
            .select
        )
        XCTAssertEqual(
            CosmeticCatalog.themeAction(themeID: "pixel", owned: owned, selectedID: "classic"),
            .buy
        )
    }

    func testPetActionMatrix() {
        let owned: Set<String> = ["foka", "kesha"]
        XCTAssertEqual(
            CosmeticCatalog.petAction(
                petID: "tauta",
                owned: owned,
                selectedID: "foka",
                visible: true
            ),
            .buy
        )
        XCTAssertEqual(
            CosmeticCatalog.petAction(
                petID: "kesha",
                owned: owned,
                selectedID: "foka",
                visible: true
            ),
            .select
        )
        XCTAssertEqual(
            CosmeticCatalog.petAction(
                petID: "foka",
                owned: owned,
                selectedID: "foka",
                visible: true
            ),
            .hide
        )
        XCTAssertEqual(
            CosmeticCatalog.petAction(
                petID: "foka",
                owned: owned,
                selectedID: "foka",
                visible: false
            ),
            .show
        )
    }

    func testDisplayedPetUsesServerSpecialOverrideAndVisibility() {
        XCTAssertNil(CosmeticCatalog.displayedPetID(profile: nil))
        XCTAssertNil(
            CosmeticCatalog.displayedPetID(
                profile: profile(selectedPetID: "foka", visible: false, specialPetID: nil)
            )
        )
        XCTAssertEqual(
            CosmeticCatalog.displayedPetID(
                profile: profile(selectedPetID: "foka", visible: true, specialPetID: nil)
            ),
            "foka"
        )
        XCTAssertEqual(
            CosmeticCatalog.displayedPetID(
                profile: profile(selectedPetID: "foka", visible: false, specialPetID: "mitsuri")
            ),
            "mitsuri"
        )
        XCTAssertEqual(
            CosmeticCatalog.displayedPetID(
                profile: profile(
                    selectedPetID: nil,
                    visible: true,
                    specialPetID: nil,
                    equippedPetID: "foka"
                )
            ),
            "foka"
        )
    }

    func testThemeAndAudioManifestsResolveKnownIDsAndFallback() {
        XCTAssertEqual(ThemePalette.resolve("light").tileColors[0], "#00b8d9")
        XCTAssertEqual(ThemePalette.resolve("light").accent, "#087d9f")
        XCTAssertEqual(ThemePalette.resolve("unknown"), .classic)

        let pixelAudio = ThemeAudioManifest.resolve("pixel")
        XCTAssertEqual(pixelAudio.menuFile, "audio-pixel-menu.m4a")
        XCTAssertEqual(pixelAudio.gameplayFile, "audio-pixel-run.m4a")
        XCTAssertEqual(pixelAudio.toneBankFile, "audio-pixel-tones.wav")
        XCTAssertEqual(ThemeAudioManifest.resolve("unknown").themeID, "classic")
    }

    func testWebMenuMetricsMatchTheReviewedCompactContract() {
        XCTAssertEqual(WebMenuMetrics.maximumPanelWidth, 460)
        XCTAssertEqual(WebMenuMetrics.compactOuterInset, 10)
        XCTAssertEqual(WebMenuMetrics.panelPadding, 22)
        XCTAssertEqual(WebMenuMetrics.utilityTarget, 44)
        XCTAssertEqual(WebMenuMetrics.headerHeight, 48)
        XCTAssertEqual(WebMenuMetrics.hintHeight, 112)
        XCTAssertEqual(WebMenuMetrics.modeHeight, 56)
        XCTAssertEqual(WebMenuMetrics.standardControlHeight, 51)
        XCTAssertEqual(WebMenuMetrics.featureControlHeight, 48)
        XCTAssertEqual(WebMenuMetrics.featureIconLeadingInset, 19)
        XCTAssertEqual(WebMenuMetrics.actionGap, 9)
        XCTAssertEqual(WebMenuMetrics.pairedGap, 8)
        XCTAssertEqual(WebMenuMetrics.menuPetHorizontalShiftFraction, 0.15)
        XCTAssertEqual(WebMenuMetrics.motivationHorizontalShiftFraction, 0.10)
        XCTAssertEqual(WebMenuMetrics.motivationScale, 1.15)
    }

    func testThemeVisualTokensMatchTheReviewedWebContract() {
        XCTAssertEqual(ThemePalette.classic.backgroundTop, "#101326")
        XCTAssertEqual(ThemePalette.classic.backgroundBottom, "#080a12")
        XCTAssertEqual(ThemePalette.classic.achievementsAccent, "#ffd84d")
        XCTAssertEqual(ThemePalette.classic.petsAccent, "#ff79ad")
        XCTAssertEqual(ThemePalette.classic.themesAccent, "#63efff")

        XCTAssertEqual(ThemePalette.disco.backgroundTop, "#030404")
        XCTAssertEqual(ThemePalette.disco.surface, "#0c0f16")
        XCTAssertEqual(ThemePalette.disco.board, "#07090d")
        XCTAssertEqual(ThemePalette.disco.idleCell, DiscoThemeTokens.idleCellHex)
        XCTAssertEqual(ThemePalette.disco.tileColors, DiscoThemeTokens.activeCellHexes)
        XCTAssertEqual(DiscoThemeTokens.idleCellHex, "#0d0f12")
        XCTAssertEqual(DiscoThemeTokens.cellBorderHex, "#4a5056")
        XCTAssertEqual(DiscoThemeTokens.activeBorderHex, "#d9dde0")
        XCTAssertEqual(ThemePreviewStyle.discoBackgroundHex, "#080909")
        XCTAssertEqual(ThemePreviewStyle.aspectRatio, 1.45, accuracy: 0.001)
        XCTAssertEqual(ThemePalette.light.backgroundTop, "#bce9ff")
        XCTAssertEqual(ThemePalette.light.backgroundBottom, "#eaf8ff")
        XCTAssertEqual(ThemePalette.light.foreground, "#17263b")
        XCTAssertEqual(ThemePalette.light.muted, "#5e7187")
        XCTAssertEqual(ThemePalette.light.board, "#ffffff")
        XCTAssertEqual(ThemePalette.light.idleCell, "#f5fbff")
        XCTAssertEqual(ThemePalette.pixel.backgroundTop, "#1a1635")
        XCTAssertEqual(ThemePalette.pixel.backgroundBottom, "#0c0c1d")
        XCTAssertTrue(ThemePalette.pixel.isPixel)
        XCTAssertEqual(ThemePalette.pixel.cornerRadius, 3)
        XCTAssertEqual(ThemePalette.pixel.resolvedFontSize(10), 12.5, accuracy: 0.001)
        XCTAssertEqual(ThemePalette.classic.resolvedFontSize(10), 10, accuracy: 0.001)
        XCTAssertEqual(
            PimPoPomBrandColors.pimGradient,
            ["#16b887", "#39c85f", "#86bd3c"]
        )
        XCTAssertEqual(
            GameCellVisualMetrics.cornerRadius(theme: .pixel, side: 40),
            0
        )
        XCTAssertEqual(
            GameCellVisualMetrics.glyphBoxSide(side: 100),
            30,
            accuracy: 0.001
        )
        XCTAssertEqual(
            GameCellVisualMetrics.cornerRadius(theme: .classic, side: 40),
            4
        )
        XCTAssertEqual(
            GameCellVisualMetrics.glyphBoxSide(side: 40),
            14,
            accuracy: 0.001
        )
        XCTAssertEqual(GameCellVisualMetrics.targetBorderWidth, 3)
        XCTAssertEqual(GameCellVisualMetrics.activeBorderWidth, 2)
        XCTAssertEqual(GameHUDMetrics.colorHeroOutlineWidth, 3)
    }

    func testPixelFontAndDiscoTexturesAreBundled() throws {
        XCTAssertNotNil(UIFont(name: "Jersey10-Regular", size: 16))
        for asset in [
            "disco-concrete-lights",
            "disco-concrete",
            "disco-tile-overlay",
        ] {
            let image = try bundledImage(named: asset)
            XCTAssertEqual(image.cgImage?.width, 1_024, asset)
            XCTAssertEqual(image.cgImage?.height, 1_024, asset)
        }
    }

    func testEveryGlyphUsesOneCanonicalBoxInSmoothAndPixelStyles() throws {
        for side in [CGFloat(14), 24, 90] {
            let target = CGRect(x: 7, y: 11, width: side, height: side)
            for style in [GameGlyphStyle.smooth, .pixel] {
                for yAxis in [GameGlyphYAxis.down, .up] {
                    for glyph in GameGlyphGeometry.supportedGlyphs {
                        let path = try XCTUnwrap(
                            GameGlyphGeometry.path(
                                for: glyph,
                                in: target,
                                style: style,
                                yAxis: yAxis
                            )
                        )
                        let bounds = path.boundingBoxOfPath
                        XCTAssertEqual(bounds.minX, target.minX, accuracy: 0.001, glyph)
                        XCTAssertEqual(bounds.minY, target.minY, accuracy: 0.001, glyph)
                        XCTAssertEqual(bounds.width, target.width, accuracy: 0.001, glyph)
                        XCTAssertEqual(bounds.height, target.height, accuracy: 0.001, glyph)
                    }
                }
            }
        }
    }

    func testSmoothCrossIsOneSolidShapeWithNoCenterHole() throws {
        let target = CGRect(x: 0, y: 0, width: 100, height: 100)
        for yAxis in [GameGlyphYAxis.down, .up] {
            let path = try XCTUnwrap(
                GameGlyphGeometry.path(
                    for: "✚",
                    in: target,
                    style: .smooth,
                    yAxis: yAxis
                )
            )
            for rule in [CGPathFillRule.winding, .evenOdd] {
                XCTAssertTrue(path.contains(CGPoint(x: 50, y: 50), using: rule))
                XCTAssertTrue(path.contains(CGPoint(x: 50, y: 10), using: rule))
                XCTAssertTrue(path.contains(CGPoint(x: 10, y: 50), using: rule))
                XCTAssertFalse(path.contains(CGPoint(x: 15, y: 15), using: rule))
            }
        }
    }

    func testThemeCellEffectsResolveIdenticallyForBoardAndPreviews() {
        let discoIdle = GameCellSurfaceEffects.resolve(theme: .disco, isLit: false, seed: 2)
        let discoActive = GameCellSurfaceEffects.resolve(theme: .disco, isLit: true, seed: 2)
        XCTAssertFalse(discoIdle.discoBacklight)
        XCTAssertTrue(discoActive.discoBacklight)
        XCTAssertTrue(discoIdle.requiresBlackCornerUnderlay)
        XCTAssertTrue(discoActive.requiresBlackCornerUnderlay)
        XCTAssertEqual(discoActive.glyphStyle, .smooth)

        for isLit in [false, true] {
            XCTAssertTrue(
                GameCellSurfaceEffects.resolve(theme: .light, isLit: isLit, seed: 3)
                    .lightGlass
            )
            let pixel = GameCellSurfaceEffects.resolve(
                theme: .pixel,
                isLit: isLit,
                seed: 4
            )
            XCTAssertTrue(pixel.pixelNoise)
            XCTAssertEqual(pixel.glyphStyle, .pixel)
        }
        XCTAssertEqual(
            PixelNoisePattern.samples(seed: 8),
            PixelNoisePattern.samples(seed: 8)
        )
        XCTAssertNotEqual(
            PixelNoisePattern.samples(seed: 8),
            PixelNoisePattern.samples(seed: 9)
        )
        let samples = PixelNoisePattern.samples(seed: 8)
        XCTAssertEqual(samples.count, 32)
        XCTAssertEqual(Set(samples.map { "\($0.x):\($0.y)" }).count, samples.count)
        XCTAssertEqual(samples.filter(\.isLight).count, 24)
        XCTAssertEqual(samples.filter { !$0.isLight }.count, 8)
        XCTAssertEqual(PixelNoisePattern.squareSide(for: 128), 4)
        XCTAssertEqual(PixelNoisePattern.squareSide(for: 40), 1)
        XCTAssertGreaterThanOrEqual(GameCellEffectTokens.pixelLightNoiseOpacity, 0.12)
        XCTAssertGreaterThan(
            GameCellEffectTokens.pixelLightNoiseOpacity,
            GameCellEffectTokens.pixelDarkNoiseOpacity
        )
        XCTAssertLessThanOrEqual(GameCellEffectTokens.discoCenterWhiteOpacity, 0.10)
        XCTAssertLessThanOrEqual(GameCellEffectTokens.discoMidpointWhiteOpacity, 0.03)
        XCTAssertGreaterThanOrEqual(GameCellEffectTokens.discoColorBoostOpacity, 0.35)
        XCTAssertEqual(GameCellEffectTokens.discoGlowFillOpacity, 0.34, accuracy: 0.001)
        XCTAssertEqual(GameCellEffectTokens.discoPrimaryGlowOpacity, 1, accuracy: 0.001)
        XCTAssertEqual(GameCellEffectTokens.discoSecondaryGlowOpacity, 0.28, accuracy: 0.001)
        XCTAssertEqual(GameCellEffectTokens.discoGlowWidthScale, 0.22, accuracy: 0.001)
        XCTAssertEqual(GameCellEffectTokens.discoHaloClipScale, 0.012, accuracy: 0.001)
        XCTAssertGreaterThan(GameCellEffectTokens.lightInnerStrokeOpacity, 0.8)
    }

    func testDiscoActiveColorsStayVividInsteadOfBeingWhitened() {
        XCTAssertEqual(
            DiscoThemeTokens.activeCellHexes,
            ["#00ffff", "#ffe600", "#ff008c", "#61ff00", "#ff5a00", "#7b00ff"]
        )
        for hex in DiscoThemeTokens.activeCellHexes {
            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            var alpha: CGFloat = 0
            XCTAssertTrue(
                UIColor(hexString: hex).getHue(
                    &hue,
                    saturation: &saturation,
                    brightness: &brightness,
                    alpha: &alpha
                ),
                hex
            )
            XCTAssertGreaterThanOrEqual(saturation, 0.90, hex)
            XCTAssertGreaterThanOrEqual(brightness, 0.95, hex)
            XCTAssertEqual(alpha, 1, accuracy: 0.001, hex)
        }
    }

    func testAchievementFallbackCatalogMatchesTheServerStableIDsAndRewards() {
        XCTAssertEqual(
            AchievementCatalog.definitions.map(\.id),
            [
                "complete_arcade",
                "godlike_speed",
                "collect_5_coins",
                "score_over_100k",
                "buy_a_pet",
            ]
        )
        XCTAssertEqual(AchievementCatalog.definitions.map(\.rewardCoins), [1, 1, 5, 5, 10])

        let signedOut = AchievementCatalog.lockedResponse(authenticated: false)
        XCTAssertFalse(signedOut.authenticated)
        XCTAssertEqual(signedOut.totalCount, 5)
        XCTAssertEqual(signedOut.claimedCount, 0)
        XCTAssertEqual(signedOut.claimableCount, 0)
        XCTAssertTrue(signedOut.achievements.allSatisfy { $0.state == .locked })
    }

    func testUITestAudioSuppressionPolicyIsExplicit() {
        XCTAssertTrue(
            AudioOutputPolicy.isSuppressed(
                arguments: ["PimPoPom", "--uitesting"],
                environment: [:]
            )
        )
        XCTAssertTrue(
            AudioOutputPolicy.isSuppressed(
                arguments: ["PimPoPom"],
                environment: ["XCTestConfigurationFilePath": "/tmp/tests.xctestconfiguration"]
            )
        )
        XCTAssertFalse(AudioOutputPolicy.isSuppressed(arguments: ["PimPoPom"], environment: [:]))
    }

    func testPetPresentationIncludesApprovedPancakeReplacement() {
        let foka = PetPresentation.resolve("foka")
        XCTAssertEqual(foka.spriteAsset, "foka-sprite")
        XCTAssertFalse(foka.usesPlaceholderArt)

        let muse = PetPresentation.resolve("muse")
        XCTAssertEqual(muse.spriteAsset, "muse-sprite")
        XCTAssertEqual(muse.habitatAsset, "muse-floor")
        XCTAssertFalse(muse.usesPlaceholderArt)

        let pancake = PetPresentation.resolve("pancake")
        XCTAssertEqual(pancake.spriteAsset, "pancake-sprite")
        XCTAssertEqual(pancake.habitatAsset, "pancake-floor")
        XCTAssertFalse(pancake.usesPlaceholderArt)
    }

    func testShopPetGeometryMatchesOriginalPreviewScene() {
        let standard = PetArtworkGeometry.resolve(
            placement: .shop,
            petID: "misha",
            spriteSize: 64
        )
        XCTAssertEqual(standard.canvas, CGSize(width: 80, height: 80))
        XCTAssertEqual(standard.spriteOffset, CGSize(width: 8, height: -5))
        XCTAssertEqual(standard.habitatSize, CGSize(width: 64, height: 64))
        XCTAssertEqual(standard.habitatOffset, CGSize(width: 8, height: 48))

        let foka = PetArtworkGeometry.resolve(
            placement: .shop,
            petID: "foka",
            spriteSize: 64
        )
        XCTAssertEqual(foka.spriteOffset, CGSize(width: 8, height: -11))

        let kesha = PetArtworkGeometry.resolve(
            placement: .shop,
            petID: "kesha",
            spriteSize: 64
        )
        XCTAssertEqual(kesha.spriteOffset, CGSize(width: 8, height: -10))

        let pancake = PetArtworkGeometry.resolve(
            placement: .shop,
            petID: "pancake",
            spriteSize: 64
        )
        XCTAssertEqual(pancake.spriteOffset, CGSize(width: 8, height: 20))
    }

    func testMenuPetGeometryAppliesOnlyTheRequestedPerPetOffsets() {
        XCTAssertEqual(
            PetArtworkGeometry.resolve(placement: .menu, petID: "foka", spriteSize: 64)
                .spriteOffset.height,
            -9
        )
        for petID in ["misha", "tauta", "pancake"] {
            let expected: CGFloat =
                switch petID {
                case "misha": 1
                case "pancake": 41
                default: 6
                }
            XCTAssertEqual(
                PetArtworkGeometry.resolve(placement: .menu, petID: petID, spriteSize: 64)
                    .spriteOffset.height,
                expected,
                petID
            )
        }
    }

    func testGameplayPetOffsetsApplyTheRequestedSequentialMovesWithoutClippingSprites() {
        for petID in ["foka", "kesha", "tauta", "misha", "mitsuri", "muse"] {
            XCTAssertEqual(PetArtworkGeometry.gameplayViewVerticalOffset(petID: petID), -10)
        }
        XCTAssertEqual(PetArtworkGeometry.gameplayViewVerticalOffset(petID: "pancake"), 10)
    }

    func testPancakeLeaderboardOffsetMovesOnlyTheSpriteAndExpandsItsCanvas() {
        let geometry = PetArtworkGeometry.resolve(
            placement: .leaderboard,
            petID: "pancake",
            spriteSize: 36
        )
        XCTAssertEqual(geometry.spriteOffset, CGSize(width: 4, height: 16))
        XCTAssertEqual(geometry.habitatOffset, CGSize(width: 4, height: 27))
        XCTAssertGreaterThanOrEqual(
            geometry.canvas.height,
            geometry.spriteOffset.height + 36
        )
        XCTAssertEqual(
            PetArtworkGeometry.resolve(
                placement: .shop,
                petID: "pancake",
                spriteSize: 64
            ).spriteOffset.height,
            20
        )
        XCTAssertEqual(PetArtworkGeometry.gameplayViewVerticalOffset(petID: "pancake"), 10)
    }

    func testPetFacingUsesHorizontalScreenPercentageZones() {
        let width: CGFloat = 200
        let center: CGFloat = 100
        XCTAssertEqual(
            PetFacing.resolve(pointerX: center, petCenterX: center, interactionWidth: width),
            .front
        )
        XCTAssertEqual(
            PetFacing.resolve(pointerX: center + 0.5, petCenterX: center, interactionWidth: width),
            .front
        )
        XCTAssertEqual(
            PetFacing.resolve(pointerX: center + 0.51, petCenterX: center, interactionWidth: width),
            .halfRight
        )
        XCTAssertEqual(
            PetFacing.resolve(pointerX: center + 30, petCenterX: center, interactionWidth: width),
            .halfRight
        )
        XCTAssertEqual(
            PetFacing.resolve(pointerX: center - 30, petCenterX: center, interactionWidth: width),
            .halfLeft
        )
        XCTAssertEqual(
            PetFacing.resolve(
                pointerX: center + 30.01,
                petCenterX: center,
                interactionWidth: width
            ),
            .right
        )
        XCTAssertEqual(
            PetFacing.resolve(
                pointerX: center - 30.01,
                petCenterX: center,
                interactionWidth: width
            ),
            .left
        )
        XCTAssertEqual(
            PetFacing.resolve(
                pointerX: .nan,
                petCenterX: center,
                interactionWidth: width,
                fallback: .halfLeft
            ),
            .halfLeft
        )
    }

    func testSharedTapFollowUsesKnownGameplayLayoutWithoutMeasuredFrames() {
        XCTAssertEqual(
            PetTapFollow.resolveGameplay(
                normalizedPointerX: 0.05,
                screenWidth: 375,
                current: .front
            ),
            .left
        )
        XCTAssertEqual(
            PetTapFollow.resolveGameplay(
                normalizedPointerX: 0.48,
                screenWidth: 375,
                current: .left
            ),
            .halfRight
        )
        XCTAssertEqual(
            PetTapFollow.resolveGameplay(
                normalizedPointerX: 0.95,
                screenWidth: 375,
                current: .halfRight
            ),
            .right
        )
        XCTAssertEqual(
            PetTapFollow.resolveGameplay(
                normalizedPointerX: .nan,
                screenWidth: 0,
                current: .halfLeft
            ),
            .halfLeft
        )
    }

    func testMenuTapFollowUsesRenderedTrailingPetCenter() {
        let centerX = PetTapFollow.resolveMenuPetCenterX(
            screenWidth: 375,
            canvasWidth: 64,
            maximumPanelWidth: 460,
            horizontalPadding: 12,
            horizontalOffset: 10 - 375 * 0.15
        )

        XCTAssertEqual(centerX, 284.75, accuracy: 0.001)
        XCTAssertEqual(
            PetTapFollow.resolve(
                pointerX: 18.75,
                petCenterX: centerX,
                interactionWidth: 375,
                current: .right
            ),
            .left
        )
    }

    func testGameplayFeedbackUsesCenteredAnnouncementsAndHidesLegacyCopies() {
        XCTAssertEqual(GameplayAnnouncementPresentation.getReadyDuration, .seconds(1))
        for feedback in [
            "Tap Pink ■", "Godlike · 201 ms", "Perfect · 301 ms", "Hit · 250 ms",
            "Get ready", "Missed", "Too early", "Too slow", "Wrong cell",
        ] {
            XCTAssertTrue(GameplayFeedbackPresentation.isVisuallyHidden(feedback), feedback)
        }
        for feedback in ["Great · 401 ms", "Good · 501 ms", "Decoy dodged"] {
            XCTAssertFalse(GameplayFeedbackPresentation.isVisuallyHidden(feedback), feedback)
        }
        XCTAssertEqual(
            GameplayAnnouncementPresentation.resolve(
                showsGetReady: true,
                feedback: "Missed"
            ),
            .getReady
        )
        XCTAssertEqual(
            GameplayAnnouncementPresentation.resolve(
                showsGetReady: false,
                feedback: "Missed"
            ),
            .missed
        )
        XCTAssertEqual(
            GameplayAnnouncementPresentation.resolve(
                showsGetReady: false,
                feedback: "Too slow"
            ),
            .tooSlow
        )
        XCTAssertNil(
            GameplayAnnouncementPresentation.resolve(
                showsGetReady: false,
                feedback: "Wrong cell"
            )
        )
        XCTAssertGreaterThan(
            GameplayOverlayLayer.ratingStamp,
            GameplayOverlayLayer.announcement
        )
        XCTAssertGreaterThan(
            GameplayOverlayLayer.announcement,
            GameplayOverlayLayer.board
        )
    }

    func testMenuMotivationUsesTheNativeTenSecondNonRepeatingContract() {
        XCTAssertEqual(MenuMotivation.rotationInterval, .seconds(10))
        XCTAssertEqual(MenuMotivation.hints.count, 26)
        XCTAssertEqual(MenuMotivation.hints.first, "Go get your pet!")
        XCTAssertEqual(MenuMotivation.hints.last, "Blink between rounds!")
        XCTAssertEqual(MenuMotivation.nextIndex(previous: nil, randomValue: 0), 0)
        XCTAssertEqual(MenuMotivation.nextIndex(previous: 0, randomValue: 0), 1)
        XCTAssertEqual(MenuMotivation.nextIndex(previous: 25, randomValue: 0.999_999), 0)
        XCTAssertEqual(MenuMotivation.introStampSeed(arguments: ["--uitesting"], randomValue: 5), 0)
        XCTAssertEqual(MenuMotivation.introStampSeed(arguments: [], randomValue: 5), 5)
    }

    func testPetTurnAnimationMovesOnlyThroughAdjacentDirectionalPoses() {
        XCTAssertEqual(PetAnimationPlan.directionalFrames, [3, 2, 0, 6, 7])
        XCTAssertEqual(
            PetAnimationPlan.turn(fromFrameIndex: 6, to: .right),
            [
                PetAnimationStep(frameIndex: 7, delayAfter: .zero)
            ]
        )
        XCTAssertEqual(
            PetAnimationPlan.turn(fromFrameIndex: 3, to: .right),
            [
                PetAnimationStep(frameIndex: 2, delayAfter: .milliseconds(100)),
                PetAnimationStep(frameIndex: 0, delayAfter: .milliseconds(100)),
                PetAnimationStep(frameIndex: 6, delayAfter: .milliseconds(100)),
                PetAnimationStep(frameIndex: 7, delayAfter: .zero),
            ]
        )

        for source in PetAnimationPlan.directionalFrames {
            for target in [
                PetFacing.left, .halfLeft, .front, .halfRight, .right,
            ] {
                let steps = PetAnimationPlan.turn(fromFrameIndex: source, to: target)
                if source == target.frameIndex {
                    XCTAssertTrue(steps.isEmpty)
                    continue
                }
                XCTAssertEqual(steps.last?.frameIndex, target.frameIndex)
                var previous = try! XCTUnwrap(
                    PetAnimationPlan.directionalFrames.firstIndex(of: source)
                )
                for step in steps {
                    let position = try! XCTUnwrap(
                        PetAnimationPlan.directionalFrames.firstIndex(of: step.frameIndex)
                    )
                    XCTAssertEqual(abs(position - previous), 1)
                    previous = position
                }
            }
        }
    }

    func testPetSleepAndWakeNeverForceTheSpriteThroughCenter() {
        XCTAssertEqual(
            PetAnimationPlan.wakeAndTurn(fromFrameIndex: 9, to: .halfRight),
            [
                PetAnimationStep(frameIndex: 8, delayAfter: .milliseconds(189)),
                PetAnimationStep(frameIndex: 6, delayAfter: .zero),
            ]
        )
        XCTAssertEqual(
            PetAnimationPlan.sleep(fromFrameIndex: 7),
            [
                PetAnimationStep(frameIndex: 8, delayAfter: .milliseconds(189)),
                PetAnimationStep(frameIndex: 9, delayAfter: .zero),
            ]
        )
        XCTAssertEqual(
            PetAnimationPlan.wakeAndTurn(fromFrameIndex: 8, to: .left),
            [PetAnimationStep(frameIndex: 3, delayAfter: .zero)]
        )
    }

    func testPancakeFullLeftUsesTheCleanMirroredRightFrameOnly() {
        XCTAssertEqual(
            PetSpriteFramePolicy.resolve(petID: "pancake", semanticFrameIndex: 3),
            PetSpriteFrameVariant(sourceFrameIndex: 7, mirrorsHorizontally: true)
        )
        XCTAssertEqual(
            PetSpriteFramePolicy.resolve(petID: "pancake", semanticFrameIndex: 2),
            PetSpriteFrameVariant(sourceFrameIndex: 2, mirrorsHorizontally: false)
        )
        for petID in ["foka", "kesha", "tauta", "misha", "mitsuri", "muse"] {
            XCTAssertEqual(
                PetSpriteFramePolicy.resolve(petID: petID, semanticFrameIndex: 3),
                PetSpriteFrameVariant(sourceFrameIndex: 3, mirrorsHorizontally: false)
            )
        }
    }

    func testEveryApprovedPetSpriteAndHabitatIsBundled() throws {
        for petID in ["foka", "kesha", "tauta", "misha", "mitsuri", "muse", "pancake"] {
            let presentation = PetPresentation.resolve(petID)
            let spriteName = try XCTUnwrap(presentation.spriteAsset)
            let habitatName = try XCTUnwrap(presentation.habitatAsset)
            let sprite = try bundledImage(named: spriteName)
            let habitat = try bundledImage(named: habitatName)
            XCTAssertEqual(sprite.cgImage?.width, 640, spriteName)
            XCTAssertEqual(sprite.cgImage?.height, 64, spriteName)
            XCTAssertEqual(habitat.cgImage?.width, 64, habitatName)
            XCTAssertEqual(habitat.cgImage?.height, 48, habitatName)
        }
    }

    private func profile(
        selectedPetID: String?,
        visible: Bool,
        specialPetID: String?,
        equippedPetID: String? = nil
    ) -> PlayerProfile {
        PlayerProfile(
            id: "player-1",
            nickname: "Player",
            nicknameConfirmed: true,
            coins: 42,
            totalPlayMs: 60_000,
            ownedPetIds: ["foka"],
            selectedPetId: selectedPetID,
            petVisible: visible,
            equippedPetId: equippedPetID ?? (visible ? selectedPetID : nil),
            specialPetId: specialPetID,
            ownedThemeIds: ["classic", "disco"],
            selectedThemeId: "classic",
            isAdmin: false,
            createdAt: "2026-07-15T00:00:00Z",
            updatedAt: "2026-07-15T00:00:00Z"
        )
    }

    private func bundledImage(named name: String) throws -> UIImage {
        let path = try XCTUnwrap(Bundle.main.path(forResource: name, ofType: "png"))
        return try XCTUnwrap(UIImage(contentsOfFile: path))
    }
}
