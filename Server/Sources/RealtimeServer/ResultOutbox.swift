import Foundation
import PimPoPomCore

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public struct CompletedMatch: Codable, Equatable, Sendable {
    public struct Player: Codable, Equatable, Sendable {
        public let playerID: String
        public let seat: Int
        public let score: Int
        public let lives: Int
        public let hits: Int
        public let misses: Int
        public let dodges: Int
        public let reactionTotalMs: Int
        public let fastestReactionMs: Int?

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(playerID, forKey: .playerID)
            try container.encode(seat, forKey: .seat)
            try container.encode(score, forKey: .score)
            try container.encode(lives, forKey: .lives)
            try container.encode(hits, forKey: .hits)
            try container.encode(misses, forKey: .misses)
            try container.encode(dodges, forKey: .dodges)
            try container.encode(reactionTotalMs, forKey: .reactionTotalMs)
            try container.encode(fastestReactionMs, forKey: .fastestReactionMs)
        }
    }
    public let matchID: String
    public let protocolVersion: Int
    public let ruleset: String
    public let durationMs: Int
    public let rankingEligible: Bool
    public let players: [Player]

    public init(snapshot: MP2Snapshot) {
        matchID = snapshot.matchID
        protocolVersion = MP2Protocol.version
        ruleset = MP2Protocol.ruleset
        durationMs = min(snapshot.elapsedMs, MP2Protocol.maximumDurationMs)
        rankingEligible = false
        players = snapshot.players.sorted { $0.seat < $1.seat }.map {
            Player(
                playerID: $0.id, seat: $0.seat, score: $0.score, lives: $0.lives,
                hits: $0.hits, misses: $0.misses, dodges: $0.dodges,
                reactionTotalMs: $0.reactionTotalMs, fastestReactionMs: $0.fastestReactionMs)
        }
    }
}

/// Safety: immutable URL and queue, and every filesystem operation runs on the
/// one private serial queue. No file handles or mutable state escape that queue.
/// Replace this adapter with an async filesystem API when one is adopted.
public final class ResultOutbox: @unchecked Sendable {
    let directory: URL
    let queue = DispatchQueue(label: "pimpopom.multiplayer-v2.result-outbox", qos: .utility)
    public static let maximumEntries = 1_000
    public static let retentionSeconds: TimeInterval = 30 * 24 * 3600
    public enum OutboxError: Error { case full, conflictingResult, invalidMatchID }

    public init(directory: URL) { self.directory = directory }

    public func store(_ match: CompletedMatch) async throws {
        guard UUID(uuidString: match.matchID) != nil else { throw OutboxError.invalidMatchID }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(match)
        try await perform {
            let manager = FileManager.default
            try manager.createDirectory(at: self.directory, withIntermediateDirectories: true)
            let url = self.directory.appendingPathComponent(match.matchID + ".json")
            if manager.fileExists(atPath: url.path) {
                guard try Data(contentsOf: url) == data else { throw OutboxError.conflictingResult }
                return
            }
            // Never evict an undelivered result to create room for another one.
            let existing = try manager.contentsOfDirectory(at: self.directory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
            guard existing.count < Self.maximumEntries else { throw OutboxError.full }
            try data.write(to: url, options: .atomic)
        }
    }

    public func pending() async throws -> [URL] {
        try await perform {
            try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
            return try FileManager.default.contentsOfDirectory(at: self.directory, includingPropertiesForKeys: nil)
                .filter {
                    $0.pathExtension == "json" && UUID(uuidString: $0.deletingPathExtension().lastPathComponent) != nil
                }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        }
    }

    public func deliverPending(configuration: ServerConfiguration) async throws {
        guard let endpoint = configuration.resultsURL, let key = configuration.serviceKey else { return }
        for url in try await pending() {
            try Task.checkCancellation()
            let data = try await perform { try Data(contentsOf: url) }
            var request = URLRequest(url: endpoint, timeoutInterval: 5)
            request.httpMethod = "POST"
            request.httpBody = data
            request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let (reply, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                continue
            }
            struct Acknowledgement: Decodable {
                let matchID: String
                let rankingEligible: Bool
                let state: String
            }
            guard reply.count <= 16_384,
                let acknowledgement = try? JSONDecoder().decode(Acknowledgement.self, from: reply),
                acknowledgement.matchID == url.deletingPathExtension().lastPathComponent,
                acknowledgement.rankingEligible == false, acknowledgement.state == "stored_unranked"
            else { continue }
            try await perform {
                // Acknowledged evidence remains recoverable in a bounded archive.
                let archive = self.directory.appendingPathComponent("delivered", isDirectory: true)
                try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
                let target = archive.appendingPathComponent(url.lastPathComponent)
                if !FileManager.default.fileExists(atPath: target.path) {
                    try FileManager.default.moveItem(at: url, to: target)
                } else if try Data(contentsOf: target) == data {
                    try FileManager.default.removeItem(at: url)
                }
                let files = try FileManager.default.contentsOfDirectory(
                    at: archive, includingPropertiesForKeys: [.contentModificationDateKey]
                )
                .filter { $0.pathExtension == "json" }.sorted {
                    let left =
                        (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                        ?? .distantPast
                    let right =
                        (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                        ?? .distantPast
                    return left > right
                }
                for (index, file) in files.enumerated() {
                    let date =
                        (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                        ?? .distantPast
                    if index >= Self.maximumEntries || Date().timeIntervalSince(date) > Self.retentionSeconds {
                        try FileManager.default.removeItem(at: file)
                    }
                }
            }
        }
    }

    private func perform<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do { continuation.resume(returning: try operation()) } catch { continuation.resume(throwing: error) }
            }
        }
    }
}
