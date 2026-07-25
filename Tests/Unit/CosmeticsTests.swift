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
        XCTAssertEqual(WebMenuMetrics.menuPetBaseHorizontalOffset, 20)
        XCTAssertEqual(WebMenuMetrics.motivationHorizontalShiftFraction, 0.10)
        XCTAssertEqual(WebMenuMetrics.motivationHorizontalNudge, -10)
        XCTAssertEqual(WebMenuMetrics.motivationScale, 1.15)
        XCTAssertEqual(WebMenuMetrics.introRulesHorizontalOffset, 10)
        XCTAssertEqual(WebMenuMetrics.largePhoneScale(screenWidth: 375), 1)
        XCTAssertEqual(
            WebMenuMetrics.largePhoneScale(screenWidth: 440),
            440 / 375,
            accuracy: 0.001
        )
        XCTAssertEqual(WebMenuMetrics.largePhoneScale(screenWidth: 500), 1.18)
        XCTAssertEqual(
            WebMenuMetrics.menuPetSize(screenWidth: 440),
            64 * (440 / 375),
            accuracy: 0.001
        )
    }

    func testThemeVisualTokensMatchTheReviewedWebContract() {
        XCTAssertEqual(ThemePalette.classic.backgroundTop, "#101326")
        XCTAssertEqual(ThemePalette.classic.backgroundBottom, "#080a12")
        XCTAssertEqual(ThemePalette.classic.achievementsAccent, "#ffd84d")
        XCTAssertEqual(ThemePalette.classic.petsAccent, "#ff79ad")
        XCTAssertEqual(ThemePalette.classic.themesAccent, "#63efff")
        XCTAssertEqual(WebMenuBorderAccents.profileHex(theme: .classic), "#8ee85a")
        XCTAssertEqual(WebMenuBorderAccents.leaderboardHex(theme: .classic), "#63efff")

        XCTAssertEqual(ThemePalette.disco.backgroundTop, "#030404")
        XCTAssertEqual(ThemePalette.disco.surface, "#0c0f16")
        XCTAssertEqual(ThemePalette.disco.board, "#07090d")
        XCTAssertEqual(ThemePalette.disco.idleCell, DiscoThemeTokens.idleCellHex)
        XCTAssertEqual(ThemePalette.disco.tileColors, DiscoThemeTokens.activeCellHexes)
        XCTAssertEqual(WebMenuBorderAccents.profileHex(theme: .disco), "#b2ee7c")
        XCTAssertEqual(WebMenuBorderAccents.leaderboardHex(theme: .disco), "#63efff")
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
        XCTAssertEqual(WebMenuBorderAccents.profileHex(theme: .light), "#25812f")
        XCTAssertEqual(WebMenuBorderAccents.leaderboardHex(theme: .light), "#087fa7")
        XCTAssertEqual(ThemePalette.pixel.backgroundTop, "#1a1635")
        XCTAssertEqual(ThemePalette.pixel.backgroundBottom, "#0c0c1d")
        XCTAssertTrue(ThemePalette.pixel.isPixel)
        XCTAssertEqual(ThemePalette.pixel.cornerRadius, 3)
        XCTAssertEqual(WebMenuBorderAccents.profileHex(theme: .pixel), "#82dd48")
        XCTAssertEqual(WebMenuBorderAccents.leaderboardHex(theme: .pixel), "#63efff")
        XCTAssertEqual(WebMenuBorderAccents.settingsOpacity, 0.85, accuracy: 0.001)
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
            12,
            accuracy: 0.001
        )
        XCTAssertEqual(GameCellVisualMetrics.previewGlyphScale, 2)
        XCTAssertEqual(
            GameCellVisualMetrics.glyphBoxSide(
                side: 100,
                scale: GameCellVisualMetrics.previewGlyphScale
            ),
            24,
            accuracy: 0.001
        )
        XCTAssertEqual(
            GameCellVisualMetrics.cornerRadius(theme: .classic, side: 40),
            4
        )
        XCTAssertEqual(
            GameCellVisualMetrics.liveCornerRadius(theme: .disco, gridDimension: 1),
            22
        )
        XCTAssertEqual(
            GameCellVisualMetrics.liveCornerRadius(theme: .disco, gridDimension: 2),
            15
        )
        XCTAssertEqual(
            GameCellVisualMetrics.liveCornerRadius(theme: .disco, gridDimension: 4),
            11
        )
        XCTAssertEqual(
            GameCellVisualMetrics.liveCornerRadius(theme: .pixel, gridDimension: 1),
            0
        )
        XCTAssertEqual(GameBoardVisualMetrics.shellCornerRadius(theme: .disco), 22)
        XCTAssertEqual(
            GameCellVisualMetrics.glyphBoxSide(side: 40),
            5.6,
            accuracy: 0.001
        )
        XCTAssertEqual(
            GameCellVisualMetrics.glyphBoxSide(
                side: 40,
                scale: GameCellVisualMetrics.previewGlyphScale
            ),
            11.2,
            accuracy: 0.001
        )
        XCTAssertEqual(GameCellVisualMetrics.liveGlyphScale(gridDimension: 1), 1)
        XCTAssertEqual(GameCellVisualMetrics.liveGlyphScale(gridDimension: 2), 2)
        XCTAssertEqual(GameCellVisualMetrics.liveGlyphScale(gridDimension: 4), 2)
        XCTAssertEqual(GameCellVisualMetrics.targetBorderWidth, 3)
        XCTAssertEqual(GameCellVisualMetrics.activeBorderWidth, 2)
        XCTAssertEqual(GameHUDMetrics.colorHeroOutlineWidth, 4)
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
                        XCTAssertEqual(bounds.width, target.width, accuracy: 0.001, glyph)
                        if style == .pixel, glyph == "★" {
                            let sourceMargin = side * 2 / 50
                            XCTAssertEqual(
                                bounds.minY,
                                target.minY + sourceMargin,
                                accuracy: 0.001,
                                glyph
                            )
                            XCTAssertEqual(
                                bounds.height,
                                target.height - sourceMargin * 2,
                                accuracy: 0.001,
                                glyph
                            )
                        } else {
                            XCTAssertEqual(bounds.minY, target.minY, accuracy: 0.001, glyph)
                            XCTAssertEqual(bounds.height, target.height, accuracy: 0.001, glyph)
                        }
                    }
                }
            }
        }
    }

    func testPixelStarUsesTheExactSuppliedFiftyByFiftyMask() throws {
        let mask = try XCTUnwrap(GameGlyphGeometry.pixelMask(for: "★"))
        XCTAssertEqual(mask.count, 50)
        XCTAssertTrue(mask.allSatisfy { $0.count == 50 })

        func row(_ ranges: [Range<Int>]) -> String {
            var characters = Array(repeating: Character("."), count: 50)
            for range in ranges {
                for index in range {
                    characters[index] = "#"
                }
            }
            return String(characters)
        }
        func repeated(_ count: Int, _ ranges: [Range<Int>]) -> [String] {
            Array(repeating: row(ranges), count: count)
        }
        let expected =
            Array(repeating: row([]), count: 2)
            + repeated(3, [24..<26])
            + repeated(4, [22..<28])
            + repeated(5, [20..<30])
            + repeated(4, [18..<32])
            + repeated(4, [0..<50])
            + repeated(2, [2..<48])
            + repeated(2, [6..<44])
            + repeated(2, [10..<40])
            + repeated(5, [14..<36])
            + repeated(4, [12..<38])
            + repeated(3, [10..<40])
            + repeated(2, [10..<23, 27..<40])
            + repeated(2, [8..<20, 30..<42])
            + repeated(2, [8..<16, 34..<42])
            + repeated(2, [8..<13, 37..<42])
            + Array(repeating: row([]), count: 2)

        XCTAssertEqual(mask, expected)
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
        XCTAssertFalse(discoIdle.discoGlow)
        XCTAssertTrue(discoActive.discoGlow)
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
        XCTAssertEqual(GameCellEffectTokens.discoCenterWhiteOpacity, 0.42, accuracy: 0.001)
        XCTAssertEqual(GameCellEffectTokens.discoMidpointWhiteOpacity, 0.11, accuracy: 0.001)
        XCTAssertEqual(GameCellEffectTokens.discoGlowNearOpacity, 0.68, accuracy: 0.001)
        XCTAssertEqual(GameCellEffectTokens.discoGlowFarOpacity, 0.34, accuracy: 0.001)
        XCTAssertLessThan(GameCellEffectTokens.discoGlowOpacity, 1)
        XCTAssertGreaterThan(GameCellEffectTokens.discoGlowOpacity, 0)
        XCTAssertEqual(GameCellEffectTokens.discoGlowNearBlurMaximum, 13)
        XCTAssertEqual(GameCellEffectTokens.discoGlowFarBlurMaximum, 30)
        XCTAssertEqual(DiscoThemeTokens.idleScratchOpacity, 0.16, accuracy: 0.001)
        XCTAssertEqual(DiscoThemeTokens.activeScratchOpacity, 0.34, accuracy: 0.001)
        XCTAssertGreaterThan(GameCellEffectTokens.lightInnerStrokeOpacity, 0.8)
    }

    func testDiscoActiveColorsMatchTheWebMaterialPalette() {
        XCTAssertEqual(
            DiscoThemeTokens.activeCellHexes,
            ["#65e9f1", "#ffe681", "#ff86bc", "#b2ee7c", "#ffb06f", "#c3a8ff"]
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
            XCTAssertGreaterThanOrEqual(saturation, 0.30, hex)
            XCTAssertGreaterThanOrEqual(brightness, 0.90, hex)
            XCTAssertEqual(alpha, 1, accuracy: 0.001, hex)
        }
    }

    @MainActor
    func testDiscoOutgoingGlowHasASoftExteriorAndTransparentCenter() throws {
        let geometry = DiscoGlowGeometry.resolve(cellSide: 128, cornerRadius: 12.8)
        XCTAssertEqual(geometry.nearBlurRadius, 7.68, accuracy: 0.001)
        XCTAssertEqual(geometry.farBlurRadius, 15.36, accuracy: 0.001)
        XCTAssertEqual(geometry.extent, 27)

        let image = DiscoOutgoingGlowArtwork.image(
            cellSide: geometry.cellSide,
            cornerRadius: geometry.cornerRadius
        )
        XCTAssertTrue(
            image
                === DiscoOutgoingGlowArtwork.image(
                    cellSide: geometry.cellSide,
                    cornerRadius: geometry.cornerRadius
                )
        )
        let cgImage = try XCTUnwrap(image.cgImage)
        XCTAssertEqual(cgImage.width, Int(geometry.imageSize.width))
        XCTAssertEqual(cgImage.height, Int(geometry.imageSize.height))

        let centerAlpha = try alpha(
            in: cgImage,
            at: CGPoint(x: geometry.tileRect.midX, y: geometry.tileRect.midY)
        )
        let nearHaloAlpha = try alpha(
            in: cgImage,
            at: CGPoint(x: geometry.tileRect.minX - 2, y: geometry.tileRect.midY)
        )
        let farHaloAlpha = try alpha(
            in: cgImage,
            at: CGPoint(x: 1, y: geometry.tileRect.midY)
        )
        XCTAssertLessThan(centerAlpha, 0.02)
        XCTAssertGreaterThan(nearHaloAlpha, 0.05)
        XCTAssertGreaterThan(nearHaloAlpha, farHaloAlpha)
    }

    func testGameBoardLayoutKeepsSwiftUIAndSpriteKitCellsOnOneGrid() {
        let layout = GameBoardLayout(size: CGSize(width: 320, height: 320), dimension: 2)
        XCTAssertEqual(layout.boardFrame, CGRect(x: 12, y: 12, width: 296, height: 296))
        XCTAssertEqual(layout.gap, 8)
        XCTAssertEqual(layout.cellSide, 144)
        XCTAssertEqual(
            layout.cellFrame(at: 0, yAxis: .down),
            CGRect(x: 12, y: 12, width: 144, height: 144)
        )
        XCTAssertEqual(
            layout.cellFrame(at: 0, yAxis: .up),
            CGRect(x: 12, y: 164, width: 144, height: 144)
        )
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
        XCTAssertFalse(
            AudioOutputPolicy.isSuppressed(
                arguments: [
                    "PimPoPom",
                    "--uitesting",
                    "--screenshot-mode",
                    "--screenshot-record-audio",
                ],
                environment: [:]
            )
        )
        XCTAssertTrue(
            AudioOutputPolicy.isSuppressed(
                arguments: [
                    "PimPoPom",
                    "--uitesting",
                    "--screenshot-mode",
                    "--screenshot-record-audio",
                ],
                environment: ["XCTestSessionIdentifier": "fixture-test"]
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
            PetFacing.resolve(pointerX: center + 10, petCenterX: center, interactionWidth: width),
            .front
        )
        XCTAssertEqual(
            PetFacing.resolve(pointerX: center - 10, petCenterX: center, interactionWidth: width),
            .front
        )
        XCTAssertEqual(
            PetFacing.resolve(pointerX: center + 10.01, petCenterX: center, interactionWidth: width),
            .halfRight
        )
        XCTAssertEqual(
            PetFacing.resolve(pointerX: center - 10.01, petCenterX: center, interactionWidth: width),
            .halfLeft
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

        XCTAssertEqual(
            PetFacing.resolve(pointerX: 44, petCenterX: 40, interactionWidth: 80),
            .front
        )
        XCTAssertEqual(
            PetFacing.resolve(pointerX: 44.01, petCenterX: 40, interactionWidth: 80),
            .halfRight
        )
        XCTAssertEqual(
            PetFacing.resolve(pointerX: 220, petCenterX: 200, interactionWidth: 1_000),
            .front
        )
        XCTAssertEqual(
            PetFacing.resolve(pointerX: 220.01, petCenterX: 200, interactionWidth: 1_000),
            .halfRight
        )
    }

    func testSharedTapFollowUsesKnownGameplayLayoutWithoutMeasuredFrames() {
        let screenWidth: CGFloat = 375
        let boardWidth = screenWidth - PetTapFollow.gameplayOuterHorizontalInset * 2
        let boardMinX = (screenWidth - boardWidth) / 2
        let petCenterX = screenWidth * 0.40
        let petCenterNormalizedX = (petCenterX - boardMinX) / boardWidth

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
                normalizedPointerX: petCenterNormalizedX,
                screenWidth: screenWidth,
                current: .right
            ),
            .front
        )
        XCTAssertEqual(
            PetTapFollow.resolveGameplay(
                normalizedPointerX: (petCenterX + screenWidth * PetFacing.frontInteractionFraction - boardMinX)
                    / boardWidth,
                screenWidth: screenWidth,
                current: .left
            ),
            .front
        )
        XCTAssertEqual(
            PetTapFollow.resolveGameplay(
                normalizedPointerX: (petCenterX + screenWidth * PetFacing.frontInteractionFraction + 0.01
                    - boardMinX) / boardWidth,
                screenWidth: screenWidth,
                current: .front
            ),
            .halfRight
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
            horizontalOffset: WebMenuMetrics.menuPetBaseHorizontalOffset
                - 375 * WebMenuMetrics.menuPetHorizontalShiftFraction
        )

        XCTAssertEqual(centerX, 294.75, accuracy: 0.001)
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
            "Tap Pink ■", "Godlike • 201ms", "Perfect • 301ms", "Hit",
            "Get ready", "Missed", "Too early", "Too slow", "Wrong cell",
        ] {
            XCTAssertTrue(GameplayFeedbackPresentation.isVisuallyHidden(feedback), feedback)
        }
        for feedback in ["Great • 401ms", "Good • 501ms"] {
            XCTAssertTrue(GameplayFeedbackPresentation.isVisuallyHidden(feedback), feedback)
        }
        XCTAssertFalse(GameplayFeedbackPresentation.isVisuallyHidden("Decoy dodged"))
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
            GameplayOverlayLayer.tapFeedback,
            GameplayOverlayLayer.announcement
        )
        XCTAssertGreaterThan(
            GameplayOverlayLayer.announcement,
            GameplayOverlayLayer.boardShellBorder
        )
        XCTAssertGreaterThan(
            GameplayOverlayLayer.boardShellBorder,
            GameplayOverlayLayer.discoGlow
        )
        XCTAssertGreaterThan(
            GameplayOverlayLayer.discoGlow,
            GameplayOverlayLayer.board
        )
        XCTAssertGreaterThan(
            GameplayOverlayLayer.board,
            GameplayOverlayLayer.boardShell
        )
        let missedYellowByTheme = [
            "classic": "#ffd84d",
            "disco": "#ffe681",
            "light": "#f2bd14",
            "pixel": "#ffd13d",
        ]
        for theme in ThemePalette.all {
            XCTAssertEqual(
                GameplayAnnouncementStyle.toneHex(for: .missed, theme: theme),
                missedYellowByTheme[theme.id]
            )
        }
        XCTAssertEqual(
            GameColorHeroPresentation.outlineHex(
                theme: .light,
                mode: .arcade,
                colorIndex: 2
            ),
            ThemePalette.light.tileColors[2]
        )
        XCTAssertEqual(
            GameColorHeroPresentation.outlineOpacity(theme: .light, mode: .arcade),
            0.82
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

    func testPerPetSpriteCorrectionsUseOnlyReviewedMirrors() {
        XCTAssertEqual(
            PetSpriteFramePolicy.resolve(petID: "pancake", semanticFrameIndex: 3),
            PetSpriteFrameVariant(sourceFrameIndex: 7, mirrorsHorizontally: true)
        )
        XCTAssertEqual(
            PetSpriteFramePolicy.resolve(petID: "pancake", semanticFrameIndex: 2),
            PetSpriteFrameVariant(sourceFrameIndex: 2, mirrorsHorizontally: false)
        )
        XCTAssertEqual(
            PetSpriteFramePolicy.resolve(
                petID: "foka",
                semanticFrameIndex: PetFacing.halfRight.frameIndex
            ),
            PetSpriteFrameVariant(
                sourceFrameIndex: PetFacing.halfLeft.frameIndex,
                mirrorsHorizontally: true
            )
        )
        XCTAssertEqual(
            PetSpriteFramePolicy.resolve(
                petID: "foka",
                semanticFrameIndex: PetFacing.right.frameIndex
            ),
            PetSpriteFrameVariant(
                sourceFrameIndex: PetFacing.left.frameIndex,
                mirrorsHorizontally: true
            )
        )
        XCTAssertEqual(
            PetSpriteFramePolicy.resolve(
                petID: "foka",
                semanticFrameIndex: PetFacing.left.frameIndex
            ),
            PetSpriteFrameVariant(
                sourceFrameIndex: PetFacing.left.frameIndex,
                mirrorsHorizontally: false
            )
        )
        for petID in ["kesha", "tauta", "misha", "mitsuri", "muse"] {
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

    private func alpha(in image: CGImage, at point: CGPoint) throws -> CGFloat {
        var pixel = [UInt8](repeating: 0, count: 4)
        let bitmapInfo =
            CGBitmapInfo.byteOrder32Big.rawValue
            | CGImageAlphaInfo.premultipliedLast.rawValue
        let context = try XCTUnwrap(
            CGContext(
                data: &pixel,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo
            )
        )
        context.interpolationQuality = .none
        context.translateBy(x: -point.x, y: -point.y)
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
        return CGFloat(pixel[3]) / 255
    }
}
