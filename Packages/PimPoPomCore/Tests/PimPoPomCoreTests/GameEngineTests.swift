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
            [0, 100, active.snapshot.targetIndex!, active.snapshot.playerColorIndex],
            [1, 250, 252, active.snapshot.targetIndex!, active.snapshot.playerColorIndex],
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
    #expect(resolveDifficulty(hits: 4, elapsedMilliseconds: 50_000, challengeHits: 1).responseWindowMilliseconds == 995)
    #expect(
        resolveDifficulty(hits: 4, elapsedMilliseconds: 50_000, challengeHits: 10).responseWindowMilliseconds == 950)
}

@Test("Arcade permits multiple live decoys only from seventy seconds")
func multipleDecoyBoundary() {
    #expect(resolveDifficulty(hits: 8, elapsedMilliseconds: 30_000).maximumActiveDecoys == 1)
    #expect(
        resolveDifficulty(
            hits: 30,
            elapsedMilliseconds: 69_999,
            challengeHits: 20
        ).maximumActiveDecoys == 1
    )
    #expect(
        resolveDifficulty(
            hits: 30,
            elapsedMilliseconds: 70_000,
            challengeHits: 0
        ).maximumActiveDecoys == 2
    )
    #expect(
        resolveDifficulty(
            hits: 60,
            elapsedMilliseconds: 70_000,
            challengeHits: 40
        ).maximumActiveDecoys == 6
    )
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
    let first = engine.activateDecoy(now: 70_000)
    let target = engine.activateRound(now: 70_020)
    let second = engine.activateDecoy(now: 70_040)
    #expect(first.kind == .decoyActive)
    #expect(target.kind == .roundActive)
    #expect(second.kind == .decoyActive)
    #expect(second.snapshot.activeDecoys.count == 2)
    #expect(second.decoy?.colorIndex != second.snapshot.playerColorIndex)
}

@Test("Decoy lifetime spans the accepted one-to-three-second range")
func decoyLifetimeRange() {
    let minimumEngine = makeEngine(random: { 0 })
    minimumEngine.start(now: 0)
    minimumEngine.hits = 4
    #expect(minimumEngine.activateDecoy(now: 10_100).lifetimeMilliseconds == 1_000)

    let maximumEngine = makeEngine(random: { 1 })
    maximumEngine.start(now: 0)
    maximumEngine.hits = 4
    #expect(maximumEngine.activateDecoy(now: 10_100).lifetimeMilliseconds == 3_000)
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
    let blocked = engine.activateDecoy(now: 35_010)
    #expect(blocked.reason == "decoy-capacity")
    #expect(engine.expireDecoys(now: first.expiresAt).decoyIDs == [1])

    let second = engine.activateDecoy(now: 70_000).decoy!
    let third = engine.activateDecoy(now: 70_010).decoy!
    #expect(
        engine.proofEvents().contains {
            $0 == [3, 70_000, second.id, second.cellIndex, second.colorIndex, 1_000]
        }
    )
    #expect(
        engine.proofEvents().contains {
            $0 == [3, 70_010, third.id, third.cellIndex, third.colorIndex, 1_000]
        }
    )
    let expired = engine.expireDecoys(now: max(second.expiresAt, third.expiresAt))
    #expect(expired.decoyIDs == [2, 3])
    #expect(engine.proofEvents().last == [4, 71_010, 2, 3])
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

@Test("A correct hit preserves decoys through the next target until natural expiry")
func hitPreservesDecoys() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    engine.hits = 4
    let active = engine.activateRound(now: 70_000)
    let decoy = engine.activateDecoy(now: 70_050).decoy!
    let hit = engine.tap(cellIndex: active.snapshot.targetIndex!, now: 70_100)
    #expect(hit.kind == .hit)
    #expect(hit.snapshot.activeDecoys == [decoy])
    #expect(hit.snapshot.dodges == 0)

    let next = engine.activateRound(now: 70_200)
    #expect(next.snapshot.targetIndex != decoy.cellIndex)
    #expect(next.snapshot.activeDecoys == [decoy])

    let expired = engine.expireDecoys(now: decoy.expiresAt)
    #expect(expired.kind == .decoysDodged)
    #expect(expired.snapshot.dodges == 1)
    #expect(expired.snapshot.activeDecoys.isEmpty)
}

@Test("A correct hit settles an independently expired decoy before its hit proof")
func hitSettlesExpiredDecoy() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    engine.hits = 4
    let decoy = engine.activateDecoy(now: 69_000).decoy!
    let active = engine.activateRound(now: 69_500)
    #expect(decoy.expiresAt == 70_000)

    let hit = engine.tap(cellIndex: active.snapshot.targetIndex!, now: 70_010)
    #expect(hit.kind == .hit)
    #expect(hit.dodgesAwarded == 1)
    #expect(hit.dodgePointsAwarded == 550)
    #expect(hit.snapshot.dodges == 1)
    let expiryIndex = engine.proofEvents().firstIndex { $0.first == 4 }
    let hitIndex = engine.proofEvents().firstIndex { $0.first == 1 }
    #expect(expiryIndex != nil)
    #expect(hitIndex != nil)
    #expect(expiryIndex! < hitIndex!)
}

@Test("Staggered decoy expiry preserves and reserves the live sibling")
func staggeredDecoyExpiryPreservesSibling() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    engine.hits = 34
    engine.challengeStartHits = 4
    engine.activeDecoys = [
        Decoy(id: 1, cellIndex: 2, colorIndex: 1, visibleAt: 70_000, expiresAt: 71_000),
        Decoy(id: 2, cellIndex: 3, colorIndex: 2, visibleAt: 70_000, expiresAt: 72_000),
    ]

    let expiry = engine.expireDecoys(now: 71_000)
    #expect(expiry.decoyIDs == [1])
    #expect(expiry.snapshot.activeDecoys.map(\.id) == [2])
    #expect(expiry.snapshot.nextDecoyExpiryAt == 72_000)

    let target = engine.activateRound(now: 71_100)
    #expect(target.snapshot.targetIndex != 2)
    #expect(target.snapshot.targetIndex != 3)
    #expect(target.snapshot.activeDecoys.map(\.id) == [2])
}

@Test("A miss awards an expired decoy while clearing its live sibling")
func missSettlesExpiredDecoyAndClearsSibling() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    engine.hits = 34
    engine.challengeStartHits = 4
    let active = engine.activateRound(now: 70_000)
    let targetIndex = active.snapshot.targetIndex!
    let decoyCells = (0..<16).filter { $0 != targetIndex }
    engine.activeDecoys = [
        Decoy(id: 1, cellIndex: decoyCells[0], colorIndex: 1, visibleAt: 70_010, expiresAt: 70_050),
        Decoy(id: 2, cellIndex: decoyCells[1], colorIndex: 2, visibleAt: 70_010, expiresAt: 72_000),
    ]

    let miss = engine.tap(cellIndex: decoyCells[0], now: 70_100)
    #expect(miss.kind == .miss)
    #expect(miss.dodgesAwarded == 1)
    #expect(miss.dodgePointsAwarded == 550)
    #expect(miss.snapshot.dodges == 1)
    #expect(miss.snapshot.activeDecoys.isEmpty)
    #expect(engine.proofEvents().contains { $0 == [4, 70_100, 1] })
}

@Test("Arcade color changes exclude every visible decoy color")
func colorChangeAvoidsVisibleDecoys() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    engine.hits = 4
    let active = engine.activateRound(now: 70_000)
    let decoy = engine.activateDecoy(now: 70_050).decoy!
    #expect(active.snapshot.playerColorIndex == 0)
    #expect(decoy.colorIndex == 1)

    let hit = engine.tap(cellIndex: active.snapshot.targetIndex!, now: 70_100)
    #expect(hit.colorChanged == true)
    #expect(hit.snapshot.playerColorIndex == 2)
    #expect(hit.snapshot.playerColorIndex != decoy.colorIndex)
    #expect(hit.snapshot.activeDecoys == [decoy])
    #expect(engine.proofEvents().last == [1, 70_100, 70_100, active.snapshot.targetIndex!, 2])
}

@Test("Arcade retains its color when visible decoys occupy every alternative")
func colorChangeRetainsCurrentFallback() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    engine.hits = 34
    engine.challengeStartHits = 4
    let active = engine.activateRound(now: 70_000)
    let targetIndex = active.snapshot.targetIndex!
    let availableCells = (0..<16).filter { $0 != targetIndex }
    engine.activeDecoys = (1...5).map { colorIndex in
        Decoy(
            id: colorIndex,
            cellIndex: availableCells[colorIndex - 1],
            colorIndex: colorIndex,
            visibleAt: 70_010,
            expiresAt: 80_000
        )
    }

    let hit = engine.tap(cellIndex: targetIndex, now: 70_100)
    #expect(hit.kind == .hit)
    #expect(hit.colorChanged == false)
    #expect(hit.snapshot.playerColorIndex == 0)
    #expect(hit.snapshot.activeDecoys.count == 5)
}

@Test("A life loss clears every still-visible decoy without a dodge")
func missClearsVisibleDecoys() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    engine.hits = 4
    let active = engine.activateRound(now: 70_000)
    _ = engine.activateDecoy(now: 70_050)
    let wrongCell = (active.snapshot.targetIndex! + 1) % 16

    let miss = engine.tap(cellIndex: wrongCell, now: 70_100)
    #expect(miss.kind == .miss)
    #expect(miss.lifeLost == true)
    #expect(miss.snapshot.activeDecoys.isEmpty)
    #expect(miss.snapshot.dodges == 0)
}

@Test("Normal ignores recovery taps and ends only on three accepted mistakes")
func threeLifeEnding() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    _ = engine.tap(cellIndex: 0, now: 100)
    #expect(engine.tap(cellIndex: 0, now: 200).reason == "recovering")
    #expect(engine.tap(cellIndex: 0, now: 300).reason == "recovering")
    #expect(engine.lives == 2)
    _ = engine.tap(cellIndex: 0, now: 1_600)
    let third = engine.tap(cellIndex: 0, now: 3_100)
    #expect(third.kind == .miss)
    #expect(third.snapshot.state == .gameOver)
    #expect(third.snapshot.lives == 0)
    #expect(third.snapshot.elapsedMilliseconds == 3_100)
    #expect(engine.proofEvents().last == [5, 3_100, 3_100])
    #expect(engine.isRunComplete())
}

@Test("Lost lives enforce recovery and waiting taps cannot restart it")
func recovery() {
    let engine = makeEngine(random: { 0 })
    engine.start(now: 0)
    _ = engine.tap(cellIndex: 0, now: 100)
    let blocked = engine.activateRound(now: 1_599)
    #expect(blocked.reason == "recovering")
    #expect(blocked.remainingMilliseconds == 1)
    let ignoredTap = engine.tap(cellIndex: 0, now: 1_000)
    #expect(ignoredTap.kind == .ignored)
    #expect(ignoredTap.reason == "recovering")
    #expect(engine.snapshot(now: 1_000).lives == 2)
    #expect(engine.snapshot(now: 1_000).recoveryRemainingMilliseconds == 600)
    #expect(engine.activateRound(now: 1_600).kind == .roundActive)
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
