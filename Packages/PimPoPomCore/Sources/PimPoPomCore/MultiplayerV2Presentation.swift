/// The exact target and first-visible clock that won a cell at an original contact.
public struct MP2PresentedTarget: Equatable, Sendable {
    public let target: MP2Target
    public let firstVisibleAtMs: Int
    public var responseDeadlineMs: Int { firstVisibleAtMs + target.responseWindowMs }
}

/// Client presentation history, independent of UI, networking, and clock acquisition.
/// Call `presented` only from an actual render frame, using the match-relative clock.
public struct MP2PresentationLedger: Sendable {
    private struct Record: Sendable {
        let target: MP2Target
        var firstVisibleAtMs: Int?
        var retired = false
    }

    private struct Interval: Sendable {
        let targetID: Int
        let cell: Int
        let from: Int
        var until: Int?
    }

    public static let maximumRetainedTargets = 256
    public static let maximumRetainedIntervals = 512
    public let historyMs: Int
    public private(set) var currentCells: [Int: MP2Target] = [:]
    public var currentTargets: [MP2Target] { currentCells.keys.sorted().compactMap { currentCells[$0] } }
    public var retainedTargetCount: Int { records.count }
    public var retainedIntervalCount: Int { intervals.count }
    public var consumedTargetCount: Int { consumed.count }

    private var records: [Int: Record] = [:]
    private var intervals: [Interval] = []
    private var consumed: Set<Int> = []
    private var retiredIDFloor = 0
    private var lastFrameAt: Int?
    private var localSeat: Int?
    private let maximumPresentationDelayMs = 750

    public init(historyMs: Int = MP2Protocol.lateInputGraceMs) {
        self.historyMs = min(MP2Protocol.lateInputGraceMs, max(250, historyMs))
    }

    /// Projects one winner per cell, then records precisely those winning intervals.
    /// Higher immutable target IDs win a conflicting cell. A hidden losing target
    /// never receives a first-visible timestamp and cannot reappear after replacement.
    /// `predictedRecoveryUntil` is for an actual local mistake, not a provisional server expiry.
    @discardableResult
    public mutating func presented(
        targets: [MP2Target], at: Int, localSeat: Int, predictedRecoveryUntil: Int = 0
    ) -> [MP2Target] {
        guard at >= 0, at <= Int.max - 20_000, (0..<4).contains(localSeat) else {
            return currentTargets
        }
        if let previousSeat = self.localSeat, previousSeat != localSeat { reset() }
        guard at >= (lastFrameAt ?? 0) else { return currentTargets }
        self.localSeat = localSeat
        lastFrameAt = at
        var incoming: Set<Int> = []
        // Sort ties as well as IDs so even conflicting source arrays have stable behavior.
        for target in targets.sorted(by: Self.targetOrder).suffix(Self.maximumRetainedTargets)
        where valid(target) && target.activateAtMs <= at {
            if let record = records[target.id] {
                guard record.target == target else { continue }  // IDs never rebind to another cell/window.
            } else {
                guard target.id > retiredIDFloor else { continue }
                records[target.id] = Record(target: target)
            }
            incoming.insert(target.id)
        }

        // Preserve an already visible own window through a provisional server expiry.
        incoming.formUnion(currentTargets.filter { $0.ownerSeat == localSeat }.map(\.id))
        var next: [Int: MP2Target] = [:]
        for id in incoming.sorted(by: >) {
            guard let record = records[id], !record.retired, !consumed.contains(id) else { continue }
            let target = record.target
            let deadline = record.firstVisibleAtMs.map { $0 + target.responseWindowMs }
            let canPresent = deadline.map { at < $0 } ?? (at - target.activateAtMs <= maximumPresentationDelayMs)
            guard canPresent, target.ownerSeat != localSeat || at >= predictedRecoveryUntil else {
                records[id]!.retired = true
                continue
            }
            if next[target.cell] == nil { next[target.cell] = target } else { records[id]!.retired = true }
        }

        for (cell, old) in currentCells where next[cell]?.id != old.id {
            closeInterval(targetID: old.id, at: at)
            records[old.id]?.retired = true
        }
        for (cell, target) in next where currentCells[cell]?.id != target.id {
            if records[target.id]!.firstVisibleAtMs == nil { records[target.id]!.firstVisibleAtMs = at }
            intervals.append(Interval(targetID: target.id, cell: cell, from: at))
        }
        currentCells = next
        prune(at: at)
        return currentTargets
    }

    /// Resolves against actual recorded cell intervals, including targets removed by
    /// a more recent frame. Deadlines are exclusive. Consumed own IDs cannot score twice.
    public func lookup(cell: Int, contactAt: Int) -> MP2PresentedTarget? {
        guard (0..<16).contains(cell), contactAt >= 0, let lastFrameAt,
            contactAt >= lastFrameAt - historyMs
        else { return nil }
        for interval in intervals.reversed() where interval.cell == cell && contactAt >= interval.from {
            guard let record = records[interval.targetID], let firstVisible = record.firstVisibleAtMs else { continue }
            let end = min(interval.until ?? Int.max, firstVisible + record.target.responseWindowMs)
            guard contactAt < end else { continue }
            // A consumed visible interval must not fall through to an older target in the same cell.
            guard !consumed.contains(interval.targetID) else { return nil }
            return MP2PresentedTarget(target: record.target, firstVisibleAtMs: firstVisible)
        }
        return nil
    }

    /// Retires only our own displayed target. Receipt processing must never undo this.
    /// Supplying `at` records the removal time between frames; omitted time uses the last frame.
    @discardableResult
    public mutating func consumeOwn(targetID: Int, at: Int? = nil) -> Bool {
        guard let record = records[targetID], record.firstVisibleAtMs != nil,
            record.target.ownerSeat == localSeat, !consumed.contains(targetID)
        else { return false }
        consumed.insert(targetID)
        records[targetID]!.retired = true
        closeInterval(targetID: targetID, at: max(lastFrameAt ?? 0, at ?? lastFrameAt ?? 0))
        currentCells = currentCells.filter { $0.value.id != targetID }
        return true
    }

    public func firstVisibleAtMs(targetID: Int) -> Int? { records[targetID]?.firstVisibleAtMs }

    public mutating func reset() {
        records.removeAll()
        intervals.removeAll()
        currentCells.removeAll()
        consumed.removeAll()
        retiredIDFloor = 0
        lastFrameAt = nil
        localSeat = nil
    }

    private func valid(_ target: MP2Target) -> Bool {
        (1...MP2Protocol.maximumInputID).contains(target.id) && (0..<16).contains(target.cell)
            && (0..<4).contains(target.ownerSeat) && gameColors.indices.contains(target.colorIndex)
            && (0...MP2Protocol.maximumDurationMs).contains(target.activateAtMs)
            && (1...10_000).contains(target.responseWindowMs)
    }

    private static func targetOrder(_ lhs: MP2Target, _ rhs: MP2Target) -> Bool {
        if lhs.id != rhs.id { return lhs.id < rhs.id }
        if lhs.cell != rhs.cell { return lhs.cell < rhs.cell }
        if lhs.ownerSeat != rhs.ownerSeat { return lhs.ownerSeat < rhs.ownerSeat }
        if lhs.activateAtMs != rhs.activateAtMs { return lhs.activateAtMs < rhs.activateAtMs }
        if lhs.responseWindowMs != rhs.responseWindowMs { return lhs.responseWindowMs < rhs.responseWindowMs }
        return lhs.colorIndex < rhs.colorIndex
    }

    private mutating func closeInterval(targetID: Int, at: Int) {
        guard let index = intervals.lastIndex(where: { $0.targetID == targetID && $0.until == nil }),
            let record = records[targetID], let firstVisible = record.firstVisibleAtMs
        else { return }
        intervals[index].until = min(at, firstVisible + record.target.responseWindowMs)
    }

    private mutating func prune(at: Int) {
        let cutoff = at - historyMs
        intervals.removeAll { interval in
            guard let record = records[interval.targetID], let first = record.firstVisibleAtMs else { return true }
            return min(interval.until ?? Int.max, first + record.target.responseWindowMs) <= cutoff
                || interval.until.map { $0 <= interval.from } == true
        }
        if intervals.count > Self.maximumRetainedIntervals {
            intervals.removeFirst(intervals.count - Self.maximumRetainedIntervals)
        }
        let visible = Set(currentTargets.map(\.id))
        var expired = records.values.filter { record in
            guard !visible.contains(record.target.id) else { return false }
            let end =
                record.firstVisibleAtMs.map { $0 + record.target.responseWindowMs }
                ?? (record.target.activateAtMs + maximumPresentationDelayMs)
            return end <= cutoff
        }.map { $0.target.id }
        if records.count - expired.count > Self.maximumRetainedTargets {
            let alreadyExpired = Set(expired)
            let overflow = records.keys.sorted().filter { !visible.contains($0) && !alreadyExpired.contains($0) }
            expired.append(contentsOf: overflow.prefix(records.count - expired.count - Self.maximumRetainedTargets))
        }
        for id in expired {
            records.removeValue(forKey: id)
            consumed.remove(id)
            retiredIDFloor = max(retiredIDFloor, id)
        }
        intervals.removeAll { records[$0.targetID] == nil }
    }
}
