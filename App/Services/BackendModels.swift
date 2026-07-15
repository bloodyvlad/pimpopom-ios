import Foundation

struct Season: Codable, Equatable {
    let id: String
    let name: String
}

struct PlayerProfile: Codable, Equatable, Identifiable {
    let id: String
    let nickname: String
    let nicknameConfirmed: Bool
    let coins: Int
    let totalPlayMs: Int
    let ownedPetIds: [String]
    let selectedPetId: String?
    let petVisible: Bool
    let equippedPetId: String?
    let specialPetId: String?
    let ownedThemeIds: [String]
    let selectedThemeId: String?
    let isAdmin: Bool
    let createdAt: String
    let updatedAt: String
}

struct RankInfo: Codable, Equatable {
    let rank: Int?
    let totalEntries: Int
    let topPercent: Int?
}

struct SessionResponse: Codable, Equatable {
    let authenticated: Bool
    let csrfToken: String
    let googleClientId: String
    let season: Season
    let profile: PlayerProfile?
    let ranks: [String: RankInfo]?
}

struct SpeedRatingCounts: Codable, Equatable {
    let godlike: Int
    let perfect: Int
    let great: Int
    let good: Int
}

struct LeaderboardEntry: Codable, Equatable, Identifiable {
    let id: String
    let rank: Int
    let name: String
    let petId: String?
    let mode: String
    let score: Int
    let survivalMs: Int
    let fastestReactionMs: Int?
    let averageReactionMs: Int?
    let hits: Int
    let dodges: Int
    let speedRatings: SpeedRatingCounts
    let createdAt: String
    let isCurrentPlayer: Bool
    let isContextResult: Bool
    let verification: String
}

struct LeaderboardResponse: Codable, Equatable {
    let season: Season
    let mode: String
    let entries: [LeaderboardEntry]
    let totalEntries: Int
    let playerRank: Int?
    let topPercent: Int?
    let contextRank: Int?
    let contextTopPercent: Int?
    let contextEntryId: String?
}

struct ProfileResponse: Codable, Equatable {
    let profile: PlayerProfile
    let ranks: [String: RankInfo]
    let leaderboard: LeaderboardResponse
}

struct CosmeticCatalogItem: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let priceCoins: Int
}

struct ThemeCatalogResponse: Codable, Equatable {
    let themes: [CosmeticCatalogItem]
    let profile: PlayerProfile?
    let coinBalance: Int
}

struct PetCatalogResponse: Codable, Equatable {
    let pets: [CosmeticCatalogItem]
    let profile: PlayerProfile?
    let coinBalance: Int
}

struct ThemeSelectionResult: Codable, Equatable {
    let id: String
    let purchased: Bool
    let pricePaid: Int
}

struct ThemeSelectionResponse: Codable, Equatable {
    let profile: PlayerProfile
    let theme: ThemeSelectionResult
    let coinBalance: Int
}

struct PetSelectionResult: Codable, Equatable {
    let id: String
    let purchased: Bool
    let pricePaid: Int
}

struct PetSelectionResponse: Codable, Equatable {
    let profile: PlayerProfile
    let pet: PetSelectionResult
    let coinBalance: Int
}

struct PetVisibilityResult: Codable, Equatable {
    let id: String
    let visible: Bool
}

struct PetVisibilityResponse: Codable, Equatable {
    let profile: PlayerProfile
    let pet: PetVisibilityResult
    let coinBalance: Int
}

struct RunTicket: Codable, Equatable {
    let runId: String
    let mode: String
    let buildId: String
    let ruleset: String
    let proofVersion: Int
}

struct RunFinishResponse: Codable, Equatable {
    let rank: Int?
    let submittedRank: Int?
    let submittedEntryId: String?
    let improved: Bool?
    let duplicate: Bool
    let verificationStatus: String?
    let coinsEarned: Int?
    let coinBalance: Int?
    let totalPlayMs: Int?
}

struct RunProofPayload: Encodable {
    let runId: String
    let mode: String
    let buildId: String
    let ruleset: String
    let proofVersion: Int
    let events: [[Int]]
}

struct APIErrorPayload: Decodable {
    let error: String?
    let code: String?
}

struct APIMessage: Decodable {
    let abandoned: Bool?
}
