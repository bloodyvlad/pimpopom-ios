import XCTest

final class HowToPlayUITests: XCTestCase {
    func testPracticeTutorialsAcrossAllThemes() {
        let app = XCUIApplication()
        for mode in ["arcade", "multiplayer"] {
            for theme in ["classic", "disco", "light", "pixel"] {
                app.launchArguments = [
                    "--uitesting", "--deterministic-game", "--ui-test-theme=\(theme)",
                    "--ui-test-tutorial=\(mode)",
                ]
                app.launch()
                assertFirstStepControls(in: app, mode: mode)
                capture("\(theme) \(mode) tutorial accessible first step", in: app)
                let next = app.buttons["tutorial-next"]
                XCTAssertFalse(app.descendants(matching: .any)["multiplayer-hub"].exists)
                XCTAssertFalse(app.buttons["arcade-cell-0"].exists)
                tapTarget(app)
                advance(next)
                tapTarget(app)
                advance(next)
                for _ in 0..<3 { tapTarget(app) }
                waitForLabel("Speed Bar, 1 of 5 steps, example multiplier 2", identifier: "tutorial-speed-bar", in: app)
                advance(next)
                waitForLabel("Lives, 2 of 3", identifier: "tutorial-lives", in: app)
                tap("tutorial-cell-5", in: app)
                waitForLabel("Lives, 3 of 3", identifier: "tutorial-lives", in: app)
                if mode == "arcade" {
                    tap("tutorial-cell-10", in: app)
                    waitForLabel("PACE 70%", identifier: "tutorial-clock-rate", in: app)
                    tap("tutorial-clock-preview", in: app)
                    waitForLabel("PACE 85%", identifier: "tutorial-clock-rate", in: app)
                    tap("tutorial-clock-preview", in: app)
                    waitForLabel("NORMAL PACE · 100%", identifier: "tutorial-clock-rate", in: app)
                    XCTAssertFalse(app.buttons["tutorial-clock-preview"].isEnabled)
                }
                capture("\(theme) \(mode) tutorial 4x4 pickups", in: app)
                advance(next)
                if mode == "multiplayer" { tapTarget(app) }
                advance(next)
                XCTAssertEqual(next.label, "Done")
                XCTAssertTrue(next.isHittable)
                next.tap()
                XCTAssertTrue(app.staticTexts["tutorial-\(mode)"].waitForNonExistence(timeout: 3))
                XCTAssertTrue(app.buttons["mode-normal"].waitForExistence(timeout: 3))
                app.terminate()
            }
        }
    }

    func testSkipTutorialDoesNotStartARealGameInReplay() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ui-test-tutorial=multiplayer"]
        app.launch()
        assertFirstStepControls(in: app, mode: "multiplayer")
        let skip = app.buttons["tutorial-skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 6))
        skip.tap()
        XCTAssertTrue(app.staticTexts["tutorial-multiplayer"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["mode-normal"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["multiplayer-hub"].exists)
        XCTAssertFalse(app.buttons["arcade-cell-0"].exists)
    }

    func testSettingsCanReplayEachTutorialWithoutStartingGameplay() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        let settings = app.buttons["open-settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 6))
        settings.tap()
        for mode in ["arcade", "multiplayer"] {
            let replay = app.buttons["replay-tutorial-\(mode)"]
            XCTAssertTrue(replay.waitForExistence(timeout: 3))
            reveal(replay, in: app)
            replay.tap()
            assertFirstStepControls(in: app, mode: mode)
            capture("Settings replay \(mode) tutorial first step", in: app)
            let skip = app.buttons["tutorial-skip"]
            XCTAssertTrue(skip.waitForExistence(timeout: 3))
            skip.tap()
            XCTAssertTrue(app.staticTexts["tutorial-\(mode)"].waitForNonExistence(timeout: 3))
            XCTAssertTrue(replay.waitForExistence(timeout: 3))
            XCTAssertFalse(app.buttons["arcade-cell-0"].exists)
            XCTAssertFalse(app.descendants(matching: .any)["multiplayer-hub"].exists)
        }
    }

    private func assertFirstStepControls(in app: XCUIApplication, mode: String) {
        let title = app.staticTexts["tutorial-\(mode)"]
        XCTAssertTrue(title.waitForExistence(timeout: 6))
        XCTAssertEqual(app.staticTexts.matching(identifier: "tutorial-\(mode)").count, 1)
        let next = app.buttons["tutorial-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons.matching(identifier: "tutorial-next").count, 1)
        XCTAssertFalse(next.isEnabled)
        let skip = app.buttons["tutorial-skip"]
        XCTAssertEqual(app.buttons.matching(identifier: "tutorial-skip").count, 1)
        XCTAssertTrue(skip.isHittable)
        XCTAssertTrue(app.switches["tutorial-remember"].exists)
        let target = app.buttons["tutorial-cell-0"]
        XCTAssertTrue(target.exists, "Practice targets must retain Button semantics, not inert accessibility groups")
        XCTAssertEqual(target.label, "Your color target, Cyan")
        XCTAssertTrue(target.isEnabled)
        reveal(target, in: app)
    }

    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func advance(_ next: XCUIElement) {
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: next)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 3), .completed)
        next.tap()
    }

    private func waitForLabel(_ label: String, identifier: String, in app: XCUIApplication) {
        let element = app.descendants(matching: .any)[identifier]
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
    }

    private func tapTarget(_ app: XCUIApplication) {
        let target = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Your color target")).firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 2))
        reveal(target, in: app)
        target.tap()
    }

    private func tap(_ identifier: String, in app: XCUIApplication) {
        let control = app.buttons[identifier]
        reveal(control, in: app)
        control.tap()
    }

    private func reveal(_ control: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<3 where !control.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(control.isHittable)
        XCTAssertGreaterThanOrEqual(control.frame.width, 44)
        XCTAssertGreaterThanOrEqual(control.frame.height, 44)
    }
}
