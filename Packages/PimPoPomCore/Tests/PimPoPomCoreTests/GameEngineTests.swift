import Testing

@testable import PimPoPomCore

private final class RandomSequence {
    private var values: [Double]
    private let fallback: Double

    init(_ values: [Double], fallback: Double = 0.99) {
        self.values = values
        self.fallback = fallback
    }

    func next() -> Double {
        values.isEmpty ? fallback : values.removeFirst()
    }
}

private func makeEngine(random: @escaping () -> Double = { 0.99 }) -> GameEngine {
    GameEngine(random: random)
}

@discardableResult
private func hitRound(
    _ engine: GameEngine,
    activeAt: Double,
    reaction: Double = 50
) -> GameTransition {
    let active = engine.activateRound(now: activeAt)
    return engine.tap(
        cellIndex: active.snapshot.targetIndex!,
        now: activeAt + reaction
    )
}

@Test("Opening play begins with one target and a 1000 ms lifetime")
func openingRound() {
    let engine = makeEngine()
    engine.start(now: 0)
    let result = engine.activateRound(now: 100)
    #expect(result.kind == .roundActive)
    #expect(result.snapshot.difficulty.gridDimension == 1)
    #expect(result.snapshot.difficulty.responseWindowMilliseconds == 1_000)
    #expect(result.snapshot.cells.filter { $0.kind == .target }.count == 1)
}

@Test("Proof records separately rounded target, input, and handler times")
func proofRounding() {
    let engine = makeEngine()
    engine.start(now: 1_000.2)
    let active = engine.activateRound(now: 1_100.6)
    _ = engine.tap(
        cellIndex: active.snapshot.targetIndex!,
        now: 1_250.4,
        resolvedAt: 1_251.8
    )
    #expect(
        engine.proofEvents() == [
            [0, 100, active.snapshot.targetIndex!],
            [1, 250, 252, active.snapshot.targetIndex!],
        ])
}

@Test("Proof time remains monotonic after separately rounded intervals")
func proofMonotonicity() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0.2)
    engine.hits = 4
    let target = engine.activateRound(now: 10_000.8)
    _ = engine.tap(cellIndex: target.snapshot.targetIndex!, now: 10_186.4)
    _ = engine.activateDecoy(now: 10_186.5)
    #expect(
        engine.proofEvents().map { Array($0.prefix(2)) } == [
            [0, 10_001], [1, 10_187], [3, 10_187],
        ])
}

@Test("Zen cadence moves halfway toward every correct reaction")
func zenCadence() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0, mode: .zen)
    #expect(engine.nextDelayMilliseconds(now: 0) == 1_000)
    let faster = hitRound(engine, activeAt: 1_000, reaction: 400)
    #expect(faster.snapshot.nextTargetDelayMilliseconds == 700)
    let slower = hitRound(engine, activeAt: 2_100, reaction: 1_000)
    #expect(slower.snapshot.nextTargetDelayMilliseconds == 850)
    engine.start(now: 4_000, mode: .zen)
    #expect(engine.nextDelayMilliseconds(now: 4_000) == 1_000)
}

@Test("Board advances from 1x1 to 2x2 and then 4x4")
func gridProgression() {
    let engine = makeEngine()
    engine.start(now: 0)
    for hit in 0..<4 {
        hitRound(engine, activeAt: 100 + Double(hit * 200))
    }
    #expect(engine.snapshot(now: 9_000).difficulty.gridDimension == 2)
    #expect(engine.snapshot(now: 40_000).difficulty.gridDimension == 4)
}

@Test("Gentle and endless difficulty preserve exact boundaries")
func difficultyBoundaries() {
    #expect(resolveDifficulty(hits: 4, elapsedMilliseconds: 20_000).responseWindowMilliseconds == 1_000)
    #expect(resolveDifficulty(hits: 4, elapsedMilliseconds: 25_000).responseWindowMilliseconds == 875)
    #expect(resolveDifficulty(hits: 4, elapsedMilliseconds: 29_000).responseWindowMilliseconds == 775)
    #expect(resolveDifficulty(hits: 4, elapsedMilliseconds: 30_000).responseWindowMilliseconds == 750)
    #expect(resolveDifficulty(hits: 8, elapsedMilliseconds: 23_460.49).responseWindowMilliseconds == 914)
    #expect(resolveDifficulty(hits: 8, elapsedMilliseconds: 23_460.51).responseWindowMilliseconds == 913)
    let capped = resolveDifficulty(hits: 500, elapsedMilliseconds: 180_000, challengeHits: 480)
    #expect(capped.responseWindowMilliseconds == 200)
    #expect(capped.maximumActiveDecoys == 6)
    #expect(capped.decoySpawnDelayRangeMilliseconds == DelayRange(600, 1_100))
}

@Test("Independent decoy cadence wakes at the phase boundary")
func decoyCadence() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    #expect(engine.nextDecoyDelayMilliseconds(now: 2_500) == 7_500)
    engine.hits = 4
    #expect(engine.nextDecoyDelayMilliseconds(now: 10_000) == 2_200)
    #expect(engine.nextDecoyDelayMilliseconds(now: 35_000) == 600)
}

@Test("Decoys overlap and never use the current player color")
func overlappingDecoys() {
    let engine = makeEngine(random: { 0.25 })
    engine.start(now: 0)
    engine.hits = 4
    let first = engine.activateDecoy(now: 35_000)
    let target = engine.activateRound(now: 35_020)
    let second = engine.activateDecoy(now: 35_040)
    #expect(first.kind == .decoyActive)
    #expect(target.kind == .roundActive)
    #expect(second.kind == .decoyActive)
    #expect(second.snapshot.activeDecoys.count == 2)
    #expect(second.decoy?.colorIndex != second.snapshot.playerColorIndex)
}

@Test("Natural decoy expiry awards a neutral 550 point dodge")
func naturalDecoyExpiry() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    engine.hits = 4
    let decoy = engine.activateDecoy(now: 10_100)
    let result = engine.expireDecoys(now: decoy.decoy!.expiresAt)
    #expect(result.kind == .decoysDodged)
    #expect(result.dodgesAwarded == 1)
    #expect(result.pointsAwarded == 550)
    #expect(result.snapshot.dodges == 1)
    #expect(result.snapshot.multiplier == 1)
}

@Test("Ignored decoy opportunities and grouped expiries preserve exact proof tuples")
func decoyProofTuples() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    let ignored = engine.activateDecoy(now: 100)
    #expect(ignored.reason == "decoys-disabled")
    #expect(engine.proofEvents() == [[6, 100]])

    engine.hits = 4
    let first = engine.activateDecoy(now: 35_000).decoy!
    let second = engine.activateDecoy(now: 35_010).decoy!
    let expired = engine.expireDecoys(now: max(first.expiresAt, second.expiresAt))
    #expect(expired.decoyIDs == [1, 2])
    #expect(engine.proofEvents().last == [4, 35_460, 1, 2])
}

@Test("An expired decoy cell is reserved from the next target")
func expiredCellReservation() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    engine.hits = 4
    let decoy = engine.activateDecoy(now: 10_100).decoy!
    let target = engine.activateRound(now: decoy.expiresAt)
    #expect(target.dodgesAwarded == 1)
    #expect(target.snapshot.targetIndex != decoy.cellIndex)
}

@Test("A correct hit clears visible decoys without a dodge")
func hitClearsDecoys() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    engine.hits = 4
    let active = engine.activateRound(now: 35_000)
    _ = engine.activateDecoy(now: 35_050)
    let hit = engine.tap(cellIndex: active.snapshot.targetIndex!, now: 35_100)
    #expect(hit.kind == .hit)
    #expect(hit.snapshot.activeDecoys.isEmpty)
    #expect(hit.snapshot.dodges == 0)
}

@Test("A hit clears an overdue but unsettled decoy without awarding a dodge")
func hitClearsUnsettledExpiredDecoy() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    engine.hits = 4
    let active = engine.activateRound(now: 35_000)
    let decoy = engine.activateDecoy(now: 35_010).decoy!
    #expect(decoy.expiresAt == 35_460)

    let hit = engine.tap(cellIndex: active.snapshot.targetIndex!, now: 35_470)
    #expect(hit.kind == .hit)
    #expect(hit.snapshot.dodges == 0)
    #expect(!engine.proofEvents().contains { $0.first == 4 })
}

@Test("Normal ends on exactly the third mistake and records finish")
func threeLifeEnding() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    _ = engine.tap(cellIndex: 0, now: 100)
    _ = engine.tap(cellIndex: 0, now: 200)
    let third = engine.tap(cellIndex: 0, now: 300)
    #expect(third.kind == .miss)
    #expect(third.snapshot.state == .gameOver)
    #expect(third.snapshot.lives == 0)
    #expect(third.snapshot.elapsedMilliseconds == 300)
    #expect(engine.proofEvents().last == [5, 300, 300])
    #expect(engine.isRunComplete())
}

@Test("Lost lives enforce recovery and waiting taps restart it")
func recovery() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    _ = engine.tap(cellIndex: 0, now: 100)
    let blocked = engine.activateRound(now: 1_599)
    #expect(blocked.reason == "recovering")
    #expect(blocked.remainingMilliseconds == 1)
    _ = engine.tap(cellIndex: 0, now: 1_000)
    #expect(engine.snapshot(now: 1_000).lives == 1)
    #expect(engine.snapshot(now: 1_000).recoveryRemainingMilliseconds == 1_500)
}

@Test("Life-loss recovery is anchored to delayed handler resolution")
func recoveryUsesResolvedTime() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    _ = engine.tap(cellIndex: 0, now: 100, resolvedAt: 500)
    #expect(engine.snapshot(now: 500).recoveryRemainingMilliseconds == 1_500)
    #expect(engine.activateRound(now: 1_999).remainingMilliseconds == 1)
    #expect(engine.activateRound(now: 2_000).kind == .roundActive)
}

@Test("Exact deadline input is late and cannot be charged twice")
func exactDeadline() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    let active = engine.activateRound(now: 1_000)
    let deadline = 1_000 + Double(active.snapshot.difficulty.responseWindowMilliseconds)
    let miss = engine.tap(cellIndex: active.snapshot.targetIndex!, now: deadline)
    let stale = engine.expireRound(now: deadline + 16)
    #expect(miss.reason == "late")
    #expect(stale.kind == .ignored)
    #expect(engine.misses == 1)
}

@Test("Zen wrong taps retain target and never remove lives")
func zenRetainsTarget() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0, mode: .zen)
    let active = engine.activateRound(now: 1_000)
    let miss = engine.tap(cellIndex: active.snapshot.targetIndex! + 1, now: 3_000)
    #expect(miss.kind == .miss)
    #expect(miss.targetRetained == true)
    #expect(miss.snapshot.state == .active)
    #expect(miss.snapshot.lives == 3)
    #expect(engine.expireRound(now: 50_000).reason == "target-does-not-expire")
}

@Test("Ending Zen freezes an ephemeral result")
func endZen() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 1_000, mode: .zen)
    _ = hitRound(engine, activeAt: 2_000, reaction: 250)
    let ended = engine.endZenRun(now: 3_000)
    #expect(ended.kind == .zenEnded)
    #expect(ended.snapshot.state == .gameOver)
    #expect(ended.snapshot.elapsedMilliseconds == 2_000)
    #expect(engine.snapshot(now: 10_000).elapsedMilliseconds == 2_000)
    #expect(engine.proofEvents().isEmpty)
}

@Test("Streak overflow raises multipliers only for subsequent taps")
func streakProgression() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    let first = hitRound(engine, activeAt: 100, reaction: 100)
    let second = hitRound(engine, activeAt: 300, reaction: 100)
    let threshold = hitRound(engine, activeAt: 500, reaction: 100)
    #expect(first.multiplierUsed == 1)
    #expect(second.multiplierUsed == 1)
    #expect(threshold.multiplierUsed == 1)
    #expect(threshold.multiplierAfter == 2)
    let next = hitRound(engine, activeAt: 700, reaction: 100)
    #expect(next.multiplierUsed == 2)
}

@Test("Five-times cap and score buckets reconcile exactly")
func maximumMultiplierAccounting() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    var last: GameTransition?
    for index in 0..<11 {
        last = hitRound(engine, activeAt: Double(100 + index * 200), reaction: 100)
    }
    let snapshot = last!.snapshot
    #expect(snapshot.multiplier == 5)
    #expect(snapshot.maximumMultiplierUsed == 5)
    #expect(snapshot.streakProgress == snapshot.streakTarget)
    #expect(snapshot.multiplierHitCounts[5] == 1)
    #expect(snapshot.multiplierHitCounts.values.reduce(0, +) == snapshot.hits)
    #expect(snapshot.reactionBasePoints + snapshot.multiplierBonusPoints == snapshot.points)
}

@Test("Mistakes reset multiplier while dodges remain neutral")
func mistakeResetsStreak() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    for index in 0..<4 { hitRound(engine, activeAt: Double(index * 200 + 100), reaction: 100) }
    #expect(engine.multiplier == 2)
    let streakBeforeDodge = engine.streakProgress
    let baseBeforeDodge = engine.reactionBasePoints
    let bonusBeforeDodge = engine.multiplierBonusPoints
    let decoy = engine.activateDecoy(now: 10_000).decoy!
    _ = engine.expireDecoys(now: decoy.expiresAt)
    #expect(engine.multiplier == 2)
    #expect(engine.streakProgress == streakBeforeDodge)
    #expect(engine.reactionBasePoints == baseBeforeDodge)
    #expect(engine.multiplierBonusPoints == bonusBeforeDodge)

    _ = engine.tap(cellIndex: 0, now: 11_000)
    #expect(engine.multiplier == 1)
    #expect(engine.streakProgress == 0)
}

@Test("Reset clears proof, timing, and accounting state")
func resetClearsRunState() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    _ = hitRound(engine, activeAt: 100, reaction: 100)
    #expect(!engine.proofEvents().isEmpty)
    engine.reset()
    let snapshot = engine.snapshot(now: 5_000)
    #expect(snapshot.state == .idle)
    #expect(snapshot.points == 0)
    #expect(snapshot.hits == 0)
    #expect(snapshot.misses == 0)
    #expect(snapshot.multiplier == 1)
    #expect(snapshot.reactionBasePoints == 0)
    #expect(engine.proofEvents().isEmpty)
}

@Test("Active snapshot exposes smooth remaining response progress")
func reactionProgress() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    _ = engine.activateRound(now: 1_000)
    #expect(engine.snapshot(now: 1_250).reactionProgress == 0.75)
    #expect(engine.snapshot(now: 2_000).reactionProgress == 0)
}
