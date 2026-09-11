import Foundation

// Ranked revision-3 results only; historical peer results remain a separate backend lane.
enum MultiplayerAPIContract {
    static let basePath = "/api/mobile/v2/multiplayer"
    static let minimumPlayers = 2
    static let maximumPlayers = 4
}

struct MultiplayerLeaderboardEntry: Codable, Equatable, Identifiable {
    let position: Int
    let rank: Int
    let name: String
    let petId: String?
    let score: Int
    let place: Int
    let playerCount: Int
    let survivalMs: Int
    let fastestReactionMs: Int?
    let averageReactionMs: Int?
    let hits: Int
    let misses: Int
    let dodges: Int
    let maxMultiplier: Int
    let speedRatings: SpeedRatingCounts?
    let createdAt: String
    let isCurrentPlayer: Bool
    let verification: String

    var id: String {
        "\(position)|\(name)|\(createdAt)"
    }
}

struct MultiplayerLeaderboardResponse: Codable, Equatable {
    let season: Season
    let mode: String
    let entries: [MultiplayerLeaderboardEntry]
    let totalEntries: Int
    let playerRank: Int?
    let topPercent: Int?

    var isValidServerLeaderboard: Bool {
        mode == "multiplayer" && totalEntries >= 0
            && entries.count <= totalEntries
            && Set(entries.map(\.position)).count == entries.count
            && entries.allSatisfy {
                $0.position > 0 && $0.position <= totalEntries && $0.rank > 0 && $0.rank <= $0.position
                    && $0.score >= 0 && (2...4).contains($0.playerCount)
                    && (1...$0.playerCount).contains($0.place) && (0...900_000).contains($0.survivalMs)
                    && $0.hits >= 0 && $0.misses >= 0 && $0.dodges >= 0
                    && (1...5).contains($0.maxMultiplier) && $0.verification == "server_reported_v2"
                    && $0.speedRatings == nil
            }
    }
}

struct MultiplayerStoredResult: Codable, Equatable, Sendable {
    struct Reward: Codable, Equatable, Sendable {
        let creditedAliveMs: Int
        let coinsEarned: Int
        let remainderMs: Int
        let totalAliveMs: Int
        let coinStatus: String
    }
    let matchID: String
    let state: String
    let rankingEligible: Bool
    let resultRevision: Int
    let rewardPolicy: String
    let reward: Reward

    func isValid(for expectedID: String) -> Bool {
        matchID == expectedID && resultRevision == 2 && rewardPolicy == "multiplayer-alive-minute-v1"
            && state == (rankingEligible ? "stored_ranked" : "stored_unranked")
            && (0...900_000).contains(reward.creditedAliveMs) && (0...30).contains(reward.coinsEarned)
            && reward.coinsEarned.isMultiple(of: 2) && (0..<60_000).contains(reward.remainderMs)
            && reward.totalAliveMs >= reward.creditedAliveMs
            && ["eligible", "ineligible", "missing_generation", "stale_generation"].contains(reward.coinStatus)
            && (reward.coinStatus == "eligible" || (reward.coinsEarned == 0 && reward.creditedAliveMs == 0))
    }
}
