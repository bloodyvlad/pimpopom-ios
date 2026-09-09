import Foundation

// Historical v1 leaderboard reads only. No v1 live mutation API remains.
enum MultiplayerAPIContract {
    static let basePath = "/api/mobile/v1/multiplayer"
    static let minimumPlayers = 2
    static let maximumPlayers = 4
}

struct MultiplayerLeaderboardEntry: Codable, Equatable, Identifiable {
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
    let speedRatings: SpeedRatingCounts
    let createdAt: String
    let isCurrentPlayer: Bool
    let verification: String

    var id: String {
        "\(rank)|\(name)|\(createdAt)"
    }
}

struct MultiplayerLeaderboardResponse: Codable, Equatable {
    let season: Season
    let mode: String
    let entries: [MultiplayerLeaderboardEntry]
    let totalEntries: Int
    let playerRank: Int?
    let topPercent: Int?
}
