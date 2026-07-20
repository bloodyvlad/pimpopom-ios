import PimPoPomCore
import UIKit
import XCTest

@testable import PimPoPom

@MainActor
final class AdsControllerTests: XCTestCase {
    func testBuildInfoSelectsReviewedDemoEnvironment() {
        let configuration = AdsConfiguration.fromInfoDictionary([
            "PimPoPomAdsMode": "demo",
            "GADApplicationIdentifier": AdsConfiguration.realAppID,
            "PimPoPomAdMobBannerUnitID": AdsConfiguration.fixedBannerDemoUnitID,
            "PimPoPomAdMobInterstitialUnitID": AdsConfiguration.interstitialDemoUnitID,
            "PimPoPomAdMobTestDeviceIDs": "",
        ])

        XCTAssertEqual(configuration.mode, .demo)
        XCTAssertEqual(configuration.bannerUnitID, AdsConfiguration.fixedBannerDemoUnitID)
        XCTAssertEqual(
            configuration.interstitialUnitID,
            AdsConfiguration.interstitialDemoUnitID
        )
        XCTAssertTrue(configuration.validationProblems(configurationName: "Debug").isEmpty)
    }

    func testOwnerSplitUsesProductionUnitsOnlyForMatchingIDFV() {
        let ownerIDFV = UUID(uuidString: "00000000-1111-2222-3333-444444444444")!
        let guestIDFV = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let ownerBanner = "ca-app-pub-6428992187280935/111"
        let ownerInterstitial = "ca-app-pub-6428992187280935/222"
        let testDeviceHash = "0123456789abcdef0123456789abcdef"
        let values: [String: Any] = [
            "PimPoPomAdsMode": "owner-split-test",
            "GADApplicationIdentifier": AdsConfiguration.realAppID,
            "PimPoPomAdMobBannerUnitID": AdsConfiguration.fixedBannerDemoUnitID,
            "PimPoPomAdMobInterstitialUnitID": AdsConfiguration.interstitialDemoUnitID,
            "PimPoPomAdMobOwnerBannerUnitID": ownerBanner,
            "PimPoPomAdMobOwnerInterstitialUnitID": ownerInterstitial,
            "PimPoPomAdMobTestDeviceIDs": testDeviceHash,
            "PimPoPomOwnerDeviceIDFVHash": AdsConfiguration.identifierForVendorFingerprint(
                ownerIDFV
            ),
        ]

        let owner = AdsConfiguration.fromInfoDictionary(
            values,
            identifierForVendor: ownerIDFV
        )
        XCTAssertTrue(owner.isOwnerDevice)
        XCTAssertEqual(owner.bannerUnitID, ownerBanner)
        XCTAssertEqual(owner.interstitialUnitID, ownerInterstitial)
        XCTAssertEqual(owner.testDeviceIdentifiers, [testDeviceHash])
        XCTAssertTrue(owner.validationProblems(configurationName: "Staging").isEmpty)

        let guest = AdsConfiguration.fromInfoDictionary(
            values,
            identifierForVendor: guestIDFV
        )
        XCTAssertFalse(guest.isOwnerDevice)
        XCTAssertEqual(guest.bannerUnitID, AdsConfiguration.fixedBannerDemoUnitID)
        XCTAssertEqual(guest.interstitialUnitID, AdsConfiguration.interstitialDemoUnitID)
        XCTAssertTrue(guest.testDeviceIdentifiers.isEmpty)
        XCTAssertTrue(guest.validationProblems(configurationName: "Staging").isEmpty)
    }

    func testConfigurationGuardsRejectUnsafeReleaseAndOwnerModes() {
        let releaseDemo = Self.demoConfiguration
        XCTAssertFalse(
            releaseDemo.validationProblems(configurationName: "Release").isEmpty
        )

        let ownerWithoutHash = AdsConfiguration(
            mode: .ownerRealTest,
            appID: AdsConfiguration.realAppID,
            bannerUnitID: "ca-app-pub-6428992187280935/111",
            interstitialUnitID: "ca-app-pub-6428992187280935/222",
            testDeviceIdentifiers: []
        )
        XCTAssertFalse(
            ownerWithoutHash.validationProblems(configurationName: "OwnerAdsQA").isEmpty
        )

        let liveWithHash = AdsConfiguration(
            mode: .live,
            appID: AdsConfiguration.realAppID,
            bannerUnitID: "ca-app-pub-6428992187280935/111",
            interstitialUnitID: "ca-app-pub-6428992187280935/222",
            testDeviceIdentifiers: ["private-hash"]
        )
        XCTAssertFalse(liveWithHash.validationProblems(configurationName: "Release").isEmpty)
    }

    func testAccountResolutionFailsClosedUntilAuthoritativeSessionArrives() {
        XCTAssertEqual(AdAccountResolution.resolve(nil), .unresolved)
        XCTAssertEqual(AdAccountResolution.resolve(Self.anonymousSession), .adsAllowed)
        XCTAssertEqual(
            AdAccountResolution.resolve(Self.authenticatedSession(adFree: nil)),
            .unresolved
        )
        XCTAssertEqual(
            AdAccountResolution.resolve(Self.authenticatedSession(adFree: false)),
            .adsAllowed
        )
        XCTAssertEqual(
            AdAccountResolution.resolve(Self.authenticatedSession(adFree: true)),
            .adFree
        )
    }

    func testUnknownAndAdFreeStartupMakeZeroConsentOrAdRequests() async {
        for session in [nil, Self.authenticatedSession(adFree: true)] {
            let fixture = Self.makeFixture()
            await fixture.controller.bootstrap(session: session)

            XCTAssertEqual(fixture.consent.requestCount, 0)
            XCTAssertEqual(fixture.ads.configureCount, 0)
            XCTAssertEqual(fixture.ads.startCount, 0)
            XCTAssertEqual(fixture.ads.bannerAttachCount, 0)
            XCTAssertEqual(fixture.ads.interstitialPreloadCount, 0)
        }
    }

    func testConsentBlockedAndFailedWithoutStoredConsentNeverStartAds() async {
        let blocked = Self.makeFixture(
            consentSnapshot: ConsentSnapshot(
                canRequestAds: false,
                privacyOptionsRequirement: .required
            )
        )
        await blocked.controller.bootstrap(session: Self.anonymousSession)
        XCTAssertEqual(blocked.controller.lifecycleState, .consentBlocked)
        XCTAssertTrue(blocked.controller.isPrivacyChoicesVisible)
        XCTAssertEqual(blocked.ads.startCount, 0)

        let failed = Self.makeFixture(
            consentSnapshot: ConsentSnapshot(
                canRequestAds: false,
                privacyOptionsRequirement: .unknown
            )
        )
        failed.consent.requestError = FakeAdsError.requestedFailure
        await failed.controller.bootstrap(session: Self.anonymousSession)
        XCTAssertEqual(failed.controller.lifecycleState, .failed)
        XCTAssertEqual(failed.ads.startCount, 0)
    }

    func testStoredConsentMayStartAdsAfterRefreshFailure() async {
        let fixture = Self.makeFixture(
            consentSnapshot: ConsentSnapshot(
                canRequestAds: true,
                privacyOptionsRequirement: .required
            )
        )
        fixture.consent.requestError = FakeAdsError.requestedFailure

        await fixture.controller.bootstrap(session: Self.anonymousSession)

        XCTAssertEqual(fixture.consent.requestCount, 1)
        XCTAssertEqual(fixture.ads.startCount, 1)
        XCTAssertEqual(fixture.ads.interstitialPreloadCount, 1)
        XCTAssertEqual(fixture.controller.lifecycleState, .ready)
        XCTAssertTrue(fixture.controller.isPrivacyChoicesVisible)
    }

    func testPrivacyChoicesPresentationRefreshesState() async {
        let fixture = Self.makeFixture(
            consentSnapshot: ConsentSnapshot(
                canRequestAds: true,
                privacyOptionsRequirement: .required
            )
        )
        await fixture.controller.bootstrap(session: Self.anonymousSession)
        fixture.consent.snapshot = ConsentSnapshot(
            canRequestAds: false,
            privacyOptionsRequirement: .notRequired
        )

        await fixture.controller.presentPrivacyChoices()

        XCTAssertEqual(fixture.consent.privacyOptionsPresentationCount, 1)
        XCTAssertFalse(fixture.controller.isPrivacyChoicesVisible)
        XCTAssertEqual(fixture.controller.lifecycleState, .consentBlocked)
        XCTAssertGreaterThanOrEqual(fixture.ads.destroyCount, 1)
    }

    func testAdFreeTransitionDestroysAdsAndClearsCadence() async {
        let fixture = Self.makeFixture(
            progress: InterstitialProgress(
                completedSessions: 8,
                isDue: false,
                recentCompletionIDs: []
            )
        )
        await fixture.controller.bootstrap(session: Self.authenticatedSession(adFree: false))
        let destroyCountBefore = fixture.ads.destroyCount

        await fixture.controller.updateSession(Self.authenticatedSession(adFree: true))

        XCTAssertEqual(fixture.controller.accountResolution, .adFree)
        XCTAssertEqual(fixture.controller.progress.completedSessions, 0)
        XCTAssertFalse(fixture.controller.progress.isDue)
        XCTAssertGreaterThan(fixture.ads.destroyCount, destroyCountBefore)
        XCTAssertFalse(fixture.controller.canAttachBanner)
        XCTAssertFalse(fixture.controller.reservesBannerSlot)
    }

    func testAccountSwitchFromAdFreeRestartsConsentBeforeAds() async {
        let fixture = Self.makeFixture()
        await fixture.controller.bootstrap(session: Self.authenticatedSession(adFree: true))
        XCTAssertEqual(fixture.consent.requestCount, 0)

        await fixture.controller.updateSession(Self.authenticatedSession(adFree: false))

        XCTAssertEqual(fixture.consent.requestCount, 1)
        XCTAssertEqual(fixture.ads.startCount, 1)
        XCTAssertEqual(fixture.controller.lifecycleState, .ready)
    }

    func testCompletionCadenceSaturatesAtTenAcrossArcadeAndZen() async {
        let fixture = Self.makeFixture()
        await fixture.controller.bootstrap(session: Self.anonymousSession)

        for index in 0..<9 {
            fixture.controller.recordCompletedSession(
                id: Self.uuid(index),
                mode: index.isMultiple(of: 2) ? .arcade : .zen
            )
        }
        XCTAssertEqual(fixture.controller.progress.completedSessions, 9)
        XCTAssertFalse(fixture.controller.progress.isDue)

        fixture.controller.recordCompletedSession(id: Self.uuid(9), mode: .zen)
        XCTAssertEqual(fixture.controller.progress.completedSessions, 10)
        XCTAssertTrue(fixture.controller.progress.isDue)

        fixture.controller.recordCompletedSession(id: Self.uuid(10), mode: .arcade)
        XCTAssertEqual(fixture.controller.progress.completedSessions, 10)
        XCTAssertTrue(fixture.controller.progress.isDue)
    }

    func testDuplicateCompletionCountsOnce() async {
        let fixture = Self.makeFixture()
        await fixture.controller.bootstrap(session: Self.anonymousSession)
        let id = UUID()

        fixture.controller.recordCompletedSession(id: id, mode: .arcade)
        fixture.controller.recordCompletedSession(id: id, mode: .arcade)

        XCTAssertEqual(fixture.controller.progress.completedSessions, 1)
    }

    func testAdFreePlayersNeverIncrementOrPresent() async {
        let fixture = Self.makeFixture(
            progress: InterstitialProgress(
                completedSessions: 9,
                isDue: false,
                recentCompletionIDs: []
            )
        )
        await fixture.controller.bootstrap(session: Self.authenticatedSession(adFree: true))
        let id = UUID()

        fixture.controller.recordCompletedSession(id: id, mode: .arcade)
        XCTAssertFalse(fixture.controller.presentInterstitialIfDue(for: id))

        XCTAssertEqual(fixture.controller.progress.completedSessions, 0)
        XCTAssertEqual(fixture.ads.interstitialPresentationCount, 0)
    }

    func testUnavailableInterstitialRetainsDueStateForLaterCompletion() async {
        let fixture = Self.makeFixture(
            progress: InterstitialProgress(
                completedSessions: 9,
                isDue: false,
                recentCompletionIDs: []
            )
        )
        fixture.ads.interstitialAvailable = false
        await fixture.controller.bootstrap(session: Self.anonymousSession)
        let id = UUID()
        fixture.controller.recordCompletedSession(id: id, mode: .arcade)

        let preloadCountBeforeAttempt = fixture.ads.interstitialPreloadCount
        XCTAssertFalse(fixture.controller.presentInterstitialIfDue(for: id))
        XCTAssertEqual(fixture.controller.progress.completedSessions, 10)
        XCTAssertTrue(fixture.controller.progress.isDue)
        XCTAssertEqual(
            fixture.ads.interstitialPreloadCount,
            preloadCountBeforeAttempt + 1
        )

        fixture.ads.interstitialAvailable = true
        let nextID = UUID()
        fixture.controller.recordCompletedSession(id: nextID, mode: .zen)
        XCTAssertTrue(fixture.controller.presentInterstitialIfDue(for: nextID))
        XCTAssertEqual(fixture.controller.progress.completedSessions, 0)
        XCTAssertFalse(fixture.controller.progress.isDue)
    }

    func testSuccessfulPresentationResetsOnlyWhenPresentationBegins() async {
        let fixture = Self.makeFixture(
            progress: InterstitialProgress(
                completedSessions: 9,
                isDue: false,
                recentCompletionIDs: []
            )
        )
        await fixture.controller.bootstrap(session: Self.anonymousSession)
        let id = UUID()
        fixture.controller.recordCompletedSession(id: id, mode: .arcade)

        XCTAssertTrue(fixture.controller.presentInterstitialIfDue(for: id))
        XCTAssertEqual(fixture.controller.progress.completedSessions, 0)
        XCTAssertFalse(fixture.controller.progress.isDue)
        XCTAssertEqual(fixture.ads.interstitialPresentationCount, 1)
        XCTAssertFalse(fixture.controller.presentInterstitialIfDue(for: id))
    }

    func testPresentationFailureKeepsInterstitialDue() async {
        let fixture = Self.makeFixture(
            progress: InterstitialProgress(
                completedSessions: 9,
                isDue: false,
                recentCompletionIDs: []
            )
        )
        fixture.ads.beginsPresentation = false
        await fixture.controller.bootstrap(session: Self.anonymousSession)
        let id = UUID()
        fixture.controller.recordCompletedSession(id: id, mode: .arcade)

        XCTAssertTrue(fixture.controller.presentInterstitialIfDue(for: id))
        XCTAssertEqual(fixture.controller.progress.completedSessions, 10)
        XCTAssertTrue(fixture.controller.progress.isDue)
    }

    func testBannerStateTracksLoadAndNoFillWithoutChangingReservedHeight() async {
        let loaded = Self.makeFixture()
        await loaded.controller.bootstrap(session: Self.anonymousSession)
        let loadedHost = UIView(frame: CGRect(x: 0, y: 0, width: 351, height: 50))
        loaded.controller.attachBanner(to: loadedHost, availableWidth: 351)
        await Task.yield()
        XCTAssertEqual(loaded.controller.bannerState, .loaded)
        XCTAssertEqual(loadedHost.bounds.height, GameplayLayoutMetrics.adBannerHeight)

        let failed = Self.makeFixture()
        failed.ads.bannerOutcome = .failed
        await failed.controller.bootstrap(session: Self.anonymousSession)
        let failedHost = UIView(frame: CGRect(x: 0, y: 0, width: 351, height: 50))
        failed.controller.attachBanner(to: failedHost, availableWidth: 351)
        await Task.yield()
        XCTAssertEqual(failed.controller.bannerState, .failed)
        XCTAssertEqual(failedHost.bounds.height, GameplayLayoutMetrics.adBannerHeight)
    }

    func testProgressPersistsAcrossControllerRecreation() async {
        let store = MemoryInterstitialProgressStore()
        let first = Self.makeFixture(progressStore: store)
        await first.controller.bootstrap(session: Self.anonymousSession)
        first.controller.recordCompletedSession(id: UUID(), mode: .arcade)

        let second = Self.makeFixture(progressStore: store)
        XCTAssertEqual(second.controller.progress.completedSessions, 1)
    }

    private static let demoConfiguration = AdsConfiguration(
        mode: .demo,
        appID: AdsConfiguration.realAppID,
        bannerUnitID: AdsConfiguration.fixedBannerDemoUnitID,
        interstitialUnitID: AdsConfiguration.interstitialDemoUnitID,
        testDeviceIdentifiers: []
    )

    private static let anonymousSession = SessionResponse(
        authenticated: false,
        csrfToken: "csrf",
        googleClientId: "google",
        season: Season(id: "season", name: "Season"),
        profile: nil,
        adFree: nil,
        ranks: nil
    )

    private static func authenticatedSession(adFree: Bool?) -> SessionResponse {
        SessionResponse(
            authenticated: true,
            csrfToken: "csrf",
            googleClientId: "google",
            season: Season(id: "season", name: "Season"),
            profile: PlayerProfile(
                id: "player",
                nickname: "Player",
                nicknameConfirmed: true,
                coins: 0,
                totalPlayMs: 0,
                ownedPetIds: [],
                selectedPetId: nil,
                petVisible: false,
                equippedPetId: nil,
                specialPetId: nil,
                ownedThemeIds: [],
                selectedThemeId: nil,
                isAdmin: false,
                createdAt: "2026-01-01T00:00:00Z",
                updatedAt: "2026-01-01T00:00:00Z"
            ),
            adFree: adFree,
            ranks: nil
        )
    }

    private static func makeFixture(
        consentSnapshot: ConsentSnapshot = ConsentSnapshot(
            canRequestAds: true,
            privacyOptionsRequirement: .notRequired
        ),
        progress: InterstitialProgress = .empty,
        progressStore: MemoryInterstitialProgressStore? = nil
    ) -> (
        controller: AdsController,
        consent: FakeConsentService,
        ads: FakeAdsService,
        store: MemoryInterstitialProgressStore
    ) {
        let consent = FakeConsentService(snapshot: consentSnapshot)
        let ads = FakeAdsService()
        let store = progressStore ?? MemoryInterstitialProgressStore(progress: progress)
        let controller = AdsController(
            configuration: demoConfiguration,
            consentService: consent,
            adsService: ads,
            progressStore: store
        )
        return (controller, consent, ads, store)
    }

    private static func uuid(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!
    }
}
