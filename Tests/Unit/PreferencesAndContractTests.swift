import XCTest

@testable import PimPoPom

@MainActor
final class PreferencesAndContractTests: XCTestCase {
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

        initial.soundEffectsEnabled = false
        initial.soundEffectsVolume = 0.25
        initial.musicEnabled = true
        initial.musicVolume = 0.70
        initial.selectedThemeID = "disco"

        let restored = AppPreferences(defaults: defaults)
        XCTAssertFalse(restored.soundEffectsEnabled)
        XCTAssertTrue(restored.musicEnabled)
        XCTAssertEqual(restored.soundEffectsVolume, 0.25, accuracy: 0.0001)
        XCTAssertEqual(restored.musicVolume, 0.70, accuracy: 0.0001)
        XCTAssertEqual(restored.selectedThemeID, "disco")
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
