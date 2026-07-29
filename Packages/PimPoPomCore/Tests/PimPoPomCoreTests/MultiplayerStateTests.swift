import Foundation
import Testing

@testable import PimPoPomCore

private let multiplayerStateBase64URL32 = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

private func stateManifest(playerCount: Int = 2) -> MultiplayerManifest {
    MultiplayerManifest(
        matchId: "850105A2-11E3-4994-9437-D8DC8EFB6398",
        seed: multiplayerStateBase64URL32,
        participants: (0..<playerCount).map {
            MultiplayerManifestParticipant(
                participantId: String(
                    format: "00000000-0000-4000-8000-%012d",
                    $0 + 1
                ),
                seat: $0,
                colorIndex: $0
            )
        },
        manifestHash: multiplayerStateBase64URL32
    )
}

private func appendHit(
    to reducer: MultiplayerStateReducer,
    targetAt: Int,
    reaction: Int = 200
) throws {
    let ownerSeat: Int
    if let previous = reducer.state.lastTargetOwnerSeat {
        let living = reducer.state.livingSeats
        ownerSeat = living.first(where: { $0 > previous }) ?? living[0]
    } else {
        ownerSeat = reducer.state.livingSeats[0]
    }
    let color = reducer.state.players.first(where: { $0.seat == ownerSeat })!.colorIndex
    let targetId = reducer.state.nextTargetId
    let cell = targetId % MultiplayerProtocolConstants.boardCellCount
    try reducer.apply(
        .target(
            sequence: reducer.state.lastSequence + 1,
            at: targetAt,
            ownerSeat: ownerSeat,
            targetId: targetId,
            cell: cell,
            colorIndex: color
        )
    )
    try reducer.apply(
        .hit(
            sequence: reducer.state.lastSequence + 1,
            inputAt: targetAt + reaction,
            handledAt: targetAt + reaction + 5,
            seat: ownerSeat,
            targetId: targetId,
            cell: cell
        )
    )
}

@Test("Reducer derives score, ratings, and next-tap streak multipliers")
func multiplayerReducerScoringAndStreak() throws {
    let reducer = try MultiplayerStateReducer(manifest: stateManifest())
    try appendHit(to: reducer, targetAt: 500)
    try appendHit(to: reducer, targetAt: 1_100, reaction: 300)
    try appendHit(to: reducer, targetAt: 1_700)
    try appendHit(to: reducer, targetAt: 2_300, reaction: 300)
    try appendHit(to: reducer, targetAt: 2_900)
    try appendHit(to: reducer, targetAt: 3_500, reaction: 300)
    try appendHit(to: reducer, targetAt: 4_100)

    let player0 = reducer.state.players.first { $0.seat == 0 }!
    #expect(player0.hits == 4)
    #expect(player0.speedRatings[.godlike] == 4)
    #expect(player0.multiplier == 2)
    #expect(player0.streakProgress == 3)
    #expect(player0.maximumMultiplier == 2)
    // The first three 200 ms taps use 1×; the fourth uses the already-earned 2×.
    #expect(player0.score == 676 * 5)
    #expect(player0.fastestReactionMilliseconds == 200)
    #expect(player0.averageReactionMilliseconds == 200)
}

@Test("Miss clears target and decoys, resets only that player, and enforces recovery")
func multiplayerReducerMissAndRecovery() throws {
    let reducer = try MultiplayerStateReducer(manifest: stateManifest())
    try reducer.apply(
        .target(sequence: 1, at: 500, ownerSeat: 0, targetId: 1, cell: 0, colorIndex: 0)
    )
    try reducer.apply(
        .miss(sequence: 2, inputAt: 600, handledAt: 610, seat: 0, reason: .empty, cell: 1)
    )
    #expect(reducer.state.players[0].lives == 2)
    #expect(reducer.state.players[0].misses == 1)
    #expect(reducer.state.target == nil)
    #expect(reducer.state.players[0].recoveryUntil == 2_110)
    #expect(throws: MultiplayerProtocolError.self) {
        try reducer.apply(
            .target(sequence: 3, at: 2_000, ownerSeat: 1, targetId: 2, cell: 1, colorIndex: 1)
        )
    }
    try reducer.apply(
        .target(sequence: 3, at: 2_400, ownerSeat: 1, targetId: 2, cell: 1, colorIndex: 1)
    )
}

@Test("Another player's miss preserves the owned target")
func multiplayerNonOwnerMissPreservesTarget() throws {
    let reducer = try MultiplayerStateReducer(manifest: stateManifest())
    try reducer.apply(
        .target(sequence: 1, at: 500, ownerSeat: 0, targetId: 1, cell: 4, colorIndex: 0)
    )
    try reducer.apply(
        .miss(sequence: 2, inputAt: 600, handledAt: 610, seat: 1, reason: .wrong, cell: 4)
    )
    #expect(reducer.state.target?.targetId == 1)
    #expect(reducer.state.players[1].lives == 2)
    try reducer.apply(
        .hit(sequence: 3, inputAt: 700, handledAt: 710, seat: 0, targetId: 1, cell: 4)
    )
    #expect(reducer.state.target == nil)
    #expect(reducer.state.players[0].hits == 1)
}

@Test("Correct targets preserve decoys and natural expiry awards rotating owner")
func multiplayerReducerPersistentDecoy() throws {
    let reducer = try MultiplayerStateReducer(manifest: stateManifest())
    for at in stride(from: 500, through: 9_500, by: 1_500) {
        try appendHit(to: reducer, targetAt: at)
    }
    let decoySequence = reducer.state.lastSequence + 1
    try reducer.apply(
        .decoyActivate(
            sequence: decoySequence,
            at: 10_000,
            ownerSeat: 0,
            decoyId: 1,
            cell: 15,
            colorIndex: 5,
            lifetimeMilliseconds: 1_000
        )
    )
    try appendHit(to: reducer, targetAt: 10_500)
    #expect(reducer.state.decoys.map(\.decoyId) == [1])
    try reducer.apply(
        .decoyExpire(
            sequence: reducer.state.lastSequence + 1,
            at: 11_000,
            decoyId: 1
        )
    )
    let player0 = reducer.state.players.first { $0.seat == 0 }!
    #expect(player0.dodges == 1)
    #expect(player0.score >= MultiplayerProtocolConstants.dodgePoints)
    #expect(reducer.state.decoys.isEmpty)
}

@Test("Decoy concurrency changes only at seventy seconds")
func multiplayerReducerDecoyConcurrency() throws {
    #expect(MultiplayerStateReducer.maximumActiveDecoys(at: 9_999, totalHits: 100) == 0)
    #expect(MultiplayerStateReducer.maximumActiveDecoys(at: 69_999, totalHits: 100) == 1)
    #expect(MultiplayerStateReducer.maximumActiveDecoys(at: 70_000, totalHits: 0) == 2)
    #expect(MultiplayerStateReducer.maximumActiveDecoys(at: 70_000, totalHits: 80) == 6)
}

@Test("Response windows match multiplayer v1 phase boundaries")
func multiplayerResponseWindows() {
    #expect(MultiplayerStateReducer.responseWindowMilliseconds(at: 19_999, challengeHits: 0) == 1_000)
    #expect(MultiplayerStateReducer.responseWindowMilliseconds(at: 25_000, challengeHits: 0) == 875)
    #expect(MultiplayerStateReducer.responseWindowMilliseconds(at: 30_000, challengeHits: 0) == 750)
    #expect(MultiplayerStateReducer.responseWindowMilliseconds(at: 40_000, challengeHits: 0) == 1_000)
    #expect(MultiplayerStateReducer.responseWindowMilliseconds(at: 50_000, challengeHits: 1) == 995)
    #expect(MultiplayerStateReducer.responseWindowMilliseconds(at: 99_000, challengeHits: 999) == 200)
}

@Test("Reducer replay and checkpoint recover the exact derived state")
func multiplayerCheckpointReplay() throws {
    let manifest = stateManifest()
    let coordinator = try MultiplayerCoordinatorEngine(manifest: manifest, random: { 0 })
    let plans = try coordinator.start()
    let targetPlan = plans.first { $0.kind == .target }!
    _ = try coordinator.advance(to: targetPlan.at)
    _ = try coordinator.handleTap(
        seat: targetPlan.ownerSeat,
        cell: targetPlan.cell,
        inputAt: targetPlan.at + 200,
        handledAt: targetPlan.at + 210
    )

    let checkpoint = coordinator.checkpoint()
    let restored = try MultiplayerCoordinatorEngine(
        manifest: manifest,
        checkpoint: checkpoint,
        random: { 0 }
    )
    #expect(restored.state == coordinator.state)
    #expect(restored.events == coordinator.events)
    #expect(restored.transcript() == coordinator.transcript())
}

@Test("Coordinator plans before presentation, commits once, and blocks recovery taps")
func multiplayerCoordinatorPlanningAndInput() throws {
    let coordinator = try MultiplayerCoordinatorEngine(manifest: stateManifest(), random: { 0 })
    let openingPlans = try coordinator.start()
    #expect(openingPlans.count == 1)
    let first = openingPlans[0]
    #expect(first.kind == .target)
    #expect(first.at == 550)
    #expect(first.ownerSeat == 0)
    #expect(coordinator.events.isEmpty)

    let activation = try coordinator.advance(to: first.at)
    #expect(
        activation.committedEvents
            == [.target(sequence: 1, at: 550, ownerSeat: 0, targetId: 1, cell: 0, colorIndex: 0)]
    )
    let hit = try coordinator.handleTap(
        seat: 0,
        cell: first.cell,
        inputAt: 750,
        handledAt: 760
    )
    #expect(hit.outcome == .hit)
    #expect(hit.committedEvents.last?.integerTuple == [1, 2, 750, 760, 0, 1, 0])
    let second = hit.plannedActivations.first { $0.kind == .target }!
    #expect(second.ownerSeat == 1)

    _ = try coordinator.advance(to: second.at)
    let miss = try coordinator.handleTap(
        seat: 1,
        cell: (second.cell + 1) % MultiplayerProtocolConstants.boardCellCount,
        inputAt: second.at + 100,
        handledAt: second.at + 110
    )
    #expect(miss.outcome == .miss)
    let recoveryTap = try coordinator.handleTap(
        seat: 1,
        cell: second.cell,
        inputAt: second.at + 200,
        handledAt: second.at + 210
    )
    #expect(recoveryTap.outcome == .ignoredRecovery)
    #expect(recoveryTap.committedEvents.isEmpty)
}

@Test("Coordinator respects a 250 ms input reorder watermark")
func multiplayerCoordinatorInputReorderWatermark() throws {
    let coordinator = try MultiplayerCoordinatorEngine(manifest: stateManifest(), random: { 0 })
    let target = try coordinator.start().first { $0.kind == .target }!

    // At wall-clock 800 ms, integration advances only to the stable watermark.
    let firstWatermark = 800 - MultiplayerProtocolConstants.coordinatorReorderMilliseconds
    #expect(firstWatermark == target.at)
    _ = try coordinator.advance(to: firstWatermark)

    // This remote touch occurred just before expiry but arrived after the
    // deadline. Integration processes it before advancing past its input time.
    let arrivedAt = target.at + 1_240
    let inputAt = target.at + 990
    let secondWatermark =
        arrivedAt - MultiplayerProtocolConstants.coordinatorReorderMilliseconds
    #expect(secondWatermark == inputAt)
    let hit = try coordinator.handleTap(
        seat: target.ownerSeat,
        cell: target.cell,
        inputAt: inputAt,
        handledAt: arrivedAt
    )
    #expect(hit.outcome == .hit)
    #expect(hit.committedEvents.last?.logicalMilliseconds == secondWatermark)
    #expect(hit.committedEvents.last?.handledMilliseconds == arrivedAt)
    #expect(coordinator.clockMilliseconds == secondWatermark)

    _ = try coordinator.advance(to: secondWatermark)
    #expect(coordinator.events.contains { event in
        if case .miss(_, _, _, _, .late, _) = event { return true }
        return false
    } == false)

    // Advancing the next stable watermark does not retroactively create the
    // expired-target miss, because the queued hit resolved it first.
    _ = try coordinator.advance(
        to: arrivedAt
    )
    #expect(coordinator.events.contains { event in
        if case .miss(_, _, _, _, .late, _) = event { return true }
        return false
    } == false)
}

@Test("Placement uses score, hits, average reaction, then seat")
func multiplayerPlacementOrdering() throws {
    let reducer = try MultiplayerStateReducer(manifest: stateManifest(playerCount: 3))
    try appendHit(to: reducer, targetAt: 500, reaction: 300)  // seat 0, 541
    try appendHit(to: reducer, targetAt: 1_100, reaction: 200)  // seat 1, 676
    try appendHit(to: reducer, targetAt: 1_700, reaction: 400)  // seat 2, 424
    let placements = reducer.placements()
    #expect(placements.map(\.seat) == [1, 0, 2])
    #expect(placements.map(\.place) == [1, 2, 3])
}

@Test("Third misses require immediate input-time player-out events before finish")
func multiplayerPlayerOutAndFinish() throws {
    let reducer = try MultiplayerStateReducer(manifest: stateManifest())
    let misses: [(seat: Int, at: Int)] = [
        (0, 0), (1, 1),
        (0, 1_500), (1, 1_501),
        (0, 3_000), (1, 3_001),
    ]
    for (seat, at) in misses {
        try reducer.apply(
            .miss(
                sequence: reducer.state.lastSequence + 1,
                inputAt: at,
                handledAt: at,
                seat: seat,
                reason: .empty,
                cell: -1
            )
        )
        if reducer.state.players.first(where: { $0.seat == seat })?.lives == 0 {
            try reducer.apply(
                .playerOut(
                    sequence: reducer.state.lastSequence + 1,
                    at: at,
                    seat: seat
                )
            )
        }
    }
    try reducer.apply(
        .finish(sequence: reducer.state.lastSequence + 1, at: 3_001)
    )
    #expect(reducer.state.phase == .finished)
    #expect(reducer.state.finishedAt == 3_001)
    #expect(reducer.placements().count == 2)
}

@Test("Coordinator timeout path produces a complete replayable match")
func multiplayerCoordinatorTimeoutCompletion() throws {
    let manifest = stateManifest()
    let coordinator = try MultiplayerCoordinatorEngine(manifest: manifest, random: { 0 })
    _ = try coordinator.start()
    _ = try coordinator.advance(to: MultiplayerProtocolConstants.maximumDurationMilliseconds)
    #expect(coordinator.state.phase == .finished)
    #expect(coordinator.events.last?.integerTuple.first == 6)
    try coordinator.transcript().validate(against: manifest)
    let replayed = try MultiplayerStateReducer.replay(
        manifest: manifest,
        transcript: coordinator.transcript()
    )
    #expect(replayed.state == coordinator.state)
    #expect(replayed.placements() == coordinator.placements())
}
