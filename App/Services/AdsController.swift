import Foundation
import OSLog
import PimPoPomCore
import UIKit

enum AdsLifecycleState: Equatable, Sendable {
    case disabled
    case waitingForAccount
    case requestingConsent
    case consentBlocked
    case ready
    case failed
}

@MainActor
final class AdsController: ObservableObject {
    @Published private(set) var lifecycleState: AdsLifecycleState
    @Published private(set) var bannerState = BannerAdState.unavailable
    @Published private(set) var privacyOptionsRequirement = PrivacyOptionsRequirement.unknown
    @Published private(set) var isPresentingPrivacyOptions = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var progress: InterstitialProgress
    @Published private(set) var accountResolution = AdAccountResolution.unresolved

    let configuration: AdsConfiguration

    var isPrivacyChoicesVisible: Bool {
        configuration.isEnabled
            && accountResolution == .adsAllowed
            && privacyOptionsRequirement == .required
    }

    var canAttachBanner: Bool {
        lifecycleState == .ready && accountResolution == .adsAllowed
    }

    var reservesBannerSlot: Bool {
        canAttachBanner
    }

    private let consentService: any ConsentServing
    private let adsService: any AdsServing
    private let progressStore: any InterstitialProgressStoring
    private let configurationProblems: [String]
    private var hasBootstrapped = false
    private var eligibilityGeneration = 0
    private var eligibilityFlowInFlight = false
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
        progressStore: any InterstitialProgressStoring
    ) {
        self.configuration = configuration
        self.consentService = consentService
        self.adsService = adsService
        self.progressStore = progressStore
        configurationProblems = configuration.validationProblems()
        progress = progressStore.load()
        lifecycleState = configuration.isEnabled ? .waitingForAccount : .disabled

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
        guard !hasBootstrapped else {
            await updateSession(session)
            return
        }
        hasBootstrapped = true
        await applySession(session, forceEligibilityFlow: true)
    }

    func updateSession(_ session: SessionResponse?) async {
        guard hasBootstrapped else { return }
        await applySession(session, forceEligibilityFlow: false)
    }

    func setApplicationActive(_ isActive: Bool) {
        adsService.setApplicationActive(isActive)
    }

    /// A failed UMP refresh must not permanently disable ads for the process.
    /// The caller invokes this once after initial bootstrap and on foreground.
    func retryEligibilityIfNeeded() async {
        guard hasBootstrapped,
            lifecycleState == .failed,
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
        guard configuration.isEnabled, accountResolution == .adsAllowed else { return }
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
        isPresentingPrivacyOptions = true
        statusMessage = nil
        defer { isPresentingPrivacyOptions = false }

        do {
            let snapshot = try await consentService.presentPrivacyOptions()
            applyConsentSnapshot(snapshot)
            if snapshot.canRequestAds {
                startAdsIfNeeded()
            } else {
                deactivateAds(state: .consentBlocked, clearCadence: false)
            }
        } catch {
            let snapshot = consentService.currentSnapshot
            applyConsentSnapshot(snapshot)
            statusMessage = "Privacy choices are unavailable right now. Please try again."
            if snapshot.canRequestAds {
                startAdsIfNeeded()
            } else {
                deactivateAds(state: .failed, clearCadence: false)
            }
        }
    }

    private func applySession(
        _ session: SessionResponse?,
        forceEligibilityFlow: Bool
    ) async {
        let previous = accountResolution
        let next = AdAccountResolution.resolve(session)
        accountResolution = next
        logger.notice("Ad account resolution: \(self.accountLabel(next), privacy: .public)")
        consoleDiagnostic("account=\(accountLabel(next))")

        guard configuration.isEnabled, configurationProblems.isEmpty else {
            deactivateAds(state: .disabled, clearCadence: next == .adFree)
            return
        }

        switch next {
        case .unresolved:
            deactivateAds(state: .waitingForAccount, clearCadence: false)
        case .adFree:
            deactivateAds(state: .disabled, clearCadence: true)
        case .adsAllowed:
            guard forceEligibilityFlow || previous != .adsAllowed else { return }
            await runEligibilityFlow()
        }
    }

    private func runEligibilityFlow() async {
        guard !eligibilityFlowInFlight else { return }
        eligibilityFlowInFlight = true
        defer { eligibilityFlowInFlight = false }
        eligibilityGeneration += 1
        let generation = eligibilityGeneration
        lifecycleState = .requestingConsent
        statusMessage = nil
        adsService.configure(configuration)

        do {
            let snapshot = try await consentService.requestConsent()
            guard generation == eligibilityGeneration,
                accountResolution == .adsAllowed
            else { return }
            applyConsentSnapshot(snapshot)
            logger.notice(
                "UMP eligibility complete; can request ads: \(snapshot.canRequestAds, privacy: .public)"
            )
            consoleDiagnostic("ump canRequestAds=\(snapshot.canRequestAds)")
            if snapshot.canRequestAds {
                startAdsIfNeeded()
            } else {
                deactivateAds(state: .consentBlocked, clearCadence: false)
            }
        } catch {
            guard generation == eligibilityGeneration,
                accountResolution == .adsAllowed
            else { return }
            let snapshot = consentService.currentSnapshot
            applyConsentSnapshot(snapshot)
            let nsError = error as NSError
            logger.error(
                "UMP eligibility failed [\(nsError.domain, privacy: .public):\(nsError.code, privacy: .public)]; stored consent permits ads: \(snapshot.canRequestAds, privacy: .public)"
            )
            consoleDiagnostic(
                "ump failed domain=\(nsError.domain) code=\(nsError.code) storedCanRequestAds=\(snapshot.canRequestAds)"
            )
            statusMessage = "Ad privacy information could not be refreshed."
            if snapshot.canRequestAds {
                startAdsIfNeeded()
            } else {
                deactivateAds(state: .failed, clearCadence: false)
            }
        }
    }

    private func applyConsentSnapshot(_ snapshot: ConsentSnapshot) {
        privacyOptionsRequirement = snapshot.privacyOptionsRequirement
    }

    private func startAdsIfNeeded() {
        guard accountResolution == .adsAllowed, configuration.isEnabled else { return }
        adsService.start()
        lifecycleState = .ready
        adsService.preloadInterstitial()
    }

    private func deactivateAds(
        state: AdsLifecycleState,
        clearCadence: Bool
    ) {
        eligibilityGeneration += 1
        adsService.destroyAll()
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
