import Foundation
import Testing

@testable import PimPoPomCore

private func mp2Players(_ count: Int = 2) -> [MP2Player] {
    (0..<count).map { MP2Player(id: "player-\($0)", seat: $0, colorIndex: $0, name: "Player\($0)") }
}

private func mp2Input(_ target: MP2Target, id: Int? = nil, reaction: Int = 100, presentationDelay: Int = 0) -> MP2Input
{
    MP2Input(
        id: id ?? target.id, seat: target.ownerSeat, targetID: target.id, cell: target.cell,
        presentedAtMs: target.activateAtMs + presentationDelay,
        contactAtMs: target.activateAtMs + presentationDelay + reaction
    )
}

@discardableResult
private func mp2Play(
    _ engine: inout MP2Engine, until end: Int, excluding: Set<Int> = [],
    inspect: (MP2Snapshot) -> Void = { _ in }
) -> [MP2Target] {
    var observed: [Int: MP2Target] = [:]
    while engine.elapsedMs < end, engine.snapshot.phase != .finished {
        engine.advance(to: min(end, engine.elapsedMs + 20))
        inspect(engine.snapshot)
        for target in engine.snapshot.targets {
            observed[target.id] = target
            if target.activateAtMs + 100 <= engine.elapsedMs, !excluding.contains(target.id) {
                let receipt = engine.submit(mp2Input(target), receivedAt: engine.elapsedMs)
                #expect(receipt.accepted)
            }
        }
    }
    return observed.values.sorted { $0.id < $1.id }
}

@Test("MP2 wire uses a separate version and round-trips all message families")
func mp2WireRoundTrip() throws {
    #expect(MP2Protocol.version == 2)
    #expect(MP2Protocol.ruleset == "multiplayer-shared-arcade-v2")
    let clientMessages: [MP2ClientMessage] = [
        .hello(ticket: "synthetic", protocolVersion: 2), .list, .create(capacity: 4), .join(roomID: "r"),
        .resume(roomID: "r", credential: "synthetic", generation: 2), .leave,
        .ready(value: true, intentID: 1, rosterRevision: 3), .start,
        .ping(id: 7, clientTimeMs: 20),
        .input(
            MP2Input(
                id: 1, seat: 0, targetID: 1, cell: 0, presentedAtMs: 1, contactAtMs: 2, roomEpoch: "e",
                sessionGeneration: 3)),
    ]
    for message in clientMessages {
        #expect(try JSONDecoder().decode(MP2ClientMessage.self, from: JSONEncoder().encode(message)) == message)
    }
    let engine = try MP2Engine(matchID: "m", players: mp2Players(), seed: 1)
    let room = MP2Room(
        id: "r", revision: 1, rosterRevision: 1, hostPlayerID: "player-0", capacity: 2, phase: .waiting,
        players: mp2Players(), epoch: "e")
    let serverMessages: [MP2ServerMessage] = [
        .welcome(playerID: "p", connectionID: "c", serverTimeMs: 10),
        .resumeCredential(roomID: "r", credential: "synthetic", generation: 2),
        .list([MP2RoomSummary(id: "r", hostName: "P", capacity: 2, playerCount: 2, revision: 1, phase: .waiting)]),
        .room(room), .snapshot(engine.snapshot), .receipt(MP2InputReceipt(id: 1, accepted: true, reason: "hit")),
        .error(code: "invalid", message: "Retry"), .pong(id: 7, clientTimeMs: 20, serverTimeMs: 30),
    ]
    for message in serverMessages {
        #expect(try JSONDecoder().decode(MP2ServerMessage.self, from: JSONEncoder().encode(message)) == message)
    }
    let raw = Data(#"{"hello":{"ticket":"synthetic","protocolVersion":2}}"#.utf8)
    #expect(try JSONDecoder().decode(MP2ClientMessage.self, from: raw) == clientMessages[0])
}

@Test("MP2 validates stable unique roster and discards client-authored game statistics")
func mp2Roster() throws {
    #expect(throws: MP2EngineError.invalidRoster) {
        try MP2Engine(matchID: "m", players: mp2Players(1), seed: 1)
    }
    var players = mp2Players()
    players[0].score = 1_000_000
    players[0].lives = 100
    let engine = try MP2Engine(matchID: "m", players: players, seed: 1)
    #expect(engine.snapshot.players[0].score == 0)
    #expect(engine.snapshot.players[0].lives == 3)
    players[1].colorIndex = 0
    #expect(throws: MP2EngineError.invalidRoster) {
        try MP2Engine(matchID: "m", players: players, seed: 1)
    }
}

@Test("MP2 two, three, and four silent participants finish naturally without input seals")
func mp2ZeroInputFinish() throws {
    for count in 2...4 {
        var engine = try MP2Engine(matchID: "m", players: mp2Players(count), seed: 42)
        let final = engine.advance(to: 60_000)
        #expect(final.phase == .finished)
        #expect(final.players.allSatisfy { $0.lives == 0 && $0.hits == 0 && $0.misses == 3 })
        #expect(final.targets.isEmpty)
        #expect(final.decoys.isEmpty)
        #expect(final.elapsedMs == final.players.compactMap(\.outAtMs).max())
        let frozen = engine.advance(to: 100_000)
        #expect(final == frozen)
    }
}

@Test("MP2 seeded schedules repeat owners and overlap without overlapping cells or own opportunities")
func mp2RandomOverlapAndGrid() throws {
    var engine = try MP2Engine(matchID: "m", players: mp2Players(4), seed: 31)
    var overlap = false
    var warmup = false
    var expanded = false
    let targets = mp2Play(&engine, until: 41_000) { snapshot in
        #expect(Set(snapshot.targets.map(\.cell)).count == snapshot.targets.count)
        #expect(Set(snapshot.targets.map(\.ownerSeat)).count == snapshot.targets.count)
        #expect(Set(snapshot.targets.map(\.cell)).isDisjoint(with: snapshot.decoys.map(\.cell)))
        if snapshot.players.reduce(0, { $0 + $1.hits }) < 4, snapshot.elapsedMs < 40_000 {
            warmup = true
            #expect(snapshot.gridDimension == 1)
            #expect(snapshot.targets.count <= 1)
        } else if snapshot.elapsedMs < 40_000 {
            expanded = true
            #expect(snapshot.gridDimension == 2)
        } else {
            #expect(snapshot.gridDimension == 4)
        }
        overlap = overlap || snapshot.targets.filter { $0.activateAtMs <= snapshot.elapsedMs }.count > 1
    }
    #expect(warmup && expanded && overlap)
    #expect(zip(targets, targets.dropFirst()).contains { $0.ownerSeat == $1.ownerSeat })
    var twin = try MP2Engine(matchID: "m", players: mp2Players(4), seed: 31)
    mp2Play(&twin, until: 41_000)
    #expect(engine.snapshot == twin.snapshot)
}

@Test("MP2 shares Arcade phase windows, quiet ranges, personal baseline and response floor")
func mp2DifficultyGoldens() throws {
    let boundaries: [(Int, Int, DelayRange)] = [
        (0, 1_000, DelayRange(550, 1_100)), (10_000, 1_000, DelayRange(550, 1_000)),
        (20_000, 1_000, DelayRange(500, 950)), (25_000, 875, DelayRange(500, 950)),
        (30_000, 750, DelayRange(475, 900)), (40_000, 1_000, DelayRange(525, 950)),
        (50_000, 1_000, DelayRange(425, 825)), (70_000, 1_000, DelayRange(425, 825)),
    ]
    var engine = try MP2Engine(matchID: "m", players: mp2Players(), seed: 10)
    for (at, response, range) in boundaries {
        let difficulty = try #require(engine.difficulty(for: 0, at: at))
        #expect(difficulty.responseWindowMilliseconds == response)
        #expect(difficulty.spawnDelayRangeMilliseconds == range)
    }
    mp2Play(&engine, until: 70_000)
    let player = try #require(engine.snapshot.players.first)
    let baseline = try #require(player.challengeBaselineHits)
    #expect(baseline > 0 && player.hits > baseline)
    #expect(
        engine.difficulty(for: player.seat)!.responseWindowMilliseconds
            == max(200, 1_000 - 5 * (player.hits - baseline)))
    mp2Play(&engine, until: 190_000)
    #expect(engine.difficulty(for: player.seat)!.responseWindowMilliseconds == 200)
    #expect(engine.snapshot.players[0].multiplier == 5)
    #expect(engine.snapshot.players[0].streakProgress == 5)
}

@Test("MP2 wrong-color taps cost only the tapping seat and cannot consume another target")
func mp2WrongColorAndDuplicate() throws {
    var engine = try MP2Engine(matchID: "m", players: mp2Players(), seed: 42)
    engine.advance(to: 700)
    let target = try #require(engine.snapshot.targets.first)
    let seat = 1 - target.ownerSeat
    let input = MP2Input(
        id: 99, seat: seat, targetID: target.id, cell: target.cell, presentedAtMs: target.activateAtMs,
        contactAtMs: target.activateAtMs + 100)
    let receipt = engine.submit(input, receivedAt: input.contactAtMs)
    #expect(receipt.accepted && receipt.reason == "wrong-color")
    #expect(engine.snapshot.players[seat].lives == 2)
    #expect(engine.snapshot.players[target.ownerSeat].lives == 3)
    #expect(engine.snapshot.targets.contains(target))
    let after = engine.snapshot
    #expect(engine.submit(input, receivedAt: input.contactAtMs + 500) == receipt)
    #expect(engine.snapshot == after)
    let changed = MP2Input(
        id: 99, seat: seat, targetID: target.id, cell: target.cell, presentedAtMs: target.activateAtMs,
        contactAtMs: target.activateAtMs + 101)
    #expect(engine.submit(changed, receivedAt: changed.contactAtMs).reason == "conflicting-input-id")
    let ownerHit = mp2Input(target)
    #expect(engine.submit(ownerHit, receivedAt: max(engine.elapsedMs, ownerHit.contactAtMs)).accepted)
}

@Test("MP2 contact at deadline loses once; first-visible delay and receipt delay never inflate reaction")
func mp2PresentationAndDeadline() throws {
    var engine = try MP2Engine(matchID: "m", players: mp2Players(), seed: 42)
    engine.advance(to: 700)
    let target = try #require(engine.snapshot.targets.first)
    let late = mp2Input(target, reaction: target.responseWindowMs)
    #expect(!engine.submit(late, receivedAt: late.contactAtMs).accepted)
    #expect(engine.snapshot.players[target.ownerSeat].misses == 1)

    var delayed = try MP2Engine(matchID: "m", players: mp2Players(), seed: 42)
    delayed.advance(to: 700)
    let contact = mp2Input(target, reaction: 200, presentationDelay: 700)
    let receipt = delayed.submit(contact, receivedAt: contact.contactAtMs + 1_900)
    #expect(receipt.reason == "corrected-hit")
    #expect(delayed.snapshot.players[target.ownerSeat].score == 676)
    #expect(delayed.snapshot.players[target.ownerSeat].lives == 3)
    #expect(delayed.snapshot.players[target.ownerSeat].fastestReactionMs == 200)
    #expect(delayed.snapshot.phase == .playing)
}

@Test("MP2 correcting provisional third expiry revives the seat before terminal admission closes")
func mp2TerminalCorrection() throws {
    var engine = try MP2Engine(matchID: "m", players: mp2Players(), seed: 42)
    var seen: [MP2Target] = []
    while engine.snapshot.phase == .playing {
        engine.advance(to: engine.elapsedMs + 20)
        seen.append(contentsOf: engine.snapshot.targets)
    }
    #expect(engine.snapshot.phase == .finishing)
    let last = try #require(seen.max { $0.expiresAtMs < $1.expiresAtMs })
    let contact = mp2Input(last)
    let receipt = engine.submit(contact, receivedAt: last.expiresAtMs + 1_000)
    #expect(receipt.reason == "corrected-hit")
    #expect(engine.snapshot.players[last.ownerSeat].lives == 1)
    #expect(engine.snapshot.players[last.ownerSeat].misses == 2)
    #expect(engine.snapshot.phase == .playing)
    engine.advance(to: engine.elapsedMs + 10_000)
    #expect(engine.snapshot.phase == .finished)
}

@Test("MP2 late correction replays subsequent multiplier awards while keeping issued windows stable")
func mp2LaterMultiplierReplay() throws {
    var engine = try MP2Engine(matchID: "m", players: mp2Players(), seed: 31)
    mp2Play(&engine, until: 10_000)
    var withheld: MP2Target?
    while withheld == nil {
        engine.advance(to: engine.elapsedMs + 20)
        withheld = engine.snapshot.targets.first { $0.ownerSeat == 0 }
        for target in engine.snapshot.targets
        where target.ownerSeat != 0 && target.activateAtMs + 100 <= engine.elapsedMs {
            #expect(engine.submit(mp2Input(target), receivedAt: engine.elapsedMs).accepted)
        }
    }
    let old = try #require(withheld)
    let multiplier = engine.snapshot.players[0].multiplier
    #expect(multiplier > 1)
    let late = mp2Input(old, reaction: 999, presentationDelay: 750)
    let arrival = late.contactAtMs + 2_000
    var nextHit: MP2Target?
    var reserved: [Int: MP2Target] = [:]
    mp2Play(&engine, until: arrival - 1, excluding: [old.id]) { snapshot in
        for target in snapshot.targets where target.ownerSeat == 0 && target.id != old.id {
            reserved[target.id] = target
            if target.activateAtMs + 100 <= snapshot.elapsedMs { nextHit = target }
        }
    }
    let later = try #require(nextHit)
    let before = engine.snapshot.players[0]
    let receipt = engine.submit(late, receivedAt: arrival)
    #expect(receipt.reason == "corrected-hit")
    let oldAward =
        ReactionScoring.points(reactionMilliseconds: 999, responseWindowMilliseconds: Double(old.responseWindowMs))
        * multiplier
    let laterExtra =
        ReactionScoring.points(reactionMilliseconds: 100, responseWindowMilliseconds: Double(later.responseWindowMs))
        * (multiplier - 1)
    #expect(engine.snapshot.players[0].score == before.score + oldAward + laterExtra)
    #expect(engine.snapshot.players[0].misses == 0)
    for target in engine.snapshot.targets where reserved[target.id] != nil {
        #expect(target == reserved[target.id])
    }
}

@Test("MP2 marked decoys persist across hits, award one natural dodge, and reserve target capacity")
func mp2PersistentDecoys() throws {
    var engine = try MP2Engine(matchID: "m", players: mp2Players(), seed: 4)
    mp2Play(&engine, until: 10_100)
    let decoy = try #require(engine.snapshot.decoys.first)
    #expect(decoy.colorIndex != engine.snapshot.players[decoy.beneficiarySeat].colorIndex)
    #expect(engine.snapshot.players.contains { $0.colorIndex == decoy.colorIndex })
    let before = engine.snapshot.players[decoy.beneficiarySeat].dodges
    var sawHitWhilePresent = false
    mp2Play(&engine, until: decoy.expiresAtMs - 1) { snapshot in
        if snapshot.players.reduce(0, { $0 + $1.hits }) > 0 {
            sawHitWhilePresent = true
            #expect(snapshot.decoys.contains { $0.id == decoy.id })
        }
        #expect(snapshot.decoys.count <= 1)
    }
    #expect(sawHitWhilePresent)
    engine.advance(to: decoy.expiresAtMs)
    #expect(engine.snapshot.players[decoy.beneficiarySeat].dodges == before + 1)
    let score = engine.snapshot.players[decoy.beneficiarySeat].score
    engine.advance(to: decoy.expiresAtMs + 1)
    #expect(engine.snapshot.players[decoy.beneficiarySeat].score == score)
    #expect(!engine.snapshot.decoys.contains { $0.id == decoy.id })
}

@Test("MP2 a disconnected seat pauses alone and resumes without a global barrier")
func mp2Disconnect() throws {
    var engine = try MP2Engine(matchID: "m", players: mp2Players(), seed: 42)
    engine.disconnect(seat: 0, at: 700)
    mp2Play(&engine, until: 4_000)
    #expect(engine.snapshot.players[0].lives == 3)
    #expect(engine.snapshot.players[1].hits > 0)
    #expect(!engine.snapshot.targets.contains { $0.ownerSeat == 0 })
    engine.reconnect(seat: 0, at: 4_000)
    mp2Play(&engine, until: 7_000)
    #expect(engine.snapshot.players[0].hits > 0)
    engine.disconnect(seat: 0, at: 7_000)
    engine.eliminateDisconnected(seat: 0, at: 7_100)
    #expect(engine.snapshot.players[0].isOut)
    #expect(engine.snapshot.phase == .playing)
}

@Test("MP2 rejects excessive presentation or packet delay without ending other seats")
func mp2AdmissionBounds() throws {
    var engine = try MP2Engine(matchID: "m", players: mp2Players(), seed: 42)
    engine.advance(to: 700)
    let target = try #require(engine.snapshot.targets.first)
    let invalid = mp2Input(target, id: 50, presentationDelay: 751)
    #expect(engine.submit(invalid, receivedAt: invalid.contactAtMs).reason == "invalid-presentation")
    let stale = mp2Input(target, id: 51)
    #expect(engine.submit(stale, receivedAt: stale.contactAtMs + 2_001).reason == "invalid-timing-or-input")
    #expect(engine.snapshot.phase == .playing)
    #expect(engine.snapshot.players[target.ownerSeat].misses == 1)
}

@Test("MP2 late beneficiary mistake revokes an already credited decoy dodge after recovery ended")
func mp2LateMistakeRevokesDodge() throws {
    var engine = try MP2Engine(matchID: "m", players: mp2Players(), seed: 4)
    mp2Play(&engine, until: 10_100)
    var decoy = try #require(engine.snapshot.decoys.first)
    while decoy.expiresAtMs - decoy.activateAtMs <= 1_600 {
        mp2Play(&engine, until: decoy.expiresAtMs + 2_000)
        decoy = try #require(engine.snapshot.decoys.first)
    }
    let contact = decoy.expiresAtMs - 1_600
    let player = decoy.beneficiarySeat
    let before = engine.snapshot.players[player].dodges
    mp2Play(&engine, until: decoy.expiresAtMs + 1)
    #expect(engine.snapshot.players[player].dodges == before + 1)
    let mistake = MP2Input(
        id: 99_999, seat: player, targetID: nil, cell: decoy.cell, presentedAtMs: contact, contactAtMs: contact)
    #expect(engine.submit(mistake, receivedAt: decoy.expiresAtMs + 1).accepted)
    #expect(engine.snapshot.players[player].dodges == before)
    #expect(engine.snapshot.phase == .playing)
}

@Test("MP2 mistake clears only beneficiary decoys and schedules quiet time after recovery")
func mp2BeneficiaryClear() throws {
    var engine = try MP2Engine(matchID: "m", players: mp2Players(), seed: 4)
    mp2Play(&engine, until: 10_100)
    let decoy = try #require(engine.snapshot.decoys.first)
    let other = 1 - decoy.beneficiarySeat
    let otherInput = MP2Input(
        id: 99_000, seat: other, targetID: nil, cell: decoy.cell, presentedAtMs: engine.elapsedMs,
        contactAtMs: engine.elapsedMs)
    #expect(engine.submit(otherInput, receivedAt: engine.elapsedMs).accepted)
    #expect(engine.snapshot.decoys.contains(decoy))
    let ownInput = MP2Input(
        id: 99_001, seat: decoy.beneficiarySeat, targetID: nil, cell: decoy.cell, presentedAtMs: engine.elapsedMs,
        contactAtMs: engine.elapsedMs)
    #expect(engine.submit(ownInput, receivedAt: engine.elapsedMs).accepted)
    #expect(!engine.snapshot.decoys.contains(decoy))
    let earliest = engine.elapsedMs + 1_500 + 2_200
    engine.advance(to: earliest - 1)
    #expect(!engine.snapshot.decoys.contains { $0.beneficiarySeat == decoy.beneficiarySeat })
}

@Test("MP2 board-gap misses cannot consume another seat's target")
func mp2GapMiss() throws {
    var engine = try MP2Engine(matchID: "m", players: mp2Players(), seed: 42)
    engine.advance(to: 700)
    let target = try #require(engine.snapshot.targets.first)
    let seat = 1 - target.ownerSeat
    let input = MP2Input(id: 99_999, seat: seat, targetID: nil, cell: -1, presentedAtMs: 700, contactAtMs: 700)
    #expect(engine.submit(input, receivedAt: 700).reason == "empty")
    #expect(engine.snapshot.players[seat].lives == 2)
    #expect(engine.snapshot.targets.contains(target))
}

@Test("MP2 provisional expiry reserves the cell through every admitted first-visible response window")
func mp2VisibleWindowReservation() throws {
    var engine = try MP2Engine(matchID: "m", players: mp2Players(), seed: 42)
    engine.advance(to: 700)
    let target = try #require(engine.snapshot.targets.first)
    engine.advance(to: target.expiresAtMs + 749)
    #expect(!engine.snapshot.targets.contains { $0.cell == target.cell })
    let input = mp2Input(target, reaction: 999, presentationDelay: 750)
    #expect(engine.submit(input, receivedAt: input.contactAtMs).reason == "corrected-hit")
    #expect(engine.snapshot.players[target.ownerSeat].lives == 3)
}
