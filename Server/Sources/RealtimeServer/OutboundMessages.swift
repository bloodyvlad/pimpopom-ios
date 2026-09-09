import PimPoPomCore
import Synchronization

/// One writer consumes this bounded FIFO. Consecutive periodic snapshots replace
/// their predecessor; Ready, activation and input acknowledgements retain order.
public final class OutboundMessages: AsyncSequence, Sendable {
    public typealias Element = MP2ServerMessage
    public enum YieldResult { case enqueued, dropped, terminated }
    struct Entry: Sendable {
        let message: MP2ServerMessage
        let coalescible: Bool
    }
    struct State: Sendable {
        var pending: [Entry] = []
        var waiter: CheckedContinuation<MP2ServerMessage?, Never>?
        var finished = false
    }
    private let state = Mutex(State())
    private let capacity: Int
    public init(capacity: Int = 64) { self.capacity = Swift.max(1, capacity) }

    @discardableResult
    public func yield(_ message: MP2ServerMessage, coalescible: Bool = false) -> YieldResult {
        state.withLock { value in
            guard !value.finished else { return .terminated }
            if let waiter = value.waiter {
                value.waiter = nil
                waiter.resume(returning: message)
                return .enqueued
            }
            if coalescible, value.pending.last?.coalescible == true {
                value.pending[value.pending.count - 1] = Entry(message: message, coalescible: true)
                return .enqueued
            }
            guard value.pending.count < capacity else { return .dropped }
            value.pending.append(Entry(message: message, coalescible: coalescible))
            return .enqueued
        }
    }

    public func finish() {
        state.withLock { value in
            value.finished = true
            value.waiter?.resume(returning: nil)
            value.waiter = nil
        }
    }

    private func next() async -> MP2ServerMessage? {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                state.withLock { value in
                    if !value.pending.isEmpty {
                        continuation.resume(returning: value.pending.removeFirst().message)
                    } else if value.finished {
                        continuation.resume(returning: nil)
                    } else {
                        value.waiter = continuation
                    }
                }
            }
        } onCancel: {
            self.finish()
        }
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        let channel: OutboundMessages
        public mutating func next() async -> MP2ServerMessage? { await channel.next() }
    }
    public func makeAsyncIterator() -> AsyncIterator { AsyncIterator(channel: self) }
}
