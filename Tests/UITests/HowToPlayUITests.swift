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
                let next = app.buttons["tutorial-next"]
                XCTAssertTrue(next.waitForExistence(timeout: 6))
                XCTAssertFalse(next.isEnabled)
                XCTAssertTrue(app.buttons["tutorial-skip"].isHittable)
                XCTAssertFalse(app.descendants(matching: .any)["multiplayer-hub"].exists)
                XCTAssertFalse(app.buttons["arcade-cell-0"].exists)
                tapTarget(app)
                advance(next)
                tapTarget(app)
                advance(next)
                for _ in 0..<3 { tapTarget(app) }
                advance(next)
                tap("tutorial-cell-5", in: app)
                if mode == "arcade" { tap("tutorial-cell-10", in: app) }
                let attachment = XCTAttachment(screenshot: app.screenshot())
                attachment.name = "\(theme) \(mode) tutorial 4x4 pickups"
                attachment.lifetime = .keepAlways
                add(attachment)
                advance(next)
                if mode == "multiplayer" { tapTarget(app) }
                advance(next)
                XCTAssertEqual(next.label, "Done")
                XCTAssertTrue(next.isHittable)
                next.tap()
                XCTAssertTrue(app.buttons["mode-normal"].waitForExistence(timeout: 3))
                app.terminate()
            }
        }
    }

    func testSkipTutorialDoesNotStartARealGameInReplay() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ui-test-tutorial=multiplayer"]
        app.launch()
        let skip = app.buttons["tutorial-skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 6))
        skip.tap()
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
            let skip = app.buttons["tutorial-skip"]
            XCTAssertTrue(skip.waitForExistence(timeout: 3))
            skip.tap()
            XCTAssertTrue(replay.waitForExistence(timeout: 3))
            XCTAssertFalse(app.buttons["arcade-cell-0"].exists)
            XCTAssertFalse(app.descendants(matching: .any)["multiplayer-hub"].exists)
        }
    }

    private func advance(_ next: XCUIElement) {
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: next)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 3), .completed)
        next.tap()
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
