import Testing

@testable import PimPoPomCore

private func mp2VisualTarget(_ id: Int, cell: Int = 0, owner: Int = 0, at: Int = 100, window: Int = 1_000) -> MP2Target
{
    MP2Target(id: id, cell: cell, ownerSeat: owner, colorIndex: owner, activateAtMs: at, responseWindowMs: window)
}

@Test("MP2 presentation records only the first actual visible frame and preserves an own provisional expiry")
func mp2PresentationFirstFrame() {
    var ledger = MP2PresentationLedger()
    let target = mp2VisualTarget(1)
    ledger.presented(targets: [target], at: 50, localSeat: 0)
    #expect(ledger.currentTargets.isEmpty)
    #expect(ledger.firstVisibleAtMs(targetID: 1) == nil)
    ledger.presented(targets: [target], at: 120, localSeat: 0)
    #expect(ledger.firstVisibleAtMs(targetID: 1) == 120)
    ledger.presented(targets: [], at: 1_110, localSeat: 0)
    #expect(ledger.currentTargets == [target])
    #expect(ledger.lookup(cell: 0, contactAt: 1_119)?.firstVisibleAtMs == 120)
    ledger.presented(targets: [], at: 1_120, localSeat: 0)
    #expect(ledger.currentTargets.isEmpty)
    #expect(ledger.lookup(cell: 0, contactAt: 1_120) == nil)
}

@Test("MP2 delayed UIKit contact still resolves the expired target that was visible at contact")
func mp2PresentationDelayedContact() {
    var ledger = MP2PresentationLedger()
    let target = mp2VisualTarget(1)
    ledger.presented(targets: [target], at: 100, localSeat: 0)
    ledger.presented(targets: [], at: 1_200, localSeat: 0)
    #expect(ledger.currentTargets.isEmpty)
    let original = ledger.lookup(cell: 0, contactAt: 1_050)
    #expect(original?.target.id == 1)
    #expect(original?.firstVisibleAtMs == 100)
    #expect(original?.responseDeadlineMs == 1_100)
    #expect(ledger.lookup(cell: 0, contactAt: 1_100) == nil)
}

@Test("MP2 wrong-color taps never consume a remote tile; own consumed IDs survive receipts and stale snapshots")
func mp2PresentationConsumption() {
    var ledger = MP2PresentationLedger()
    let own = mp2VisualTarget(1)
    let remote = mp2VisualTarget(2, cell: 1, owner: 1)
    ledger.presented(targets: [own, remote], at: 100, localSeat: 0)
    let remoteConsumed = ledger.consumeOwn(targetID: remote.id, at: 150)
    #expect(!remoteConsumed)
    #expect(ledger.currentCells[1] == remote)
    #expect(ledger.lookup(cell: 1, contactAt: 150)?.target == remote)
    let ownConsumed = ledger.consumeOwn(targetID: own.id, at: 150)
    #expect(ownConsumed)
    ledger.presented(targets: [own, remote], at: 200, localSeat: 0)
    #expect(ledger.currentCells[0] == nil)
    #expect(ledger.lookup(cell: 0, contactAt: 140) == nil)
    let duplicateConsumed = ledger.consumeOwn(targetID: own.id)
    #expect(!duplicateConsumed)
    #expect(ledger.currentCells[1] == remote)
}

@Test("MP2 cell replacement records the same deterministic winner for rendering and original-contact lookup")
func mp2PresentationReplacement() {
    var ledger = MP2PresentationLedger()
    let old = mp2VisualTarget(1)
    let newer = mp2VisualTarget(2, owner: 1, at: 200)
    ledger.presented(targets: [old], at: 100, localSeat: 0)
    ledger.presented(targets: [newer, old], at: 200, localSeat: 0)
    #expect(ledger.currentCells[0] == newer)
    #expect(ledger.lookup(cell: 0, contactAt: 199)?.target == old)
    #expect(ledger.lookup(cell: 0, contactAt: 200)?.target == newer)
    ledger.presented(targets: [old], at: 300, localSeat: 0)
    #expect(ledger.currentCells[0] == nil)
    #expect(ledger.lookup(cell: 0, contactAt: 250)?.target == newer)
    #expect(ledger.lookup(cell: 0, contactAt: 300) == nil)
}

@Test("MP2 same-frame conflicts timestamp only the displayed winner and never rebind an existing identity")
func mp2PresentationSameFrame() {
    var left = MP2PresentationLedger()
    var right = MP2PresentationLedger()
    let first = mp2VisualTarget(1)
    let second = mp2VisualTarget(2, owner: 1)
    left.presented(targets: [first, second], at: 100, localSeat: 0)
    right.presented(targets: [second, first], at: 100, localSeat: 0)
    #expect(left.currentCells == right.currentCells)
    #expect(left.firstVisibleAtMs(targetID: 1) == nil)
    #expect(left.lookup(cell: 0, contactAt: 100)?.target == second)
    left.presented(targets: [mp2VisualTarget(2, cell: 3, owner: 1)], at: 200, localSeat: 0)
    #expect(left.currentCells[3] == nil)
    #expect(left.lookup(cell: 0, contactAt: 150)?.target == second)
    var sameTime = MP2PresentationLedger()
    sameTime.presented(targets: [first], at: 100, localSeat: 0)
    sameTime.presented(targets: [second], at: 100, localSeat: 0)
    #expect(sameTime.currentCells[0] == second)
    #expect(sameTime.lookup(cell: 0, contactAt: 100)?.target == second)
    #expect(sameTime.lookup(cell: 0, contactAt: 99) == nil)
}

@Test("MP2 predicted personal recovery clears own presentation while other seats keep their windows")
func mp2PresentationRecovery() {
    var ledger = MP2PresentationLedger()
    let own = mp2VisualTarget(1)
    let remote = mp2VisualTarget(2, cell: 1, owner: 1)
    ledger.presented(targets: [own, remote], at: 100, localSeat: 0)
    ledger.presented(targets: [own, remote], at: 200, localSeat: 0, predictedRecoveryUntil: 1_700)
    #expect(ledger.currentTargets == [remote])
    #expect(ledger.lookup(cell: 0, contactAt: 199)?.target == own)
    #expect(ledger.lookup(cell: 0, contactAt: 200) == nil)
    #expect(ledger.lookup(cell: 1, contactAt: 300)?.target == remote)
}

@Test("MP2 presentation history expires, remains memory bounded, fences retired IDs, and resets for a new match")
func mp2PresentationBounds() {
    var ledger = MP2PresentationLedger(historyMs: 100_000)
    #expect(ledger.historyMs == 2_000)
    for id in 1...2_000 {
        let at = id + 100
        ledger.presented(targets: [mp2VisualTarget(id, at: at)], at: at, localSeat: 0)
        let consumed = ledger.consumeOwn(targetID: id)
        #expect(consumed)
        #expect(ledger.retainedTargetCount <= MP2PresentationLedger.maximumRetainedTargets)
        #expect(ledger.retainedIntervalCount <= MP2PresentationLedger.maximumRetainedIntervals)
        #expect(ledger.consumedTargetCount <= MP2PresentationLedger.maximumRetainedTargets)
    }
    ledger.presented(targets: [], at: 5_200, localSeat: 0)
    #expect(ledger.retainedTargetCount == 0)
    #expect(ledger.retainedIntervalCount == 0)
    #expect(ledger.consumedTargetCount == 0)
    ledger.presented(targets: [mp2VisualTarget(1, at: 5_200)], at: 5_200, localSeat: 0)
    #expect(ledger.currentTargets.isEmpty)
    ledger.reset()
    ledger.presented(targets: [mp2VisualTarget(1)], at: 100, localSeat: 0)
    #expect(ledger.lookup(cell: 0, contactAt: 110)?.target.id == 1)
    ledger.presented(targets: [], at: 3_101, localSeat: 0)
    #expect(ledger.lookup(cell: 0, contactAt: 110) == nil)
    ledger.reset()
    let oversized = (1...2_000).map { mp2VisualTarget($0, cell: $0 % 16) }
    ledger.presented(targets: oversized, at: 100, localSeat: 0)
    #expect(ledger.retainedTargetCount <= MP2PresentationLedger.maximumRetainedTargets)
    #expect(ledger.currentTargets.count == 16)
}

@Test("MP2 ignores regressing frames and does not invent visibility for an excessively late first presentation")
func mp2PresentationClockBounds() {
    var ledger = MP2PresentationLedger()
    let target = mp2VisualTarget(1)
    ledger.presented(targets: [target], at: 851, localSeat: 0)
    #expect(ledger.currentTargets.isEmpty)
    ledger.presented(targets: [target], at: 100, localSeat: 0)
    #expect(ledger.currentTargets.isEmpty)
    #expect(ledger.lookup(cell: -1, contactAt: 100) == nil)
}
