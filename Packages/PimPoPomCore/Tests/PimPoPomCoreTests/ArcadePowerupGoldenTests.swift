import Foundation
import Testing

@testable import PimPoPomCore

private struct ArcadePowerupGolden: Codable, Equatable {
    struct Result: Codable, Equatable {
        let score: Int
        let durationMs: Int
        let hits: Int
        let misses: Int
        let dodges: Int
        let reactionTotalMs: Int
        let fastestReactionMs: Int?
        let lives: Int
        let maximumMultiplierUsed: Int
    }
    let name: String
    let ruleset: String
    let proofVersion: Int
    let events: [[Int]]
    let expected: Result
}

private final class GoldenRandom {
    var value = 0.0
}

private enum GoldenEvent {
    case targetContact, pickupContact, decoyExpiry, pickupExpiry, targetSpawn, decoySpawn, pickupSpawn
}

/// Complete, naturally scheduled traces rather than direct mutation of engine
/// state. PHP consumes the identical checked-in event arrays and expected totals.
private func generateGolden(hearts: Bool, ruleset: ArcadeRuleset = .v4) -> ArcadePowerupGolden {
    let random = GoldenRandom()
    let engine = GameEngine(ruleset: ruleset, random: { random.value })
    engine.start(now: 0)
    var targetSpawnAt: Double? = engine.nextDelayMilliseconds(now: 0)
    var targetContactAt: Double?
    var decoySpawnAt = engine.nextDecoyDelayMilliseconds(now: 0)
    var pickupContactAt: Double?
    var missedOnce = false
    var missAfterHeart = false
    var pickupsSpawned = 0
    var lastTime = 0.0

    for _ in 0..<2_000 {
        if engine.state == .gameOver { break }
        var events: [(time: Double, priority: Int, kind: GoldenEvent)] = []
        if let targetContactAt { events.append((targetContactAt, 0, .targetContact)) }
        if let pickupContactAt { events.append((pickupContactAt, 1, .pickupContact)) }
        if let expiry = engine.nextDecoyExpiryAt() { events.append((expiry, 2, .decoyExpiry)) }
        if let expiry = engine.nextPickupExpiryAt() { events.append((expiry + 32, 3, .pickupExpiry)) }
        if let targetSpawnAt { events.append((targetSpawnAt, 4, .targetSpawn)) }
        if let decoySpawnAt { events.append((decoySpawnAt, 5, .decoySpawn)) }
        if let opportunity = engine.nextPickupOpportunityAt { events.append((opportunity, 6, .pickupSpawn)) }
        guard let event = events.min(by: { ($0.time, $0.priority) < ($1.time, $1.priority) }) else { break }
        let now = max(lastTime, event.time)
        lastTime = now
        switch event.kind {
        case .targetContact:
            targetContactAt = nil
            let finishAfter = ruleset == .v5 ? (hearts ? 125_000.0 : 110_000) : (hearts ? 75_000 : 65_000)
            let shouldMiss =
                now >= finishAfter
                || (hearts && ((!missedOnce && engine.hits >= 4) || missAfterHeart))
            let missedCell = engine.snapshot(now: now).cells.indices.first { index in
                index != engine.targetIndex && !engine.activePickups.contains(where: { $0.cellIndex == index })
            }
            let result = engine.tap(cellIndex: shouldMiss ? (missedCell ?? -1) : (engine.targetIndex ?? -1), now: now)
            if result.kind == .miss {
                missedOnce = true
                missAfterHeart = false
                pickupContactAt = nil
                decoySpawnAt = engine.nextDecoyDelayMilliseconds(now: now).map { now + $0 }
            }
            if engine.state == .waiting { targetSpawnAt = now + engine.nextDelayMilliseconds(now: now) }
        case .pickupContact:
            pickupContactAt = nil
            if let pickup = engine.activePickups.first {
                let result = engine.tap(cellIndex: pickup.cellIndex, now: now)
                if hearts, result.kind == .pickupCollected { missAfterHeart = true }
            }
        case .decoyExpiry:
            _ = engine.expireDecoys(now: now)
        case .pickupExpiry:
            _ = engine.expirePickups(now: now)
        case .targetSpawn:
            targetSpawnAt = nil
            let result = engine.activateRound(now: now)
            if result.kind == .roundActive {
                targetContactAt = now + 100
            } else {
                targetSpawnAt = now + engine.nextDelayMilliseconds(now: now)
            }
        case .decoySpawn:
            _ = engine.activateDecoy(now: now)
            decoySpawnAt = engine.nextDecoyDelayMilliseconds(now: now).map { now + $0 }
        case .pickupSpawn:
            random.value = hearts ? 0 : 0.75
            let result = engine.activatePickup(now: now)
            random.value = 0
            if result.kind == .pickupActive {
                pickupsSpawned += 1
                if hearts || pickupsSpawned % 2 == 1 { pickupContactAt = now + 100 }
            }
        }
    }
    let final = engine.snapshot(now: lastTime)
    return ArcadePowerupGolden(
        name: hearts ? "hearts-cumulative-misses" : "clock-sampling-and-explicit-expiry",
        ruleset: engine.ruleset.rawValue, proofVersion: engine.ruleset.proofVersion, events: engine.proofEvents(),
        expected: .init(
            score: final.points, durationMs: Int(final.elapsedMilliseconds), hits: final.hits,
            misses: final.misses, dodges: final.dodges, reactionTotalMs: engine.reactionTotalMilliseconds,
            fastestReactionMs: final.fastestReactionMilliseconds, lives: final.lives,
            maximumMultiplierUsed: final.maximumMultiplierUsed))
}

@Test("Complete Arcade v5 traces defer pickups to 4×4 and preserve restored-life and clock semantics")
func arcadeFourByFourPowerupGoldenTraces() throws {
    let goldens = [generateGolden(hearts: true, ruleset: .v5), generateGolden(hearts: false, ruleset: .v5)]
    for trace in goldens {
        #expect(trace.ruleset == "reaction-proof-v5")
        #expect(trace.proofVersion == 3)
        #expect(trace.expected.lives == 0)
        #expect(trace.events.last?.first == 5)
        #expect(trace.events.count < 10_000)
        #expect(trace.events.contains { $0.first == 10 && $0[1] < 40_000 })
        #expect(trace.events.filter { $0.first == 7 }.allSatisfy { $0[1] >= 40_000 })
        #expect(trace.events.contains { $0.first == 8 })
    }
    #expect(goldens[0].expected.misses >= 8)
    #expect(goldens[1].events.contains { $0.first == 9 })
    #expect(goldens[1].events.filter { $0.first == 8 }.count >= 2)
    if ProcessInfo.processInfo.environment["PIMPOPOM_EXPORT_V5_POWERUP_FIXTURES"] == "1" {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        print("ARCADE_V5_POWERUP_GOLDENS:" + String(decoding: try encoder.encode(goldens), as: UTF8.self))
        return
    }
    let fixtureURL = try #require(
        Bundle.module.url(forResource: "arcade-v5-powerups", withExtension: "json", subdirectory: "Fixtures"))
    let stored = try JSONDecoder().decode([ArcadePowerupGolden].self, from: Data(contentsOf: fixtureURL))
    #expect(goldens == stored)
}

@Test("Complete Swift Arcade v4 proof goldens terminate, cover hearts above three misses and clock expiry")
func arcadePowerupGoldenTraces() throws {
    let goldens = [generateGolden(hearts: true), generateGolden(hearts: false)]
    for trace in goldens {
        #expect(trace.expected.lives == 0)
        #expect(trace.events.last?.first == 5)
        #expect(trace.events.count < 10_000)
        #expect(trace.events.contains { $0.first == 8 })
        #expect(trace.events.filter { $0.first == 2 && $0[3] == 1 }.allSatisfy { $0[4] >= 0 })
    }
    #expect(goldens[0].expected.misses > 3)
    #expect(goldens[1].events.contains { $0.first == 9 })
    #expect(goldens[1].events.filter { $0.first == 8 }.count >= 2)
    let fixtureURL = try #require(
        Bundle.module.url(forResource: "arcade-v4-powerups", withExtension: "json", subdirectory: "Fixtures"))
    let stored = try JSONDecoder().decode([ArcadePowerupGolden].self, from: Data(contentsOf: fixtureURL))
    #expect(goldens == stored)
    if ProcessInfo.processInfo.environment["PIMPOPOM_EXPORT_POWERUP_FIXTURES"] == "1" {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        print("ARCADE_POWERUP_GOLDENS:" + String(decoding: try encoder.encode(goldens), as: UTF8.self))
    }
}
