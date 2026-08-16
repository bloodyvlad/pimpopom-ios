import Foundation
import Testing

@testable import PimPoPomCore

@Test("Fast policy deduplicates identical copies and rejects conflicts")
func multiplayerFastInputIdentity() throws {
    var frontier = try MultiplayerInputFrontier(seats: [0, 1])
    let input = MultiplayerSealedInput(
        id: MultiplayerInputID(seat: 1, inputSequence: 1),
        cell: 7,
        inputAt: 90
    )

    #expect(try frontier.recordInput(input) == .inserted)
    #expect(try frontier.recordInput(input) == .duplicate)
    #expect(throws: MultiplayerFastPolicyError.conflictingInput(input.id)) {
        try frontier.recordInput(
            MultiplayerSealedInput(id: input.id, cell: 8, inputAt: 90)
        )
    }
}

@Test("Same-millisecond contacts remain distinct by input sequence")
func multiplayerFastSameMillisecondInputs() throws {
    var frontier = try MultiplayerInputFrontier(seats: [0, 1])
    let first = MultiplayerSealedInput(
        id: MultiplayerInputID(seat: 1, inputSequence: 1),
        cell: 7,
        inputAt: 90
    )
    let second = MultiplayerSealedInput(
        id: MultiplayerInputID(seat: 1, inputSequence: 2),
        cell: 7,
        inputAt: 90
    )

    #expect(try frontier.recordInput(first) == .inserted)
    #expect(try frontier.recordInput(second) == .inserted)
    try frontier.recordSeal(
        MultiplayerInputSeal(seat: 1, throughInputAt: 90, highestInputSequence: 2)
    )
    #expect(frontier.effectiveSeal(for: 1)?.highestInputSequence == 2)
}

@Test("An earlier missing input freezes the global frontier until recovery")
func multiplayerFastMissingEarlierInput() throws {
    var frontier = try MultiplayerInputFrontier(seats: [0, 1])
    try frontier.recordSeal(
        MultiplayerInputSeal(seat: 0, throughInputAt: 100, highestInputSequence: 0)
    )
    _ = try frontier.recordInput(
        MultiplayerSealedInput(
            id: MultiplayerInputID(seat: 1, inputSequence: 2),
            cell: 9,
            inputAt: 95
        )
    )
    try frontier.recordSeal(
        MultiplayerInputSeal(seat: 1, throughInputAt: 100, highestInputSequence: 2)
    )

    #expect(frontier.publishWatermark == nil)
    #expect(
        frontier.missingInputIDs
            == [MultiplayerInputID(seat: 1, inputSequence: 1)]
    )

    _ = try frontier.recordInput(
        MultiplayerSealedInput(
            id: MultiplayerInputID(seat: 1, inputSequence: 1),
            cell: 4,
            inputAt: 80
        )
    )
    #expect(frontier.publishWatermark == 100)
    #expect(
        frontier.takeReadyInputs().map(\.id)
            == [
                MultiplayerInputID(seat: 1, inputSequence: 1),
                MultiplayerInputID(seat: 1, inputSequence: 2),
            ]
    )
}

@Test("Ready inputs use contact, seat, and sequence ordering")
func multiplayerFastReadyOrdering() throws {
    var frontier = try MultiplayerInputFrontier(seats: [0, 1, 2])
    let inputs = [
        MultiplayerSealedInput(
            id: MultiplayerInputID(seat: 2, inputSequence: 1),
            cell: 2,
            inputAt: 90
        ),
        MultiplayerSealedInput(
            id: MultiplayerInputID(seat: 0, inputSequence: 1),
            cell: 0,
            inputAt: 90
        ),
        MultiplayerSealedInput(
            id: MultiplayerInputID(seat: 1, inputSequence: 2),
            cell: 3,
            inputAt: 90
        ),
        MultiplayerSealedInput(
            id: MultiplayerInputID(seat: 1, inputSequence: 1),
            cell: 1,
            inputAt: 90
        ),
    ]
    for input in inputs {
        _ = try frontier.recordInput(input)
    }
    try frontier.recordSeal(
        MultiplayerInputSeal(seat: 0, throughInputAt: 100, highestInputSequence: 1)
    )
    try frontier.recordSeal(
        MultiplayerInputSeal(seat: 1, throughInputAt: 100, highestInputSequence: 2)
    )
    try frontier.recordSeal(
        MultiplayerInputSeal(seat: 2, throughInputAt: 100, highestInputSequence: 1)
    )

    #expect(
        frontier.takeReadyInputs().map(\.id)
            == [
                MultiplayerInputID(seat: 0, inputSequence: 1),
                MultiplayerInputID(seat: 1, inputSequence: 1),
                MultiplayerInputID(seat: 1, inputSequence: 2),
                MultiplayerInputID(seat: 2, inputSequence: 1),
            ]
    )
}

@Test("Pending seal boundaries cannot be erased by a newer seal")
func multiplayerFastPendingSealBoundary() throws {
    var frontier = try MultiplayerInputFrontier(seats: [0, 1])
    try frontier.recordSeal(
        MultiplayerInputSeal(seat: 1, throughInputAt: 100, highestInputSequence: 1)
    )
    try frontier.recordSeal(
        MultiplayerInputSeal(seat: 1, throughInputAt: 200, highestInputSequence: 2)
    )

    #expect(throws: MultiplayerFastPolicyError.inputOutsideDeclaredSeal) {
        try frontier.recordInput(
            MultiplayerSealedInput(
                id: MultiplayerInputID(seat: 1, inputSequence: 1),
                cell: 4,
                inputAt: 150
            )
        )
    }
}

@Test("Effective seals never allow a later contact in a closed millisecond")
func multiplayerFastEffectiveSealBoundary() throws {
    var frontier = try MultiplayerInputFrontier(seats: [0, 1])
    try frontier.recordSeal(
        MultiplayerInputSeal(seat: 1, throughInputAt: 100, highestInputSequence: 0)
    )

    #expect(throws: MultiplayerFastPolicyError.inputAtOrBeforeEffectiveSeal) {
        try frontier.recordInput(
            MultiplayerSealedInput(
                id: MultiplayerInputID(seat: 1, inputSequence: 1),
                cell: 4,
                inputAt: 100
            )
        )
    }
}

@Test("Seals are component-wise monotonic and the watermark cannot roll back")
func multiplayerFastMonotonicSeals() throws {
    var frontier = try MultiplayerInputFrontier(seats: [0, 1])
    try frontier.recordSeal(
        MultiplayerInputSeal(seat: 0, throughInputAt: 100, highestInputSequence: 0)
    )
    try frontier.recordSeal(
        MultiplayerInputSeal(seat: 1, throughInputAt: 100, highestInputSequence: 0)
    )
    #expect(frontier.publishWatermark == 100)

    try frontier.recordSeal(
        MultiplayerInputSeal(seat: 0, throughInputAt: 150, highestInputSequence: 0)
    )
    #expect(frontier.publishWatermark == 100)
    try frontier.recordSeal(
        MultiplayerInputSeal(seat: 1, throughInputAt: 99, highestInputSequence: 0)
    )
    #expect(frontier.publishWatermark == 100)
    _ = try frontier.recordInput(
        MultiplayerSealedInput(
            id: MultiplayerInputID(seat: 1, inputSequence: 1),
            cell: 4,
            inputAt: 125
        )
    )
    try frontier.recordSeal(
        MultiplayerInputSeal(seat: 1, throughInputAt: 150, highestInputSequence: 1)
    )
    #expect(frontier.publishWatermark == 150)
    #expect(throws: MultiplayerFastPolicyError.regressingSeal) {
        try frontier.recordSeal(
            MultiplayerInputSeal(seat: 1, throughInputAt: 200, highestInputSequence: 0)
        )
    }
}

@Test("A dominated seal may arrive after its newer cumulative checkpoint")
func multiplayerFastReorderedDominatedSeal() throws {
    var frontier = try MultiplayerInputFrontier(seats: [0, 1])
    _ = try frontier.recordInput(
        MultiplayerSealedInput(
            id: MultiplayerInputID(seat: 1, inputSequence: 1),
            cell: 4,
            inputAt: 80
        )
    )
    _ = try frontier.recordInput(
        MultiplayerSealedInput(
            id: MultiplayerInputID(seat: 1, inputSequence: 2),
            cell: 5,
            inputAt: 150
        )
    )
    let newer = MultiplayerInputSeal(
        seat: 1,
        throughInputAt: 200,
        highestInputSequence: 2
    )
    try frontier.recordSeal(newer)

    try frontier.recordSeal(
        MultiplayerInputSeal(
            seat: 1,
            throughInputAt: 100,
            highestInputSequence: 1
        )
    )

    #expect(frontier.effectiveSeal(for: 1) == newer)
}

@Test("A reordered older seal still constrains evidence missing from a newer seal")
func multiplayerFastReorderedPendingSealBoundary() throws {
    var frontier = try MultiplayerInputFrontier(seats: [0, 1])
    try frontier.recordSeal(
        MultiplayerInputSeal(
            seat: 1,
            throughInputAt: 200,
            highestInputSequence: 2
        )
    )
    try frontier.recordSeal(
        MultiplayerInputSeal(
            seat: 1,
            throughInputAt: 100,
            highestInputSequence: 1
        )
    )

    #expect(throws: MultiplayerFastPolicyError.inputOutsideDeclaredSeal) {
        try frontier.recordInput(
            MultiplayerSealedInput(
                id: MultiplayerInputID(seat: 1, inputSequence: 1),
                cell: 4,
                inputAt: 150
            )
        )
    }
}

@Test("A seat leaves the minimum frontier only after canonical elimination")
func multiplayerFastCanonicalSeatRemoval() throws {
    var frontier = try MultiplayerInputFrontier(seats: [0, 1])
    try frontier.recordSeal(
        MultiplayerInputSeal(seat: 0, throughInputAt: 200, highestInputSequence: 0)
    )
    try frontier.recordSeal(
        MultiplayerInputSeal(seat: 1, throughInputAt: 100, highestInputSequence: 0)
    )
    #expect(frontier.publishWatermark == 100)
    try frontier.removeSeatAfterPlayerOut(1)
    #expect(frontier.publishWatermark == 200)
}

@Test("Late evidence from an eliminated seat is retained without reopening the frontier")
func multiplayerFastInactiveSeatEvidence() throws {
    var frontier = try MultiplayerInputFrontier(seats: [0, 1])
    try frontier.recordSeal(
        MultiplayerInputSeal(seat: 0, throughInputAt: 200, highestInputSequence: 0)
    )
    try frontier.recordSeal(
        MultiplayerInputSeal(seat: 1, throughInputAt: 100, highestInputSequence: 0)
    )
    try frontier.removeSeatAfterPlayerOut(1)

    let late = MultiplayerSealedInput(
        id: MultiplayerInputID(seat: 1, inputSequence: 1),
        cell: 4,
        inputAt: 150
    )
    #expect(try frontier.recordInput(late) == .inserted)
    try frontier.recordSeal(
        MultiplayerInputSeal(seat: 1, throughInputAt: 200, highestInputSequence: 1)
    )

    #expect(frontier.publishWatermark == 200)
    #expect(frontier.takeReadyInputs().isEmpty)
}

@Test("Network policy freezes the one-second notice and fifteen-second recovery windows")
func multiplayerFastNetworkBudgets() throws {
    #expect(
        try MultiplayerFrozenNetworkPolicy.negotiate(
            [.init(p95RoundTripMilliseconds: 10, p95JitterMilliseconds: 2)]
        )
            == .init(
                frontierStalenessMilliseconds: 1_000,
                evidenceRecoveryMilliseconds: 15_000
            )
    )
    #expect(
        try MultiplayerFrozenNetworkPolicy.negotiate(
            [.init(p95RoundTripMilliseconds: 60, p95JitterMilliseconds: 15)]
        )
            == .init(
                frontierStalenessMilliseconds: 1_000,
                evidenceRecoveryMilliseconds: 15_000
            )
    )
    #expect(
        try MultiplayerFrozenNetworkPolicy.negotiate(
            [
                .init(p95RoundTripMilliseconds: 10, p95JitterMilliseconds: 2),
                .init(
                    p95RoundTripMilliseconds: 100,
                    p95JitterMilliseconds: 25,
                    lossPercent: 3,
                    reorderPercent: 3
                ),
            ]
        )
            == .init(
                frontierStalenessMilliseconds: 1_000,
                evidenceRecoveryMilliseconds: 15_000
            )
    )
}

@Test("Clock delay, loss, and reordering remain diagnostics instead of blocking startup")
func multiplayerClockDiagnosticsDoNotRejectStartup() throws {
    #expect(
        try MultiplayerFrozenNetworkPolicy.negotiate(
            [
                .init(
                    p95RoundTripMilliseconds: 800,
                    p95JitterMilliseconds: 300,
                    lossPercent: 34,
                    reorderPercent: 25
                )
            ]
        )
            == .init(
                frontierStalenessMilliseconds: 1_000,
                evidenceRecoveryMilliseconds: 15_000
            )
    )
}

@Test("Network policy proposal includes measured loss and reordering")
func multiplayerFastNetworkPolicyIncludesMeasuredLossAndReorder() throws {
    var supported = try MultiplayerNetworkPolicyConsensus(
        seats: [0, 1],
        coordinatorSeat: 0
    )
    try supported.recordMeasurement(
        MultiplayerSeatNetworkMeasurement(
            seat: 1,
            attemptedSampleCount: 100,
            completedSampleCount: 97,
            reorderedSampleCount: 2,
            p95RoundTripMilliseconds: 60,
            p95RoundTripVariationMilliseconds: 15
        ),
        from: 1
    )
    #expect(
        supported.proposal?.policy
            == MultiplayerFrozenNetworkPolicy(
                frontierStalenessMilliseconds: 1_000,
                evidenceRecoveryMilliseconds: 15_000
            )
    )

    var lossy = try MultiplayerNetworkPolicyConsensus(
        seats: [0, 1],
        coordinatorSeat: 0
    )
    try lossy.recordMeasurement(
        MultiplayerSeatNetworkMeasurement(
            seat: 1,
            attemptedSampleCount: 5,
            completedSampleCount: 4,
            reorderedSampleCount: 1,
            p95RoundTripMilliseconds: 60,
            p95RoundTripVariationMilliseconds: 15
        ),
        from: 1
    )
    #expect(lossy.proposal?.measurements.first?.lossPercent == 20)
    #expect(lossy.proposal?.measurements.first?.reorderPercent == 25)
    #expect(
        lossy.proposal?.policy
            == MultiplayerFrozenNetworkPolicy(
                frontierStalenessMilliseconds: 1_000,
                evidenceRecoveryMilliseconds: 15_000
            )
    )
}

@Test("Network policy freezes only after every seat votes for measured worst-peer data")
func multiplayerFastNetworkPolicyConsensus() throws {
    let measurements = [
        MultiplayerSeatNetworkMeasurement(
            seat: 1,
            attemptedSampleCount: 4,
            completedSampleCount: 4,
            reorderedSampleCount: 0,
            p95RoundTripMilliseconds: 10,
            p95RoundTripVariationMilliseconds: 2
        ),
        MultiplayerSeatNetworkMeasurement(
            seat: 2,
            attemptedSampleCount: 5,
            completedSampleCount: 5,
            reorderedSampleCount: 0,
            p95RoundTripMilliseconds: 60,
            p95RoundTripVariationMilliseconds: 15
        ),
        MultiplayerSeatNetworkMeasurement(
            seat: 3,
            attemptedSampleCount: 4,
            completedSampleCount: 4,
            reorderedSampleCount: 0,
            p95RoundTripMilliseconds: 40,
            p95RoundTripVariationMilliseconds: 8
        ),
    ]
    let proposal = MultiplayerNetworkPolicyProposal(
        measurements: measurements,
        policy: MultiplayerFrozenNetworkPolicy(
            frontierStalenessMilliseconds: 1_000,
            evidenceRecoveryMilliseconds: 15_000
        )
    )
    var consensus = try MultiplayerNetworkPolicyConsensus(
        seats: [0, 1, 2, 3],
        coordinatorSeat: 0
    )

    try consensus.recordVote(
        MultiplayerNetworkPolicyVote(seat: 3, proposal: proposal),
        from: 3
    )
    try consensus.recordMeasurement(measurements[2], from: 3)
    try consensus.recordMeasurement(measurements[0], from: 1)
    try consensus.recordMeasurement(measurements[1], from: 2)
    #expect(consensus.proposal == proposal)
    #expect(consensus.frozenProposal == nil)

    for seat in [0, 1, 2] {
        try consensus.recordVote(
            MultiplayerNetworkPolicyVote(seat: seat, proposal: proposal),
            from: seat
        )
    }
    #expect(consensus.frozenProposal == proposal)
}

@Test("Network policy rejects insufficient, conflicting, and malformed measurements")
func multiplayerFastNetworkPolicyRejectsBadEvidence() throws {
    var consensus = try MultiplayerNetworkPolicyConsensus(
        seats: [0, 1],
        coordinatorSeat: 0
    )
    #expect(throws: MultiplayerFastPolicyError.invalidNetworkMeasurement) {
        try consensus.recordMeasurement(
            MultiplayerSeatNetworkMeasurement(
                seat: 1,
                attemptedSampleCount: 4,
                completedSampleCount: 3,
                reorderedSampleCount: 0,
                p95RoundTripMilliseconds: 60,
                p95RoundTripVariationMilliseconds: 15
            ),
            from: 1
        )
    }
    #expect(throws: MultiplayerFastPolicyError.invalidNetworkMeasurement) {
        try consensus.recordMeasurement(
            MultiplayerSeatNetworkMeasurement(
                seat: 1,
                attemptedSampleCount: 4,
                completedSampleCount: 4,
                reorderedSampleCount: 0,
                p95RoundTripMilliseconds: -1,
                p95RoundTripVariationMilliseconds: 30
            ),
            from: 1
        )
    }
}

@Test("Live-only input resolutions round-trip without changing transcript events")
func multiplayerFastResolutionRoundTrip() throws {
    let values = [
        MultiplayerInputResolution(
            inputID: MultiplayerInputID(seat: 0, inputSequence: 1),
            disposition: .committed(eventSequence: 3)
        ),
        MultiplayerInputResolution(
            inputID: MultiplayerInputID(seat: 1, inputSequence: 2),
            disposition: .ignored(.recovery)
        ),
    ]
    let data = try JSONEncoder().encode(values)
    #expect(try JSONDecoder().decode([MultiplayerInputResolution].self, from: data) == values)
    #expect(values.allSatisfy { $0.version == 1 })
}
