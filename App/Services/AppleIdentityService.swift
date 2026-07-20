import AuthenticationServices
import Foundation
import UIKit

struct AppleSystemAuthorizationResult: Equatable, Sendable {
    let state: String?
    let identityToken: Data?
    let authorizationCode: Data?
}

enum AppleIdentityServiceError: LocalizedError, Equatable {
    case authorizationInProgress
    case presentationUnavailable
    case cancelled
    case stateMismatch
    case incompleteCredential

    var errorDescription: String? {
        switch self {
        case .authorizationInProgress:
            "Another Sign in with Apple request is already open."
        case .presentationUnavailable:
            "Sign in with Apple cannot open right now. Please try again."
        case .cancelled:
            "Sign in with Apple was cancelled."
        case .stateMismatch:
            "Sign in with Apple could not verify this request. Please try again."
        case .incompleteCredential:
            "Apple returned an incomplete authorization. Please try again."
        }
    }
}

@MainActor
final class AppleIdentityService: NSObject {
    typealias AuthorizationPerformer =
        @MainActor (AppleSignInChallenge) async throws
        -> AppleSystemAuthorizationResult
    typealias PresentationAnchorProvider = @MainActor () -> ASPresentationAnchor?

    private let authorizationPerformer: AuthorizationPerformer?
    private let presentationAnchorProvider: PresentationAnchorProvider
    private var authorizationContinuation: CheckedContinuation<AppleSystemAuthorizationResult, Error>?
    private var authorizationController: ASAuthorizationController?
    private var presentationAnchor: ASPresentationAnchor?
    private var authorizationInProgress = false

    init(
        authorizationPerformer: AuthorizationPerformer? = nil,
        presentationAnchorProvider: @escaping PresentationAnchorProvider =
            AppleIdentityService.activePresentationAnchor
    ) {
        self.authorizationPerformer = authorizationPerformer
        self.presentationAnchorProvider = presentationAnchorProvider
        super.init()
    }

    func authorize(challenge: AppleSignInChallenge) async throws -> AppleAuthorizationProof {
        guard !authorizationInProgress else {
            throw AppleIdentityServiceError.authorizationInProgress
        }
        authorizationInProgress = true
        defer { authorizationInProgress = false }

        let result: AppleSystemAuthorizationResult
        do {
            if let authorizationPerformer {
                result = try await authorizationPerformer(challenge)
            } else {
                result = try await performSystemAuthorization(challenge: challenge)
            }
        } catch {
            if Self.isCancellation(error) {
                throw AppleIdentityServiceError.cancelled
            }
            throw error
        }

        guard result.state == challenge.state else {
            throw AppleIdentityServiceError.stateMismatch
        }
        guard let identityTokenData = result.identityToken,
            let authorizationCodeData = result.authorizationCode,
            let identityToken = String(data: identityTokenData, encoding: .utf8),
            let authorizationCode = String(data: authorizationCodeData, encoding: .utf8),
            !identityToken.isEmpty,
            !authorizationCode.isEmpty
        else {
            throw AppleIdentityServiceError.incompleteCredential
        }

        return AppleAuthorizationProof(
            state: challenge.state,
            identityToken: identityToken,
            authorizationCode: authorizationCode
        )
    }

    private func performSystemAuthorization(
        challenge: AppleSignInChallenge
    ) async throws -> AppleSystemAuthorizationResult {
        guard let presentationAnchor = presentationAnchorProvider() else {
            throw AppleIdentityServiceError.presentationUnavailable
        }
        self.presentationAnchor = presentationAnchor

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.nonce = challenge.nonce
        request.state = challenge.state

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                authorizationContinuation = continuation
                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = self
                controller.presentationContextProvider = self
                authorizationController = controller
                controller.performRequests()
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finishSystemAuthorization(throwing: CancellationError())
            }
        }
    }

    private func finishSystemAuthorization(
        returning result: AppleSystemAuthorizationResult
    ) {
        let continuation = authorizationContinuation
        authorizationContinuation = nil
        authorizationController = nil
        presentationAnchor = nil
        continuation?.resume(returning: result)
    }

    private func finishSystemAuthorization(throwing error: Error) {
        let continuation = authorizationContinuation
        authorizationContinuation = nil
        authorizationController = nil
        presentationAnchor = nil
        continuation?.resume(throwing: error)
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let nsError = error as NSError
        return nsError.domain == ASAuthorizationError.errorDomain
            && nsError.code == ASAuthorizationError.canceled.rawValue
    }

    private static func activePresentationAnchor() -> ASPresentationAnchor? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        return scenes.lazy
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
            ?? scenes.lazy.flatMap(\.windows).first
    }
}

extension AppleIdentityService: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller _: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finishSystemAuthorization(throwing: AppleIdentityServiceError.incompleteCredential)
            return
        }
        finishSystemAuthorization(
            returning: AppleSystemAuthorizationResult(
                state: credential.state,
                identityToken: credential.identityToken,
                authorizationCode: credential.authorizationCode
            )
        )
    }

    func authorizationController(
        controller _: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        finishSystemAuthorization(throwing: error)
    }
}

extension AppleIdentityService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchor
            ?? AppleIdentityService.activePresentationAnchor()
            ?? ASPresentationAnchor(frame: .zero)
    }
}
