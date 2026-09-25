import DeclaredAgeRange
import UIKit

/// The controller serializes Apple presentations after any Google consent form.
@MainActor
final class AppleAgeService: AppleAgeServing {
    private let findPresenter: @MainActor () -> UIViewController?
    private let readinessDelay: @MainActor () async throws -> Void
    private let readinessAttempts: Int

    init(
        findPresenter: @escaping @MainActor () -> UIViewController? = AppleAgeService.attachedPresenter,
        readinessAttempts: Int = 50,
        readinessDelay: @escaping @MainActor () async throws -> Void = {
            try await Task.sleep(for: .milliseconds(100))
        }
    ) {
        self.findPresenter = findPresenter
        self.readinessAttempts = readinessAttempts
        self.readinessDelay = readinessDelay
    }

    func regulatoryRequirement() async throws -> AppleAgeRequirement {
        try await Self.readRegulatoryRequirement()
    }

    func requestAgeRange() async throws -> AppleAgeResponse {
        guard #available(iOS 26.0, *) else { return .unsupported }
        try Task.checkCancellation()
        do {
            let presenter = try await waitForPresenter()
            let response = try await AgeRangeService.shared.requestAgeRange(
                ageGates: 13, 16, 18, in: presenter
            )
            // Return a shared range even after cancellation so the sticky lock is retained.
            switch response {
            case .declinedSharing:
                try Task.checkCancellation()
                return .declined
            case .sharing(let range):
                let shared = AppleSharedAgeRange(
                    lowerBound: range.lowerBound, upperBound: range.upperBound,
                    hasParentalControls: !range.activeParentalControls.isEmpty
                )
                guard shared.isValid else { throw AgeServiceError.invalidRange }
                return .shared(shared)
            @unknown default:
                throw AgeServiceError.invalidRange
            }
        } catch AgeRangeService.Error.notAvailable {
            try Task.checkCancellation()
            return .declined
        }
    }

    // Return only our immutable applicability result across the SDK actor boundary.
    nonisolated private static func readRegulatoryRequirement() async throws -> AppleAgeRequirement {
        if #available(iOS 26.2, *) {
            return try await AgeRangeService.shared.isEligibleForAgeFeatures ? .required : .optional
        }
        return .legacy
    }

    func waitForPresenter() async throws -> UIViewController {
        for _ in 0..<readinessAttempts {
            try Task.checkCancellation()
            if let presenter = findPresenter() { return presenter }
            try await readinessDelay()
        }
        throw AgeServiceError.presenterNotReady
    }

    private static func attachedPresenter() -> UIViewController? {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        guard top.isViewLoaded, top.view.window != nil,
            !top.isBeingDismissed, !top.isBeingPresented
        else { return nil }
        return top
    }
}

enum AgeServiceError: Error {
    case presenterNotReady
    case invalidRange
}
