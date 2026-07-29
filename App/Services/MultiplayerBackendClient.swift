import Foundation

extension BackendClient: MultiplayerBackendServing {
    func loadMultiplayerLeaderboard() async throws -> MultiplayerLeaderboardResponse {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                let exposesFixture =
                    ProcessInfo.processInfo.arguments.contains("--ui-test-leaderboard-fixture")
                    || ProcessInfo.processInfo.arguments.contains("--screenshot-mode")
                return MultiplayerLeaderboardResponse(
                    season: Season(id: "season-1", name: "Season 1"),
                    mode: "multiplayer",
                    entries: exposesFixture
                        ? [
                            MultiplayerLeaderboardEntry(
                                rank: 1,
                                name: "TeamAurora",
                                petId: "foka",
                                score: 24_850,
                                place: 1,
                                playerCount: 4,
                                survivalMs: 186_000,
                                fastestReactionMs: 181,
                                averageReactionMs: 302,
                                hits: 94,
                                misses: 2,
                                dodges: 14,
                                maxMultiplier: 4,
                                speedRatings: SpeedRatingCounts(
                                    godlike: 18,
                                    perfect: 34,
                                    great: 27,
                                    good: 15
                                ),
                                createdAt: "2026-07-29T18:00:00Z",
                                isCurrentPlayer: true,
                                verification: "peer_consistent_v1"
                            )
                        ] : [],
                    totalEntries: exposesFixture ? 1 : 0,
                    playerRank: exposesFixture ? 1 : nil,
                    topPercent: exposesFixture ? 1 : nil
                )
            }
        #endif
        let response: MultiplayerLeaderboardResponse = try await performMultiplayerRequest(
            path: "\(MultiplayerAPIContract.basePath)/leaderboard",
            requiresAuthentication: false,
            requiresCSRF: false
        )
        guard response.mode == "multiplayer",
            response.totalEntries >= 0,
            response.entries.allSatisfy({
                $0.rank > 0
                    && $0.score >= 0
                    && $0.place > 0
                    && $0.playerCount >= MultiplayerAPIContract.minimumPlayers
                    && $0.playerCount <= MultiplayerAPIContract.maximumPlayers
                    && $0.verification == "peer_consistent_v1"
            })
        else {
            throw Self.invalidMultiplayerResponse()
        }
        return response
    }

    func loadMultiplayerLobbies(limit: Int = 20) async throws
        -> MultiplayerLobbyListResponse
    {
        guard (1...50).contains(limit) else {
            throw Self.invalidMultiplayerRequest("Lobby limit must be between 1 and 50.")
        }
        let response: MultiplayerLobbyListResponse = try await performMultiplayerRequest(
            path: "\(MultiplayerAPIContract.basePath)/lobbies?limit=\(limit)",
            requiresAuthentication: true,
            requiresCSRF: false
        )
        guard response.lobbies.allSatisfy(Self.isValidLobby) else {
            throw Self.invalidMultiplayerResponse()
        }
        return response
    }

    func createMultiplayerMatch(capacity: Int) async throws -> MultiplayerMatch {
        guard
            (MultiplayerAPIContract.minimumPlayers...MultiplayerAPIContract.maximumPlayers)
                .contains(capacity)
        else {
            throw Self.invalidMultiplayerRequest(
                "Multiplayer capacity must be between 2 and 4."
            )
        }
        struct Body: Encodable {
            let mode: String
            let capacity: Int
            let buildId: String
        }
        let response: MultiplayerMatchResponse = try await performMultiplayerRequest(
            path: "\(MultiplayerAPIContract.basePath)/matches",
            method: "POST",
            body: try JSONEncoder().encode(
                Body(
                    mode: MultiplayerAPIContract.mode,
                    capacity: capacity,
                    buildId: MultiplayerAPIContract.buildID
                )
            ),
            requiresAuthentication: true,
            requiresCSRF: true
        )
        return try Self.validatedMatch(response.match)
    }

    func loadMultiplayerMatch(_ matchID: String) async throws -> MultiplayerMatch {
        let matchID = try Self.validatedMatchID(matchID)
        let response: MultiplayerMatchResponse = try await performMultiplayerRequest(
            path: "\(MultiplayerAPIContract.basePath)/matches/\(matchID)",
            requiresAuthentication: true,
            requiresCSRF: false
        )
        guard response.match.matchId.lowercased() == matchID else {
            throw Self.invalidMultiplayerResponse()
        }
        return try Self.validatedMatch(response.match)
    }

    func joinMultiplayerMatch(_ matchID: String) async throws -> MultiplayerMatch {
        try await emptyMultiplayerMatchMutation(matchID, action: "join")
    }

    func leaveMultiplayerMatch(_ matchID: String) async throws -> MultiplayerLeaveResponse {
        let matchID = try Self.validatedMatchID(matchID)
        let response: MultiplayerLeaveResponse = try await performMultiplayerRequest(
            path: "\(MultiplayerAPIContract.basePath)/matches/\(matchID)/leave",
            method: "POST",
            body: Data("{}".utf8),
            requiresAuthentication: true,
            requiresCSRF: true
        )
        guard response.left else { throw Self.invalidMultiplayerResponse() }
        return response
    }

    func setMultiplayerReadiness(
        _ matchID: String,
        ready: Bool
    ) async throws -> MultiplayerMatch {
        struct Body: Encodable {
            let ready: Bool
        }
        let matchID = try Self.validatedMatchID(matchID)
        let response: MultiplayerMatchResponse = try await performMultiplayerRequest(
            path: "\(MultiplayerAPIContract.basePath)/matches/\(matchID)/readiness",
            method: "PATCH",
            body: try JSONEncoder().encode(Body(ready: ready)),
            requiresAuthentication: true,
            requiresCSRF: true
        )
        guard response.match.matchId.lowercased() == matchID else {
            throw Self.invalidMultiplayerResponse()
        }
        return try Self.validatedMatch(response.match)
    }

    func confirmMultiplayerGameKitRoster(
        _ matchID: String,
        roster: MultiplayerGameKitRoster
    ) async throws -> MultiplayerRosterConfirmationResponse {
        let matchID = try Self.validatedMatchID(matchID)
        let response: MultiplayerRosterConfirmationResponse =
            try await performMultiplayerRequest(
                path: "\(MultiplayerAPIContract.basePath)/matches/\(matchID)/gamekit-roster",
                method: "POST",
                body: try JSONEncoder().encode(roster.confirmationRequest),
                requiresAuthentication: true,
                requiresCSRF: true
            )
        guard response.confirmed,
            response.participantCount == roster.gamePlayerIDs.count,
            response.confirmedCount > 0,
            response.confirmedCount <= response.participantCount
        else {
            throw Self.invalidMultiplayerResponse()
        }
        return response
    }

    func startMultiplayerMatch(_ matchID: String) async throws -> MultiplayerStartResponse {
        let matchID = try Self.validatedMatchID(matchID)
        let response: MultiplayerStartResponse = try await performMultiplayerRequest(
            path: "\(MultiplayerAPIContract.basePath)/matches/\(matchID)/start",
            method: "POST",
            body: Data("{}".utf8),
            requiresAuthentication: true,
            requiresCSRF: true
        )
        guard Self.isValidManifest(response.manifest, expectedMatchID: matchID),
            response.participants.count == response.manifest.participants.count
        else {
            throw Self.invalidMultiplayerResponse()
        }
        return response
    }

    func submitMultiplayerTranscript(
        matchID: String,
        manifestHash: String,
        transcript: MultiplayerTranscriptSubmission
    ) async throws -> MultiplayerSettlementResponse {
        let matchID = try Self.validatedMatchID(matchID)
        guard transcript.matchId.lowercased() == matchID,
            transcript.buildId == MultiplayerAPIContract.buildID,
            transcript.ruleset == MultiplayerAPIContract.ruleset,
            transcript.protocolVersion == MultiplayerAPIContract.protocolVersion,
            transcript.proofVersion == MultiplayerAPIContract.proofVersion,
            Self.isBase64URLSHA256(manifestHash),
            Self.isStructurallyValidTranscript(transcript.events)
        else {
            throw Self.invalidMultiplayerRequest("The multiplayer transcript is invalid.")
        }
        let request = MultiplayerSubmissionRequest(
            manifestHash: manifestHash,
            transcript: transcript
        )
        let response: MultiplayerSettlementResponse = try await performMultiplayerRequest(
            path: "\(MultiplayerAPIContract.basePath)/matches/\(matchID)/submissions",
            method: "POST",
            body: try JSONEncoder().encode(request),
            requiresAuthentication: true,
            requiresCSRF: true
        )
        return try Self.validatedSettlement(response)
    }

    func loadMultiplayerSettlement(_ matchID: String) async throws
        -> MultiplayerSettlementResponse
    {
        let matchID = try Self.validatedMatchID(matchID)
        let response: MultiplayerSettlementResponse = try await performMultiplayerRequest(
            path: "\(MultiplayerAPIContract.basePath)/matches/\(matchID)/settlement",
            requiresAuthentication: true,
            requiresCSRF: false
        )
        return try Self.validatedSettlement(response)
    }

    private func emptyMultiplayerMatchMutation(
        _ matchID: String,
        action: String
    ) async throws -> MultiplayerMatch {
        let matchID = try Self.validatedMatchID(matchID)
        let response: MultiplayerMatchResponse = try await performMultiplayerRequest(
            path: "\(MultiplayerAPIContract.basePath)/matches/\(matchID)/\(action)",
            method: "POST",
            body: Data("{}".utf8),
            requiresAuthentication: true,
            requiresCSRF: true
        )
        guard response.match.matchId.lowercased() == matchID else {
            throw Self.invalidMultiplayerResponse()
        }
        return try Self.validatedMatch(response.match)
    }

    private static func validatedMatch(_ match: MultiplayerMatch) throws -> MultiplayerMatch {
        guard UUID(uuidString: match.matchId) != nil,
            UUID(uuidString: match.selfParticipantId) != nil,
            match.mode == MultiplayerAPIContract.mode,
            (MultiplayerAPIContract.minimumPlayers...MultiplayerAPIContract.maximumPlayers)
                .contains(match.capacity),
            (1...Int(Int32.max)).contains(match.playerGroup),
            !match.state.isEmpty,
            !match.participants.isEmpty,
            match.participants.count <= match.capacity,
            Set(match.participants.map(\.participantId)).count == match.participants.count,
            Set(match.participants.map(\.seat)).count == match.participants.count,
            Set(match.participants.map(\.colorIndex)).count == match.participants.count,
            match.participants.contains(where: {
                $0.isCurrentPlayer && $0.participantId == match.selfParticipantId
            }),
            match.manifest.map({
                isValidManifest($0, expectedMatchID: match.matchId.lowercased())
            }) ?? true
        else {
            throw invalidMultiplayerResponse()
        }
        return match
    }

    private static func isValidLobby(_ lobby: MultiplayerLobby) -> Bool {
        UUID(uuidString: lobby.matchId) != nil
            && lobby.mode == MultiplayerAPIContract.mode
            && (MultiplayerAPIContract.minimumPlayers...MultiplayerAPIContract.maximumPlayers)
                .contains(lobby.capacity)
            && lobby.playerCount > 0
            && lobby.playerCount < lobby.capacity
            && !lobby.host.name.isEmpty
    }

    private static func isValidManifest(
        _ manifest: MultiplayerStartManifest,
        expectedMatchID: String
    ) -> Bool {
        manifest.matchId.lowercased() == expectedMatchID
            && manifest.buildId == MultiplayerAPIContract.buildID
            && manifest.ruleset == MultiplayerAPIContract.ruleset
            && manifest.protocolVersion == MultiplayerAPIContract.protocolVersion
            && manifest.proofVersion == MultiplayerAPIContract.proofVersion
            && manifest.startingLives == 3
            && isBase64URLSHA256(manifest.seed)
            && isBase64URLSHA256(manifest.manifestHash)
            && (MultiplayerAPIContract.minimumPlayers...MultiplayerAPIContract.maximumPlayers)
                .contains(manifest.participants.count)
            && Set(manifest.participants.map(\.participantId)).count
                == manifest.participants.count
            && Set(manifest.participants.map(\.seat)).count == manifest.participants.count
            && Set(manifest.participants.map(\.colorIndex)).count
                == manifest.participants.count
    }

    private static func validatedSettlement(
        _ response: MultiplayerSettlementResponse
    ) throws -> MultiplayerSettlementResponse {
        let submittedCountIsValid = response.submittedCount.map { $0 >= 0 } ?? true
        let participantCountIsValid =
            response.participantCount.map { count in
                (MultiplayerAPIContract.minimumPlayers...MultiplayerAPIContract.maximumPlayers)
                    .contains(count)
            } ?? true
        let resultsAreValid =
            response.results?.allSatisfy(Self.isValidSettlementResult) ?? true
        guard !response.state.isEmpty,
            submittedCountIsValid,
            participantCountIsValid,
            response.state != "settled"
                || (response.leaderboardEligible
                    && response.verification == "peer_consistent_v1"
                    && response.results != nil),
            response.state != "review" || !response.leaderboardEligible,
            resultsAreValid
        else {
            throw invalidMultiplayerResponse()
        }
        return response
    }

    private static func isValidSettlementResult(_ result: MultiplayerSettlementResult) -> Bool {
        UUID(uuidString: result.resultId) != nil
            && UUID(uuidString: result.participantId) != nil
            && (1...result.playerCount).contains(result.place)
            && (MultiplayerAPIContract.minimumPlayers...MultiplayerAPIContract.maximumPlayers)
                .contains(result.playerCount)
            && result.score >= 0
            && result.survivalMs >= 0
            && result.hits >= 0
            && result.misses >= 0
            && result.dodges >= 0
            && (1...5).contains(result.maxMultiplier)
    }

    private static func validatedMatchID(_ value: String) throws -> String {
        guard let uuid = UUID(uuidString: value) else {
            throw invalidMultiplayerRequest("The multiplayer match ID is invalid.")
        }
        return uuid.uuidString.lowercased()
    }

    private static func isBase64URLSHA256(_ value: String) -> Bool {
        value.utf8.count == 43
            && value.unicodeScalars.allSatisfy {
                CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_"
            }
    }

    private static func isStructurallyValidTranscript(_ events: [[Int]]) -> Bool {
        guard !events.isEmpty, events.count <= MultiplayerAPIContract.maximumEvents else {
            return false
        }
        var previousTime = 0
        for (index, event) in events.enumerated() {
            guard event.count >= 3,
                event[1] == index + 1,
                (0...6).contains(event[0])
            else { return false }
            let expectedCount: Int
            let logicalTimeIndex: Int
            switch event[0] {
            case 0:
                expectedCount = 7
                logicalTimeIndex = 2
            case 1, 2:
                expectedCount = 7
                logicalTimeIndex = 3
            case 3:
                expectedCount = 8
                logicalTimeIndex = 2
            case 4, 5:
                expectedCount = 4
                logicalTimeIndex = 2
            case 6:
                expectedCount = 3
                logicalTimeIndex = 2
            default:
                return false
            }
            guard event.count == expectedCount,
                event[logicalTimeIndex] >= previousTime,
                event[logicalTimeIndex] <= MultiplayerAPIContract.maximumDurationMilliseconds
            else { return false }
            previousTime = event[logicalTimeIndex]
        }
        return events.last?.first == 6
    }

    private static func invalidMultiplayerRequest(_ message: String) -> BackendError {
        BackendError(status: 400, message: message, code: "invalid-multiplayer-request")
    }

    private static func invalidMultiplayerResponse() -> BackendError {
        BackendError(
            status: 200,
            message: "The multiplayer service response could not be read.",
            code: "invalid-multiplayer-response"
        )
    }
}
