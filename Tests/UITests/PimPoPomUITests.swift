import XCTest

final class PimPoPomUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testArcadeLaunchesAndAcceptsFirstTap() throws {
        let app = launch()
        let arcade = app.buttons["mode-normal"]
        XCTAssertTrue(arcade.waitForExistence(timeout: 8))
        arcade.tap()

        let board = app.otherElements["reaction-board"]
        XCTAssertTrue(board.waitForExistence(timeout: 8))

        let feedback = app.staticTexts["game-feedback"]
        let targetDeadline = Date().addingTimeInterval(5)
        while Date() < targetDeadline, !feedback.label.hasPrefix("Tap ") {
            usleep(20_000)
        }
        XCTAssertTrue(feedback.label.hasPrefix("Tap "), "A target never became active")
        board.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let score = app.staticTexts["game-score"]
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [
                    XCTNSPredicateExpectation(
                        predicate: NSPredicate(format: "label != 'SCORE, 0'"),
                        object: score
                    )
                ],
                timeout: 2
            ),
            .completed,
            "Expected a scored first tap, got: \(score.label)"
        )
    }

    func testZenCanEndIntoResults() throws {
        let app = launch()
        let zen = app.buttons["mode-zen"]
        XCTAssertTrue(zen.waitForExistence(timeout: 8))
        zen.tap()

        let endButton = app.buttons["end-zen-run"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 8))
        endButton.tap()

        let resultTitle = app.staticTexts["results-title"]
        XCTAssertTrue(resultTitle.waitForExistence(timeout: 2))
        XCTAssertEqual(resultTitle.label, "Zen results")
    }

    func testThemeShopExposesCoinStorePlaceholder() throws {
        let app = launch()
        openMenuControl("open-theme-shop", in: app)

        XCTAssertTrue(app.navigationBars["Theme Shop"].waitForExistence(timeout: 3))
        let buyCoins = app.buttons["theme-buy-coins"]
        XCTAssertTrue(buyCoins.waitForExistence(timeout: 3))
        buyCoins.tap()

        XCTAssertTrue(app.navigationBars["Buy Coins"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.staticTexts["StoreKit coin packs are disabled in this internal alpha."]
                .waitForExistence(timeout: 2)
        )
    }

    func testPetShopExposesCoinStoreAndPlaceholderPetArt() throws {
        let app = launch()
        openMenuControl("open-pet-shop", in: app)

        XCTAssertTrue(app.navigationBars["Pet Shop"].waitForExistence(timeout: 3))
        let buyCoins = app.buttons["pet-buy-coins"]
        XCTAssertTrue(buyCoins.waitForExistence(timeout: 3))
        XCTAssertTrue(scrollToText("PLACEHOLDER", in: app))

        for _ in 0..<8 where !buyCoins.isHittable {
            app.swipeDown()
        }
        XCTAssertTrue(buyCoins.isHittable)
        buyCoins.tap()
        XCTAssertTrue(app.navigationBars["Buy Coins"].waitForExistence(timeout: 3))
    }

    func testSettingsExposeIndependentAudioControls() throws {
        let app = launch()
        openMenuControl("open-settings", in: app)

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.switches["sound-effects-toggle"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.switches["music-toggle"].waitForExistence(timeout: 2))
    }

    func testPetShopPreviewAnimatesOnlyAfterTapAndStops() throws {
        let app = launch()
        openMenuControl("open-pet-shop", in: app)

        let preview = app.buttons["pet-preview-foka"]
        XCTAssertTrue(preview.waitForExistence(timeout: 3))
        XCTAssertEqual(preview.value as? String, "Idle · preview 0")
        usleep(700_000)
        XCTAssertEqual(preview.value as? String, "Idle · preview 0")
        preview.tap()
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [
                    XCTNSPredicateExpectation(
                        predicate: NSPredicate(format: "value CONTAINS 'preview 1'"),
                        object: preview
                    )
                ],
                timeout: 2
            ),
            .completed
        )
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [
                    XCTNSPredicateExpectation(
                        predicate: NSPredicate(format: "value == 'Idle · preview 1'"),
                        object: preview
                    )
                ],
                timeout: 3
            ),
            .completed
        )
    }

    func testBackendSpecialPetAppearsOnMenuAndGameplay() throws {
        let app = launch(additionalArguments: ["--ui-test-pet-profile"])
        let menuPet = app.descendants(matching: .any)["menu-pet-muse"]
        XCTAssertTrue(menuPet.waitForExistence(timeout: 4))

        let arcade = app.buttons["mode-normal"]
        XCTAssertTrue(arcade.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(menuPet.frame.midX, app.frame.midX)
        arcade.tap()

        let gameplayPet = app.descendants(matching: .any)["gameplay-pet-muse"]
        XCTAssertTrue(gameplayPet.waitForExistence(timeout: 8))
    }

    func testResponseProgressDrainsWhileTargetIsActive() throws {
        let app = launch()
        let arcade = app.buttons["mode-normal"]
        XCTAssertTrue(arcade.waitForExistence(timeout: 3))
        arcade.tap()

        let feedback = app.staticTexts["game-feedback"]
        let targetDeadline = Date().addingTimeInterval(8)
        while Date() < targetDeadline, !feedback.label.hasPrefix("Tap ") {
            usleep(20_000)
        }
        XCTAssertTrue(feedback.label.hasPrefix("Tap "))

        let progress = app.descendants(matching: .any)["response-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 2))
        let first = try XCTUnwrap(Int(progress.value as? String ?? ""))
        XCTAssertGreaterThanOrEqual(first, 70, "A newly observed target must retain most of its bar.")

        var samples = [first]
        for _ in 0..<3 {
            usleep(250_000)
            samples.append(try XCTUnwrap(Int(progress.value as? String ?? "")))
        }
        for (earlier, later) in zip(samples, samples.dropFirst()) {
            XCTAssertLessThanOrEqual(later, earlier, "The response bar must never grow during a target.")
        }
        XCTAssertLessThan(try XCTUnwrap(samples.last), first)
    }

    func testPetSelectHideAndShowActionsUpdateTheShop() throws {
        let app = launch(additionalArguments: ["--ui-test-pet-profile"])
        openMenuControl("open-pet-shop", in: app)

        let keshaAction = app.buttons["pet-action-kesha"]
        XCTAssertTrue(keshaAction.waitForExistence(timeout: 3))
        XCTAssertEqual(keshaAction.label, "Select")
        keshaAction.tap()
        XCTAssertTrue(waitForLabel("Hide", on: keshaAction))

        keshaAction.tap()
        XCTAssertTrue(waitForLabel("Show", on: keshaAction))

        keshaAction.tap()
        XCTAssertTrue(waitForLabel("Hide", on: keshaAction))
        XCTAssertTrue(app.staticTexts["pet-shop-status"].label.contains("special companion remains visible"))
    }

    private func launch(additionalArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--deterministic-game", "--uitesting"] + additionalArguments
        app.launch()
        let environment = app.staticTexts["backend-environment"]
        XCTAssertTrue(environment.waitForExistence(timeout: 3))
        XCTAssertEqual(environment.label, "Offline UI Test")
        return app
    }

    private func openMenuControl(_ identifier: String, in app: XCUIApplication) {
        let control = app.descendants(matching: .any)[identifier]
        for _ in 0..<5 where !control.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(control.exists, "Missing menu control: \(identifier)")
        XCTAssertTrue(control.isHittable, "Menu control is not hittable: \(identifier)")
        control.tap()
    }

    private func scrollToText(_ label: String, in app: XCUIApplication) -> Bool {
        let text = app.staticTexts[label]
        for _ in 0..<8 where !text.exists {
            app.swipeUp()
        }
        return text.exists
    }

    private func waitForLabel(
        _ label: String,
        on element: XCUIElement,
        timeout: TimeInterval = 3
    ) -> Bool {
        XCTWaiter.wait(
            for: [
                XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "label == %@", label),
                    object: element
                )
            ],
            timeout: timeout
        ) == .completed
    }
}
