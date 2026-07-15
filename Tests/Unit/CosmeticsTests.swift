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

    func testPetPresentationNeverUsesUnapprovedPancakeBitmap() {
        let foka = PetPresentation.resolve("foka")
        XCTAssertEqual(foka.spriteAsset, "foka-sprite")
        XCTAssertFalse(foka.usesPlaceholderArt)

        let pancake = PetPresentation.resolve("pancake")
        XCTAssertNil(pancake.spriteAsset)
        XCTAssertNil(pancake.habitatAsset)
        XCTAssertTrue(pancake.usesPlaceholderArt)
    }

    private func profile(
        selectedPetID: String?,
        visible: Bool,
        specialPetID: String?
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
            equippedPetId: visible ? selectedPetID : nil,
            specialPetId: specialPetID,
            ownedThemeIds: ["classic", "disco"],
            selectedThemeId: "classic",
            isAdmin: false,
            createdAt: "2026-07-15T00:00:00Z",
            updatedAt: "2026-07-15T00:00:00Z"
        )
    }
}
