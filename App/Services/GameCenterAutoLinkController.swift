import Combine
import Foundation

struct GameCenterAutoLinkContext: Equatable, Sendable {
    let profileID: String
    let gamePlayerID: String
    let teamPlayerID: String
}

enum GameCenterAutoLinkState: Equatable {
    case idle
    case linking
    case linked
    case deferred
}

/// Silently associates the Game Center player currently authenticated by iOS
/// with the PimPoPom profile currently authenticated by the PHP service.
///
/// Failures never block gameplay or surface account-conflict UI. A later
/// foreground event or primary sign-in retries the complete fresh proof flow.
@MainActor
final class GameCenterAutoLinkController: ObservableObject {
    typealias CurrentContext = @MainActor () -> GameCenterAutoLinkContext?
    typealias ServerLinkIsReady = @MainActor () -> Bool
    typealias Link = @MainActor (GameCenterAutoLinkContext) async throws -> Void

    @Published private(set) var state: GameCenterAutoLinkState = .idle

    private let currentContext: CurrentContext
    private let serverLinkIsReady: ServerLinkIsReady
    private let link: Link
    private var completedContext: GameCenterAutoLinkContext?
    private var activeContext: GameCenterAutoLinkContext?
    private var activeTask: Task<Void, Never>?
    private var generation = 0

    init(
        currentContext: @escaping CurrentContext,
        serverLinkIsReady: @escaping ServerLinkIsReady = { true },
        link: @escaping Link
    ) {
        self.currentContext = currentContext
        self.serverLinkIsReady = serverLinkIsReady
        self.link = link
    }

    convenience init(
        backend: BackendClient,
        gameCenter: GameCenterService
    ) {
        self.init(
            currentContext: {
                Self.liveContext(backend: backend, gameCenter: gameCenter)
            },
            serverLinkIsReady: {
                backend.sessionState?.identityBindings?.gameCenter == true
                    && backend.sessionState?.gameCenter?.identityLinked == true
                    && backend.sessionState?.gameCenter?.publicationEnabled == true
            },
            link: { context in
                let workflow = GameCenterLinkWorkflow(
                    loadSession: {
                        try await backend.loadSession()
                    },
                    contextIsActive: {
                        Self.liveContext(backend: backend, gameCenter: gameCenter)
                            == context
                    },
                    issueChallenge: { playerID in
                        try await backend.issueGameCenterLinkChallenge(
                            expectedPlayerID: playerID
                        )
                    },
                    fetchVerification: {
                        try await gameCenter.fetchIdentityVerification()
                    },
                    submit: { challenge, verification, playerID in
                        try await backend.linkGameCenter(
                            challenge: challenge,
                            verification: verification,
                            expectedPlayerID: playerID
                        )
                    },
                    markRuntimeVerification: { playerID, verification in
                        try gameCenter.markRuntimeVerification(
                            profileID: playerID,
                            verification: verification
                        )
                    }
                )
                try await workflow.perform(playerID: context.profileID)
            }
        )
    }

    func reconcile() {
        guard let context = currentContext() else {
            reset()
            return
        }
        if completedContext == context, serverLinkIsReady() {
            state = .linked
            return
        }
        if completedContext == context {
            completedContext = nil
        }
        guard activeContext != context else { return }

        generation += 1
        let activeGeneration = generation
        activeTask?.cancel()
        activeContext = context
        state = .linking
        activeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await link(context)
                guard activeGeneration == generation,
                    currentContext() == context
                else { return }
                completedContext = context
                state = .linked
            } catch is CancellationError {
                guard activeGeneration == generation else { return }
                state = .idle
            } catch {
                guard activeGeneration == generation,
                    currentContext() == context
                else { return }
                // Game Center is supplementary. A future foreground or
                // primary-login event retries without interrupting the player.
                state = .deferred
            }
            if activeGeneration == generation {
                activeContext = nil
                activeTask = nil
            }
        }
    }

    func reset() {
        generation += 1
        activeTask?.cancel()
        activeTask = nil
        activeContext = nil
        completedContext = nil
        state = .idle
    }

    private static func liveContext(
        backend: BackendClient,
        gameCenter: GameCenterService
    ) -> GameCenterAutoLinkContext? {
        guard backend.isAuthenticated,
            let profileID = backend.profile?.id,
            case .authenticated(let player) = gameCenter.state,
            player.scopedIDsArePersistent
        else { return nil }
        return GameCenterAutoLinkContext(
            profileID: profileID,
            gamePlayerID: player.gamePlayerID,
            teamPlayerID: player.teamPlayerID
        )
    }
}
