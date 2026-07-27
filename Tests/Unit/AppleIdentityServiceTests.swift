import Foundation
import XCTest

@testable import PimPoPom

@MainActor
final class AppleIdentityServiceTests: XCTestCase {
    func testProfileAppleEntryUsesLoginOrCreateIntentWithoutASecondPrompt() {
        XCTAssertEqual(ProfileAuthenticationPolicy.appleEntryIntent, .register)
    }

    func testAuthorizationUsesExactChallengeAndReturnsUTF8Proof() async throws {
        var receivedChallenge: AppleSignInChallenge?
        let service = AppleIdentityService { challenge in
            receivedChallenge = challenge
            return AppleSystemAuthorizationResult(
                state: challenge.state,
                identityToken: Data("header.payload.signature".utf8),
                authorizationCode: Data("one-time-code".utf8)
            )
        }
        let challenge = Self.challenge()

        let proof = try await service.authorize(challenge: challenge)

        XCTAssertEqual(receivedChallenge, challenge)
        XCTAssertEqual(
            proof,
            AppleAuthorizationProof(
                state: "server-state",
                identityToken: "header.payload.signature",
                authorizationCode: "one-time-code"
            )
        )
    }

    func testAuthorizationRejectsMismatchedState() async throws {
        let service = AppleIdentityService { _ in
            AppleSystemAuthorizationResult(
                state: "attacker-state",
                identityToken: Data("token".utf8),
                authorizationCode: Data("code".utf8)
            )
        }

        do {
            _ = try await service.authorize(challenge: Self.challenge())
            XCTFail("Apple state must match the backend challenge exactly.")
        } catch let error as AppleIdentityServiceError {
            XCTAssertEqual(error, .stateMismatch)
        }
    }

    func testAuthorizationRejectsMissingTokenOrCode() async throws {
        for result in [
            AppleSystemAuthorizationResult(
                state: "server-state",
                identityToken: nil,
                authorizationCode: Data("code".utf8)
            ),
            AppleSystemAuthorizationResult(
                state: "server-state",
                identityToken: Data("token".utf8),
                authorizationCode: nil
            ),
        ] {
            let service = AppleIdentityService { _ in result }
            do {
                _ = try await service.authorize(challenge: Self.challenge())
                XCTFail("Incomplete Apple credentials must not reach the backend.")
            } catch let error as AppleIdentityServiceError {
                XCTAssertEqual(error, .incompleteCredential)
            }
        }
    }

    func testOnlyOneAppleAuthorizationMayRunAtATime() async throws {
        var continuation: CheckedContinuation<AppleSystemAuthorizationResult, Error>?
        let service = AppleIdentityService { challenge in
            try await withCheckedThrowingContinuation { pending in
                continuation = pending
            }
        }
        let first = Task { @MainActor in
            try await service.authorize(challenge: Self.challenge())
        }
        while continuation == nil { await Task.yield() }

        do {
            _ = try await service.authorize(challenge: Self.challenge())
            XCTFail("A second Apple sheet must not replace the first request.")
        } catch let error as AppleIdentityServiceError {
            XCTAssertEqual(error, .authorizationInProgress)
        }

        continuation?.resume(
            returning: AppleSystemAuthorizationResult(
                state: "server-state",
                identityToken: Data("token".utf8),
                authorizationCode: Data("code".utf8)
            )
        )
        _ = try await first.value
    }

    private static func challenge() -> AppleSignInChallenge {
        AppleSignInChallenge(
            challengeId: "challenge-id",
            nonce: "raw-server-nonce",
            state: "server-state",
            intent: .login,
            audience: "com.otcsoftware.pimpopom",
            expiresAt: "2026-07-20T15:00:00Z"
        )
    }
}
