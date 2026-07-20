import GoogleMobileAds
import OSLog
import UIKit
import UserMessagingPlatform

@MainActor
final class GoogleConsentService: ConsentServing {
    var currentSnapshot: ConsentSnapshot {
        ConsentSnapshot(
            canRequestAds: ConsentInformation.shared.canRequestAds,
            privacyOptionsRequirement: privacyRequirement
        )
    }

    func requestConsent() async throws -> ConsentSnapshot {
        let parameters = RequestParameters()
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        try await ConsentForm.loadAndPresentIfRequired(from: nil)
        return currentSnapshot
    }

    func presentPrivacyOptions() async throws -> ConsentSnapshot {
        try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        return currentSnapshot
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
}

@MainActor
final class GoogleAdsService: NSObject, AdsServing {
    var onBannerStateChange: ((BannerAdState) -> Void)?
    var onInterstitialPresentationBegan: (() -> Void)?
    var onInterstitialPresentationEnded: (() -> Void)?

    private var configuration: AdsConfiguration?
    private var hasStarted = false
    private var hasInitializedSDK = false
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

    func configure(_ configuration: AdsConfiguration) {
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
        requestConfiguration.ageRestrictedTreatment = .unspecified
        requestConfiguration.publisherPrivacyPersonalizationState = .disabled
        requestConfiguration.setPublisherFirstPartyIDEnabled(false)
        requestConfiguration.testDeviceIdentifiers =
            configuration.testDeviceIdentifiers.isEmpty
            ? nil
            : configuration.testDeviceIdentifiers
        logger.notice(
            "Configured ads route: \(configuration.isOwnerDevice ? "owner primary with demo fallback" : "demo", privacy: .public)"
        )
        consoleDiagnostic(
            configuration.isOwnerDevice ? "route=owner-primary" : "route=demo"
        )
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        if !hasInitializedSDK {
            hasInitializedSDK = true
            MobileAds.shared.start()
        }
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
        banner.load(Request())
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

        interstitialLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { interstitialLoadTask = nil }
            await loadInterstitialWithFallback()
        }
    }

    private func loadInterstitialWithFallback() async {
        while hasStarted, isApplicationActive, let route = interstitialRoute {
            do {
                let ad = try await InterstitialAd.load(
                    with: route.currentUnitID,
                    request: Request()
                )
                guard hasStarted else { return }
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
        hasStarted = false
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
    func adWillPresentFullScreenContent(_: FullScreenPresentingAd) {
        onInterstitialPresentationBegan?()
    }

    func ad(
        _: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError _: Error
    ) {
        interstitialAd = nil
        interstitialLoadedAt = nil
        isPresentingInterstitial = false
        onInterstitialPresentationEnded?()
    }

    func adDidDismissFullScreenContent(_: FullScreenPresentingAd) {
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

    func requestConsent() async throws -> ConsentSnapshot {
        requestCount += 1
        if let requestError { throw requestError }
        return snapshot
    }

    func presentPrivacyOptions() async throws -> ConsentSnapshot {
        privacyOptionsPresentationCount += 1
        if let privacyOptionsError { throw privacyOptionsError }
        return snapshot
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

    func configure(_: AdsConfiguration) {
        configureCount += 1
        configured = true
    }

    func start() {
        guard configured else { return }
        startCount += 1
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
        destroyCount += 1
        started = false
        hasResolvedBanner = false
        label.removeFromSuperview()
        onBannerStateChange?(.unavailable)
    }
}
