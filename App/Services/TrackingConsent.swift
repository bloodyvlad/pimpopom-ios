import AppTrackingTransparency
import UIKit

enum TrackingPermission: Equatable, Sendable {
    case notDetermined, authorized, denied, restricted
}

/// UMP collects regulatory choices first. This policy decides whether asking
/// Apple for tracking permission has a purpose; it never replaces UMP ad eligibility.
enum TrackingConsentPolicy {
    static func permitsPersonalization(age: AdAgeBand?, regulatoryConsent: Bool, permission: TrackingPermission) -> Bool
    {
        age == .adult && regulatoryConsent && permission == .authorized
    }

    static func shouldRequest(age: AdAgeBand?, regulatoryConsent: Bool, permission: TrackingPermission) -> Bool {
        age == .adult && regulatoryConsent && permission == .notDetermined
    }

    static func permitsGooglePersonalization(
        consentNotRequired: Bool, gdprApplies: Int?, purposes: String?, vendors: String?
    ) -> Bool {
        if gdprApplies == 1 {
            // Google is TCF vendor 755. The SDK also enforces its remaining
            // purpose, legitimate-interest, publisher-restriction and GPP signals.
            return [1, 3, 4].allSatisfy { bit($0, in: purposes) } && bit(755, in: vendors)
        }
        return consentNotRequired || gdprApplies == 0
    }

    private static func bit(_ position: Int, in value: String?) -> Bool {
        guard let value else { return false }
        let bits = Array(value.utf8)
        return bits.indices.contains(position - 1) && bits[position - 1] == 49
    }
}

@MainActor
protocol TrackingAuthorizing {
    var permission: TrackingPermission { get }
    func request() async -> TrackingPermission
}

@MainActor
struct AppleTrackingAuthorization: TrackingAuthorizing {
    var permission: TrackingPermission {
        switch ATTrackingManager.trackingAuthorizationStatus {
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        default: .notDetermined
        }
    }

    func request() async -> TrackingPermission {
        guard permission == .notDetermined else { return permission }
        // UMP has finished its presentation. Wait for an active attached scene
        // before invoking ATT; iOS ignores permission requests while inactive.
        guard (try? await AppleAgeService().waitForPresenter()) != nil else { return permission }
        guard UIApplication.shared.applicationState == .active else { return permission }
        _ = await ATTrackingManager.requestTrackingAuthorization()
        return permission
    }
}
