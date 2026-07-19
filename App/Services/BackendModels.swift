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

struct StoreKitBindingResponse: Codable, Equatable, Sendable {
    let appAccountToken: String
    let bindingStatus: String

    var boundToken: UUID? {
        guard bindingStatus == "bound" else { return nil }
        return UUID(uuidString: appAccountToken)
    }
}

struct SessionResponse: Codable, Equatable {
    let authenticated: Bool
    let csrfToken: String
    let googleClientId: String
    let season: Season
    let profile: PlayerProfile?
    let wallet: StoreWalletSummary?
    let adFree: Bool?
    let storeKit: StoreKitBindingResponse?
    let ranks: [String: RankInfo]?

    init(
        authenticated: Bool,
        csrfToken: String,
        googleClientId: String,
        season: Season,
        profile: PlayerProfile?,
        wallet: StoreWalletSummary? = nil,
        adFree: Bool? = nil,
        storeKit: StoreKitBindingResponse? = nil,
        ranks: [String: RankInfo]?
    ) {
        self.authenticated = authenticated
        self.csrfToken = csrfToken
        self.googleClientId = googleClientId
        self.season = season
        self.profile = profile
        self.wallet = wallet
        self.adFree = adFree
        self.storeKit = storeKit
        self.ranks = ranks
    }
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
    let wallet: StoreWalletSummary?
    let adFree: Bool?
    let storeKit: StoreKitBindingResponse?
    let ranks: [String: RankInfo]
    let leaderboard: LeaderboardResponse

    init(
        profile: PlayerProfile,
        wallet: StoreWalletSummary? = nil,
        adFree: Bool? = nil,
        storeKit: StoreKitBindingResponse? = nil,
        ranks: [String: RankInfo],
        leaderboard: LeaderboardResponse
    ) {
        self.profile = profile
        self.wallet = wallet
        self.adFree = adFree
        self.storeKit = storeKit
        self.ranks = ranks
        self.leaderboard = leaderboard
    }
}

struct StoreKitCreditAPIResponse: Codable, Equatable, Sendable {
    let transactionId: String
    let status: String
    let duplicate: Bool
    let wallet: StoreWalletSummary?
    let adFree: Bool
}

struct AccountDeletionResponse: Codable, Equatable {
    let deleted: Bool
    let authenticated: Bool
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

enum AchievementState: String, Codable, Equatable, Sendable {
    case locked
    case claimable
    case claimed
}

struct AchievementItem: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let description: String
    let rewardCoins: Int
    let state: AchievementState
    let unlockedAt: String?
    let claimedAt: String?
}

struct AchievementsResponse: Codable, Equatable, Sendable {
    let authenticated: Bool
    let achievements: [AchievementItem]
    let claimedCount: Int
    let totalCount: Int
    let coinBalance: Int
    let achievement: AchievementItem?
    let coinsEarned: Int?
    let duplicate: Bool?

    init(
        authenticated: Bool,
        achievements: [AchievementItem],
        claimedCount: Int,
        totalCount: Int,
        coinBalance: Int,
        achievement: AchievementItem? = nil,
        coinsEarned: Int? = nil,
        duplicate: Bool? = nil
    ) {
        self.authenticated = authenticated
        self.achievements = achievements
        self.claimedCount = claimedCount
        self.totalCount = totalCount
        self.coinBalance = coinBalance
        self.achievement = achievement
        self.coinsEarned = coinsEarned
        self.duplicate = duplicate
    }

    var claimableCount: Int {
        achievements.filter { $0.state == .claimable }.count
    }
}

enum AchievementCatalog {
    static let definitions = [
        definition(
            id: "complete_arcade",
            title: "Complete Arcade mode",
            description: "Play until all three Arcade lives are gone.",
            rewardCoins: 1
        ),
        definition(
            id: "godlike_speed",
            title: "Show Godlike speed",
            description: "Make a correct tap in under 250 ms.",
            rewardCoins: 1
        ),
        definition(
            id: "collect_5_coins",
            title: "Collect 5 coins",
            description: "Collect five coins in total.",
            rewardCoins: 5
        ),
        definition(
            id: "score_over_100k",
            title: "Score more than 100K",
            description: "Score over 100,000 points in one run.",
            rewardCoins: 5
        ),
        definition(
            id: "buy_a_pet",
            title: "Buy a pet",
            description: "Purchase any pet from the shop.",
            rewardCoins: 10
        ),
    ]

    static func lockedResponse(authenticated: Bool, coinBalance: Int = 0) -> AchievementsResponse {
        AchievementsResponse(
            authenticated: authenticated,
            achievements: definitions,
            claimedCount: 0,
            totalCount: definitions.count,
            coinBalance: coinBalance
        )
    }

    private static func definition(
        id: String,
        title: String,
        description: String,
        rewardCoins: Int
    ) -> AchievementItem {
        AchievementItem(
            id: id,
            title: title,
            description: description,
            rewardCoins: rewardCoins,
            state: .locked,
            unlockedAt: nil,
            claimedAt: nil
        )
    }
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

    var normalizedVerificationStatus: String {
        verificationStatus?.lowercased() ?? ""
    }

    func confirmsPersistence(of runID: String) -> Bool {
        switch normalizedVerificationStatus {
        case "verified":
            return submittedEntryId == runID
        case "review", "quarantined":
            // The PHP service commits these results but intentionally withholds
            // them from the public ranked list.
            return true
        default:
            return false
        }
    }
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
