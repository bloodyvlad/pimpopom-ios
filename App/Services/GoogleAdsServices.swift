import GoogleMobileAds
import OSLog
import UIKit
import UserMessagingPlatform

@MainActor
final class GoogleConsentService: ConsentServing {
    private var didApplyDebugReset = false

    private let operations = ConsentOperationQueue()
    private var validatedSnapshot = ConsentSnapshot(
        canRequestAds: false, privacyOptionsRequirement: .unknown
    )

    var currentSnapshot: ConsentSnapshot { validatedSnapshot }

    func waitUntilIdle() async { await operations.waitUntilIdle() }

    func invalidate() {
        operations.invalidate()
        validatedSnapshot = ConsentSnapshot(
            canRequestAds: false, privacyOptionsRequirement: .unknown
        )
    }

    static func requestParameters(for ageBand: AdAgeBand) -> RequestParameters {
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = ageBand.isUnderAdConsentAge
        return parameters
    }

    func requestConsent(for ageBand: AdAgeBand) async throws -> ConsentSnapshot {
        guard ageBand.allowsApp else { throw CancellationError() }
        return try await operations.run { [self] generation in
            let parameters = Self.requestParameters(for: ageBand)
            #if DEBUG
                let arguments = ProcessInfo.processInfo.arguments
                if arguments.contains("--ump-debug-reset"), !didApplyDebugReset {
                    ConsentInformation.shared.reset()
                    didApplyDebugReset = true
                }
                if arguments.contains("--ump-debug-eea") {
                    let debugSettings = DebugSettings()
                    debugSettings.geography = .EEA
                    parameters.debugSettings = debugSettings
                }
            #endif
            consoleDiagnostic("requesting consent information")
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                }
            }
            try operations.check(generation)
            consoleDiagnostic("consent information updated; \(statusDescription)")
            if ConsentInformation.shared.consentStatus == .required {
                let form = try await ConsentForm.load()
                try operations.check(generation)
                try await form.present(from: nil)
            }
            try operations.check(generation)
            validatedSnapshot = sdkSnapshot
            return validatedSnapshot
        }
    }

    func presentPrivacyOptions() async throws -> ConsentSnapshot {
        return try await operations.run { [self] generation in
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
            try operations.check(generation)
            validatedSnapshot = sdkSnapshot
            return validatedSnapshot
        }
    }

    private var sdkSnapshot: ConsentSnapshot {
        ConsentSnapshot(
            canRequestAds: ConsentInformation.shared.canRequestAds,
            privacyOptionsRequirement: privacyRequirement
        )
    }

    private var privacyRequirement: PrivacyOptionsRequirement {
        switch ConsentInformation.shared.privacyOptionsRequirementStatus {
        case .required:
            .required
        case .notRequired:
            .notRequired
        case .unknown:
            .unknown
        @unknown default:
            .unknown
        }
    }

    private var statusDescription: String {
        let information = ConsentInformation.shared
        return [
            "status=\(information.consentStatus.rawValue)",
            "form=\(information.formStatus.rawValue)",
            "canRequestAds=\(information.canRequestAds)",
            "privacy=\(information.privacyOptionsRequirementStatus.rawValue)",
        ].joined(separator: " ")
    }

    private func consoleDiagnostic(_ message: String) {
        guard ProcessInfo.processInfo.arguments.contains("--ad-diagnostics") else { return }
        print("[PimPoPom UMP] \(message)")
    }
}

@MainActor
final class GoogleAdsService: NSObject, AdsServing {
    var onBannerStateChange: ((BannerAdState) -> Void)?
    var onInterstitialPresentationBegan: (() -> Void)?
    var onInterstitialPresentationEnded: (() -> Void)?

    private let initializeSDK: @MainActor () async -> Void

    init(
        initializeSDK: @escaping @MainActor () async -> Void = {
            _ = await MobileAds.shared.start()
        }
    ) {
        self.initializeSDK = initializeSDK
        super.init()
    }

    private var configuration: AdsConfiguration?
    private var hasStarted = false
    private var sdkInitializationTask: Task<Void, Never>?
    private var inventoryGeneration = 0
    private var isApplicationActive = true
    private weak var bannerContainer: UIView?
    private var bannerView: BannerView?
    private var bannerRoute: AdUnitRoute?
    private var bannerWaitsForForegroundRetry = false
    private var interstitialAd: InterstitialAd?
    private var interstitialRoute: AdUnitRoute?
    private var interstitialLoadedAt: Date?
    private var interstitialLoadTask: Task<Void, Never>?
    private var isPresentingInterstitial = false
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.otcsoftware.pimpopom",
        category: "Ads"
    )

    func configure(_ configuration: AdsConfiguration, ageBand: AdAgeBand) {
        destroyAll()
        guard ageBand.allowsApp else { return }
        self.configuration = configuration
        bannerRoute = AdUnitRoute(
            primaryUnitID: configuration.bannerUnitID,
            fallbackUnitID: configuration.fallbackBannerUnitID
        )
        interstitialRoute = AdUnitRoute(
            primaryUnitID: configuration.interstitialUnitID,
            fallbackUnitID: configuration.fallbackInterstitialUnitID
        )
        bannerWaitsForForegroundRetry = false
        let requestConfiguration = MobileAds.shared.requestConfiguration
        requestConfiguration.maxAdContentRating = GADMaxAdContentRating.general
        requestConfiguration.ageRestrictedTreatment = Self.ageRestrictedTreatment(for: ageBand)
        requestConfiguration.publisherPrivacyPersonalizationState = .disabled
        requestConfiguration.setPublisherFirstPartyIDEnabled(false)
        requestConfiguration.testDeviceIdentifiers =
            configuration.testDeviceIdentifiers.isEmpty
            ? nil
            : configuration.testDeviceIdentifiers
        logger.notice(
            "Configured ads route: \(configuration.routeDescription, privacy: .public)"
        )
        consoleDiagnostic("route=\(configuration.routeDescription)")
    }

    static func ageRestrictedTreatment(for ageBand: AdAgeBand) -> AgeRestrictedTreatment {
        switch ageBand {
        case .under13, .youngTeen: .child
        case .olderTeen: .teen
        case .adult: .unspecified
        }
    }

    static func nonPersonalizedRequest() -> Request {
        let request = Request()
        let extras = Extras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        return request
    }

    func start() async {
        guard !hasStarted, configuration != nil else { return }
        let generation = inventoryGeneration
        if sdkInitializationTask == nil {
            sdkInitializationTask = Task { @MainActor [self] in
                await initializeSDK()
                consoleDiagnostic("sdk initialized")
            }
        }
        await sdkInitializationTask?.value
        guard generation == inventoryGeneration else { return }
        hasStarted = true
    }

    func attachBanner(to container: UIView, availableWidth: CGFloat) {
        guard hasStarted, isApplicationActive, configuration != nil else {
            detachBanner(from: container)
            return
        }
        guard availableWidth >= 320 else {
            onBannerStateChange?(.failed)
            detachBanner(from: container)
            return
        }

        bannerContainer = container
        guard !bannerWaitsForForegroundRetry else { return }
        if let bannerView {
            install(bannerView, in: container)
            return
        }

        // Current large anchored-adaptive banners may be 50–150 points tall.
        // The accepted PimPoPom gameplay host is strictly 50 points, so use the
        // official 320×50 format instead of clipping an adaptive creative.
        loadBanner(in: container)
    }

    private func loadBanner(in container: UIView) {
        guard hasStarted,
            isApplicationActive,
            let route = bannerRoute
        else { return }
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = route.currentUnitID
        banner.rootViewController = Self.topViewController()
        banner.delegate = self
        banner.accessibilityIdentifier = "google-banner-view"
        bannerView = banner
        install(banner, in: container)
        onBannerStateChange?(.loading)
        logger.notice(
            "Requesting fixed banner via \(route.isUsingFallback ? "demo fallback" : "primary", privacy: .public) route"
        )
        consoleDiagnostic(
            "banner request route=\(route.isUsingFallback ? "demo-fallback" : "primary")"
        )
        banner.load(Self.nonPersonalizedRequest())
    }

    func detachBanner(from container: UIView) {
        if bannerView?.superview === container {
            bannerView?.removeFromSuperview()
        }
        if bannerContainer === container {
            bannerContainer = nil
        }
    }

    func preloadInterstitial() {
        guard hasStarted,
            isApplicationActive,
            interstitialAd == nil,
            interstitialLoadTask == nil,
            interstitialRoute != nil
        else { return }

        let generation = inventoryGeneration
        interstitialLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if generation == inventoryGeneration { interstitialLoadTask = nil }
            }
            await loadInterstitialWithFallback(generation: generation)
        }
    }

    private func loadInterstitialWithFallback(generation: Int) async {
        while generation == inventoryGeneration, !Task.isCancelled,
            hasStarted, isApplicationActive, let route = interstitialRoute
        {
            do {
                let ad = try await InterstitialAd.load(
                    with: route.currentUnitID,
                    request: Self.nonPersonalizedRequest()
                )
                guard generation == inventoryGeneration, !Task.isCancelled, hasStarted else { return }
                ad.fullScreenContentDelegate = self
                interstitialAd = ad
                interstitialLoadedAt = Date()
                logger.notice(
                    "Interstitial loaded via \(route.isUsingFallback ? "demo fallback" : "primary", privacy: .public) route"
                )
                consoleDiagnostic(
                    "interstitial loaded route=\(route.isUsingFallback ? "demo-fallback" : "primary")"
                )
                return
            } catch {
                guard generation == inventoryGeneration, !Task.isCancelled, hasStarted else { return }
                let nsError = error as NSError
                logger.error(
                    "Interstitial preload failed [\(nsError.domain, privacy: .public):\(nsError.code, privacy: .public)]: \(nsError.localizedDescription, privacy: .public)"
                )
                consoleDiagnostic(
                    "interstitial failed domain=\(nsError.domain) code=\(nsError.code) message=\(nsError.localizedDescription)"
                )
                consoleResponseDiagnostic(for: nsError)
                interstitialAd = nil
                interstitialLoadedAt = nil
                guard Self.isNoFill(error),
                    interstitialRoute?.useFallbackIfAvailable() == true
                else { return }
                logger.notice("Retrying interstitial with the configured demo fallback")
                consoleDiagnostic("interstitial retry route=demo-fallback")
            }
        }
    }

    func presentInterstitial() -> Bool {
        guard hasStarted, isApplicationActive, !isPresentingInterstitial else { return false }
        guard let interstitialAd, let interstitialLoadedAt else { return false }
        guard Date().timeIntervalSince(interstitialLoadedAt) < 3_600 else {
            self.interstitialAd = nil
            self.interstitialLoadedAt = nil
            preloadInterstitial()
            return false
        }
        isPresentingInterstitial = true
        interstitialAd.present(from: Self.topViewController())
        return true
    }

    func setApplicationActive(_ isActive: Bool) {
        isApplicationActive = isActive
        if isActive, let bannerContainer {
            if bannerWaitsForForegroundRetry {
                bannerWaitsForForegroundRetry = false
                discardBanner()
                loadBanner(in: bannerContainer)
            } else if let bannerView {
                install(bannerView, in: bannerContainer)
            }
        }
    }

    func destroyAll() {
        inventoryGeneration += 1
        hasStarted = false
        configuration = nil
        bannerRoute = nil
        interstitialRoute = nil
        interstitialLoadTask?.cancel()
        interstitialLoadTask = nil
        interstitialAd?.fullScreenContentDelegate = nil
        interstitialAd = nil
        interstitialLoadedAt = nil
        isPresentingInterstitial = false
        discardBanner()
        bannerContainer = nil
        bannerWaitsForForegroundRetry = false
        onBannerStateChange?(.unavailable)
    }

    private func discardBanner() {
        bannerView?.delegate = nil
        bannerView?.removeFromSuperview()
        bannerView = nil
    }

    private func install(_ banner: BannerView, in container: UIView) {
        if banner.superview !== container {
            banner.removeFromSuperview()
            container.addSubview(banner)
        }
        banner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.deactivate(
            container.constraints.filter { constraint in
                constraint.firstItem === banner || constraint.secondItem === banner
            })
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            banner.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            banner.widthAnchor.constraint(equalToConstant: 320),
            banner.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    private static func topViewController() -> UIViewController? {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let root = windowScene?.windows.first { $0.isKeyWindow }?.rootViewController
        return descend(from: root)
    }

    private static func descend(from controller: UIViewController?) -> UIViewController? {
        if let presented = controller?.presentedViewController {
            return descend(from: presented)
        }
        if let navigation = controller as? UINavigationController {
            return descend(from: navigation.visibleViewController)
        }
        if let tab = controller as? UITabBarController {
            return descend(from: tab.selectedViewController)
        }
        return controller
    }

    static func isNoFill(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == GADErrorDomain
            && nsError.code == GoogleMobileAds.RequestError.noFill.rawValue
    }

    private func consoleDiagnostic(_ message: String) {
        guard ProcessInfo.processInfo.arguments.contains("--ad-diagnostics") else { return }
        print("[PimPoPom Ads] \(message)")
    }

    private func consoleResponseDiagnostic(for error: NSError) {
        guard ProcessInfo.processInfo.arguments.contains("--ad-diagnostics"),
            let responseInfo = error.userInfo[GADErrorUserInfoKeyResponseInfo]
                as? ResponseInfo
        else { return }
        let dictionary = responseInfo.dictionaryRepresentation
        if JSONSerialization.isValidJSONObject(dictionary),
            let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys]),
            let json = String(data: data, encoding: .utf8)
        {
            print("[PimPoPom Ads] response=\(json)")
        } else {
            print("[PimPoPom Ads] response=\(dictionary)")
        }
    }

}

extension GoogleAdsService: BannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        guard bannerView === self.bannerView else { return }
        logger.notice("Banner loaded")
        consoleDiagnostic("banner loaded")
        onBannerStateChange?(.loaded)
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        guard bannerView === self.bannerView else { return }
        let nsError = error as NSError
        logger.error(
            "Banner load failed [\(nsError.domain, privacy: .public):\(nsError.code, privacy: .public)]: \(nsError.localizedDescription, privacy: .public)"
        )
        consoleDiagnostic(
            "banner failed domain=\(nsError.domain) code=\(nsError.code) message=\(nsError.localizedDescription)"
        )
        consoleResponseDiagnostic(for: nsError)
        if Self.isNoFill(error),
            bannerRoute?.useFallbackIfAvailable() == true,
            let container = bannerContainer,
            isApplicationActive
        {
            logger.notice("Retrying banner with the configured demo fallback")
            consoleDiagnostic("banner retry route=demo-fallback")
            discardBanner()
            loadBanner(in: container)
        } else {
            bannerWaitsForForegroundRetry = true
            onBannerStateChange?(.failed)
            // Do not let GMA's retained banner refresh itself repeatedly after
            // a terminal load failure. A genuine foreground transition is the
            // only retry trigger for this app process.
            discardBanner()
        }
    }
}

extension GoogleAdsService: FullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        guard ad === interstitialAd, hasStarted else { return }
        onInterstitialPresentationBegan?()
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError _: Error
    ) {
        guard ad === interstitialAd, hasStarted else { return }
        interstitialAd = nil
        interstitialLoadedAt = nil
        isPresentingInterstitial = false
        onInterstitialPresentationEnded?()
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        guard ad === interstitialAd, hasStarted else { return }
        interstitialAd = nil
        interstitialLoadedAt = nil
        isPresentingInterstitial = false
        onInterstitialPresentationEnded?()
    }
}

enum FakeAdsError: Error {
    case requestedFailure
}

@MainActor
final class FakeConsentService: ConsentServing {
    var snapshot: ConsentSnapshot
    var requestError: Error?
    var privacyOptionsError: Error?
    var requestDelay: Duration?
    var privacyOptionsDelay: Duration?
    private(set) var requestedAgeBands: [AdAgeBand] = []
    private(set) var invalidateCount = 0
    private(set) var requestCount = 0
    private(set) var privacyOptionsPresentationCount = 0

    init(
        snapshot: ConsentSnapshot = ConsentSnapshot(
            canRequestAds: true,
            privacyOptionsRequirement: .notRequired
        )
    ) {
        self.snapshot = snapshot
    }

    var currentSnapshot: ConsentSnapshot { snapshot }

    func invalidate() { invalidateCount += 1 }

    func requestConsent(for ageBand: AdAgeBand) async throws -> ConsentSnapshot {
        requestCount += 1
        requestedAgeBands.append(ageBand)
        let result = snapshot
        if let requestDelay { try await Task.sleep(for: requestDelay) }
        if let requestError { throw requestError }
        return result
    }

    func presentPrivacyOptions() async throws -> ConsentSnapshot {
        privacyOptionsPresentationCount += 1
        let result = snapshot
        if let privacyOptionsDelay { try await Task.sleep(for: privacyOptionsDelay) }
        if let privacyOptionsError { throw privacyOptionsError }
        return result
    }
}

@MainActor
final class FakeAdsService: AdsServing {
    var onBannerStateChange: ((BannerAdState) -> Void)?
    var onInterstitialPresentationBegan: (() -> Void)?
    var onInterstitialPresentationEnded: (() -> Void)?
    var bannerOutcome = BannerAdState.loaded
    var interstitialAvailable = true
    var beginsPresentation = true
    var startDelay: Duration?
    private(set) var configuredAgeBands: [AdAgeBand] = []
    private var inventoryGeneration = 0
    private(set) var configureCount = 0
    private(set) var startCount = 0
    private(set) var bannerAttachCount = 0
    private(set) var interstitialPreloadCount = 0
    private(set) var interstitialPresentationCount = 0
    private(set) var destroyCount = 0
    private(set) var applicationActiveChanges: [Bool] = []
    private var configured = false
    private var started = false
    private var hasResolvedBanner = false
    private let label = UILabel()

    init() {
        label.text = "Test ad"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabel
        label.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.92)
        label.accessibilityIdentifier = "fake-ad-banner"
    }

    func configure(_: AdsConfiguration, ageBand: AdAgeBand) {
        configuredAgeBands.append(ageBand)
        configureCount += 1
        configured = true
    }

    func start() async {
        guard configured else { return }
        startCount += 1
        let generation = inventoryGeneration
        if let startDelay {
            try? await Task.sleep(for: startDelay)
        }
        guard generation == inventoryGeneration else { return }
        started = true
    }

    func attachBanner(to container: UIView, availableWidth _: CGFloat) {
        guard started else { return }
        if bannerOutcome == .loaded {
            label.removeFromSuperview()
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                label.widthAnchor.constraint(equalToConstant: 320),
                label.heightAnchor.constraint(equalToConstant: 50),
            ])
        }
        guard !hasResolvedBanner else { return }
        hasResolvedBanner = true
        bannerAttachCount += 1
        let outcome = bannerOutcome
        Task { @MainActor [weak self] in
            guard let self, started, hasResolvedBanner else { return }
            onBannerStateChange?(.loading)
            onBannerStateChange?(outcome)
        }
    }

    func detachBanner(from container: UIView) {
        if label.superview === container { label.removeFromSuperview() }
    }

    func preloadInterstitial() {
        guard started else { return }
        interstitialPreloadCount += 1
    }

    func presentInterstitial() -> Bool {
        guard started, interstitialAvailable else { return false }
        interstitialPresentationCount += 1
        if beginsPresentation {
            onInterstitialPresentationBegan?()
            onInterstitialPresentationEnded?()
        } else {
            onInterstitialPresentationEnded?()
        }
        return true
    }

    func setApplicationActive(_ isActive: Bool) {
        applicationActiveChanges.append(isActive)
    }

    func destroyAll() {
        inventoryGeneration += 1
        destroyCount += 1
        configured = false
        started = false
        hasResolvedBanner = false
        label.removeFromSuperview()
        onBannerStateChange?(.unavailable)
    }
}
