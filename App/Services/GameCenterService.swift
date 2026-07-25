import Combine
import Foundation
import GameKit
import UIKit

struct GameCenterPlayerIdentity: Equatable, Sendable {
    let displayName: String
    let gamePlayerID: String
    let teamPlayerID: String
    let scopedIDsArePersistent: Bool

    init(
        displayName: String,
        gamePlayerID: String,
        teamPlayerID: String,
        scopedIDsArePersistent: Bool = true
    ) {
        self.displayName = displayName
        self.gamePlayerID = gamePlayerID
        self.teamPlayerID = teamPlayerID
        self.scopedIDsArePersistent = scopedIDsArePersistent
    }
}

struct GameCenterIdentityVerification: Equatable, Sendable {
    let signedTeamPlayerID: String
    let gamePlayerID: String
    let bundleIdentifier: String
    let publicKeyURL: URL
    let signature: Data
    let salt: Data
    let timestamp: UInt64
}

enum GameCenterConnectionState: Equatable {
    case disabled
    case idle
    case authenticating
    case authenticated(GameCenterPlayerIdentity)
    case unavailable(String)
}

enum GameCenterLinkIssue: Equatable {
    case primaryReauthenticationRequired
    case conflict(String)
    case unavailable(String)
}

enum GameCenterProfileState: Equatable {
    case gameCenterSignedOut
    case gameCenterUnavailable(String)
    case primaryProfileRequired
    case primaryReauthenticationRequired
    case scopedIDsTransient
    case unlinked
    case linkedIdentityOnly
    case publicationQueued(Int)
    case mirrorReady
    case publicationHeld(Int)
    case conflict(String)
    case resetNeedsSupport
}

enum GameCenterProfileStateResolver {
    static func resolve(
        connection: GameCenterConnectionState,
        primaryProfileAuthenticated: Bool,
        identityBinding: Bool,
        serverStatus: GameCenterServerStatus?,
        issue: GameCenterLinkIssue?
    ) -> GameCenterProfileState {
        switch connection {
        case .disabled, .idle, .authenticating:
            return .gameCenterSignedOut
        case .unavailable(let message):
            return .gameCenterUnavailable(message)
        case .authenticated(let player):
            guard primaryProfileAuthenticated else {
                return .primaryProfileRequired
            }
            if issue == .primaryReauthenticationRequired {
                return .primaryReauthenticationRequired
            }
            guard player.scopedIDsArePersistent else {
                return .scopedIDsTransient
            }
            if case .conflict(let message) = issue {
                return .conflict(message)
            }
            if case .unavailable(let message) = issue {
                return .gameCenterUnavailable(message)
            }

            if let serverStatus {
                if serverStatus.heldJobs > 0 {
                    return .publicationHeld(serverStatus.heldJobs)
                }
                if serverStatus.needsReset {
                    return .resetNeedsSupport
                }
                guard serverStatus.identityLinked, identityBinding else {
                    return .unlinked
                }
                guard serverStatus.publicationEnabled,
                    serverStatus.serverPublicationAvailable
                else {
                    return .linkedIdentityOnly
                }
                if serverStatus.pendingJobs > 0 {
                    return .publicationQueued(serverStatus.pendingJobs)
                }
                if serverStatus.mirrorReady {
                    return .mirrorReady
                }
                return .linkedIdentityOnly
            }
            return identityBinding ? .linkedIdentityOnly : .unlinked
        }
    }
}

enum GameCenterServiceError: LocalizedError, Equatable {
    case notAuthenticated
    case incompleteIdentity
    case scopedIDsTransient
    case incompleteVerification
    case identityChanged
    case verificationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "Sign in to Game Center before verifying this player."
        case .incompleteIdentity:
            "Game Center returned an incomplete player identity."
        case .scopedIDsTransient:
            "Game Center has not provided persistent player IDs yet. Try again later."
        case .incompleteVerification:
            "Game Center returned an incomplete identity signature."
        case .identityChanged:
            "The Game Center player changed during identity verification."
        case .verificationFailed(let message):
            message
        }
    }
}

@MainActor
struct GameCenterClient {
    typealias AuthenticationCallback = @MainActor (UIViewController?, String?) -> Void
    typealias VerificationCallback = @MainActor (URL?, Data?, Data?, UInt64, String?) -> Void

    let installAuthenticationHandler: (@escaping AuthenticationCallback) -> Void
    let removeAuthenticationHandler: () -> Void
    let isAuthenticated: () -> Bool
    let displayName: () -> String
    let gamePlayerID: () -> String
    let teamPlayerID: () -> String
    let scopedIDsArePersistent: () -> Bool
    let fetchIdentityVerification: (@escaping VerificationCallback) -> Void

    static let live = GameCenterClient(
        installAuthenticationHandler: { callback in
            GKLocalPlayer.local.authenticateHandler = { viewController, error in
                callback(viewController, error?.localizedDescription)
            }
        },
        removeAuthenticationHandler: {
            GKLocalPlayer.local.authenticateHandler = nil
        },
        isAuthenticated: { GKLocalPlayer.local.isAuthenticated },
        displayName: { GKLocalPlayer.local.displayName },
        gamePlayerID: { GKLocalPlayer.local.gamePlayerID },
        teamPlayerID: { GKLocalPlayer.local.teamPlayerID },
        scopedIDsArePersistent: { GKLocalPlayer.local.scopedIDsArePersistent() },
        fetchIdentityVerification: { callback in
            GKLocalPlayer.local.fetchItems(forIdentityVerificationSignature: {
                publicKeyURL,
                signature,
                salt,
                timestamp,
                error in
                let errorDescription = error?.localizedDescription
                Task { @MainActor in
                    callback(
                        publicKeyURL,
                        signature,
                        salt,
                        timestamp,
                        errorDescription
                    )
                }
            })
        }
    )
}

@MainActor
final class GameCenterService: ObservableObject {
    static let participationPreferenceKey = "game-center.participation.enabled"

    @Published private(set) var state: GameCenterConnectionState
    @Published private(set) var participationEnabled: Bool

    private let client: GameCenterClient
    private let defaults: UserDefaults
    private let arguments: [String]
    private let environment: [String: String]
    private let bundleIdentifier: String
    private let presentAuthenticationViewController: @MainActor (UIViewController) -> Bool
    private var hasInstalledAuthenticationHandler = false
    private var authenticationGeneration = 0

    init(
        client: GameCenterClient = .live,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "",
        defaults: UserDefaults = .standard,
        presentAuthenticationViewController: @escaping @MainActor (UIViewController) -> Bool =
            GameCenterService.presentAuthenticationViewController
    ) {
        self.client = client
        self.arguments = arguments
        self.environment = environment
        self.bundleIdentifier = bundleIdentifier
        self.defaults = defaults
        self.presentAuthenticationViewController = presentAuthenticationViewController
        let savedParticipation = defaults.bool(forKey: Self.participationPreferenceKey)
        participationEnabled = savedParticipation
        state = savedParticipation ? .idle : .disabled
    }

    func resumeAuthenticationIfOptedIn() {
        guard participationEnabled else {
            state = .disabled
            return
        }
        startAuthentication()
    }

    func connect() {
        startAuthentication()
    }

    private func startAuthentication() {
        guard !hasInstalledAuthenticationHandler else { return }
        installAuthenticationHandler()
    }

    func retryAuthentication() {
        installAuthenticationHandler()
    }

    func disableParticipation() {
        authenticationGeneration += 1
        client.removeAuthenticationHandler()
        hasInstalledAuthenticationHandler = false
        setParticipationEnabled(false)
        state = .disabled
    }

    func fetchIdentityVerification() async throws -> GameCenterIdentityVerification {
        guard case .authenticated(let player) = state, client.isAuthenticated() else {
            throw GameCenterServiceError.notAuthenticated
        }
        guard player.scopedIDsArePersistent, client.scopedIDsArePersistent() else {
            throw GameCenterServiceError.scopedIDsTransient
        }
        let signedTeamPlayerID = player.teamPlayerID
        let gamePlayerID = player.gamePlayerID

        return try await withCheckedThrowingContinuation { continuation in
            client.fetchIdentityVerification { publicKeyURL, signature, salt, timestamp, error in
                if let error {
                    continuation.resume(
                        throwing: GameCenterServiceError.verificationFailed(error)
                    )
                    return
                }
                guard self.client.isAuthenticated() else {
                    continuation.resume(throwing: GameCenterServiceError.notAuthenticated)
                    return
                }
                guard self.client.teamPlayerID() == signedTeamPlayerID else {
                    continuation.resume(throwing: GameCenterServiceError.identityChanged)
                    return
                }
                guard self.client.gamePlayerID() == gamePlayerID,
                    self.client.scopedIDsArePersistent()
                else {
                    continuation.resume(throwing: GameCenterServiceError.identityChanged)
                    return
                }
                guard let publicKeyURL,
                    publicKeyURL.scheme?.lowercased() == "https",
                    let signature,
                    !signature.isEmpty,
                    let salt,
                    !salt.isEmpty,
                    timestamp > 0,
                    !self.bundleIdentifier.isEmpty
                else {
                    continuation.resume(throwing: GameCenterServiceError.incompleteVerification)
                    return
                }
                continuation.resume(
                    returning: GameCenterIdentityVerification(
                        signedTeamPlayerID: signedTeamPlayerID,
                        gamePlayerID: gamePlayerID,
                        bundleIdentifier: self.bundleIdentifier,
                        publicKeyURL: publicKeyURL,
                        signature: signature,
                        salt: salt,
                        timestamp: timestamp
                    )
                )
            }
        }
    }

    private func installAuthenticationHandler() {
        hasInstalledAuthenticationHandler = true

        if arguments.contains("--uitesting")
            || environment["XCTestConfigurationFilePath"] != nil
        {
            hasInstalledAuthenticationHandler = false
            state = .unavailable("Unavailable in deterministic automated tests")
            return
        }

        state = .authenticating
        authenticationGeneration += 1
        let generation = authenticationGeneration
        client.installAuthenticationHandler { [weak self] viewController, error in
            guard self?.authenticationGeneration == generation else { return }
            self?.handleAuthentication(viewController: viewController, error: error)
        }
        if authenticationGeneration == generation, client.isAuthenticated() {
            publishAuthenticatedPlayer()
        }
    }

    private func handleAuthentication(viewController: UIViewController?, error: String?) {
        if let viewController {
            state = .authenticating
            if !presentAuthenticationViewController(viewController) {
                client.removeAuthenticationHandler()
                hasInstalledAuthenticationHandler = false
                state = .unavailable("Game Center could not open its sign-in screen.")
            }
            return
        }

        if client.isAuthenticated() {
            publishAuthenticatedPlayer()
            return
        }

        client.removeAuthenticationHandler()
        hasInstalledAuthenticationHandler = false
        state = .unavailable(error ?? "Game Center is unavailable. PimPoPom still works normally.")
    }

    private func publishAuthenticatedPlayer() {
        let identity = GameCenterPlayerIdentity(
            displayName: client.displayName(),
            gamePlayerID: client.gamePlayerID(),
            teamPlayerID: client.teamPlayerID(),
            scopedIDsArePersistent: client.scopedIDsArePersistent()
        )
        guard !identity.gamePlayerID.isEmpty, !identity.teamPlayerID.isEmpty else {
            state = .unavailable(
                GameCenterServiceError.incompleteIdentity.localizedDescription
            )
            return
        }
        setParticipationEnabled(true)
        state = .authenticated(identity)
    }

    private func setParticipationEnabled(_ enabled: Bool) {
        participationEnabled = enabled
        defaults.set(enabled, forKey: Self.participationPreferenceKey)
    }

    private static func presentAuthenticationViewController(
        _ viewController: UIViewController
    ) -> Bool {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var presenter = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = presenter?.presentedViewController {
            if presented === viewController { return true }
            presenter = presented
        }
        guard let presenter else { return false }
        presenter.present(viewController, animated: true)
        return true
    }
}
