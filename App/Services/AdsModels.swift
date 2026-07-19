import Foundation
import UIKit

enum AdsMode: String, CaseIterable, Codable, Sendable {
    case disabled
    case demo
    case ownerRealTest = "owner-real-test"
    case live

    var isEnabled: Bool { self != .disabled }
}

struct AdsConfiguration: Equatable, Sendable {
    static let realAppID = "ca-app-pub-6428992187280935~3622035442"
    static let fixedBannerDemoUnitID = "ca-app-pub-3940256099942544/2934735716"
    static let interstitialDemoUnitID = "ca-app-pub-3940256099942544/4411468910"

    let mode: AdsMode
    let appID: String
    let bannerUnitID: String
    let interstitialUnitID: String
    let testDeviceIdentifiers: [String]

    var isEnabled: Bool { mode.isEnabled }

    static func load(bundle: Bundle = .main) -> AdsConfiguration {
        let values = bundle.infoDictionary ?? [:]
        return fromInfoDictionary(values)
    }

    static func fromInfoDictionary(_ values: [String: Any]) -> AdsConfiguration {
        let mode =
            AdsMode(
                rawValue: stringValue(values["PimPoPomAdsMode"])
            ) ?? .disabled
        return AdsConfiguration(
            mode: mode,
            appID: stringValue(values["GADApplicationIdentifier"]),
            bannerUnitID: stringValue(values["PimPoPomAdMobBannerUnitID"]),
            interstitialUnitID: stringValue(values["PimPoPomAdMobInterstitialUnitID"]),
            testDeviceIdentifiers: splitIdentifiers(
                stringValue(values["PimPoPomAdMobTestDeviceIDs"])
            )
        )
    }

    #if DEBUG
        static func uiTesting(adsEnabled: Bool) -> AdsConfiguration {
            AdsConfiguration(
                mode: adsEnabled ? .demo : .disabled,
                appID: realAppID,
                bannerUnitID: adsEnabled ? fixedBannerDemoUnitID : "",
                interstitialUnitID: adsEnabled ? interstitialDemoUnitID : "",
                testDeviceIdentifiers: []
            )
        }
    #endif

    func validationProblems(configurationName: String? = nil) -> [String] {
        var problems: [String] = []
        if appID != Self.realAppID {
            problems.append("The real PimPoPom AdMob App ID is required.")
        }

        switch mode {
        case .disabled:
            if !bannerUnitID.isEmpty || !interstitialUnitID.isEmpty {
                problems.append("Disabled mode must not contain ad-unit IDs.")
            }
            if !testDeviceIdentifiers.isEmpty {
                problems.append("Disabled mode must not contain test-device IDs.")
            }
        case .demo:
            if bannerUnitID != Self.fixedBannerDemoUnitID {
                problems.append("Demo mode requires Google's fixed banner test unit.")
            }
            if interstitialUnitID != Self.interstitialDemoUnitID {
                problems.append("Demo mode requires Google's interstitial test unit.")
            }
            if !testDeviceIdentifiers.isEmpty {
                problems.append("Demo mode must not contain private test-device IDs.")
            }
            if configurationName == "Release" || configurationName == "OwnerAdsQA" {
                problems.append("Demo mode is not valid for this configuration.")
            }
        case .ownerRealTest:
            if configurationName != nil, configurationName != "OwnerAdsQA" {
                problems.append("Owner real-unit testing is restricted to OwnerAdsQA.")
            }
            if !Self.looksLikeProductionUnit(bannerUnitID)
                || !Self.looksLikeProductionUnit(interstitialUnitID)
            {
                problems.append("Owner Ads QA requires production-format ad units.")
            }
            if testDeviceIdentifiers.isEmpty {
                problems.append("Owner Ads QA requires an ignored test-device hash.")
            }
        case .live:
            if configurationName != nil, configurationName != "Release" {
                problems.append("Live mode is restricted to Release.")
            }
            if !Self.looksLikeProductionUnit(bannerUnitID)
                || !Self.looksLikeProductionUnit(interstitialUnitID)
            {
                problems.append("Live mode requires production-format ad units.")
            }
            if !testDeviceIdentifiers.isEmpty {
                problems.append("Live mode must not contain test-device IDs.")
            }
        }
        return problems
    }

    private static func stringValue(_ value: Any?) -> String {
        (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func splitIdentifiers(_ value: String) -> [String] {
        value.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func looksLikeProductionUnit(_ value: String) -> Bool {
        value.hasPrefix("ca-app-pub-6428992187280935/")
            && value != fixedBannerDemoUnitID
            && value != interstitialDemoUnitID
    }
}

enum AdAccountResolution: Equatable, Sendable {
    case unresolved
    case adsAllowed
    case adFree

    static func resolve(_ session: SessionResponse?) -> AdAccountResolution {
        guard let session else { return .unresolved }
        if !session.authenticated, session.profile == nil {
            return .adsAllowed
        }
        guard session.authenticated, session.profile != nil, let adFree = session.adFree else {
            return .unresolved
        }
        return adFree ? .adFree : .adsAllowed
    }
}

enum PrivacyOptionsRequirement: Equatable, Sendable {
    case unknown
    case notRequired
    case required
}

struct ConsentSnapshot: Equatable, Sendable {
    let canRequestAds: Bool
    let privacyOptionsRequirement: PrivacyOptionsRequirement
}

enum BannerAdState: Equatable, Sendable {
    case unavailable
    case loading
    case loaded
    case failed
}

@MainActor
protocol ConsentServing: AnyObject {
    var currentSnapshot: ConsentSnapshot { get }
    func requestConsent() async throws -> ConsentSnapshot
    func presentPrivacyOptions() async throws -> ConsentSnapshot
}

@MainActor
protocol AdsServing: AnyObject {
    var onBannerStateChange: ((BannerAdState) -> Void)? { get set }
    var onInterstitialPresentationBegan: (() -> Void)? { get set }
    var onInterstitialPresentationEnded: (() -> Void)? { get set }

    func configure(_ configuration: AdsConfiguration)
    func start()
    func attachBanner(to container: UIView, availableWidth: CGFloat)
    func detachBanner(from container: UIView)
    func preloadInterstitial()
    func presentInterstitial() -> Bool
    func setApplicationActive(_ isActive: Bool)
    func destroyAll()
}

struct InterstitialProgress: Codable, Equatable, Sendable {
    static let threshold = 10

    var completedSessions: Int
    var isDue: Bool
    var recentCompletionIDs: [String]

    static let empty = InterstitialProgress(
        completedSessions: 0,
        isDue: false,
        recentCompletionIDs: []
    )

    mutating func record(completionID: UUID) -> Bool {
        let value = completionID.uuidString.lowercased()
        guard !recentCompletionIDs.contains(value) else { return false }
        recentCompletionIDs.append(value)
        if recentCompletionIDs.count > 20 {
            recentCompletionIDs.removeFirst(recentCompletionIDs.count - 20)
        }
        completedSessions = min(Self.threshold, completedSessions + 1)
        isDue = completedSessions >= Self.threshold
        return true
    }

    mutating func markPresented() {
        completedSessions = 0
        isDue = false
    }

    mutating func clearCadence() {
        completedSessions = 0
        isDue = false
    }
}

@MainActor
protocol InterstitialProgressStoring: AnyObject {
    func load() -> InterstitialProgress
    func save(_ progress: InterstitialProgress)
}

@MainActor
final class UserDefaultsInterstitialProgressStore: InterstitialProgressStoring {
    private static let key = "ads.interstitial-progress.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> InterstitialProgress {
        guard let data = defaults.data(forKey: Self.key),
            let decoded = try? JSONDecoder().decode(InterstitialProgress.self, from: data)
        else { return .empty }
        return decoded
    }

    func save(_ progress: InterstitialProgress) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

@MainActor
final class MemoryInterstitialProgressStore: InterstitialProgressStoring {
    private(set) var progress: InterstitialProgress

    init(progress: InterstitialProgress = .empty) {
        self.progress = progress
    }

    func load() -> InterstitialProgress { progress }
    func save(_ progress: InterstitialProgress) { self.progress = progress }
}
