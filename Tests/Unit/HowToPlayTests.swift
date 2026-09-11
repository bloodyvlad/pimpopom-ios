import SwiftUI
import XCTest

@testable import PimPoPom

@MainActor
final class HowToPlayTests: XCTestCase {
    func testArcadeRequiresCorrectTapsAndOnlyShowsPickupsOnFourByFour() {
        var practice = HowToPlayPractice(mode: .arcade)
        XCTAssertEqual(practice.gridDimension, 1)
        XCTAssertFalse(practice.advance())
        practice.tap(cell: 12)
        XCTAssertEqual(practice.interactions, 0)
        practice.tap(cell: 0)
        XCTAssertTrue(practice.advance())
        XCTAssertEqual(practice.step, .changingColor)
        XCTAssertEqual(practice.colorIndex, 2)
        XCTAssertEqual(practice.gridDimension, 2)
        practice.tap(cell: 1)
        XCTAssertEqual(practice.interactions, 0)
        practice.tap(cell: practice.targetCell)
        XCTAssertTrue(practice.advance())
        for count in 1...3 {
            practice.tap(cell: practice.targetCell)
            XCTAssertEqual(practice.interactions, count)
            XCTAssertEqual(practice.canAdvance, count == 3)
        }
        XCTAssertEqual(practice.speedProgress, 1)
        XCTAssertEqual(practice.multiplier, 2)
        XCTAssertTrue(practice.advance())
        XCTAssertEqual(practice.gridDimension, 4)
        XCTAssertEqual(practice.tile(at: 5), .heart)
        XCTAssertEqual(practice.tile(at: 10), .empty)
        practice.tap(cell: 5)
        XCTAssertFalse(practice.canAdvance)
        XCTAssertEqual(practice.tile(at: 10), .clock)
        practice.tap(cell: 5)
        XCTAssertEqual(practice.interactions, 1)
        practice.tap(cell: 10)
        XCTAssertTrue(practice.advance())
        XCTAssertEqual(practice.step, .competition)
        XCTAssertTrue(practice.advance())
        XCTAssertTrue(practice.isLastStep)
        XCTAssertFalse(practice.advance())
    }

    func testMultiplayerNeverDemonstratesAClockAndExplainsScoreWinner() {
        var practice = HowToPlayPractice(mode: .multiplayer)
        while practice.step != .pickups {
            while !practice.canAdvance { practice.tap(cell: practice.targetCell) }
            XCTAssertTrue(practice.advance())
        }
        XCTAssertEqual(practice.requiredInteractions, 1)
        XCTAssertFalse((0..<16).map { practice.tile(at: $0) }.contains(.clock))
        practice.tap(cell: 5)
        XCTAssertTrue(practice.advance())
        XCTAssertTrue(practice.instruction.contains("highest final score wins"))
        XCTAssertTrue(practice.instruction.contains("last player is out"))
        practice.tap(cell: 1)
        XCTAssertFalse(practice.canAdvance)
        practice.tap(cell: practice.targetCell)
        XCTAssertTrue(practice.advance())
        XCTAssertTrue(practice.rewardsInstruction.contains("2 coins"))
        XCTAssertTrue(practice.rewardsInstruction.contains("Spectating time does not count"))
        XCTAssertTrue(practice.rewardsInstruction.contains("leaderboard"))
    }

    func testRewardCopyCanFollowDisabledCapabilitiesWithoutMakingPromises() {
        let practice = HowToPlayPractice(mode: .multiplayer, capabilities: .init())
        XCTAssertTrue(practice.rewardsInstruction.contains("no coin rewards"))
        XCTAssertTrue(practice.rewardsInstruction.contains("ranking is not enabled"))
        XCTAssertTrue(HowToPlayPractice(mode: .arcade).rewardsInstruction.contains("one coin"))
    }

    func testTutorialPreferencesDefaultOnAndPersistSeparately() throws {
        let name = "HowToPlayTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = AppPreferences(defaults: defaults)
        XCTAssertFalse(preferences.skipsTutorial(for: .arcade))
        XCTAssertFalse(preferences.skipsTutorial(for: .multiplayer))
        preferences.setSkipsTutorial(true, for: .arcade)
        let reloaded = AppPreferences(defaults: defaults)
        XCTAssertTrue(reloaded.skipsTutorial(for: .arcade))
        XCTAssertFalse(reloaded.skipsTutorial(for: .multiplayer))
        reloaded.setSkipsTutorial(true, for: .multiplayer)
        reloaded.setSkipsTutorial(false, for: .arcade)
        let final = AppPreferences(defaults: defaults)
        XCTAssertFalse(final.skipsTutorial(for: .arcade))
        XCTAssertTrue(final.skipsTutorial(for: .multiplayer))
    }

    func testExistingUITestsBypassEntryAndExplicitFixturesAreDebugOnly() {
        XCTAssertTrue(HowToPlayLaunchPolicy.shouldPresent(rememberedSkip: false, arguments: []))
        XCTAssertFalse(HowToPlayLaunchPolicy.shouldPresent(rememberedSkip: true, arguments: []))
        XCTAssertFalse(HowToPlayLaunchPolicy.shouldPresent(rememberedSkip: false, arguments: ["--uitesting"]))
        XCTAssertTrue(
            HowToPlayLaunchPolicy.shouldPresent(
                rememberedSkip: false, arguments: ["--uitesting", "--ui-test-tutorial-entry"]))
        XCTAssertEqual(
            HowToPlayLaunchPolicy.fixtureMode(arguments: ["--uitesting", "--ui-test-tutorial=multiplayer"]),
            .multiplayer)
        XCTAssertNil(HowToPlayLaunchPolicy.fixtureMode(arguments: ["--ui-test-tutorial=arcade"]))
    }

    func testEntryDoesNotConstructTheGameDestinationBeforeTutorialAdmission() async throws {
        let name = "HowToPlayAdmission.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = AppPreferences(defaults: defaults)
        let backend = BackendClient(isUITestOffline: true)
        let cosmetics = CosmeticsController(backend: backend, preferences: preferences)
        let probe = TutorialDestinationProbe()
        let host = UIHostingController(
            rootView: HowToPlayEntryView(mode: .arcade, arguments: []) {
                probe.makeDestination()
            }
            .environmentObject(preferences)
            .environmentObject(cosmetics))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKey()
        }
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(probe.constructions, 0, "A tutorial must not construct a live game or lobby")
        preferences.setSkipsTutorial(true, for: .arcade)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertGreaterThan(probe.constructions, 0)
    }
}

@MainActor
private final class TutorialDestinationProbe {
    var constructions = 0
    func makeDestination() -> some View {
        constructions += 1
        return Text("Admitted destination")
    }
}
