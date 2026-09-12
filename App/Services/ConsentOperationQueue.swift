import Foundation

/// UMP owns process-wide state: a superseded request must finish before the
/// replacement updates that state. Generation checks also fence form presentation.
@MainActor
final class ConsentOperationQueue {
    private var pending: Task<ConsentSnapshot, Error>?
    private var operationID = 0
    private(set) var generation = 0

    func invalidate() { generation += 1 }

    func check(_ expected: Int) throws {
        guard generation == expected else { throw CancellationError() }
    }

    func run(
        _ operation: @escaping @MainActor (Int) async throws -> ConsentSnapshot
    ) async throws -> ConsentSnapshot {
        let previous = pending
        let expected = generation
        operationID += 1
        let identifier = operationID
        let task = Task { @MainActor in
            _ = try? await previous?.value
            try self.check(expected)
            let result = try await operation(expected)
            try self.check(expected)
            return result
        }
        pending = task
        defer {
            if identifier == operationID { pending = nil }
        }
        return try await task.value
    }
}
