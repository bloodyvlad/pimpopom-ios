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
    case idle
    case authenticating
    case authenticated(GameCenterPlayerIdentity)
    case unavailable(String)
}

@MainActor
private final class GameCenterDashboardPresenter:
    NSObject, @preconcurrency GKGameCenterControllerDelegate,
    UIAdaptivePresentationControllerDelegate
{
    static let shared = GameCenterDashboardPresenter()

    private weak var dashboard: GKGameCenterViewController?
    private var completion: (@MainActor @Sendable () -> Void)?

    func present(completion: @escaping @MainActor @Sendable () -> Void) -> Bool {
        guard GKLocalPlayer.local.isAuthenticated,
            self.completion == nil,
            let presenter = Self.activePresenter()
        else { return false }

        let dashboard = GKGameCenterViewController(state: .dashboard)
        dashboard.gameCenterDelegate = self
        self.dashboard = dashboard
        self.completion = completion
        presenter.present(dashboard, animated: true) {
            dashboard.presentationController?.delegate = self
        }
        return true
    }

    func gameCenterViewControllerDidFinish(
        _ gameCenterViewController: GKGameCenterViewController
    ) {
        let completion = takeCompletion()
        gameCenterViewController.dismiss(animated: true) {
            completion?()
        }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        takeCompletion()?()
    }

    private func takeCompletion() -> (@MainActor @Sendable () -> Void)? {
        let pendingCompletion = completion
        self.completion = nil
        dashboard = nil
        return pendingCompletion
    }

    private static func activePresenter() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var presenter = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = presenter?.presentedViewController {
            presenter = presented
        }
        return presenter
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
    typealias DashboardCompletion = @MainActor () -> Void

    let installAuthenticationHandler: (@escaping AuthenticationCallback) -> Void
    let removeAuthenticationHandler: () -> Void
    let isAuthenticated: () -> Bool
    let displayName: () -> String
    let gamePlayerID: () -> String
    let teamPlayerID: () -> String
    let scopedIDsArePersistent: () -> Bool
    let fetchIdentityVerification: (@escaping VerificationCallback) -> Void
    let showDashboard: (@escaping DashboardCompletion) -> Bool

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
        },
        showDashboard: { completion in
            GameCenterDashboardPresenter.shared.present(completion: completion)
        }
    )
}

@MainActor
final class GameCenterService: ObservableObject {
    @Published private(set) var state: GameCenterConnectionState
    @Published private(set) var runtimeVerifiedProfileID: String?
    @Published private(set) var isOpeningStats = false

    private let client: GameCenterClient
    private let arguments: [String]
    private let environment: [String: String]
    private let bundleIdentifier: String
    private let presentAuthenticationViewController: @MainActor (UIViewController) -> Bool
    private var hasInstalledAuthenticationHandler = false
    private var authenticationGeneration = 0
    private var runtimeVerification: RuntimeVerification?

    private struct RuntimeVerification: Equatable {
        let profileID: String
        let gamePlayerID: String
        let teamPlayerID: String
        let verifiedAt: Date
    }

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
        runtimeVerifiedProfileID = nil
        state = .idle
    }

    func authenticateAtLaunch() {
        startAuthentication()
    }

    private func startAuthentication() {
        if hasInstalledAuthenticationHandler {
            if client.isAuthenticated() {
                publishAuthenticatedPlayer()
            }
            return
        }
        installAuthenticationHandler()
    }

    @discardableResult
    func showStats() -> Bool {
        guard case .authenticated = state,
            client.isAuthenticated(),
            !isOpeningStats
        else { return false }

        isOpeningStats = true
        let presented = client.showDashboard { [weak self] in
            self?.isOpeningStats = false
        }
        if !presented {
            isOpeningStats = false
        }
        return presented
    }

    func markRuntimeVerification(
        profileID: String,
        verification: GameCenterIdentityVerification
    ) throws {
        guard case .authenticated(let player) = state,
            client.isAuthenticated(),
            player.scopedIDsArePersistent,
            client.scopedIDsArePersistent(),
            verification.bundleIdentifier == bundleIdentifier,
            player.gamePlayerID == verification.gamePlayerID,
            player.teamPlayerID == verification.signedTeamPlayerID,
            client.gamePlayerID() == verification.gamePlayerID,
            client.teamPlayerID() == verification.signedTeamPlayerID
        else {
            clearRuntimeVerification()
            throw GameCenterServiceError.identityChanged
        }

        runtimeVerification = RuntimeVerification(
            profileID: profileID,
            gamePlayerID: verification.gamePlayerID,
            teamPlayerID: verification.signedTeamPlayerID,
            verifiedAt: Date()
        )
        runtimeVerifiedProfileID = profileID
    }

    func clearRuntimeVerification() {
        runtimeVerification = nil
        runtimeVerifiedProfileID = nil
    }

    func isCurrentRuntimePlayerVerified(
        for profileID: String,
        maximumAge: TimeInterval? = nil,
        now: Date = Date()
    ) -> Bool {
        guard let runtimeVerification,
            runtimeVerification.profileID == profileID,
            maximumAge.map({
                now.timeIntervalSince(runtimeVerification.verifiedAt) >= 0
                    && now.timeIntervalSince(runtimeVerification.verifiedAt) <= $0
            }) ?? true,
            case .authenticated(let player) = state,
            player.gamePlayerID == runtimeVerification.gamePlayerID,
            player.teamPlayerID == runtimeVerification.teamPlayerID,
            player.scopedIDsArePersistent,
            client.isAuthenticated(),
            client.scopedIDsArePersistent(),
            client.gamePlayerID() == runtimeVerification.gamePlayerID,
            client.teamPlayerID() == runtimeVerification.teamPlayerID
        else { return false }
        return true
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
        clearRuntimeVerification()
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
            clearRuntimeVerification()
            state = .unavailable(
                GameCenterServiceError.incompleteIdentity.localizedDescription
            )
            return
        }
        if let runtimeVerification,
            !identity.scopedIDsArePersistent
                || runtimeVerification.gamePlayerID != identity.gamePlayerID
                || runtimeVerification.teamPlayerID != identity.teamPlayerID
        {
            clearRuntimeVerification()
        }
        state = .authenticated(identity)
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
