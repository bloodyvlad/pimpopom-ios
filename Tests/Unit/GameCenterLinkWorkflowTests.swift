import XCTest

@testable import PimPoPom

@MainActor
final class GameCenterLinkWorkflowTests: XCTestCase {
    func testExplicitVerificationAlwaysUsesFreshProofEvenWhenMirrorIsAlreadyReady() async throws {
        let profile = makeProfile()
        let serverStatus = makeStatus(mirrorReady: true)
        let session = makeSession(profile: profile, status: serverStatus)
        let challenge = GameCenterLinkChallenge(
            challengeId: "challenge-1",
            expiresAt: "2026-07-27T12:00:00Z"
        )
        let verification = makeVerification()
        let response = GameCenterLinkResponse(
            profile: profile,
            identityBindings: IdentityBindings(
                google: true,
                apple: false,
                gameCenter: true
            ),
            gameCenter: serverStatus
        )
        var sessionLoads = 0
        var challengeRequests = 0
        var proofRequests = 0
        var submissions = 0
        var markedProfileID: String?

        let workflow = GameCenterLinkWorkflow(
            loadSession: {
                sessionLoads += 1
                return session
            },
            contextIsActive: { true },
            issueChallenge: { playerID in
                XCTAssertEqual(playerID, profile.id)
                challengeRequests += 1
                return challenge
            },
            fetchVerification: {
                proofRequests += 1
                return verification
            },
            submit: { submittedChallenge, submittedVerification, playerID in
                XCTAssertEqual(submittedChallenge, challenge)
                XCTAssertEqual(submittedVerification, verification)
                XCTAssertEqual(playerID, profile.id)
                submissions += 1
                return response
            },
            markRuntimeVerification: { playerID, submittedVerification in
                XCTAssertEqual(submittedVerification, verification)
                markedProfileID = playerID
            }
        )

        try await workflow.perform(playerID: profile.id)

        XCTAssertEqual(sessionLoads, 2)
        XCTAssertEqual(challengeRequests, 1)
        XCTAssertEqual(proofRequests, 1)
        XCTAssertEqual(submissions, 1)
        XCTAssertEqual(markedProfileID, profile.id)
    }

    func testContextChangeCancelsBeforeRequestingGameKitProof() async {
        let profile = makeProfile()
        let session = makeSession(profile: profile, status: makeStatus(mirrorReady: true))
        var contextChecks = 0
        var proofRequests = 0

        let workflow = GameCenterLinkWorkflow(
            loadSession: { session },
            contextIsActive: {
                contextChecks += 1
                return contextChecks == 1
            },
            issueChallenge: { _ in
                GameCenterLinkChallenge(
                    challengeId: "challenge-1",
                    expiresAt: "2026-07-27T12:00:00Z"
                )
            },
            fetchVerification: {
                proofRequests += 1
                return self.makeVerification()
            },
            submit: { _, _, _ in
                XCTFail("A stale context must not submit a Game Center proof.")
                throw CancellationError()
            },
            markRuntimeVerification: { _, _ in
                XCTFail("A stale context must not become runtime-verified.")
            }
        )

        do {
            try await workflow.perform(playerID: profile.id)
            XCTFail("Expected cancellation after the profile/player context changed.")
        } catch is CancellationError {
            XCTAssertEqual(proofRequests, 0)
        }
    }

    private func makeProfile() -> PlayerProfile {
        PlayerProfile(
            id: "00000000-0000-4000-8000-000000000051",
            nickname: "ArcadeTester",
            nicknameConfirmed: true,
            coins: 0,
            totalPlayMs: 0,
            ownedPetIds: [],
            selectedPetId: nil,
            petVisible: false,
            equippedPetId: nil,
            specialPetId: nil,
            ownedThemeIds: [],
            selectedThemeId: nil,
            isAdmin: false,
            createdAt: "2026-07-27T10:00:00Z",
            updatedAt: "2026-07-27T10:00:00Z"
        )
    }

    private func makeStatus(mirrorReady: Bool) -> GameCenterServerStatus {
        GameCenterServerStatus(
            serverPublicationAvailable: true,
            preReleased: true,
            identityLinked: true,
            publicationEnabled: true,
            mirrorReady: mirrorReady,
            pendingJobs: 0,
            heldJobs: 0,
            needsReset: false
        )
    }

    private func makeSession(
        profile: PlayerProfile,
        status: GameCenterServerStatus
    ) -> SessionResponse {
        SessionResponse(
            authenticated: true,
            csrfToken: "csrf",
            googleClientId: "google-client",
            season: Season(id: "season-1", name: "Season 1"),
            profile: profile,
            identityBindings: IdentityBindings(
                google: true,
                apple: false,
                gameCenter: true
            ),
            gameCenter: status,
            ranks: [:]
        )
    }

    private func makeVerification() -> GameCenterIdentityVerification {
        GameCenterIdentityVerification(
            signedTeamPlayerID: "team-player-1",
            gamePlayerID: "game-player-1",
            bundleIdentifier: "com.otcsoftware.pimpopom",
            publicKeyURL: URL(string: "https://static.gc.apple.com/public-key")!,
            signature: Data([1]),
            salt: Data([2]),
            timestamp: 1
        )
    }
}
