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

struct MultiplayerPresentedTargetCandidate: Equatable, Sendable {
    let activationID: MultiplayerPresentedActivationID
    let presentedAt: Int
    let cell: Int
    let colorIndex: Int
    let ownerSeat: Int
}

enum MultiplayerPresentedTargetSelection {
    static func latest(
        in candidates: [MultiplayerPresentedTargetCandidate]
    ) -> MultiplayerPresentedTargetCandidate? {
        candidates.max { lhs, rhs in
            if lhs.presentedAt != rhs.presentedAt {
                return lhs.presentedAt < rhs.presentedAt
            }
            if lhs.activationID.entityID != rhs.activationID.entityID {
                return lhs.activationID.entityID < rhs.activationID.entityID
            }
            return lhs.cell < rhs.cell
        }
    }
}

enum MultiplayerInputAdmissionPolicy {
    static let ordinaryFutureToleranceMilliseconds = 2_000

    static func maximumAcceptedInputAt(
        currentLogicalMilliseconds: Int,
        isPausedForRecovery: Bool,
        recoveryLimitMilliseconds: Int
    ) -> Int {
        currentLogicalMilliseconds
            + (isPausedForRecovery
                ? recoveryLimitMilliseconds
                : ordinaryFutureToleranceMilliseconds)
    }
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

struct MultiplayerReadyIntent: Equatable, Sendable {
    private var desiredReady: Bool?
    private var inFlightReady: Bool?

    var projectedReady: Bool? {
        desiredReady ?? inFlightReady
    }

    mutating func request(_ ready: Bool) {
        desiredReady = ready
    }

    func displayedReady(serverReady: Bool) -> Bool {
        projectedReady ?? serverReady
    }

    mutating func takePendingMutation(
        serverReady: Bool,
        compatibility: MultiplayerLiveCompatibility
    ) -> Bool? {
        guard inFlightReady == nil, let desiredReady else { return nil }
        guard desiredReady != serverReady else {
            self.desiredReady = nil
            return nil
        }
        guard !desiredReady || compatibility == .unanimous else { return nil }
        inFlightReady = desiredReady
        return desiredReady
    }

    mutating func observe(serverReady: Bool) {
        guard inFlightReady == nil, desiredReady == serverReady else { return }
        desiredReady = nil
    }

    mutating func acknowledge(serverReady _: Bool) {
        inFlightReady = nil
        desiredReady = nil
    }

    mutating func mutationFailed() {
        inFlightReady = nil
        desiredReady = nil
    }

    mutating func reset() {
        desiredReady = nil
        inFlightReady = nil
    }
}

enum MultiplayerClockSynchronizationPolicy {
    static func shouldStart(
        isCoordinator: Bool,
        isWaiting: Bool,
        isTransportConnected: Bool,
        connectionPresentsFailure: Bool,
        hasMeasurement: Bool,
        hasTask: Bool,
        hasMatchID: Bool
    ) -> Bool {
        !isCoordinator
            && isWaiting
            && isTransportConnected
            && !connectionPresentsFailure
            && !hasMeasurement
            && !hasTask
            && hasMatchID
    }

    static func shouldContinue(
        now: Int,
        deadline: Int,
        hasMeasurement: Bool
    ) -> Bool {
        !hasMeasurement && now < deadline
    }
}

enum MultiplayerWaitingConnectionOperationPolicy {
    static func canContinue(
        isWaiting: Bool,
        isTransportConnected: Bool,
        hasDisconnectedPlayers: Bool,
        expectedConnectionGeneration: UInt64,
        currentConnectionGeneration: UInt64
    ) -> Bool {
        isWaiting
            && isTransportConnected
            && !hasDisconnectedPlayers
            && expectedConnectionGeneration == currentConnectionGeneration
    }
}

enum MultiplayerPauseRecoveryAnchorPolicy {
    static func applyingSnapshot(
        pausedAtLogicalMilliseconds: Int?,
        existingAnchor: Int?,
        now: Int
    ) -> Int? {
        guard pausedAtLogicalMilliseconds != nil else { return nil }
        return existingAnchor ?? now
    }
}

struct MultiplayerLobbyOperationIdentity: Equatable, Sendable {
    let matchID: String
    let runtimeGeneration: UInt64
    let revision: UInt64

    func isCurrent(
        matchID: String?,
        runtimeGeneration: UInt64,
        revision: UInt64
    ) -> Bool {
        self.matchID == matchID
            && self.runtimeGeneration == runtimeGeneration
            && self.revision == revision
    }
}

struct MultiplayerLocalInputPrediction: Equatable, Sendable {
    private(set) var nextInputSequence = 1
    private var pendingInputsByID: [MultiplayerInputID: MultiplayerPendingLocalInput] = [:]
    private var inputIDByActivation: [MultiplayerPresentedActivationID: MultiplayerInputID] =
        [:]

    var pendingInput: MultiplayerPendingLocalInput? {
        pendingInputsByID.values.max {
            $0.inputID.inputSequence < $1.inputID.inputSequence
        }
    }

    var hasPendingInputs: Bool { !pendingInputsByID.isEmpty }

    var latestPendingInputAt: Int? {
        pendingInputsByID.values.map(\.inputAt).max()
    }

    var overlay: MultiplayerLocalPredictionOverlay? {
        pendingInput?.overlay
    }

    var hiddenTargetCell: Int? {
        guard case .consumedTarget(let cell) = overlay else { return nil }
        return cell
    }

    var allowsInput: Bool { pendingInput == nil }

    func pendingInput(
        for activationID: MultiplayerPresentedActivationID
    ) -> MultiplayerPendingLocalInput? {
        guard let inputID = inputIDByActivation[activationID] else { return nil }
        return pendingInputsByID[inputID]
    }

    func overlay(
        for activationID: MultiplayerPresentedActivationID
    ) -> MultiplayerLocalPredictionOverlay? {
        pendingInput(for: activationID)?.overlay
    }

    func hidesTarget(
        for activationID: MultiplayerPresentedActivationID
    ) -> Bool {
        guard case .consumedTarget = overlay(for: activationID) else { return false }
        return true
    }

    func allowsInput(
        for activationID: MultiplayerPresentedActivationID
    ) -> Bool {
        pendingInput(for: activationID) == nil
    }

    mutating func begin(
        seat: Int,
        activationID: MultiplayerPresentedActivationID,
        tappedCell: Int,
        ownedTargetCell: Int?,
        inputAt: Int
    ) -> MultiplayerLocalInputCapture {
        if let pendingInput = pendingInput(for: activationID) {
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
        let pendingInput = MultiplayerPendingLocalInput(
            inputID: inputID,
            activationID: activationID,
            tappedCell: tappedCell,
            inputAt: inputAt,
            overlay: overlay,
            committedEventSequence: nil
        )
        pendingInputsByID[inputID] = pendingInput
        inputIDByActivation[activationID] = inputID
        return .accepted(inputID)
    }

    mutating func receive(
        _ resolution: MultiplayerInputResolution
    ) -> MultiplayerLocalReconciliation {
        guard var pendingInput = pendingInputsByID[resolution.inputID]
        else { return .unchanged }
        switch resolution.disposition {
        case .committed(let eventSequence):
            if pendingInput.committedEventSequence == eventSequence {
                return .unchanged
            }
            pendingInput.committedEventSequence = eventSequence
            pendingInputsByID[resolution.inputID] = pendingInput
            return .agreement
        case .ignored:
            pendingInputsByID.removeValue(forKey: resolution.inputID)
            inputIDByActivation.removeValue(forKey: pendingInput.activationID)
            return .corrected
        }
    }

    mutating func canonicalApplied(eventSequence: Int) -> Bool {
        takeCanonicalAppliedInputID(eventSequence: eventSequence) != nil
    }

    mutating func takeCanonicalAppliedInputID(
        eventSequence: Int
    ) -> MultiplayerInputID? {
        guard
            let resolved = pendingInputsByID.values
                .filter({ $0.committedEventSequence == eventSequence })
                .sorted(by: {
                    if $0.inputID.seat != $1.inputID.seat {
                        return $0.inputID.seat < $1.inputID.seat
                    }
                    return $0.inputID.inputSequence < $1.inputID.inputSequence
                })
                .first
        else { return nil }
        pendingInputsByID.removeValue(forKey: resolved.inputID)
        inputIDByActivation.removeValue(forKey: resolved.activationID)
        return resolved.inputID
    }

    mutating func reset() {
        nextInputSequence = 1
        pendingInputsByID = [:]
        inputIDByActivation = [:]
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
    private struct Entry: Equatable, Sendable {
        let beganAtMonotonicMilliseconds: Int
        var requestedSnapshot: Bool
    }

    private var entries: [MultiplayerInputID: Entry] = [:]

    var hasPendingInputs: Bool { !entries.isEmpty }

    var isCatchingUp: Bool {
        entries.values.contains(where: \.requestedSnapshot)
    }

    var pendingInputIDs: [MultiplayerInputID] {
        entries.keys.sorted {
            if $0.seat != $1.seat { return $0.seat < $1.seat }
            return $0.inputSequence < $1.inputSequence
        }
    }

    mutating func begin(
        inputID: MultiplayerInputID,
        monotonicMilliseconds: Int
    ) {
        guard entries[inputID] == nil else { return }
        entries[inputID] = Entry(
            beganAtMonotonicMilliseconds: monotonicMilliseconds,
            requestedSnapshot: false
        )
    }

    mutating func resolve(_ resolvedInputID: MultiplayerInputID) {
        entries.removeValue(forKey: resolvedInputID)
    }

    mutating func action(
        monotonicMilliseconds: Int,
        noticeAfterMilliseconds: Int,
        cancelAfterMilliseconds: Int
    ) -> MultiplayerResolutionWatchdogAction {
        guard noticeAfterMilliseconds >= 0,
            cancelAfterMilliseconds > noticeAfterMilliseconds
        else { return .none }

        let orderedEntries = entries.sorted {
            if $0.value.beganAtMonotonicMilliseconds
                != $1.value.beganAtMonotonicMilliseconds
            {
                return $0.value.beganAtMonotonicMilliseconds
                    < $1.value.beganAtMonotonicMilliseconds
            }
            if $0.key.seat != $1.key.seat { return $0.key.seat < $1.key.seat }
            return $0.key.inputSequence < $1.key.inputSequence
        }
        if let expired = orderedEntries.first(where: {
            monotonicMilliseconds - $0.value.beganAtMonotonicMilliseconds
                >= cancelAfterMilliseconds
        }) {
            return .cancelWithoutSettlement(expired.key)
        }
        if let pendingNotice = orderedEntries.first(where: {
            !$0.value.requestedSnapshot
                && monotonicMilliseconds - $0.value.beganAtMonotonicMilliseconds
                    >= noticeAfterMilliseconds
        }) {
            entries[pendingNotice.key]?.requestedSnapshot = true
            return .requestSnapshot(pendingNotice.key)
        }
        return .none
    }

    mutating func reset() {
        entries = [:]
    }
}

enum MultiplayerRecoveryWindowPhase: Equatable, Sendable {
    case silent
    case visible
    case expired
}

enum MultiplayerRecoveryWindow {
    static func phase(
        now: Int,
        beganAt: Int,
        noticeAfterMilliseconds: Int,
        cancelAfterMilliseconds: Int
    ) -> MultiplayerRecoveryWindowPhase {
        let elapsed = max(0, now - beganAt)
        if elapsed >= cancelAfterMilliseconds { return .expired }
        if elapsed >= noticeAfterMilliseconds { return .visible }
        return .silent
    }
}

enum MultiplayerPeerCanonicalRecoveryPolicy {
    static func isRequired(
        pendingBatchCount: Int,
        hasPendingSnapshot: Bool,
        isSnapshotAssemblyPending: Bool,
        pendingFinishEventSequence: Int?,
        transcriptEventCount: Int
    ) -> Bool {
        pendingBatchCount > 0
            || hasPendingSnapshot
            || isSnapshotAssemblyPending
            || pendingFinishEventSequence.map({ $0 > transcriptEventCount }) == true
    }
}

enum MultiplayerSnapshotRecoveryRequestPolicy {
    static func shouldRequest(
        isCoordinator: Bool,
        hasPeerCanonicalRecovery: Bool,
        hasResolutionRecovery: Bool,
        now: Int,
        lastRequestAt: Int?,
        retryIntervalMilliseconds: Int = 250
    ) -> Bool {
        guard !isCoordinator,
            hasPeerCanonicalRecovery || hasResolutionRecovery
        else { return false }
        return lastRequestAt.map({ now - $0 >= retryIntervalMilliseconds }) ?? true
    }
}

enum MultiplayerReconnectSnapshotPolicy {
    static func shouldSend(
        isCoordinator: Bool,
        hasPendingResumeRecovery: Bool
    ) -> Bool {
        isCoordinator && !hasPendingResumeRecovery
    }
}

enum MultiplayerSnapshotMetadataPolicy {
    static func shouldCommitInController(
        snapshotThroughEventSequence: Int,
        transcriptEventCount: Int,
        snapshotControlWatermark: Int,
        latestMetadataControlSequence: Int
    ) -> Bool {
        snapshotThroughEventSequence == transcriptEventCount
            && snapshotControlWatermark >= latestMetadataControlSequence
    }

    static func shouldStageInTransport(
        snapshotThroughEventSequence: Int,
        appliedEventSequence: Int,
        snapshotControlWatermark: Int,
        latestMetadataControlSequence: Int
    ) -> Bool {
        snapshotThroughEventSequence >= appliedEventSequence
            && snapshotControlWatermark >= latestMetadataControlSequence
    }
}

enum MultiplayerCoordinatedPausePolicy {
    static func shouldBegin(
        isCoordinator: Bool,
        isAlreadyPaused: Bool,
        isTerminalDraining: Bool,
        didBroadcastFinish: Bool
    ) -> Bool {
        isCoordinator
            && !isAlreadyPaused
            && !isTerminalDraining
            && !didBroadcastFinish
    }
}

enum MultiplayerTerminalDrainDeadlinePolicy {
    static func hasExpired(now: Int, deadline: Int) -> Bool {
        now >= deadline
    }
}

enum MultiplayerRecoveryDeadlinePolicy {
    static func firstExpiredMessage(
        now: Int,
        noticeAfterMilliseconds: Int,
        cancelAfterMilliseconds: Int,
        recoveries: [(beganAt: Int?, message: String)]
    ) -> String? {
        recoveries.first { recovery in
            guard let beganAt = recovery.beganAt else { return false }
            return MultiplayerRecoveryWindow.phase(
                now: now,
                beganAt: beganAt,
                noticeAfterMilliseconds: noticeAfterMilliseconds,
                cancelAfterMilliseconds: cancelAfterMilliseconds
            ) == .expired
        }?.message
    }
}

struct MultiplayerCoordinatorPlanOutbox {
    private var plansByID: [Int: MultiplayerWireActivationPlan] = [:]
    private var queuedAtByID: [Int: Int] = [:]

    var isEmpty: Bool { plansByID.isEmpty }

    mutating func enqueue(
        _ plan: MultiplayerWireActivationPlan,
        logicalMilliseconds: Int
    ) {
        plansByID[plan.planId] = plan
        queuedAtByID[plan.planId] = logicalMilliseconds
    }

    mutating func remove(planIDs: some Sequence<Int>) {
        for planID in planIDs {
            plansByID.removeValue(forKey: planID)
            queuedAtByID.removeValue(forKey: planID)
        }
    }

    func nextBatch() -> (plans: [MultiplayerWireActivationPlan], queuedAt: Int)? {
        let plans = plansByID.values.sorted { $0.planId < $1.planId }
        guard !plans.isEmpty else { return nil }
        let queuedAt = plans.compactMap { queuedAtByID[$0.planId] }.min() ?? 0
        return (plans, queuedAt)
    }

    mutating func reset() {
        plansByID = [:]
        queuedAtByID = [:]
    }
}

enum MultiplayerCanonicalBatchReconciliationError: Error, Equatable {
    case conflictingAppliedEvent(Int)
    case conflictingPendingBatch(Int)
}

enum MultiplayerCanonicalBatchReconciler {
    static func inserting(
        _ batch: [MultiplayerEvent],
        into pending: [Int: [MultiplayerEvent]],
        after transcript: [MultiplayerEvent]
    ) throws -> [Int: [MultiplayerEvent]] {
        guard let firstSequence = batch.first?.sequence else { return pending }
        if let existing = pending[firstSequence], existing != batch {
            throw MultiplayerCanonicalBatchReconciliationError.conflictingPendingBatch(
                firstSequence
            )
        }
        var combined = pending
        combined[firstSequence] = batch
        return try retainingUnapplied(combined, after: transcript)
    }

    static func retainingUnapplied(
        _ batches: [Int: [MultiplayerEvent]],
        after transcript: [MultiplayerEvent]
    ) throws -> [Int: [MultiplayerEvent]] {
        var retained: [Int: [MultiplayerEvent]] = [:]
        for batch in batches.values {
            for event in batch where event.sequence <= transcript.count {
                guard event.sequence > 0,
                    transcript[event.sequence - 1] == event
                else {
                    throw
                        MultiplayerCanonicalBatchReconciliationError
                        .conflictingAppliedEvent(event.sequence)
                }
            }
            let remaining = batch.filter { $0.sequence > transcript.count }
            guard let first = remaining.first else { continue }
            if let existing = retained[first.sequence], existing != remaining {
                throw
                    MultiplayerCanonicalBatchReconciliationError
                    .conflictingPendingBatch(first.sequence)
            }
            retained[first.sequence] = remaining
        }
        return retained
    }
}

enum MultiplayerSnapshotTranscriptReconciliationError: Error, Equatable {
    case noncontiguousEvent(Int)
    case conflictingAppliedEvent(Int)
}

enum MultiplayerSnapshotTranscriptReconciler {
    static func unappliedEvents(
        from tuples: [[Int]],
        after transcript: [MultiplayerEvent]
    ) throws -> [MultiplayerEvent] {
        let events = try tuples.map(MultiplayerEvent.init(integerTuple:))
        for (index, event) in events.enumerated() {
            guard event.sequence > 0,
                index == 0 || event.sequence == events[index - 1].sequence + 1
            else {
                throw MultiplayerSnapshotTranscriptReconciliationError.noncontiguousEvent(
                    event.sequence
                )
            }
            if event.sequence <= transcript.count {
                guard transcript[event.sequence - 1] == event else {
                    throw
                        MultiplayerSnapshotTranscriptReconciliationError
                        .conflictingAppliedEvent(event.sequence)
                }
            }
        }
        let unapplied = events.filter { $0.sequence > transcript.count }
        if let first = unapplied.first,
            first.sequence != transcript.count + 1
        {
            throw MultiplayerSnapshotTranscriptReconciliationError.noncontiguousEvent(
                first.sequence
            )
        }
        return unapplied
    }
}

enum MultiplayerSnapshotAssemblyError: Error, Equatable {
    case invalidChunk
    case conflictingChunk(Int)
}

struct MultiplayerSnapshotAssembler {
    private var exemplar: MultiplayerSnapshotPacket?
    private var chunksByIndex: [Int: MultiplayerSnapshotPacket] = [:]

    var isPending: Bool { exemplar != nil }

    mutating func ingest(
        _ packet: MultiplayerSnapshotPacket
    ) throws -> MultiplayerSnapshotPacket? {
        guard packet.afterEventSequence >= 0,
            packet.throughEventSequence <= MultiplayerProtocolConstants.maximumEvents,
            packet.chunkCount > 0,
            packet.chunkCount <= MultiplayerSnapshotPacket.maximumChunkCount,
            (0..<packet.chunkCount).contains(packet.chunkIndex),
            packet.throughEventSequence >= packet.afterEventSequence,
            packet.events.count <= MultiplayerSnapshotPacket.maximumEventsPerChunk,
            Set(packet.pendingPlans.map(\.planId)).count == packet.pendingPlans.count
        else {
            throw MultiplayerSnapshotAssemblyError.invalidChunk
        }
        if let exemplar, !Self.belongsToSameSnapshot(packet, exemplar) {
            guard packet.chunkIndex == 0 else {
                throw MultiplayerSnapshotAssemblyError.invalidChunk
            }
            reset()
        }
        if exemplar == nil { exemplar = packet }
        if let existing = chunksByIndex[packet.chunkIndex], existing != packet {
            throw MultiplayerSnapshotAssemblyError.conflictingChunk(packet.chunkIndex)
        }
        chunksByIndex[packet.chunkIndex] = packet
        guard chunksByIndex.count == packet.chunkCount,
            let exemplar = self.exemplar
        else { return nil }
        let events = try (0..<packet.chunkCount).flatMap { index -> [[Int]] in
            guard let chunk = chunksByIndex[index] else {
                throw MultiplayerSnapshotAssemblyError.invalidChunk
            }
            return chunk.events
        }
        let eventSequences = events.compactMap { $0.count > 1 ? $0[1] : nil }
        guard eventSequences.count == events.count else {
            throw MultiplayerSnapshotAssemblyError.invalidChunk
        }
        let eventsAreContiguous = eventSequences.enumerated().allSatisfy {
            index, sequence in
            sequence == exemplar.afterEventSequence + index + 1
        }
        guard eventsAreContiguous,
            (eventSequences.last ?? exemplar.afterEventSequence)
                == exemplar.throughEventSequence
        else {
            throw MultiplayerSnapshotAssemblyError.invalidChunk
        }
        let assembled = MultiplayerSnapshotPacket(
            afterEventSequence: exemplar.afterEventSequence,
            throughEventSequence: exemplar.throughEventSequence,
            chunkIndex: 0,
            chunkCount: 1,
            controlWatermark: exemplar.controlWatermark,
            events: events,
            pendingPlans: exemplar.pendingPlans,
            coordinatorMatchStartMonotonicMilliseconds:
                exemplar.coordinatorMatchStartMonotonicMilliseconds,
            pauseId: exemplar.pauseId,
            pausedAtLogicalMilliseconds: exemplar.pausedAtLogicalMilliseconds
        )
        reset()
        return assembled
    }

    mutating func reset() {
        exemplar = nil
        chunksByIndex = [:]
    }

    private static func belongsToSameSnapshot(
        _ lhs: MultiplayerSnapshotPacket,
        _ rhs: MultiplayerSnapshotPacket
    ) -> Bool {
        lhs.afterEventSequence == rhs.afterEventSequence
            && lhs.throughEventSequence == rhs.throughEventSequence
            && lhs.chunkCount == rhs.chunkCount
            && lhs.controlWatermark == rhs.controlWatermark
            && lhs.pendingPlans == rhs.pendingPlans
            && lhs.coordinatorMatchStartMonotonicMilliseconds
                == rhs.coordinatorMatchStartMonotonicMilliseconds
            && lhs.pauseId == rhs.pauseId
            && lhs.pausedAtLogicalMilliseconds == rhs.pausedAtLogicalMilliseconds
    }
}

struct MultiplayerLiveInteractionPresentation: Equatable, Sendable {
    let inputMode: MultiplayerPresentation.LiveInputMode
    let networkStatus: MultiplayerPresentation.LiveNetworkStatus?
}

enum MultiplayerLiveInteractionPolicy {
    static func resolve(
        localHasLives: Bool,
        isApplicationActive: Bool,
        hasDisconnectedPlayers: Bool,
        isPaused: Bool,
        isTerminalDraining: Bool,
        hasPendingInputForPresentedActivation: Bool,
        isCatchUpVisible: Bool
    ) -> MultiplayerLiveInteractionPresentation {
        let isReconnecting = !isApplicationActive || hasDisconnectedPlayers
        let networkStatus: MultiplayerPresentation.LiveNetworkStatus? =
            if isReconnecting {
                .reconnecting
            } else if isTerminalDraining {
                .finalizing
            } else if isCatchUpVisible {
                .catchingUp
            } else {
                nil
            }
        let inputMode: MultiplayerPresentation.LiveInputMode =
            if !localHasLives {
                .spectating
            } else if isReconnecting {
                .syncing
            } else if isTerminalDraining {
                .finalizing
            } else if hasPendingInputForPresentedActivation {
                .pending
            } else {
                .interactive
            }
        return MultiplayerLiveInteractionPresentation(
            inputMode: inputMode,
            networkStatus: networkStatus
        )
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
            || previous.networkStatus != next.networkStatus
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
    static let captureGraceMilliseconds = 150

    private var lastThroughInputAt = -1
    private var lastReliableLogicalMilliseconds: Int?

    mutating func next(
        seat: Int,
        highestInputSequence: Int,
        logicalMilliseconds: Int
    ) -> MultiplayerLocalSealEmission? {
        guard logicalMilliseconds > Self.captureGraceMilliseconds else { return nil }
        let throughInputAt = logicalMilliseconds - Self.captureGraceMilliseconds
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
