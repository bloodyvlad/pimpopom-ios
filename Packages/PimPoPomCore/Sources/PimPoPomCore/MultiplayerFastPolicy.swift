import Foundation

public struct MultiplayerInputID: Codable, Hashable, Sendable {
    public let seat: Int
    public let inputSequence: Int

    public init(seat: Int, inputSequence: Int) {
        self.seat = seat
        self.inputSequence = inputSequence
    }
}

public struct MultiplayerSealedInput: Codable, Hashable, Sendable {
    public let id: MultiplayerInputID
    public let cell: Int
    public let inputAt: Int

    public init(id: MultiplayerInputID, cell: Int, inputAt: Int) {
        self.id = id
        self.cell = cell
        self.inputAt = inputAt
    }
}

public struct MultiplayerInputSeal: Codable, Hashable, Sendable {
    public let seat: Int
    public let throughInputAt: Int
    public let highestInputSequence: Int

    public init(seat: Int, throughInputAt: Int, highestInputSequence: Int) {
        self.seat = seat
        self.throughInputAt = throughInputAt
        self.highestInputSequence = highestInputSequence
    }
}

public enum MultiplayerInputRecordResult: Equatable, Sendable {
    case inserted
    case duplicate
}

public enum MultiplayerFastPolicyError: Error, Equatable, Sendable {
    case invalidSeats
    case invalidInput
    case invalidSeal
    case unknownSeat(Int)
    case conflictingInput(MultiplayerInputID)
    case nonMonotonicInputTime
    case regressingSeal
    case inputOutsideDeclaredSeal
    case inputAtOrBeforeEffectiveSeal
    case unsupportedNetwork
    case invalidNetworkMeasurement
    case conflictingNetworkMeasurement(Int)
    case invalidNetworkVote
    case conflictingNetworkVote(Int)
}

public struct MultiplayerInputFrontier: Sendable {
    private struct SeatState: Sendable {
        var isActive = true
        var inputs: [Int: MultiplayerSealedInput] = [:]
        var processedSequences: Set<Int> = []
        var pendingSeals: [MultiplayerInputSeal] = []
        var lastDeclaredSeal: MultiplayerInputSeal?
        var effectiveSeal: MultiplayerInputSeal?
    }

    private var states: [Int: SeatState]

    public init(seats: [Int]) throws {
        let uniqueSeats = Set(seats)
        guard
            (MultiplayerProtocolConstants
                .minimumPlayers...MultiplayerProtocolConstants
                .maximumPlayers).contains(seats.count),
            uniqueSeats.count == seats.count,
            uniqueSeats == Set(0..<seats.count)
        else {
            throw MultiplayerFastPolicyError.invalidSeats
        }
        states = Dictionary(uniqueKeysWithValues: seats.map { ($0, SeatState()) })
    }

    public var activeSeats: [Int] {
        states.compactMap { $0.value.isActive ? $0.key : nil }.sorted()
    }

    public var publishWatermark: Int? {
        let active = states.values.filter(\.isActive)
        guard !active.isEmpty,
            active.allSatisfy({ $0.effectiveSeal != nil })
        else { return nil }
        return active.compactMap(\.effectiveSeal?.throughInputAt).min()
    }

    public var missingInputIDs: [MultiplayerInputID] {
        var result: [MultiplayerInputID] = []
        for (seat, state) in states.sorted(by: { $0.key < $1.key }) {
            guard state.isActive,
                let highest = state.lastDeclaredSeal?.highestInputSequence,
                highest > 0
            else { continue }
            for sequence in 1...highest where state.inputs[sequence] == nil {
                result.append(
                    MultiplayerInputID(seat: seat, inputSequence: sequence)
                )
            }
        }
        return result
    }

    public func effectiveSeal(for seat: Int) -> MultiplayerInputSeal? {
        states[seat]?.effectiveSeal
    }

    @discardableResult
    public mutating func recordInput(
        _ input: MultiplayerSealedInput
    ) throws -> MultiplayerInputRecordResult {
        guard var state = states[input.id.seat] else {
            throw MultiplayerFastPolicyError.unknownSeat(input.id.seat)
        }
        guard input.id.inputSequence > 0,
            input.id.inputSequence <= MultiplayerProtocolConstants.maximumEvents,
            (0..<MultiplayerProtocolConstants.boardCellCount).contains(input.cell),
            input.inputAt >= 0,
            input.inputAt <= MultiplayerProtocolConstants.maximumDurationMilliseconds
        else {
            throw MultiplayerFastPolicyError.invalidInput
        }
        if let existing = state.inputs[input.id.inputSequence] {
            guard existing == input else {
                throw MultiplayerFastPolicyError.conflictingInput(input.id)
            }
            return .duplicate
        }
        if let effective = state.effectiveSeal,
            input.id.inputSequence > effective.highestInputSequence,
            input.inputAt <= effective.throughInputAt
        {
            throw MultiplayerFastPolicyError.inputAtOrBeforeEffectiveSeal
        }
        if let upperBoundary = state.pendingSeals.first(where: {
            $0.highestInputSequence >= input.id.inputSequence
        }), input.inputAt > upperBoundary.throughInputAt {
            throw MultiplayerFastPolicyError.inputOutsideDeclaredSeal
        }
        if let lowerBoundary = state.pendingSeals.last(where: {
            $0.highestInputSequence < input.id.inputSequence
        }), input.inputAt <= lowerBoundary.throughInputAt {
            throw MultiplayerFastPolicyError.inputAtOrBeforeEffectiveSeal
        }
        if let previous = state.inputs[input.id.inputSequence - 1],
            input.inputAt < previous.inputAt
        {
            throw MultiplayerFastPolicyError.nonMonotonicInputTime
        }
        if let next = state.inputs[input.id.inputSequence + 1],
            input.inputAt > next.inputAt
        {
            throw MultiplayerFastPolicyError.nonMonotonicInputTime
        }

        state.inputs[input.id.inputSequence] = input
        try Self.advanceEffectiveSeal(&state)
        states[input.id.seat] = state
        return .inserted
    }

    public mutating func recordSeal(_ seal: MultiplayerInputSeal) throws {
        guard var state = states[seal.seat] else {
            throw MultiplayerFastPolicyError.unknownSeat(seal.seat)
        }
        guard seal.throughInputAt >= 0,
            seal.throughInputAt <= MultiplayerProtocolConstants.maximumDurationMilliseconds,
            seal.highestInputSequence >= 0,
            seal.highestInputSequence <= MultiplayerProtocolConstants.maximumEvents
        else {
            throw MultiplayerFastPolicyError.invalidSeal
        }
        let declaredSeals = [state.effectiveSeal].compactMap { $0 } + state.pendingSeals
        if declaredSeals.contains(seal) { return }
        guard
            declaredSeals.allSatisfy({ existing in
                Self.dominates(seal, existing) || Self.dominates(existing, seal)
            })
        else {
            throw MultiplayerFastPolicyError.regressingSeal
        }
        for (sequence, input) in state.inputs {
            if sequence <= seal.highestInputSequence,
                input.inputAt > seal.throughInputAt
            {
                throw MultiplayerFastPolicyError.inputOutsideDeclaredSeal
            }
            if sequence > seal.highestInputSequence,
                input.inputAt <= seal.throughInputAt
            {
                throw MultiplayerFastPolicyError.inputAtOrBeforeEffectiveSeal
            }
        }
        if let effective = state.effectiveSeal,
            Self.dominates(effective, seal)
        {
            return
        }

        state.pendingSeals.append(seal)
        state.pendingSeals.sort {
            if $0.throughInputAt != $1.throughInputAt {
                return $0.throughInputAt < $1.throughInputAt
            }
            return $0.highestInputSequence < $1.highestInputSequence
        }
        state.lastDeclaredSeal = state.pendingSeals.last ?? state.effectiveSeal
        try Self.advanceEffectiveSeal(&state)
        states[seal.seat] = state
    }

    public mutating func takeReadyInputs() -> [MultiplayerSealedInput] {
        guard let watermark = publishWatermark else { return [] }
        var ready: [MultiplayerSealedInput] = []
        for seat in states.keys.sorted() {
            guard var state = states[seat], state.isActive else { continue }
            let newInputs = state.inputs.values.filter {
                $0.inputAt <= watermark
                    && !state.processedSequences.contains($0.id.inputSequence)
            }
            ready.append(contentsOf: newInputs)
            state.processedSequences.formUnion(newInputs.map(\.id.inputSequence))
            states[seat] = state
        }
        return ready.sorted {
            if $0.inputAt != $1.inputAt { return $0.inputAt < $1.inputAt }
            if $0.id.seat != $1.id.seat { return $0.id.seat < $1.id.seat }
            return $0.id.inputSequence < $1.id.inputSequence
        }
    }

    public mutating func removeSeatAfterPlayerOut(_ seat: Int) throws {
        guard var state = states[seat], state.isActive else {
            throw MultiplayerFastPolicyError.unknownSeat(seat)
        }
        state.isActive = false
        states[seat] = state
    }

    private static func advanceEffectiveSeal(_ state: inout SeatState) throws {
        while let seal = state.pendingSeals.first {
            let hasEveryInput =
                seal.highestInputSequence == 0
                || (1...seal.highestInputSequence).allSatisfy {
                    state.inputs[$0] != nil
                }
            guard hasEveryInput else { return }

            let previous = state.effectiveSeal
            let previousHighest = previous?.highestInputSequence ?? 0
            let previousThrough = previous?.throughInputAt ?? -1
            if seal.highestInputSequence > previousHighest {
                for sequence in (previousHighest + 1)...seal.highestInputSequence {
                    guard let input = state.inputs[sequence] else { return }
                    guard input.inputAt > previousThrough else {
                        throw MultiplayerFastPolicyError.inputAtOrBeforeEffectiveSeal
                    }
                    guard input.inputAt <= seal.throughInputAt else {
                        throw MultiplayerFastPolicyError.inputOutsideDeclaredSeal
                    }
                }
            }
            state.effectiveSeal = seal
            state.pendingSeals.removeFirst()
        }
    }

    private static func dominates(
        _ lhs: MultiplayerInputSeal,
        _ rhs: MultiplayerInputSeal
    ) -> Bool {
        lhs.throughInputAt >= rhs.throughInputAt
            && lhs.highestInputSequence >= rhs.highestInputSequence
    }
}

public struct MultiplayerNetworkQuality: Codable, Equatable, Sendable {
    public let p95RoundTripMilliseconds: Int
    public let p95JitterMilliseconds: Int
    public let lossPercent: Int
    public let reorderPercent: Int

    public init(
        p95RoundTripMilliseconds: Int,
        p95JitterMilliseconds: Int,
        lossPercent: Int = 0,
        reorderPercent: Int = 0
    ) {
        self.p95RoundTripMilliseconds = p95RoundTripMilliseconds
        self.p95JitterMilliseconds = p95JitterMilliseconds
        self.lossPercent = lossPercent
        self.reorderPercent = reorderPercent
    }
}

public struct MultiplayerSeatNetworkMeasurement: Codable, Equatable, Sendable {
    public let seat: Int
    public let attemptedSampleCount: Int
    public let completedSampleCount: Int
    public let reorderedSampleCount: Int
    public let p95RoundTripMilliseconds: Int
    public let p95RoundTripVariationMilliseconds: Int

    public var lossPercent: Int {
        Self.roundedUpPercent(
            numerator: attemptedSampleCount - completedSampleCount,
            denominator: attemptedSampleCount
        )
    }

    public var reorderPercent: Int {
        Self.roundedUpPercent(
            numerator: reorderedSampleCount,
            denominator: completedSampleCount
        )
    }

    public init(
        seat: Int,
        attemptedSampleCount: Int,
        completedSampleCount: Int,
        reorderedSampleCount: Int,
        p95RoundTripMilliseconds: Int,
        p95RoundTripVariationMilliseconds: Int
    ) {
        self.seat = seat
        self.attemptedSampleCount = attemptedSampleCount
        self.completedSampleCount = completedSampleCount
        self.reorderedSampleCount = reorderedSampleCount
        self.p95RoundTripMilliseconds = p95RoundTripMilliseconds
        self.p95RoundTripVariationMilliseconds = p95RoundTripVariationMilliseconds
    }

    private static func roundedUpPercent(numerator: Int, denominator: Int) -> Int {
        guard numerator > 0, denominator > 0 else { return 0 }
        return (numerator * 100 + denominator - 1) / denominator
    }
}

public struct MultiplayerNetworkPolicyProposal: Codable, Equatable, Sendable {
    public let measurements: [MultiplayerSeatNetworkMeasurement]
    public let policy: MultiplayerFrozenNetworkPolicy

    public init(
        measurements: [MultiplayerSeatNetworkMeasurement],
        policy: MultiplayerFrozenNetworkPolicy
    ) {
        self.measurements = measurements.sorted { $0.seat < $1.seat }
        self.policy = policy
    }
}

public struct MultiplayerNetworkPolicyVote: Codable, Equatable, Sendable {
    public let seat: Int
    public let proposal: MultiplayerNetworkPolicyProposal

    public init(seat: Int, proposal: MultiplayerNetworkPolicyProposal) {
        self.seat = seat
        self.proposal = proposal
    }
}

public struct MultiplayerFrozenNetworkPolicy: Codable, Equatable, Sendable {
    public let frontierStalenessMilliseconds: Int
    public let evidenceRecoveryMilliseconds: Int

    public init(
        frontierStalenessMilliseconds: Int,
        evidenceRecoveryMilliseconds: Int
    ) {
        self.frontierStalenessMilliseconds = frontierStalenessMilliseconds
        self.evidenceRecoveryMilliseconds = evidenceRecoveryMilliseconds
    }

    public static func negotiate(
        _ qualities: [MultiplayerNetworkQuality]
    ) throws -> MultiplayerFrozenNetworkPolicy {
        guard !qualities.isEmpty,
            qualities.allSatisfy({
                $0.p95RoundTripMilliseconds >= 0
                    && $0.p95JitterMilliseconds >= 0
                    && $0.lossPercent >= 0
                    && $0.reorderPercent >= 0
            })
        else {
            throw MultiplayerFastPolicyError.unsupportedNetwork
        }
        return MultiplayerFrozenNetworkPolicy(
            frontierStalenessMilliseconds: 1_000,
            evidenceRecoveryMilliseconds: 15_000
        )
    }
}

public struct MultiplayerNetworkPolicyConsensus: Sendable {
    private let seats: Set<Int>
    private let coordinatorSeat: Int
    private var measurements: [Int: MultiplayerSeatNetworkMeasurement] = [:]
    private var votes: [Int: MultiplayerNetworkPolicyVote] = [:]

    public init(seats: [Int], coordinatorSeat: Int) throws {
        let uniqueSeats = Set(seats)
        guard
            (MultiplayerProtocolConstants
                .minimumPlayers...MultiplayerProtocolConstants
                .maximumPlayers).contains(seats.count),
            uniqueSeats.count == seats.count,
            uniqueSeats == Set(0..<seats.count),
            uniqueSeats.contains(coordinatorSeat)
        else {
            throw MultiplayerFastPolicyError.invalidSeats
        }
        self.seats = uniqueSeats
        self.coordinatorSeat = coordinatorSeat
    }

    public var proposal: MultiplayerNetworkPolicyProposal? {
        try? makeProposal(measurements)
    }

    public var frozenProposal: MultiplayerNetworkPolicyProposal? {
        guard let proposal,
            Set(votes.keys) == seats,
            votes.values.allSatisfy({ $0.proposal == proposal })
        else { return nil }
        return proposal
    }

    public mutating func recordMeasurement(
        _ measurement: MultiplayerSeatNetworkMeasurement,
        from seat: Int
    ) throws {
        guard seat == measurement.seat,
            seats.contains(seat),
            seat != coordinatorSeat,
            measurement.attemptedSampleCount >= 4,
            measurement.completedSampleCount >= 4,
            measurement.completedSampleCount <= measurement.attemptedSampleCount,
            measurement.reorderedSampleCount >= 0,
            measurement.reorderedSampleCount <= measurement.completedSampleCount,
            measurement.p95RoundTripMilliseconds >= 0,
            measurement.p95RoundTripVariationMilliseconds >= 0
        else {
            throw MultiplayerFastPolicyError.invalidNetworkMeasurement
        }
        if let existing = measurements[seat] {
            guard existing == measurement else {
                throw MultiplayerFastPolicyError.conflictingNetworkMeasurement(seat)
            }
            return
        }
        var candidate = measurements
        candidate[seat] = measurement
        if Set(candidate.keys) == seats.subtracting([coordinatorSeat]) {
            _ = try makeProposal(candidate)
        }
        measurements = candidate
        try validateVotesAgainstProposalIfComplete()
    }

    public mutating func recordVote(
        _ vote: MultiplayerNetworkPolicyVote,
        from seat: Int
    ) throws {
        guard seat == vote.seat, seats.contains(seat) else {
            throw MultiplayerFastPolicyError.invalidNetworkVote
        }
        if let existing = votes[seat] {
            guard existing == vote else {
                throw MultiplayerFastPolicyError.conflictingNetworkVote(seat)
            }
            return
        }
        votes[seat] = vote
        do {
            try validateVotesAgainstProposalIfComplete()
        } catch {
            votes.removeValue(forKey: seat)
            throw error
        }
    }

    private func makeProposal(
        _ measurements: [Int: MultiplayerSeatNetworkMeasurement]
    ) throws -> MultiplayerNetworkPolicyProposal {
        let expectedSeats = seats.subtracting([coordinatorSeat])
        guard Set(measurements.keys) == expectedSeats else {
            throw MultiplayerFastPolicyError.invalidNetworkMeasurement
        }
        let sorted = measurements.values.sorted { $0.seat < $1.seat }
        let policy = try MultiplayerFrozenNetworkPolicy.negotiate(
            sorted.map {
                MultiplayerNetworkQuality(
                    p95RoundTripMilliseconds: $0.p95RoundTripMilliseconds,
                    p95JitterMilliseconds:
                        $0.p95RoundTripVariationMilliseconds,
                    lossPercent: $0.lossPercent,
                    reorderPercent: $0.reorderPercent
                )
            }
        )
        return MultiplayerNetworkPolicyProposal(
            measurements: sorted,
            policy: policy
        )
    }

    private func validateVotesAgainstProposalIfComplete() throws {
        guard let proposal else { return }
        guard votes.values.allSatisfy({ $0.proposal == proposal }) else {
            let seat = votes.first(where: { $0.value.proposal != proposal })?.key ?? -1
            throw MultiplayerFastPolicyError.conflictingNetworkVote(seat)
        }
    }
}

public enum MultiplayerIgnoredInputReason: String, Codable, Equatable, Sendable {
    case duplicate
    case recovery
    case alreadyResolved
    case prePresentation
    case staleTarget
    case eliminated
    case finished
}

public enum MultiplayerInputDisposition: Codable, Equatable, Sendable {
    case committed(eventSequence: Int)
    case ignored(MultiplayerIgnoredInputReason)
}

public struct MultiplayerInputResolution: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    public let inputID: MultiplayerInputID
    public let disposition: MultiplayerInputDisposition

    public init(
        version: Int = currentVersion,
        inputID: MultiplayerInputID,
        disposition: MultiplayerInputDisposition
    ) {
        self.version = version
        self.inputID = inputID
        self.disposition = disposition
    }
}
