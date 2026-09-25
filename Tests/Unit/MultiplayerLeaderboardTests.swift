import XCTest

@testable import PimPoPom

final class MultiplayerLeaderboardTests: XCTestCase {
    func testResultsOnlyShowConfirmedCoinAmountsAndKeepThemDuringBalanceRefresh() {
        var state = MultiplayerPresentation.ResultsState(
            settlement: .settled(leaderboardEligible: false), results: [], isRefreshing: true,
            localSubmissionAccepted: true, message: "Syncing")
        XCTAssertNil(state.coinsEarned)
        for coins in [0, 2, 6] {
            let receipt = storedReceipt(coins: coins, status: "eligible")
            state.recordStoredResult(receipt)
            state.recordStoredResult(receipt)
            XCTAssertEqual(state.coinsEarned, coins, "Repeated receipts must not add coins again")
            XCTAssertEqual(state.message, "Result saved")
            XCTAssertTrue(state.isPersistenceConfirmed)
            XCTAssertFalse(state.isBalanceCurrent)
            state.message = "Your balance has not refreshed yet"
            XCTAssertEqual(state.coinsEarned, coins)
        }
    }

    func testIneligibleReceiptsNeverShowAnEarnedCoinCelebration() {
        for status in ["ineligible", "missing_generation", "stale_generation"] {
            var state = MultiplayerPresentation.ResultsState(
                settlement: .settled(leaderboardEligible: false), results: [], isRefreshing: false,
                localSubmissionAccepted: true, message: nil)
            state.recordStoredResult(storedReceipt(coins: 0, status: status))
            XCTAssertNil(state.coinsEarned)
            XCTAssertEqual(state.message, "Result saved. This match did not earn coins.")
        }
    }

    private func storedReceipt(coins: Int, status: String) -> MultiplayerStoredResult {
        .init(
            matchID: "match", state: "stored_ranked", rankingEligible: true, resultRevision: 2,
            rewardPolicy: "multiplayer-alive-minute-v1",
            reward: .init(
                creditedAliveMs: status == "eligible" ? 97_000 : 0, coinsEarned: coins,
                remainderMs: 37_000, totalAliveMs: 97_000, coinStatus: status))
    }

    func testNewServerBoardAcceptsScoreTiesWithUniquePositionsAndNoInventedRatings() throws {
        let response = try response()
        XCTAssertTrue(response.isValidServerLeaderboard)
        XCTAssertEqual(response.entries.map(\.rank), [1, 1])
        XCTAssertEqual(Set(response.entries.map(\.id)).count, 2)
        XCTAssertNil(response.entries.first?.speedRatings)
        XCTAssertEqual(MultiplayerAPIContract.basePath, "/api/mobile/v2/multiplayer")
    }

    func testOldPeerTrustDuplicatePositionsAndInvalidPlayerCountAreRejected() throws {
        XCTAssertFalse(try response(verification: "peer_consistent_v1").isValidServerLeaderboard)
        XCTAssertFalse(try response(secondPosition: 1).isValidServerLeaderboard)
        XCTAssertFalse(try response(playerCount: -1).isValidServerLeaderboard)
        XCTAssertFalse(try response(includesInvalidRatings: true).isValidServerLeaderboard)
    }

    func testStoredReceiptBindsMatchAndRejectsInvalidAwards() {
        func receipt(coins: Int = 2, status: String = "eligible") -> MultiplayerStoredResult {
            .init(
                matchID: "match", state: "stored_ranked", rankingEligible: true, resultRevision: 2,
                rewardPolicy: "multiplayer-alive-minute-v1",
                reward: .init(
                    creditedAliveMs: 60_000, coinsEarned: coins, remainderMs: 0,
                    totalAliveMs: 60_000, coinStatus: status))
        }
        XCTAssertTrue(receipt().isValid(for: "match"))
        XCTAssertFalse(receipt().isValid(for: "another-match"))
        XCTAssertFalse(receipt(coins: 3).isValid(for: "match"))
        XCTAssertFalse(receipt(coins: Int.max).isValid(for: "match"))
        XCTAssertFalse(receipt(status: "ineligible").isValid(for: "match"))
    }

    private func response(
        verification: String = "server_reported_v2", secondPosition: Int = 2, playerCount: Int = 4,
        includesInvalidRatings: Bool = false
    ) throws -> MultiplayerLeaderboardResponse {
        let rows: [[String: Any]] = [1, secondPosition].map { position in
            var row: [String: Any] = [
                "position": position, "rank": 1, "name": "Player\(position)", "score": 2_000,
                "place": 1, "playerCount": playerCount, "survivalMs": 60_000,
                "hits": 10, "misses": 3, "dodges": 2, "maxMultiplier": 2,
                "createdAt": "2026-09-11T18:00:00Z", "isCurrentPlayer": position == 1,
                "verification": verification,
            ]
            if includesInvalidRatings {
                row["speedRatings"] = ["godlike": Int.max, "perfect": 1, "great": 0, "good": 0]
            }
            return row
        }
        let data = try JSONSerialization.data(withJSONObject: [
            "season": ["id": "mp2-1", "name": "Multiplayer"], "mode": "multiplayer",
            "entries": rows, "totalEntries": 2, "playerRank": 1, "topPercent": 1,
        ])
        return try JSONDecoder().decode(MultiplayerLeaderboardResponse.self, from: data)
    }
}
