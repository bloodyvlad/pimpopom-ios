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

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--deterministic-game", "--uitesting"]
        app.launch()
        let environment = app.staticTexts["backend-environment"]
        XCTAssertTrue(environment.waitForExistence(timeout: 3))
        XCTAssertEqual(environment.label, "Offline UI Test")
        return app
    }
}
