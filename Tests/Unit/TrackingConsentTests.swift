import XCTest

@testable import PimPoPom

@MainActor
final class TrackingConsentTests: XCTestCase {
    func testOnlyConsentingAdultCanRequestATTOrEnablePersonalization() {
        let ages: [AdAgeBand?] = [nil, .under13, .youngTeen, .olderTeen, .adult]
        let permissions: [TrackingPermission] = [.notDetermined, .authorized, .denied, .restricted]
        for age in ages {
            for consent in [false, true] {
                for permission in permissions {
                    XCTAssertEqual(
                        TrackingConsentPolicy.shouldRequest(
                            age: age, regulatoryConsent: consent, permission: permission),
                        age == .adult && consent && permission == .notDetermined
                    )
                    XCTAssertEqual(
                        TrackingConsentPolicy.permitsPersonalization(
                            age: age, regulatoryConsent: consent, permission: permission),
                        age == .adult && consent && permission == .authorized
                    )
                }
            }
        }
    }

    func testEuropeanConsentDoesNotConfuseAdEligibilityWithTrackingConsent() {
        let googleConsent = String(repeating: "0", count: 754) + "1"
        XCTAssertTrue(
            TrackingConsentPolicy.permitsGooglePersonalization(
                consentNotRequired: false, gdprApplies: 1, purposes: "1011", vendors: googleConsent
            ))
        for purposes in [nil, "", "1000", "1001", "0011", "1010"] {
            XCTAssertFalse(
                TrackingConsentPolicy.permitsGooglePersonalization(
                    consentNotRequired: false, gdprApplies: 1, purposes: purposes, vendors: googleConsent
                ))
        }
        for vendors in [nil, "", "1", String(repeating: "0", count: 755)] {
            XCTAssertFalse(
                TrackingConsentPolicy.permitsGooglePersonalization(
                    consentNotRequired: false, gdprApplies: 1, purposes: "1111", vendors: vendors
                ))
        }
        // Missing regional signals fail closed unless UMP explicitly says consent
        // is not required; false eligibility is never an adult-age assertion.
        XCTAssertFalse(
            TrackingConsentPolicy.permitsGooglePersonalization(
                consentNotRequired: false, gdprApplies: nil, purposes: nil, vendors: nil
            ))
        XCTAssertTrue(
            TrackingConsentPolicy.permitsGooglePersonalization(
                consentNotRequired: true, gdprApplies: nil, purposes: nil, vendors: nil
            ))
    }

    func testSkipPersistsWithoutInventingAnAgeOrBindingToAnAccount() {
        let suite = "consent-choice-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsAdAgeBandStore(defaults: defaults)
        XCTAssertFalse(store.hasCompletedAgeChoice)
        store.hasCompletedAgeChoice = true
        store.confirmedProfileID = "first-account"
        let restored = UserDefaultsAdAgeBandStore(defaults: defaults)
        restored.confirmedProfileID = nil
        XCTAssertTrue(restored.hasCompletedAgeChoice)
        XCTAssertNil(restored.ageBand)
    }
}
