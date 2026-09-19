import GoogleMobileAds
import UIKit
import XCTest

@testable import PimPoPom

@MainActor
final class AppleAgeControllerTests: XCTestCase {
    func testEveryManualChoicePersistsAndUnder13CannotEnterTheApp() async {
        for band in AdAgeBand.allCases {
            let fixture = Fixture(.declined, storedAge: nil)
            fixture.service.requirement = .optional
            await fixture.age.refresh()
            await fixture.age.chooseManualAge(band)
            XCTAssertEqual(fixture.ageStore.ageBand, band)
            XCTAssertTrue(fixture.ageStore.hasCompletedAgeChoice)
            XCTAssertEqual(fixture.ads.allowsApp, band != .under13)
            XCTAssertEqual(fixture.age.state, band == .under13 ? .under13 : .ready)
            await fixture.age.refresh()
            XCTAssertEqual(fixture.age.state, band == .under13 ? .under13 : .ready)
            XCTAssertEqual(fixture.service.calls, 0)
        }
    }

    func testInclusiveAndOverriddenRangesUseYoungestPossibleAge() {
        let cases: [(Int?, Int?, AdAgeBand)] = [
            (nil, 12, .under13), (12, 17, .under13), (13, 15, .youngTeen),
            (13, 17, .youngTeen), (13, nil, .youngTeen), (16, 17, .olderTeen),
            (16, nil, .olderTeen), (18, nil, .adult), (21, 25, .adult),
        ]
        for (lower, upper, expected) in cases {
            let range = AppleSharedAgeRange(lowerBound: lower, upperBound: upper, hasParentalControls: false)
            XCTAssertTrue(range.isValid)
            XCTAssertEqual(range.adBand, expected)
        }
        XCTAssertEqual(Self.range(13, 17).displayTitle, "13–17")
        for range in [Self.range(nil, nil), Self.range(-1, 12), Self.range(18, 17)] {
            XCTAssertFalse(range.isValid)
            XCTAssertEqual(range.adBand, .under13)
        }
    }

    func testStartupDoesNotTrustPreviouslyStoredAdultBeforeAppleReturns() async {
        let fixture = Fixture(.shared(Self.range(16, 17)))
        XCTAssertFalse(fixture.ads.allowsApp)
        await fixture.ads.bootstrap(session: Self.anonymous)
        XCTAssertEqual(fixture.consent.requestCount, 0)
        XCTAssertEqual(fixture.inventory.startCount, 0)
        await fixture.age.refresh()
        XCTAssertTrue(fixture.ads.allowsApp)
        XCTAssertEqual(fixture.ads.ageBand, .olderTeen)
        await fixture.ads.bootstrap(session: Self.anonymous)
        XCTAssertEqual(fixture.consent.requestedAgeBands, [.olderTeen])
    }

    func testParentControlledAppleRangeCannotBeManuallyOverridden() async {
        let fixture = Fixture(.shared(Self.range(13, 15, parental: true)))
        await fixture.age.refresh()
        XCTAssertTrue(fixture.ads.appleParentalControls)
        XCTAssertFalse(fixture.ads.canManuallyChangeAge)
        await fixture.ads.setAgeBand(.adult)
        XCTAssertEqual(fixture.ads.ageBand, .youngTeen)
        XCTAssertEqual(fixture.ads.appleAgeDescription, "13–15")
    }

    func testUnder13AppleRangeBlocksBeforeAnyConsentOrAdStart() async {
        let fixture = Fixture(.shared(Self.range(nil, 12, parental: true)))
        await fixture.age.refresh()
        await fixture.ads.bootstrap(session: Self.anonymous)
        XCTAssertEqual(fixture.age.state, .under13)
        XCTAssertFalse(fixture.ads.allowsApp)
        XCTAssertFalse(fixture.ads.canManuallyChangeAge)
        XCTAssertEqual(fixture.consent.requestCount, 0)
        XCTAssertEqual(fixture.inventory.startCount, 0)
    }

    func testOptionalAndLegacyStartupOffersSkippableChoiceWithoutAppleRequest() async {
        for requirement in [AppleAgeRequirement.optional, .legacy] {
            let fixture = Fixture(.declined, storedAge: nil)
            fixture.service.requirement = requirement
            await fixture.age.refresh()
            XCTAssertEqual(fixture.age.state, .manual)
            XCTAssertFalse(fixture.ads.allowsApp)
            await fixture.age.chooseManualAge(nil)
            XCTAssertEqual(fixture.age.state, .ready)
            XCTAssertTrue(fixture.ads.allowsApp)
            XCTAssertNil(fixture.ads.ageBand)
            XCTAssertNil(fixture.ageStore.ageBand)
            XCTAssertEqual(fixture.service.calls, 0)
            do { try await fixture.age.waitForAuthorization() } catch {
                XCTFail("Optional app access must authorize identity")
            }
        }
    }

    func testRequiredDeclineAndTransientErrorDoNotUseStoredAdult() async {
        let fixture = Fixture(.declined)
        await fixture.age.refresh()
        XCTAssertEqual(fixture.age.state, .sharingRequired)
        XCTAssertFalse(fixture.ads.allowsApp)
        fixture.service.error = TestFailure.unavailable
        await fixture.age.refresh()
        XCTAssertEqual(fixture.age.state, .failed)
        XCTAssertFalse(fixture.ads.allowsApp)
        XCTAssertFalse(fixture.ads.canManuallyChangeAge)
    }

    func testRememberedAppleLockSurvivesDeclineErrorAndRelaunch() async {
        let lock = MemoryAppleLock()
        let first = Fixture(.shared(Self.range(18, nil)), lock: lock)
        await first.age.refresh()
        XCTAssertTrue(lock.hasSharedAppleRange)
        for response in [AppleAgeResponse.declined, .unsupported] {
            let next = Fixture(response, lock: lock)
            await next.age.refresh()
            XCTAssertEqual(next.age.state, .sharingRequired)
            XCTAssertFalse(next.ads.canManuallyChangeAge)
            XCTAssertFalse(next.ads.allowsApp)
        }
    }

    func testForegroundClosesOldInventoryThenAppliesFreshTeenPolicy() async {
        let fixture = Fixture(.shared(Self.range(18, nil)))
        await fixture.age.refresh()
        await fixture.ads.bootstrap(session: Self.anonymous)
        XCTAssertTrue(fixture.ads.canAttachBanner)
        fixture.age.setInBackground(true)
        XCTAssertFalse(fixture.ads.allowsApp)
        XCTAssertFalse(fixture.ads.canAttachBanner)
        fixture.service.response = .shared(Self.range(13, 17, parental: true))
        fixture.age.setInBackground(false)
        await fixture.age.waitUntilIdle()
        await fixture.ads.bootstrap(session: Self.anonymous)
        XCTAssertEqual(fixture.consent.requestedAgeBands, [.adult, .youngTeen])
        XCTAssertEqual(fixture.ads.appleAgeDescription, "13–17")
    }

    func testSupersededAppleRequestsSerializeAndCannotReopenAdultAccess() async {
        let fixture = Fixture(.shared(Self.range(18, nil)))
        fixture.service.holdNextRequest = true
        fixture.age.scheduleRefresh()
        await waitForCalls(1, service: fixture.service)
        fixture.service.response = .shared(Self.range(nil, 12, parental: true))
        fixture.age.scheduleRefresh()
        await Task.yield()
        XCTAssertEqual(fixture.service.calls, 1)
        XCTAssertFalse(fixture.ads.allowsApp)
        fixture.service.release()
        await fixture.age.waitUntilIdle()
        XCTAssertEqual(fixture.service.calls, 2)
        XCTAssertEqual(fixture.age.state, .under13)
        XCTAssertFalse(fixture.ads.allowsApp)
    }

    func testRestoredDifferentAccountPreservesDeviceAgeAndConsent() async {
        let fixture = Fixture(.shared(Self.range(18, nil)), binding: "previous-profile")
        await fixture.age.refresh()
        await fixture.ads.bootstrap(session: Self.anonymous)
        XCTAssertEqual(fixture.service.calls, 1)
        XCTAssertEqual(fixture.consent.requestCount, 1)
        XCTAssertTrue(fixture.ads.isAgeConfirmed(for: Self.anonymous))
        await fixture.ads.updateSession(nil)
        await fixture.ads.updateSession(Self.anonymous)
        XCTAssertEqual(fixture.service.calls, 1)
        XCTAssertEqual(fixture.consent.requestCount, 1)
        XCTAssertEqual(fixture.ads.ageBand, .adult)
    }

    func testStaleSharedChildRangeStillPreventsLaterManualDowngrade() async {
        let fixture = Fixture(.shared(Self.range(nil, 12, parental: true)))
        fixture.service.holdNextRequest = true
        fixture.age.scheduleRefresh()
        await waitForCalls(1, service: fixture.service)
        fixture.age.setInBackground(true)
        fixture.service.release()
        await fixture.age.waitUntilIdle()
        fixture.service.response = .declined
        fixture.age.setInBackground(false)
        await fixture.age.waitUntilIdle()
        XCTAssertEqual(fixture.age.state, .sharingRequired)
        XCTAssertFalse(fixture.ads.canManuallyChangeAge)
        XCTAssertFalse(fixture.ads.allowsApp)
    }

    func testApplePresentationWaitsForPriorConsentOperationToFinish() async {
        let queue = ConsentOperationQueue()
        var release: CheckedContinuation<Void, Never>?
        let operation = Task {
            try await queue.run { _ in
                await withCheckedContinuation { release = $0 }
                return ConsentSnapshot(canRequestAds: false, privacyOptionsRequirement: .unknown)
            }
        }
        for _ in 0..<1000 where release == nil { await Task.yield() }
        XCTAssertNotNil(release)
        queue.invalidate()
        var drained = false
        let waiter = Task {
            await queue.waitUntilIdle()
            drained = true
        }
        await Task.yield()
        XCTAssertFalse(drained)
        release?.resume()
        await waiter.value
        _ = try? await operation.value
        XCTAssertTrue(drained)
    }

    func testIdentityCompletionWaitsForFreshAgeAndRejectsUnder13() async {
        for eligible in [true, false] {
            let fixture = Fixture(.shared(Self.range(18, nil)))
            await fixture.age.refresh()
            fixture.age.setInBackground(true)
            var returned = false
            let authorization = Task {
                do {
                    try await fixture.age.waitForAuthorization()
                    returned = true
                } catch {}
            }
            await Task.yield()
            XCTAssertFalse(returned)
            fixture.service.response = .shared(eligible ? Self.range(16, 17) : Self.range(nil, 12))
            fixture.age.setInBackground(false)
            await fixture.age.waitUntilIdle()
            await authorization.value
            XCTAssertEqual(returned, eligible)
        }
    }

    func testCancelledIdentityAgeWaitDoesNotResumeAuthentication() async {
        let fixture = Fixture(.shared(Self.range(18, nil)))
        var returned = false
        let authorization = Task {
            do {
                try await fixture.age.waitForAuthorization()
                returned = true
            } catch {}
        }
        await Task.yield()
        authorization.cancel()
        await authorization.value
        await fixture.age.refresh()
        XCTAssertFalse(returned)
    }

    func testNonPersonalizedRequestFactorySetsNPA() {
        for _ in 0..<2 {
            let request = GoogleAdsService.nonPersonalizedRequest()
            let extras = request.adNetworkExtras(for: Extras.self) as? Extras
            XCTAssertEqual(extras?.additionalParameters?["npa"] as? String, "1")
        }
    }

    func testUnknownAgeCompletesConsentAdsAndAccountStartupWithoutInventingBand() async {
        let fixture = Fixture(.declined, storedAge: nil)
        fixture.service.requirement = .optional
        await fixture.age.refresh()
        await fixture.age.chooseManualAge(nil)
        await fixture.ads.bootstrap(session: Self.anonymous)
        XCTAssertEqual(fixture.consent.requestedAgeBands, [nil])
        XCTAssertEqual(fixture.inventory.configuredAgeBands, [nil])
        XCTAssertTrue(fixture.ads.canAttachBanner)
        XCTAssertNotNil(fixture.ads.confirmedAccountStartupID(for: Self.anonymous))
        XCTAssertEqual(fixture.ageStore.confirmedProfileID, "anonymous")
        XCTAssertNil(fixture.ageStore.ageBand)
        XCTAssertEqual(fixture.service.calls, 0)
    }

    func testUnknownAgeConsentFailurePreservesPlayButDoesNotStartAds() async {
        let fixture = Fixture(.declined, storedAge: nil)
        fixture.service.requirement = .optional
        fixture.consent.requestError = TestFailure.unavailable
        await fixture.age.refresh()
        await fixture.age.chooseManualAge(nil)
        await fixture.ads.bootstrap(session: Self.anonymous)
        XCTAssertTrue(fixture.ads.allowsApp)
        XCTAssertFalse(fixture.ads.canAttachBanner)
        XCTAssertEqual(fixture.inventory.startCount, 0)
        XCTAssertNotNil(fixture.ads.confirmedAccountStartupID(for: Self.anonymous))
    }

    func testUnknownAgeSDKParametersUseUnspecifiedTreatmentAndRegularConsent() {
        XCTAssertFalse(GoogleConsentService.requestParameters(for: nil).isTaggedForUnderAgeOfConsent)
        XCTAssertEqual(GoogleAdsService.ageRestrictedTreatment(for: nil), .unspecified)
    }

    func testOptionalAccountChangeDoesNotInheritStoredAdultOrRequestAppleSharing() async {
        let fixture = Fixture(.declined, binding: "previous-profile")
        fixture.service.requirement = .optional
        await fixture.age.refresh()
        await fixture.ads.bootstrap(session: Self.anonymous)
        await fixture.age.waitUntilIdle()
        await fixture.ads.bootstrap(session: Self.anonymous)
        XCTAssertTrue(fixture.ads.allowsApp)
        XCTAssertEqual(fixture.ads.ageBand, .adult)
        XCTAssertEqual(fixture.consent.requestedAgeBands, [.adult])
        XCTAssertEqual(fixture.service.calls, 0)
        XCTAssertNotNil(fixture.ads.confirmedAccountStartupID(for: Self.anonymous))
    }

    func testOptionalStartupPreservesPreviouslyKnownUnder13Restriction() async {
        let fixture = Fixture(.declined, storedAge: .under13)
        fixture.service.requirement = .optional
        await fixture.age.refresh()
        await fixture.ads.bootstrap(session: Self.anonymous)
        XCTAssertEqual(fixture.age.state, .under13)
        XCTAssertFalse(fixture.ads.allowsApp)
        XCTAssertEqual(fixture.ads.ageBand, .under13)
        XCTAssertEqual(fixture.service.calls, 0)
        XCTAssertEqual(fixture.consent.requestCount, 0)
        XCTAssertEqual(fixture.inventory.startCount, 0)
    }

    func testOptionalForegroundNeverRequestsSharingOrHidesUnknownAgePlay() async {
        let fixture = Fixture(.declined, storedAge: nil)
        fixture.service.requirement = .optional
        await fixture.age.refresh()
        await fixture.age.chooseManualAge(nil)
        let ageGeneration = fixture.ads.ageConfirmationGeneration
        fixture.age.setInBackground(true)
        XCTAssertTrue(fixture.ads.allowsApp)
        fixture.age.setInBackground(false)
        XCTAssertTrue(fixture.ads.allowsApp)
        await fixture.age.waitUntilIdle()
        XCTAssertEqual(fixture.service.calls, 0)
        XCTAssertEqual(fixture.service.requirementCalls, 2)
        XCTAssertEqual(fixture.ads.ageConfirmationGeneration, ageGeneration)
    }

    func testUnknownRegionalRequirementCannotAuthorizeUnknownAge() async {
        let fixture = Fixture(.declined, storedAge: nil)
        fixture.service.requirementError = NSError(domain: "RegionalService", code: 4)
        await fixture.age.refresh()
        XCTAssertFalse(fixture.ads.allowsApp)
        XCTAssertEqual(fixture.age.state, .failed)
        XCTAssertEqual(fixture.service.calls, 0)
        XCTAssertEqual(
            fixture.age.diagnostic,
            AppleAgeDiagnostic(stage: "regional-requirement", domain: "RegionalService", code: 4))
    }

    func testOptionalRegionNeverRequestsSharingForHistoricalAppleLock() async {
        let lock = MemoryAppleLock()
        lock.hasSharedAppleRange = true
        let fixture = Fixture(.declined, storedAge: nil, lock: lock)
        fixture.service.requirement = .optional
        await fixture.age.refresh()
        XCTAssertEqual(fixture.service.calls, 0)
        XCTAssertEqual(fixture.age.state, .ready)
        XCTAssertTrue(fixture.ads.allowsApp)
        XCTAssertNil(fixture.ads.ageBand)
        XCTAssertFalse(fixture.ads.canManuallyChangeAge)
    }

    func testFalseEligibilityPreservesSharedParentRangeWithoutAnotherRequest() async {
        let fixture = Fixture(.shared(Self.range(13, 15, parental: true)))
        await fixture.age.refresh()
        fixture.service.requirement = .optional
        fixture.age.setInBackground(true)
        fixture.age.setInBackground(false)
        await fixture.age.waitUntilIdle()
        XCTAssertEqual(fixture.service.calls, 1)
        XCTAssertTrue(fixture.ads.allowsApp)
        XCTAssertEqual(fixture.ads.ageBand, .youngTeen)
        XCTAssertEqual(fixture.ads.appleAgeDescription, "13–15")
        XCTAssertTrue(fixture.ads.appleParentalControls)
        XCTAssertFalse(fixture.ads.canManuallyChangeAge)
    }

    func testFalseEligibilityKeepsLateSharedChildRestriction() async {
        let fixture = Fixture(.shared(Self.range(nil, 12, parental: true)))
        fixture.service.holdNextRequest = true
        fixture.age.scheduleRefresh()
        await waitForCalls(1, service: fixture.service)
        fixture.age.setInBackground(true)
        fixture.service.requirement = .optional
        fixture.service.release()
        await fixture.age.waitUntilIdle()
        fixture.age.setInBackground(false)
        await fixture.age.waitUntilIdle()
        XCTAssertEqual(fixture.service.calls, 1)
        XCTAssertEqual(fixture.age.state, .under13)
        XCTAssertEqual(fixture.ads.ageBand, .under13)
        XCTAssertFalse(fixture.ads.allowsApp)
        XCTAssertTrue(fixture.ads.appleParentalControls)
    }

    func testFalseEligibilityAccountChangeRestoresKnownAppleChildProtection() async {
        let lock = MemoryAppleLock()
        lock.hasSharedAppleRange = true
        let fixture = Fixture(.declined, storedAge: .youngTeen, binding: "previous-profile", lock: lock)
        fixture.service.requirement = .optional
        await fixture.age.refresh()
        await fixture.ads.bootstrap(session: Self.anonymous)
        await fixture.age.waitUntilIdle()
        await fixture.ads.bootstrap(session: Self.anonymous)
        XCTAssertEqual(fixture.service.calls, 0)
        XCTAssertEqual(fixture.ads.ageBand, .youngTeen)
        XCTAssertEqual(fixture.consent.requestedAgeBands, [.youngTeen])
        XCTAssertFalse(fixture.ads.canManuallyChangeAge)
        XCTAssertNotNil(fixture.ads.confirmedAccountStartupID(for: Self.anonymous))
    }

    func testActualAppleProtectionPersistsAcrossControllerRelaunch() async {
        let lock = MemoryAppleLock()
        let first = Fixture(.shared(Self.range(16, 17, parental: true)), lock: lock)
        await first.age.refresh()
        let next = Fixture(.declined, storedAge: nil, lock: lock)
        next.service.requirement = .optional
        await next.age.refresh()
        XCTAssertEqual(next.service.calls, 0)
        XCTAssertEqual(next.ads.ageBand, .olderTeen)
        XCTAssertEqual(next.ads.appleAgeDescription, "16–17")
        XCTAssertTrue(next.ads.appleParentalControls)
        XCTAssertFalse(next.ads.canManuallyChangeAge)
    }

    func testLateAdultResponseDoesNotBecomeCurrentAgeAfterFalseEligibility() async {
        let fixture = Fixture(.shared(Self.range(18, nil)), storedAge: nil)
        fixture.service.holdNextRequest = true
        fixture.age.scheduleRefresh()
        await waitForCalls(1, service: fixture.service)
        fixture.age.setInBackground(true)
        fixture.service.requirement = .optional
        fixture.service.release()
        await fixture.age.waitUntilIdle()
        fixture.age.setInBackground(false)
        await fixture.age.waitUntilIdle()
        XCTAssertEqual(fixture.service.calls, 1)
        XCTAssertTrue(fixture.ads.allowsApp)
        XCTAssertNil(fixture.ads.ageBand)
        XCTAssertNil(fixture.age.sharedRange)
    }

    func testPresenterReadinessAutomaticallyRetriesThenUsesAttachedWindow() async throws {
        var attempts = 0
        var delays = 0
        let presenter = UIViewController()
        let service = AppleAgeService(
            findPresenter: {
                attempts += 1
                return attempts == 3 ? presenter : nil
            },
            readinessAttempts: 4,
            readinessDelay: { delays += 1 }
        )
        let result = try await service.waitForPresenter()
        XCTAssertTrue(result === presenter)
        XCTAssertEqual(delays, 2)
    }

    private func waitForCalls(_ count: Int, service: TestAppleAgeService) async {
        for _ in 0..<1000 where service.calls < count { await Task.yield() }
        XCTAssertEqual(service.calls, count)
    }

    private static func range(_ lower: Int?, _ upper: Int?, parental: Bool = false) -> AppleSharedAgeRange {
        AppleSharedAgeRange(lowerBound: lower, upperBound: upper, hasParentalControls: parental)
    }

    private static let anonymous = SessionResponse(
        authenticated: false, csrfToken: "csrf", googleClientId: "google",
        season: Season(id: "season", name: "Season"), profile: nil, adFree: nil, ranks: nil
    )
}

@MainActor
private final class Fixture {
    let age: AppleAgeController
    let ads: AdsController
    let service: TestAppleAgeService
    let consent = FakeConsentService()
    let inventory = FakeAdsService()
    let ageStore: MemoryAdAgeBandStore

    init(
        _ response: AppleAgeResponse, storedAge: AdAgeBand? = .adult,
        binding: String? = nil, lock: MemoryAppleLock? = nil
    ) {
        service = TestAppleAgeService(response)
        ageStore = MemoryAdAgeBandStore(storedAge, confirmedProfileID: binding)
        ads = AdsController(
            configuration: .uiTesting(adsEnabled: true), consentService: consent,
            adsService: inventory, progressStore: MemoryInterstitialProgressStore(),
            ageStore: ageStore
        )
        age = AppleAgeController(ads: ads, service: service, store: lock ?? MemoryAppleLock())
    }
}

@MainActor
private final class MemoryAppleLock: AppleAgeLockStoring {
    var hasSharedAppleRange = false
    var lastKnownProtection: AppleAgeProtection?
}

@MainActor
private final class TestAppleAgeService: AppleAgeServing {
    var response: AppleAgeResponse
    var error: Error?
    var requirement = AppleAgeRequirement.required
    var requirementError: Error?
    var requirementCalls = 0
    var calls = 0
    var holdNextRequest = false
    private var continuation: CheckedContinuation<Void, Never>?

    init(_ response: AppleAgeResponse) { self.response = response }

    func regulatoryRequirement() async throws -> AppleAgeRequirement {
        requirementCalls += 1
        if let requirementError { throw requirementError }
        return requirement
    }

    func requestAgeRange() async throws -> AppleAgeResponse {
        calls += 1
        let result = response
        if holdNextRequest {
            holdNextRequest = false
            await withCheckedContinuation { continuation = $0 }
        }
        if let error { throw error }
        return result
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

private enum TestFailure: Error { case unavailable }
