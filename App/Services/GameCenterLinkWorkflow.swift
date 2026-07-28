import Foundation

/// Executes one complete Game Center verification round-trip.
///
/// Server mirror state is intentionally never a shortcut: every invocation
/// obtains a new server challenge and a new GameKit identity signature for the
/// player currently authenticated on this device.
@MainActor
struct GameCenterLinkWorkflow {
    let loadSession: @MainActor () async throws -> SessionResponse
    let contextIsActive: @MainActor () -> Bool
    let issueChallenge: @MainActor (String) async throws -> GameCenterLinkChallenge
    let fetchVerification: @MainActor () async throws -> GameCenterIdentityVerification
    let submit:
        @MainActor (
            GameCenterLinkChallenge,
            GameCenterIdentityVerification,
            String
        ) async throws -> GameCenterLinkResponse
    let markRuntimeVerification: @MainActor (String, GameCenterIdentityVerification) throws -> Void

    func perform(playerID: String) async throws {
        let session = try await loadSession()
        guard session.authenticated, session.profile?.id == playerID else {
            throw BackendError(
                status: 401,
                message: "Sign in to the intended PimPoPom profile before linking Game Center.",
                code: "primary-profile-required"
            )
        }
        guard contextIsActive() else { throw CancellationError() }

        let challenge = try await issueChallenge(playerID)
        try Task.checkCancellation()
        guard contextIsActive() else { throw CancellationError() }

        let verification = try await fetchVerification()
        try Task.checkCancellation()
        guard contextIsActive() else { throw CancellationError() }

        let linked = try await submit(challenge, verification, playerID)
        try Task.checkCancellation()
        guard linked.profile.id == playerID,
            linked.identityBindings.gameCenter,
            linked.gameCenter.identityLinked,
            linked.gameCenter.publicationEnabled
        else {
            throw BackendError(
                status: 409,
                message: "Game Center did not link to the current PimPoPom profile.",
                code: "game-center-link-account-mismatch"
            )
        }

        let refreshed = try await loadSession()
        try Task.checkCancellation()
        guard refreshed.profile?.id == playerID,
            refreshed.identityBindings?.gameCenter == true,
            refreshed.gameCenter?.identityLinked == true,
            refreshed.gameCenter?.publicationEnabled == true
        else {
            throw BackendError(
                status: 409,
                message: "Game Center did not remain linked to the current PimPoPom profile.",
                code: "game-center-link-not-confirmed"
            )
        }
        guard contextIsActive() else { throw CancellationError() }
        try markRuntimeVerification(playerID, verification)
    }
}
