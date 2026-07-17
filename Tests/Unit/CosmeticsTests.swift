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
        XCTAssertEqual(ThemePreviewStyle.discoBackgroundHex, "#080909")
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
        XCTAssertEqual(ThemePalette.pixel.resolvedFontSize(10), 11, accuracy: 0.001)
        XCTAssertEqual(ThemePalette.classic.resolvedFontSize(10), 10, accuracy: 0.001)
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
                case "pancake": 26
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

    func testGameplayFeedbackHidesTargetsAndSpeedRatingsButRetainsMistakes() {
        for feedback in [
            "Tap Pink ■", "Godlike · 201 ms", "Perfect · 301 ms", "Great · 401 ms",
            "Good · 501 ms", "Hit · 250 ms",
        ] {
            XCTAssertTrue(GameplayFeedbackPresentation.isVisuallyHidden(feedback), feedback)
        }
        for feedback in ["Too slow", "Wrong cell", "Too early", "Decoy dodged"] {
            XCTAssertFalse(GameplayFeedbackPresentation.isVisuallyHidden(feedback), feedback)
        }
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

    func testPetPreviewAnimationStartsStaticAndReturnsToItsRestingFrame() {
        XCTAssertEqual(PetPreviewAnimation.frames.first, 0)
        XCTAssertTrue(PetPreviewAnimation.frames.dropFirst().contains { $0 != 0 })
        XCTAssertEqual(PetPreviewAnimation.frames.last, 0)
        XCTAssertEqual(PetPreviewAnimation.frames.count, 9)
    }

    func testPetTurnAnimationMatchesTheWebTimingAndDirectionalFrames() {
        XCTAssertEqual(
            PetAnimationPlan.turn(to: .halfLeft),
            [
                PetAnimationStep(frameIndex: 0, delayAfter: .milliseconds(150)),
                PetAnimationStep(frameIndex: 1, delayAfter: .milliseconds(150)),
                PetAnimationStep(frameIndex: 2, delayAfter: .zero),
            ]
        )
        XCTAssertEqual(
            PetAnimationPlan.turn(to: .right),
            [
                PetAnimationStep(frameIndex: 0, delayAfter: .milliseconds(100)),
                PetAnimationStep(frameIndex: 5, delayAfter: .milliseconds(100)),
                PetAnimationStep(frameIndex: 6, delayAfter: .milliseconds(100)),
                PetAnimationStep(frameIndex: 7, delayAfter: .zero),
            ]
        )
        XCTAssertEqual(
            PetAnimationPlan.wakeAndTurn(to: .halfRight),
            [
                PetAnimationStep(frameIndex: 9, delayAfter: .milliseconds(189)),
                PetAnimationStep(frameIndex: 8, delayAfter: .milliseconds(261)),
                PetAnimationStep(frameIndex: 0, delayAfter: .milliseconds(150)),
                PetAnimationStep(frameIndex: 5, delayAfter: .milliseconds(150)),
                PetAnimationStep(frameIndex: 6, delayAfter: .zero),
            ]
        )
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
