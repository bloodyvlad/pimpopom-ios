import Foundation
import Testing

@testable import RealtimeServer

struct ResultOutboxPreparationTests {
    @Test func preparationPreservesEvidenceAndRemovesOnlyItsProbe() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let outbox = ResultOutbox(directory: directory)
        try await outbox.prepare()
        let archive = directory.appendingPathComponent("delivered")
        let pending = directory.appendingPathComponent(UUID().uuidString + ".json")
        let delivered = archive.appendingPathComponent(UUID().uuidString + ".json")
        let contents = Data("existing immutable evidence".utf8)
        try contents.write(to: pending)
        try contents.write(to: delivered)
        try await outbox.prepare()
        try await outbox.prepare()
        #expect(try Data(contentsOf: pending) == contents)
        #expect(try Data(contentsOf: delivered) == contents)
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
                == [pending.lastPathComponent, "delivered"].sorted())
        #expect(try FileManager.default.contentsOfDirectory(atPath: archive.path) == [delivered.lastPathComponent])
    }

    @Test(arguments: [false, true]) func preparationRejectsSymlinkWithoutTouchingTarget(archiveLink: Bool) async throws
    {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = FileManager.default
        let target = directory.appendingPathComponent("outside")
        let outbox = directory.appendingPathComponent("outbox")
        try manager.createDirectory(at: target, withIntermediateDirectories: true)
        let evidence = target.appendingPathComponent("sentinel.json")
        let contents = Data("preserve symlink target".utf8)
        try contents.write(to: evidence)
        let link: URL
        if archiveLink {
            try manager.createDirectory(at: outbox, withIntermediateDirectories: true)
            link = outbox.appendingPathComponent("delivered")
        } else {
            link = outbox
        }
        try manager.createSymbolicLink(at: link, withDestinationURL: target)
        await #expect(throws: ResultOutbox.OutboxError.self) { try await ResultOutbox(directory: outbox).prepare() }
        #expect(try Data(contentsOf: evidence) == contents)
        #expect(try manager.contentsOfDirectory(atPath: target.path) == ["sentinel.json"])
        #expect(try manager.destinationOfSymbolicLink(atPath: link.path) == target.path)
    }

    @Test(arguments: [false, true]) func preparationRejectsFileWithoutChangingEvidence(archiveFile: Bool) async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let outbox = directory.appendingPathComponent("outbox")
        let file: URL
        if archiveFile {
            try manager.createDirectory(at: outbox, withIntermediateDirectories: true)
            file = outbox.appendingPathComponent("delivered")
        } else {
            file = outbox
        }
        let contents = Data("do not replace existing data".utf8)
        try contents.write(to: file)
        await #expect(throws: (any Error).self) { try await ResultOutbox(directory: outbox).prepare() }
        #expect(try Data(contentsOf: file) == contents)
        #expect(try manager.contentsOfDirectory(atPath: directory.path) == ["outbox"])
        if archiveFile { #expect(try manager.contentsOfDirectory(atPath: outbox.path) == ["delivered"]) }
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("mp2-readiness-test-" + UUID().uuidString)
    }
}
