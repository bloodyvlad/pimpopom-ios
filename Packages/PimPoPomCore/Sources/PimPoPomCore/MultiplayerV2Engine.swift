import Foundation

public enum MP2EngineError: Error, Equatable, Sendable {
    case invalidRoster
}

/// Synchronous room-owned value. No transport, peer acknowledgements, or v1 replay.
/// All timers use a monotonic, match-relative integer millisecond clock.
public struct MP2Engine: Sendable {
    private enum Outcome: Sendable {
        case hit(reaction: Int, window: Int)
        case mistake
        case dodge(activatedAt: Int)
        case baseline
        case out
    }

    private struct Event: Sendable {
        let id: Int
        let at: Int
        let outcome: Outcome
    }

    private enum Resolution: Sendable {
        case open
        case expired(eventID: Int)
        case hit
        case void
    }

    private struct TargetRecord: Sendable {
        let target: MP2Target
        var resolution: Resolution
    }

    private struct SeatState: Sendable {
        var base: MP2Player
        var player: MP2Player
        var journal: [Event] = []
        var nextTargetAt: Int
        var nextDecoyAt: Int
        var dueSince: Int
        var lastExpiredDecoyCell: Int?
        var receipts: [Int: (MP2Input, MP2InputReceipt)] = [:]
    }

    public let matchID: String
    public let configuration: GameConfiguration
    /// Delivery headroom; shared cell contention or late receipt can extend quiet time.
    public let scheduleLeadMs: Int
    public private(set) var elapsedMs = 0
    public private(set) var revision = 0
    private var phase: MP2MatchPhase = .playing
    private var gridDimension = 1
    private var seats: [Int: SeatState] = [:]
    private var targets: [Int: TargetRecord] = [:]
    private var decoys: [Int: MP2Decoy] = [:]
    private var nextTargetID = 1
    private var nextDecoyID = 1
    private var nextEventID = 1
    private var randomState: UInt64
    private var finishAt: Int?
    private var durationEnded = false
    private let presentationAllowanceMs = 750
    private let journalHorizonMs = 5_000
    private let maximumReceiptsPerSeat = 10_000

    public init(
        matchID: String, players: [MP2Player], seed: UInt64,
        configuration: GameConfiguration = .standard, scheduleLeadMs: Int = 250
    ) throws {
        guard (2...4).contains(players.count), !matchID.isEmpty,
            Set(players.map(\.id)).count == players.count,
            Set(players.map(\.seat)).count == players.count,
            Set(players.map(\.colorIndex)).count == players.count,
            players.allSatisfy({
                !$0.id.isEmpty && (0..<4).contains($0.seat) && gameColors.indices.contains($0.colorIndex)
            })
        else { throw MP2EngineError.invalidRoster }
        self.matchID = matchID
        self.configuration = configuration
        self.scheduleLeadMs = min(750, max(0, scheduleLeadMs))
        self.randomState = seed
        for source in players.sorted(by: { $0.seat < $1.seat }) {
            let player = MP2Player(
                id: source.id, seat: source.seat, colorIndex: source.colorIndex,
                name: source.name, petID: source.petID, connected: source.connected,
                lives: configuration.startingLives
            )
            let due = sample(configuration.spawnDelays.warmup)
            seats[player.seat] = SeatState(
                base: player, player: player, nextTargetAt: due,
                nextDecoyAt: configuration.phases.colorPatienceStartsAtMilliseconds, dueSince: due
            )
        }
        processCurrentTime()
    }

    public var snapshot: MP2Snapshot {
        MP2Snapshot(
            matchID: matchID, revision: revision,
            elapsedMs: finishAt.map { $0 - finalAdmissionMs } ?? elapsedMs, phase: phase,
            gridDimension: gridDimension, players: seats.keys.sorted().compactMap { seats[$0]?.player },
            targets: targets.values.compactMap {
                if case .open = $0.resolution { return $0.target }
                return nil
            }.sorted { $0.id < $1.id },
            decoys: decoys.values.sorted { $0.id < $1.id }
        )
    }

    /// Always progresses without input from any seat. Finalization retains the complete admission horizon.
    @discardableResult
    public mutating func advance(to requestedMs: Int) -> MP2Snapshot {
        guard requestedMs > elapsedMs, phase != .finished else { return snapshot }
        let destination = min(requestedMs, MP2Protocol.maximumDurationMs + finalAdmissionMs)
        while elapsedMs < destination, phase != .finished {
            var next = destination
            if !durationEnded { next = min(next, MP2Protocol.maximumDurationMs) }
            if let finishAt { next = min(next, finishAt) }
            for record in targets.values {
                if case .open = record.resolution { next = min(next, record.target.expiresAtMs) }
            }
            for decoy in decoys.values { next = min(next, decoy.expiresAtMs) }
            if phase == .playing {
                for seat in seats.values where seat.player.connected && !seat.player.isOut {
                    if !hasOpenTarget(seat.player.seat) {
                        next = min(next, max(seat.player.recoveryUntilMs, seat.nextTargetAt - scheduleLeadMs))
                    }
                    next = min(next, max(seat.player.recoveryUntilMs, seat.nextDecoyAt))
                }
                if elapsedMs < configuration.phases.fourByFourStartsAtMilliseconds {
                    next = min(next, configuration.phases.fourByFourStartsAtMilliseconds)
                }
            }
            elapsedMs = min(destination, max(elapsedMs + 1, next))
            processCurrentTime()
        }
        pruneHistory()
        revision += 1
        return snapshot
    }

    @discardableResult
    public mutating func submit(_ input: MP2Input, receivedAt: Int) -> MP2InputReceipt {
        guard let state = seats[input.seat] else { return receipt(input, false, "unknown-seat") }
        if let previous = state.receipts[input.id] {
            return previous.0 == input ? previous.1 : receipt(input, false, "conflicting-input-id")
        }
        advance(to: receivedAt)
        guard seats[input.seat]!.receipts.count < maximumReceiptsPerSeat else {
            return receipt(input, false, "input-limit")
        }
        let result = admit(input, receivedAt: receivedAt)
        seats[input.seat]!.receipts[input.id] = (input, result)
        return result
    }

    /// Disconnect voids only this seat's current opportunity; the room service owns its rejoin timer.
    @discardableResult
    public mutating func disconnect(seat: Int, at: Int) -> MP2Snapshot {
        advance(to: at)
        guard seats[seat] != nil, phase != .finished else { return snapshot }
        seats[seat]!.base.connected = false
        seats[seat]!.player.connected = false
        voidOpenTargets(seat: seat)
        clearDecoys(seat: seat)
        revision += 1
        return snapshot
    }

    @discardableResult
    public mutating func reconnect(seat: Int, at: Int) -> MP2Snapshot {
        advance(to: at)
        guard seats[seat] != nil, !seats[seat]!.player.isOut, phase == .playing else { return snapshot }
        seats[seat]!.base.connected = true
        seats[seat]!.player.connected = true
        scheduleNextTarget(seat: seat, after: elapsedMs)
        scheduleNextDecoy(seat: seat, after: elapsedMs)
        revision += 1
        return snapshot
    }

    @discardableResult
    public mutating func eliminateDisconnected(seat: Int, at: Int) -> MP2Snapshot {
        advance(to: at)
        guard let state = seats[seat], !state.player.connected, !state.player.isOut, phase != .finished else {
            return snapshot
        }
        append(seat: seat, at: elapsedMs, outcome: .out)
        updateFinish()
        revision += 1
        return snapshot
    }

    public func difficulty(for seat: Int, at elapsed: Int? = nil) -> Difficulty? {
        guard let state = seats[seat] else { return nil }
        return resolveDifficulty(
            hits: totalHits, elapsedMilliseconds: Double(elapsed ?? elapsedMs),
            challengeHits: max(0, state.player.hits - (state.player.challengeBaselineHits ?? state.player.hits)),
            configuration: configuration
        )
    }

    private var totalHits: Int { seats.values.reduce(0) { $0 + $1.player.hits } }
    private var finalAdmissionMs: Int { presentationAllowanceMs + MP2Protocol.lateInputGraceMs }

    private mutating func admit(_ input: MP2Input, receivedAt: Int) -> MP2InputReceipt {
        guard (1...MP2Protocol.maximumInputID).contains(input.id), (-1..<16).contains(input.cell),
            input.cell != -1 || input.targetID == nil,
            input.presentedAtMs >= 0, input.contactAtMs >= input.presentedAtMs,
            input.contactAtMs <= receivedAt, receivedAt >= elapsedMs,
            receivedAt - input.contactAtMs <= MP2Protocol.lateInputGraceMs
        else { return receipt(input, false, "invalid-timing-or-input") }
        guard phase != .finished, input.contactAtMs < MP2Protocol.maximumDurationMs else {
            return receipt(input, false, "match-finished")
        }
        guard seats[input.seat]!.player.connected else { return receipt(input, false, "disconnected") }

        if let id = input.targetID {
            guard let record = targets[id], record.target.cell == input.cell else {
                return receipt(input, false, "unknown-target")
            }
            let target = record.target
            guard input.presentedAtMs >= target.activateAtMs,
                input.presentedAtMs - target.activateAtMs <= presentationAllowanceMs
            else { return receipt(input, false, "invalid-presentation") }
            if target.ownerSeat != input.seat {
                guard case .open = record.resolution, input.contactAtMs < target.expiresAtMs else {
                    return receipt(input, false, "stale-target")
                }
                return mistake(input, reason: "wrong-color")
            }
            switch record.resolution {
            case .hit, .void: return receipt(input, false, "target-resolved")
            case .open, .expired: break
            }
            let reaction = input.contactAtMs - input.presentedAtMs
            guard reaction < target.responseWindowMs else {
                if case .expired = record.resolution { return receipt(input, false, "late") }
                return mistake(input, reason: "late")
            }
            // Evaluate eligibility without this provisional expiry. This permits revival after a third miss.
            let expiryID: Int? = if case .expired(let id) = record.resolution { id } else { nil }
            let before = replayedPlayer(seat: input.seat, through: input.contactAtMs, excluding: expiryID)
            guard !before.isOut, input.contactAtMs >= before.recoveryUntilMs else {
                return receipt(input, false, "recovery-or-out")
            }
            if let expiryID { seats[input.seat]!.journal.removeAll { $0.id == expiryID } }
            targets[id]!.resolution = .hit
            append(
                seat: input.seat, at: input.contactAtMs,
                outcome: .hit(reaction: reaction, window: target.responseWindowMs))
            // Issued targets/windows are immutable; correction only changes future, unissued opportunities.
            if !hasOpenTarget(input.seat) { scheduleNextTarget(seat: input.seat, after: input.contactAtMs) }
            updateGrid()
            updateFinish()
            processCurrentTime()
            revision += 1
            return receipt(input, true, expiryID == nil ? "hit" : "corrected-hit")
        }

        let visibleOwn = targets.values.contains {
            if case .open = $0.resolution {
                return $0.target.ownerSeat == input.seat && $0.target.cell == input.cell
                    && $0.target.activateAtMs <= input.contactAtMs
            }
            return false
        }
        guard !visibleOwn else { return receipt(input, false, "target-id-required") }
        return mistake(input, reason: decoys.values.contains { $0.cell == input.cell } ? "decoy" : "empty")
    }

    private mutating func mistake(_ input: MP2Input, reason: String) -> MP2InputReceipt {
        let before = replayedPlayer(seat: input.seat, through: input.contactAtMs)
        guard !before.isOut, input.contactAtMs >= before.recoveryUntilMs else {
            return receipt(input, false, "recovery-or-out")
        }
        append(seat: input.seat, at: input.contactAtMs, outcome: .mistake)
        voidOpenTargets(seat: input.seat)
        clearDecoys(seat: input.seat)
        scheduleNextTarget(seat: input.seat, after: input.contactAtMs)
        scheduleNextDecoy(seat: input.seat, after: input.contactAtMs)
        updateFinish()
        revision += 1
        return receipt(input, true, reason)
    }

    private mutating func processCurrentTime() {
        updateGrid()
        for id in decoys.keys.sorted() {
            guard let decoy = decoys[id], decoy.expiresAtMs <= elapsedMs else { continue }
            decoys.removeValue(forKey: id)
            seats[decoy.beneficiarySeat]!.lastExpiredDecoyCell = decoy.cell
            append(seat: decoy.beneficiarySeat, at: decoy.expiresAtMs, outcome: .dodge(activatedAt: decoy.activateAtMs))
            revision += 1
        }
        for id in targets.keys.sorted() {
            guard let record = targets[id], case .open = record.resolution,
                record.target.expiresAtMs <= elapsedMs
            else { continue }
            let seat = record.target.ownerSeat
            let eventID = append(seat: seat, at: record.target.expiresAtMs, outcome: .mistake)
            targets[id]!.resolution = .expired(eventID: eventID)
            clearDecoys(seat: seat)
            scheduleNextTarget(seat: seat, after: record.target.expiresAtMs)
            scheduleNextDecoy(seat: seat, after: record.target.expiresAtMs)
            revision += 1
        }
        if elapsedMs >= MP2Protocol.maximumDurationMs, !durationEnded {
            durationEnded = true
            for seat in seats.keys.sorted() {
                voidOpenTargets(seat: seat)
                clearDecoys(seat: seat)
            }
        }
        updateFinish()
        guard phase == .playing else { return }
        issueTargets()
        issueDecoys()
    }

    private mutating func issueTargets() {
        var eligible = seats.keys.sorted().filter {
            let state = seats[$0]!
            return state.player.connected && !state.player.isOut && !hasOpenTarget($0)
                && elapsedMs >= state.player.recoveryUntilMs && state.nextTargetAt - scheduleLeadMs <= elapsedMs
        }
        while !eligible.isEmpty {
            // Independent due times plus random arbitration permit repeats. An overdue seat gets bounded fairness.
            let oldest = eligible.min { seats[$0]!.dueSince < seats[$1]!.dueSince }!
            let seat = elapsedMs - seats[oldest]!.dueSince >= 2_000 ? oldest : eligible[randomIndex(eligible.count)]
            eligible.removeAll { $0 == seat }
            let occupied = occupiedCells
            var free = (0..<(gridDimension * gridDimension)).filter {
                !occupied.contains($0) && $0 != seats[seat]!.lastExpiredDecoyCell
            }
            if free.isEmpty { free = (0..<(gridDimension * gridDimension)).filter { !occupied.contains($0) } }
            guard !free.isEmpty else {
                seats[seat]!.nextTargetAt = elapsedMs + scheduleLeadMs + 50
                continue
            }
            let activation = max(elapsedMs + scheduleLeadMs, seats[seat]!.nextTargetAt)
            if activation >= configuration.phases.fourByFourChallengeStartsAtMilliseconds,
                seats[seat]!.player.challengeBaselineHits == nil
            {
                append(seat: seat, at: activation, outcome: .baseline)
            }
            let target = MP2Target(
                id: nextTargetID, cell: free[randomIndex(free.count)], ownerSeat: seat,
                colorIndex: seats[seat]!.player.colorIndex, activateAtMs: activation,
                responseWindowMs: difficulty(for: seat, at: activation)!.responseWindowMilliseconds
            )
            nextTargetID += 1
            targets[target.id] = TargetRecord(target: target, resolution: .open)
            seats[seat]!.lastExpiredDecoyCell = nil
            revision += 1
        }
    }

    private mutating func issueDecoys() {
        var eligible = seats.keys.sorted().filter {
            let state = seats[$0]!
            return state.player.connected && !state.player.isOut && elapsedMs >= state.player.recoveryUntilMs
                && state.nextDecoyAt <= elapsedMs
        }
        while !eligible.isEmpty {
            let seat = eligible.remove(at: randomIndex(eligible.count))
            let difficulty = difficulty(for: seat)!
            let livingCount = seats.values.filter { !$0.player.isOut && $0.player.connected }.count
            // One global Arcade cap, with one cell reserved for each living seat where geometry permits.
            let cap = min(difficulty.maximumActiveDecoys, max(0, gridDimension * gridDimension - livingCount))
            let occupied = occupiedCells
            let free = (0..<(gridDimension * gridDimension)).filter { !occupied.contains($0) }
            guard decoys.count < cap, !free.isEmpty, let range = difficulty.decoySpawnDelayRangeMilliseconds else {
                seats[seat]!.nextDecoyAt = elapsedMs + configuration.decoys.retryDelayMilliseconds
                continue
            }
            let colors = seats.values.map { $0.player.colorIndex }.sorted().filter {
                $0 != seats[seat]!.player.colorIndex
            }
            let decoy = MP2Decoy(
                id: nextDecoyID, cell: free[randomIndex(free.count)], colorIndex: colors[randomIndex(colors.count)],
                beneficiarySeat: seat, activateAtMs: elapsedMs,
                expiresAtMs: elapsedMs + sample(configuration.decoys.lifetimeRangeMilliseconds)
            )
            nextDecoyID += 1
            decoys[decoy.id] = decoy
            seats[seat]!.nextDecoyAt = elapsedMs + sample(range)
            revision += 1
        }
    }

    private mutating func updateGrid() {
        gridDimension = max(
            gridDimension,
            resolveDifficulty(
                hits: totalHits, elapsedMilliseconds: Double(elapsedMs), configuration: configuration
            ).gridDimension)
    }

    private mutating func updateFinish() {
        guard phase != .finished else { return }
        if durationEnded || seats.values.allSatisfy({ $0.player.isOut }) {
            let logicalEnd =
                durationEnded
                ? MP2Protocol.maximumDurationMs : seats.values.compactMap { $0.player.outAtMs }.max() ?? elapsedMs
            finishAt = logicalEnd + finalAdmissionMs
            phase = .finishing
            if elapsedMs >= finishAt! {
                phase = .finished
                decoys.removeAll()
            }
        } else {
            finishAt = nil
            phase = .playing
        }
    }

    private mutating func scheduleNextTarget(seat: Int, after: Int) {
        let baseTime = max(after, seats[seat]!.player.recoveryUntilMs)
        let quiet = sample(difficulty(for: seat, at: baseTime)!.spawnDelayRangeMilliseconds)
        seats[seat]!.nextTargetAt = max(elapsedMs + scheduleLeadMs, baseTime + quiet)
        seats[seat]!.dueSince = seats[seat]!.nextTargetAt
    }

    private mutating func scheduleNextDecoy(seat: Int, after: Int) {
        let baseTime = max(after, seats[seat]!.player.recoveryUntilMs)
        if baseTime < configuration.phases.colorPatienceStartsAtMilliseconds {
            seats[seat]!.nextDecoyAt = configuration.phases.colorPatienceStartsAtMilliseconds
        } else if let range = difficulty(for: seat, at: baseTime)!.decoySpawnDelayRangeMilliseconds {
            seats[seat]!.nextDecoyAt = baseTime + sample(range)
        } else {
            seats[seat]!.nextDecoyAt = baseTime + configuration.decoys.retryDelayMilliseconds
        }
    }

    private func hasOpenTarget(_ seat: Int) -> Bool {
        targets.values.contains {
            if case .open = $0.resolution { return $0.target.ownerSeat == seat }
            return false
        }
    }

    /// A scheduled expiry may precede the owner's full first-visible window.
    /// Keep that cell reserved until every admitted presentation could have expired.
    private var occupiedCells: Set<Int> {
        Set(
            targets.values.compactMap { record -> Int? in
                switch record.resolution {
                case .open: return record.target.cell
                case .expired:
                    return elapsedMs < record.target.expiresAtMs + presentationAllowanceMs ? record.target.cell : nil
                case .hit, .void: return nil
                }
            }
        ).union(decoys.values.map(\.cell))
    }

    private mutating func voidOpenTargets(seat: Int) {
        for id in targets.keys.sorted() where targets[id]!.target.ownerSeat == seat {
            if case .open = targets[id]!.resolution { targets[id]!.resolution = .void }
        }
    }

    private mutating func clearDecoys(seat: Int) {
        decoys = decoys.filter { $0.value.beneficiarySeat != seat }
    }

    @discardableResult
    private mutating func append(seat: Int, at: Int, outcome: Outcome) -> Int {
        let event = Event(id: nextEventID, at: at, outcome: outcome)
        nextEventID += 1
        seats[seat]!.journal.append(event)
        seats[seat]!.journal.sort { ($0.at, $0.id) < ($1.at, $1.id) }
        seats[seat]!.player = replayedPlayer(seat: seat)
        return event.id
    }

    private func replayedPlayer(seat: Int, through: Int = .max, excluding: Int? = nil) -> MP2Player {
        let state = seats[seat]!
        var player = state.base
        for event in state.journal where event.at <= through && event.id != excluding {
            apply(event, to: &player)
        }
        return player
    }

    private func apply(_ event: Event, to player: inout MP2Player) {
        switch event.outcome {
        case .baseline:
            if player.challengeBaselineHits == nil { player.challengeBaselineHits = player.hits }
        case .out:
            player.lives = 0
            player.outAtMs = event.at
            player.multiplier = 1
            player.streakProgress = 0
        case .hit(let reaction, let window):
            guard !player.isOut, event.at >= player.recoveryUntilMs else { return }
            player.score +=
                ReactionScoring.points(
                    reactionMilliseconds: Double(reaction), responseWindowMilliseconds: Double(window),
                    configuration: configuration
                ) * player.multiplier
            player.hits += 1
            player.reactionTotalMs += reaction
            player.fastestReactionMs = min(player.fastestReactionMs ?? reaction, reaction)
            let rating = SpeedRating.classify(reactionMilliseconds: Double(reaction)).rating
            player.streakProgress += configuration.streak.ratingSteps[rating, default: 0]
            while player.streakProgress >= configuration.streak.stepsPerMultiplier,
                player.multiplier < configuration.streak.maximumMultiplier
            {
                player.multiplier += 1
                player.streakProgress -= configuration.streak.stepsPerMultiplier
            }
            if player.multiplier == configuration.streak.maximumMultiplier {
                player.streakProgress = configuration.streak.stepsPerMultiplier
            }
        case .mistake:
            guard !player.isOut, event.at >= player.recoveryUntilMs else { return }
            player.lives -= 1
            player.misses += 1
            if player.isOut { player.outAtMs = event.at }
            player.multiplier = 1
            player.streakProgress = 0
            player.recoveryUntilMs = event.at + configuration.lifeLossRecoveryMilliseconds
        case .dodge(let activatedAt):
            guard !player.isOut, player.recoveryUntilMs <= activatedAt else { return }
            player.dodges += 1
            player.score += configuration.dodgePoints
        }
    }

    private mutating func pruneHistory() {
        let cutoff = elapsedMs - journalHorizonMs
        for seat in seats.keys.sorted() {
            let settled = seats[seat]!.journal.filter { $0.at < cutoff }
            var base = seats[seat]!.base
            for event in settled { apply(event, to: &base) }
            seats[seat]!.base = base
            seats[seat]!.journal.removeAll { $0.at < cutoff }
        }
        targets = targets.filter { _, record in
            if case .open = record.resolution { return true }
            return record.target.expiresAtMs + finalAdmissionMs >= elapsedMs
        }
    }

    private func receipt(_ input: MP2Input, _ accepted: Bool, _ reason: String) -> MP2InputReceipt {
        MP2InputReceipt(id: input.id, accepted: accepted, reason: reason, revision: revision)
    }

    private mutating func sample(_ range: DelayRange) -> Int {
        let unit = Double(nextRandom() >> 11) / 9_007_199_254_740_992.0
        return jsRound(Double(range.minimum) + unit * Double(range.maximum - range.minimum))
    }

    private mutating func randomIndex(_ count: Int) -> Int { Int(nextRandom() % UInt64(count)) }

    private mutating func nextRandom() -> UInt64 {
        randomState &+= 0x9E37_79B9_7F4A_7C15
        var value = randomState
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
