import Foundation

public enum MultiplayerActivationKind: String, Codable, Equatable, Hashable, Sendable {
    case target
    case decoy
}

/// A presentation plan may be sent to peers before its logical `at` time.
///
/// Plans are deliberately not transcript events and carry no transcript
/// sequence. A miss, finish, or roster failure can cancel a plan without
/// creating a sequence gap. The coordinator commits the corresponding exact
/// integer tuple only when `advance(to:)` reaches `at`.
public struct MultiplayerActivationPlan: Codable, Equatable, Hashable, Sendable {
    public let planId: Int
    public let kind: MultiplayerActivationKind
    public let at: Int
    public let ownerSeat: Int
    public let entityId: Int
    public let cell: Int
    public let colorIndex: Int
    public let lifetimeMilliseconds: Int?

    public init(
        planId: Int,
        kind: MultiplayerActivationKind,
        at: Int,
        ownerSeat: Int,
        entityId: Int,
        cell: Int,
        colorIndex: Int,
        lifetimeMilliseconds: Int? = nil
    ) {
        self.planId = planId
        self.kind = kind
        self.at = at
        self.ownerSeat = ownerSeat
        self.entityId = entityId
        self.cell = cell
        self.colorIndex = colorIndex
        self.lifetimeMilliseconds = lifetimeMilliseconds
    }
}

public enum MultiplayerInputOutcome: String, Codable, Equatable, Sendable {
    case hit
    case miss
    case ignoredRecovery
    case ignoredEliminated
    case ignoredFinished
    case ignoredExpired
}

public struct MultiplayerCoordinatorAdvance: Equatable, Sendable {
    public let committedEvents: [MultiplayerEvent]
    public let plannedActivations: [MultiplayerActivationPlan]
    public let cancelledPlanIds: [Int]

    public init(
        committedEvents: [MultiplayerEvent] = [],
        plannedActivations: [MultiplayerActivationPlan] = [],
        cancelledPlanIds: [Int] = []
    ) {
        self.committedEvents = committedEvents
        self.plannedActivations = plannedActivations
        self.cancelledPlanIds = cancelledPlanIds
    }
}

public struct MultiplayerInputResult: Equatable, Sendable {
    public let outcome: MultiplayerInputOutcome
    public let committedEvents: [MultiplayerEvent]
    public let plannedActivations: [MultiplayerActivationPlan]
    public let cancelledPlanIds: [Int]

    public init(
        outcome: MultiplayerInputOutcome,
        committedEvents: [MultiplayerEvent],
        plannedActivations: [MultiplayerActivationPlan],
        cancelledPlanIds: [Int]
    ) {
        self.outcome = outcome
        self.committedEvents = committedEvents
        self.plannedActivations = plannedActivations
        self.cancelledPlanIds = cancelledPlanIds
    }
}

public struct MultiplayerTranscriptCheckpoint: Codable, Equatable, Sendable {
    public let manifestHash: String
    public let transcript: MultiplayerTranscript

    public init(manifestHash: String, transcript: MultiplayerTranscript) {
        self.manifestHash = manifestHash
        self.transcript = transcript
    }

    public func restore(manifest: MultiplayerManifest) throws -> MultiplayerStateReducer {
        guard manifestHash == manifest.manifestHash else {
            throw MultiplayerProtocolError.invalidTranscript("checkpoint manifest hash mismatch")
        }
        return try MultiplayerStateReducer.replay(manifest: manifest, transcript: transcript)
    }
}

public final class MultiplayerCoordinatorEngine {
    public let manifest: MultiplayerManifest
    public let availableColorIndices: [Int]
    public let presentationLeadMilliseconds: Int

    public var state: MultiplayerLiveState {
        reducer.state
    }

    public var events: [MultiplayerEvent] {
        reducer.events
    }

    public var clockMilliseconds: Int {
        currentMilliseconds
    }

    public var pendingActivations: [MultiplayerActivationPlan] {
        [pendingTarget, pendingDecoy]
            .compactMap { $0 }
            .sorted(by: activationOrder)
    }

    private let reducer: MultiplayerStateReducer
    private let random: () -> Double
    private var started = false
    private var currentMilliseconds = 0
    private var nextTargetDue: Int?
    private var nextDecoyDue: Int?
    private var pendingTarget: MultiplayerActivationPlan?
    private var pendingDecoy: MultiplayerActivationPlan?
    private var nextPlanId = 1

    public init(
        manifest: MultiplayerManifest,
        availableColorIndices: [Int] = Array(gameColors.indices),
        presentationLeadMilliseconds: Int = 1_200,
        random: @escaping () -> Double = { Double.random(in: 0..<1) }
    ) throws {
        self.manifest = manifest
        self.availableColorIndices = availableColorIndices
        self.presentationLeadMilliseconds = max(0, presentationLeadMilliseconds)
        self.random = random
        reducer = try MultiplayerStateReducer(manifest: manifest)
        try validateAvailableColors()
    }

    public init(
        manifest: MultiplayerManifest,
        checkpoint: MultiplayerTranscriptCheckpoint,
        availableColorIndices: [Int] = Array(gameColors.indices),
        presentationLeadMilliseconds: Int = 1_200,
        random: @escaping () -> Double = { Double.random(in: 0..<1) }
    ) throws {
        self.manifest = manifest
        self.availableColorIndices = availableColorIndices
        self.presentationLeadMilliseconds = max(0, presentationLeadMilliseconds)
        self.random = random
        reducer = try checkpoint.restore(manifest: manifest)
        currentMilliseconds = reducer.state.logicalMilliseconds
        started = true
        try validateAvailableColors()
        if reducer.state.phase == .running {
            establishFutureDueTimes(from: currentMilliseconds)
        }
    }

    /// Starts a logical match clock at zero and returns activation plans already
    /// inside the configured presentation lead horizon.
    @discardableResult
    public func start(at milliseconds: Int = 0) throws -> [MultiplayerActivationPlan] {
        guard !started else {
            return try prepareActivations(
                now: currentMilliseconds,
                horizonMilliseconds: presentationLeadMilliseconds
            )
        }
        guard milliseconds == 0 else {
            throw MultiplayerProtocolError.illegalTransition(
                "multiplayer logical time must start at zero"
            )
        }
        started = true
        currentMilliseconds = 0
        establishFutureDueTimes(from: 0)
        return try prepareActivations(
            now: 0,
            horizonMilliseconds: presentationLeadMilliseconds
        )
    }

    /// Materializes target/decoy choices shortly before presentation without
    /// committing them to the transcript.
    @discardableResult
    public func prepareActivations(
        now: Int,
        horizonMilliseconds: Int? = nil
    ) throws -> [MultiplayerActivationPlan] {
        try requireStarted()
        guard reducer.state.phase == .running else { return [] }
        guard now >= currentMilliseconds else {
            throw MultiplayerProtocolError.nonMonotonicTime(
                previous: currentMilliseconds,
                actual: now
            )
        }
        let horizon = now + max(0, horizonMilliseconds ?? presentationLeadMilliseconds)
        establishFutureDueTimes(from: now)
        var created: [MultiplayerActivationPlan] = []

        if pendingTarget == nil,
            reducer.state.target == nil,
            let due = nextTargetDue,
            due <= horizon,
            let ownerSeat = nextLivingSeat(after: reducer.state.lastTargetOwnerSeat)
        {
            let occupied = reservedCells()
            let available = (0..<MultiplayerProtocolConstants.boardCellCount)
                .filter { !occupied.contains($0) }
            guard !available.isEmpty else {
                throw MultiplayerProtocolError.illegalTransition("no target cell available")
            }
            guard let participant = manifest.participants.first(where: { $0.seat == ownerSeat }) else {
                throw MultiplayerProtocolError.invalidManifest("target owner is absent")
            }
            let plan = MultiplayerActivationPlan(
                planId: allocatePlanId(),
                kind: .target,
                at: due,
                ownerSeat: ownerSeat,
                entityId: reducer.state.nextTargetId,
                cell: randomElement(available),
                colorIndex: participant.colorIndex
            )
            pendingTarget = plan
            created.append(plan)
        }

        if pendingDecoy == nil,
            let due = nextDecoyDue,
            due <= horizon,
            due >= 10_000
        {
            let cap = MultiplayerStateReducer.maximumActiveDecoys(
                at: due,
                totalHits: reducer.state.totalHits
            )
            if reducer.state.decoys.count < cap,
                let ownerSeat = nextLivingSeat(after: reducer.state.lastDecoyOwnerSeat)
            {
                let occupied = reservedCells()
                let available = (0..<MultiplayerProtocolConstants.boardCellCount)
                    .filter { !occupied.contains($0) }
                let assignedColors = Set(manifest.participants.map(\.colorIndex))
                let decoyColors = availableColorIndices.filter { !assignedColors.contains($0) }
                if !available.isEmpty, !decoyColors.isEmpty {
                    let plan = MultiplayerActivationPlan(
                        planId: allocatePlanId(),
                        kind: .decoy,
                        at: due,
                        ownerSeat: ownerSeat,
                        entityId: reducer.state.nextDecoyId,
                        cell: randomElement(available),
                        colorIndex: randomElement(decoyColors),
                        lifetimeMilliseconds: randomInteger(in: 1_000...3_000)
                    )
                    pendingDecoy = plan
                    created.append(plan)
                } else {
                    nextDecoyDue = due + 600
                }
            } else {
                nextDecoyDue = due + 600
            }
        }
        return created.sorted(by: activationOrder)
    }

    @discardableResult
    public func advance(to milliseconds: Int) throws -> MultiplayerCoordinatorAdvance {
        try advanceInternal(to: milliseconds)
    }

    @discardableResult
    public func handleTap(
        seat: Int,
        cell: Int,
        inputAt: Int,
        handledAt: Int
    ) throws -> MultiplayerInputResult {
        try requireStarted()
        guard (0..<MultiplayerProtocolConstants.boardCellCount).contains(cell) else {
            throw MultiplayerProtocolError.invalidEvent("input cell is out of bounds")
        }
        guard handledAt >= inputAt, handledAt >= currentMilliseconds else {
            throw MultiplayerProtocolError.invalidEvent("input/handling time is invalid")
        }
        let initialEventCount = reducer.events.count
        var newPlans: [MultiplayerActivationPlan] = []
        var cancelledPlanIDs: [Int] = []

        if inputAt < reducer.state.logicalMilliseconds {
            return inputResult(
                outcome: .ignoredExpired,
                initialEventCount: initialEventCount,
                plans: [],
                cancellations: []
            )
        }
        let inputAdvance = try advanceInternal(to: max(currentMilliseconds, inputAt))
        newPlans.append(contentsOf: inputAdvance.plannedActivations)
        cancelledPlanIDs.append(contentsOf: inputAdvance.cancelledPlanIds)

        guard reducer.state.phase == .running else {
            return inputResult(
                outcome: .ignoredFinished,
                initialEventCount: initialEventCount,
                plans: newPlans,
                cancellations: cancelledPlanIDs
            )
        }
        guard let player = reducer.state.players.first(where: { $0.seat == seat }),
            player.isAlive
        else {
            return inputResult(
                outcome: .ignoredEliminated,
                initialEventCount: initialEventCount,
                plans: newPlans,
                cancellations: cancelledPlanIDs
            )
        }
        if let recoveryUntil = player.recoveryUntil, inputAt < recoveryUntil {
            return inputResult(
                outcome: .ignoredRecovery,
                initialEventCount: initialEventCount,
                plans: newPlans,
                cancellations: cancelledPlanIDs
            )
        }

        let targetAtInput = reducer.state.target
        let occupiedAtInput = reducer.state.occupiedCells
        if let targetAtInput,
            reducer.state.target?.targetId == targetAtInput.targetId,
            targetAtInput.ownerSeat == seat,
            targetAtInput.cell == cell,
            inputAt < targetAtInput.deadline
        {
            try reducer.apply(
                .hit(
                    sequence: nextSequence,
                    inputAt: inputAt,
                    handledAt: handledAt,
                    seat: seat,
                    targetId: targetAtInput.targetId,
                    cell: cell
                )
            )
            nextTargetDue = nil
            establishFutureDueTimes(from: handledAt)
            newPlans.append(
                contentsOf: try prepareActivations(
                    now: currentMilliseconds,
                    horizonMilliseconds: presentationLeadMilliseconds
                )
            )
            return inputResult(
                outcome: .hit,
                initialEventCount: initialEventCount,
                plans: newPlans,
                cancellations: cancelledPlanIDs
            )
        }

        let reason: MultiplayerMissReason = occupiedAtInput.contains(cell) ? .wrong : .empty
        try reducer.apply(
            .miss(
                sequence: nextSequence,
                inputAt: inputAt,
                handledAt: handledAt,
                seat: seat,
                reason: reason,
                cell: cell
            )
        )
        cancelledPlanIDs.append(contentsOf: cancelPendingActivations())
        try appendPlayerOutAndFinishIfNeeded(
            seat: seat,
            outAt: inputAt,
            finishAt: handledAt
        )
        if reducer.state.phase == .running {
            nextTargetDue = nil
            nextDecoyDue = nil
            establishFutureDueTimes(from: handledAt)
        }
        if reducer.state.phase == .running {
            newPlans.append(
                contentsOf: try prepareActivations(
                    now: currentMilliseconds,
                    horizonMilliseconds: presentationLeadMilliseconds
                )
            )
        } else {
            currentMilliseconds = reducer.state.logicalMilliseconds
        }
        return inputResult(
            outcome: .miss,
            initialEventCount: initialEventCount,
            plans: newPlans,
            cancellations: cancelledPlanIDs
        )
    }

    public func transcript() -> MultiplayerTranscript {
        reducer.transcript()
    }

    public func placements() -> [MultiplayerPlacement] {
        reducer.placements()
    }

    public func checkpoint() -> MultiplayerTranscriptCheckpoint {
        MultiplayerTranscriptCheckpoint(
            manifestHash: manifest.manifestHash,
            transcript: reducer.transcript()
        )
    }

    private var nextSequence: Int {
        reducer.state.lastSequence + 1
    }

    private func advanceInternal(
        to milliseconds: Int
    ) throws -> MultiplayerCoordinatorAdvance {
        try requireStarted()
        guard milliseconds >= currentMilliseconds else {
            throw MultiplayerProtocolError.nonMonotonicTime(
                previous: currentMilliseconds,
                actual: milliseconds
            )
        }
        let initialEventCount = reducer.events.count
        var plans: [MultiplayerActivationPlan] = []
        var cancellations: [Int] = []

        while reducer.state.phase == .running {
            plans.append(
                contentsOf: try prepareActivations(
                    now: currentMilliseconds,
                    horizonMilliseconds: max(0, milliseconds - currentMilliseconds)
                )
            )
            guard let due = nextDueAction(),
                due.at <= milliseconds
            else {
                break
            }
            currentMilliseconds = due.at
            switch due.kind {
            case .decoyExpiry(let decoyId):
                try reducer.apply(
                    .decoyExpire(sequence: nextSequence, at: due.at, decoyId: decoyId)
                )
            case .targetExpiry(let target):
                try reducer.apply(
                    .miss(
                        sequence: nextSequence,
                        inputAt: due.at,
                        handledAt: due.at,
                        seat: target.ownerSeat,
                        reason: .late,
                        cell: -1
                    )
                )
                cancellations.append(contentsOf: cancelPendingActivations())
                try appendPlayerOutAndFinishIfNeeded(
                    seat: target.ownerSeat,
                    outAt: due.at,
                    finishAt: due.at
                )
                if reducer.state.phase == .running {
                    nextTargetDue = nil
                    nextDecoyDue = nil
                    establishFutureDueTimes(from: due.at)
                }
            case .activation(let plan):
                switch plan.kind {
                case .target:
                    try reducer.apply(
                        .target(
                            sequence: nextSequence,
                            at: plan.at,
                            ownerSeat: plan.ownerSeat,
                            targetId: plan.entityId,
                            cell: plan.cell,
                            colorIndex: plan.colorIndex
                        )
                    )
                    pendingTarget = nil
                    nextTargetDue = nil
                case .decoy:
                    guard let lifetime = plan.lifetimeMilliseconds else {
                        throw MultiplayerProtocolError.invalidEvent(
                            "decoy plan has no lifetime"
                        )
                    }
                    try reducer.apply(
                        .decoyActivate(
                            sequence: nextSequence,
                            at: plan.at,
                            ownerSeat: plan.ownerSeat,
                            decoyId: plan.entityId,
                            cell: plan.cell,
                            colorIndex: plan.colorIndex,
                            lifetimeMilliseconds: lifetime
                        )
                    )
                    pendingDecoy = nil
                    nextDecoyDue = plan.at + decoyDelay(at: plan.at)
                }
            }
        }
        currentMilliseconds = milliseconds
        if reducer.state.phase == .running {
            plans.append(
                contentsOf: try prepareActivations(
                    now: milliseconds,
                    horizonMilliseconds: presentationLeadMilliseconds
                )
            )
        }
        return MultiplayerCoordinatorAdvance(
            committedEvents: Array(reducer.events.dropFirst(initialEventCount)),
            plannedActivations: uniquelyOrdered(plans),
            cancelledPlanIds: uniquelyOrdered(cancellations)
        )
    }

    private enum DueKind {
        case decoyExpiry(Int)
        case targetExpiry(MultiplayerTargetState)
        case activation(MultiplayerActivationPlan)
    }

    private struct DueAction {
        let at: Int
        let priority: Int
        let kind: DueKind
    }

    private func nextDueAction() -> DueAction? {
        var actions: [DueAction] = reducer.state.decoys.map {
            DueAction(at: $0.expiresAt, priority: 0, kind: .decoyExpiry($0.decoyId))
        }
        if let target = reducer.state.target {
            actions.append(
                DueAction(
                    at: target.deadline,
                    priority: 1,
                    kind: .targetExpiry(target)
                )
            )
        }
        if let pendingDecoy {
            actions.append(
                DueAction(at: pendingDecoy.at, priority: 2, kind: .activation(pendingDecoy))
            )
        }
        if let pendingTarget {
            actions.append(
                DueAction(at: pendingTarget.at, priority: 3, kind: .activation(pendingTarget))
            )
        }
        return actions.min {
            if $0.at != $1.at { return $0.at < $1.at }
            return $0.priority < $1.priority
        }
    }

    private func establishFutureDueTimes(from now: Int) {
        guard reducer.state.phase == .running else { return }
        if reducer.state.target == nil, pendingTarget == nil, nextTargetDue == nil,
            !reducer.state.livingSeats.isEmpty
        {
            let base = now
            let proposed = base + targetDelay(at: base)
            let minimum = reducer.state.nextTargetEarliestAt
            let maximum = reducer.state.nextTargetLatestAt
            nextTargetDue = min(maximum, max(minimum, proposed))
        }
        if pendingDecoy == nil, nextDecoyDue == nil, !reducer.state.livingSeats.isEmpty {
            if now < 10_000 {
                nextDecoyDue = 10_000
            } else {
                let base = max(now, (reducer.state.lastDecoyAt ?? 0) + 600)
                nextDecoyDue = base + decoyDelay(at: base)
            }
        }
    }

    private func appendPlayerOutAndFinishIfNeeded(
        seat: Int,
        outAt: Int,
        finishAt: Int
    ) throws {
        if let player = reducer.state.players.first(where: { $0.seat == seat }),
            player.lives == 0,
            player.eliminatedAt == nil
        {
            try reducer.apply(.playerOut(sequence: nextSequence, at: outAt, seat: seat))
        }
        if reducer.state.players.allSatisfy({ $0.lives == 0 && $0.eliminatedAt != nil }) {
            try reducer.apply(.finish(sequence: nextSequence, at: finishAt))
            _ = cancelPendingActivations()
        }
    }

    private func cancelPendingActivations() -> [Int] {
        let cancelled = [pendingTarget?.planId, pendingDecoy?.planId].compactMap { $0 }
        pendingTarget = nil
        pendingDecoy = nil
        nextTargetDue = nil
        nextDecoyDue = nil
        return cancelled.sorted()
    }

    private func targetDelay(at milliseconds: Int) -> Int {
        switch milliseconds {
        case ..<10_000:
            return randomInteger(in: 550...1_100)
        case 10_000..<20_000:
            return randomInteger(in: 550...1_000)
        case 20_000..<30_000:
            return randomInteger(in: 500...950)
        case 30_000..<40_000:
            return randomInteger(in: 475...900)
        case 40_000..<50_000:
            return randomInteger(in: 525...950)
        default:
            let tier = reducer.state.totalHits / 10
            let minimum = max(250, 425 - 15 * tier)
            let maximum = max(500, 825 - 25 * tier)
            return randomInteger(in: minimum...maximum)
        }
    }

    private func decoyDelay(at milliseconds: Int) -> Int {
        switch milliseconds {
        case ..<20_000:
            return randomInteger(in: 2_200...3_600)
        case 20_000..<30_000:
            return randomInteger(in: 2_000...3_200)
        case 30_000..<40_000:
            return randomInteger(in: 600...3_400)
        case 40_000..<50_000:
            return randomInteger(in: 2_200...3_400)
        default:
            let tier = reducer.state.totalHits / 10
            return randomInteger(in: 600...max(1_100, 2_000 - 170 * tier))
        }
    }

    private func nextLivingSeat(after previous: Int?) -> Int? {
        let seats = reducer.state.livingSeats
        guard !seats.isEmpty else { return nil }
        guard let previous else { return seats[0] }
        return seats.first(where: { $0 > previous }) ?? seats[0]
    }

    private func reservedCells() -> Set<Int> {
        var result = reducer.state.occupiedCells
        if let pendingTarget { result.insert(pendingTarget.cell) }
        if let pendingDecoy { result.insert(pendingDecoy.cell) }
        return result
    }

    private func allocatePlanId() -> Int {
        defer { nextPlanId += 1 }
        return nextPlanId
    }

    private func randomInteger(in range: ClosedRange<Int>) -> Int {
        guard range.lowerBound < range.upperBound else { return range.lowerBound }
        let unit = min(0.999_999_999, max(0, random()))
        let width = range.upperBound - range.lowerBound + 1
        return range.lowerBound + Int(floor(unit * Double(width)))
    }

    private func randomElement<T>(_ values: [T]) -> T {
        values[randomInteger(in: 0...(values.count - 1))]
    }

    private func validateAvailableColors() throws {
        let assigned = Set(manifest.participants.map(\.colorIndex))
        guard Set(availableColorIndices).count == availableColorIndices.count,
            availableColorIndices.allSatisfy({ $0 >= 0 }),
            !Set(availableColorIndices).subtracting(assigned).isEmpty
        else {
            throw MultiplayerProtocolError.invalidManifest(
                "available colors must include at least one unassigned decoy color"
            )
        }
    }

    private func requireStarted() throws {
        guard started else {
            throw MultiplayerProtocolError.illegalTransition("coordinator has not started")
        }
    }

    private func inputResult(
        outcome: MultiplayerInputOutcome,
        initialEventCount: Int,
        plans: [MultiplayerActivationPlan],
        cancellations: [Int]
    ) -> MultiplayerInputResult {
        MultiplayerInputResult(
            outcome: outcome,
            committedEvents: Array(reducer.events.dropFirst(initialEventCount)),
            plannedActivations: uniquelyOrdered(plans),
            cancelledPlanIds: uniquelyOrdered(cancellations)
        )
    }
}

private func activationOrder(
    _ lhs: MultiplayerActivationPlan,
    _ rhs: MultiplayerActivationPlan
) -> Bool {
    if lhs.at != rhs.at { return lhs.at < rhs.at }
    if lhs.kind != rhs.kind { return lhs.kind == .decoy }
    return lhs.planId < rhs.planId
}

private func uniquelyOrdered<T: Hashable>(_ values: [T]) -> [T] {
    var seen: Set<T> = []
    return values.filter { seen.insert($0).inserted }
}
