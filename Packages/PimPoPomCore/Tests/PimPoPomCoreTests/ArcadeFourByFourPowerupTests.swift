import Foundation
import Testing

@testable import PimPoPomCore

@Test("Arcade v5 blocks pickups on 1×1 and 2×2, including an active 2×2 target spanning forty seconds")
func arcadeV5ActualBoardGate() throws {
    let engine = GameEngine(ruleset: .v5, random: { 0 })
    engine.start(now: 0)
    #expect(engine.snapshot(now: 12_000).difficulty.gridDimension == 1)
    #expect(engine.activatePickup(now: 12_000).reason == "pickup-capacity")
    #expect(engine.nextPickupOpportunityAt == 12_250)
    engine.hits = 4
    for time in stride(from: 12_250.0, through: 39_750, by: 250) {
        #expect(engine.snapshot(now: time).difficulty.gridDimension == 2)
        #expect(engine.activatePickup(now: time).reason == "pickup-capacity")
        #expect(engine.activePickups.isEmpty)
    }
    let target = engine.activateRound(now: 39_900)
    #expect(target.snapshot.difficulty.gridDimension == 2)
    #expect(engine.snapshot(now: 40_000).difficulty.gridDimension == 2)
    #expect(engine.activatePickup(now: 40_000).reason == "pickup-capacity")
    #expect(engine.nextPickupOpportunityAt == 40_250)
    #expect(engine.tap(cellIndex: target.snapshot.targetIndex!, now: 40_010).kind == .hit)
    #expect(engine.snapshot(now: 40_010).difficulty.gridDimension == 4)
    #expect(engine.activatePickup(now: 40_249).reason == "pickup-not-due")
    let pickup = try #require(engine.activatePickup(now: 40_250).pickup)
    #expect(pickup.kind == .heart)
    #expect(pickup.visibleAt == 40_250 && pickup.expiresAt == 43_250)
    #expect(engine.nextPickupOpportunityAt == 52_250)
    #expect(engine.proofEvents().filter { $0.first == 7 } == [[7, 40_250, pickup.id, 0, pickup.cellIndex, 3_000]])
}

@Test("Arcade v5 heart and clock claims on 4×4 retain caps, immutable targets and exact clock recovery")
func arcadeV5PickupEffectsAfterExpansion() throws {
    for kind in ArcadePickupKind.allCases {
        var random = 0.0
        let engine = GameEngine(ruleset: .v5, random: { random })
        engine.start(now: 0)
        engine.hits = 4
        for time in stride(from: 12_000.0, through: 39_750, by: 250) {
            #expect(engine.activatePickup(now: time).kind == .ignored)
        }
        random = kind == .heart ? 0 : 0.75
        let pickup = try #require(engine.activatePickup(now: 40_000).pickup)
        #expect(pickup.kind == kind)
        random = 0
        engine.lives = 2
        let target = engine.activateRound(now: 40_010)
        let claim = engine.tap(cellIndex: pickup.cellIndex, now: 40_100, resolvedAt: 40_120)
        #expect(claim.kind == .pickupCollected)
        #expect(claim.snapshot.targetIndex == target.snapshot.targetIndex)
        #expect(claim.snapshot.difficulty == target.snapshot.difficulty)
        #expect(claim.snapshot.hits == target.snapshot.hits && claim.snapshot.points == target.snapshot.points)
        #expect(engine.lives == (kind == .heart ? 3 : 2))
        #expect(engine.speedRate(now: 40_120) == (kind == .clock ? 0.7 : 1))
        #expect(engine.speedRate(now: 45_120) == (kind == .clock ? 0.85 : 1))
        #expect(engine.speedRate(now: 50_120) == 1)
        #expect(engine.tap(cellIndex: pickup.cellIndex, now: 40_100, resolvedAt: 40_130).kind == .ignored)
        #expect(engine.tap(cellIndex: target.snapshot.targetIndex!, now: 40_200).kind == .hit)
        if kind == .clock {
            let next = engine.activateRound(now: 40_300)
            let rate = ArcadePowerupRules.rateUnits(atMilliseconds: 40_300, clockClaimHandledAtMilliseconds: 40_120)
            #expect(
                next.snapshot.difficulty.responseWindowMilliseconds
                    == ArcadePowerupRules.scaledInterval(baseMilliseconds: 1_000, rateUnits: rate))
        }
    }
}

@Test("Arcade v5 keeps explicit contracts while Zen and old v4 generation remain unchanged")
func arcadeV5ContractIsolation() {
    #expect(ArcadeRuleset.v5.rawValue == "reaction-proof-v5")
    #expect(ArcadeRuleset.v5.proofVersion == 3)
    #expect(ArcadeRuleset.v5.minimumPickupGridDimension == 4)
    #expect(ArcadeRuleset.v4.minimumPickupGridDimension == 2)
    let retained = GameEngine(ruleset: .v4, random: { 0 })
    retained.start(now: 0)
    retained.hits = 4
    #expect(retained.activatePickup(now: 12_000).kind == .pickupActive)

    var defaultDraws = 0
    var newDraws = 0
    let legacyZen = GameEngine(random: {
        defaultDraws += 1
        return 0
    })
    let newZen = GameEngine(
        ruleset: .v5,
        random: {
            newDraws += 1
            return 0
        })
    legacyZen.start(now: 0, mode: .zen)
    newZen.start(now: 0, mode: .zen)
    for time in [1_000.0, 10_000, 40_000, 60_000] {
        let original = legacyZen.activateRound(now: time)
        let current = newZen.activateRound(now: time)
        #expect(original.snapshot == current.snapshot)
        #expect(newZen.activatePickup(now: time).reason == "pickups-disabled")
        _ = legacyZen.tap(cellIndex: original.snapshot.targetIndex!, now: time + 100)
        _ = newZen.tap(cellIndex: current.snapshot.targetIndex!, now: time + 100)
    }
    #expect(defaultDraws == newDraws)
    #expect(legacyZen.proofEvents() == newZen.proofEvents())
}
