import Foundation
import OSLog
import PimPoPomCore
import UIKit

enum AdsLifecycleState: Equatable, Sendable {
    case disabled
    case waitingForAge
    case waitingForAccount
    case requestingConsent
    case consentBlocked
    case ready
    case failed
}

@MainActor
final class AdsController: ObservableObject {
    struct ConfirmedAccountStartupID: Hashable {
        let profileID: String
        let ageGeneration: Int
    }

    private enum ConsentRefreshState {
        case notStarted
        case requesting
        case complete
        case failed
    }

    @Published private(set) var lifecycleState: AdsLifecycleState
    @Published private(set) var bannerState = BannerAdState.unavailable
    @Published private(set) var privacyOptionsRequirement = PrivacyOptionsRequirement.unknown
    @Published private(set) var isPresentingPrivacyOptions = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var progress: InterstitialProgress
    @Published private(set) var accountResolution = AdAccountResolution.unresolved

    @Published private(set) var ageBand: AdAgeBand?
    @Published private(set) var ageConfirmationGeneration = 0
    @Published private var hasCompletedPolicyConsentFlow = false

    var allowsApp: Bool { ageBand?.allowsApp == true }

    let configuration: AdsConfiguration

    var isPrivacyChoicesVisible: Bool {
        configuration.isEnabled && allowsApp
            && privacyOptionsRequirement == .required
    }

    var canAttachBanner: Bool {
        allowsApp && lifecycleState == .ready && accountResolution == .adsAllowed
    }

    var reservesBannerSlot: Bool {
        canAttachBanner
    }

    private let ageStore: any AdAgeBandStoring
    private var policyGeneration = 0
    private var accountGeneration = 0
    private var inventoryGeneration = 0
    private var hasCurrentPolicyConsent = false
    private var currentProfileID: String?
    private let consentService: any ConsentServing
    private let adsService: any AdsServing
    private let progressStore: any InterstitialProgressStoring
    private let configurationProblems: [String]
    private var hasBootstrapped = false
    @Published private var eligibilityFlowInFlight = false
    private var consentRefreshState = ConsentRefreshState.notStarted
    private var hasConfiguredAds = false
    private var adsStartInFlight = false
    private var attemptedResultIDs: Set<UUID> = []
    private var presentationInFlight = false
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.otcsoftware.pimpopom",
        category: "AdsEligibility"
    )

    init(
        configuration: AdsConfiguration,
        consentService: any ConsentServing,
        adsService: any AdsServing,
        progressStore: any InterstitialProgressStoring,
        ageStore: any AdAgeBandStoring = UserDefaultsAdAgeBandStore()
    ) {
        self.configuration = configuration
        self.ageStore = ageStore
        ageBand = ageStore.ageBand
        self.consentService = consentService
        self.adsService = adsService
        self.progressStore = progressStore
        configurationProblems = configuration.validationProblems()
        progress = progressStore.load()
        lifecycleState =
            ageStore.ageBand?.allowsApp == true
            ? (configuration.isEnabled ? .waitingForAccount : .disabled) : .waitingForAge

        adsService.onBannerStateChange = { [weak self] state in
            self?.bannerState = state
        }
        adsService.onInterstitialPresentationBegan = { [weak self] in
            self?.interstitialPresentationBegan()
        }
        adsService.onInterstitialPresentationEnded = { [weak self] in
            self?.interstitialPresentationEnded()
        }

        if !configurationProblems.isEmpty {
            lifecycleState = .disabled
            statusMessage = "Advertising is disabled because this build's ad configuration is invalid."
        }
    }

    convenience init(
        configuration: AdsConfiguration = .load(),
        progressStore: any InterstitialProgressStoring = UserDefaultsInterstitialProgressStore()
    ) {
        self.init(
            configuration: configuration,
            consentService: GoogleConsentService(),
            adsService: GoogleAdsService(),
            progressStore: progressStore
        )
    }

    func bootstrap(session: SessionResponse?) async {
        guard allowsApp else { return }
        guard !hasBootstrapped else {
            await updateSession(session)
            if case .notStarted = consentRefreshState { await runEligibilityFlow() }
            return
        }
        hasBootstrapped = true
        await applySession(session)

        guard allowsApp else { return }
        guard configuration.isEnabled, configurationProblems.isEmpty else {
            hasCompletedPolicyConsentFlow = true
            return
        }
        await runEligibilityFlow()
    }

    func isAgeConfirmed(for session: SessionResponse?) -> Bool {
        guard allowsApp, let key = Self.profileBinding(for: session) else { return false }
        return ageStore.confirmedProfileID == key
    }

    func confirmedAccountStartupID(for session: SessionResponse?) -> ConfirmedAccountStartupID? {
        guard hasBootstrapped, hasCompletedPolicyConsentFlow,
            !eligibilityFlowInFlight, !isPresentingPrivacyOptions, isAgeConfirmed(for: session),
            let profileID = Self.profileBinding(for: session), currentProfileID == profileID
        else { return nil }
        return ConfirmedAccountStartupID(profileID: profileID, ageGeneration: ageConfirmationGeneration)
    }

    private static func profileBinding(for session: SessionResponse?) -> String? {
        guard let session else { return nil }
        if session.authenticated, let profile = session.profile { return profile.id }
        if !session.authenticated, session.profile == nil { return "anonymous" }
        return nil
    }

    func setAgeBand(_ band: AdAgeBand) async {
        invalidatePolicy()
        ageStore.ageBand = band
        ageStore.confirmedProfileID = currentProfileID
        ageBand = band
        ageConfirmationGeneration += 1
        if hasBootstrapped, allowsApp { await runEligibilityFlow() }
    }

    private func requireAgeConfirmation() {
        invalidatePolicy()
        ageStore.ageBand = nil
        ageStore.confirmedProfileID = nil
        ageBand = nil
        ageConfirmationGeneration += 1
    }

    private func invalidatePolicy() {
        policyGeneration += 1
        consentService.invalidate()
        consentRefreshState = .notStarted
        hasCurrentPolicyConsent = false
        hasCompletedPolicyConsentFlow = false
        privacyOptionsRequirement = .unknown
        isPresentingPrivacyOptions = false
        eligibilityFlowInFlight = false
        adsStartInFlight = false
        hasConfiguredAds = false
        deactivateAds(state: .waitingForAge, clearCadence: false)
    }

    func updateSession(_ session: SessionResponse?) async {
        guard hasBootstrapped else { return }
        await applySession(session)
    }

    func setApplicationActive(_ isActive: Bool) {
        adsService.setApplicationActive(isActive)
    }

    /// A failed UMP refresh must not permanently disable ads for the process.
    /// Foreground recovery invokes this after the initial policy flow has finished.
    func retryEligibilityIfNeeded() async {
        guard hasBootstrapped, allowsApp,
            case .failed = consentRefreshState,
            accountResolution == .adsAllowed,
            configuration.isEnabled,
            configurationProblems.isEmpty,
            !eligibilityFlowInFlight
        else { return }
        logger.notice("Retrying ad eligibility after a transient failure")
        consoleDiagnostic("retrying eligibility")
        await runEligibilityFlow()
    }

    func attachBanner(to container: UIView, availableWidth: CGFloat) {
        guard canAttachBanner else {
            adsService.detachBanner(from: container)
            return
        }
        adsService.attachBanner(to: container, availableWidth: availableWidth)
    }

    func detachBanner(from container: UIView) {
        adsService.detachBanner(from: container)
    }

    func recordCompletedSession(id: UUID, mode _: GameMode) {
        guard allowsApp, configuration.isEnabled, accountResolution == .adsAllowed else { return }
        guard progress.record(completionID: id) else { return }
        persistProgress()
    }

    @discardableResult
    func presentInterstitialIfDue(for completionID: UUID) -> Bool {
        guard progress.recentCompletionIDs.contains(completionID.uuidString.lowercased()) else {
            return false
        }
        guard progress.isDue, !presentationInFlight else { return false }
        guard attemptedResultIDs.insert(completionID).inserted else { return false }
        guard lifecycleState == .ready, accountResolution == .adsAllowed else { return false }

        presentationInFlight = true
        let accepted = adsService.presentInterstitial()
        if !accepted {
            presentationInFlight = false
            // Never wait on this results transition. Keep the cadence due and
            // prepare another creative for the next qualifying result instead.
            adsService.preloadInterstitial()
        }
        return accepted
    }

    func presentPrivacyChoices() async {
        guard isPrivacyChoicesVisible, !isPresentingPrivacyOptions else { return }
        let generation = policyGeneration
        isPresentingPrivacyOptions = true
        statusMessage = nil
        // Existing creatives cannot outlive a privacy choice change.
        deactivateAds(state: .requestingConsent, clearCadence: false)
        consentRefreshState = .requesting
        defer {
            if generation == policyGeneration { isPresentingPrivacyOptions = false }
        }

        do {
            let snapshot = try await consentService.presentPrivacyOptions()
            guard generation == policyGeneration, allowsApp else { return }
            consentRefreshState = .complete
            hasCurrentPolicyConsent = true
            applyConsentSnapshot(snapshot)
            await reconcileEligibility()
        } catch {
            guard generation == policyGeneration, allowsApp else { return }
            let snapshot = consentService.currentSnapshot
            consentRefreshState = .failed
            applyConsentSnapshot(snapshot)
            statusMessage = "Privacy choices are unavailable right now. Please try again."
            await reconcileEligibility()
        }
    }

    private func applySession(_ session: SessionResponse?) async {
        let next = AdAccountResolution.resolve(session)
        if next != accountResolution {
            accountGeneration += 1
            adsStartInFlight = false
        }
        accountResolution = next
        if session == nil, currentProfileID != nil {
            currentProfileID = nil
            requireAgeConfirmation()
            return
        }
        if let session {
            let profileID = Self.profileBinding(for: session)
            currentProfileID = profileID
            if let confirmed = ageStore.confirmedProfileID, confirmed != profileID {
                requireAgeConfirmation()
                return
            }
            if allowsApp, let profileID { ageStore.confirmedProfileID = profileID }
        }
        guard allowsApp else {
            deactivateAds(state: .waitingForAge, clearCadence: next == .adFree)
            return
        }
        logger.notice("Ad account resolution: \(self.accountLabel(next), privacy: .public)")
        consoleDiagnostic("account=\(accountLabel(next))")

        guard configuration.isEnabled, configurationProblems.isEmpty else {
            hasCompletedPolicyConsentFlow = true
            deactivateAds(state: .disabled, clearCadence: next == .adFree)
            return
        }

        await reconcileEligibility()
    }

    private func runEligibilityFlow() async {
        guard allowsApp, let ageBand else { return }
        guard configuration.isEnabled, configurationProblems.isEmpty else {
            hasCompletedPolicyConsentFlow = true
            return
        }
        guard !eligibilityFlowInFlight else { return }
        let generation = policyGeneration
        eligibilityFlowInFlight = true
        defer {
            if generation == policyGeneration {
                eligibilityFlowInFlight = false
                hasCompletedPolicyConsentFlow = true
            }
        }
        consentRefreshState = .requesting
        lifecycleState = .requestingConsent
        statusMessage = nil

        do {
            let snapshot = try await consentService.requestConsent(for: ageBand)
            guard generation == policyGeneration, allowsApp else { return }
            consentRefreshState = .complete
            hasCurrentPolicyConsent = true
            applyConsentSnapshot(snapshot)
            logger.notice(
                "UMP eligibility complete; can request ads: \(snapshot.canRequestAds, privacy: .public)"
            )
            consoleDiagnostic("ump canRequestAds=\(snapshot.canRequestAds)")
            await reconcileEligibility()
        } catch {
            guard generation == policyGeneration, allowsApp else { return }
            let snapshot = consentService.currentSnapshot
            consentRefreshState = .failed
            applyConsentSnapshot(snapshot)
            let nsError = error as NSError
            logger.error(
                "UMP eligibility failed [\(nsError.domain, privacy: .public):\(nsError.code, privacy: .public)]; stored consent permits ads: \(snapshot.canRequestAds, privacy: .public)"
            )
            consoleDiagnostic(
                "ump failed domain=\(nsError.domain) code=\(nsError.code) storedCanRequestAds=\(snapshot.canRequestAds)"
            )
            statusMessage = "Ad privacy information could not be refreshed."
            await reconcileEligibility()
        }
    }

    private func applyConsentSnapshot(_ snapshot: ConsentSnapshot) {
        privacyOptionsRequirement = snapshot.privacyOptionsRequirement
    }

    private func configureAdsIfNeeded() {
        guard !hasConfiguredAds, let ageBand, ageBand.allowsApp else { return }
        adsService.configure(configuration, ageBand: ageBand)
        hasConfiguredAds = true
    }

    private func reconcileEligibility() async {
        guard allowsApp else {
            deactivateAds(state: .waitingForAge, clearCadence: false)
            return
        }
        guard configuration.isEnabled, configurationProblems.isEmpty else {
            deactivateAds(state: .disabled, clearCadence: accountResolution == .adFree)
            return
        }

        switch accountResolution {
        case .unresolved:
            deactivateAds(state: .waitingForAccount, clearCadence: false)
        case .adFree:
            deactivateAds(state: .disabled, clearCadence: true)
        case .adsAllowed:
            switch consentRefreshState {
            case .notStarted, .requesting:
                deactivateAds(state: .requestingConsent, clearCadence: false)
            case .complete:
                if consentService.currentSnapshot.canRequestAds {
                    await startAdsIfNeeded()
                } else {
                    deactivateAds(state: .consentBlocked, clearCadence: false)
                }
            case .failed:
                if hasCurrentPolicyConsent, consentService.currentSnapshot.canRequestAds {
                    await startAdsIfNeeded()
                } else {
                    deactivateAds(state: .failed, clearCadence: false)
                }
            }
        }
    }

    private func startAdsIfNeeded() async {
        guard allowsApp, accountResolution == .adsAllowed,
            configuration.isEnabled, hasCurrentPolicyConsent,
            consentService.currentSnapshot.canRequestAds,
            lifecycleState != .ready,
            !adsStartInFlight
        else { return }
        let generation = policyGeneration
        let account = accountGeneration
        let inventory = inventoryGeneration
        adsStartInFlight = true
        defer {
            if generation == policyGeneration, account == accountGeneration,
                inventory == inventoryGeneration
            {
                adsStartInFlight = false
            }
        }
        configureAdsIfNeeded()
        await adsService.start()
        guard generation == policyGeneration, account == accountGeneration,
            inventory == inventoryGeneration
        else { return }
        guard allowsApp, accountResolution == .adsAllowed,
            consentService.currentSnapshot.canRequestAds
        else {
            deactivateAds(
                state: accountResolution == .adFree ? .disabled : .waitingForAccount,
                clearCadence: accountResolution == .adFree
            )
            return
        }
        lifecycleState = .ready
        adsService.preloadInterstitial()
    }

    private func deactivateAds(
        state: AdsLifecycleState,
        clearCadence: Bool
    ) {
        inventoryGeneration += 1
        adsStartInFlight = false
        adsService.destroyAll()
        hasConfiguredAds = false
        bannerState = .unavailable
        lifecycleState = state
        presentationInFlight = false
        attemptedResultIDs.removeAll()
        if clearCadence {
            progress.clearCadence()
            persistProgress()
        }
    }

    private func interstitialPresentationBegan() {
        guard accountResolution == .adsAllowed, progress.isDue else { return }
        progress.markPresented()
        attemptedResultIDs.removeAll()
        persistProgress()
    }

    private func interstitialPresentationEnded() {
        presentationInFlight = false
        if lifecycleState == .ready, accountResolution == .adsAllowed {
            adsService.preloadInterstitial()
        }
    }

    private func persistProgress() {
        progressStore.save(progress)
    }

    private func accountLabel(_ resolution: AdAccountResolution) -> String {
        switch resolution {
        case .unresolved: "unresolved"
        case .adsAllowed: "ads-allowed"
        case .adFree: "ad-free"
        }
    }

    private func consoleDiagnostic(_ message: String) {
        guard ProcessInfo.processInfo.arguments.contains("--ad-diagnostics") else { return }
        print("[PimPoPom Ads] \(message)")
    }
}
