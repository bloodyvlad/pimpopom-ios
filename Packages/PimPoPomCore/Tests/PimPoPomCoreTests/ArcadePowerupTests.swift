import Foundation
import Testing

@testable import PimPoPomCore

private final class PickupRandom {
    var value = 0.0
}

private func pickupEngine(random: PickupRandom = PickupRandom()) -> GameEngine {
    let engine = GameEngine(ruleset: .v4, random: { random.value })
    engine.start(now: 0)
    engine.hits = 4
    return engine
}

@Test("Powerups require explicit v4 Arcade and do not alter default or Zen randomness/proofs")
func pickupRulesetIsolation() {
    for mode in [GameMode.arcade, .zen] {
        var legacyCalls = 0
        var explicitCalls = 0
        let legacy = GameEngine(random: {
            legacyCalls += 1
            return 0
        })
        let explicit = GameEngine(
            ruleset: mode == .zen ? .v4 : .v3,
            random: {
                explicitCalls += 1
                return 0
            })
        legacy.start(now: 0, mode: mode)
        explicit.start(now: 0, mode: mode)
        #expect(legacy.ruleset == .v3)
        #expect(explicit.nextPickupOpportunityAt == nil)
        #expect(explicit.activatePickup(now: 12_000).reason == "pickups-disabled")
        for time in [550.0, 1_200, 2_000, 10_000, 40_000] {
            let first = legacy.activateRound(now: time)
            let second = explicit.activateRound(now: time)
            #expect(first.snapshot == second.snapshot)
            _ = legacy.tap(cellIndex: first.snapshot.targetIndex!, now: time + 100)
            _ = explicit.tap(cellIndex: second.snapshot.targetIndex!, now: time + 100)
            #expect(legacy.nextDelayMilliseconds(now: time + 100) == explicit.nextDelayMilliseconds(now: time + 100))
        }
        #expect(legacyCalls == explicitCalls)
        #expect(legacy.proofEvents() == explicit.proofEvents())
    }
    #expect(ArcadeRuleset.v3.proofVersion == 2)
    #expect(ArcadeRuleset.v4.rawValue == "reaction-proof-v4")
    #expect(ArcadeRuleset.v4.proofVersion == 3)
}

@Test("Pickup opportunities use one unscaled random 12–20-second stream and reserve a target cell")
func pickupCadenceAndCapacity() {
    let engine = GameEngine(ruleset: .v4, random: { 0 })
    engine.start(now: 0)
    #expect(engine.nextPickupOpportunityAt == 12_000)
    #expect(engine.activatePickup(now: 11_999).reason == "pickup-not-due")
    #expect(engine.proofEvents().isEmpty)
    #expect(engine.activatePickup(now: 12_000).reason == "pickup-capacity")
    #expect(engine.nextPickupOpportunityAt == 12_250)
    #expect(engine.proofEvents() == [[10, 12_000]])
    engine.hits = 4
    let first = engine.activatePickup(now: 12_250)
    #expect(first.kind == .pickupActive)
    #expect(first.pickup?.expiresAt == 15_250)
    #expect(engine.nextPickupOpportunityAt == 24_250)
    #expect(engine.activateRound(now: 12_300).snapshot.targetIndex != first.pickup?.cellIndex)
    #expect(engine.activateDecoy(now: 12_310).decoy?.cellIndex != first.pickup?.cellIndex)
    let occupied = Set(
        engine.activeDecoys.map(\.cellIndex) + engine.activePickups.map(\.cellIndex) + [engine.targetIndex!])
    #expect(occupied.count == 3)

    let upper = GameEngine(ruleset: .v4, random: { 1 })
    upper.start(now: 5)
    #expect(upper.nextPickupOpportunityAt == 20_005)
}

@Test("Heart claims restore one capped life without changing target, score, streak or reactions")
func heartCollection() throws {
    let engine = pickupEngine()
    engine.lives = 2
    let pickup = try #require(engine.activatePickup(now: 12_000).pickup)
    let active = engine.activateRound(now: 12_100)
    let claim = engine.tap(cellIndex: pickup.cellIndex, now: 12_200, resolvedAt: 12_210)
    #expect(claim.kind == .pickupCollected)
    #expect(claim.snapshot.lives == 3)
    #expect(claim.snapshot.points == active.snapshot.points)
    #expect(claim.snapshot.hits == active.snapshot.hits)
    #expect(claim.snapshot.multiplier == active.snapshot.multiplier)
    #expect(claim.snapshot.streakProgress == active.snapshot.streakProgress)
    #expect(claim.snapshot.targetIndex == active.snapshot.targetIndex)
    #expect(claim.snapshot.difficulty == active.snapshot.difficulty)
    #expect(engine.activeAt == 12_100)
    #expect(engine.nextPickupOpportunityAt == 24_000)
    #expect(engine.proofEvents().last == [8, 12_200, 12_210, pickup.id, pickup.cellIndex])
    #expect(
        engine.tap(cellIndex: pickup.cellIndex, now: 12_205, resolvedAt: 12_215).reason == "pickup-already-resolved")
    #expect(engine.lives == 3)

    _ = engine.tap(cellIndex: active.snapshot.targetIndex!, now: 12_300)
    let second = try #require(engine.activatePickup(now: 24_000).pickup)
    #expect(engine.tap(cellIndex: second.cellIndex, now: 24_050).kind == .pickupCollected)
    #expect(engine.lives == 3)
    #expect(engine.activePickups.isEmpty)
}

@Test("Heart input predating a new target uses its own presentation time and duplicate input is harmless")
func pickupOriginalContactBeforeTarget() throws {
    let engine = pickupEngine()
    let heart = try #require(engine.activatePickup(now: 12_000).pickup)
    _ = engine.activateRound(now: 12_200)
    #expect(engine.pickup(atCell: heart.cellIndex, inputAt: 12_100) == heart)
    #expect(engine.tap(cellIndex: heart.cellIndex, now: 12_100, resolvedAt: 12_230).kind == .pickupCollected)
    #expect(engine.tap(cellIndex: heart.cellIndex, now: 12_100, resolvedAt: 12_240).reason == "pickup-already-resolved")
    #expect(engine.proofEvents().last == [8, 12_100, 12_230, heart.id, heart.cellIndex])
}

@Test("Pickup expiry is explicit, reserves cells during touch drain and never resurrects after commit")
func pickupExpiryContactDrain() throws {
    let engine = pickupEngine()
    engine.lives = 2
    let heart = try #require(engine.activatePickup(now: 12_000).pickup)
    #expect(engine.snapshot(now: 15_010).activePickups == [heart])
    let target = engine.activateRound(now: 15_010)
    #expect(target.snapshot.targetIndex != heart.cellIndex)
    #expect(engine.activePickups == [heart])
    #expect(engine.tap(cellIndex: heart.cellIndex, now: 14_999, resolvedAt: 15_020).kind == .pickupCollected)
    #expect(engine.lives == 3)
    #expect(engine.expirePickups(now: 15_030).kind == .ignored)

    let other = pickupEngine()
    let expired = try #require(other.activatePickup(now: 12_000).pickup)
    #expect(other.expirePickups(now: 14_999).kind == .ignored)
    #expect(other.tap(cellIndex: expired.cellIndex, now: 15_000).reason == "pickup-expired")
    #expect(other.expirePickups(now: 15_020).pickupIDs == [expired.id])
    #expect(other.proofEvents().last == [9, 15_020, expired.id])
    #expect(
        other.tap(cellIndex: expired.cellIndex, now: 14_999, resolvedAt: 15_030).reason == "pickup-already-resolved")
    #expect(other.lives == 3)
    let reused = other.activateRound(now: 15_050)
    #expect(reused.snapshot.targetIndex == expired.cellIndex)
    #expect(other.pickup(atCell: expired.cellIndex, inputAt: 15_060) == nil)
    #expect(other.tap(cellIndex: expired.cellIndex, now: 15_060).kind == .hit)
}

@Test("Clock rate recovers linearly using exact integer inverse interval rounding")
func clockIntegerMath() {
    for (elapsed, expected) in [
        (0, 70_000), (1, 70_003), (5_000, 85_000), (9_999, 99_997), (10_000, 100_000), (30_000, 100_000),
    ] {
        #expect(
            ArcadePowerupRules.rateUnits(atMilliseconds: 1_000 + elapsed, clockClaimHandledAtMilliseconds: 1_000)
                == expected)
    }
    #expect(ArcadePowerupRules.scaledInterval(baseMilliseconds: 1_000, rateUnits: 70_000) == 1_429)
    #expect(ArcadePowerupRules.scaledInterval(baseMilliseconds: 550, rateUnits: 70_000) == 786)
    #expect(ArcadePowerupRules.scaledInterval(baseMilliseconds: 1_000, rateUnits: 85_000) == 1_177)
    #expect(ArcadePowerupRules.scaledInterval(baseMilliseconds: 200, rateUnits: 100_000) == 200)
}

@Test("Clock changes only newly sampled gameplay quiet delays and newly activated response windows")
func clockFrozenWindowsAndSampling() throws {
    let random = PickupRandom()
    let engine = pickupEngine(random: random)
    random.value = 0.75
    let clock = try #require(engine.activatePickup(now: 12_000).pickup)
    random.value = 0
    let old = engine.activateRound(now: 12_100)
    let decoy = try #require(engine.activateDecoy(now: 12_150).decoy)
    let pendingQuiet = engine.nextDelayMilliseconds(now: 12_150)
    #expect(engine.tap(cellIndex: clock.cellIndex, now: 12_200, resolvedAt: 12_220).kind == .pickupCollected)
    #expect(engine.speedRate(now: 12_220) == 0.7)
    #expect(engine.speedRate(now: 17_220) == 0.85)
    #expect(engine.speedRate(now: 22_220) == 1)
    #expect(
        engine.snapshot(now: 12_220).difficulty.responseWindowMilliseconds
            == old.snapshot.difficulty.responseWindowMilliseconds)
    #expect(engine.activeDecoys == [decoy])
    #expect(pendingQuiet == 550)
    #expect(engine.nextDelayMilliseconds(now: 12_220) == 786)
    #expect(engine.nextDecoyDelayMilliseconds(now: 12_220) == 3_143)
    #expect(engine.tap(cellIndex: old.snapshot.targetIndex!, now: 12_300).kind == .hit)
    let newer = engine.activateRound(now: 13_100)
    let rate = ArcadePowerupRules.rateUnits(atMilliseconds: 13_100, clockClaimHandledAtMilliseconds: 12_220)
    #expect(
        newer.snapshot.difficulty.responseWindowMilliseconds
            == ArcadePowerupRules.scaledInterval(baseMilliseconds: 1_000, rateUnits: rate))
    #expect(newer.snapshot.difficulty.spawnDelayRangeMilliseconds == DelayRange(550, 1_000))
    #expect(engine.nextPickupOpportunityAt == 30_000)
}

@Test("Miss clears pickup and resets its opportunity after recovery without cancelling an active clock")
func pickupMissResetAndTerminalCleanup() throws {
    let random = PickupRandom()
    let engine = pickupEngine(random: random)
    random.value = 0.75
    let clock = try #require(engine.activatePickup(now: 12_000).pickup)
    random.value = 0
    _ = engine.tap(cellIndex: clock.cellIndex, now: 12_100)
    let miss = engine.tap(cellIndex: -1, now: 12_200, resolvedAt: 12_210)
    #expect(miss.kind == .miss)
    #expect(engine.nextPickupOpportunityAt == 25_710)
    #expect(engine.recoveryUntil == 13_710)
    #expect(engine.speedRate(now: 12_210) < 1)
    #expect(engine.activatePickup(now: 13_000).reason == "recovering")
    let heart = try #require(engine.activatePickup(now: 25_710).pickup)
    _ = engine.tap(cellIndex: -1, now: 25_800)
    #expect(engine.activePickups.isEmpty)
    #expect(!engine.proofEvents().contains { $0.first == 9 && $0.dropFirst(2).contains(heart.id) })
    #expect(engine.nextPickupOpportunityAt == 39_300)
    _ = engine.tap(cellIndex: -1, now: 27_300)
    #expect(engine.isRunComplete())
    #expect(engine.nextPickupOpportunityAt == nil)
    #expect(engine.speedRate(now: 27_300) == 1)
    #expect(engine.tap(cellIndex: heart.cellIndex, now: 25_750, resolvedAt: 27_400).kind == .ignored)
    #expect(engine.lives == 0)
    engine.reset()
    #expect(engine.activePickups.isEmpty)
    #expect(engine.nextPickupExpiryAt() == nil)
    #expect(engine.nextPickupOpportunityAt == nil)
    #expect(engine.proofEvents().isEmpty)
}

@Test("Fractional pickup deadline rounds consistently with proof replay")
func pickupDeadlineRounding() throws {
    let engine = pickupEngine()
    let heart = try #require(engine.activatePickup(now: 12_000.2).pickup)
    #expect(engine.tap(cellIndex: heart.cellIndex, now: 14_999.6, resolvedAt: 15_005).reason == "pickup-expired")
    #expect(engine.activePickups.count == 1)
    #expect(engine.proofEvents().last?.first == 7)
}

@Test("Correct hits preserve pickups while target and decoy placement continue to exclude their cells")
func pickupSurvivesCorrectHit() throws {
    let engine = pickupEngine()
    let pickup = try #require(engine.activatePickup(now: 12_000).pickup)
    let target = engine.activateRound(now: 12_100)
    #expect(engine.tap(cellIndex: target.snapshot.targetIndex!, now: 12_200).kind == .hit)
    #expect(engine.activePickups == [pickup])
    let next = engine.activateRound(now: 12_900)
    #expect(next.snapshot.targetIndex != pickup.cellIndex)
    let decoy = try #require(engine.activateDecoy(now: 13_000).decoy)
    #expect(decoy.cellIndex != pickup.cellIndex)
    #expect(decoy.cellIndex != next.snapshot.targetIndex)
}

@Test("Clock recharge is nonmultiplicative and difficulty uses real elapsed time and hit progression")
func clockRechargeAndUnderlyingProgression() throws {
    let random = PickupRandom()
    let engine = pickupEngine(random: random)
    random.value = 0.75
    let first = try #require(engine.activatePickup(now: 12_000).pickup)
    _ = engine.tap(cellIndex: first.cellIndex, now: 12_100)
    #expect(engine.speedRate(now: 12_100) == 0.7)
    let second = try #require(engine.activatePickup(now: 30_000).pickup)
    _ = engine.tap(cellIndex: second.cellIndex, now: 30_100)
    #expect(engine.speedRate(now: 30_100) == 0.7)
    let duplicate = engine.tap(cellIndex: second.cellIndex, now: 30_100, resolvedAt: 30_110)
    #expect(duplicate.kind == .ignored)
    #expect(engine.speedRate(now: 35_100) == 0.85)
    #expect(engine.snapshot(now: 40_000).difficulty.gridDimension == 4)
    #expect(engine.snapshot(now: 40_000).elapsedMilliseconds == 40_000)
    let third = try #require(engine.activatePickup(now: 48_000).pickup)
    _ = engine.tap(cellIndex: third.cellIndex, now: 48_100)
    random.value = 0
    let initial = engine.activateRound(now: 50_000)
    #expect(engine.challengeStartHits == 4)
    #expect(initial.snapshot.difficulty.phaseID == "four-by-four-challenge")
    _ = engine.tap(cellIndex: initial.snapshot.targetIndex!, now: 50_100)
    let advanced = engine.activateRound(now: 51_000)
    let rate = ArcadePowerupRules.rateUnits(atMilliseconds: 51_000, clockClaimHandledAtMilliseconds: 48_100)
    #expect(
        advanced.snapshot.difficulty.responseWindowMilliseconds
            == ArcadePowerupRules.scaledInterval(baseMilliseconds: 995, rateUnits: rate))
}
