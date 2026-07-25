import XCTest

@testable import PimPoPom

final class ScreenshotFixtureTests: XCTestCase {
    func testFixtureRequiresExplicitScreenshotAndUITestArguments() {
        XCTAssertNil(ScreenshotFixture.resolve(arguments: ["PimPoPom", "--screenshot-mode"]))
        XCTAssertNil(ScreenshotFixture.resolve(arguments: ["PimPoPom", "--uitesting"]))
    }

    func testFixtureParsesScreenThemePetAndAutoplay() throws {
        let fixture = try XCTUnwrap(
            ScreenshotFixture.resolve(
                arguments: [
                    "PimPoPom",
                    "--uitesting",
                    "--screenshot-mode",
                    "--screenshot-screen=arcade",
                    "--screenshot-theme",
                    "pixel",
                    "--screenshot-pet=misha",
                    "--screenshot-autoplay",
                    "--screenshot-seed",
                    "42",
                ]
            )
        )

        XCTAssertEqual(fixture.destination, .arcade)
        XCTAssertEqual(fixture.themeID, "pixel")
        XCTAssertEqual(fixture.petID, "misha")
        XCTAssertTrue(fixture.autoplayEnabled)
        XCTAssertEqual(fixture.autoplaySeed, 42)
    }

    func testFixtureUsesSafeDefaultsForUnknownValues() throws {
        let fixture = try XCTUnwrap(
            ScreenshotFixture.resolve(
                arguments: [
                    "PimPoPom",
                    "--uitesting",
                    "--screenshot-mode",
                    "--screenshot-screen=unknown",
                    "--screenshot-theme=unknown",
                    "--screenshot-pet=none",
                ]
            )
        )

        XCTAssertEqual(fixture.destination, .menu)
        XCTAssertEqual(fixture.themeID, "pixel")
        XCTAssertNil(fixture.petID)
        XCTAssertFalse(fixture.autoplayEnabled)
    }

    func testAutoplayStaysInsideEveryRequestedReactionRange() {
        var random = ScreenshotAutoplayRandom(seed: 42)

        for dimension in [1, 2, 4] {
            let range = ScreenshotFixture.reactionRangeMilliseconds(
                forGridDimension: dimension
            )
            let samples = (0..<100).map { _ in
                random.nextReactionMilliseconds(forGridDimension: dimension)
            }
            XCTAssertTrue(samples.allSatisfy(range.contains))
            XCTAssertGreaterThan(Set(samples).count, 1)
        }

        XCTAssertEqual(
            ScreenshotFixture.reactionRangeMilliseconds(forGridDimension: 1),
            190...280
        )
        XCTAssertEqual(
            ScreenshotFixture.reactionRangeMilliseconds(forGridDimension: 2),
            270...350
        )
        XCTAssertEqual(
            ScreenshotFixture.reactionRangeMilliseconds(forGridDimension: 4),
            310...500
        )
    }

    func testAutoplayUsesSeededVariedInteriorTapLocations() {
        var first = ScreenshotAutoplayRandom(seed: 42)
        var second = ScreenshotAutoplayRandom(seed: 42)

        let firstSamples = (0..<100).map { _ in first.nextTapLocation() }
        let secondSamples = (0..<100).map { _ in second.nextTapLocation() }

        XCTAssertEqual(firstSamples, secondSamples)
        XCTAssertTrue(
            firstSamples.allSatisfy {
                (ScreenshotAutoplayRandom.minimumTapFraction...ScreenshotAutoplayRandom.maximumTapFraction)
                    .contains($0.horizontalFraction)
                    && (ScreenshotAutoplayRandom.minimumTapFraction...ScreenshotAutoplayRandom.maximumTapFraction)
                        .contains($0.verticalFraction)
            }
        )
        XCTAssertGreaterThan(Set(firstSamples.map(\.horizontalFraction)).count, 1)
        XCTAssertGreaterThan(Set(firstSamples.map(\.verticalFraction)).count, 1)
        XCTAssertTrue(
            firstSamples.contains {
                abs($0.horizontalFraction - 0.5) > 0.1
                    || abs($0.verticalFraction - 0.5) > 0.1
            }
        )
    }

    func testFixtureRecognizesMarketingDestinations() throws {
        for destination in [
            ScreenshotFixture.Destination.leaderboard,
            .profile,
            .achievements,
        ] {
            let fixture = try XCTUnwrap(
                ScreenshotFixture.resolve(
                    arguments: [
                        "PimPoPom",
                        "--uitesting",
                        "--screenshot-mode",
                        "--screenshot-screen=\(destination.rawValue)",
                    ]
                )
            )
            XCTAssertEqual(fixture.destination, destination)
        }
    }

    @MainActor
    func testSyntheticLeaderboardUsesDistinctPlausibleResults() {
        let response = BackendClient.screenshotLeaderboard(
            mode: .arcade,
            playerName: "PimPoPlayer"
        )
        let names = response.entries.map(\.name)
        let scores = response.entries.map(\.score)

        XCTAssertEqual(names.count, Set(names).count)
        XCTAssertEqual(response.entries.map(\.rank), Array(1...7))
        XCTAssertTrue(scores.allSatisfy { $0 > 0 })
        XCTAssertEqual(scores, scores.sorted(by: >))
        XCTAssertEqual(response.playerRank, 6)
        XCTAssertEqual(response.entries.first(where: \.isCurrentPlayer)?.name, "PimPoPlayer")
    }
}
