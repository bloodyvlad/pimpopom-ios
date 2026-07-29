import PimPoPomCore
import XCTest

@testable import PimPoPom

final class LeaderboardPresentationTests: XCTestCase {
    func testLeaderboardModesKeepMultiplayerOutOfGameplayModes() {
        XCTAssertEqual(LeaderboardMode.arcade.title, "Arcade")
        XCTAssertEqual(LeaderboardMode.arcade.gameMode, .arcade)
        XCTAssertEqual(LeaderboardMode.zen.title, "Zen")
        XCTAssertEqual(LeaderboardMode.zen.gameMode, .zen)
        XCTAssertEqual(LeaderboardMode.multiplayer.title, "Multiplayer")
        XCTAssertNil(LeaderboardMode.multiplayer.gameMode)
    }
}
