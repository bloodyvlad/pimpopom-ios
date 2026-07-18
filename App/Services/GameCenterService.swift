import Combine
import GameKit
import UIKit

struct GameCenterPlayerIdentity: Equatable, Sendable {
    let displayName: String
    let gamePlayerID: String
    let teamPlayerID: String
}

struct GameCenterIdentityVerification: Equatable, Sendable {
    let signedTeamPlayerID: String
    let bundleIdentifier: String
    let publicKeyURL: URL
    let signature: Data
    let salt: Data
    let timestamp: UInt64
}

enum GameCenterConnectionState: Equatable {
    case idle
    case authenticating
    case authenticated(GameCenterPlayerIdentity)
    case unavailable(String)
}

enum GameCenterServiceError: LocalizedError, Equatable {
    case notAuthenticated
    case incompleteIdentity
    case incompleteVerification
    case identityChanged
    case verificationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "Sign in to Game Center before verifying this player."
        case .incompleteIdentity:
            "Game Center returned an incomplete player identity."
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
    let isAuthenticated: () -> Bool
    let displayName: () -> String
    let gamePlayerID: () -> String
    let teamPlayerID: () -> String
    let fetchIdentityVerification: (@escaping VerificationCallback) -> Void

    static let live = GameCenterClient(
        installAuthenticationHandler: { callback in
            GKLocalPlayer.local.authenticateHandler = { viewController, error in
                callback(viewController, error?.localizedDescription)
            }
        },
        isAuthenticated: { GKLocalPlayer.local.isAuthenticated },
        displayName: { GKLocalPlayer.local.displayName },
        gamePlayerID: { GKLocalPlayer.local.gamePlayerID },
        teamPlayerID: { GKLocalPlayer.local.teamPlayerID },
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
    @Published private(set) var state = GameCenterConnectionState.idle

    private let client: GameCenterClient
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
        presentAuthenticationViewController: @escaping @MainActor (UIViewController) -> Bool =
            GameCenterService.presentAuthenticationViewController
    ) {
        self.client = client
        self.arguments = arguments
        self.environment = environment
        self.bundleIdentifier = bundleIdentifier
        self.presentAuthenticationViewController = presentAuthenticationViewController
    }

    func startAuthentication() {
        guard !hasInstalledAuthenticationHandler else { return }
        installAuthenticationHandler()
    }

    func retryAuthentication() {
        installAuthenticationHandler()
    }

    func fetchIdentityVerification() async throws -> GameCenterIdentityVerification {
        guard case .authenticated(let player) = state, client.isAuthenticated() else {
            throw GameCenterServiceError.notAuthenticated
        }
        let signedTeamPlayerID = player.teamPlayerID

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
    }

    private func handleAuthentication(viewController: UIViewController?, error: String?) {
        if let viewController {
            state = .authenticating
            if !presentAuthenticationViewController(viewController) {
                state = .unavailable("Game Center could not open its sign-in screen.")
            }
            return
        }

        if client.isAuthenticated() {
            let identity = GameCenterPlayerIdentity(
                displayName: client.displayName(),
                gamePlayerID: client.gamePlayerID(),
                teamPlayerID: client.teamPlayerID()
            )
            guard !identity.gamePlayerID.isEmpty, !identity.teamPlayerID.isEmpty else {
                state = .unavailable(
                    GameCenterServiceError.incompleteIdentity.localizedDescription
                )
                return
            }
            state = .authenticated(identity)
            return
        }

        state = .unavailable(error ?? "Game Center is unavailable. PimPoPom still works normally.")
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
