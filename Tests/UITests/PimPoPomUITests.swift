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

        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Preparing '")).count,
            0
        )
        let board = app.otherElements["reaction-board"]
        XCTAssertTrue(board.waitForExistence(timeout: 8))

        let feedback = app.staticTexts["game-feedback"]
        XCTAssertTrue(feedback.waitForExistence(timeout: 3))
        XCTAssertTrue(
            feedback.label == "Get ready" || feedback.label.hasPrefix("Tap "),
            "Unexpected start feedback: \(feedback.label)"
        )
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
        XCTAssertTrue(app.descendants(matching: .any)["result-score-card"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["result-stats"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["result-speed-ratings"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["result-save-panel"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["result-save-status"].exists)
        attachScreenshot(of: app, name: "SE Zen results")
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

    func testPetShopExposesCoinStoreAndApprovedPancakeArt() throws {
        let app = launch()
        openMenuControl("open-pet-shop", in: app)

        XCTAssertTrue(app.navigationBars["Pet Shop"].waitForExistence(timeout: 3))
        let buyCoins = app.buttons["pet-buy-coins"]
        XCTAssertTrue(buyCoins.waitForExistence(timeout: 3))
        let pancake = app.buttons["pet-preview-pancake"]
        for _ in 0..<8 where !pancake.exists {
            app.swipeUp()
        }
        XCTAssertTrue(pancake.exists)
        XCTAssertFalse(app.staticTexts["PLACEHOLDER"].exists)

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
        XCTAssertTrue(app.switches["glyphs-toggle"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.switches["sound-effects-toggle"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.switches["music-toggle"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Current Theme"].exists)
    }

    func testGlyphsOffReachesTheGameplayHeader() throws {
        let app = launch(additionalArguments: ["--ui-test-glyphs-off"])
        let settings = app.descendants(matching: .any)["open-settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        XCTAssertTrue(settings.label.contains("Glyphs off"))

        app.buttons["mode-normal"].tap()
        let target = app.descendants(matching: .any)["target-color"]
        XCTAssertTrue(target.waitForExistence(timeout: 8))
        XCTAssertFalse(target.label.localizedCaseInsensitiveContains("symbol"))
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
        XCTAssertLessThan(menuPet.frame.midX, app.frame.width * 0.84)
        arcade.tap()

        let gameplayPet = app.descendants(matching: .any)["gameplay-pet-muse"]
        XCTAssertTrue(gameplayPet.waitForExistence(timeout: 8))
        let board = app.descendants(matching: .any)["reaction-board"]
        XCTAssertTrue(board.waitForExistence(timeout: 3))
        XCTAssertEqual(board.frame.width, app.frame.width - 24, accuracy: 4)
        XCTAssertEqual(gameplayPet.frame.midX, app.frame.width * 0.40, accuracy: 4)
        XCTAssertTrue(app.buttons["game-menu"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["speed-streak"].exists)

        let feedback = app.staticTexts["game-feedback"]
        let targetDeadline = Date().addingTimeInterval(5)
        while Date() < targetDeadline, !feedback.label.hasPrefix("Tap ") {
            usleep(20_000)
        }
        XCTAssertTrue(feedback.label.hasPrefix("Tap "))
        board.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.50)).tap()
        XCTAssertTrue(waitForValue("right", on: gameplayPet))
        board.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.50)).tap()
        XCTAssertTrue(waitForValue("left", on: gameplayPet))
    }

    func testMenuPetSleepsAfterInactivityAndWakesOnTap() throws {
        let app = launch(additionalArguments: ["--ui-test-pet-profile"])
        let pet = app.descendants(matching: .any)["menu-pet-muse"]
        XCTAssertTrue(pet.waitForExistence(timeout: 4))

        XCTAssertEqual(
            XCTWaiter.wait(
                for: [
                    XCTNSPredicateExpectation(
                        predicate: NSPredicate(format: "value == 'Sleeping'"),
                        object: pet
                    )
                ],
                timeout: 7
            ),
            .completed
        )

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.25)).tap()
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [
                    XCTNSPredicateExpectation(
                        predicate: NSPredicate(format: "value != 'Sleeping'"),
                        object: pet
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
                        predicate: NSPredicate(format: "value == 'right'"),
                        object: pet
                    )
                ],
                timeout: 2
            ),
            .completed
        )

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.25)).tap()
        XCTAssertTrue(waitForValue("left", on: pet))

    }

    func testPancakeUsesRequestedMenuAndLeaderboardPlacement() throws {
        let app = launch(
            additionalArguments: [
                "--ui-test-pancake-profile", "--ui-test-leaderboard-fixture",
            ]
        )
        let menuPancake = app.descendants(matching: .any)["menu-pet-pancake"]
        XCTAssertTrue(menuPancake.waitForExistence(timeout: 4))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.25)).tap()
        XCTAssertTrue(waitForValue("left", on: menuPancake))
        attachScreenshot(of: app, name: "SE Pancake menu placement")

        openMenuControl("open-leaderboard", in: app)
        let leaderboardPancake =
            app.descendants(matching: .any)["leaderboard-entry-pet-ui-player"]
        XCTAssertTrue(leaderboardPancake.waitForExistence(timeout: 4))
        XCTAssertGreaterThan(leaderboardPancake.frame.height, 38)
        attachScreenshot(of: app, name: "SE Pancake leaderboard placement")
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

    func testMenuMatchesTheReviewedWebGeometryOnSE() throws {
        let app = launch(additionalArguments: ["--ui-test-pet-profile"])
        XCTAssertEqual(app.frame.width, 375, accuracy: 0.5)

        let dialog = app.descendants(matching: .any)["menu-dialog"]
        let wordmark = app.descendants(matching: .any)["menu-wordmark"]
        let coinStore = app.descendants(matching: .any)["open-coin-store"]
        let leaderboard = app.descendants(matching: .any)["open-leaderboard"]
        let profile = app.descendants(matching: .any)["open-profile"]
        let arcade = app.buttons["mode-normal"]
        let zen = app.buttons["mode-zen"]
        let achievements = app.descendants(matching: .any)["open-achievements"]
        let petShop = app.descendants(matching: .any)["open-pet-shop"]
        let themes = app.descendants(matching: .any)["open-theme-shop"]
        let settings = app.descendants(matching: .any)["open-settings"]
        let pet = app.descendants(matching: .any)["menu-pet-muse"]
        let removeAds = app.descendants(matching: .any)["remove-ads"]

        for element in [
            dialog, wordmark, coinStore, leaderboard, profile, arcade, zen, achievements,
            petShop, themes, settings, pet, removeAds,
        ] {
            XCTAssertTrue(element.waitForExistence(timeout: 3), element.identifier)
        }

        XCTAssertEqual(dialog.frame.minX, 12, accuracy: 1)
        XCTAssertEqual(dialog.frame.width, 351, accuracy: 1)
        XCTAssertLessThan(wordmark.frame.maxX, coinStore.frame.minX)
        XCTAssertEqual(leaderboard.value as? String, "Position #6")

        for utility in [coinStore, leaderboard, profile] {
            XCTAssertGreaterThanOrEqual(utility.frame.width, 44)
            XCTAssertGreaterThanOrEqual(utility.frame.height, 44)
        }

        XCTAssertEqual(arcade.frame.height, 56, accuracy: 1)
        XCTAssertEqual(zen.frame.height, 56, accuracy: 1)
        XCTAssertEqual(arcade.frame.width, zen.frame.width, accuracy: 1)
        XCTAssertLessThan(pet.frame.minY, arcade.frame.minY)
        XCTAssertGreaterThanOrEqual(achievements.frame.height, 51)
        XCTAssertEqual(petShop.frame.width, themes.frame.width, accuracy: 1)
        XCTAssertEqual(themes.frame.minX - petShop.frame.maxX, 8, accuracy: 1)
        XCTAssertGreaterThanOrEqual(petShop.frame.height, 48)
        XCTAssertGreaterThanOrEqual(settings.frame.height, 51)
        XCTAssertGreaterThanOrEqual(removeAds.frame.height, 44)

        let arcadeFrame = arcade.frame
        let settingsFrame = settings.frame
        app.swipeUp()
        XCTAssertEqual(arcade.frame, arcadeFrame)
        XCTAssertEqual(settings.frame, settingsFrame)
        XCTAssertFalse(app.staticTexts["backend-environment"].exists)
        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Hostinger'")).count,
            0
        )
    }

    func testRemoveAdsOpensAStoreKitPlaceholder() throws {
        let app = launch()
        let removeAds = app.buttons["remove-ads"]
        XCTAssertTrue(removeAds.waitForExistence(timeout: 3))
        removeAds.tap()

        XCTAssertTrue(app.navigationBars["Remove Ads"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.descendants(matching: .any)["remove-ads-store-placeholder"]
                .waitForExistence(timeout: 2)
        )
    }

    func testMotivationAdvancesOnTap() throws {
        let app = launch(additionalArguments: ["--ui-test-menu-motivation"])
        let motivation = app.buttons["menu-motivation"]
        XCTAssertTrue(motivation.waitForExistence(timeout: 3))
        let first = motivation.label
        motivation.tap()
        XCTAssertNotEqual(motivation.label, first)
    }

    func testLeaderboardAndProfileExposeWebParityContext() throws {
        let app = launch(
            additionalArguments: ["--ui-test-pet-profile", "--ui-test-leaderboard-fixture"]
        )

        let leaderboardButton = app.buttons["open-leaderboard"]
        XCTAssertTrue(leaderboardButton.waitForExistence(timeout: 3))
        leaderboardButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.descendants(matching: .any)["leaderboard-mode-tabs"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["leaderboard-position"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["leaderboard-entry-ui-player"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["speed-rating-distribution"].exists)
        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'does not prove'")).count,
            0
        )
        attachScreenshot(of: app, name: "SE leaderboard parity")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let profileButton = app.buttons["open-profile"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 3))
        profileButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["My Profile"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["profile-rank-card"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["leaderboard-entry-ui-player"].exists)
        let gameCenter = app.buttons["profile-game-center"]
        XCTAssertTrue(gameCenter.waitForExistence(timeout: 3))
        gameCenter.tap()
        XCTAssertTrue(app.alerts["Game Center"].waitForExistence(timeout: 2))
        app.alerts["Game Center"].buttons["OK"].tap()
        attachScreenshot(of: app, name: "SE profile parity")
    }

    func testEveryThemeHasADeterministicVisualFixture() throws {
        for themeID in ["classic", "disco", "light", "pixel"] {
            let app = launch(additionalArguments: ["--ui-test-theme", themeID])
            let dialog = app.descendants(matching: .any)["menu-dialog"]
            XCTAssertTrue(dialog.waitForExistence(timeout: 3))
            XCTAssertEqual(dialog.value as? String, "Theme \(themeID)")
            app.terminate()
        }
    }

    func testThemeShopUsesTwoColumnCardsAndShowsSelectedFixture() throws {
        let app = launch(additionalArguments: ["--ui-test-theme", "pixel"])
        openMenuControl("open-theme-shop", in: app)

        let classic = app.buttons["theme-action-classic"]
        let disco = app.buttons["theme-action-disco"]
        let light = app.buttons["theme-action-light"]
        let pixel = app.buttons["theme-action-pixel"]
        for card in [classic, disco, light, pixel] {
            XCTAssertTrue(card.waitForExistence(timeout: 3), card.identifier)
        }

        XCTAssertEqual(classic.frame.width, disco.frame.width, accuracy: 1)
        XCTAssertGreaterThan(
            min(classic.frame.maxY, disco.frame.maxY),
            max(classic.frame.minY, disco.frame.minY)
        )
        XCTAssertEqual(light.frame.minX, classic.frame.minX, accuracy: 1)
        XCTAssertGreaterThan(light.frame.minY, classic.frame.maxY)

        XCTAssertEqual(pixel.label, "Pixel")
        XCTAssertEqual(pixel.value as? String, "Selected")
        XCTAssertTrue(pixel.isEnabled)

        classic.tap()
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [
                    XCTNSPredicateExpectation(
                        predicate: NSPredicate(format: "value == 'Selected'"),
                        object: classic
                    )
                ],
                timeout: 2
            ),
            .completed
        )
        XCTAssertEqual(pixel.value as? String, "Select")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == 'Select'")).count, 0)
    }

    private func launch(additionalArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--deterministic-game", "--uitesting"] + additionalArguments
        app.launch()
        XCTAssertTrue(
            app.descendants(matching: .any)["menu-dialog"].waitForExistence(timeout: 3)
        )
        return app
    }

    private func openMenuControl(_ identifier: String, in app: XCUIApplication) {
        let control = app.descendants(matching: .any)[identifier]
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

    private func attachScreenshot(of app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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

    private func waitForValue(
        _ value: String,
        on element: XCUIElement,
        timeout: TimeInterval = 3
    ) -> Bool {
        XCTWaiter.wait(
            for: [
                XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "value == %@", value),
                    object: element
                )
            ],
            timeout: timeout
        ) == .completed
    }

}
