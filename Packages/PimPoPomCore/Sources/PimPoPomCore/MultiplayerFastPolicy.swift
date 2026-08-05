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
        guard var state = states[input.id.seat], state.isActive else {
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
        guard var state = states[seal.seat], state.isActive else {
            throw MultiplayerFastPolicyError.unknownSeat(seal.seat)
        }
        guard seal.throughInputAt >= 0,
            seal.throughInputAt <= MultiplayerProtocolConstants.maximumDurationMilliseconds,
            seal.highestInputSequence >= 0,
            seal.highestInputSequence <= MultiplayerProtocolConstants.maximumEvents
        else {
            throw MultiplayerFastPolicyError.invalidSeal
        }
        if let previous = state.lastDeclaredSeal {
            if seal == previous { return }
            guard seal.throughInputAt >= previous.throughInputAt,
                seal.highestInputSequence >= previous.highestInputSequence
            else {
                throw MultiplayerFastPolicyError.regressingSeal
            }
        }
        if let effective = state.effectiveSeal {
            guard seal.throughInputAt >= effective.throughInputAt,
                seal.highestInputSequence >= effective.highestInputSequence
            else {
                throw MultiplayerFastPolicyError.regressingSeal
            }
        }

        let previousBoundary = state.lastDeclaredSeal ?? state.effectiveSeal
        if let previousBoundary,
            seal.highestInputSequence > previousBoundary.highestInputSequence
        {
            for sequence
                in (previousBoundary.highestInputSequence + 1)...seal
                .highestInputSequence
            {
                if let input = state.inputs[sequence],
                    input.inputAt <= previousBoundary.throughInputAt
                {
                    throw MultiplayerFastPolicyError.inputAtOrBeforeEffectiveSeal
                }
            }
        }
        if seal.highestInputSequence > 0 {
            for sequence in 1...seal.highestInputSequence {
                if let input = state.inputs[sequence], input.inputAt > seal.throughInputAt {
                    throw MultiplayerFastPolicyError.inputOutsideDeclaredSeal
                }
            }
        }

        state.lastDeclaredSeal = seal
        state.pendingSeals.append(seal)
        try Self.advanceEffectiveSeal(&state)
        states[seal.seat] = state
    }

    public mutating func takeReadyInputs() -> [MultiplayerSealedInput] {
        guard let watermark = publishWatermark else { return [] }
        var ready: [MultiplayerSealedInput] = []
        for seat in states.keys.sorted() {
            guard var state = states[seat] else { continue }
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
        let roundTrip = qualities.map(\.p95RoundTripMilliseconds).max() ?? 0
        let jitter = qualities.map(\.p95JitterMilliseconds).max() ?? 0
        let loss = qualities.map(\.lossPercent).max() ?? 0
        let reorder = qualities.map(\.reorderPercent).max() ?? 0
        let rawStaleness = (roundTrip + 1) / 2 + jitter + 17
        let rawRecovery = 2 * roundTrip + 2 * jitter
        guard rawStaleness <= 100,
            rawRecovery <= 250,
            loss <= 3,
            reorder <= 3
        else {
            throw MultiplayerFastPolicyError.unsupportedNetwork
        }
        return MultiplayerFrozenNetworkPolicy(
            frontierStalenessMilliseconds: min(100, max(40, rawStaleness)),
            evidenceRecoveryMilliseconds: min(250, max(120, rawRecovery))
        )
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
