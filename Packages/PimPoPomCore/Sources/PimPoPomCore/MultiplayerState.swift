import Foundation

public enum MultiplayerLivePhase: String, Codable, Equatable, Sendable {
    case running
    case finished
}

public struct MultiplayerTargetState: Codable, Equatable, Sendable {
    public let targetId: Int
    public let ownerSeat: Int
    public let cell: Int
    public let colorIndex: Int
    public let presentedAt: Int
    public let responseWindowMilliseconds: Int

    public var deadline: Int {
        presentedAt + responseWindowMilliseconds
    }
}

public struct MultiplayerDecoyState: Codable, Equatable, Sendable {
    public let decoyId: Int
    public let ownerSeat: Int
    public let cell: Int
    public let colorIndex: Int
    public let activatedAt: Int
    public let lifetimeMilliseconds: Int

    public var expiresAt: Int {
        activatedAt + lifetimeMilliseconds
    }
}

public struct MultiplayerPlayerState: Codable, Equatable, Sendable {
    public let participantId: String
    public let seat: Int
    public let colorIndex: Int
    public internal(set) var lives: Int
    public internal(set) var score: Int
    public internal(set) var hits: Int
    public internal(set) var misses: Int
    public internal(set) var dodges: Int
    public internal(set) var fastestReactionMilliseconds: Int?
    public internal(set) var reactionTotalMilliseconds: Int
    public internal(set) var speedRatings: [SpeedRating: Int]
    public internal(set) var multiplier: Int
    public internal(set) var streakProgress: Int
    public internal(set) var maximumMultiplier: Int
    public internal(set) var challengeHits: Int
    public internal(set) var recoveryUntil: Int?
    public internal(set) var pendingOutAt: Int?
    public internal(set) var eliminatedAt: Int?

    public var averageReactionMilliseconds: Double? {
        guard hits > 0 else { return nil }
        return Double(reactionTotalMilliseconds) / Double(hits)
    }

    public var isAlive: Bool {
        lives > 0
    }
}

public struct MultiplayerLiveState: Codable, Equatable, Sendable {
    public let matchId: String
    public internal(set) var phase: MultiplayerLivePhase
    public internal(set) var players: [MultiplayerPlayerState]
    public internal(set) var target: MultiplayerTargetState?
    public internal(set) var decoys: [MultiplayerDecoyState]
    public internal(set) var nextTargetEarliestAt: Int
    public internal(set) var nextTargetLatestAt: Int
    public internal(set) var lastSequence: Int
    public internal(set) var logicalMilliseconds: Int
    public internal(set) var lastTargetAt: Int?
    public internal(set) var lastTargetOwnerSeat: Int?
    public internal(set) var lastDecoyAt: Int?
    public internal(set) var lastDecoyOwnerSeat: Int?
    public internal(set) var nextTargetId: Int
    public internal(set) var nextDecoyId: Int
    public internal(set) var finishedAt: Int?

    public var totalHits: Int {
        players.reduce(0) { $0 + $1.hits }
    }

    public var livingSeats: [Int] {
        players.filter(\.isAlive).map(\.seat).sorted()
    }

    public var occupiedCells: Set<Int> {
        var cells = Set(decoys.map(\.cell))
        if let target {
            cells.insert(target.cell)
        }
        return cells
    }
}

public struct MultiplayerPlacement: Codable, Equatable, Sendable {
    public let place: Int
    public let participantId: String
    public let seat: Int
    public let colorIndex: Int
    public let score: Int
    public let hits: Int
    public let misses: Int
    public let dodges: Int
    public let fastestReactionMilliseconds: Int?
    public let averageReactionMilliseconds: Int?
    public let maximumMultiplier: Int
    public let speedRatings: [SpeedRating: Int]
}

public final class MultiplayerStateReducer {
    public let manifest: MultiplayerManifest
    public private(set) var state: MultiplayerLiveState
    public private(set) var events: [MultiplayerEvent] = []

    public init(manifest: MultiplayerManifest) throws {
        try manifest.validate()
        self.manifest = manifest
        state = MultiplayerLiveState(
            matchId: manifest.matchId,
            phase: .running,
            players: manifest.participants.sorted { $0.seat < $1.seat }.map {
                MultiplayerPlayerState(
                    participantId: $0.participantId,
                    seat: $0.seat,
                    colorIndex: $0.colorIndex,
                    lives: manifest.startingLives,
                    score: 0,
                    hits: 0,
                    misses: 0,
                    dodges: 0,
                    fastestReactionMilliseconds: nil,
                    reactionTotalMilliseconds: 0,
                    speedRatings: Dictionary(
                        uniqueKeysWithValues: SpeedRating.allCases.map { ($0, 0) }
                    ),
                    multiplier: 1,
                    streakProgress: 0,
                    maximumMultiplier: 1,
                    challengeHits: 0,
                    recoveryUntil: nil,
                    pendingOutAt: nil,
                    eliminatedAt: nil
                )
            },
            target: nil,
            decoys: [],
            nextTargetEarliestAt: 250,
            nextTargetLatestAt: 5_000,
            lastSequence: 0,
            logicalMilliseconds: 0,
            lastTargetAt: nil,
            lastTargetOwnerSeat: nil,
            lastDecoyAt: nil,
            lastDecoyOwnerSeat: nil,
            nextTargetId: 1,
            nextDecoyId: 1,
            finishedAt: nil
        )
    }

    @discardableResult
    public func apply(_ event: MultiplayerEvent) throws -> MultiplayerLiveState {
        let previousState = state
        let previousEvents = events
        do {
            try validateEnvelope(event)
            switch event {
            case .target(let sequence, let at, let ownerSeat, let targetId, let cell, let colorIndex):
                try applyTarget(
                    sequence: sequence,
                    at: at,
                    ownerSeat: ownerSeat,
                    targetId: targetId,
                    cell: cell,
                    colorIndex: colorIndex
                )
            case .hit(let sequence, let inputAt, let handledAt, let seat, let targetId, let cell):
                try applyHit(
                    sequence: sequence,
                    inputAt: inputAt,
                    handledAt: handledAt,
                    seat: seat,
                    targetId: targetId,
                    cell: cell
                )
            case .miss(let sequence, let inputAt, let handledAt, let seat, let reason, let cell):
                try applyMiss(
                    sequence: sequence,
                    inputAt: inputAt,
                    handledAt: handledAt,
                    seat: seat,
                    reason: reason,
                    cell: cell
                )
            case .decoyActivate(
                let
                    sequence,
                let
                    at,
                let
                    ownerSeat,
                let
                    decoyId,
                let
                    cell,
                let
                    colorIndex,
                let
                    lifetimeMilliseconds
            ):
                try applyDecoyActivate(
                    sequence: sequence,
                    at: at,
                    ownerSeat: ownerSeat,
                    decoyId: decoyId,
                    cell: cell,
                    colorIndex: colorIndex,
                    lifetimeMilliseconds: lifetimeMilliseconds
                )
            case .decoyExpire(let sequence, let at, let decoyId):
                try applyDecoyExpire(sequence: sequence, at: at, decoyId: decoyId)
            case .playerOut(let sequence, let at, let seat):
                try applyPlayerOut(sequence: sequence, at: at, seat: seat)
            case .finish(let sequence, let at):
                try applyFinish(sequence: sequence, at: at)
            }
            state.lastSequence = event.sequence
            state.logicalMilliseconds = event.logicalMilliseconds
            events.append(event)
            return state
        } catch {
            state = previousState
            events = previousEvents
            throw error
        }
    }

    public func transcript() -> MultiplayerTranscript {
        MultiplayerTranscript(
            matchId: manifest.matchId,
            buildId: manifest.buildId,
            ruleset: manifest.ruleset,
            protocolVersion: manifest.protocolVersion,
            proofVersion: manifest.proofVersion,
            events: events
        )
    }

    public func placements() -> [MultiplayerPlacement] {
        let ordered = state.players.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.hits != rhs.hits { return lhs.hits > rhs.hits }
            let lhsAverage = lhs.averageReactionMilliseconds.map(jsRound) ?? Int.max
            let rhsAverage = rhs.averageReactionMilliseconds.map(jsRound) ?? Int.max
            if lhsAverage != rhsAverage { return lhsAverage < rhsAverage }
            return lhs.seat < rhs.seat
        }
        return ordered.enumerated().map { offset, player in
            MultiplayerPlacement(
                place: offset + 1,
                participantId: player.participantId,
                seat: player.seat,
                colorIndex: player.colorIndex,
                score: player.score,
                hits: player.hits,
                misses: player.misses,
                dodges: player.dodges,
                fastestReactionMilliseconds: player.fastestReactionMilliseconds,
                averageReactionMilliseconds: player.averageReactionMilliseconds.map(jsRound),
                maximumMultiplier: player.maximumMultiplier,
                speedRatings: player.speedRatings
            )
        }
    }

    public static func replay(
        manifest: MultiplayerManifest,
        transcript: MultiplayerTranscript
    ) throws -> MultiplayerStateReducer {
        try transcript.validate(against: manifest)
        let reducer = try MultiplayerStateReducer(manifest: manifest)
        for event in transcript.events {
            try reducer.apply(event)
        }
        return reducer
    }

    public static func responseWindowMilliseconds(at: Int, challengeHits: Int) -> Int {
        switch at {
        case ..<20_000:
            1_000
        case 20_000..<30_000:
            jsRound(1_000 - 250 * (Double(at - 20_000) / 10_000))
        case 30_000..<40_000:
            750
        case 40_000..<50_000:
            1_000
        default:
            max(200, 1_000 - 5 * challengeHits)
        }
    }

    public static func maximumActiveDecoys(at: Int, totalHits: Int) -> Int {
        guard at >= 10_000 else { return 0 }
        if at < 70_000 { return 1 }
        return min(6, 2 + totalHits / 20)
    }

    private func validateEnvelope(_ event: MultiplayerEvent) throws {
        guard state.phase == .running else {
            throw MultiplayerProtocolError.illegalTransition("event after finish")
        }
        if let pending = state.players.first(where: { $0.pendingOutAt != nil }) {
            guard case .playerOut(_, let at, let seat) = event,
                seat == pending.seat,
                at == pending.pendingOutAt
            else {
                throw MultiplayerProtocolError.illegalTransition(
                    "eliminated player is missing its out transition"
                )
            }
        }
        let expected = state.lastSequence + 1
        guard event.sequence == expected else {
            throw MultiplayerProtocolError.unexpectedSequence(
                expected: expected,
                actual: event.sequence
            )
        }
        guard event.logicalMilliseconds >= state.logicalMilliseconds else {
            throw MultiplayerProtocolError.nonMonotonicTime(
                previous: state.logicalMilliseconds,
                actual: event.logicalMilliseconds
            )
        }
        guard
            (0...MultiplayerProtocolConstants.maximumDurationMilliseconds)
                .contains(event.logicalMilliseconds)
        else {
            throw MultiplayerProtocolError.invalidEvent("logical time is out of bounds")
        }
        guard events.count < MultiplayerProtocolConstants.maximumEvents else {
            throw MultiplayerProtocolError.invalidTranscript("event cap exceeded")
        }
        let expiredDecoys = state.decoys
            .filter { $0.expiresAt <= event.logicalMilliseconds }
            .sorted {
                if $0.expiresAt != $1.expiresAt { return $0.expiresAt < $1.expiresAt }
                return $0.decoyId < $1.decoyId
            }
        if let firstExpired = expiredDecoys.first {
            guard case .decoyExpire(_, _, let decoyId) = event,
                decoyId == firstExpired.decoyId
            else {
                throw MultiplayerProtocolError.illegalTransition(
                    "independently expired decoy is missing its transition"
                )
            }
        }
        if let target = state.target,
            target.deadline <= event.logicalMilliseconds,
            expiredDecoys.isEmpty
        {
            guard case .miss(_, let inputAt, _, let seat, let reason, _) = event,
                reason == .late,
                seat == target.ownerSeat,
                inputAt >= target.deadline
            else {
                throw MultiplayerProtocolError.illegalTransition(
                    "expired target is missing its late-miss transition"
                )
            }
        }
    }

    private func applyTarget(
        sequence _: Int,
        at: Int,
        ownerSeat: Int,
        targetId: Int,
        cell: Int,
        colorIndex: Int
    ) throws {
        guard state.target == nil else {
            throw MultiplayerProtocolError.illegalTransition("target already active")
        }
        guard (0..<MultiplayerProtocolConstants.boardCellCount).contains(cell) else {
            throw MultiplayerProtocolError.invalidEvent("target cell is out of bounds")
        }
        guard !state.decoys.contains(where: { $0.cell == cell }) else {
            throw MultiplayerProtocolError.illegalTransition("target reused a reserved decoy cell")
        }
        guard targetId == state.nextTargetId else {
            throw MultiplayerProtocolError.invalidEvent("target ID is not contiguous")
        }
        guard let ownerIndex = playerIndex(seat: ownerSeat),
            state.players[ownerIndex].isAlive
        else {
            throw MultiplayerProtocolError.illegalTransition("target owner is not alive")
        }
        guard colorIndex == state.players[ownerIndex].colorIndex else {
            throw MultiplayerProtocolError.invalidEvent("target color is not the owner's assigned color")
        }

        guard at >= state.nextTargetEarliestAt, at <= state.nextTargetLatestAt else {
            throw MultiplayerProtocolError.invalidEvent(
                "target scheduling is outside its 250...5000 ms window"
            )
        }
        let expectedOwner = nextLivingSeat(after: state.lastTargetOwnerSeat)
        guard ownerSeat == expectedOwner else {
            throw MultiplayerProtocolError.invalidEvent("target owner rotation is not fair")
        }

        let responseWindow = Self.responseWindowMilliseconds(
            at: at,
            challengeHits: state.players[ownerIndex].challengeHits
        )
        state.target = MultiplayerTargetState(
            targetId: targetId,
            ownerSeat: ownerSeat,
            cell: cell,
            colorIndex: colorIndex,
            presentedAt: at,
            responseWindowMilliseconds: responseWindow
        )
        state.lastTargetAt = at
        state.lastTargetOwnerSeat = ownerSeat
        state.nextTargetId += 1
    }

    private func applyHit(
        sequence _: Int,
        inputAt: Int,
        handledAt: Int,
        seat: Int,
        targetId: Int,
        cell: Int
    ) throws {
        try validateInputTimes(inputAt: inputAt, handledAt: handledAt)
        guard let target = state.target else {
            throw MultiplayerProtocolError.illegalTransition("hit without an active target")
        }
        guard target.ownerSeat == seat, target.targetId == targetId, target.cell == cell else {
            throw MultiplayerProtocolError.invalidEvent("hit does not match the active owned target")
        }
        guard let playerIndex = playerIndex(seat: seat), state.players[playerIndex].isAlive else {
            throw MultiplayerProtocolError.illegalTransition("eliminated player hit")
        }
        let reaction = inputAt - target.presentedAt
        guard reaction >= 0, inputAt < target.deadline else {
            throw MultiplayerProtocolError.invalidEvent("hit is outside the target response window")
        }

        let rating = SpeedRating.classify(reactionMilliseconds: Double(reaction)).rating
        let multiplierUsed = state.players[playerIndex].multiplier
        let base = ReactionScoring.points(
            reactionMilliseconds: Double(reaction),
            responseWindowMilliseconds: Double(target.responseWindowMilliseconds)
        )
        state.players[playerIndex].score += base * multiplierUsed
        state.players[playerIndex].hits += 1
        state.players[playerIndex].reactionTotalMilliseconds += reaction
        state.players[playerIndex].fastestReactionMilliseconds =
            state.players[playerIndex].fastestReactionMilliseconds
            .map { min($0, reaction) } ?? reaction
        state.players[playerIndex].speedRatings[rating, default: 0] += 1
        state.players[playerIndex].maximumMultiplier = max(
            state.players[playerIndex].maximumMultiplier,
            multiplierUsed
        )
        if target.presentedAt >= 50_000 {
            state.players[playerIndex].challengeHits += 1
        }
        advanceStreak(playerIndex: playerIndex, rating: rating)
        state.target = nil
        state.nextTargetEarliestAt = handledAt + 250
        state.nextTargetLatestAt = handledAt + 5_000
    }

    private func applyMiss(
        sequence _: Int,
        inputAt: Int,
        handledAt: Int,
        seat: Int,
        reason: MultiplayerMissReason,
        cell: Int
    ) throws {
        try validateInputTimes(inputAt: inputAt, handledAt: handledAt)
        guard let playerIndex = playerIndex(seat: seat), state.players[playerIndex].isAlive else {
            throw MultiplayerProtocolError.illegalTransition("eliminated player missed")
        }
        if let recoveryUntil = state.players[playerIndex].recoveryUntil,
            inputAt < recoveryUntil
        {
            throw MultiplayerProtocolError.illegalTransition("input occurred during recovery")
        }
        switch reason {
        case .late:
            guard cell == -1 || (0..<MultiplayerProtocolConstants.boardCellCount).contains(cell),
                let target = state.target,
                target.ownerSeat == seat,
                inputAt >= target.deadline
            else {
                throw MultiplayerProtocolError.invalidEvent("late miss does not match an expired owned target")
            }
        case .empty, .wrong:
            guard cell == -1 || (0..<MultiplayerProtocolConstants.boardCellCount).contains(cell) else {
                throw MultiplayerProtocolError.invalidEvent("miss cell is out of bounds")
            }
            if let target = state.target,
                target.ownerSeat == seat,
                target.cell == cell
            {
                throw MultiplayerProtocolError.invalidEvent("correct owned target was recorded as a miss")
            }
        }

        state.players[playerIndex].lives -= 1
        state.players[playerIndex].misses += 1
        state.players[playerIndex].multiplier = 1
        state.players[playerIndex].streakProgress = 0
        state.players[playerIndex].recoveryUntil =
            handledAt + MultiplayerProtocolConstants.recoveryMilliseconds
        if state.target?.ownerSeat == seat {
            state.target = nil
        }
        state.decoys.removeAll()
        state.nextTargetEarliestAt =
            handledAt + MultiplayerProtocolConstants.recoveryMilliseconds + 250
        state.nextTargetLatestAt =
            handledAt + MultiplayerProtocolConstants.recoveryMilliseconds + 5_000
        if state.players[playerIndex].lives == 0 {
            state.players[playerIndex].pendingOutAt = inputAt
        }
    }

    private func applyDecoyActivate(
        sequence _: Int,
        at: Int,
        ownerSeat: Int,
        decoyId: Int,
        cell: Int,
        colorIndex: Int,
        lifetimeMilliseconds: Int
    ) throws {
        guard at >= 10_000 else {
            throw MultiplayerProtocolError.invalidEvent("decoy activated before 10 seconds")
        }
        guard (1_000...3_000).contains(lifetimeMilliseconds) else {
            throw MultiplayerProtocolError.invalidEvent("decoy lifetime is outside 1000...3000 ms")
        }
        guard (0..<MultiplayerProtocolConstants.boardCellCount).contains(cell) else {
            throw MultiplayerProtocolError.invalidEvent("decoy cell is out of bounds")
        }
        guard !state.occupiedCells.contains(cell) else {
            throw MultiplayerProtocolError.illegalTransition("decoy cell is already reserved")
        }
        guard !Set(state.players.map(\.colorIndex)).contains(colorIndex) else {
            throw MultiplayerProtocolError.invalidEvent("decoy uses an assigned player color")
        }
        if let lastDecoyAt = state.lastDecoyAt, at - lastDecoyAt < 600 {
            throw MultiplayerProtocolError.invalidEvent("decoys are separated by less than 600 ms")
        }
        guard state.decoys.allSatisfy({ $0.expiresAt > at }) else {
            throw MultiplayerProtocolError.illegalTransition("expired decoy was not resolved")
        }
        let cap = Self.maximumActiveDecoys(at: at, totalHits: state.totalHits)
        guard state.decoys.count < cap else {
            throw MultiplayerProtocolError.illegalTransition("active decoy cap exceeded")
        }
        guard decoyId == state.nextDecoyId else {
            throw MultiplayerProtocolError.invalidEvent("decoy ID is not contiguous")
        }
        guard let ownerIndex = playerIndex(seat: ownerSeat), state.players[ownerIndex].isAlive else {
            throw MultiplayerProtocolError.illegalTransition("decoy owner is not alive")
        }
        let expectedOwner = nextLivingSeat(after: state.lastDecoyOwnerSeat)
        guard ownerSeat == expectedOwner else {
            throw MultiplayerProtocolError.invalidEvent("dodge owner rotation is not fair")
        }

        state.decoys.append(
            MultiplayerDecoyState(
                decoyId: decoyId,
                ownerSeat: ownerSeat,
                cell: cell,
                colorIndex: colorIndex,
                activatedAt: at,
                lifetimeMilliseconds: lifetimeMilliseconds
            )
        )
        state.decoys.sort { $0.decoyId < $1.decoyId }
        state.lastDecoyAt = at
        state.lastDecoyOwnerSeat = ownerSeat
        state.nextDecoyId += 1
    }

    private func applyDecoyExpire(sequence _: Int, at: Int, decoyId: Int) throws {
        guard let index = state.decoys.firstIndex(where: { $0.decoyId == decoyId }) else {
            throw MultiplayerProtocolError.illegalTransition("unknown decoy expired")
        }
        let decoy = state.decoys[index]
        guard at >= decoy.expiresAt, at <= decoy.expiresAt + 5_000 else {
            throw MultiplayerProtocolError.invalidEvent("decoy expiry is outside its allowed lag")
        }
        guard let ownerIndex = playerIndex(seat: decoy.ownerSeat) else {
            throw MultiplayerProtocolError.invalidEvent("decoy owner is unknown")
        }
        if state.players[ownerIndex].isAlive {
            state.players[ownerIndex].dodges += 1
            state.players[ownerIndex].score += MultiplayerProtocolConstants.dodgePoints
        }
        state.decoys.remove(at: index)
    }

    private func applyPlayerOut(sequence _: Int, at: Int, seat: Int) throws {
        guard let playerIndex = playerIndex(seat: seat) else {
            throw MultiplayerProtocolError.invalidEvent("unknown player seat")
        }
        guard state.players[playerIndex].lives == 0,
            state.players[playerIndex].eliminatedAt == nil,
            state.players[playerIndex].pendingOutAt == at
        else {
            throw MultiplayerProtocolError.illegalTransition("player-out requires a newly depleted player")
        }
        state.players[playerIndex].pendingOutAt = nil
        state.players[playerIndex].eliminatedAt = at
    }

    private func applyFinish(sequence _: Int, at: Int) throws {
        guard state.players.allSatisfy({ $0.lives == 0 && $0.eliminatedAt != nil }) else {
            throw MultiplayerProtocolError.illegalTransition("finish requires every player to be out")
        }
        guard state.target == nil else {
            throw MultiplayerProtocolError.illegalTransition("finish with an active target")
        }
        state.decoys.removeAll()
        state.phase = .finished
        state.finishedAt = at
    }

    private func validateInputTimes(inputAt: Int, handledAt: Int) throws {
        guard inputAt >= 0, handledAt >= inputAt, handledAt - inputAt <= 10_000 else {
            throw MultiplayerProtocolError.invalidEvent("input/handling time is invalid")
        }
    }

    private func playerIndex(seat: Int) -> Int? {
        state.players.firstIndex { $0.seat == seat }
    }

    private func nextLivingSeat(after previous: Int?) -> Int? {
        let seats = state.livingSeats
        guard !seats.isEmpty else { return nil }
        guard let previous else { return seats[0] }
        return seats.first(where: { $0 > previous }) ?? seats[0]
    }

    private func advanceStreak(playerIndex: Int, rating: SpeedRating) {
        let steps: Int =
            switch rating {
            case .godlike: 2
            case .perfect: 1
            case .great, .good: 0
            }
        guard steps > 0 else { return }
        var progress = state.players[playerIndex].streakProgress + steps
        var multiplier = state.players[playerIndex].multiplier
        while progress >= 5, multiplier < 5 {
            progress -= 5
            multiplier += 1
        }
        if multiplier == 5 {
            progress = 5
        }
        state.players[playerIndex].streakProgress = progress
        state.players[playerIndex].multiplier = multiplier
    }
}
