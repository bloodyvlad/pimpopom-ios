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

    func testRatingStampPlacementIsDeterministicInUITestsAndStaysOnTheBorderLanes() {
        let event = GameplayHitFeedbackEvent(
            id: 1,
            rating: .perfect,
            milliseconds: 321,
            pointsAwarded: 2_343,
            normalizedLocation: CGPoint(x: 0.25, y: 0.60)
        )
        let presentation = RatingStampPresentation.make(event: event, deterministic: true)
        let point = presentation.position(in: CGSize(width: 351, height: 351))
        let boardFrame = CGRect(x: 10, y: 100, width: 351, height: 351)
        let speedBarFrame = CGRect(x: 30, y: 500, width: 200, height: 36)
        let pointsFrame = CGRect(x: 12, y: 52, width: 70, height: 42)
        let speedBarDestination = try! XCTUnwrap(
            FeedbackMotionPath.relativeDestination(
                from: boardFrame,
                to: speedBarFrame
            )
        )
        let pointsDestination = try! XCTUnwrap(
            FeedbackMotionPath.relativeDestination(
                from: boardFrame,
                to: pointsFrame
            )
        )

        XCTAssertEqual(presentation.event, event)
        XCTAssertEqual(presentation.edge, .right)
        XCTAssertEqual(presentation.laneFraction, 0.5)
        XCTAssertEqual(presentation.tilt, -6)
        XCTAssertEqual(point.x, 287.82, accuracy: 0.001)
        XCTAssertEqual(point.y, 175.5, accuracy: 0.001)

        let hit = GameplayHitPresentation(
            event: event,
            stamp: presentation,
            stampPhase: .visible,
            isScoreVisible: true,
            speedBarDestination: speedBarDestination,
            pointsDestination: pointsDestination
        )
        XCTAssertEqual(
            GameplayRatingFormatting.stamp(rating: .good, milliseconds: 802),
            "Good - 802ms"
        )
        XCTAssertEqual(hit.scoreText, "+2,343 points")
        XCTAssertEqual(
            hit.scorePosition(in: CGSize(width: 320, height: 320)),
            CGPoint(x: 80, y: 177)
        )

        var absorbing = hit
        absorbing.stampPhase = .absorbing
        XCTAssertEqual(
            absorbing.stampPosition(in: CGSize(width: 351, height: 351)),
            CGPoint(x: 120, y: 418)
        )
        absorbing.isScoreVisible = false
        absorbing.isScoreAbsorbing = true
        XCTAssertEqual(
            absorbing.scorePosition(in: CGSize(width: 320, height: 320)),
            pointsDestination
        )
        XCTAssertEqual(absorbing.scoreScale, 0.58)

        XCTAssertTrue(RatingStampMotionPolicy.feedsSpeedBar(.godlike))
        XCTAssertTrue(RatingStampMotionPolicy.feedsSpeedBar(.perfect))
        XCTAssertFalse(RatingStampMotionPolicy.feedsSpeedBar(.great))
        XCTAssertFalse(RatingStampMotionPolicy.feedsSpeedBar(.good))

        for rating in [SpeedRating.great, .good] {
            let stationaryEvent = GameplayHitFeedbackEvent(
                id: 2,
                rating: rating,
                milliseconds: 500,
                pointsAwarded: 10,
                normalizedLocation: CGPoint(x: 0.5, y: 0.5)
            )
            let stationaryStamp = RatingStampPresentation.make(
                event: stationaryEvent,
                deterministic: true
            )
            let stationary = GameplayHitPresentation(
                event: stationaryEvent,
                stamp: stationaryStamp,
                stampPhase: .absorbing,
                isScoreVisible: false,
                speedBarDestination: speedBarDestination,
                pointsDestination: pointsDestination
            )
            XCTAssertEqual(
                stationary.stampPosition(in: CGSize(width: 351, height: 351)),
                stationaryStamp.position(in: CGSize(width: 351, height: 351))
            )
        }
    }

    func testFeedbackMotionPathIsAClampedDirectSegmentWithoutReversal() {
        let start = CGPoint(x: 280, y: 24)
        let destination = CGPoint(x: 120, y: 418)
        let progress: [CGFloat] = [0, 0.25, 0.5, 0.75, 1]
        let points = progress.map {
            FeedbackMotionPath.point(from: start, to: destination, progress: $0)
        }

        XCTAssertEqual(points.first, start)
        XCTAssertEqual(points.last, destination)
        for pair in zip(points, points.dropFirst()) {
            XCTAssertLessThan(pair.1.x, pair.0.x)
            XCTAssertGreaterThan(pair.1.y, pair.0.y)
            XCTAssertLessThan(
                hypot(pair.1.x - destination.x, pair.1.y - destination.y),
                hypot(pair.0.x - destination.x, pair.0.y - destination.y)
            )
        }
        XCTAssertEqual(
            FeedbackMotionPath.point(from: start, to: destination, progress: -1),
            start
        )
        XCTAssertEqual(
            FeedbackMotionPath.point(from: start, to: destination, progress: 2),
            destination
        )
    }

    func testGameplayHUDUsesRequestedZenAndFooterMetrics() {
        XCTAssertEqual(GameHUDMetrics.livesColorHex, "#ff5370")
        XCTAssertEqual(GameHUDMetrics.colorHeroOutlineWidth, 5)
        XCTAssertEqual(GameHUDMetrics.colorHeroGlowOpacity, 0.72)
        XCTAssertEqual(GameHUDMetrics.colorHeroGlowRadius, 10)
        XCTAssertEqual(GameplayLayoutMetrics.footerLift, 8)
        XCTAssertEqual(GameplayLayoutMetrics.adBannerHeight, 50)
        XCTAssertEqual(GameplayLayoutMetrics.reservedHeight(hasPet: false), 226)
        XCTAssertEqual(GameplayLayoutMetrics.reservedHeight(hasPet: true), 226)
        XCTAssertEqual(ZenAnyCellTokens.previewSide, 40)
        XCTAssertEqual(
            ZenAnyCellTokens.horizontalLogoGradientHexes,
            [
                "#16b887", "#39c85f", "#86bd3c", "#ffe659", "#ff9a56", "#ff6fc8",
                "#a58aff", "#69d7ff",
            ]
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
