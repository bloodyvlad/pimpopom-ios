import Foundation

extension BackendClient {
    func loadMultiplayerLeaderboard() async throws -> MultiplayerLeaderboardResponse {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                let exposesFixture =
                    ProcessInfo.processInfo.arguments.contains("--ui-test-leaderboard-fixture")
                    || ProcessInfo.processInfo.arguments.contains("--screenshot-mode")
                return MultiplayerLeaderboardResponse(
                    season: Season(id: "season-1", name: "Season 1"),
                    mode: "multiplayer",
                    entries: exposesFixture
                        ? [
                            MultiplayerLeaderboardEntry(
                                rank: 1,
                                name: "TeamAurora",
                                petId: "foka",
                                score: 24_850,
                                place: 1,
                                playerCount: 4,
                                survivalMs: 186_000,
                                fastestReactionMs: 181,
                                averageReactionMs: 302,
                                hits: 94,
                                misses: 2,
                                dodges: 14,
                                maxMultiplier: 4,
                                speedRatings: SpeedRatingCounts(
                                    godlike: 18,
                                    perfect: 34,
                                    great: 27,
                                    good: 15
                                ),
                                createdAt: "2026-07-29T18:00:00Z",
                                isCurrentPlayer: true,
                                verification: "peer_consistent_v1"
                            )
                        ] : [],
                    totalEntries: exposesFixture ? 1 : 0,
                    playerRank: exposesFixture ? 1 : nil,
                    topPercent: exposesFixture ? 1 : nil
                )
            }
        #endif
        let response: MultiplayerLeaderboardResponse = try await performMultiplayerRequest(
            path: "\(MultiplayerAPIContract.basePath)/leaderboard",
            requiresAuthentication: false,
            requiresCSRF: false
        )
        guard response.mode == "multiplayer",
            response.totalEntries >= 0,
            response.entries.allSatisfy({
                $0.rank > 0
                    && $0.score >= 0
                    && $0.place > 0
                    && $0.playerCount >= MultiplayerAPIContract.minimumPlayers
                    && $0.playerCount <= MultiplayerAPIContract.maximumPlayers
                    && $0.verification == "peer_consistent_v1"
            })
        else {
            throw BackendError(
                status: 0, message: "Invalid historical leaderboard response.", code: "invalid-multiplayer-response")
        }
        return response
    }

}
