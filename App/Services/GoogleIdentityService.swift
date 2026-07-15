import GoogleSignIn
import UIKit

enum GoogleIdentityError: LocalizedError {
    case notConfigured
    case noPresenter
    case missingIDToken

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Add the PimPoPom iOS OAuth client ID to Config/Local.xcconfig."
        case .noPresenter:
            "Google Sign-In could not open from the current screen."
        case .missingIDToken:
            "Google Sign-In returned no server identity token."
        }
    }
}

@MainActor
final class GoogleIdentityService {
    var isConfigured: Bool {
        !iOSClientID.hasPrefix("placeholder") && iOSClientID.hasSuffix(".apps.googleusercontent.com")
    }

    func signIn() async throws -> String {
        guard isConfigured else { throw GoogleIdentityError.notConfigured }
        guard let presenter = presentingViewController() else {
            throw GoogleIdentityError.noPresenter
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: iOSClientID,
            serverClientID: serverClientID
        )
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let token = result.user.idToken?.tokenString, !token.isEmpty else {
            throw GoogleIdentityError.missingIDToken
        }
        return token
    }

    func restoreIDTokenIfAvailable() async throws -> String? {
        guard isConfigured, GIDSignIn.sharedInstance.hasPreviousSignIn() else { return nil }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: iOSClientID,
            serverClientID: serverClientID
        )
        let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
        let refreshed = try await user.refreshTokensIfNeeded()
        return refreshed.idToken?.tokenString
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    private var iOSClientID: String {
        Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String ?? ""
    }

    private var serverClientID: String {
        Bundle.main.object(forInfoDictionaryKey: "GIDServerClientID") as? String ?? ""
    }

    private func presentingViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var controller = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
