import Foundation

public struct ColorSpec: Equatable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let value: String
    public let ink: String
    public let glyph: String
}

public struct DelayRange: Equatable, Codable, Sendable {
    public let minimum: Int
    public let maximum: Int

    public init(_ minimum: Int, _ maximum: Int) {
        self.minimum = minimum
        self.maximum = maximum
    }
}

public struct GameConfiguration: Equatable, Sendable {
    public struct Zen: Equatable, Sendable {
        public let initialTargetDelayMilliseconds: Double
        public let cadenceAdaptation: Double
    }

    public struct Phases: Equatable, Sendable {
        public let colorPatienceStartsAtMilliseconds: Int
        public let gentleRampStartsAtMilliseconds: Int
        public let rareDecoysStartsAtMilliseconds: Int
        public let fourByFourStartsAtMilliseconds: Int
        public let fourByFourChallengeStartsAtMilliseconds: Int
    }

    public struct ResponseWindows: Equatable, Sendable {
        public let comfortable: Int
        public let gentleMinimum: Int
        public let fourByFourStart: Int
        public let fourByFourMinimum: Int
        public let fourByFourDecreasePerHit: Int
    }

    public struct EndlessDifficulty: Equatable, Sendable {
        public let hitsPerTier: Int
        public let maximumDecoys: Int
        public let spawnMinimumDecreasePerTierMilliseconds: Int
        public let spawnMaximumDecreasePerTierMilliseconds: Int
        public let minimumSpawnDelayMilliseconds: Int
        public let maximumSpawnDelayFloorMilliseconds: Int
        public let decoyMinimumDelayMilliseconds: Int
        public let decoyMaximumDelayFloorMilliseconds: Int
        public let decoyMaximumDecreasePerTierMilliseconds: Int
    }

    public struct SpawnDelays: Equatable, Sendable {
        public let warmup: DelayRange
        public let colorPatience: DelayRange
        public let gentleRamp: DelayRange
        public let rareDecoys: DelayRange
        public let fourByFourReset: DelayRange
        public let fourByFourChallenge: DelayRange
    }

    public struct Decoys: Equatable, Sendable {
        public let maximumLifetimeMilliseconds: Int
        public let lifetimeRangeMilliseconds: DelayRange
        public let retryDelayMilliseconds: Int
        public let colorPatience: DelayRange
        public let gentleRamp: DelayRange
        public let rareDecoys: DelayRange
        public let fourByFourReset: DelayRange
        public let fourByFourChallenge: DelayRange
    }

    public struct Streak: Equatable, Sendable {
        public let stepsPerMultiplier: Int
        public let maximumMultiplier: Int
        public let ratingSteps: [SpeedRating: Int]
    }

    public let startingLives: Int
    public let zen: Zen
    public let lifeLossRecoveryMilliseconds: Int
    public let twoByTwoStartsAtHits: Int
    public let phases: Phases
    public let responseWindows: ResponseWindows
    public let endlessDifficulty: EndlessDifficulty
    public let spawnDelays: SpawnDelays
    public let decoys: Decoys
    public let dodgePoints: Int
    public let streak: Streak
    public let scoreFloor: Int
    public let scoreCeiling: Int

    public static let standard = GameConfiguration(
        startingLives: 3,
        zen: Zen(initialTargetDelayMilliseconds: 1_000, cadenceAdaptation: 0.5),
        lifeLossRecoveryMilliseconds: 1_500,
        twoByTwoStartsAtHits: 4,
        phases: Phases(
            colorPatienceStartsAtMilliseconds: 10_000,
            gentleRampStartsAtMilliseconds: 20_000,
            rareDecoysStartsAtMilliseconds: 30_000,
            fourByFourStartsAtMilliseconds: 40_000,
            fourByFourChallengeStartsAtMilliseconds: 50_000
        ),
        responseWindows: ResponseWindows(
            comfortable: 1_000,
            gentleMinimum: 750,
            fourByFourStart: 1_000,
            fourByFourMinimum: 200,
            fourByFourDecreasePerHit: 10
        ),
        endlessDifficulty: EndlessDifficulty(
            hitsPerTier: 10,
            maximumDecoys: 6,
            spawnMinimumDecreasePerTierMilliseconds: 15,
            spawnMaximumDecreasePerTierMilliseconds: 25,
            minimumSpawnDelayMilliseconds: 250,
            maximumSpawnDelayFloorMilliseconds: 500,
            decoyMinimumDelayMilliseconds: 600,
            decoyMaximumDelayFloorMilliseconds: 1_100,
            decoyMaximumDecreasePerTierMilliseconds: 170
        ),
        spawnDelays: SpawnDelays(
            warmup: DelayRange(550, 1_100),
            colorPatience: DelayRange(550, 1_000),
            gentleRamp: DelayRange(500, 950),
            rareDecoys: DelayRange(475, 900),
            fourByFourReset: DelayRange(525, 950),
            fourByFourChallenge: DelayRange(425, 825)
        ),
        decoys: Decoys(
            maximumLifetimeMilliseconds: 750,
            lifetimeRangeMilliseconds: DelayRange(450, 750),
            retryDelayMilliseconds: 150,
            colorPatience: DelayRange(2_200, 3_600),
            gentleRamp: DelayRange(2_000, 3_200),
            rareDecoys: DelayRange(600, 3_400),
            fourByFourReset: DelayRange(2_200, 3_400),
            fourByFourChallenge: DelayRange(600, 2_000)
        ),
        dodgePoints: 550,
        streak: Streak(
            stepsPerMultiplier: 5,
            maximumMultiplier: 5,
            ratingSteps: [.godlike: 2, .perfect: 1, .great: 0, .good: 0]
        ),
        scoreFloor: 100,
        scoreCeiling: 1_000
    )

    /// Returns a copy suitable for renderer/input harnesses that need a wider
    /// first-phase interaction window. Production uses `standard` unchanged.
    public func overridingComfortableResponseWindow(milliseconds: Int) -> GameConfiguration {
        GameConfiguration(
            startingLives: startingLives,
            zen: zen,
            lifeLossRecoveryMilliseconds: lifeLossRecoveryMilliseconds,
            twoByTwoStartsAtHits: twoByTwoStartsAtHits,
            phases: phases,
            responseWindows: ResponseWindows(
                comfortable: max(1, milliseconds),
                gentleMinimum: responseWindows.gentleMinimum,
                fourByFourStart: responseWindows.fourByFourStart,
                fourByFourMinimum: responseWindows.fourByFourMinimum,
                fourByFourDecreasePerHit: responseWindows.fourByFourDecreasePerHit
            ),
            endlessDifficulty: endlessDifficulty,
            spawnDelays: spawnDelays,
            decoys: decoys,
            dodgePoints: dodgePoints,
            streak: streak,
            scoreFloor: scoreFloor,
            scoreCeiling: scoreCeiling
        )
    }
}

public let gameColors: [ColorSpec] = [
    ColorSpec(id: "cyan", name: "Cyan", value: "#35e6df", ink: "#062524", glyph: "●"),
    ColorSpec(id: "yellow", name: "Yellow", value: "#ffd84d", ink: "#2b2100", glyph: "▲"),
    ColorSpec(id: "magenta", name: "Pink", value: "#ff5ba8", ink: "#320018", glyph: "■"),
    ColorSpec(id: "lime", name: "Lime", value: "#8ee85a", ink: "#132707", glyph: "◆"),
    ColorSpec(id: "orange", name: "Orange", value: "#ff914d", ink: "#321300", glyph: "✚"),
    ColorSpec(id: "violet", name: "Violet", value: "#a987ff", ink: "#180c37", glyph: "★"),
]
