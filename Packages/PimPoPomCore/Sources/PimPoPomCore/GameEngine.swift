import Foundation

public final class GameEngine {
    public let configuration: GameConfiguration
    public let colors: [ColorSpec]
    private let random: () -> Double

    public internal(set) var state = GameState.idle
    public internal(set) var mode = GameMode.arcade
    public internal(set) var points = 0
    public internal(set) var lives = 3
    public internal(set) var hits = 0
    public internal(set) var misses = 0
    public internal(set) var dodges = 0
    public internal(set) var reactionTotalMilliseconds = 0
    public internal(set) var fastestReactionMilliseconds: Int?
    public internal(set) var speedRatings: [SpeedRating: Int] = [:]
    public internal(set) var multiplier = 1
    public internal(set) var maximumMultiplierUsed = 1
    public internal(set) var streakProgress = 0
    public internal(set) var reactionBasePoints = 0
    public internal(set) var multiplierBonusPoints = 0
    public internal(set) var multiplierHitCounts: [Int: Int] = [:]
    public internal(set) var multiplierBasePoints: [Int: Int] = [:]
    public internal(set) var startedAt: Double?
    public internal(set) var endedAt: Double?
    public internal(set) var endReason: String?
    public internal(set) var playerColorIndex = 0
    public internal(set) var roundDifficulty: Difficulty?
    public internal(set) var roundKind: RoundKind?
    public internal(set) var activeAt: Double?
    public internal(set) var targetIndex: Int?
    public internal(set) var activeDecoys: [Decoy] = []
    public internal(set) var recentlyExpiredDecoyIndexes: Set<Int> = []
    public internal(set) var nextDecoyID = 1
    public internal(set) var challengeStartHits: Int?
    public internal(set) var recoveryUntil: Double?
    public internal(set) var proofTargetAt: Int?
    public internal(set) var zenTargetDelayMilliseconds = 1_000.0

    private var runProofEvents: [[Int]] = []
    private var runProofFinished = false
    private var runProofEnabled = false
    private var proofClockFloor = 0

    public init(
        configuration: GameConfiguration = .standard,
        colors: [ColorSpec] = gameColors,
        random: @escaping () -> Double = { Double.random(in: 0..<1) }
    ) {
        precondition(colors.count >= 2, "PimPoPom needs at least two colors.")
        self.configuration = configuration
        self.colors = colors
        self.random = random
        reset()
    }

    public func reset() {
        state = .idle
        mode = .arcade
        points = 0
        lives = configuration.startingLives
        hits = 0
        misses = 0
        dodges = 0
        reactionTotalMilliseconds = 0
        fastestReactionMilliseconds = nil
        speedRatings = Dictionary(uniqueKeysWithValues: SpeedRating.allCases.map { ($0, 0) })
        multiplier = 1
        maximumMultiplierUsed = 1
        streakProgress = 0
        reactionBasePoints = 0
        multiplierBonusPoints = 0
        multiplierHitCounts = emptyMultiplierCounts()
        multiplierBasePoints = emptyMultiplierCounts()
        startedAt = nil
        endedAt = nil
        endReason = nil
        playerColorIndex = 0
        roundDifficulty = nil
        roundKind = nil
        activeAt = nil
        targetIndex = nil
        activeDecoys = []
        recentlyExpiredDecoyIndexes = []
        nextDecoyID = 1
        challengeStartHits = nil
        recoveryUntil = nil
        proofTargetAt = nil
        runProofEvents = []
        runProofFinished = false
        runProofEnabled = false
        proofClockFloor = 0
        zenTargetDelayMilliseconds = configuration.zen.initialTargetDelayMilliseconds
    }

    @discardableResult
    public func start(now: Double = 0, mode: GameMode = .arcade) -> GameSnapshot {
        reset()
        state = .waiting
        self.mode = mode
        runProofEnabled = mode == .arcade
        startedAt = now
        playerColorIndex = randomInteger(maximumExclusive: colors.count)
        return snapshot(now: now)
    }

    public func elapsedMilliseconds(now: Double) -> Double {
        guard let startedAt else { return 0 }
        return max(0, (endedAt ?? now) - startedAt)
    }

    public func proofEvents() -> [[Int]] {
        runProofEvents.map(Array.init)
    }

    public func remainingMilliseconds(now _: Double? = nil) -> Double? { nil }

    public func challengeHits() -> Int {
        guard let challengeStartHits else { return 0 }
        return max(0, hits - challengeStartHits)
    }

    public func recoveryRemainingMilliseconds(now: Double) -> Double {
        guard let recoveryUntil else { return 0 }
        return max(0, recoveryUntil - now)
    }

    public func nextDelayMilliseconds(now: Double) -> Double {
        if mode == .zen { return zenTargetDelayMilliseconds }
        let recovery = recoveryRemainingMilliseconds(now: now)
        let difficultyAt = now + recovery
        let difficulty = resolveDifficulty(
            hits: hits,
            elapsedMilliseconds: elapsedMilliseconds(now: difficultyAt),
            challengeHits: challengeHits(),
            configuration: configuration
        )
        let range = difficulty.spawnDelayRangeMilliseconds
        let quiet = jsRound(
            Double(range.minimum) + random() * Double(range.maximum - range.minimum)
        )
        return ceil(recovery) + Double(quiet)
    }

    public func nextDecoyDelayMilliseconds(now: Double) -> Double? {
        if state == .idle || state == .gameOver || mode == .zen { return nil }
        let recovery = recoveryRemainingMilliseconds(now: now)
        let difficultyAt = now + recovery
        let elapsed = proofElapsed(now: difficultyAt)
        if elapsed < configuration.phases.colorPatienceStartsAtMilliseconds {
            return ceil(
                recovery + Double(configuration.phases.colorPatienceStartsAtMilliseconds - elapsed)
            )
        }
        let difficulty = currentDifficulty(now: difficultyAt)
        guard difficulty.gridDimension >= 2,
            let range = difficulty.decoySpawnDelayRangeMilliseconds
        else {
            return ceil(recovery) + Double(configuration.decoys.retryDelayMilliseconds)
        }
        let quiet = jsRound(
            Double(range.minimum) + random() * Double(range.maximum - range.minimum)
        )
        return ceil(recovery) + Double(quiet)
    }

    public func nextDecoyExpiryAt() -> Double? {
        activeDecoys.map(\.expiresAt).min()
    }

    @discardableResult
    public func activateRound(now: Double) -> GameTransition {
        guard state == .waiting else {
            return ignored("not-waiting", now: now)
        }
        if let guarded = recoveryGuard(now: now) { return guarded }
        let settled = settleExpiredDecoys(now: now)
        let elapsed = proofElapsed(now: now)
        if elapsed >= configuration.phases.fourByFourChallengeStartsAtMilliseconds,
            challengeStartHits == nil
        {
            challengeStartHits = hits
        }
        let difficulty = resolveDifficulty(
            hits: hits,
            elapsedMilliseconds: Double(elapsed),
            challengeHits: challengeHits(),
            configuration: configuration
        )
        let cellCount = difficulty.gridDimension * difficulty.gridDimension
        let occupied = recentlyExpiredDecoyIndexes.union(activeDecoys.map(\.cellIndex))
        var available = (0..<cellCount).filter { !occupied.contains($0) }
        if available.isEmpty {
            let activeIndexes = Set(activeDecoys.map(\.cellIndex))
            available = (0..<cellCount).filter { !activeIndexes.contains($0) }
        }
        guard !available.isEmpty else {
            return GameTransition(
                kind: .ignored,
                reason: "no-target-cell",
                snapshot: snapshot(now: now),
                dodgesAwarded: settled.count,
                dodgePointsAwarded: settled.points
            )
        }

        let selectedTarget = available[randomInteger(maximumExclusive: available.count)]
        recentlyExpiredDecoyIndexes.removeAll()
        state = .active
        roundDifficulty = difficulty
        roundKind = .target
        activeAt = now
        targetIndex = selectedTarget
        proofTargetAt = proofElapsed(now: now)
        recordProofEvent([0, proofTargetAt ?? 0, selectedTarget, playerColorIndex])
        return GameTransition(
            kind: .roundActive,
            snapshot: snapshot(now: now),
            dodgesAwarded: settled.count,
            dodgePointsAwarded: settled.points
        )
    }

    @discardableResult
    public func activateDecoy(now: Double) -> GameTransition {
        guard state != .idle, state != .gameOver else {
            return ignored("not-running", now: now)
        }
        guard mode != .zen else {
            return ignored("decoys-disabled", now: now)
        }
        if let guarded = recoveryGuard(now: now) { return guarded }
        let settled = settleExpiredDecoys(now: now)
        let difficulty = currentDifficulty(now: now)
        let cellCount = difficulty.gridDimension * difficulty.gridDimension
        let capacity = min(difficulty.maximumActiveDecoys, max(0, cellCount - 1))

        guard difficulty.decoySpawnDelayRangeMilliseconds != nil, capacity > 0 else {
            recordProofEvent([6, proofElapsed(now: now)])
            return GameTransition(
                kind: .ignored,
                reason: "decoys-disabled",
                snapshot: snapshot(now: now),
                dodgesAwarded: settled.count,
                dodgePointsAwarded: settled.points
            )
        }
        guard activeDecoys.count < capacity else {
            recordProofEvent([6, proofElapsed(now: now)])
            return GameTransition(
                kind: .ignored,
                reason: "decoy-capacity",
                snapshot: snapshot(now: now),
                dodgesAwarded: settled.count,
                dodgePointsAwarded: settled.points
            )
        }

        var occupied = Set(activeDecoys.map(\.cellIndex))
        if let targetIndex { occupied.insert(targetIndex) }
        let available = (0..<cellCount).filter { !occupied.contains($0) }
        guard !available.isEmpty else {
            recordProofEvent([6, proofElapsed(now: now)])
            return GameTransition(
                kind: .ignored,
                reason: "no-decoy-cell",
                snapshot: snapshot(now: now),
                dodgesAwarded: settled.count,
                dodgePointsAwarded: settled.points
            )
        }

        let configuredRange = configuration.decoys.lifetimeRangeMilliseconds
        let maximum = min(
            configuration.decoys.maximumLifetimeMilliseconds,
            configuredRange.maximum
        )
        let minimum = min(maximum, max(0, configuredRange.minimum))
        let lifetime = jsRound(Double(minimum) + random() * Double(maximum - minimum))
        let decoy = Decoy(
            id: nextDecoyID,
            cellIndex: available[randomInteger(maximumExclusive: available.count)],
            colorIndex: differentColorIndex(),
            visibleAt: now,
            expiresAt: now + Double(lifetime)
        )
        nextDecoyID += 1
        activeDecoys.append(decoy)
        recordProofEvent([
            3,
            proofElapsed(now: now),
            decoy.id,
            decoy.cellIndex,
            decoy.colorIndex,
            lifetime,
        ])
        return GameTransition(
            kind: .decoyActive,
            snapshot: snapshot(now: now),
            decoy: decoy,
            lifetimeMilliseconds: lifetime,
            dodgesAwarded: settled.count,
            dodgePointsAwarded: settled.points
        )
    }

    @discardableResult
    public func expireDecoys(now: Double) -> GameTransition {
        guard state != .idle, state != .gameOver else {
            return ignored("not-running", now: now)
        }
        let settled = settleExpiredDecoys(now: now)
        guard settled.count > 0 else {
            return GameTransition(
                kind: .ignored,
                reason: "not-expired",
                snapshot: snapshot(now: now),
                nextExpiryAt: nextDecoyExpiryAt()
            )
        }
        return GameTransition(
            kind: .decoysDodged,
            snapshot: snapshot(now: now),
            decoyIDs: settled.ids,
            dodgesAwarded: settled.count,
            pointsAwarded: settled.points
        )
    }

    @discardableResult
    public func tap(cellIndex: Int, now: Double, resolvedAt: Double? = nil) -> GameTransition {
        let handledAt = resolvedAt ?? now
        let settled = settleExpiredDecoys(now: now)
        if state == .waiting {
            if let guarded = recoveryGuard(now: now) { return guarded }
            return miss(
                reason: .empty,
                now: now,
                reactionMilliseconds: nil,
                settled: settled,
                resolvedAt: handledAt,
                cellIndex: cellIndex
            )
        }
        guard state == .active,
            let activeAt,
            let roundDifficulty
        else {
            return ignored("not-active", now: now)
        }
        let reaction = max(0, now - activeAt)
        if mode != .zen,
            reaction >= Double(roundDifficulty.responseWindowMilliseconds)
        {
            return miss(
                reason: .late,
                now: now,
                reactionMilliseconds: reaction,
                settled: settled,
                resolvedAt: handledAt,
                cellIndex: cellIndex
            )
        }
        guard cellIndex == targetIndex else {
            return miss(
                reason: .wrong,
                now: now,
                reactionMilliseconds: reaction,
                settled: settled,
                resolvedAt: handledAt,
                cellIndex: cellIndex
            )
        }

        let classified = SpeedRating.classify(reactionMilliseconds: reaction)
        let scoredReaction = classified.displayedMilliseconds
        let inputAt = (proofTargetAt ?? proofElapsed(now: activeAt)) + scoredReaction
        let handledProofAt = max(inputAt, proofElapsed(now: handledAt))
        let multiplierUsed = multiplier
        maximumMultiplierUsed = max(maximumMultiplierUsed, multiplierUsed)
        let base = ReactionScoring.points(
            reactionMilliseconds: Double(scoredReaction),
            responseWindowMilliseconds: Double(roundDifficulty.responseWindowMilliseconds),
            configuration: configuration
        )
        let awarded = base * multiplierUsed
        points += awarded
        reactionBasePoints += base
        multiplierBonusPoints += awarded - base
        multiplierHitCounts[multiplierUsed, default: 0] += 1
        multiplierBasePoints[multiplierUsed, default: 0] += base
        hits += 1
        reactionTotalMilliseconds += scoredReaction
        fastestReactionMilliseconds = fastestReactionMilliseconds.map { min($0, scoredReaction) } ?? scoredReaction
        speedRatings[classified.rating, default: 0] += 1
        let multiplierBefore = multiplier
        let steps = configuration.streak.ratingSteps[classified.rating, default: 0]
        if steps > 0 { advanceStreak(steps: steps) }
        let raised = multiplier > multiplierBefore
        if mode == .zen {
            zenTargetDelayMilliseconds += configuration.zen.cadenceAdaptation * (reaction - zenTargetDelayMilliseconds)
        }
        finishRound(clearingDecoys: false)
        let shouldChangeColor = proofElapsed(now: now) >= configuration.phases.colorPatienceStartsAtMilliseconds
        let colorChanged = shouldChangeColor ? changePlayerColor(now: now) : false
        recordProofEvent([1, inputAt, handledProofAt, cellIndex, playerColorIndex])

        return GameTransition(
            kind: .hit,
            snapshot: snapshot(now: now),
            dodgesAwarded: settled.count,
            dodgePointsAwarded: settled.points,
            pointsAwarded: awarded,
            basePointsAwarded: base,
            multiplierUsed: multiplierUsed,
            multiplierAfter: multiplier,
            multiplierRaised: raised,
            reactionMilliseconds: reaction,
            displayedReactionMilliseconds: scoredReaction,
            speedRating: classified.rating,
            colorChanged: colorChanged
        )
    }

    @discardableResult
    public func expireRound(now: Double) -> GameTransition {
        guard state == .active,
            let activeAt,
            let difficulty = roundDifficulty
        else {
            return ignored("not-active", now: now)
        }
        guard mode != .zen else {
            return ignored("target-does-not-expire", now: now)
        }
        let reaction = max(0, now - activeAt)
        guard reaction >= Double(difficulty.responseWindowMilliseconds) else {
            return GameTransition(
                kind: .ignored,
                reason: "not-expired",
                snapshot: snapshot(now: now),
                remainingMilliseconds: Double(difficulty.responseWindowMilliseconds) - reaction
            )
        }
        let settled = settleExpiredDecoys(now: now)
        return miss(
            reason: .late,
            now: now,
            reactionMilliseconds: reaction,
            settled: settled,
            resolvedAt: now,
            cellIndex: -1
        )
    }

    public func finishTimedRun(now: Double) -> GameTransition {
        ignored("not-timed", now: now)
    }

    @discardableResult
    public func endZenRun(now: Double) -> GameTransition {
        if state == .idle { return ignored("not-running", now: now) }
        if state == .gameOver { return ignored("already-ended", now: now) }
        guard mode == .zen else { return ignored("not-zen", now: now) }
        state = .gameOver
        endedAt = max(startedAt ?? now, now)
        endReason = "manual"
        activeDecoys = []
        recentlyExpiredDecoyIndexes = []
        targetIndex = nil
        activeAt = nil
        roundKind = nil
        roundDifficulty = nil
        recoveryUntil = nil
        proofTargetAt = nil
        return GameTransition(kind: .zenEnded, reason: "manual", snapshot: snapshot(now: now))
    }

    public func isRunComplete() -> Bool {
        guard state == .gameOver else { return false }
        return (mode == .arcade && lives == 0 && endReason == "lives") || (mode == .zen && endReason == "manual")
    }

    public func snapshot(now: Double? = nil) -> GameSnapshot {
        let requested = now ?? startedAt ?? 0
        let snapshotAt = endedAt ?? requested
        let elapsed = elapsedMilliseconds(now: snapshotAt)
        let difficulty = currentDifficulty(now: snapshotAt)
        let cellCount = difficulty.gridDimension * difficulty.gridDimension
        var cells = Array(repeating: Cell(), count: cellCount)
        let visibleDecoys = activeDecoys.filter {
            $0.cellIndex < cellCount && $0.expiresAt > snapshotAt
        }
        for decoy in visibleDecoys {
            cells[decoy.cellIndex] = Cell(kind: .decoy, colorIndex: decoy.colorIndex)
        }
        if state == .active, let targetIndex, targetIndex < cellCount {
            cells[targetIndex] = Cell(kind: .target, colorIndex: playerColorIndex)
        }
        let reactionProgress: Double? =
            if mode != .zen,
                state == .active,
                let activeAt
            {
                clamp(
                    1 - (snapshotAt - activeAt) / Double(difficulty.responseWindowMilliseconds),
                    minimum: 0,
                    maximum: 1
                )
            } else {
                nil
            }
        return GameSnapshot(
            state: state,
            mode: mode,
            points: points,
            lives: lives,
            hits: hits,
            misses: misses,
            dodges: dodges,
            fastestReactionMilliseconds: fastestReactionMilliseconds,
            averageReactionMilliseconds: hits > 0
                ? Double(reactionTotalMilliseconds) / Double(hits)
                : nil,
            speedRatings: speedRatings,
            multiplier: multiplier,
            streakProgress: streakProgress,
            streakTarget: configuration.streak.stepsPerMultiplier,
            maximumMultiplier: configuration.streak.maximumMultiplier,
            maximumMultiplierUsed: maximumMultiplierUsed,
            reactionBasePoints: reactionBasePoints,
            multiplierBonusPoints: multiplierBonusPoints,
            multiplierHitCounts: multiplierHitCounts,
            multiplierBasePoints: multiplierBasePoints,
            reactionProgress: reactionProgress,
            nextTargetDelayMilliseconds: mode == .zen ? zenTargetDelayMilliseconds : nil,
            recoveryRemainingMilliseconds: recoveryRemainingMilliseconds(now: snapshotAt),
            elapsedMilliseconds: elapsed,
            remainingMilliseconds: remainingMilliseconds(now: snapshotAt),
            endReason: endReason,
            playerColorIndex: playerColorIndex,
            playerColor: colors[playerColorIndex],
            targetIndex: targetIndex,
            activeDecoys: visibleDecoys,
            nextDecoyExpiryAt: nextDecoyExpiryAt(),
            roundKind: roundKind,
            difficulty: difficulty,
            cells: cells
        )
    }

    private struct SettledDecoys {
        var count = 0
        var points = 0
        var ids: [Int] = []
    }

    private func randomInteger(maximumExclusive: Int) -> Int {
        let value = clamp(random(), minimum: 0, maximum: 0.999_999_999)
        return Int(floor(value * Double(maximumExclusive)))
    }

    private func emptyMultiplierCounts() -> [Int: Int] {
        Dictionary(uniqueKeysWithValues: (1...configuration.streak.maximumMultiplier).map { ($0, 0) })
    }

    private func differentColorIndex() -> Int {
        let offset = 1 + randomInteger(maximumExclusive: colors.count - 1)
        return (playerColorIndex + offset) % colors.count
    }

    private func changePlayerColor(now: Double) -> Bool {
        let visibleDecoyColors = Set(
            activeDecoys.lazy
                .filter { $0.expiresAt > now }
                .map(\.colorIndex)
        )
        let candidates = colors.indices.filter {
            $0 != playerColorIndex && !visibleDecoyColors.contains($0)
        }
        guard !candidates.isEmpty else { return false }
        playerColorIndex = candidates[randomInteger(maximumExclusive: candidates.count)]
        return true
    }

    private func advanceStreak(steps: Int) {
        if multiplier >= configuration.streak.maximumMultiplier {
            streakProgress = configuration.streak.stepsPerMultiplier
            return
        }
        streakProgress += steps
        while streakProgress >= configuration.streak.stepsPerMultiplier,
            multiplier < configuration.streak.maximumMultiplier
        {
            streakProgress -= configuration.streak.stepsPerMultiplier
            multiplier += 1
        }
        if multiplier >= configuration.streak.maximumMultiplier {
            streakProgress = configuration.streak.stepsPerMultiplier
        }
    }

    private func resetStreak() {
        multiplier = 1
        streakProgress = 0
    }

    private func finishRound(clearingDecoys: Bool = true) {
        state = .waiting
        if clearingDecoys { activeDecoys = [] }
        targetIndex = nil
        activeAt = nil
        roundKind = nil
        roundDifficulty = nil
        recoveryUntil = nil
        proofTargetAt = nil
    }

    private func miss(
        reason: MissReason,
        now: Double,
        reactionMilliseconds: Double?,
        settled: SettledDecoys,
        resolvedAt: Double,
        cellIndex: Int
    ) -> GameTransition {
        let inputAt: Int
        if let reactionMilliseconds {
            inputAt = (proofTargetAt ?? proofElapsed(now: now - reactionMilliseconds)) + jsRound(reactionMilliseconds)
        } else {
            inputAt = proofElapsed(now: now)
        }
        let handledAt = max(inputAt, proofElapsed(now: resolvedAt))
        recordProofEvent([2, inputAt, handledAt, reason.proofCode, cellIndex])
        resetStreak()
        let lifeLost = mode == .arcade
        if lifeLost { lives = max(0, lives - 1) }
        misses += 1
        let targetRetained = mode == .zen && state == .active && targetIndex != nil
        if targetRetained {
            activeDecoys = []
            return GameTransition(
                kind: .miss,
                reason: reason.rawValue,
                snapshot: snapshot(now: max(now, resolvedAt)),
                reactionMilliseconds: reactionMilliseconds,
                lifeLost: lifeLost,
                targetRetained: true
            )
        }
        if lifeLost, lives == 0 {
            state = .gameOver
            endedAt = (startedAt ?? 0) + Double(inputAt)
            endReason = "lives"
            activeDecoys = []
            targetIndex = nil
            activeAt = nil
            roundKind = nil
            roundDifficulty = nil
            recoveryUntil = nil
            proofTargetAt = nil
            recordFinishElapsed(logical: inputAt, handled: handledAt)
        } else {
            finishRound()
            if lifeLost {
                recoveryUntil = max(now, resolvedAt) + Double(configuration.lifeLossRecoveryMilliseconds)
            }
        }
        return GameTransition(
            kind: .miss,
            reason: reason.rawValue,
            snapshot: snapshot(now: max(now, resolvedAt)),
            dodgesAwarded: settled.count,
            dodgePointsAwarded: settled.points,
            reactionMilliseconds: reactionMilliseconds,
            lifeLost: lifeLost,
            targetRetained: false
        )
    }

    private func currentDifficulty(now: Double) -> Difficulty {
        var difficulty =
            state == .active && roundDifficulty != nil
            ? roundDifficulty!
            : resolveDifficulty(
                hits: hits,
                elapsedMilliseconds: Double(proofElapsed(now: now)),
                challengeHits: challengeHits(),
                configuration: configuration
            )
        if mode == .zen {
            difficulty = Difficulty(
                gridDimension: difficulty.gridDimension,
                phaseID: difficulty.phaseID,
                phaseName: difficulty.phaseName,
                responseWindowMilliseconds: difficulty.responseWindowMilliseconds,
                spawnDelayRangeMilliseconds: difficulty.spawnDelayRangeMilliseconds,
                decoySpawnDelayRangeMilliseconds: nil,
                maximumActiveDecoys: 0,
                challengeTier: difficulty.challengeTier,
                paceLevel: difficulty.paceLevel
            )
        }
        return difficulty
    }

    private func proofElapsed(now: Double) -> Int {
        guard let startedAt else { return 0 }
        return max(proofClockFloor, jsRound(max(0, now - startedAt)))
    }

    private func recordProofEvent(_ event: [Int]) {
        guard runProofEnabled else { return }
        runProofEvents.append(event)
        let clockIndex = [1, 2, 5].contains(event[0]) ? 2 : 1
        proofClockFloor = max(proofClockFloor, event.indices.contains(clockIndex) ? event[clockIndex] : 0)
    }

    private func recordFinishElapsed(logical: Int, handled: Int) {
        guard !runProofFinished else { return }
        recordProofEvent([5, logical, max(logical, handled)])
        runProofFinished = true
    }

    private func recoveryGuard(now: Double) -> GameTransition? {
        let remaining = recoveryRemainingMilliseconds(now: now)
        if remaining <= 0 {
            recoveryUntil = nil
            return nil
        }
        return GameTransition(
            kind: .ignored,
            reason: "recovering",
            snapshot: snapshot(now: now),
            remainingMilliseconds: remaining
        )
    }

    private func settleExpiredDecoys(now: Double) -> SettledDecoys {
        guard state != .idle, state != .gameOver, !activeDecoys.isEmpty else {
            return SettledDecoys()
        }
        let expired = activeDecoys.filter { $0.expiresAt <= now }
        guard !expired.isEmpty else { return SettledDecoys() }
        activeDecoys.removeAll { $0.expiresAt <= now }
        for decoy in expired { recentlyExpiredDecoyIndexes.insert(decoy.cellIndex) }
        let awarded = mode == .zen ? 0 : expired.count * configuration.dodgePoints
        points += awarded
        dodges += expired.count
        let ids = expired.map(\.id)
        recordProofEvent([4, proofElapsed(now: now)] + ids)
        return SettledDecoys(count: expired.count, points: awarded, ids: ids)
    }

    private func ignored(_ reason: String, now: Double) -> GameTransition {
        GameTransition(kind: .ignored, reason: reason, snapshot: snapshot(now: now))
    }
}
