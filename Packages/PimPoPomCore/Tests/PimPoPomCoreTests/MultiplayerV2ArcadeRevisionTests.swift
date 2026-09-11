import Foundation
import Testing

@testable import PimPoPomCore

private func arcadePlayers(_ count: Int = 2) -> [MP2Player] {
    (0..<count).map { MP2Player(id: "p\($0)", seat: $0, colorIndex: $0, name: "P\($0)") }
}

private func arcadeInput(_ target: MP2Target, reaction: Int = 100) -> MP2Input {
    MP2Input(
        id: target.id, seat: target.ownerSeat, targetID: target.id, cell: target.cell,
        presentedAtMs: target.activateAtMs, contactAtMs: target.activateAtMs + reaction)
}

private func heartInput(_ heart: MP2Heart, seat: Int, id: Int, at: Int) -> MP2Input {
    MP2Input(
        id: id, seat: seat, targetID: nil, cell: heart.cell, presentedAtMs: heart.activateAtMs,
        contactAtMs: at, heartID: heart.id)
}

private func playArcade(_ engine: inout MP2Engine, to end: Int, excludingSeats: Set<Int> = []) {
    while engine.elapsedMs < end, engine.snapshot.phase != .finished {
        engine.advance(to: min(end, engine.elapsedMs + 20))
        for target in engine.snapshot.targets
        where target.activateAtMs + 100 <= engine.elapsedMs && !excludingSeats.contains(target.ownerSeat) {
            #expect(engine.submit(arcadeInput(target), receivedAt: engine.elapsedMs).accepted)
        }
    }
}

private func firstHeart(_ engine: inout MP2Engine, excludingSeats: Set<Int> = []) throws -> MP2Heart {
    let limit = max(60_000, engine.elapsedMs + 25_000)
    while engine.snapshot.hearts.isEmpty, engine.elapsedMs < limit, engine.snapshot.phase == .playing {
        playArcade(&engine, to: engine.elapsedMs + 20, excludingSeats: excludingSeats)
    }
    let heart = try #require(engine.snapshot.hearts.first)
    playArcade(&engine, to: heart.activateAtMs + 10, excludingSeats: excludingSeats)
    return heart
}

@Test("MP2 gameplay revision negotiation is additive and old snapshots still decode")
func arcadeRevisionWireCompatibility() throws {
    let decoder = JSONDecoder()
    let oldHello = Data(#"{"hello":{"ticket":"synthetic","protocolVersion":2}}"#.utf8)
    #expect(
        try decoder.decode(MP2ClientMessage.self, from: oldHello) == .hello(ticket: "synthetic", protocolVersion: 2))
    let newHello = MP2ClientMessage.hello(ticket: "synthetic", protocolVersion: 2, gameplayRevision: 2)
    #expect(try decoder.decode(MP2ClientMessage.self, from: JSONEncoder().encode(newHello)) == newHello)
    let oldSnapshot = Data(
        #"{"matchID":"m","revision":1,"elapsedMs":0,"phase":"playing","gridDimension":1,"players":[],"targets":[],"decoys":[]}"#
            .utf8)
    let decoded = try decoder.decode(MP2Snapshot.self, from: oldSnapshot)
    #expect(decoded.gameplayRevision == MP2Protocol.legacyGameplayRevision)
    #expect(decoded.hearts.isEmpty)
    let legacy = try MP2Engine(matchID: "m", players: arcadePlayers(), seed: 1)
    #expect(legacy.snapshot.gameplayRevision == 1)
    #expect(legacy.snapshot.hearts.isEmpty)
    let current = try MP2Engine(matchID: "m", players: arcadePlayers(), seed: 1, gameplayRevision: 2)
    #expect(current.snapshot.gameplayRevision == 2)
    #expect(throws: MP2EngineError.invalidRoster) {
        try MP2Engine(matchID: "m", players: arcadePlayers(), seed: 1, gameplayRevision: 3)
    }
    let heart = MP2Heart(id: 1, cell: 3, activateAtMs: 10, expiresAtMs: 3_010)
    let snapshot = MP2Snapshot(
        matchID: "m", revision: 2, elapsedMs: 0, phase: .playing, gridDimension: 2,
        players: arcadePlayers(), targets: [], decoys: [], hearts: [heart], gameplayRevision: 2)
    #expect(try decoder.decode(MP2Snapshot.self, from: JSONEncoder().encode(snapshot)) == snapshot)
    let input = heartInput(heart, seat: 0, id: 900, at: 20)
    #expect(try decoder.decode(MP2Input.self, from: JSONEncoder().encode(input)) == input)
    #expect(try decoder.decode(MP2ServerMessage.self, from: JSONEncoder().encode(MP2ServerMessage.left)) == .left)
}

@Test("MP2 revision 2 opening replacements retain the complete Arcade quiet interval for any next owner")
func arcadeSharedQuietOpening() throws {
    for lead in [0, 250] {
        for seed: UInt64 in 1...20 {
            var engine = try MP2Engine(
                matchID: "m", players: arcadePlayers(4), seed: seed, scheduleLeadMs: lead, gameplayRevision: 2)
            while engine.snapshot.targets.isEmpty { engine.advance(to: engine.elapsedMs + 10) }
            let target = try #require(engine.snapshot.targets.first)
            let input = arcadeInput(target)
            #expect(engine.submit(input, receivedAt: input.contactAtMs).accepted)
            while engine.snapshot.targets.isEmpty { engine.advance(to: engine.elapsedMs + 1) }
            let next = try #require(engine.snapshot.targets.first)
            let quiet = next.activateAtMs - input.contactAtMs
            #expect(quiet >= GameConfiguration.standard.spawnDelays.warmup.minimum)
            #expect(quiet <= GameConfiguration.standard.spawnDelays.warmup.maximum)
        }
    }
}

@Test("MP2 revision 2 shares Arcade quiet progression without removing pre-announced overlapping targets")
func arcadeSharedQuietProgression() throws {
    var engine = try MP2Engine(matchID: "m", players: arcadePlayers(4), seed: 31, gameplayRevision: 2)
    var announced: Set<Int> = []
    var minimumNextActivation = 0
    var overlaps = false
    var owners: [Int] = []
    while engine.elapsedMs < 150_000 {
        engine.advance(to: engine.elapsedMs + 20)
        for target in engine.snapshot.targets where announced.insert(target.id).inserted {
            #expect(target.activateAtMs >= minimumNextActivation)
            owners.append(target.ownerSeat)
        }
        overlaps = overlaps || engine.snapshot.targets.filter { $0.activateAtMs <= engine.elapsedMs }.count > 1
        for target in engine.snapshot.targets where target.activateAtMs + 100 <= engine.elapsedMs {
            let input = arcadeInput(target)
            #expect(engine.submit(input, receivedAt: engine.elapsedMs).accepted)
            let difficulty = try #require(engine.difficulty(for: target.ownerSeat, at: input.contactAtMs))
            minimumNextActivation = max(
                minimumNextActivation, input.contactAtMs + difficulty.spawnDelayRangeMilliseconds.minimum)
            // Input can publish future opportunities immediately; remember those as announced before the next contact.
            for next in engine.snapshot.targets where announced.insert(next.id).inserted {
                #expect(next.activateAtMs >= minimumNextActivation)
                owners.append(next.ownerSeat)
            }
        }
    }
    #expect(overlaps)
    #expect(zip(owners, owners.dropFirst()).contains { $0 == $1 })
    #expect(engine.snapshot.players.allSatisfy { $0.hits > 20 && $0.lives == 3 })
    #expect(engine.snapshot.gridDimension == 4)
    for player in engine.snapshot.players {
        let challengeHits = player.hits - (player.challengeBaselineHits ?? player.hits)
        let expected = resolveDifficulty(hits: 0, elapsedMilliseconds: 150_000, challengeHits: challengeHits)
        #expect(
            engine.difficulty(for: player.seat)?.spawnDelayRangeMilliseconds == expected.spawnDelayRangeMilliseconds)
        #expect(engine.difficulty(for: player.seat)?.responseWindowMilliseconds == expected.responseWindowMilliseconds)
    }
}

@Test("MP2 revision 2 changes color only after ten-second hits and never collides with players or persistent decoys")
func arcadeColorAndDecoyInvariants() throws {
    for count in 2...4 {
        var engine = try MP2Engine(
            matchID: "m", players: arcadePlayers(count), seed: UInt64(count), gameplayRevision: 2)
        var sawDecoy = false
        var sawTwoByTwoDecoy = false
        var changes = 0
        var preserved = 0
        while engine.elapsedMs < 100_000 {
            engine.advance(to: engine.elapsedMs + 20)
            for target in engine.snapshot.targets where target.activateAtMs + 100 <= engine.elapsedMs {
                let before = engine.snapshot
                let input = arcadeInput(target)
                #expect(engine.submit(input, receivedAt: engine.elapsedMs).accepted)
                let after = engine.snapshot
                if input.contactAtMs < 10_000 {
                    #expect(after.players[target.ownerSeat].colorIndex == before.players[target.ownerSeat].colorIndex)
                } else if after.players[target.ownerSeat].colorIndex != before.players[target.ownerSeat].colorIndex {
                    changes += 1
                }
                for decoy in before.decoys where decoy.expiresAtMs > engine.elapsedMs {
                    #expect(after.decoys.contains(decoy))
                    preserved += 1
                }
            }
            let snapshot = engine.snapshot
            let assigned = Set(snapshot.players.map(\.colorIndex))
            #expect(assigned.count == count)
            #expect(assigned.isDisjoint(with: snapshot.decoys.map(\.colorIndex)))
            for target in snapshot.targets {
                #expect(target.colorIndex == snapshot.players[target.ownerSeat].colorIndex)
            }
            let cells = snapshot.targets.map(\.cell) + snapshot.decoys.map(\.cell) + snapshot.hearts.map(\.cell)
            #expect(Set(cells).count == cells.count)
            for decoy in snapshot.decoys {
                #expect((1_000...3_000).contains(decoy.expiresAtMs - decoy.activateAtMs))
            }
            sawDecoy = sawDecoy || !snapshot.decoys.isEmpty
            sawTwoByTwoDecoy = sawTwoByTwoDecoy || (snapshot.gridDimension == 2 && !snapshot.decoys.isEmpty)
        }
        #expect(changes > 10)
        #expect(sawDecoy)
        #expect(sawTwoByTwoDecoy)
        #expect(preserved > 0)
    }
}

@Test("MP2 shared hearts restore one life and first admitted claimant wins exactly once without scoring")
func arcadeHeartClaims() throws {
    var engine = try MP2Engine(matchID: "m", players: arcadePlayers(), seed: 5, gameplayRevision: 2)
    for seat in 0...1 {
        #expect(
            engine.submit(
                MP2Input(
                    id: 900_000, seat: seat, targetID: nil, cell: -1, presentedAtMs: 0, contactAtMs: 0), receivedAt: 0
            ).accepted)
    }
    let heart = try firstHeart(&engine)
    #expect(heart.activateAtMs >= 40_000)
    #expect(engine.snapshot.gridDimension == 4)
    #expect(heart.expiresAtMs - heart.activateAtMs == 3_000)
    let before = engine.snapshot.players
    #expect(before.allSatisfy { $0.lives == 2 })
    let winning = heartInput(heart, seat: 1, id: 900_001, at: engine.elapsedMs)
    let receipt = engine.submit(winning, receivedAt: engine.elapsedMs)
    #expect(receipt.accepted && receipt.reason == "heart")
    #expect(engine.snapshot.players[1].lives == 3)
    #expect(engine.snapshot.players[1].score == before[1].score)
    #expect(engine.snapshot.players[1].hits == before[1].hits)
    #expect(engine.snapshot.hearts.isEmpty)
    #expect(engine.submit(winning, receivedAt: engine.elapsedMs) == receipt)
    let loser = heartInput(heart, seat: 0, id: 900_001, at: engine.elapsedMs - 1)
    let lostReceipt = engine.submit(loser, receivedAt: engine.elapsedMs)
    #expect(!lostReceipt.accepted && lostReceipt.reason == "heart-claimed")
    #expect(engine.snapshot.players[0].lives == 2)
    #expect(engine.snapshot.players[0].misses == 1)
}

@Test("MP2 revision 2 never announces a heart before the actual shared 4×4 board")
func arcadeMultiplayerHeartFourByFourGate() throws {
    for count in 2...4 {
        for seed: UInt64 in 1...5 {
            var engine = try MP2Engine(
                matchID: "m", players: arcadePlayers(count), seed: seed, scheduleLeadMs: 250, gameplayRevision: 2)
            #expect(engine.snapshot.gridDimension == 1)
            #expect(engine.snapshot.hearts.isEmpty)
            var sawTwoByTwo = false
            while engine.elapsedMs < 39_999 {
                playArcade(&engine, to: min(39_999, engine.elapsedMs + 20))
                sawTwoByTwo = sawTwoByTwo || engine.snapshot.gridDimension == 2
                #expect(engine.snapshot.gridDimension < 4)
                #expect(engine.snapshot.hearts.isEmpty)
            }
            #expect(sawTwoByTwo)
            playArcade(&engine, to: 40_000)
            #expect(engine.snapshot.gridDimension == 4)
            let heart = try firstHeart(&engine)
            #expect(heart.activateAtMs >= 40_250)
            #expect(heart.activateAtMs <= 40_500)
            #expect(heart.expiresAtMs - heart.activateAtMs == 3_000)
            #expect(engine.snapshot.gameplayRevision == 2)
        }
    }
}

@Test("MP2 hearts are bounded, expire harmlessly, reject spectators and never exceed the life cap")
func arcadeHeartBoundsAndSpectators() throws {
    var engine = try MP2Engine(matchID: "m", players: arcadePlayers(), seed: 5, gameplayRevision: 2)
    for (index, at) in [0, 1_500, 3_000].enumerated() {
        let input = MP2Input(
            id: 900_000 + index, seat: 0, targetID: nil, cell: -1, presentedAtMs: at, contactAtMs: at)
        #expect(engine.submit(input, receivedAt: at).accepted)
    }
    #expect(engine.snapshot.players[0].isOut)
    let heart = try firstHeart(&engine, excludingSeats: [0])
    let rejected = engine.submit(
        heartInput(heart, seat: 0, id: 900_003, at: engine.elapsedMs), receivedAt: engine.elapsedMs)
    #expect(!rejected.accepted && rejected.reason == "recovery-or-out")
    #expect(engine.snapshot.players[0].lives == 0)
    #expect(engine.snapshot.hearts == [heart])
    let accepted = engine.submit(
        heartInput(heart, seat: 1, id: 900_003, at: engine.elapsedMs), receivedAt: engine.elapsedMs)
    #expect(accepted.accepted)
    #expect(engine.snapshot.players[1].lives == 3)
    let next = try firstHeart(&engine, excludingSeats: [0])
    playArcade(&engine, to: next.expiresAtMs, excludingSeats: [0])
    #expect(engine.snapshot.hearts.isEmpty)
    let misses = engine.snapshot.players[1].misses
    let late = heartInput(next, seat: 1, id: 900_004, at: next.expiresAtMs)
    #expect(!engine.submit(late, receivedAt: engine.elapsedMs).accepted)
    #expect(engine.snapshot.players[1].misses == misses)
}

@Test("MP2 revised colors, hearts and quiet scheduling remain deterministic for two to four players")
func arcadeRevisionDeterminism() throws {
    for count in 2...4 {
        var first = try MP2Engine(matchID: "m", players: arcadePlayers(count), seed: 93, gameplayRevision: 2)
        var second = first
        playArcade(&first, to: 90_000)
        playArcade(&second, to: 90_000)
        #expect(first.snapshot == second.snapshot)
        var silent = try MP2Engine(matchID: "m", players: arcadePlayers(count), seed: 93, gameplayRevision: 2)
        #expect(silent.advance(to: 60_000).phase == .finished)
        #expect(silent.snapshot.hearts.isEmpty)
    }
}

@Test("MP2 heart admission tolerates ordinary delayed delivery and rejects malformed or ambiguous claims")
func arcadeDelayedHeartAdmission() throws {
    var engine = try MP2Engine(matchID: "m", players: arcadePlayers(), seed: 7, gameplayRevision: 2)
    let heart = try firstHeart(&engine)
    let ambiguous = MP2Input(
        id: 900_000, seat: 0, targetID: 1, cell: heart.cell, presentedAtMs: heart.activateAtMs,
        contactAtMs: engine.elapsedMs, heartID: heart.id)
    #expect(!engine.submit(ambiguous, receivedAt: engine.elapsedMs).accepted)
    #expect(engine.snapshot.hearts.contains(heart))
    let wrongCell = MP2Input(
        id: 900_001, seat: 0, targetID: nil, cell: (heart.cell + 1) % 16,
        presentedAtMs: heart.activateAtMs, contactAtMs: engine.elapsedMs, heartID: heart.id)
    #expect(!engine.submit(wrongCell, receivedAt: engine.elapsedMs).accepted)
    let beforePresentation = MP2Input(
        id: 900_002, seat: 0, targetID: nil, cell: heart.cell,
        presentedAtMs: heart.activateAtMs - 1, contactAtMs: engine.elapsedMs, heartID: heart.id)
    #expect(!engine.submit(beforePresentation, receivedAt: engine.elapsedMs).accepted)
    playArcade(&engine, to: heart.expiresAtMs + 300)
    let delayed = heartInput(heart, seat: 0, id: 900_003, at: heart.expiresAtMs - 1)
    #expect(engine.submit(delayed, receivedAt: engine.elapsedMs).accepted)
    let repeated = engine.snapshot.players[0]
    playArcade(&engine, to: engine.elapsedMs + 6_000)
    #expect(engine.snapshot.players[0].lives == repeated.lives)
    #expect(engine.snapshot.players[0].lives == 3)
}

@Test("MP2 revision 2 late target corrections preserve immutable colors and unique shared-board assignments")
func arcadeDelayedTargetColorInvariants() throws {
    var engine = try MP2Engine(matchID: "m", players: arcadePlayers(4), seed: 18, gameplayRevision: 2)
    var pending: [Int: MP2Target] = [:]
    var seen: Set<Int> = []
    var corrections = 0
    while engine.elapsedMs < 100_000, engine.snapshot.phase != .finished {
        engine.advance(to: engine.elapsedMs + 20)
        for target in engine.snapshot.targets where seen.insert(target.id).inserted {
            pending[target.id] = target
        }
        let due = pending.values.filter { $0.activateAtMs + 1_100 <= engine.elapsedMs }.sorted { $0.id < $1.id }
        for target in due {
            let input = MP2Input(
                id: target.id, seat: target.ownerSeat, targetID: target.id, cell: target.cell,
                presentedAtMs: target.activateAtMs + 400, contactAtMs: target.activateAtMs + 500)
            let receipt = engine.submit(input, receivedAt: engine.elapsedMs)
            #expect(receipt.accepted)
            if receipt.reason == "corrected-hit" { corrections += 1 }
            pending.removeValue(forKey: target.id)
        }
        let snapshot = engine.snapshot
        #expect(Set(snapshot.players.map(\.colorIndex)).count == 4)
        #expect(Set(snapshot.players.map(\.colorIndex)).isDisjoint(with: snapshot.decoys.map(\.colorIndex)))
        for target in snapshot.targets {
            #expect(snapshot.players[target.ownerSeat].colorIndex == target.colorIndex)
        }
    }
    #expect(corrections > 20)
    // The cutoff can land after a provisional expiry but before its artificial
    // delayed delivery. Resolve contacts that already happened without advancing
    // into another generation of targets before asserting final life accounting.
    for target in pending.values.filter({ $0.activateAtMs + 500 <= engine.elapsedMs }).sorted(by: { $0.id < $1.id }) {
        let input = MP2Input(
            id: target.id, seat: target.ownerSeat, targetID: target.id, cell: target.cell,
            presentedAtMs: target.activateAtMs + 400, contactAtMs: target.activateAtMs + 500)
        #expect(engine.submit(input, receivedAt: engine.elapsedMs).accepted)
    }
    #expect(engine.snapshot.players.allSatisfy { $0.lives == 3 })
}
