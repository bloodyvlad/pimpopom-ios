import DeclaredAgeRange
import UIKit

/// The controller serializes Apple presentations after any Google consent form.
@MainActor
final class AppleAgeService: AppleAgeServing {
    func requestAgeRange() async throws -> AppleAgeResponse {
        guard #available(iOS 26.0, *) else { return .unsupported }
        let isRequired = try await Self.ageRangeIsRequired()
        // iOS26.0/26.1 expose DAR but no regional-requirements query. Their
        // optional-sharing fallback is legacy behavior, not proof of no controls.
        try Task.checkCancellation()
        do {
            let response = try await AgeRangeService.shared.requestAgeRange(
                ageGates: 13, 16, 18, in: presenter()
            )
            switch response {
            case .declinedSharing:
                return .declined(isRequired: isRequired)
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
            if #available(iOS 26.2, *) { throw AgeServiceError.unavailable }
            return .unsupported
        }
    }

    // Apple's regional query types are not Sendable in the iOS26.5 SDK.
    // Keep those values on the nonisolated side; only a Bool enters UI isolation.
    nonisolated private static func ageRangeIsRequired() async throws -> Bool {
        if #available(iOS 26.4, *) {
            let features = try await AgeRangeService.shared.requiredRegulatoryFeatures
            return features.contains(.declaredAgeRangeRequired)
        }
        if #available(iOS 26.2, *) {
            return try await AgeRangeService.shared.isEligibleForAgeFeatures
        }
        return false
    }

    private func presenter() throws -> UIViewController {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        else { throw AgeServiceError.unavailable }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

private enum AgeServiceError: Error {
    case unavailable
    case invalidRange
}
