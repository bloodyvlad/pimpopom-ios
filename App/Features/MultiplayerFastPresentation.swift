import CoreGraphics
import PimPoPomCore

enum MultiplayerHitFeedbackPresentation {
    static func make(
        event: MultiplayerEvent,
        targetPresentedAt: Int,
        localSeat: Int,
        scoreBefore: Int,
        scoreAfter: Int,
        normalizedLocation: CGPoint
    ) -> GameplayHitFeedbackEvent? {
        guard
            case .hit(
                let sequence,
                let inputAt,
                _,
                let seat,
                _,
                let cell
            ) = event,
            seat == localSeat,
            scoreAfter >= scoreBefore,
            (0..<MultiplayerProtocolConstants.boardCellCount).contains(cell),
            normalizedLocation.x.isFinite,
            normalizedLocation.y.isFinite
        else {
            return nil
        }
        let classified = SpeedRating.classify(
            reactionMilliseconds: Double(max(0, inputAt - targetPresentedAt))
        )
        return GameplayHitFeedbackEvent(
            id: sequence,
            rating: classified.rating,
            milliseconds: classified.displayedMilliseconds,
            pointsAwarded: scoreAfter - scoreBefore,
            normalizedLocation: CGPoint(
                x: min(1, max(0, normalizedLocation.x)),
                y: min(1, max(0, normalizedLocation.y))
            )
        )
    }
}

enum MultiplayerPresentedActivationKind: String, Codable, Equatable, Sendable {
    case target
    case decoy
}

struct MultiplayerPresentedActivationID: Codable, Equatable, Hashable, Sendable {
    let kind: MultiplayerPresentedActivationKind
    let entityID: Int
}

enum MultiplayerLocalPredictionOverlay: Equatable, Sendable {
    case consumedTarget(cell: Int)
    case neutralPressure(cell: Int)
}

struct MultiplayerPendingLocalInput: Equatable, Sendable {
    let inputID: MultiplayerInputID
    let activationID: MultiplayerPresentedActivationID
    let tappedCell: Int
    let inputAt: Int
    let overlay: MultiplayerLocalPredictionOverlay
    var committedEventSequence: Int?
}

enum MultiplayerLocalInputCapture: Equatable, Sendable {
    case accepted(MultiplayerInputID)
    case blocked(MultiplayerInputID)
}

enum MultiplayerLocalReconciliation: Equatable, Sendable {
    case agreement
    case corrected
    case unchanged
}

struct MultiplayerLocalInputPrediction: Equatable, Sendable {
    private(set) var nextInputSequence = 1
    private(set) var pendingInput: MultiplayerPendingLocalInput?

    var overlay: MultiplayerLocalPredictionOverlay? {
        pendingInput?.overlay
    }

    var hiddenTargetCell: Int? {
        guard case .consumedTarget(let cell) = overlay else { return nil }
        return cell
    }

    var allowsInput: Bool { pendingInput == nil }

    mutating func begin(
        seat: Int,
        activationID: MultiplayerPresentedActivationID,
        tappedCell: Int,
        ownedTargetCell: Int?,
        inputAt: Int
    ) -> MultiplayerLocalInputCapture {
        if let pendingInput {
            return .blocked(pendingInput.inputID)
        }
        let inputID = MultiplayerInputID(
            seat: seat,
            inputSequence: nextInputSequence
        )
        nextInputSequence += 1
        let overlay: MultiplayerLocalPredictionOverlay =
            tappedCell == ownedTargetCell
            ? .consumedTarget(cell: tappedCell)
            : .neutralPressure(cell: tappedCell)
        pendingInput = MultiplayerPendingLocalInput(
            inputID: inputID,
            activationID: activationID,
            tappedCell: tappedCell,
            inputAt: inputAt,
            overlay: overlay,
            committedEventSequence: nil
        )
        return .accepted(inputID)
    }

    mutating func receive(
        _ resolution: MultiplayerInputResolution
    ) -> MultiplayerLocalReconciliation {
        guard var pendingInput,
            pendingInput.inputID == resolution.inputID
        else { return .unchanged }
        switch resolution.disposition {
        case .committed(let eventSequence):
            if pendingInput.committedEventSequence == eventSequence {
                return .unchanged
            }
            pendingInput.committedEventSequence = eventSequence
            self.pendingInput = pendingInput
            return .agreement
        case .ignored:
            self.pendingInput = nil
            return .corrected
        }
    }

    mutating func canonicalApplied(eventSequence: Int) -> Bool {
        guard pendingInput?.committedEventSequence == eventSequence else {
            return false
        }
        pendingInput = nil
        return true
    }

    mutating func snapshotProvedActivationEnded(
        _ activeActivationID: MultiplayerPresentedActivationID?
    ) -> Bool {
        guard let pendingInput else { return false }
        guard pendingInput.activationID != activeActivationID else { return false }
        self.pendingInput = nil
        return true
    }

    mutating func reset() {
        nextInputSequence = 1
        pendingInput = nil
    }
}

struct MultiplayerLocalLatencyCorrelation: Equatable, Sendable {
    private var sampleByInputID: [MultiplayerInputID: MultiplayerLatencySampleID] = [:]
    private var pendingAcknowledgement: MultiplayerLatencySampleID?

    mutating func arm(
        inputID: MultiplayerInputID,
        sampleID: MultiplayerLatencySampleID
    ) {
        sampleByInputID[inputID] = sampleID
        pendingAcknowledgement = sampleID
    }

    mutating func takeAcknowledgement(
        on frame: MultiplayerDisplayFrame
    ) -> (MultiplayerLatencySampleID, MultiplayerDisplayFrame)? {
        guard let sampleID = pendingAcknowledgement else { return nil }
        pendingAcknowledgement = nil
        return (sampleID, frame)
    }

    func sampleID(for inputID: MultiplayerInputID) -> MultiplayerLatencySampleID? {
        sampleByInputID[inputID]
    }

    mutating func finish(inputID: MultiplayerInputID) {
        sampleByInputID.removeValue(forKey: inputID)
    }

    mutating func reset() {
        sampleByInputID = [:]
        pendingAcknowledgement = nil
    }
}

enum MultiplayerResolutionWatchdogAction: Equatable, Sendable {
    case none
    case requestSnapshot(MultiplayerInputID)
    case cancelWithoutSettlement(MultiplayerInputID)
}

struct MultiplayerResolutionWatchdog: Equatable, Sendable {
    private(set) var inputID: MultiplayerInputID?
    private var beganAtMonotonicMilliseconds: Int?
    private var requestedSnapshot = false

    var isSyncing: Bool { requestedSnapshot }

    mutating func begin(
        inputID: MultiplayerInputID,
        monotonicMilliseconds: Int
    ) {
        self.inputID = inputID
        beganAtMonotonicMilliseconds = monotonicMilliseconds
        requestedSnapshot = false
    }

    mutating func resolve(_ resolvedInputID: MultiplayerInputID) {
        guard inputID == resolvedInputID else { return }
        reset()
    }

    mutating func action(
        monotonicMilliseconds: Int,
        recoveryBudgetMilliseconds: Int
    ) -> MultiplayerResolutionWatchdogAction {
        guard let inputID, let beganAtMonotonicMilliseconds,
            recoveryBudgetMilliseconds > 0
        else { return .none }
        let elapsed = monotonicMilliseconds - beganAtMonotonicMilliseconds
        if elapsed >= recoveryBudgetMilliseconds * 2 {
            return .cancelWithoutSettlement(inputID)
        }
        if elapsed >= recoveryBudgetMilliseconds, !requestedSnapshot {
            requestedSnapshot = true
            return .requestSnapshot(inputID)
        }
        return .none
    }

    mutating func reset() {
        inputID = nil
        beganAtMonotonicMilliseconds = nil
        requestedSnapshot = false
    }
}

enum MultiplayerPresentationPublicationPolicy {
    static func shouldPublish(
        previous: MultiplayerPresentation.LiveMatchState?,
        next: MultiplayerPresentation.LiveMatchState
    ) -> Bool {
        guard let previous else { return true }
        return previous.matchID != next.matchID
            || previous.cells != next.cells
            || previous.players != next.players
            || previous.localSeat != next.localSeat
            || previous.streakSteps != next.streakSteps
            || previous.isRecovering != next.isRecovering
            || previous.announcement != next.announcement
            || previous.hitFeedbackEvent != next.hitFeedbackEvent
            || previous.inputMode != next.inputMode
    }
}

enum MultiplayerCoordinatorResolutionError: Error, Equatable {
    case missingCommittedInputEvent(MultiplayerInputID)
    case conflictingCommittedInputEvents(MultiplayerInputID)
}

enum MultiplayerCoordinatorResolutionPolicy {
    static func resolution(
        inputID: MultiplayerInputID,
        input: MultiplayerSealedInput,
        result: MultiplayerInputResult
    ) throws -> MultiplayerInputResolution {
        switch result.outcome {
        case .hit, .miss:
            let sequences = result.committedEvents.compactMap { event -> Int? in
                switch (result.outcome, event) {
                case (
                    .hit,
                    .hit(let sequence, let inputAt, _, let seat, _, let cell)
                )
                where seat == input.id.seat
                    && cell == input.cell
                    && inputAt == input.inputAt:
                    sequence
                case (
                    .miss,
                    .miss(let sequence, let inputAt, _, let seat, _, let cell)
                )
                where seat == input.id.seat
                    && cell == input.cell
                    && inputAt == input.inputAt:
                    sequence
                default:
                    nil
                }
            }
            guard let sequence = sequences.first else {
                throw
                    MultiplayerCoordinatorResolutionError
                    .missingCommittedInputEvent(inputID)
            }
            guard sequences.count == 1 else {
                throw
                    MultiplayerCoordinatorResolutionError
                    .conflictingCommittedInputEvents(inputID)
            }
            return MultiplayerInputResolution(
                inputID: inputID,
                disposition: .committed(eventSequence: sequence)
            )
        case .ignoredRecovery:
            return ignored(inputID, reason: .recovery)
        case .ignoredEliminated:
            return ignored(inputID, reason: .eliminated)
        case .ignoredFinished:
            return ignored(inputID, reason: .finished)
        case .ignoredExpired:
            return ignored(inputID, reason: .staleTarget)
        }
    }

    private static func ignored(
        _ inputID: MultiplayerInputID,
        reason: MultiplayerIgnoredInputReason
    ) -> MultiplayerInputResolution {
        MultiplayerInputResolution(
            inputID: inputID,
            disposition: .ignored(reason)
        )
    }
}

struct MultiplayerLocalSealEmission: Equatable, Sendable {
    let seal: MultiplayerInputSeal
    let includesReliableCheckpoint: Bool
}

struct MultiplayerLocalSealEmitter: Equatable, Sendable {
    private var lastThroughInputAt = -1
    private var lastReliableLogicalMilliseconds: Int?

    mutating func next(
        seat: Int,
        highestInputSequence: Int,
        logicalMilliseconds: Int
    ) -> MultiplayerLocalSealEmission? {
        guard logicalMilliseconds > 0 else { return nil }
        let throughInputAt = logicalMilliseconds - 1
        guard throughInputAt > lastThroughInputAt else { return nil }
        let includesReliableCheckpoint =
            lastReliableLogicalMilliseconds.map {
                logicalMilliseconds - $0 >= 100
            } ?? true
        lastThroughInputAt = throughInputAt
        if includesReliableCheckpoint {
            lastReliableLogicalMilliseconds = logicalMilliseconds
        }
        return MultiplayerLocalSealEmission(
            seal: MultiplayerInputSeal(
                seat: seat,
                throughInputAt: throughInputAt,
                highestInputSequence: highestInputSequence
            ),
            includesReliableCheckpoint: includesReliableCheckpoint
        )
    }

    mutating func reset() {
        lastThroughInputAt = -1
        lastReliableLogicalMilliseconds = nil
    }
}

enum MultiplayerTerminalDrainError: Error, Equatable, Sendable {
    case invalidSeats
    case unknownSeat(Int)
    case invalidEvidence(MultiplayerInputID)
    case conflictingEvidence(MultiplayerInputID)
    case invalidTerminalSeal(Int)
    case conflictingTerminalSeal(Int)
    case evidenceAfterTerminalSeal(MultiplayerInputID)
    case evidenceOutsideTerminalSeal(MultiplayerInputID)
}

struct MultiplayerTerminalDrainTracker: Equatable, Sendable {
    private let seats: Set<Int>
    private var evidence: [MultiplayerInputID: MultiplayerSealedInput] = [:]
    private var terminalSeals: [Int: MultiplayerInputSeal] = [:]

    init(seats: [Int]) throws {
        let uniqueSeats = Set(seats)
        guard
            (MultiplayerProtocolConstants
                .minimumPlayers...MultiplayerProtocolConstants
                .maximumPlayers).contains(seats.count),
            uniqueSeats.count == seats.count,
            uniqueSeats == Set(0..<seats.count)
        else {
            throw MultiplayerTerminalDrainError.invalidSeats
        }
        self.seats = uniqueSeats
    }

    var missingInputIDs: [MultiplayerInputID] {
        terminalSeals.values.sorted { $0.seat < $1.seat }.flatMap {
            seal -> [MultiplayerInputID] in
            guard seal.highestInputSequence > 0 else { return [] }
            return (1...seal.highestInputSequence).compactMap { sequence in
                let id = MultiplayerInputID(
                    seat: seal.seat,
                    inputSequence: sequence
                )
                return evidence[id] == nil ? id : nil
            }
        }
    }

    var isComplete: Bool {
        terminalSeals.count == seats.count && missingInputIDs.isEmpty
    }

    mutating func recordEvidence(_ input: MultiplayerSealedInput) throws {
        guard seats.contains(input.id.seat) else {
            throw MultiplayerTerminalDrainError.unknownSeat(input.id.seat)
        }
        guard input.id.inputSequence > 0,
            input.id.inputSequence <= MultiplayerProtocolConstants.maximumEvents,
            (0..<MultiplayerProtocolConstants.boardCellCount).contains(input.cell),
            (0...MultiplayerProtocolConstants.maximumDurationMilliseconds)
                .contains(input.inputAt)
        else {
            throw MultiplayerTerminalDrainError.invalidEvidence(input.id)
        }
        if let existing = evidence[input.id] {
            guard existing == input else {
                throw MultiplayerTerminalDrainError.conflictingEvidence(input.id)
            }
            return
        }
        if let seal = terminalSeals[input.id.seat] {
            guard input.id.inputSequence <= seal.highestInputSequence else {
                throw MultiplayerTerminalDrainError.evidenceAfterTerminalSeal(input.id)
            }
            guard input.inputAt <= seal.throughInputAt else {
                throw MultiplayerTerminalDrainError.evidenceOutsideTerminalSeal(input.id)
            }
        }
        evidence[input.id] = input
    }

    mutating func recordTerminalSeal(_ seal: MultiplayerInputSeal) throws {
        guard seats.contains(seal.seat) else {
            throw MultiplayerTerminalDrainError.unknownSeat(seal.seat)
        }
        guard seal.throughInputAt >= 0,
            seal.throughInputAt <= MultiplayerProtocolConstants.maximumDurationMilliseconds,
            seal.highestInputSequence >= 0,
            seal.highestInputSequence <= MultiplayerProtocolConstants.maximumEvents
        else {
            throw MultiplayerTerminalDrainError.invalidTerminalSeal(seal.seat)
        }
        if let existing = terminalSeals[seal.seat] {
            guard existing == seal else {
                throw MultiplayerTerminalDrainError.conflictingTerminalSeal(seal.seat)
            }
            return
        }
        for input in evidence.values where input.id.seat == seal.seat {
            guard input.id.inputSequence <= seal.highestInputSequence else {
                throw MultiplayerTerminalDrainError.evidenceAfterTerminalSeal(input.id)
            }
            guard input.inputAt <= seal.throughInputAt else {
                throw MultiplayerTerminalDrainError.evidenceOutsideTerminalSeal(input.id)
            }
        }
        terminalSeals[seal.seat] = seal
    }
}

struct MultiplayerTerminalGate: Equatable, Sendable {
    private enum State: Equatable, Sendable {
        case active
        case cancelled
        case submissionAuthorized
    }

    private var state: State = .active

    var submissionAuthorized: Bool { state == .submissionAuthorized }
    var isCancelled: Bool { state == .cancelled }

    mutating func cancel() {
        guard state != .submissionAuthorized else { return }
        state = .cancelled
    }

    mutating func authorizeSubmission(ifConsistent isConsistent: Bool) -> Bool {
        guard state == .active, isConsistent else { return false }
        state = .submissionAuthorized
        return true
    }

    mutating func reset() {
        state = .active
    }
}
