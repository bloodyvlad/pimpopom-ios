import Foundation
import Testing

@testable import PimPoPomCore

private func competitiveEngine(_ count: Int = 2, revision: Int = 3, seed: UInt64 = 7) throws -> MP2Engine {
    try MP2Engine(
        matchID: "match",
        players: (0..<count).map {
            MP2Player(id: "p\($0)", seat: $0, colorIndex: $0, name: "P\($0)")
        }, seed: seed, gameplayRevision: revision)
}

private func playCompetitive(_ engine: inout MP2Engine, to end: Int) {
    while engine.elapsedMs < end && engine.snapshot.phase != .finished {
        engine.advance(to: min(end, engine.elapsedMs + 20))
        for target in engine.snapshot.targets where target.activateAtMs + 100 <= engine.elapsedMs {
            let receipt = engine.submit(
                MP2Input(
                    id: target.id, seat: target.ownerSeat, targetID: target.id, cell: target.cell,
                    presentedAtMs: target.activateAtMs, contactAtMs: target.activateAtMs + 100),
                receivedAt: engine.elapsedMs)
            #expect(receipt.accepted)
        }
    }
}

private func wrongContact(_ engine: inout MP2Engine, seat: Int, id: Int, at: Int) {
    #expect(
        engine.submit(
            MP2Input(
                id: id, seat: seat, targetID: nil, cell: -1,
                presentedAtMs: at, contactAtMs: at), receivedAt: at
        ).accepted)
}

@Test("Last living player keeps playing and scoring in every supported room size", arguments: [2, 3, 4])
func competitiveLastPlayerContinues(_ count: Int) throws {
    var engine = try competitiveEngine(count)
    for seat in 1..<count {
        engine.disconnect(seat: seat, at: 0)
        engine.eliminateDisconnected(seat: seat, at: 0)
    }
    #expect(engine.snapshot.phase == .playing)
    playCompetitive(&engine, to: 20_000)
    let survivor = engine.snapshot.players[0]
    #expect(!survivor.isOut && survivor.hits > 5 && survivor.score > 0)
    #expect(survivor.eligibleAliveMs == 20_000)
    #expect(survivor.maxMultiplier == 5)
    #expect(engine.snapshot.finalReason == nil)
    #expect(engine.snapshot.players.dropFirst().allSatisfy { $0.eligibleAliveMs == 0 })
    engine.advance(to: 60_000)
    #expect(engine.snapshot.phase == .finished)
    #expect(engine.snapshot.finalReason == .allOut)
    #expect(engine.snapshot.players[0].score >= survivor.score)
    #expect(engine.snapshot.players[0].eligibleAliveMs == engine.snapshot.players[0].outAtMs)
}

@Test("Reward time excludes disconnected and spectator intervals while including alive recovery")
func competitiveAliveClock() throws {
    var engine = try competitiveEngine()
    playCompetitive(&engine, to: 20_000)
    engine.disconnect(seat: 0, at: 20_000)
    playCompetitive(&engine, to: 22_000)
    engine.reconnect(seat: 0, at: 22_000)
    playCompetitive(&engine, to: 39_000)
    wrongContact(&engine, seat: 0, id: 900_000, at: 39_000)
    playCompetitive(&engine, to: 41_000)
    #expect(engine.snapshot.players[0].eligibleAliveMs == 39_000)
    engine.disconnect(seat: 0, at: 41_000)
    engine.eliminateDisconnected(seat: 0, at: 41_000)
    playCompetitive(&engine, to: 50_000)
    engine.reconnect(seat: 0, at: 50_000)
    playCompetitive(&engine, to: 60_000)
    #expect(engine.snapshot.players[0].eligibleAliveMs == 39_000)
    #expect(engine.snapshot.players[1].eligibleAliveMs == 60_000)
}

@Test("A delayed original heart contact corrects provisional final death and reports one life exactly once")
func competitiveDelayedHeartBeforeFinalDeath() throws {
    var engine = try competitiveEngine()
    playCompetitive(&engine, to: 39_000)
    wrongContact(&engine, seat: 0, id: 900_000, at: 39_000)
    playCompetitive(&engine, to: 40_500)
    wrongContact(&engine, seat: 0, id: 900_001, at: 40_500)
    playCompetitive(&engine, to: 42_000)
    let heart = try #require(engine.snapshot.hearts.first)
    engine.disconnect(seat: 1, at: 42_000)
    engine.eliminateDisconnected(seat: 1, at: 42_000)
    wrongContact(&engine, seat: 0, id: 900_002, at: 42_050)
    #expect(engine.snapshot.phase == .finishing)
    let afterDeath = MP2Input(
        id: 900_004, seat: 0, targetID: nil, cell: heart.cell,
        presentedAtMs: heart.activateAtMs, contactAtMs: 42_060, heartID: heart.id)
    #expect(!engine.submit(afterDeath, receivedAt: 42_075).accepted)
    let input = MP2Input(
        id: 900_003, seat: 0, targetID: nil, cell: heart.cell,
        presentedAtMs: heart.activateAtMs, contactAtMs: 42_025, heartID: heart.id)
    let receipt = engine.submit(input, receivedAt: 42_100)
    #expect(receipt.accepted && receipt.lifeAwarded == true)
    #expect(engine.snapshot.phase == .playing && engine.snapshot.finalReason == nil)
    #expect(engine.snapshot.players[0].lives == 1)
    #expect(engine.snapshot.players[0].outAtMs == nil)
    #expect(engine.snapshot.players[0].eligibleAliveMs == 42_100)
    #expect(engine.submit(input, receivedAt: 42_200) == receipt)
    #expect(engine.snapshot.players[0].lives == 1)
    playCompetitive(&engine, to: 48_000)
    #expect(engine.snapshot.players[0].eligibleAliveMs == 48_000)
}

@Test("Full-life heart consumption never announces a life award and legacy metadata remains absent")
func competitiveHeartCapAndCompatibility() throws {
    for revision in [1, 2, 3] {
        var engine = try competitiveEngine(revision: revision)
        playCompetitive(&engine, to: 40_500)
        if revision >= 2 {
            let heart = try #require(engine.snapshot.hearts.first)
            let input = MP2Input(
                id: 900_000, seat: 0, targetID: nil, cell: heart.cell,
                presentedAtMs: heart.activateAtMs, contactAtMs: 40_500, heartID: heart.id)
            let receipt = engine.submit(input, receivedAt: 40_500)
            #expect(receipt.accepted)
            #expect(receipt.lifeAwarded == (revision == 3 ? false : nil))
            let competing = MP2Input(
                id: 900_001, seat: 1, targetID: nil, cell: heart.cell,
                presentedAtMs: heart.activateAtMs, contactAtMs: 40_499, heartID: heart.id)
            let losing = engine.submit(competing, receivedAt: 40_500)
            #expect(!losing.accepted && losing.reason == "heart-claimed" && losing.lifeAwarded == nil)
        }
        #expect(engine.snapshot.players[0].eligibleAliveMs == (revision == 3 ? 40_500 : nil))
        #expect(engine.snapshot.players[0].maxMultiplier == (revision == 3 ? 5 : nil))
        #expect(engine.snapshot.finalReason == nil)
    }
    let old = Data(#"{"id":1,"accepted":true,"reason":"heart","revision":2}"#.utf8)
    #expect(try JSONDecoder().decode(MP2InputReceipt.self, from: old).lifeAwarded == nil)
}

@Test("Revision3 reconnect retains the complete terminal correction horizon and exact presence time")
func competitiveTerminalContactReconnect() throws {
    var engine = try competitiveEngine()
    var seen: [MP2Target] = []
    while engine.snapshot.phase == .playing {
        engine.advance(to: engine.elapsedMs + 20)
        seen.append(contentsOf: engine.snapshot.targets)
    }
    let last = try #require(seen.max { $0.expiresAtMs < $1.expiresAtMs })
    let disconnected = engine.elapsedMs
    engine.disconnect(seat: last.ownerSeat, at: disconnected)
    engine.reconnect(seat: last.ownerSeat, at: disconnected + 200)
    let input = MP2Input(
        id: last.id, seat: last.ownerSeat, targetID: last.id, cell: last.cell,
        presentedAtMs: last.activateAtMs, contactAtMs: last.activateAtMs + 100)
    #expect(engine.submit(input, receivedAt: disconnected + 200).reason == "corrected-hit")
    #expect(engine.snapshot.phase == .playing && engine.snapshot.players[last.ownerSeat].lives == 1)
    #expect(engine.snapshot.players[last.ownerSeat].eligibleAliveMs == disconnected)
    playCompetitive(&engine, to: disconnected + 6_000)
    #expect(engine.snapshot.players[last.ownerSeat].eligibleAliveMs == disconnected + 5_800)
}

@Test("Time limit freezes authoritative alive time after the admission horizon")
func competitiveTimeLimit() throws {
    var engine = try competitiveEngine(seed: 29)
    playCompetitive(&engine, to: 899_000)
    var held: MP2Target?
    while engine.elapsedMs < 900_000 {
        engine.advance(to: min(900_000, engine.elapsedMs + 20))
        for target in engine.snapshot.targets {
            if held == nil, target.expiresAtMs > 900_000, target.activateAtMs + 1 < 900_000 { held = target }
            guard target.id != held?.id, target.activateAtMs + 100 <= engine.elapsedMs else { continue }
            #expect(
                engine.submit(
                    MP2Input(
                        id: target.id, seat: target.ownerSeat, targetID: target.id,
                        cell: target.cell, presentedAtMs: target.activateAtMs, contactAtMs: target.activateAtMs + 100),
                    receivedAt: engine.elapsedMs
                ).accepted)
        }
    }
    #expect(engine.snapshot.phase == .finishing && engine.snapshot.finalReason == .timeLimit)
    let target = try #require(held)
    let previous = engine.snapshot.players[target.ownerSeat].score
    let delayed = MP2Input(
        id: target.id, seat: target.ownerSeat, targetID: target.id, cell: target.cell,
        presentedAtMs: target.activateAtMs, contactAtMs: target.activateAtMs + 1)
    #expect(engine.submit(delayed, receivedAt: 900_100).accepted)
    #expect(engine.snapshot.players[target.ownerSeat].score > previous)
    #expect(engine.snapshot.phase == .finishing && engine.snapshot.elapsedMs == 900_000)
    engine.advance(to: 903_000)
    #expect(engine.snapshot.phase == .finished && engine.snapshot.elapsedMs == 900_000)
    #expect(engine.snapshot.players.allSatisfy { !$0.isOut && $0.eligibleAliveMs == 900_000 })
}
