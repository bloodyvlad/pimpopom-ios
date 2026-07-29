import XCTest

final class PimPoPomUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testArcadeLaunchesAndAcceptsFirstTap() throws {
        let app = launch(
            additionalArguments: ["--ui-test-reaction-ms", "200", "--ui-test-glyphs-on"]
        )
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
        let targetColor = app.descendants(matching: .any)["target-color"]
        XCTAssertTrue(targetColor.waitForExistence(timeout: 2))
        if feedback.label == "Get ready" {
            XCTAssertEqual(targetColor.label, "Target color pending")
        }
        let targetDeadline = Date().addingTimeInterval(5)
        while Date() < targetDeadline, !feedback.label.hasPrefix("Tap ") {
            usleep(20_000)
        }
        XCTAssertTrue(feedback.label.hasPrefix("Tap "), "A target never became active")
        XCTAssertNotEqual(targetColor.label, "Target color pending")
        board.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        usleep(140_000)
        attachScreenshot(of: app, name: "iPhone 17 straight two-line tap feedback")
        usleep(400_000)
        attachScreenshot(of: app, name: "iPhone 17 two-line tap feedback fading")

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

        let target = app.descendants(matching: .any)["target-color"]
        XCTAssertTrue(target.waitForExistence(timeout: 3))
        XCTAssertEqual(target.label, "Target color Any")
        XCTAssertFalse(target.label.contains("☯"))
        XCTAssertFalse(target.label.localizedCaseInsensitiveContains("symbol"))

        let lives = app.descendants(matching: .any)["game-lives"]
        XCTAssertTrue(lives.waitForExistence(timeout: 2))
        XCTAssertTrue(lives.label.contains("∞"))

        let speedBar = app.descendants(matching: .any)["speed-streak"]
        XCTAssertTrue(speedBar.waitForExistence(timeout: 2))
        XCTAssertEqual(speedBar.label, "Speed bar")

        XCTAssertFalse(app.descendants(matching: .any)["ad-slot-activeGameplay"].exists)
        XCTAssertFalse(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] 'ad' OR label CONTAINS[c] 'advertisement'")
            ).firstMatch.exists)
        attachScreenshot(
            of: app,
            name: "iPhone 17 Zen horizontal logo gradient without disabled ad UI"
        )

        endButton.tap()

        let resultTitle = app.staticTexts["results-title"]
        XCTAssertTrue(resultTitle.waitForExistence(timeout: 2))
        XCTAssertEqual(resultTitle.label, "Zen results")
        XCTAssertTrue(app.descendants(matching: .any)["result-score-card"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["result-stats"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["result-speed-ratings"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["ad-slot-results"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["result-save-panel"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["result-save-status"].exists)
        attachScreenshot(of: app, name: "iPhone 17 Zen results")
    }

    func testThemeShopExposesAccountBoundCoinStore() throws {
        let app = launch()
        openMenuControl("open-theme-shop", in: app)

        XCTAssertTrue(app.navigationBars["Theme Shop"].waitForExistence(timeout: 3))
        let buyCoins = app.buttons["theme-buy-coins"]
        XCTAssertTrue(buyCoins.waitForExistence(timeout: 3))
        buyCoins.tap()

        XCTAssertTrue(app.navigationBars["Buy Coins"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Sign in to purchase"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["store-account-gate"].exists)
        XCTAssertTrue(app.staticTexts["50 Coins and Ad-free"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["$2.99"].exists)
        XCTAssertFalse(
            app.buttons["store-product-com.otcsoftware.pimpopom.coins.50.v1"].isEnabled
        )
    }

    func testCoinStoreReviewPresentation() throws {
        let app = launch(additionalArguments: ["--ui-test-storekit-profile"])
        openMenuControl("open-theme-shop", in: app)

        XCTAssertTrue(app.navigationBars["Theme Shop"].waitForExistence(timeout: 3))
        let buyCoins = app.buttons["theme-buy-coins"]
        XCTAssertTrue(buyCoins.waitForExistence(timeout: 3))
        buyCoins.tap()

        XCTAssertTrue(app.navigationBars["Buy Coins"].waitForExistence(timeout: 3))
        let firstPack = app.buttons[
            "store-product-com.otcsoftware.pimpopom.coins.50.v1"
        ]
        XCTAssertTrue(firstPack.waitForExistence(timeout: 2))
        XCTAssertTrue(firstPack.isEnabled)
        XCTAssertTrue(app.descendants(matching: .any)["store-wallet"].exists)
        XCTAssertTrue(scrollToElement(firstPack, in: app))
        attachScreenshot(of: app, name: "IAP review 50 coins")

        for (productID, name) in [
            ("com.otcsoftware.pimpopom.coins.100.v1", "IAP review 100 coins"),
            ("com.otcsoftware.pimpopom.coins.500.v1", "IAP review 500 coins"),
            ("com.otcsoftware.pimpopom.coins.1000.v1", "IAP review 1000 coins"),
        ] {
            let product = app.buttons["store-product-\(productID)"]
            XCTAssertTrue(product.waitForExistence(timeout: 2))
            XCTAssertTrue(product.isEnabled)
            XCTAssertTrue(scrollToElement(product, in: app))
            attachScreenshot(of: app, name: name)
        }
    }

    func testAchievementsClaimUsesTheAuthoritativeRewardFixture() throws {
        let app = launch(additionalArguments: ["--ui-test-achievements-profile"])
        let menuButton = app.buttons["open-achievements"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 3))
        XCTAssertEqual(menuButton.value as? String, "1 reward ready to claim")
        menuButton.tap()

        XCTAssertTrue(app.navigationBars["Achievements"].waitForExistence(timeout: 3))
        let progress = app.descendants(matching: .any)["achievements-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 2))
        XCTAssertEqual(progress.value as? String, "1 of 5")
        XCTAssertFalse(
            app.descendants(matching: .any)["achievements-coin-balance"].exists
        )

        for id in [
            "complete_arcade", "godlike_speed", "collect_5_coins", "score_over_100k",
            "buy_a_pet",
        ] {
            XCTAssertTrue(
                app.descendants(matching: .any)["achievement-card-\(id)"]
                    .waitForExistence(timeout: 2),
                id
            )
        }

        let claimable = app.descendants(matching: .any)["achievement-card-complete_arcade"]
        XCTAssertEqual(claimable.value as? String, "Ready to claim. Reward: 1 coin")
        claimable.tap()
        XCTAssertTrue(waitForValue("Claimed. Reward: 1 coin", on: claimable))
        XCTAssertEqual(progress.value as? String, "2 of 5")
        XCTAssertTrue(
            waitForLabel(
                "Complete Arcade mode claimed — 1 coin credited.",
                on: app.staticTexts["achievements-status"]
            )
        )

        app.navigationBars["Achievements"].buttons["Done"].tap()
        XCTAssertTrue(menuButton.waitForExistence(timeout: 2))
        XCTAssertEqual(menuButton.value as? String, "2 / 5 claimed")
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

    func testUnaffordableThemeAndPetOpenCoinStoreWithoutShortfallCopy() throws {
        let themeApp = launch(additionalArguments: ["--ui-test-pet-profile"])
        openMenuControl("open-theme-shop", in: themeApp)

        let pixel = themeApp.buttons["theme-action-pixel"]
        XCTAssertTrue(pixel.waitForExistence(timeout: 3))
        pixel.tap()
        XCTAssertTrue(themeApp.navigationBars["Buy Coins"].waitForExistence(timeout: 3))
        XCTAssertFalse(themeApp.staticTexts["You need 25 more coins for Pixel."].exists)

        themeApp.terminate()
        let petApp = launch(additionalArguments: ["--ui-test-pet-profile"])
        openMenuControl("open-pet-shop", in: petApp)
        XCTAssertFalse(
            petApp.staticTexts["Choose one pet to show, or hide the current companion."].exists
        )

        let misha = petApp.buttons["pet-action-misha"]
        XCTAssertTrue(scrollToElement(misha, in: petApp))
        misha.tap()
        XCTAssertTrue(petApp.navigationBars["Buy Coins"].waitForExistence(timeout: 3))
        XCTAssertFalse(petApp.staticTexts["You need 25 more coins for Misha."].exists)
        XCTAssertFalse(petApp.staticTexts["Foka is yours and selected."].exists)
    }

    func testSettingsExposeIndependentAudioControls() throws {
        let app = launch()
        openMenuControl("open-settings", in: app)

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        let glowIcon = app.buttons["app-icon-glow"]
        let lightIcon = app.buttons["app-icon-light"]
        let pixelIcon = app.buttons["app-icon-pixel"]
        XCTAssertTrue(glowIcon.waitForExistence(timeout: 2))
        XCTAssertTrue(lightIcon.waitForExistence(timeout: 2))
        XCTAssertTrue(pixelIcon.waitForExistence(timeout: 2))
        XCTAssertEqual(
            [glowIcon, lightIcon, pixelIcon]
                .filter { $0.value as? String == "Selected" }
                .count,
            1
        )
        attachScreenshot(of: app, name: "iPhone 17 alternate app icons")
        XCTAssertTrue(app.switches["glyphs-toggle"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.switches["sound-effects-toggle"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.switches["music-toggle"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Current Theme"].exists)
    }

    func testFakeAdsAppearOnMenuGameplayAndResults() throws {
        let app = launch(additionalArguments: ["--ui-test-ads-enabled"])
        let menuSlot = app.descendants(matching: .any)["ad-slot-menu"]
        XCTAssertTrue(menuSlot.waitForExistence(timeout: 3))
        XCTAssertEqual(menuSlot.frame.height, 50, accuracy: 1)
        XCTAssertEqual(menuSlot.value as? String, "Loaded")
        let menuBanner = app.descendants(matching: .any)["fake-ad-banner"]
        XCTAssertTrue(menuBanner.waitForExistence(timeout: 2))
        XCTAssertEqual(menuBanner.frame.width, 320, accuracy: 1)
        XCTAssertEqual(menuBanner.frame.height, 50, accuracy: 1)
        XCTAssertEqual(menuBanner.frame.midX, menuSlot.frame.midX, accuracy: 1)
        XCTAssertLessThanOrEqual(menuBanner.frame.maxY, app.frame.maxY + 0.5)

        let removeAds = app.descendants(matching: .any)["remove-ads"]
        let copyright = app.descendants(matching: .any)["menu-copyright"]
        let coinStore = app.descendants(matching: .any)["open-coin-store"]
        let wordmark = app.descendants(matching: .any)["menu-wordmark"]
        XCTAssertTrue(removeAds.exists)
        XCTAssertTrue(copyright.exists)
        let usesCompactRemoveAds = app.frame.height <= 667
        XCTAssertEqual(removeAds.frame.width, usesCompactRemoveAds ? 44 : 112, accuracy: 1)
        XCTAssertEqual(removeAds.frame.height, 44, accuracy: 1)
        if usesCompactRemoveAds {
            XCTAssertLessThan(wordmark.frame.maxX, removeAds.frame.minX)
            XCTAssertLessThan(removeAds.frame.maxX, coinStore.frame.minX)
            XCTAssertEqual(removeAds.frame.midY, coinStore.frame.midY, accuracy: 1)
        } else {
            XCTAssertLessThan(removeAds.frame.maxY, copyright.frame.minY)
        }
        XCTAssertLessThan(copyright.frame.maxY, menuSlot.frame.minY)
        XCTAssertLessThanOrEqual(menuSlot.frame.minY - copyright.frame.maxY, 16)

        app.buttons["mode-zen"].tap()
        let activeSlot = app.descendants(matching: .any)["ad-slot-activeGameplay"]
        XCTAssertTrue(activeSlot.waitForExistence(timeout: 8))
        XCTAssertEqual(activeSlot.frame.height, 50, accuracy: 1)
        XCTAssertEqual(activeSlot.value as? String, "Loaded")
        let gameplayBanner = app.descendants(matching: .any)["fake-ad-banner"]
        XCTAssertTrue(gameplayBanner.waitForExistence(timeout: 2))
        XCTAssertEqual(gameplayBanner.frame.width, 320, accuracy: 1)
        XCTAssertEqual(gameplayBanner.frame.midX, activeSlot.frame.midX, accuracy: 1)
        let speedBar = app.descendants(matching: .any)["speed-streak"]
        XCTAssertTrue(speedBar.exists)
        XCTAssertLessThanOrEqual(speedBar.frame.maxY, activeSlot.frame.minY)
        attachScreenshot(of: app, name: "iPhone 17 gameplay fixed banner below Speed Bar")

        app.buttons["end-zen-run"].tap()
        XCTAssertTrue(app.staticTexts["results-title"].waitForExistence(timeout: 3))
        let resultsSlot = app.descendants(matching: .any)["ad-slot-results"]
        XCTAssertTrue(resultsSlot.waitForExistence(timeout: 3))
        XCTAssertEqual(resultsSlot.frame.height, 50, accuracy: 1)
        XCTAssertEqual(resultsSlot.value as? String, "Loaded")
        let resultsBanner = app.descendants(matching: .any)["fake-ad-banner"]
        XCTAssertTrue(resultsBanner.waitForExistence(timeout: 2))
        XCTAssertEqual(resultsBanner.frame.width, 320, accuracy: 1)
        XCTAssertEqual(resultsBanner.frame.midX, resultsSlot.frame.midX, accuracy: 1)
        attachScreenshot(of: app, name: "iPhone 17 Results fixed banner")
    }

    func testRankedSaveStatusFitsAboveResultsBannerWithoutScrolling() throws {
        let app = launch(
            additionalArguments: ["--ui-test-ads-enabled", "--ui-test-storekit-profile"]
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["fake-ad-banner"].waitForExistence(timeout: 5)
        )
        app.buttons["mode-normal"].tap()

        XCTAssertTrue(app.staticTexts["results-title"].waitForExistence(timeout: 30))
        let status = app.descendants(matching: .any)["result-save-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 3))
        XCTAssertTrue(status.label.contains("Score saved to leaderboard"))

        let resultsSlot = app.descendants(matching: .any)["ad-slot-results"]
        XCTAssertTrue(resultsSlot.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(status.frame.minY, app.frame.minY)
        XCTAssertLessThanOrEqual(status.frame.maxY, resultsSlot.frame.minY)
        XCTAssertTrue(app.buttons["results-menu"].isHittable)
        attachScreenshot(of: app, name: "iPhone 17 ranked save above Results banner")
    }

    func testAdFreePlayerSeesNoRemoveAdsControlOrBannerArea() throws {
        let app = launch(
            additionalArguments: ["--ui-test-ads-enabled", "--ui-test-ad-free"]
        )
        let profile = app.descendants(matching: .any)["open-profile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 3))
        XCTAssertTrue(waitForLabel("Profile. Signed in", on: profile))

        let removeAds = app.descendants(matching: .any)["remove-ads"]
        let menuSlot = app.descendants(matching: .any)["ad-slot-menu"]
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [
                    XCTNSPredicateExpectation(
                        predicate: NSPredicate(format: "exists == false"),
                        object: menuSlot
                    )
                ],
                timeout: 2
            ),
            .completed
        )
        XCTAssertFalse(removeAds.exists)
        XCTAssertTrue(app.descendants(matching: .any)["menu-copyright"].exists)

        app.buttons["mode-zen"].tap()
        let endButton = app.buttons["end-zen-run"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 8))
        XCTAssertFalse(app.descendants(matching: .any)["ad-slot-activeGameplay"].exists)
        endButton.tap()
        XCTAssertTrue(app.staticTexts["results-title"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["ad-slot-results"].exists)
    }

    func testRequiredPrivacyChoicesAreAccessibleThroughSettings() throws {
        let app = launch(
            additionalArguments: ["--ui-test-ads-enabled", "--ui-test-privacy-required"]
        )
        openMenuControl("open-settings", in: app)

        let privacyChoices = app.buttons["privacy-choices"]
        for _ in 0..<10 where !privacyChoices.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(privacyChoices.exists)
        XCTAssertEqual(privacyChoices.label, "Privacy choices")
        XCTAssertTrue(privacyChoices.isHittable)
        let privacyDisclosure = app.images["privacy-choices-disclosure"]
        XCTAssertTrue(privacyDisclosure.exists)
        XCTAssertGreaterThanOrEqual(
            privacyChoices.frame.maxX - privacyDisclosure.frame.maxX,
            12
        )
        XCTAssertFalse(app.descendants(matching: .any)["ad-slot-menu"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["fake-ad-banner"].exists)
        privacyChoices.tap()
        XCTAssertTrue(privacyChoices.waitForExistence(timeout: 2))
    }

    func testChangeIconDeepLinkOpensIconSettings() throws {
        let app = launch()
        app.terminate()
        app.open(URL(string: "pimpopom://settings/icon")!)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let openButton = springboard.alerts.buttons["Open"]
        if openButton.waitForExistence(timeout: 2) {
            openButton.tap()
        }

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["app-icon-glow"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["app-icon-light"].exists)
        XCTAssertTrue(app.buttons["app-icon-pixel"].exists)
        XCTAssertTrue(app.navigationBars["Settings"].buttons["Done"].exists)
        attachScreenshot(of: app, name: "iPhone 17 Change Icon deep link")
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
        let speedBar = app.descendants(matching: .any)["speed-streak"]
        XCTAssertTrue(speedBar.exists)

        let feedback = app.staticTexts["game-feedback"]
        let targetDeadline = Date().addingTimeInterval(5)
        while Date() < targetDeadline, !feedback.label.hasPrefix("Tap ") {
            usleep(20_000)
        }
        XCTAssertTrue(feedback.label.hasPrefix("Tap "))
        board.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.50)).tap()
        XCTAssertTrue(waitForValue("right", on: gameplayPet))
        gameplayPet.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.50)).tap()
        XCTAssertTrue(waitForValue("front", on: gameplayPet))
        board.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.50)).tap()
        XCTAssertTrue(waitForValue("left", on: gameplayPet))
        let petCenterInSpeedBar = min(
            1,
            max(0, (gameplayPet.frame.midX - speedBar.frame.minX) / speedBar.frame.width)
        )
        speedBar.coordinate(
            withNormalizedOffset: CGVector(dx: petCenterInSpeedBar, dy: 0.75)
        ).tap()
        XCTAssertTrue(waitForValue("front", on: gameplayPet))
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

        pet.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.50)).tap()
        XCTAssertTrue(waitForValue("front", on: pet))

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
        attachScreenshot(of: app, name: "iPhone 17 Pancake menu placement")

        openMenuControl("open-leaderboard", in: app)
        let leaderboardPancake =
            app.descendants(matching: .any)["leaderboard-entry-pet-ui-player"]
        XCTAssertTrue(leaderboardPancake.waitForExistence(timeout: 4))
        XCTAssertGreaterThan(leaderboardPancake.frame.height, 38)
        attachScreenshot(of: app, name: "iPhone 17 Pancake leaderboard placement")
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

    func testScreenshotFixtureAutoplaysAnUnlockedPixelProfile() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--deterministic-game",
            "--uitesting",
            "--screenshot-mode",
            "--screenshot-screen=arcade",
            "--screenshot-theme=pixel",
            "--screenshot-pet=foka",
            "--screenshot-autoplay",
            "--screenshot-seed=42",
        ]
        app.launch()

        let board = app.descendants(matching: .any)["reaction-board"]
        XCTAssertTrue(board.waitForExistence(timeout: 8))
        XCTAssertEqual(board.value as? String, "1 by 1")
        let pet = app.descendants(matching: .any)["gameplay-pet-foka"]
        XCTAssertTrue(pet.waitForExistence(timeout: 3))

        let score = app.descendants(matching: .any)["game-score"]
        XCTAssertTrue(score.waitForExistence(timeout: 3))
        let autoplayDeadline = Date().addingTimeInterval(5)
        while Date() < autoplayDeadline, score.label.filter(\.isNumber) == "0" {
            usleep(20_000)
        }
        XCTAssertNotEqual(score.label.filter(\.isNumber), "0")

        var observedDirectionalFacing = false
        let facingDeadline = Date().addingTimeInterval(3)
        while Date() < facingDeadline {
            if let value = pet.value as? String,
                value != "front",
                value != "Sleeping"
            {
                observedDirectionalFacing = true
                break
            }
            usleep(20_000)
        }
        XCTAssertTrue(observedDirectionalFacing)
    }

    func testScreenshotFixtureAutoplaysMenuPetFacing() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--screenshot-mode",
            "--screenshot-screen=menu",
            "--screenshot-theme=pixel",
            "--screenshot-pet=foka",
            "--screenshot-autoplay",
            "--screenshot-seed=43",
        ]
        app.launch()

        let pet = app.descendants(matching: .any)["menu-pet-foka"]
        XCTAssertTrue(pet.waitForExistence(timeout: 5))
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [
                    XCTNSPredicateExpectation(
                        predicate: NSPredicate(
                            format: "value != 'front' AND value != 'Sleeping'"
                        ),
                        object: pet
                    )
                ],
                timeout: 3
            ),
            .completed
        )
    }

    func testScreenshotFixtureOpensSyntheticMarketingScreens() {
        let app = XCUIApplication()

        app.launchArguments = [
            "--uitesting",
            "--screenshot-mode",
            "--screenshot-screen=leaderboard",
            "--screenshot-theme=pixel",
        ]
        app.launch()
        XCTAssertTrue(
            app.descendants(matching: .any)["leaderboard-results"]
                .waitForExistence(timeout: 6)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["leaderboard-entry-ui-rank-1"]
                .waitForExistence(timeout: 2)
        )
        attachScreenshot(of: app, name: "Pixel leaderboard without text shadows")

        app.terminate()
        app.launchArguments = [
            "--uitesting",
            "--screenshot-mode",
            "--screenshot-screen=profile",
            "--screenshot-theme=pixel",
        ]
        app.launch()
        XCTAssertTrue(
            app.descendants(matching: .any)["profile-apple-sign-in"]
                .waitForExistence(timeout: 6)
        )
        XCTAssertFalse(app.buttons["Log out"].exists)

        app.terminate()
        app.launchArguments = [
            "--uitesting",
            "--screenshot-mode",
            "--screenshot-screen=achievements",
            "--screenshot-theme=pixel",
        ]
        app.launch()
        let achievement =
            app.descendants(matching: .any)["achievement-card-complete_arcade"]
        XCTAssertTrue(achievement.waitForExistence(timeout: 6))
        XCTAssertTrue((achievement.value as? String)?.contains("Ready to claim") == true)
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

    func testMenuMatchesTheReviewedWebGeometryOnPrimarySimulator() throws {
        let app = launch(additionalArguments: ["--ui-test-pet-profile"])
        XCTAssertEqual(app.frame.width, 402, accuracy: 0.5)

        let dialog = app.descendants(matching: .any)["menu-dialog"]
        let wordmark = app.descendants(matching: .any)["menu-wordmark"]
        let coinStore = app.descendants(matching: .any)["open-coin-store"]
        let leaderboard = app.descendants(matching: .any)["open-leaderboard"]
        let profile = app.descendants(matching: .any)["open-profile"]
        let gameModeLabel = app.descendants(matching: .any)["menu-game-mode-label"]
        let arcade = app.buttons["mode-normal"]
        let zen = app.buttons["mode-zen"]
        let multiplayer = app.descendants(matching: .any)["mode-multiplayer"]
        let achievements = app.descendants(matching: .any)["open-achievements"]
        let petShop = app.descendants(matching: .any)["open-pet-shop"]
        let themes = app.descendants(matching: .any)["open-theme-shop"]
        let settings = app.descendants(matching: .any)["open-settings"]
        let pet = app.descendants(matching: .any)["menu-pet-muse"]
        let removeAds = app.descendants(matching: .any)["remove-ads"]

        for element in [
            dialog, wordmark, coinStore, leaderboard, profile, gameModeLabel, arcade, zen,
            multiplayer, achievements, petShop, themes, settings, pet, removeAds,
        ] {
            XCTAssertTrue(element.waitForExistence(timeout: 3), element.identifier)
        }

        XCTAssertEqual(dialog.frame.minX, 12, accuracy: 1)
        XCTAssertEqual(dialog.frame.width, app.frame.width - 24, accuracy: 1)
        XCTAssertLessThan(wordmark.frame.maxX, coinStore.frame.minX)
        XCTAssertEqual(leaderboard.value as? String, "Position #6")

        for utility in [coinStore, leaderboard, profile] {
            XCTAssertGreaterThanOrEqual(utility.frame.width, 44)
            XCTAssertGreaterThanOrEqual(utility.frame.height, 44)
        }

        XCTAssertEqual(arcade.frame.height, 56, accuracy: 1)
        XCTAssertEqual(zen.frame.height, 56, accuracy: 1)
        XCTAssertEqual(arcade.frame.width, zen.frame.width, accuracy: 1)
        XCTAssertLessThan(gameModeLabel.frame.maxY, arcade.frame.minY)
        XCTAssertLessThan(arcade.frame.maxY, zen.frame.minY)
        XCTAssertLessThan(zen.frame.maxY, multiplayer.frame.minY)
        XCTAssertLessThan(multiplayer.frame.maxY, achievements.frame.minY)
        XCTAssertGreaterThanOrEqual(achievements.frame.minY - multiplayer.frame.maxY, 9)
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
        assertFrame(arcade.frame, matches: arcadeFrame, accuracy: 0.5)
        assertFrame(settings.frame, matches: settingsFrame, accuracy: 0.5)
        XCTAssertFalse(app.staticTexts["backend-environment"].exists)
        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Hostinger'")).count,
            0
        )
    }

    func testRemoveAdsOpensRestorableStore() throws {
        let app = launch()
        let removeAds = app.buttons["remove-ads"]
        XCTAssertTrue(removeAds.waitForExistence(timeout: 3))
        removeAds.tap()

        XCTAssertTrue(app.navigationBars["Remove Ads"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.descendants(matching: .any)["remove-ads-store"]
                .waitForExistence(timeout: 2)
        )
        XCTAssertTrue(app.staticTexts["Remove Ads"].exists)
        XCTAssertTrue(app.staticTexts["$1.99"].exists)
        XCTAssertTrue(app.buttons["store-restore-purchases"].exists)
        XCTAssertFalse(app.buttons["store-restore-purchases"].isEnabled)
    }

    func testRemoveAdsReviewPresentation() throws {
        let app = launch(additionalArguments: ["--ui-test-storekit-profile"])
        let removeAds = app.buttons["remove-ads"]
        XCTAssertTrue(removeAds.waitForExistence(timeout: 3))
        removeAds.tap()

        XCTAssertTrue(app.navigationBars["Remove Ads"].waitForExistence(timeout: 3))
        let product = app.buttons[
            "store-product-com.otcsoftware.pimpopom.removeads.lifetime"
        ]
        XCTAssertTrue(product.waitForExistence(timeout: 2))
        XCTAssertTrue(product.isEnabled)
        XCTAssertTrue(app.staticTexts["Restorable · Family Sharing"].exists)
        XCTAssertTrue(app.buttons["store-restore-purchases"].isEnabled)
        XCTAssertFalse(app.descendants(matching: .any)["store-wallet"].exists)
        XCTAssertFalse(app.staticTexts["Current balance"].exists)
        XCTAssertTrue(scrollToElement(product, in: app))
        attachScreenshot(of: app, name: "IAP review remove ads")
    }

    func testMotivationAdvancesOnTap() throws {
        let app = launch(additionalArguments: ["--ui-test-menu-motivation"])
        let motivation = app.buttons["menu-motivation"]
        XCTAssertTrue(motivation.waitForExistence(timeout: 3))
        let first = motivation.label
        motivation.tap()
        XCTAssertNotEqual(motivation.label, first)
    }

    func testRulesReturnOnEveryLaunchAndYieldToSlogansAfterFirstGame() throws {
        let app = launch()
        XCTAssertTrue(
            app.descendants(matching: .any)["menu-intro-stamps"].waitForExistence(timeout: 3)
        )
        XCTAssertFalse(app.buttons["menu-motivation"].exists)

        app.buttons["mode-zen"].tap()
        let endRun = app.buttons["end-zen-run"]
        XCTAssertTrue(endRun.waitForExistence(timeout: 8))
        let feedback = app.staticTexts["game-feedback"]
        let targetDeadline = Date().addingTimeInterval(8)
        while Date() < targetDeadline, !feedback.label.hasPrefix("Tap ") {
            usleep(20_000)
        }
        XCTAssertTrue(feedback.label.hasPrefix("Tap "))
        endRun.tap()
        let menu = app.buttons["results-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 3))
        menu.tap()

        XCTAssertTrue(app.buttons["menu-motivation"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["menu-intro-stamps"].exists)

        app.terminate()
        app.launch()
        XCTAssertTrue(
            app.descendants(matching: .any)["menu-intro-stamps"].waitForExistence(timeout: 3)
        )
        XCTAssertFalse(app.buttons["menu-motivation"].exists)
    }

    func testLeaderboardAndProfileExposeWebParityContext() throws {
        let app = launch(
            additionalArguments: [
                "--ui-test-pet-profile",
                "--ui-test-leaderboard-fixture",
                "--ui-test-both-linked",
            ]
        )

        let leaderboardButton = app.buttons["open-leaderboard"]
        XCTAssertTrue(leaderboardButton.waitForExistence(timeout: 3))
        leaderboardButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.descendants(matching: .any)["leaderboard-mode-tabs"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["leaderboard-position"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["leaderboard-entry-ui-player"].exists)
        XCTAssertTrue(app.buttons["leaderboard-mode-normal"].exists)
        XCTAssertEqual(app.buttons["leaderboard-mode-zen"].label, "Zen")
        let multiplayerTab = app.buttons["leaderboard-mode-multiplayer"]
        XCTAssertEqual(multiplayerTab.label, "Multiplayer")
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == 'LEGACY'")).count, 0)
        let score = app.descendants(matching: .any)["leaderboard-entry-score-ui-player"]
        XCTAssertTrue(score.waitForExistence(timeout: 2))
        XCTAssertEqual(score.label.filter(\.isNumber), "8640")
        XCTAssertGreaterThan(score.frame.minX, app.frame.midX)
        XCTAssertTrue(app.descendants(matching: .any)["speed-rating-distribution"].exists)
        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'does not prove'")).count,
            0
        )
        multiplayerTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["multiplayer-leaderboard-entry-1|TeamAurora|2026-07-29T18:00:00Z"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertFalse(app.buttons["close-multiplayer-leaderboard"].exists)
        attachScreenshot(of: app, name: "iPhone 17 leaderboard parity")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let profileButton = app.buttons["open-profile"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 3))
        profileButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["My Profile"].waitForExistence(timeout: 3))
        let rankCard = app.descendants(matching: .any)["profile-rank-card"]
        XCTAssertTrue(rankCard.waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["leaderboard-entry-ui-player"].exists)
        let gameCenterCard = app.staticTexts["profile-game-center-card"]
        XCTAssertTrue(gameCenterCard.waitForExistence(timeout: 3))
        XCTAssertLessThan(gameCenterCard.frame.minY, rankCard.frame.minY)
        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(format: "label == 'Linked'")).count,
            2
        )
        XCTAssertFalse(app.buttons["Link Apple"].exists)
        XCTAssertFalse(app.buttons["Link Google"].exists)
        let gameCenter = app.buttons["profile-game-center"]
        for _ in 0..<3 where !gameCenter.exists {
            app.swipeUp()
        }
        XCTAssertTrue(gameCenter.waitForExistence(timeout: 3))
        XCTAssertEqual(gameCenter.label, "See stats")
        XCTAssertFalse(gameCenter.isEnabled)
        XCTAssertFalse(
            app.descendants(matching: .any)["profile-game-center-status"].exists
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["profile-game-center-explanation"].exists
        )
        XCTAssertFalse(
            app.buttons["profile-game-center-turn-off"].exists
        )
        XCTAssertFalse(app.alerts["Game Center"].exists)
        attachScreenshot(of: app, name: "iPhone 17 profile parity")
    }

    func testProfileAccountDeletionIsLastExactPhraseGatedAndPreservesGameCenter() throws {
        let app = launch(
            additionalArguments: [
                "--ui-test-pet-profile",
                "--ui-test-leaderboard-fixture",
                "--ui-test-account-deletion",
            ]
        )

        openMenuControl("open-profile", in: app)
        XCTAssertTrue(app.navigationBars["My Profile"].waitForExistence(timeout: 3))

        let gameCenterCard = app.staticTexts["profile-game-center-card"]
        let rankCard = app.descendants(matching: .any)["profile-rank-card"]
        XCTAssertTrue(gameCenterCard.waitForExistence(timeout: 3))
        XCTAssertTrue(rankCard.waitForExistence(timeout: 3))
        XCTAssertLessThan(gameCenterCard.frame.minY, rankCard.frame.minY)
        let finalLeaderboardEntry = app.descendants(matching: .any)[
            "leaderboard-entry-ui-neighbor"
        ]
        XCTAssertTrue(finalLeaderboardEntry.waitForExistence(timeout: 3))

        let deleteAccount = app.buttons["profile-delete-account"]
        for _ in 0..<8 where !deleteAccount.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(deleteAccount.isHittable)
        XCTAssertGreaterThan(deleteAccount.frame.minY, finalLeaderboardEntry.frame.minY)
        deleteAccount.tap()

        let confirmation = app.textFields["profile-delete-confirmation"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 2))
        let permanentlyDelete = app.buttons["profile-delete-confirm"]
        XCTAssertTrue(permanentlyDelete.waitForExistence(timeout: 2))
        XCTAssertFalse(permanentlyDelete.isEnabled)

        confirmation.tap()
        confirmation.typeText("DELETE MY ACCOUNT")
        XCTAssertTrue(permanentlyDelete.isEnabled)
        if app.keyboards.buttons["Done"].exists {
            app.keyboards.buttons["Done"].tap()
        }
        for _ in 0..<4 where !permanentlyDelete.isHittable {
            app.swipeUp()
        }
        permanentlyDelete.tap()

        let profileButton = app.buttons["open-profile"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 3))
        XCTAssertTrue(
            waitForLabel(
                "Profile. Signed out",
                on: profileButton,
                timeout: 5
            )
        )
        let dismissalDeadline = Date().addingTimeInterval(3)
        while Date() < dismissalDeadline, !profileButton.isHittable {
            usleep(50_000)
        }
        XCTAssertTrue(profileButton.isHittable)

        profileButton.tap()
        let appleSignIn = app.buttons["profile-apple-sign-in"]
        let googleSignIn = app.buttons["profile-google-sign-in"]
        XCTAssertTrue(appleSignIn.waitForExistence(timeout: 3))
        XCTAssertTrue(googleSignIn.waitForExistence(timeout: 3))
        XCTAssertLessThan(appleSignIn.frame.minY, googleSignIn.frame.minY)
        XCTAssertTrue(
            app.staticTexts["profile-game-center-card"].waitForExistence(timeout: 3)
        )
        XCTAssertFalse(app.otherElements["profile-danger-zone"].exists)
    }

    func testSignedOutProfileKeepsGameCenterStatsAsASimpleSystemAction() throws {
        let app = launch()
        openMenuControl("open-profile", in: app)
        XCTAssertTrue(app.navigationBars["My Profile"].waitForExistence(timeout: 3))

        let gameCenter = app.buttons["profile-game-center"]
        XCTAssertTrue(gameCenter.waitForExistence(timeout: 3))
        XCTAssertEqual(gameCenter.label, "See stats")
        XCTAssertFalse(gameCenter.isEnabled)
        XCTAssertFalse(
            app.descendants(matching: .any)["profile-game-center-status"].exists
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["profile-game-center-explanation"].exists
        )
        XCTAssertFalse(
            app.buttons["profile-game-center-turn-off"].exists
        )
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

    func testDiscoGameplayShowsConcreteAndVividLiveCells() throws {
        let app = launch(additionalArguments: ["--ui-test-theme", "disco"])
        app.buttons["mode-normal"].tap()

        let board = app.descendants(matching: .any)["reaction-board"]
        XCTAssertTrue(board.waitForExistence(timeout: 8))
        let feedback = app.staticTexts["game-feedback"]
        let targetDeadline = Date().addingTimeInterval(8)
        while Date() < targetDeadline, !feedback.label.hasPrefix("Tap ") {
            usleep(20_000)
        }
        XCTAssertTrue(feedback.label.hasPrefix("Tap "))
        XCTAssertTrue(app.descendants(matching: .any)["target-color"].exists)
        attachScreenshot(of: app, name: "iPhone 17 Disco gameplay polish")
    }

    func testThemeShopUsesTwoColumnCardsAndShowsSelectedFixture() throws {
        let app = launch(
            additionalArguments: ["--ui-test-theme", "pixel", "--ui-test-glyphs-on"]
        )
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
        attachScreenshot(of: app, name: "iPhone 17 Theme Shop two-times preview glyphs")

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

    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<10 where !element.isHittable {
            app.swipeUp()
        }
        return element.isHittable
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

    private func assertFrame(
        _ frame: CGRect,
        matches expected: CGRect,
        accuracy: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(frame.minX, expected.minX, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(frame.minY, expected.minY, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(frame.width, expected.width, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(frame.height, expected.height, accuracy: accuracy, file: file, line: line)
    }

}
