import Foundation
import PimPoPomCore
import Synchronization
import Testing

@testable import RealtimeServer

struct RoomSearchTests {
    func service(code: (@Sendable () -> String)? = nil) throws -> RoomService {
        var config = try ServerConfiguration(environment: ["MP2_DEV_AUTH": "1"])
        config.idleConnectionMs = 1_000_000
        let results = AsyncStream<CompletedMatch>.makeStream(bufferingPolicy: .bufferingOldest(128))
        return RoomService(
            configuration: config, resultOutput: results.continuation, randomSeed: { 42 }, roomCodeCandidate: code)
    }

    func connect(_ service: RoomService, _ id: String, revision: Int = 2) async throws -> OutboundMessages {
        try await RoomDirectoryTests().connect(service, id: id, revision: revision)
    }

    func messages(_ output: OutboundMessages) async -> [MP2ServerMessage] {
        output.finish()
        var messages: [MP2ServerMessage] = []
        for await message in output { messages.append(message) }
        return messages
    }

    @Test func oldCreateAndRoomPayloadsRemainCompatible() throws {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        #expect(
            try decoder.decode(MP2ClientMessage.self, from: Data(#"{"create":{"capacity":3}}"#.utf8))
                == .create(capacity: 3))
        let oldRoom = Data(
            #"{"id":"room","epoch":"epoch","revision":1,"rosterRevision":1,"hostPlayerID":"host","capacity":3,"phase":"waiting","players":[]}"#
                .utf8)
        let room = try decoder.decode(MP2Room.self, from: oldRoom)
        #expect(room.roomCode == nil && room.isPrivate == nil)
        let oldSummary = Data(
            #"{"id":"room","hostName":"Host","capacity":3,"playerCount":1,"revision":1,"phase":"waiting"}"#.utf8)
        let summary = try decoder.decode(MP2RoomSummary.self, from: oldSummary)
        #expect(summary.roomCode == nil && summary.isPrivate == nil)

        enum LegacyClient: Codable, Equatable { case create(capacity: Int) }
        #expect(
            try decoder.decode(
                LegacyClient.self, from: encoder.encode(MP2ClientMessage.create(capacity: 3, isPrivate: true)))
                == .create(capacity: 3))
        for message in [
            MP2ClientMessage.create(capacity: 4, isPrivate: true), .search(query: "ABCD2345", requestID: 12),
        ] {
            #expect(try decoder.decode(MP2ClientMessage.self, from: encoder.encode(message)) == message)
        }
        let revised = MP2RoomSummary(
            id: "room", hostName: "Host", capacity: 3, playerCount: 1, revision: 1, phase: .waiting,
            gameplayRevision: 2, roomCode: "ABCD2345", isPrivate: true)
        let response = MP2ServerMessage.searchResults(query: "abcd2345", requestID: 12, rooms: [revised])
        #expect(try decoder.decode(MP2ServerMessage.self, from: encoder.encode(response)) == response)
        struct LegacySummary: Decodable {
            let id: String
            let hostName: String
            let capacity: Int
            let playerCount: Int
            let revision: Int
            let phase: MP2RoomPhase
            let gameplayRevision: Int?
        }
        #expect(try decoder.decode(LegacySummary.self, from: encoder.encode(revised)).id == revised.id)
        let oldWelcome = Data(
            #"{"welcome":{"playerID":"player","connectionID":"connection","serverTimeMs":1,"gameplayRevision":2}}"#.utf8
        )
        #expect(
            try decoder.decode(MP2ServerMessage.self, from: oldWelcome)
                == .welcome(playerID: "player", connectionID: "connection", serverTimeMs: 1, gameplayRevision: 2))
        enum LegacyServer: Codable, Equatable {
            case welcome(playerID: String, connectionID: String, serverTimeMs: Int, gameplayRevision: Int?)
        }
        let newWelcome = MP2ServerMessage.welcome(
            playerID: "player", connectionID: "connection", serverTimeMs: 1, gameplayRevision: 2,
            roomDiscoveryRevision: MP2Protocol.roomDiscoveryRevision)
        #expect(
            try decoder.decode(LegacyServer.self, from: encoder.encode(newWelcome))
                == .welcome(playerID: "player", connectionID: "connection", serverTimeMs: 1, gameplayRevision: 2))
        #expect(try decoder.decode(MP2ServerMessage.self, from: encoder.encode(newWelcome)) == newWelcome)
    }

    @Test func authenticatedWelcomeAdvertisesDiscoveryIndependentlyOfGameplay() async throws {
        let service = try service()
        for revision in [1, 2] {
            let output = try await connect(service, "player-\(revision)", revision: revision)
            let all = await messages(output)
            let welcome = try #require(all.first)
            #expect(
                welcome
                    == .welcome(
                        playerID: "player-\(revision)", connectionID: "player-\(revision)", serverTimeMs: 0,
                        gameplayRevision: revision, roomDiscoveryRevision: 1))
            #expect(all.allSatisfy { if case .searchResults = $0 { false } else { true } })
        }
    }

    @Test func legacyCreateWithoutPrivacyFieldCreatesPublicRoomWithCode() async throws {
        let service = try service(code: { "ABCD2345" })
        let host = try await connect(service, "legacy", revision: 1)
        let observer = try await connect(service, "observer", revision: 1)
        let create = try JSONDecoder().decode(MP2ClientMessage.self, from: Data(#"{"create":{"capacity":3}}"#.utf8))
        await service.receive(create, from: "legacy", now: 1)
        let roomID = try #require(await service.connections["legacy"]?.roomID)
        let room = try #require(await service.rooms[roomID]?.value)
        #expect(room.roomCode == "ABCD2345" && room.isPrivate == false)
        #expect(room.gameplayRevision == 1)
        let summary = try #require(await service.directory(gameplayRevision: 1).first)
        #expect(summary.id == roomID && summary.roomCode == "ABCD2345" && summary.isPrivate == false)
        for output in [host, observer] {
            #expect(await messages(output).allSatisfy { if case .searchResults = $0 { false } else { true } })
        }
    }

    @Test func codeAlphabetIsUnambiguousAndGenerationHasFixedShape() {
        #expect(RoomCode.alphabet.count == 32)
        #expect(Set(RoomCode.alphabet).count == 32)
        #expect(Set("01IO").isDisjoint(with: RoomCode.alphabet))
        for _ in 0..<128 { #expect(RoomCode.isValid(RoomCode.generate())) }
        for invalid in ["", "ABC", "abcd2345", "ABCD23450", "ABCD23I5", "ABCD23O5", "ABCD2305", "ABCD2315", "ÁBCD2345"]
        {
            #expect(!RoomCode.isValid(invalid))
        }
    }

    @Test func codeCollisionRetriesWithoutSharingAnotherRoomCode() async throws {
        let candidates = Mutex(["ABCD2345", "ABCD2345", "WXYZ6789"])
        let service = try service(code: { candidates.withLock { $0.removeFirst() } })
        _ = try await connect(service, "first")
        _ = try await connect(service, "second")
        await service.receive(.create(capacity: 2), from: "first", now: 1)
        await service.receive(.create(capacity: 2, isPrivate: true), from: "second", now: 2)
        let first = try #require(await service.connections["first"]?.roomID)
        let second = try #require(await service.connections["second"]?.roomID)
        #expect(await service.rooms[first]?.value.roomCode == "ABCD2345")
        #expect(await service.rooms[second]?.value.roomCode == "WXYZ6789")
        #expect(candidates.withLock { $0.isEmpty })
    }

    @Test func exhaustedCollisionBudgetFailsWithoutCreatingDuplicateRoom() async throws {
        let calls = Mutex(0)
        let service = try service(code: {
            calls.withLock { $0 += 1 }
            return "ABCD2345"
        })
        _ = try await connect(service, "first")
        let second = try await connect(service, "second")
        await service.receive(.create(capacity: 2), from: "first", now: 1)
        await service.receive(.create(capacity: 2), from: "second", now: 2)
        #expect(calls.withLock { $0 } == 33)
        #expect(await service.rooms.count == 1)
        #expect(await service.connections["second"]?.roomID == nil)
        #expect(
            await messages(second).contains {
                if case .error(code: "cannot_create", message: _) = $0 { true } else { false }
            })
    }

    @Test func privateRoomsAreHiddenFromEveryListAndNicknameOrPrefixSearch() async throws {
        let service = try service(code: { "ABCD2345" })
        let observer = try await connect(service, "observer")
        let legacy = try await connect(service, "legacy", revision: 1)
        _ = try await connect(service, "PrivateCreator")
        await service.receive(.create(capacity: 4, isPrivate: true), from: "PrivateCreator", now: 1)
        let roomID = try #require(await service.connections["PrivateCreator"]?.roomID)
        #expect(await service.directory(gameplayRevision: 2).isEmpty)
        for (index, query) in ["", "PrivateCreator", "creator", "ABCD", String(roomID.prefix(8)), "ABCD2345extra"]
            .enumerated()
        {
            await service.receive(.search(query: query, requestID: index), from: "observer", now: index + 2)
            #expect(await service.connections["observer"]?.search?.results.isEmpty == true)
        }
        for query in [" abcd2345\n", roomID.uppercased()] {
            #expect(await service.searchRooms(query: query, gameplayRevision: 2).map(\.id) == [roomID])
            #expect(await service.searchRooms(query: query, gameplayRevision: 1).isEmpty)
        }
        await service.receive(.list, from: "observer", now: 20)
        for output in [observer, legacy] {
            for message in await messages(output) {
                if case .list(let rooms) = message { #expect(rooms.isEmpty) }
            }
        }
        #expect(await service.connections["observer"]?.search == nil)
    }

    @Test func publicNicknameSearchIsCaseInsensitiveTrimmedAndDoesNotCrossRevisions() async throws {
        let service = try service()
        for name in ["ÅLENKA", "Other", "observer"] { _ = try await connect(service, name) }
        _ = try await connect(service, "oldÅLENKA", revision: 1)
        for name in ["ÅLENKA", "Other", "oldÅLENKA"] { await service.receive(.create(capacity: 3), from: name, now: 1) }
        let roomID = try #require(await service.connections["ÅLENKA"]?.roomID)
        await service.receive(.search(query: "  åle\n", requestID: 10), from: "observer", now: 2)
        #expect(await service.connections["observer"]?.search?.query == "åle")
        #expect(await service.connections["observer"]?.search?.results.map(\.id) == [roomID])
        let room = try #require(await service.rooms[roomID]?.value)
        #expect(room.isPrivate == false)
        #expect(
            await service.searchRooms(query: try #require(room.roomCode).lowercased(), gameplayRevision: 2).map(\.id)
                == [roomID])
        #expect(await service.searchRooms(query: "", gameplayRevision: 2).count == 2)
    }

    @Test func exactPrivateCodeAndUUIDJoinKeepStableRoomIdentity() async throws {
        let service = try service(code: { "ABCD2345" })
        for id in ["host", "guest", "third", "invalid"] { _ = try await connect(service, id) }
        await service.receive(.create(capacity: 4, isPrivate: true), from: "host", now: 1)
        let roomID = try #require(await service.connections["host"]?.roomID)
        let epoch = try #require(await service.rooms[roomID]?.value.epoch)
        for invalid in ["ABC", "host", "ABCD234", "ABCD2345X"] {
            await service.receive(.join(roomID: invalid), from: "invalid", now: 2)
            #expect(await service.connections["invalid"]?.roomID == nil)
        }
        await service.receive(.join(roomID: "  abcd2345\n"), from: "guest", now: 3)
        await service.receive(.join(roomID: roomID.uppercased()), from: "third", now: 4)
        #expect(await service.connections["guest"]?.roomID == roomID)
        #expect(await service.connections["third"]?.roomID == roomID)
        await service.receive(.leave, from: "host", now: 5)
        #expect(await service.rooms[roomID]?.value.hostPlayerID == "guest")
        #expect(await service.rooms[roomID]?.value.roomCode == "ABCD2345")
        #expect(await service.rooms[roomID]?.value.epoch == epoch)
        #expect(await service.rooms[roomID]?.value.isPrivate == true)
        #expect(await service.directory(gameplayRevision: 2).isEmpty)
    }

    @Test func privateSearchPushesFullDisconnectResumeAndLeaveWithoutDirectoryChanges() async throws {
        let service = try service(code: { "ABCD2345" })
        let observer = try await connect(service, "observer")
        for id in ["host", "guest"] { _ = try await connect(service, id) }
        await service.receive(.search(query: "abcd2345", requestID: 10), from: "observer", now: 1)
        await service.receive(.create(capacity: 2, isPrivate: true), from: "host", now: 2)
        let roomID = try #require(await service.connections["host"]?.roomID)
        #expect(await service.connections["observer"]?.search?.results.map(\.id) == [roomID])
        await service.receive(.join(roomID: "ABCD2345"), from: "guest", now: 3)
        #expect(await service.connections["observer"]?.search?.results.isEmpty == true)
        await service.receive(.leave, from: "guest", now: 4)
        #expect(await service.connections["observer"]?.search?.results.map(\.id) == [roomID])
        let credential = try #require(await service.rooms[roomID]?.presence["host"]?.credential)
        await service.disconnect(id: "host", now: 5)
        #expect(await service.connections["observer"]?.search?.results.isEmpty == true)
        _ = try await RoomDirectoryTests().connect(service, id: "resumed", playerID: "host", revision: 2)
        await service.receive(.resume(roomID: roomID, credential: credential, generation: 1), from: "resumed", now: 6)
        #expect(await service.connections["observer"]?.search?.results.map(\.id) == [roomID])
        #expect(await service.rooms[roomID]?.value.roomCode == "ABCD2345")
        await service.receive(.leave, from: "resumed", now: 7)
        #expect(await service.connections["observer"]?.search?.results.isEmpty == true)
        #expect(await service.rooms[roomID] == nil)
        let responses = await messages(observer).compactMap { message -> [String]? in
            if case .searchResults(let query, let requestID, let rooms) = message {
                #expect(query == "abcd2345" && requestID == 10)
                return rooms.map(\.id)
            }
            return nil
        }
        #expect(responses == [[], [roomID], [], [roomID], [], [roomID], []])
    }

    @Test func newestSearchRequestWinsAndListCancelsOnlySearchSubscription() async throws {
        let service = try service()
        let observer = try await connect(service, "observer")
        let legacy = try await connect(service, "legacy")
        _ = try await connect(service, "Alpha")
        _ = try await connect(service, "Beta")
        await service.receive(.search(query: "Alpha", requestID: 1), from: "observer", now: 1)
        await service.receive(.search(query: "Beta", requestID: 2), from: "observer", now: 2)
        await service.receive(.search(query: "Alpha", requestID: 1), from: "observer", now: 3)
        await service.receive(.search(query: "Alpha", requestID: 2), from: "observer", now: 4)
        #expect(await service.connections["observer"]?.search?.query == "Beta")
        await service.receive(.create(capacity: 3), from: "Alpha", now: 5)
        await service.receive(.create(capacity: 3), from: "Beta", now: 6)
        let beta = try #require(await service.connections["Beta"]?.roomID)
        let betaSummary = try #require(await service.searchRooms(query: "Beta", gameplayRevision: 2).first)
        #expect(await service.connections["observer"]?.search?.results.map(\.id) == [beta])
        await service.receive(.list, from: "observer", now: 7)
        await service.receive(.leave, from: "Beta", now: 8)
        #expect(await service.connections["observer"]?.search == nil)
        let searches = await messages(observer).filter { if case .searchResults = $0 { true } else { false } }
        #expect(
            searches == [
                .searchResults(query: "Alpha", requestID: 1, rooms: []),
                .searchResults(query: "Beta", requestID: 2, rooms: []),
                .searchResults(query: "Beta", requestID: 2, rooms: [betaSummary]),
            ])
        // Clients which never request search must never see its new enum case.
        #expect(await messages(legacy).allSatisfy { if case .searchResults = $0 { false } else { true } })
    }

    @Test func searchBoundsAndMembershipRejectWithoutChangingValidSubscription() async throws {
        let service = try service()
        let observer = try await connect(service, "observer")
        await service.receive(.search(query: "valid", requestID: 1), from: "observer", now: 1)
        for (query, requestID) in [
            (String(repeating: "a", count: 129), 2), (String(repeating: "é", count: 65), 2), ("x", -1),
            ("x", MP2Protocol.maximumInputID + 1),
        ] {
            await service.receive(.search(query: query, requestID: requestID), from: "observer", now: 2)
            #expect(await service.connections["observer"]?.search?.query == "valid")
        }
        await service.receive(.create(capacity: 3), from: "observer", now: 3)
        #expect(await service.connections["observer"]?.search == nil)
        await service.receive(.search(query: "valid", requestID: 3), from: "observer", now: 4)
        #expect(await service.connections["observer"]?.search == nil)
        let errors = await messages(observer).filter {
            if case .error(code: "invalid_search", message: _) = $0 { true } else { false }
        }
        #expect(errors.count == 5)
    }

    @Test func finishedPrivateRoomCannotBeFoundOrJoinedAndNeverReusesItsRetainedCode() async throws {
        let candidates = Mutex(["ABCD2345", "ABCD2345", "WXYZ6789"])
        let service = try service(code: { candidates.withLock { $0.removeFirst() } })
        for id in ["host", "guest", "observer"] { _ = try await connect(service, id) }
        await service.receive(.create(capacity: 2, isPrivate: true), from: "host", now: 0)
        let roomID = try #require(await service.connections["host"]?.roomID)
        await service.receive(.search(query: "ABCD2345", requestID: 1), from: "observer", now: 1)
        await service.receive(.join(roomID: "ABCD2345"), from: "guest", now: 2)
        let roster = try #require(await service.rooms[roomID]?.value.rosterRevision)
        for id in ["host", "guest"] {
            await service.receive(.ready(value: true, intentID: 1, rosterRevision: roster), from: id, now: 3)
        }
        await service.receive(.start, from: "host", now: 4)
        #expect(await service.searchRooms(query: "ABCD2345", gameplayRevision: 2).isEmpty)
        for now in stride(from: 1_004, through: 60_004, by: 100) { await service.tick(now: now) }
        let terminal = try #require(await service.rooms[roomID]?.engine?.snapshot)
        #expect(terminal.phase == .finished)
        #expect(await service.connections["observer"]?.search?.results.isEmpty == true)
        for query in ["ABCD2345", roomID] {
            await service.receive(.join(roomID: query), from: "observer", now: 60_005)
            #expect(await service.connections["observer"]?.roomID == nil)
        }
        await service.receive(.create(capacity: 2, isPrivate: true), from: "host", now: 60_006)
        let newRoom = try #require(await service.connections["host"]?.roomID)
        #expect(newRoom != roomID)
        #expect(await service.rooms[newRoom]?.value.roomCode == "WXYZ6789")
        #expect(await service.rooms[roomID]?.engine?.snapshot == terminal)
        await service.tick(now: 100_000)
        #expect(await service.rooms[roomID] != nil)
        await service.resultStored(matchID: terminal.matchID)
        await service.tick(now: 100_001)
        #expect(await service.rooms[roomID] == nil)
        #expect(await service.connections["host"]?.roomID == newRoom)
        #expect(await service.connections["observer"]?.search?.results.isEmpty == true)
    }

    @Test func codeJoinCannotCrossGameplayRevision() async throws {
        let service = try service(code: { "ABCD2345" })
        _ = try await connect(service, "host")
        _ = try await connect(service, "legacy", revision: 1)
        await service.receive(.create(capacity: 2, isPrivate: true), from: "host", now: 1)
        await service.receive(.join(roomID: "ABCD2345"), from: "legacy", now: 2)
        #expect(await service.connections["legacy"]?.roomID == nil)
        #expect(await service.searchRooms(query: "ABCD2345", gameplayRevision: 1).isEmpty)
    }
}
