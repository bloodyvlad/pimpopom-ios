import PimPoPomCore
import UIKit
import XCTest

@testable import PimPoPom

@MainActor
final class PreferencesAndContractTests: XCTestCase {
    func testAppIconChoiceResolvesSystemNames() {
        XCTAssertEqual(AppIconChoice.resolve(alternateIconName: nil), .glow)
        XCTAssertEqual(AppIconChoice.resolve(alternateIconName: "AppIconLight"), .light)
        XCTAssertEqual(AppIconChoice.resolve(alternateIconName: "AppIconPixel"), .pixel)
        XCTAssertEqual(AppIconChoice.resolve(alternateIconName: "UnknownIcon"), .glow)
        XCTAssertNil(AppIconChoice.glow.alternateIconName)
        XCTAssertEqual(AppIconChoice.light.alternateIconName, "AppIconLight")
        XCTAssertEqual(AppIconChoice.pixel.alternateIconName, "AppIconPixel")
    }

    func testAppIconControllerUsesTheSystemSelectionAsTruth() async {
        let application = TestAppIconApplication(alternateIconName: nil)
        let controller = AppIconController(application: application)

        XCTAssertEqual(controller.selectedChoice, .glow)
        await controller.select(.light)

        XCTAssertEqual(application.requestedIconNames, ["AppIconLight"])
        XCTAssertEqual(controller.selectedChoice, .light)
        XCTAssertFalse(controller.isChanging)
        XCTAssertNil(controller.statusMessage)
    }

    func testAppIconControllerRejectsUnsupportedChanges() async {
        let application = TestAppIconApplication(
            supportsAlternateIcons: false,
            alternateIconName: nil
        )
        let controller = AppIconController(application: application)

        await controller.select(.pixel)

        XCTAssertTrue(application.requestedIconNames.isEmpty)
        XCTAssertEqual(controller.selectedChoice, .glow)
        XCTAssertEqual(
            controller.statusMessage,
            "Alternate app icons are not supported on this device."
        )
    }

    func testChangeIconDeepLinkAndShortcutQueueOneConsumableRequest() {
        let controller = HomeQuickActionController()
        XCTAssertFalse(controller.hasPendingChangeIconRequest)
        XCTAssertTrue(controller.handle(HomeQuickAction.changeIconURL))
        XCTAssertTrue(controller.hasPendingChangeIconRequest)
        XCTAssertTrue(controller.consumeChangeIconRequest())
        XCTAssertFalse(controller.consumeChangeIconRequest())

        let shortcut = UIApplicationShortcutItem(
            type: "com.otcsoftware.pimpopom.change-icon",
            localizedTitle: "Change Icon",
            localizedSubtitle: nil,
            icon: nil,
            userInfo: ["url": HomeQuickAction.changeIconURL.absoluteString as NSString]
        )
        XCTAssertTrue(controller.handle(shortcut))
        XCTAssertTrue(controller.consumeChangeIconRequest())
        XCTAssertFalse(controller.handle(URL(string: "pimpopom://settings/audio")!))
    }

    func testAudioPreferencesDefaultOnAndPersistIndependently() throws {
        let suiteName = "PimPoPomTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let initial = AppPreferences(defaults: defaults)
        XCTAssertTrue(initial.soundEffectsEnabled)
        XCTAssertTrue(initial.musicEnabled)
        XCTAssertEqual(initial.soundEffectsVolume, 1)
        XCTAssertEqual(initial.musicVolume, 1)
        XCTAssertEqual(initial.selectedThemeID, "classic")
        XCTAssertTrue(initial.glyphsEnabled)

        initial.soundEffectsEnabled = false
        initial.soundEffectsVolume = 0.25
        initial.musicEnabled = true
        initial.musicVolume = 0.70
        initial.selectedThemeID = "disco"
        initial.glyphsEnabled = false

        let restored = AppPreferences(defaults: defaults)
        XCTAssertFalse(restored.soundEffectsEnabled)
        XCTAssertTrue(restored.musicEnabled)
        XCTAssertEqual(restored.soundEffectsVolume, 0.25, accuracy: 0.0001)
        XCTAssertEqual(restored.musicVolume, 0.70, accuracy: 0.0001)
        XCTAssertEqual(restored.selectedThemeID, "disco")
        XCTAssertFalse(restored.glyphsEnabled)
    }

    func testStoredVolumesAreClamped() throws {
        let suiteName = "PimPoPomTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(1.75, forKey: "audio.sound-effects.volume")
        defaults.set(-0.25, forKey: "audio.music.volume")

        let preferences = AppPreferences(defaults: defaults)
        XCTAssertEqual(preferences.soundEffectsVolume, 1)
        XCTAssertEqual(preferences.musicVolume, 0)
    }

    func testAudioAutomaticallyResumesWhenInterruptionEndsBeforeForeground() {
        var state = AudioResumeState()
        XCTAssertTrue(state.setApplicationActive(true))
        state.interruptionBegan()
        XCTAssertFalse(state.canProduceOutput)
        XCTAssertFalse(state.setApplicationActive(false))
        XCTAssertFalse(state.interruptionEnded(shouldResume: true))

        XCTAssertTrue(state.setApplicationActive(true))
        XCTAssertTrue(state.canProduceOutput)
        XCTAssertFalse(state.audioSessionIsInterrupted)
        XCTAssertFalse(state.outputRequiresUserResume)
    }

    func testAudioForegroundRecoversALifecycleInterruptionMissingItsEndNotification() {
        var state = AudioResumeState()
        XCTAssertTrue(state.setApplicationActive(true))
        state.interruptionBegan()
        XCTAssertFalse(state.setApplicationActive(false))

        XCTAssertTrue(state.setApplicationActive(true))
        XCTAssertTrue(state.canProduceOutput)
        XCTAssertFalse(state.audioSessionIsInterrupted)
    }

    func testAudioRouteLossStillRequiresATrustedUserActionAfterForeground() {
        var state = AudioResumeState()
        XCTAssertTrue(state.setApplicationActive(true))
        state.routeBecameUnavailable()
        XCTAssertFalse(state.canProduceOutput)
        XCTAssertFalse(state.setApplicationActive(false))
        XCTAssertFalse(state.setApplicationActive(true))
        XCTAssertTrue(state.outputRequiresUserResume)

        XCTAssertTrue(state.trustedUserAction())
        XCTAssertTrue(state.canProduceOutput)
    }

    func testAudioExternalInterruptionWithoutResumeRecommendationStaysUserGated() {
        var state = AudioResumeState()
        XCTAssertTrue(state.setApplicationActive(true))
        state.interruptionBegan()
        XCTAssertFalse(state.interruptionEnded(shouldResume: false))
        XCTAssertFalse(state.canProduceOutput)
        XCTAssertTrue(state.outputRequiresUserResume)

        XCTAssertTrue(state.trustedUserAction())
        XCTAssertTrue(state.canProduceOutput)
    }

    func testAudioNonresumableInterruptionEndingInBackgroundStaysUserGated() {
        var state = AudioResumeState()
        XCTAssertTrue(state.setApplicationActive(true))
        state.interruptionBegan()
        XCTAssertFalse(state.setApplicationActive(false))
        XCTAssertFalse(state.interruptionEnded(shouldResume: false))

        XCTAssertFalse(state.setApplicationActive(true))
        XCTAssertFalse(state.canProduceOutput)
        XCTAssertTrue(state.outputRequiresUserResume)

        XCTAssertTrue(state.trustedUserAction())
        XCTAssertTrue(state.canProduceOutput)
    }

    func testAudioLateNonresumableInterruptionEndOverridesEarlyForegroundRecovery() {
        var state = AudioResumeState()
        XCTAssertTrue(state.setApplicationActive(true))
        state.interruptionBegan()
        XCTAssertFalse(state.setApplicationActive(false))
        XCTAssertTrue(state.setApplicationActive(true))

        XCTAssertFalse(state.interruptionEnded(shouldResume: false))
        XCTAssertFalse(state.canProduceOutput)
        XCTAssertTrue(state.outputRequiresUserResume)
    }

    func testMusicTransitionDoesNotInvalidateInFlightLoad() {
        var generations = AudioTaskGenerations()
        let loadGeneration = generations.beginLoad()
        _ = generations.beginTransition()

        XCTAssertEqual(generations.load, loadGeneration)
        generations.invalidateTransition()
        XCTAssertEqual(generations.load, loadGeneration)

        generations.invalidateLoad()
        XCTAssertNotEqual(generations.load, loadGeneration)
    }

    func testMusicTransitionRequiresExactGenerationContextAndTheme() {
        let transition = MusicTransitionSnapshot(
            generation: 7,
            context: .menu,
            themeID: "disco"
        )

        XCTAssertTrue(transition.isCurrent(generation: 7, context: .menu, themeID: "disco"))
        XCTAssertFalse(transition.isCurrent(generation: 8, context: .menu, themeID: "disco"))
        XCTAssertFalse(transition.isCurrent(generation: 7, context: .gameplay, themeID: "disco"))
        XCTAssertFalse(transition.isCurrent(generation: 7, context: .menu, themeID: "classic"))
    }

    func testResponseProgressIsHiddenWhenInactiveAndDrainsWithoutInversion() {
        XCTAssertNil(ResponseProgressPresentation.remainingFraction(nil, isActive: false))
        XCTAssertNil(ResponseProgressPresentation.remainingFraction(1, isActive: false))
        XCTAssertEqual(ResponseProgressPresentation.remainingFraction(1, isActive: true), 1)
        XCTAssertEqual(ResponseProgressPresentation.remainingFraction(0.5, isActive: true), 0.5)
        XCTAssertEqual(ResponseProgressPresentation.remainingFraction(0, isActive: true), 0)
        XCTAssertEqual(ResponseProgressPresentation.remainingFraction(1.4, isActive: true), 1)
        XCTAssertEqual(ResponseProgressPresentation.remainingFraction(-0.4, isActive: true), 0)
    }

    func testTapFeedbackUsesOneStraightTwoLinePresentationAtTheTap() {
        let event = GameplayHitFeedbackEvent(
            id: 1,
            rating: .perfect,
            milliseconds: 321,
            pointsAwarded: 2_343,
            normalizedLocation: CGPoint(x: 0.25, y: 0.60)
        )
        let hit = GameplayHitPresentation(
            event: event,
            phase: .visible
        )
        XCTAssertEqual(
            GameplayRatingFormatting.detail(rating: .good, milliseconds: 802),
            "Good • 802ms"
        )
        XCTAssertEqual(hit.scoreText, "+2,343 points")
        XCTAssertEqual(hit.ratingText, "Perfect • 321ms")
        XCTAssertEqual(
            hit.tapPosition(in: CGSize(width: 320, height: 320)),
            CGPoint(x: 80, y: 192)
        )
        XCTAssertEqual(
            hit.ratingPosition(in: CGSize(width: 320, height: 320)),
            CGPoint(x: 80, y: 211)
        )
        XCTAssertEqual(GameplayHitFeedbackMetrics.pointsFontSize, 16)
        XCTAssertEqual(GameplayHitFeedbackMetrics.ratingFontSize, 12)
        XCTAssertEqual(GameplayHitFeedbackMetrics.ratingVerticalOffset, 19)
        XCTAssertEqual(GameplayHitFeedbackMetrics.lifetimeMilliseconds, 980)
        XCTAssertEqual(hit.opacity, 1)
        var fadingHit = hit
        fadingHit.phase = .hidden
        XCTAssertEqual(fadingHit.opacity, 0)
    }

    func testGameplayHUDUsesRequestedZenAndFooterMetrics() {
        XCTAssertEqual(GameHUDMetrics.livesColorHex, "#ff5370")
        XCTAssertEqual(GameHUDMetrics.colorHeroOutlineWidth, 4)
        XCTAssertEqual(GameHUDMetrics.colorHeroGlowOpacity, 0.72)
        XCTAssertEqual(GameHUDMetrics.colorHeroGlowRadius, 10)
        XCTAssertEqual(GameplayLayoutMetrics.footerLift, 8)
        XCTAssertEqual(GameplayLayoutMetrics.adBannerHeight, 50)
        XCTAssertEqual(GameplayLayoutMetrics.reservedHeight(hasPet: false), 226)
        XCTAssertEqual(GameplayLayoutMetrics.reservedHeight(hasPet: true), 226)
        XCTAssertEqual(GameplayLayoutMetrics.boardToSpeedBarSpacing, 14)

        let compact = GameplayLayoutMetrics.resolve(
            availableSize: CGSize(width: 375, height: 600),
            hasPet: false
        )
        let large = GameplayLayoutMetrics.resolve(
            availableSize: CGSize(width: 440, height: 900),
            hasPet: true
        )
        XCTAssertEqual(compact.boardSide, 351)
        XCTAssertEqual(compact.boardTopSpacing, 14.9, accuracy: 0.001)
        XCTAssertEqual(compact.boardToSpeedBarSpacing, 14)
        XCTAssertEqual(large.boardSide, 416)
        XCTAssertEqual(large.boardTopSpacing, 52)
        XCTAssertEqual(large.boardToSpeedBarSpacing, 14)

        let firstTier = SpeedBarPresentation.resolve(
            multiplier: 1,
            progress: 4,
            target: 5
        )
        XCTAssertEqual(firstTier.completedOpacity, 0)
        XCTAssertEqual(firstTier.activeFraction, 0.8, accuracy: 0.001)

        let promoted = SpeedBarPresentation.resolve(
            multiplier: 2,
            progress: 0,
            target: 5
        )
        XCTAssertEqual(promoted.completedOpacity, 0.60)
        XCTAssertEqual(promoted.activeFraction, 0)

        let growingNextTier = SpeedBarPresentation.resolve(
            multiplier: 2,
            progress: 2,
            target: 5
        )
        XCTAssertEqual(growingNextTier.completedOpacity, 0.60)
        XCTAssertEqual(growingNextTier.activeFraction, 0.4, accuracy: 0.001)

        let maximum = SpeedBarPresentation.resolve(
            multiplier: 5,
            progress: 0,
            target: 5
        )
        XCTAssertEqual(maximum.completedOpacity, 0.60)
        XCTAssertEqual(maximum.activeFraction, 1)

        let godlikePromotion = SpeedBarTransitionPlan.resolve(
            from: firstTier,
            to: SpeedBarPresentation.resolve(
                multiplier: 2,
                progress: 1,
                target: 5
            )
        )
        XCTAssertTrue(godlikePromotion.completesOutgoingTier)
        XCTAssertEqual(godlikePromotion.outgoingCompletionFraction, 1)
        XCTAssertEqual(godlikePromotion.carriedActiveFraction, 0.2, accuracy: 0.001)

        let ordinaryProgress = SpeedBarTransitionPlan.resolve(
            from: promoted,
            to: growingNextTier
        )
        XCTAssertFalse(ordinaryProgress.completesOutgoingTier)
        XCTAssertEqual(ordinaryProgress.outgoingCompletionFraction, 0.4, accuracy: 0.001)
        XCTAssertEqual(ordinaryProgress.carriedActiveFraction, 0.4, accuracy: 0.001)
        XCTAssertEqual(ZenAnyCellTokens.previewSide, 40)
        XCTAssertEqual(
            ZenAnyCellTokens.horizontalLogoGradientHexes,
            [
                "#16b887", "#39c85f", "#86bd3c", "#ffe659", "#ff9a56", "#ff6fc8",
                "#a58aff", "#69d7ff",
            ]
        )
    }

    func testRemoveAdsPlacementUsesCompactHeaderOnlyOnSixThroughSEScreenSizes() {
        XCTAssertTrue(
            MenuRemoveAdsPlacement.usesCompactHeader(screenSize: CGSize(width: 375, height: 667))
        )
        XCTAssertTrue(
            MenuRemoveAdsPlacement.usesCompactHeader(screenSize: CGSize(width: 320, height: 568))
        )
        XCTAssertFalse(
            MenuRemoveAdsPlacement.usesCompactHeader(screenSize: CGSize(width: 414, height: 736))
        )
        XCTAssertFalse(
            MenuRemoveAdsPlacement.usesCompactHeader(screenSize: CGSize(width: 375, height: 812))
        )
        XCTAssertFalse(
            MenuRemoveAdsPlacement.usesCompactHeader(screenSize: CGSize(width: 390, height: 844))
        )
    }

    func testCatalogAndMutationResponsesDecodeCurrentBackendKeys() throws {
        let catalogJSON = Data(
            """
            {
              "themes": [{"id":"light","name":"Light","priceCoins":50}],
              "profile": null,
              "coinBalance": 17
            }
            """.utf8
        )
        let catalog = try JSONDecoder().decode(ThemeCatalogResponse.self, from: catalogJSON)
        XCTAssertEqual(catalog.themes.first?.id, "light")
        XCTAssertEqual(catalog.coinBalance, 17)

        let selectionJSON = Data(
            """
            {
              "profile": {
                "id":"player-1",
                "nickname":"Player",
                "nicknameConfirmed":true,
                "coins":7,
                "totalPlayMs":60000,
                "ownedPetIds":["foka"],
                "selectedPetId":"foka",
                "petVisible":true,
                "equippedPetId":"foka",
                "specialPetId":null,
                "ownedThemeIds":["classic","disco","light"],
                "selectedThemeId":"light",
                "isAdmin":false,
                "createdAt":"2026-07-15T00:00:00Z",
                "updatedAt":"2026-07-15T00:00:00Z"
              },
              "theme":{"id":"light","purchased":true,"pricePaid":50},
              "coinBalance":7
            }
            """.utf8
        )
        let selection = try JSONDecoder().decode(ThemeSelectionResponse.self, from: selectionJSON)
        XCTAssertTrue(selection.theme.purchased)
        XCTAssertEqual(selection.theme.pricePaid, 50)
        XCTAssertEqual(selection.profile.selectedThemeId, "light")
        XCTAssertEqual(selection.coinBalance, 7)
    }
}

@MainActor
private final class TestAppIconApplication: AppIconApplication {
    let supportsAlternateIcons: Bool
    private(set) var alternateIconName: String?
    private(set) var requestedIconNames: [String] = []

    init(supportsAlternateIcons: Bool = true, alternateIconName: String?) {
        self.supportsAlternateIcons = supportsAlternateIcons
        self.alternateIconName = alternateIconName
    }

    func setAlternateIconName(_ alternateIconName: String?) async throws {
        requestedIconNames.append(alternateIconName ?? "primary")
        self.alternateIconName = alternateIconName
    }
}
