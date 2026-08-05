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
    #expect(throws: MultiplayerFastPolicyError.regressingSeal) {
        try frontier.recordSeal(
            MultiplayerInputSeal(seat: 1, throughInputAt: 99, highestInputSequence: 0)
        )
    }
    try frontier.recordSeal(
        MultiplayerInputSeal(seat: 1, throughInputAt: 150, highestInputSequence: 0)
    )
    #expect(frontier.publishWatermark == 150)
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

@Test("Network policy freezes the clean, normal, and edge budgets")
func multiplayerFastNetworkBudgets() throws {
    #expect(
        try MultiplayerFrozenNetworkPolicy.negotiate(
            [.init(p95RoundTripMilliseconds: 10, p95JitterMilliseconds: 2)]
        )
            == .init(frontierStalenessMilliseconds: 40, evidenceRecoveryMilliseconds: 120)
    )
    #expect(
        try MultiplayerFrozenNetworkPolicy.negotiate(
            [.init(p95RoundTripMilliseconds: 60, p95JitterMilliseconds: 15)]
        )
            == .init(frontierStalenessMilliseconds: 62, evidenceRecoveryMilliseconds: 150)
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
            == .init(frontierStalenessMilliseconds: 92, evidenceRecoveryMilliseconds: 250)
    )
}

@Test("Unsupported network requirements are rejected rather than silently clamped")
func multiplayerFastUnsupportedNetwork() {
    #expect(throws: MultiplayerFastPolicyError.unsupportedNetwork) {
        try MultiplayerFrozenNetworkPolicy.negotiate(
            [.init(p95RoundTripMilliseconds: 120, p95JitterMilliseconds: 30)]
        )
    }
    #expect(throws: MultiplayerFastPolicyError.unsupportedNetwork) {
        try MultiplayerFrozenNetworkPolicy.negotiate(
            [
                .init(
                    p95RoundTripMilliseconds: 60,
                    p95JitterMilliseconds: 15,
                    lossPercent: 4,
                    reorderPercent: 1
                )
            ]
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
