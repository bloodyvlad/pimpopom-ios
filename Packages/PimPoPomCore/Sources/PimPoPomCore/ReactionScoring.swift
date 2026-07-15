import Foundation

@inline(__always)
func jsRound(_ value: Double) -> Int {
    Int(floor(value + 0.5))
}

@inline(__always)
func clamp(_ value: Double, minimum: Double, maximum: Double) -> Double {
    min(maximum, max(minimum, value))
}

public enum SpeedRating: String, CaseIterable, Codable, Hashable, Sendable {
    case godlike
    case perfect
    case great
    case good

    public var label: String {
        rawValue.capitalized
    }

    public static func classify(reactionMilliseconds: Double) -> (rating: Self, displayedMilliseconds: Int) {
        let displayed = jsRound(max(0, reactionMilliseconds))
        let rating: Self =
            if displayed < 250 {
                .godlike
            } else if displayed < 350 {
                .perfect
            } else if displayed < 450 {
                .great
            } else {
                .good
            }
        return (rating, displayed)
    }
}

public enum ReactionScoring {
    public static func points(
        reactionMilliseconds: Double,
        responseWindowMilliseconds: Double,
        configuration: GameConfiguration = .standard
    ) -> Int {
        guard responseWindowMilliseconds > 0 else { return configuration.scoreFloor }
        let remainingRatio = clamp(
            1 - reactionMilliseconds / responseWindowMilliseconds,
            minimum: 0,
            maximum: 1
        )
        let range = configuration.scoreCeiling - configuration.scoreFloor
        return jsRound(Double(configuration.scoreFloor) + Double(range) * pow(remainingRatio, 2))
    }
}

public func orthogonalNeighbors(index: Int, dimension: Int) -> [Int] {
    let row = index / dimension
    let column = index % dimension
    var neighbors: [Int] = []
    if row > 0 { neighbors.append(index - dimension) }
    if column < dimension - 1 { neighbors.append(index + 1) }
    if row < dimension - 1 { neighbors.append(index + dimension) }
    if column > 0 { neighbors.append(index - 1) }
    return neighbors
}

public func resolveDifficulty(
    hits: Int,
    elapsedMilliseconds: Double,
    challengeHits: Int = 0,
    configuration: GameConfiguration = .standard
) -> Difficulty {
    let elapsed = jsRound(max(0, elapsedMilliseconds))
    let phases = configuration.phases
    let windows = configuration.responseWindows
    let delays = configuration.spawnDelays
    let gridDimension =
        elapsed >= phases.fourByFourStartsAtMilliseconds
        ? 4
        : (hits >= configuration.twoByTwoStartsAtHits ? 2 : 1)

    var phaseID = "warmup"
    var phaseName = "Warm-up"
    var responseWindow = windows.comfortable
    var spawnDelay = delays.warmup
    var decoyDelay: DelayRange?
    var maximumActiveDecoys = 0
    var challengeTier = 0

    if elapsed >= phases.colorPatienceStartsAtMilliseconds {
        phaseID = "color-patience"
        phaseName = "Color patience"
        spawnDelay = delays.colorPatience
        decoyDelay = configuration.decoys.colorPatience
        maximumActiveDecoys = 1
    }
    if elapsed >= phases.gentleRampStartsAtMilliseconds {
        let duration = phases.rareDecoysStartsAtMilliseconds - phases.gentleRampStartsAtMilliseconds
        let progress = clamp(
            Double(elapsed - phases.gentleRampStartsAtMilliseconds) / Double(duration),
            minimum: 0,
            maximum: 1
        )
        phaseID = "gentle-ramp"
        phaseName = "Gentle pace"
        responseWindow = jsRound(
            Double(windows.comfortable) - Double(windows.comfortable - windows.gentleMinimum) * progress
        )
        spawnDelay = delays.gentleRamp
        decoyDelay = configuration.decoys.gentleRamp
        maximumActiveDecoys = 1
    }
    if elapsed >= phases.rareDecoysStartsAtMilliseconds {
        phaseID = "rare-decoys"
        phaseName = "Rare decoys"
        responseWindow = windows.gentleMinimum
        spawnDelay = delays.rareDecoys
        decoyDelay = configuration.decoys.rareDecoys
        maximumActiveDecoys = 2
    }
    if elapsed >= phases.fourByFourStartsAtMilliseconds {
        phaseID = "four-by-four-reset"
        phaseName = "16-cell reset"
        responseWindow = windows.fourByFourStart
        spawnDelay = delays.fourByFourReset
        decoyDelay = configuration.decoys.fourByFourReset
        maximumActiveDecoys = 1
    }
    if elapsed >= phases.fourByFourChallengeStartsAtMilliseconds {
        let endless = configuration.endlessDifficulty
        challengeTier = challengeHits / endless.hitsPerTier
        let names = [
            "16-cell focus", "Twin decoys", "Triple threat",
            "Pressure", "Overdrive", "Endurance",
        ]
        phaseID = "four-by-four-challenge"
        phaseName = names[min(challengeTier, names.count - 1)]
        responseWindow = max(
            windows.fourByFourMinimum,
            windows.fourByFourStart - challengeHits * windows.fourByFourDecreasePerHit
        )
        spawnDelay = DelayRange(
            max(
                endless.minimumSpawnDelayMilliseconds,
                delays.fourByFourChallenge.minimum - challengeTier * endless.spawnMinimumDecreasePerTierMilliseconds
            ),
            max(
                endless.maximumSpawnDelayFloorMilliseconds,
                delays.fourByFourChallenge.maximum - challengeTier * endless.spawnMaximumDecreasePerTierMilliseconds
            )
        )
        decoyDelay = DelayRange(
            endless.decoyMinimumDelayMilliseconds,
            max(
                endless.decoyMaximumDelayFloorMilliseconds,
                configuration.decoys.fourByFourChallenge.maximum - challengeTier
                    * endless.decoyMaximumDecreasePerTierMilliseconds
            )
        )
        maximumActiveDecoys = min(endless.maximumDecoys, 2 + challengeTier)
    }

    let paceLevel: Int
    if gridDimension == 1 {
        paceLevel = 0
    } else if phaseID == "warmup" || phaseID == "color-patience" {
        paceLevel = 1
    } else if phaseID == "gentle-ramp" {
        paceLevel = 2
    } else if phaseID == "rare-decoys" {
        paceLevel = 3
    } else if phaseID == "four-by-four-reset" {
        paceLevel = 4
    } else {
        paceLevel = min(11, 5 + challengeTier)
    }

    return Difficulty(
        gridDimension: gridDimension,
        phaseID: phaseID,
        phaseName: phaseName,
        responseWindowMilliseconds: responseWindow,
        spawnDelayRangeMilliseconds: spawnDelay,
        decoySpawnDelayRangeMilliseconds: decoyDelay,
        maximumActiveDecoys: maximumActiveDecoys,
        challengeTier: challengeTier,
        paceLevel: paceLevel
    )
}
