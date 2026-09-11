import Foundation
import PimPoPomCore
import Testing

@testable import RealtimeServer

struct CompetitiveRoomTests {
    @Test func realEngineCompetitiveAggregateCrossLanguageFixture() throws {
        let ids = ["00000000-0000-4000-8000-000000000001", "00000000-0000-4000-8000-000000000002"]
        var engine = try MP2Engine(
            matchID: "00000000-0000-4000-8000-000000000029",
            players:
                ids.enumerated().map {
                    MP2Player(id: $0.element, seat: $0.offset, colorIndex: $0.offset, name: "Fixture")
                },
            seed: 29, gameplayRevision: 3)
        while engine.elapsedMs < 65_000 {
            engine.advance(to: min(65_000, engine.elapsedMs + 20))
            for target in engine.snapshot.targets {
                let reaction = target.ownerSeat == 0 ? 100 : min(500, target.responseWindowMs - 1)
                guard target.activateAtMs + reaction <= engine.elapsedMs else { continue }
                #expect(
                    engine.submit(
                        MP2Input(
                            id: target.id, seat: target.ownerSeat, targetID: target.id,
                            cell: target.cell, presentedAtMs: target.activateAtMs,
                            contactAtMs: target.activateAtMs + reaction),
                        receivedAt: engine.elapsedMs
                    ).accepted)
            }
        }
        engine.disconnect(seat: 0, at: 65_000)
        engine.eliminateDisconnected(seat: 0, at: 65_000)
        #expect(engine.snapshot.phase == .playing)
        engine.advance(to: 95_000)
        #expect(engine.snapshot.phase == .finished)
        let match = CompletedMatch(
            snapshot: engine.snapshot, competitive: true, economyGenerations: [ids[0]: 1, ids[1]: 4])
        #expect(match.players[0].score > match.players[1].score)
        #expect(match.players[0].survivalMs == 65_000)
        #expect(try #require(match.players[1].survivalMs) > 65_000)
        #expect(match.players.allSatisfy { ($0.eligibleAliveMs ?? 0) >= 60_000 })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(match)
        #expect(try JSONDecoder().decode(CompletedMatch.self, from: data) == match)
        if let path = ProcessInfo.processInfo.environment["MP29_RESULT_FIXTURE"] {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    @Test func hostPrivacyMutationUpdatesDiscoveryAtomicallyWithoutResettingReadyOrCode() async throws {
        let fixture = RoomSearchTests()
        let service = try fixture.service(code: { "ABCD2345" })
        let host = try await fixture.connect(service, "host", revision: 3)
        let browser = try await fixture.connect(service, "browser", revision: 3)
        let search = try await fixture.connect(service, "search", revision: 3)
        await service.receive(.create(capacity: 3), from: "host", now: 1)
        let roomID = try #require(await service.connections["host"]?.roomID)
        let before = try #require(await service.rooms[roomID]?.value)
        await service.receive(
            .ready(value: true, intentID: 1, rosterRevision: before.rosterRevision), from: "host", now: 2)
        await service.receive(.search(query: "host", requestID: 1), from: "search", now: 3)
        let revision = try #require(await service.rooms[roomID]?.value.revision)
        await service.receive(
            .setPrivacy(isPrivate: true, roomID: roomID, roomRevision: revision), from: "host", now: 4)
        let hidden = try #require(await service.rooms[roomID]?.value)
        #expect(hidden.isPrivate == true && hidden.revision == revision + 1)
        #expect(hidden.rosterRevision == before.rosterRevision && hidden.players[0].ready)
        #expect(hidden.roomCode == before.roomCode && hidden.epoch == before.epoch)
        #expect(await service.directory(gameplayRevision: 3).isEmpty)
        #expect(await service.connections["search"]?.search?.results.isEmpty == true)
        #expect(await service.searchRooms(query: "ABCD2345", gameplayRevision: 3).count == 1)
        await service.receive(
            .setPrivacy(isPrivate: false, roomID: roomID, roomRevision: hidden.revision), from: "host", now: 5)
        #expect(await service.directory(gameplayRevision: 3).map(\.id) == [roomID])
        #expect(await service.connections["search"]?.search?.results.map(\.id) == [roomID])
        let lists = await RoomDirectoryTests().lists(browser)
        #expect(lists.map(\.count).suffix(3) == [1, 0, 1])
        for output in [host, search] { output.finish() }
    }

    @Test func privacyRejectsNonHostStaleRoomRevisionWrongMembershipAndStartedMatch() async throws {
        let fixture = RoomSearchTests()
        let service = try fixture.service()
        let host = try await fixture.connect(service, "host", revision: 3)
        let guest = try await fixture.connect(service, "guest", revision: 3)
        await service.receive(.create(capacity: 2), from: "host", now: 1)
        let roomID = try #require(await service.connections["host"]?.roomID)
        await service.receive(.join(roomID: roomID), from: "guest", now: 2)
        let room = try #require(await service.rooms[roomID]?.value)
        for (caller, requested, revision) in [
            ("guest", roomID, room.revision), ("host", roomID, room.revision - 1), ("host", "other", room.revision),
        ] {
            await service.receive(
                .setPrivacy(isPrivate: true, roomID: requested, roomRevision: revision), from: caller, now: 3)
            #expect(await service.rooms[roomID]?.value == room)
        }
        for id in ["host", "guest"] {
            await service.receive(
                .ready(value: true, intentID: 1, rosterRevision: room.rosterRevision), from: id, now: 4)
        }
        await service.receive(.start, from: "host", now: 5)
        for at in [6, 1_006] {
            await service.tick(now: at)
            let value = try #require(await service.rooms[roomID]?.value)
            await service.receive(
                .setPrivacy(isPrivate: true, roomID: roomID, roomRevision: value.revision), from: "host", now: at)
            #expect(await service.rooms[roomID]?.value.isPrivate == false)
        }
        host.finish()
        guest.finish()
    }

    @Test func resultMetadataIsExplicitAndLegacyCanonicalPayloadRemainsIdentical() throws {
        let player = MP2Player(
            id: "p", seat: 0, colorIndex: 0, name: "P", lives: 0,
            score: 100, hits: 1, misses: 3, reactionTotalMs: 100, fastestReactionMs: 100,
            outAtMs: 75_000, eligibleAliveMs: 60_000, maxMultiplier: 4)
        let make: (Int, MP2MatchPhase, MP2FinalReason?) -> MP2Snapshot = { revision, phase, reason in
            MP2Snapshot(
                matchID: "m", revision: 1, elapsedMs: 80_000, phase: phase, gridDimension: 4,
                players: [player], targets: [], decoys: [], gameplayRevision: revision, finalReason: reason)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let legacy = CompletedMatch(snapshot: make(2, .finished, nil), competitive: true, economyGenerations: ["p": 9])
        let data = try encoder.encode(legacy)
        #expect(
            String(decoding: data, as: UTF8.self)
                == #"{"durationMs":80000,"matchID":"m","players":[{"dodges":0,"fastestReactionMs":100,"hits":1,"lives":0,"misses":3,"playerID":"p","reactionTotalMs":100,"score":100,"seat":0}],"protocolVersion":2,"rankingEligible":false,"ruleset":"multiplayer-shared-arcade-v2"}"#
        )
        #expect(try JSONDecoder().decode(CompletedMatch.self, from: data) == legacy)
        let current = CompletedMatch(
            snapshot: make(3, .finished, .allOut), competitive: true, economyGenerations: ["p": 9])
        #expect(current.resultRevision == 2 && current.gameplayRevision == 3)
        #expect(current.rewardPolicy == "multiplayer-alive-minute-v1")
        #expect(current.matchKind == "competitive" && current.completionReason == "completed")
        #expect(current.rankingEligible && current.players[0].economyGeneration == 9)
        #expect(current.players[0].survivalMs == 75_000 && current.players[0].eligibleAliveMs == 60_000)
        #expect(current.players[0].maxMultiplier == 4)
        #expect(try JSONDecoder().decode(CompletedMatch.self, from: encoder.encode(current)) == current)
        let rankedAck = Data(#"{"matchID":"m","rankingEligible":true,"state":"stored_ranked"}"#.utf8)
        let legacyAck = Data(#"{"matchID":"m","rankingEligible":false,"state":"stored_unranked"}"#.utf8)
        let rankedData = try encoder.encode(current)
        #expect(ResultOutbox.acceptsAcknowledgement(rankedAck, for: rankedData, matchID: "m"))
        #expect(!ResultOutbox.acceptsAcknowledgement(legacyAck, for: rankedData, matchID: "m"))
        #expect(ResultOutbox.acceptsAcknowledgement(legacyAck, for: data, matchID: "m"))
        #expect(!ResultOutbox.acceptsAcknowledgement(rankedAck, for: data, matchID: "m"))
        #expect(!ResultOutbox.acceptsAcknowledgement(rankedAck, for: rankedData, matchID: "other"))
        let missing = CompletedMatch(snapshot: make(3, .finished, .allOut), competitive: true)
        #expect(String(decoding: try encoder.encode(missing), as: UTF8.self).contains("\"economyGeneration\":null"))
        let tutorial = CompletedMatch(snapshot: make(3, .finished, .allOut))
        #expect(tutorial.matchKind == "tutorial" && !tutorial.rankingEligible)
        let unfinished = CompletedMatch(snapshot: make(3, .finishing, .allOut), competitive: true)
        #expect(unfinished.resultRevision == nil && !unfinished.rankingEligible)
    }

    @Test func matchStartCapturesEconomyGenerationOnceAndDevelopmentMatchesCannotRank() async throws {
        var configuration = try ServerConfiguration(environment: ["MP2_DEV_AUTH": "1"])
        configuration.idleConnectionMs = 1_000_000
        let results = AsyncStream<CompletedMatch>.makeStream(bufferingPolicy: .bufferingOldest(10))
        let service = RoomService(configuration: configuration, resultOutput: results.continuation, randomSeed: { 7 })
        for index in 0..<2 {
            let id = "p\(index)"
            #expect(await service.connect(id: id, output: OutboundMessages(capacity: 1_000), now: 0))
            await service.authenticated(
                id: id,
                player: AuthenticatedPlayer(
                    playerID: id, name: id,
                    sessionBinding: "binding", expiresAt: 9_999_999_999, economyGeneration: index == 0 ? 7 : nil),
                now: 0,
                gameplayRevision: 3)
        }
        await service.receive(.create(capacity: 2), from: "p0", now: 1)
        let roomID = try #require(await service.connections["p0"]?.roomID)
        await service.receive(.join(roomID: roomID), from: "p1", now: 2)
        let roster = try #require(await service.rooms[roomID]?.value.rosterRevision)
        for id in ["p0", "p1"] {
            await service.receive(.ready(value: true, intentID: 1, rosterRevision: roster), from: id, now: 3)
        }
        await service.receive(.start, from: "p0", now: 4)
        await service.tick(now: 1_004)
        #expect(await service.rooms[roomID]?.economyGenerations == ["p0": 7])
        let validations = await service.validationsDue(now: 15_000)
        let validation = try #require(validations.first { $0.connectionID == "p0" })
        let original = validation.player
        await service.validated(
            validation,
            refreshed: AuthenticatedPlayer(
                playerID: original.playerID,
                name: original.name, sessionBinding: original.sessionBinding, expiresAt: original.expiresAt,
                economyGeneration: 8), now: 15_000)
        #expect(await service.rooms[roomID]?.economyGenerations == ["p0": 7])
        #expect(await service.connections["p0"]?.player?.economyGeneration == 8)
        await service.tick(now: 61_004)
        results.continuation.finish()
        var collected: [CompletedMatch] = []
        for await result in results.stream { collected.append(result) }
        let result = try #require(collected.first)
        #expect(collected.count == 1 && result.matchKind == "tutorial" && !result.rankingEligible)
        #expect(result.players[0].economyGeneration == 7 && result.players[1].economyGeneration == nil)
        #expect(result.players.allSatisfy { ($0.eligibleAliveMs ?? -1) == $0.survivalMs })
        #expect(result.durationMs < 60_000)
    }

    @Test func identityGenerationIsOptionalButNeverNegative() throws {
        for generation: Int? in [nil, 0, 8, -1] {
            let identity = AuthenticatedPlayer(
                playerID: UUID().uuidString, name: "P", sessionBinding: "binding",
                expiresAt: Int(Date().timeIntervalSince1970) + 60, economyGeneration: generation)
            let data = try JSONEncoder().encode(identity)
            if generation == -1 {
                #expect(throws: AuthenticationFailure.invalidCapability) {
                    try TicketAuthenticator.decodeResponse(data, statusCode: 200)
                }
            } else {
                #expect(try TicketAuthenticator.decodeResponse(data, statusCode: 200).economyGeneration == generation)
            }
        }
    }
}
