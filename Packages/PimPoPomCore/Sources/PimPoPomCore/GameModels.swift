import Foundation

public enum GameMode: String, CaseIterable, Codable, Hashable, Sendable {
    case arcade = "normal"
    case zen

    public var displayName: String {
        switch self {
        case .arcade: "Arcade"
        case .zen: "Zen"
        }
    }
}

public enum GameState: String, Codable, Sendable {
    case idle
    case waiting
    case active
    case gameOver = "game-over"
}

public enum RoundKind: String, Codable, Sendable {
    case target
}

public enum CellKind: String, Codable, Sendable {
    case idle
    case target
    case decoy
}

public enum MissReason: String, Codable, Sendable {
    case empty
    case wrong
    case late

    var proofCode: Int {
        switch self {
        case .empty: 0
        case .wrong: 1
        case .late: 2
        }
    }
}

public struct Cell: Equatable, Codable, Sendable {
    public let kind: CellKind
    public let colorIndex: Int?

    public init(kind: CellKind = .idle, colorIndex: Int? = nil) {
        self.kind = kind
        self.colorIndex = colorIndex
    }
}

public struct Decoy: Equatable, Codable, Sendable {
    public let id: Int
    public let cellIndex: Int
    public let colorIndex: Int
    public let visibleAt: Double
    public let expiresAt: Double
}

public struct Difficulty: Equatable, Codable, Sendable {
    public let gridDimension: Int
    public let phaseID: String
    public let phaseName: String
    public let responseWindowMilliseconds: Int
    public let spawnDelayRangeMilliseconds: DelayRange
    public let decoySpawnDelayRangeMilliseconds: DelayRange?
    public let maximumActiveDecoys: Int
    public let challengeTier: Int
    public let paceLevel: Int
}

public struct GameSnapshot: Equatable, Sendable {
    public let state: GameState
    public let mode: GameMode
    public let points: Int
    public let lives: Int
    public let hits: Int
    public let misses: Int
    public let dodges: Int
    public let fastestReactionMilliseconds: Int?
    public let averageReactionMilliseconds: Double?
    public let speedRatings: [SpeedRating: Int]
    public let multiplier: Int
    public let streakProgress: Int
    public let streakTarget: Int
    public let maximumMultiplier: Int
    public let maximumMultiplierUsed: Int
    public let reactionBasePoints: Int
    public let multiplierBonusPoints: Int
    public let multiplierHitCounts: [Int: Int]
    public let multiplierBasePoints: [Int: Int]
    public let reactionProgress: Double?
    public let nextTargetDelayMilliseconds: Double?
    public let recoveryRemainingMilliseconds: Double
    public let elapsedMilliseconds: Double
    public let remainingMilliseconds: Double?
    public let endReason: String?
    public let playerColorIndex: Int
    public let playerColor: ColorSpec
    public let targetIndex: Int?
    public let activeDecoys: [Decoy]
    public let nextDecoyExpiryAt: Double?
    public let roundKind: RoundKind?
    public let difficulty: Difficulty
    public let cells: [Cell]
}

public enum TransitionKind: String, Sendable {
    case ignored
    case roundActive = "round-active"
    case decoyActive = "decoy-active"
    case decoysDodged = "decoys-dodged"
    case hit
    case miss
    case zenEnded = "zen-ended"
}

public struct GameTransition: Sendable {
    public let kind: TransitionKind
    public let reason: String?
    public let snapshot: GameSnapshot
    public let remainingMilliseconds: Double?
    public let nextExpiryAt: Double?
    public let decoy: Decoy?
    public let decoyIDs: [Int]
    public let lifetimeMilliseconds: Int?
    public let dodgesAwarded: Int
    public let dodgePointsAwarded: Int
    public let pointsAwarded: Int?
    public let basePointsAwarded: Int?
    public let multiplierUsed: Int?
    public let multiplierAfter: Int?
    public let multiplierRaised: Bool?
    public let reactionMilliseconds: Double?
    public let displayedReactionMilliseconds: Int?
    public let speedRating: SpeedRating?
    public let colorChanged: Bool?
    public let lifeLost: Bool?
    public let targetRetained: Bool?

    init(
        kind: TransitionKind,
        reason: String? = nil,
        snapshot: GameSnapshot,
        remainingMilliseconds: Double? = nil,
        nextExpiryAt: Double? = nil,
        decoy: Decoy? = nil,
        decoyIDs: [Int] = [],
        lifetimeMilliseconds: Int? = nil,
        dodgesAwarded: Int = 0,
        dodgePointsAwarded: Int = 0,
        pointsAwarded: Int? = nil,
        basePointsAwarded: Int? = nil,
        multiplierUsed: Int? = nil,
        multiplierAfter: Int? = nil,
        multiplierRaised: Bool? = nil,
        reactionMilliseconds: Double? = nil,
        displayedReactionMilliseconds: Int? = nil,
        speedRating: SpeedRating? = nil,
        colorChanged: Bool? = nil,
        lifeLost: Bool? = nil,
        targetRetained: Bool? = nil
    ) {
        self.kind = kind
        self.reason = reason
        self.snapshot = snapshot
        self.remainingMilliseconds = remainingMilliseconds
        self.nextExpiryAt = nextExpiryAt
        self.decoy = decoy
        self.decoyIDs = decoyIDs
        self.lifetimeMilliseconds = lifetimeMilliseconds
        self.dodgesAwarded = dodgesAwarded
        self.dodgePointsAwarded = dodgePointsAwarded
        self.pointsAwarded = pointsAwarded
        self.basePointsAwarded = basePointsAwarded
        self.multiplierUsed = multiplierUsed
        self.multiplierAfter = multiplierAfter
        self.multiplierRaised = multiplierRaised
        self.reactionMilliseconds = reactionMilliseconds
        self.displayedReactionMilliseconds = displayedReactionMilliseconds
        self.speedRating = speedRating
        self.colorChanged = colorChanged
        self.lifeLost = lifeLost
        self.targetRetained = targetRetained
    }
}
