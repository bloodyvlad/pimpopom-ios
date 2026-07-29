import Foundation
import XCTest

@testable import PimPoPom

@MainActor
final class MultiplayerBackendClientTests: XCTestCase {
    override func tearDown() {
        MultiplayerStubURLProtocol.handler = nil
        super.tearDown()
    }

    func testExactMultiplayerRoutesBodiesCSRFAndAdditiveResponses() async throws {
        let recorder = MultiplayerRequestRecorder()
        let sessionData = try JSONEncoder().encode(Self.session)
        let matchData = try JSONEncoder().encode(
            MultiplayerMatchResponse(match: Self.match)
        )
        let leaveData = try JSONEncoder().encode(
            MultiplayerLeaveResponse(left: true, matchCancelled: false)
        )
        let rosterData = try JSONEncoder().encode(
            MultiplayerRosterConfirmationResponse(
                confirmed: true,
                confirmedCount: 2,
                participantCount: 2
            )
        )
        let startData = try JSONEncoder().encode(Self.startResponse)
        let collectingData = try JSONEncoder().encode(Self.collecting)
        let settledData = try JSONEncoder().encode(Self.settled)
        let lobbyData = try JSONEncoder().encode(
            MultiplayerLobbyListResponse(
                lobbies: [
                    MultiplayerLobby(
                        matchId: Self.matchID,
                        mode: MultiplayerAPIContract.mode,
                        capacity: 3,
                        playerCount: 1,
                        host: MultiplayerLobbyHost(name: "Player9551", petId: "foka"),
                        createdAt: "2026-07-29T12:00:00.000Z",
                        expiresAt: "2026-07-29T12:10:00.000Z"
                    )
                ]
            )
        )
        let leaderboardData = try JSONEncoder().encode(Self.leaderboard)

        MultiplayerStubURLProtocol.handler = { request in
            recorder.append(request)
            switch (request.url?.path, request.httpMethod) {
            case ("/api/session", "GET"):
                return MultiplayerStubResponse(data: sessionData)
            case ("/api/mobile/v1/multiplayer/leaderboard", "GET"):
                return MultiplayerStubResponse(data: leaderboardData)
            case ("/api/mobile/v1/multiplayer/lobbies", "GET"):
                return MultiplayerStubResponse(data: lobbyData)
            case ("/api/mobile/v1/multiplayer/matches", "POST"):
                return MultiplayerStubResponse(data: matchData, statusCode: 201)
            case ("/api/mobile/v1/multiplayer/matches/\(Self.matchID)", "GET"):
                return MultiplayerStubResponse(data: matchData)
            case ("/api/mobile/v1/multiplayer/matches/\(Self.matchID)/join", "POST"):
                return MultiplayerStubResponse(data: matchData)
            case ("/api/mobile/v1/multiplayer/matches/\(Self.matchID)/leave", "POST"):
                return MultiplayerStubResponse(data: leaveData)
            case ("/api/mobile/v1/multiplayer/matches/\(Self.matchID)/readiness", "PATCH"):
                return MultiplayerStubResponse(data: matchData)
            case (
                "/api/mobile/v1/multiplayer/matches/\(Self.matchID)/gamekit-roster",
                "POST"
            ):
                return MultiplayerStubResponse(data: rosterData)
            case ("/api/mobile/v1/multiplayer/matches/\(Self.matchID)/start", "POST"):
                return MultiplayerStubResponse(data: startData)
            case ("/api/mobile/v1/multiplayer/matches/\(Self.matchID)/submissions", "POST"):
                return MultiplayerStubResponse(data: collectingData)
            case ("/api/mobile/v1/multiplayer/matches/\(Self.matchID)/settlement", "GET"):
                return MultiplayerStubResponse(data: settledData)
            default:
                return MultiplayerStubResponse(data: Data("{}".utf8), statusCode: 404)
            }
        }

        let backend = makeBackend()
        _ = try await backend.loadSession()
        let leaderboard = try await backend.loadMultiplayerLeaderboard()
        XCTAssertEqual(leaderboard, Self.leaderboard)
        let lobbies = try await backend.loadMultiplayerLobbies(limit: 20)
        XCTAssertEqual(lobbies.lobbies.count, 1)
        _ = try await backend.createMultiplayerMatch(capacity: 2)
        _ = try await backend.loadMultiplayerMatch(Self.matchID.uppercased())
        _ = try await backend.joinMultiplayerMatch(Self.matchID)
        let leave = try await backend.leaveMultiplayerMatch(Self.matchID)
        XCTAssertTrue(leave.left)
        _ = try await backend.setMultiplayerReadiness(Self.matchID, ready: true)
        let roster = try MultiplayerGameKitRoster(
            localGamePlayerID: "G:local",
            observedGamePlayerIDs: ["G:remote"]
        )
        _ = try await backend.confirmMultiplayerGameKitRoster(Self.matchID, roster: roster)
        _ = try await backend.startMultiplayerMatch(Self.matchID)
        let transcript = MultiplayerTranscriptSubmission(
            matchId: Self.matchID,
            events: [[6, 1, 500]]
        )
        let submissionResponse = try await backend.submitMultiplayerTranscript(
            matchID: Self.matchID,
            manifestHash: Self.hash,
            transcript: transcript
        )
        XCTAssertEqual(submissionResponse.state, "collecting")
        let settlement = try await backend.loadMultiplayerSettlement(Self.matchID)
        XCTAssertEqual(settlement.state, "settled")

        let mutations = recorder.all.filter {
            ["POST", "PATCH"].contains($0.method)
                && $0.path.hasPrefix("/api/mobile/v1/multiplayer/")
        }
        XCTAssertFalse(mutations.isEmpty)
        XCTAssertTrue(
            mutations.allSatisfy {
                $0.header(named: "X-SpeedyTapper-CSRF") == "csrf-multiplayer"
            }
        )

        let create = try XCTUnwrap(
            recorder.first(path: "/api/mobile/v1/multiplayer/matches", method: "POST")
        )
        XCTAssertEqual(
            try jsonObject(create.body),
            [
                "mode": MultiplayerAPIContract.mode,
                "capacity": 2,
                "buildId": MultiplayerAPIContract.buildID,
            ] as [String: AnyHashable]
        )

        let lobbyRequest = try XCTUnwrap(
            recorder.first(path: "/api/mobile/v1/multiplayer/lobbies", method: "GET")
        )
        XCTAssertEqual(lobbyRequest.query, "limit=20")
        XCTAssertNil(lobbyRequest.header(named: "X-SpeedyTapper-CSRF"))

        let rosterRequest = try XCTUnwrap(
            recorder.first(
                path: "/api/mobile/v1/multiplayer/matches/\(Self.matchID)/gamekit-roster",
                method: "POST"
            )
        )
        XCTAssertEqual(
            try jsonObject(rosterRequest.body),
            [
                "localGamePlayerId": "G:local",
                "observedGamePlayerIds": ["G:remote"],
                "coordinatorGamePlayerId": "G:local",
            ] as [String: AnyHashable]
        )

        let submissionRequest = try XCTUnwrap(
            recorder.first(
                path: "/api/mobile/v1/multiplayer/matches/\(Self.matchID)/submissions",
                method: "POST"
            )
        )
        let submission = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(submissionRequest.body))
                as? [String: Any]
        )
        XCTAssertEqual(submission["manifestHash"] as? String, Self.hash)
        let submittedTranscript = try XCTUnwrap(submission["transcript"] as? [String: Any])
        XCTAssertEqual(
            submittedTranscript["ruleset"] as? String,
            MultiplayerAPIContract.ruleset
        )
        XCTAssertEqual(
            submittedTranscript["buildId"] as? String,
            MultiplayerAPIContract.buildID
        )
    }

    func testInvalidMatchCapacityTranscriptAndServerMismatchFailBeforeAuthorityLeaks() async throws {
        let backend = makeBackend()
        do {
            _ = try await backend.createMultiplayerMatch(capacity: 5)
            XCTFail("Invalid capacity must be rejected locally.")
        } catch let error as BackendError {
            XCTAssertEqual(error.code, "invalid-multiplayer-request")
        }
        do {
            _ = try await backend.submitMultiplayerTranscript(
                matchID: Self.matchID,
                manifestHash: "not-a-hash",
                transcript: MultiplayerTranscriptSubmission(
                    matchId: Self.matchID,
                    events: [[6, 2, 500]]
                )
            )
            XCTFail("Malformed evidence must not be submitted.")
        } catch let error as BackendError {
            XCTAssertEqual(error.code, "invalid-multiplayer-request")
        }
    }

    func testFinishedTranscriptOrdersMissPlayerOutAndFinishByInputTime() async throws {
        let recorder = MultiplayerRequestRecorder()
        let sessionData = try JSONEncoder().encode(Self.session)
        let collectingData = try JSONEncoder().encode(Self.collecting)
        MultiplayerStubURLProtocol.handler = { request in
            recorder.append(request)
            switch (request.url?.path, request.httpMethod) {
            case ("/api/session", "GET"):
                return MultiplayerStubResponse(data: sessionData)
            case ("/api/mobile/v1/multiplayer/matches/\(Self.matchID)/submissions", "POST"):
                return MultiplayerStubResponse(data: collectingData)
            default:
                return MultiplayerStubResponse(data: Data("{}".utf8), statusCode: 404)
            }
        }

        let backend = makeBackend()
        _ = try await backend.loadSession()
        let events = [
            [2, 1, 1_000, 1_008, 0, 0, 1],
            [2, 2, 3_000, 3_009, 0, 0, 1],
            [2, 3, 5_000, 5_013, 0, 0, 1],
            [5, 4, 5_000, 0],
            [2, 5, 7_000, 7_011, 1, 0, 1],
            [2, 6, 9_000, 9_014, 1, 0, 1],
            [2, 7, 11_000, 11_016, 1, 0, 1],
            [5, 8, 11_000, 1],
            [6, 9, 11_016],
        ]

        let response = try await backend.submitMultiplayerTranscript(
            matchID: Self.matchID,
            manifestHash: Self.hash,
            transcript: MultiplayerTranscriptSubmission(
                matchId: Self.matchID,
                events: events
            )
        )

        XCTAssertEqual(response.state, "collecting")
        XCTAssertNotNil(
            recorder.first(
                path: "/api/mobile/v1/multiplayer/matches/\(Self.matchID)/submissions",
                method: "POST"
            ),
            "A valid final miss → player-out → finish transcript must reach PHP."
        )
    }

    private func makeBackend() -> BackendClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MultiplayerStubURLProtocol.self]
        configuration.httpCookieStorage = nil
        return BackendClient(
            baseURL: URL(string: "https://unit.test")!,
            isUITestOffline: false,
            urlSession: URLSession(configuration: configuration)
        )
    }

    private func jsonObject(_ body: Data?) throws -> [String: AnyHashable] {
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(body)) as? [String: Any]
        )
        return object.reduce(into: [String: AnyHashable]()) { result, item in
            if let value = item.value as? AnyHashable {
                result[item.key] = value
            }
        }
    }

    private static let matchID = "11111111-1111-4111-8111-111111111111"
    private static let localParticipantID = "22222222-2222-4222-8222-222222222222"
    private static let remoteParticipantID = "33333333-3333-4333-8333-333333333333"
    private static let hash = String(repeating: "A", count: 43)

    private static let participants = [
        MultiplayerParticipant(
            participantId: localParticipantID,
            seat: 0,
            colorIndex: 0,
            name: "Player9551",
            petId: "foka",
            ready: true,
            status: "ready",
            isCurrentPlayer: true
        ),
        MultiplayerParticipant(
            participantId: remoteParticipantID,
            seat: 1,
            colorIndex: 1,
            name: "PixelNova",
            petId: nil,
            ready: true,
            status: "ready",
            isCurrentPlayer: false
        ),
    ]

    private static let manifest = MultiplayerStartManifest(
        protocolVersion: MultiplayerAPIContract.protocolVersion,
        ruleset: MultiplayerAPIContract.ruleset,
        proofVersion: MultiplayerAPIContract.proofVersion,
        matchId: matchID,
        buildId: MultiplayerAPIContract.buildID,
        seed: hash,
        startingLives: 3,
        participants: [
            MultiplayerManifestParticipant(
                participantId: localParticipantID,
                seat: 0,
                colorIndex: 0
            ),
            MultiplayerManifestParticipant(
                participantId: remoteParticipantID,
                seat: 1,
                colorIndex: 1
            ),
        ],
        manifestHash: hash
    )

    private static let match = MultiplayerMatch(
        matchId: matchID,
        state: "forming",
        mode: MultiplayerAPIContract.mode,
        capacity: 2,
        selfParticipantId: localParticipantID,
        isCreator: true,
        playerGroup: 123_456_789,
        participants: participants,
        expiresAt: "2026-07-29T12:10:00.000Z",
        manifest: nil
    )

    private static let startResponse = MultiplayerStartResponse(
        manifest: manifest,
        participants: participants
    )

    private static let collecting = MultiplayerSettlementResponse(
        duplicate: false,
        conflict: nil,
        state: "collecting",
        submittedCount: 1,
        participantCount: 2,
        leaderboardEligible: false,
        verification: nil,
        reviewReason: nil,
        results: nil
    )

    private static let result = MultiplayerSettlementResult(
        resultId: "44444444-4444-4444-8444-444444444444",
        participantId: localParticipantID,
        place: 1,
        playerCount: 2,
        name: "Player9551",
        petId: "foka",
        score: 4_200,
        survivalMs: 12_000,
        hits: 5,
        misses: 3,
        dodges: 1,
        fastestReactionMs: 190,
        averageReactionMs: 320,
        maxMultiplier: 2,
        speedRatings: SpeedRatingCounts(godlike: 1, perfect: 2, great: 1, good: 1),
        isCurrentPlayer: true
    )

    private static let settled = MultiplayerSettlementResponse(
        duplicate: nil,
        conflict: nil,
        state: "settled",
        submittedCount: nil,
        participantCount: nil,
        leaderboardEligible: true,
        verification: "peer_consistent_v1",
        reviewReason: nil,
        results: [result]
    )

    private static let leaderboard = MultiplayerLeaderboardResponse(
        season: Season(id: "season-1", name: "Season 1"),
        mode: "multiplayer",
        entries: [
            MultiplayerLeaderboardEntry(
                rank: 1,
                name: "Player9551",
                petId: "foka",
                score: 4_200,
                place: 1,
                playerCount: 2,
                survivalMs: 12_000,
                fastestReactionMs: 190,
                averageReactionMs: 320,
                hits: 5,
                misses: 3,
                dodges: 1,
                maxMultiplier: 2,
                speedRatings: SpeedRatingCounts(
                    godlike: 1,
                    perfect: 2,
                    great: 1,
                    good: 1
                ),
                createdAt: "2026-07-29T12:15:00.000Z",
                isCurrentPlayer: true,
                verification: "peer_consistent_v1"
            )
        ],
        totalEntries: 1,
        playerRank: 1,
        topPercent: 100
    )

    private static let session = SessionResponse(
        authenticated: true,
        csrfToken: "csrf-multiplayer",
        googleClientId: "server-client.apps.googleusercontent.com",
        season: Season(id: "season-1", name: "Season 1"),
        profile: PlayerProfile(
            id: "55555555-5555-4555-8555-555555555555",
            nickname: "Player9551",
            nicknameConfirmed: true,
            coins: 0,
            totalPlayMs: 0,
            ownedPetIds: ["foka"],
            selectedPetId: "foka",
            petVisible: true,
            equippedPetId: "foka",
            specialPetId: nil,
            ownedThemeIds: ["classic", "disco"],
            selectedThemeId: "classic",
            isAdmin: false,
            createdAt: "2026-07-29T00:00:00Z",
            updatedAt: "2026-07-29T00:00:00Z"
        ),
        identityBindings: IdentityBindings(google: true, apple: false, gameCenter: true),
        gameCenter: GameCenterServerStatus(
            serverPublicationAvailable: true,
            preReleased: true,
            identityLinked: true,
            publicationEnabled: true,
            mirrorReady: true,
            pendingJobs: 0,
            heldJobs: 0,
            needsReset: false
        ),
        ranks: ["multiplayer": RankInfo(rank: nil, totalEntries: 0, topPercent: nil)]
    )
}

private struct MultiplayerStubResponse: @unchecked Sendable {
    let data: Data
    let statusCode: Int

    init(data: Data, statusCode: Int = 200) {
        self.data = data
        self.statusCode = statusCode
    }
}

private final class MultiplayerStubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> MultiplayerStubResponse)?

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let result = Self.handler?(request), let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: result.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: result.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class MultiplayerRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [MultiplayerRecordedRequest] = []

    var all: [MultiplayerRecordedRequest] {
        lock.withLock { recorded }
    }

    func append(_ request: URLRequest) {
        lock.withLock {
            recorded.append(MultiplayerRecordedRequest(request))
        }
    }

    func first(path: String, method: String) -> MultiplayerRecordedRequest? {
        lock.withLock {
            recorded.first { $0.path == path && $0.method == method }
        }
    }
}

private struct MultiplayerRecordedRequest: @unchecked Sendable {
    let path: String
    let query: String?
    let method: String?
    let headers: [String: String]
    let body: Data?

    init(_ request: URLRequest) {
        path = request.url?.path ?? ""
        query = request.url?.query
        method = request.httpMethod
        headers = request.allHTTPHeaderFields ?? [:]
        body = request.httpBody ?? Self.read(stream: request.httpBodyStream)
    }

    func header(named name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    private static func read(stream: InputStream?) -> Data? {
        guard let stream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data.isEmpty ? nil : data
    }
}
