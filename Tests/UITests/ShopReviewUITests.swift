import XCTest

@MainActor
final class ShopReviewUITests: XCTestCase {
    func testGuestSignInRoutes() {
        let app = launch()
        capture(app, "Guest menu")
        app.buttons["mode-multiplayer"].tap()
        expectProfile(app)
        app.buttons["Done"].tap()
        app.buttons["open-pet-shop"].tap()
        let pet = app.buttons["pet-action-foka"]
        XCTAssertTrue(pet.waitForExistence(timeout: 4))
        XCTAssertTrue(pet.label.contains("Sign in to buy"))
        capture(app, "Guest pets")
        pet.tap()
        expectProfile(app)
        app.buttons["Done"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["open-theme-shop"].tap()
        let theme = app.buttons["theme-action-light"]
        XCTAssertTrue(theme.waitForExistence(timeout: 4))
        XCTAssertTrue(theme.label.contains("Sign in to buy"))
        capture(app, "Guest themes")
        theme.tap()
        expectProfile(app)
        app.buttons["Done"].tap()
        app.buttons["theme-buy-coins"].tap()
        let pack = app.buttons["store-product-com.otcsoftware.pimpopom.coins.50.v1"]
        XCTAssertTrue(pack.waitForExistence(timeout: 4))
        XCTAssertTrue(pack.label.contains("Sign in to buy"))
        XCTAssertTrue(pack.isEnabled)
        XCTAssertFalse(app.staticTexts["APPLE-VERIFIED COINS"].exists)
        XCTAssertFalse(app.staticTexts["Sign in to purchase"].exists)
        capture(app, "Guest coin store")
        pack.tap()
        expectProfile(app)
    }

    func testSignedInShopAndProfilePresentation() {
        let app = launch(["--ui-test-pet-profile"])
        app.buttons["open-profile"].tap()
        let name = app.textFields["profile-nickname"]
        XCTAssertTrue(name.waitForExistence(timeout: 4))
        XCTAssertFalse((name.value as? String ?? "").isEmpty)
        XCTAssertNotEqual(name.value as? String, "Public nickname")
        XCTAssertTrue(app.buttons["profile-log-out"].exists)
        XCTAssertFalse(app.staticTexts["Enter a player name."].exists)
        capture(app, "Signed-in profile")
        app.buttons["Done"].tap()
        app.buttons["open-pet-shop"].tap()
        let pet = app.buttons["pet-action-tauta"]
        XCTAssertTrue(pet.waitForExistence(timeout: 4))
        XCTAssertTrue(pet.label.contains("Buy for 50 coins"))
        capture(app, "Signed-in pets")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["open-theme-shop"].tap()
        let theme = app.buttons["theme-action-pixel"]
        XCTAssertTrue(theme.waitForExistence(timeout: 4))
        XCTAssertTrue(theme.label.contains("Buy for 100 coins"))
        capture(app, "Signed-in themes")
        app.buttons["theme-buy-coins"].tap()
        let pack = app.buttons["store-product-com.otcsoftware.pimpopom.coins.50.v1"]
        XCTAssertTrue(pack.waitForExistence(timeout: 4))
        XCTAssertTrue(pack.label.contains("Buy for $2.99"))
        capture(app, "Signed-in coin store")
    }

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--deterministic-game"] + arguments
        app.launch()
        XCTAssertTrue(app.buttons["open-profile"].waitForExistence(timeout: 5))
        return app
    }

    private func expectProfile(_ app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["My Profile"].waitForExistence(timeout: 4))
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
