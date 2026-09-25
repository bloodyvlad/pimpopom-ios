import Foundation

extension BackendClient {
    func loadMultiplayerResult(matchID: String) async throws -> MultiplayerStoredResult {
        guard UUID(uuidString: matchID) != nil else {
            throw BackendError(status: 0, message: "Invalid match identifier.", code: "invalid-multiplayer-response")
        }
        let response: MultiplayerStoredResult = try await performMultiplayerRequest(
            path: "\(MultiplayerAPIContract.basePath)/results/\(matchID)",
            requiresAuthentication: true, requiresCSRF: false)
        guard response.isValid(for: matchID) else {
            throw BackendError(status: 0, message: "Invalid result receipt.", code: "invalid-multiplayer-response")
        }
        return response
    }

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
                                position: 1,
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
                                speedRatings: nil,
                                createdAt: "2026-07-29T18:00:00Z",
                                isCurrentPlayer: true,
                                verification: "server_reported_v2"
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
        guard response.isValidServerLeaderboard else {
            throw BackendError(
                status: 0, message: "Invalid multiplayer leaderboard response.", code: "invalid-multiplayer-response")
        }
        return response
    }

}
