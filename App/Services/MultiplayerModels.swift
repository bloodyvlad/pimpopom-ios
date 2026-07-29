import Foundation

enum MultiplayerAPIContract {
    static let basePath = "/api/mobile/v1/multiplayer"
    static let buildID = "20260729-1"
    static let mode = "own_color"
    static let ruleset = "multiplayer-own-color-v1"
    static let protocolVersion = 1
    static let proofVersion = 1
    static let minimumPlayers = 2
    static let maximumPlayers = 4
    static let maximumEvents = 2_500
    static let maximumDurationMilliseconds = 900_000
}

struct MultiplayerLobbyHost: Codable, Equatable {
    let name: String
    let petId: String?
}

struct MultiplayerLobby: Codable, Equatable, Identifiable {
    let matchId: String
    let mode: String
    let capacity: Int
    let playerCount: Int
    let host: MultiplayerLobbyHost
    let createdAt: String
    let expiresAt: String

    var id: String { matchId }
}

struct MultiplayerLobbyListResponse: Codable, Equatable {
    let lobbies: [MultiplayerLobby]
}

struct MultiplayerParticipant: Codable, Equatable, Identifiable {
    let participantId: String
    let seat: Int
    let colorIndex: Int
    let name: String
    let petId: String?
    let ready: Bool
    let status: String
    let isCurrentPlayer: Bool

    var id: String { participantId }
}

struct MultiplayerManifestParticipant: Codable, Equatable {
    let participantId: String
    let seat: Int
    let colorIndex: Int
}

/// The exact manifest DTO returned by PHP.
///
/// The pure gameplay layer maps this into its own validated manifest value
/// before starting a match. The server-provided seed remains an opaque nonce.
struct MultiplayerStartManifest: Codable, Equatable {
    let protocolVersion: Int
    let ruleset: String
    let proofVersion: Int
    let matchId: String
    let buildId: String
    let seed: String
    let startingLives: Int
    let participants: [MultiplayerManifestParticipant]
    let manifestHash: String
}

struct MultiplayerMatch: Codable, Equatable, Identifiable {
    let matchId: String
    let state: String
    let mode: String
    let capacity: Int
    let selfParticipantId: String
    let isCreator: Bool
    let playerGroup: Int
    let participants: [MultiplayerParticipant]
    let expiresAt: String
    let manifest: MultiplayerStartManifest?

    var id: String { matchId }
}

struct MultiplayerMatchResponse: Codable, Equatable {
    let match: MultiplayerMatch
}

struct MultiplayerLeaveResponse: Codable, Equatable {
    let left: Bool
    let matchCancelled: Bool
}

struct MultiplayerRosterConfirmationRequest: Codable, Equatable {
    let localGamePlayerId: String
    let observedGamePlayerIds: [String]
    let coordinatorGamePlayerId: String
}

struct MultiplayerRosterConfirmationResponse: Codable, Equatable {
    let confirmed: Bool
    let confirmedCount: Int
    let participantCount: Int
}

struct MultiplayerStartResponse: Codable, Equatable {
    let manifest: MultiplayerStartManifest
    let participants: [MultiplayerParticipant]
}

struct MultiplayerTranscriptSubmission: Codable, Equatable {
    let matchId: String
    let buildId: String
    let ruleset: String
    let protocolVersion: Int
    let proofVersion: Int
    let events: [[Int]]

    init(matchId: String, events: [[Int]]) {
        self.matchId = matchId
        buildId = MultiplayerAPIContract.buildID
        ruleset = MultiplayerAPIContract.ruleset
        protocolVersion = MultiplayerAPIContract.protocolVersion
        proofVersion = MultiplayerAPIContract.proofVersion
        self.events = events
    }
}

struct MultiplayerSubmissionRequest: Codable, Equatable {
    let manifestHash: String
    let transcript: MultiplayerTranscriptSubmission
}

struct MultiplayerSettlementResult: Codable, Equatable, Identifiable {
    let resultId: String
    let participantId: String
    let place: Int
    let playerCount: Int
    let name: String
    let petId: String?
    let score: Int
    let survivalMs: Int
    let hits: Int
    let misses: Int
    let dodges: Int
    let fastestReactionMs: Int?
    let averageReactionMs: Int?
    let maxMultiplier: Int
    let speedRatings: SpeedRatingCounts
    let isCurrentPlayer: Bool

    var id: String { resultId }
}

/// One response model intentionally covers collecting, settled, and review
/// payloads. Additive fields from PHP remain ignored by `JSONDecoder`.
struct MultiplayerSettlementResponse: Codable, Equatable {
    let duplicate: Bool?
    let conflict: Bool?
    let state: String
    let submittedCount: Int?
    let participantCount: Int?
    let leaderboardEligible: Bool
    let verification: String?
    let reviewReason: String?
    let results: [MultiplayerSettlementResult]?
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

@MainActor
protocol MultiplayerBackendServing: AnyObject {
    func loadMultiplayerLeaderboard() async throws -> MultiplayerLeaderboardResponse
    func loadMultiplayerLobbies(limit: Int) async throws -> MultiplayerLobbyListResponse
    func createMultiplayerMatch(capacity: Int) async throws -> MultiplayerMatch
    func loadMultiplayerMatch(_ matchID: String) async throws -> MultiplayerMatch
    func joinMultiplayerMatch(_ matchID: String) async throws -> MultiplayerMatch
    func leaveMultiplayerMatch(_ matchID: String) async throws -> MultiplayerLeaveResponse
    func setMultiplayerReadiness(
        _ matchID: String,
        ready: Bool
    ) async throws -> MultiplayerMatch
    func confirmMultiplayerGameKitRoster(
        _ matchID: String,
        roster: MultiplayerGameKitRoster
    ) async throws -> MultiplayerRosterConfirmationResponse
    func startMultiplayerMatch(_ matchID: String) async throws -> MultiplayerStartResponse
    func submitMultiplayerTranscript(
        matchID: String,
        manifestHash: String,
        transcript: MultiplayerTranscriptSubmission
    ) async throws -> MultiplayerSettlementResponse
    func loadMultiplayerSettlement(_ matchID: String) async throws
        -> MultiplayerSettlementResponse
}
