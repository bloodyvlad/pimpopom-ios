import SwiftUI

@main
struct PimPoPomApp: App {
    @UIApplicationDelegateAdaptor(PimPoPomAppDelegate.self) private var appDelegate
    @StateObject private var backend: BackendClient
    @StateObject private var preferences: AppPreferences
    @StateObject private var cosmetics: CosmeticsController
    @StateObject private var achievements: AchievementsController
    @StateObject private var audio: AudioController
    @StateObject private var appIcons: AppIconController
    @StateObject private var quickActions: HomeQuickActionController
    @StateObject private var gameCenter: GameCenterService
    @StateObject private var gameCenterAutoLink: GameCenterAutoLinkController
    @StateObject private var purchases: PurchaseController
    @StateObject private var ads: AdsController
    private let googleIdentity = GoogleIdentityService()
    private let appleIdentity = AppleIdentityService()

    init() {
        let backend = BackendClient()
        let preferences = AppPreferences()
        let storeKit: any StoreKitServing
        let adsController: AdsController
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--uitesting") {
                storeKit = UITestStoreKitService()
                let privacyRequirement: PrivacyOptionsRequirement =
                    arguments.contains("--ui-test-privacy-required") ? .required : .notRequired
                let consent = FakeConsentService(
                    snapshot: ConsentSnapshot(
                        canRequestAds: !arguments.contains("--ui-test-consent-blocked"),
                        privacyOptionsRequirement: privacyRequirement
                    )
                )
                let fakeAds = FakeAdsService()
                fakeAds.interstitialAvailable =
                    !arguments.contains("--ui-test-interstitial-unavailable")
                adsController = AdsController(
                    configuration: .uiTesting(
                        adsEnabled: arguments.contains("--ui-test-ads-enabled")
                    ),
                    consentService: consent,
                    adsService: fakeAds,
                    progressStore: MemoryInterstitialProgressStore()
                )
            } else {
                storeKit = StoreKitService()
                adsController = AdsController()
            }
        #else
            storeKit = StoreKitService()
            adsController = AdsController()
        #endif
        _backend = StateObject(wrappedValue: backend)
        _preferences = StateObject(wrappedValue: preferences)
        _cosmetics = StateObject(
            wrappedValue: CosmeticsController(backend: backend, preferences: preferences)
        )
        _achievements = StateObject(wrappedValue: AchievementsController(backend: backend))
        _audio = StateObject(wrappedValue: AudioController())
        _appIcons = StateObject(wrappedValue: AppIconController())
        _quickActions = StateObject(wrappedValue: HomeQuickActionController.shared)
        let gameCenter = GameCenterService()
        _gameCenter = StateObject(wrappedValue: gameCenter)
        _gameCenterAutoLink = StateObject(
            wrappedValue: GameCenterAutoLinkController(
                backend: backend,
                gameCenter: gameCenter
            )
        )
        _purchases = StateObject(
            wrappedValue: PurchaseController(storeKit: storeKit, creditService: backend)
        )
        _ads = StateObject(wrappedValue: adsController)
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                googleIdentity: googleIdentity,
                appleIdentity: appleIdentity
            )
            .environmentObject(backend)
            .environmentObject(preferences)
            .environmentObject(cosmetics)
            .environmentObject(achievements)
            .environmentObject(audio)
            .environmentObject(appIcons)
            .environmentObject(quickActions)
            .environmentObject(gameCenter)
            .environmentObject(gameCenterAutoLink)
            .environmentObject(purchases)
            .environmentObject(ads)
            .onOpenURL {
                if !quickActions.handle($0) {
                    _ = googleIdentity.handle($0)
                }
            }
            .preferredColorScheme(cosmetics.theme.isLight ? .light : .dark)
        }
    }
}
