import CryptoKit
import Foundation
import UIKit

enum AdsMode: String, CaseIterable, Codable, Sendable {
    case disabled
    case demo
    case ownerSplitTest = "owner-split-test"
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
    let ownerBannerUnitID: String
    let ownerInterstitialUnitID: String
    let ownerTestDeviceIdentifiers: [String]
    let ownerDeviceIDFVHashes: [String]
    let isOwnerDevice: Bool
    let fallbackBannerUnitID: String
    let fallbackInterstitialUnitID: String

    init(
        mode: AdsMode,
        appID: String,
        bannerUnitID: String,
        interstitialUnitID: String,
        testDeviceIdentifiers: [String],
        ownerBannerUnitID: String = "",
        ownerInterstitialUnitID: String = "",
        ownerTestDeviceIdentifiers: [String] = [],
        ownerDeviceIDFVHashes: [String] = [],
        isOwnerDevice: Bool = false,
        fallbackBannerUnitID: String? = nil,
        fallbackInterstitialUnitID: String? = nil
    ) {
        self.mode = mode
        self.appID = appID
        self.bannerUnitID = bannerUnitID
        self.interstitialUnitID = interstitialUnitID
        self.testDeviceIdentifiers = testDeviceIdentifiers
        self.ownerBannerUnitID = ownerBannerUnitID
        self.ownerInterstitialUnitID = ownerInterstitialUnitID
        self.ownerTestDeviceIdentifiers = ownerTestDeviceIdentifiers
        self.ownerDeviceIDFVHashes = ownerDeviceIDFVHashes
        self.isOwnerDevice = isOwnerDevice
        self.fallbackBannerUnitID = fallbackBannerUnitID ?? bannerUnitID
        self.fallbackInterstitialUnitID = fallbackInterstitialUnitID ?? interstitialUnitID
    }

    var isEnabled: Bool { mode.isEnabled }

    @MainActor
    static func load(bundle: Bundle = .main) -> AdsConfiguration {
        let values = bundle.infoDictionary ?? [:]
        return fromInfoDictionary(
            values,
            identifierForVendor: UIDevice.current.identifierForVendor
        )
    }

    static func fromInfoDictionary(
        _ values: [String: Any],
        identifierForVendor: UUID? = nil
    ) -> AdsConfiguration {
        let mode =
            AdsMode(
                rawValue: stringValue(values["PimPoPomAdsMode"])
            ) ?? .disabled
        let defaultBannerUnitID = stringValue(values["PimPoPomAdMobBannerUnitID"])
        let defaultInterstitialUnitID = stringValue(
            values["PimPoPomAdMobInterstitialUnitID"]
        )
        let configuredTestDeviceIdentifiers = splitIdentifiers(
            stringValue(values["PimPoPomAdMobTestDeviceIDs"])
        )
        let ownerBannerUnitID = stringValue(values["PimPoPomAdMobOwnerBannerUnitID"])
        let ownerInterstitialUnitID = stringValue(
            values["PimPoPomAdMobOwnerInterstitialUnitID"]
        )
        let ownerDeviceIDFVHashes = splitIdentifiers(
            stringValue(values["PimPoPomOwnerDeviceIDFVHashes"])
        ).map { $0.lowercased() }
        let identifierFingerprint = identifierForVendorFingerprint(identifierForVendor)
        let isOwnerDevice =
            mode == .ownerSplitTest
            && !identifierFingerprint.isEmpty
            && ownerDeviceIDFVHashes.contains(identifierFingerprint)

        return AdsConfiguration(
            mode: mode,
            appID: stringValue(values["GADApplicationIdentifier"]),
            bannerUnitID: isOwnerDevice ? ownerBannerUnitID : defaultBannerUnitID,
            interstitialUnitID: isOwnerDevice
                ? ownerInterstitialUnitID
                : defaultInterstitialUnitID,
            testDeviceIdentifiers: isOwnerDevice ? configuredTestDeviceIdentifiers : [],
            ownerBannerUnitID: ownerBannerUnitID,
            ownerInterstitialUnitID: ownerInterstitialUnitID,
            ownerTestDeviceIdentifiers: configuredTestDeviceIdentifiers,
            ownerDeviceIDFVHashes: ownerDeviceIDFVHashes,
            isOwnerDevice: isOwnerDevice,
            fallbackBannerUnitID: defaultBannerUnitID,
            fallbackInterstitialUnitID: defaultInterstitialUnitID
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
        case .ownerSplitTest:
            if configurationName != nil, configurationName != "Staging" {
                problems.append("Owner split testing is restricted to Staging.")
            }
            if !Self.isReviewedDemoPair(
                bannerUnitID: fallbackBannerUnitID,
                interstitialUnitID: fallbackInterstitialUnitID
            ) {
                problems.append("Owner split testing requires Google demo units by default.")
            }
            if !Self.looksLikeProductionUnit(ownerBannerUnitID)
                || !Self.looksLikeProductionUnit(ownerInterstitialUnitID)
            {
                problems.append("Owner split testing requires production-format owner units.")
            }
            if ownerTestDeviceIdentifiers.count != 1
                || !Self.isHex(ownerTestDeviceIdentifiers[0], length: 32)
            {
                problems.append("Owner split testing requires one GMA test-device hash.")
            }
            if ownerDeviceIDFVHashes.isEmpty
                || ownerDeviceIDFVHashes.count > 4
                || Set(ownerDeviceIDFVHashes).count != ownerDeviceIDFVHashes.count
                || ownerDeviceIDFVHashes.contains(where: { !Self.isHex($0, length: 64) })
            {
                problems.append(
                    "Owner split testing requires one to four unique SHA-256 IDFV fingerprints."
                )
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

    static func identifierForVendorFingerprint(_ identifier: UUID?) -> String {
        guard let identifier else { return "" }
        let normalized = identifier.uuidString.lowercased()
        return SHA256.hash(data: Data(normalized.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func isReviewedDemoPair(
        bannerUnitID: String,
        interstitialUnitID: String
    ) -> Bool {
        bannerUnitID == fixedBannerDemoUnitID
            && interstitialUnitID == interstitialDemoUnitID
    }

    private static func isHex(_ value: String, length: Int) -> Bool {
        value.count == length && value.allSatisfy(\.isHexDigit)
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
    static let threshold = 3

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
    // The storage generation tracks cadence semantics. Build 6 changes the
    // threshold from ten completions to three, so an old partial counter must
    // not be interpreted under the new policy.
    private static let key = "ads.interstitial-progress.v2"
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
