import SwiftUI

@main
struct PimPoPomApp: App {
    @Environment(\.scenePhase) private var scenePhase
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
    @StateObject private var multiplayer: MultiplayerController
    @StateObject private var purchases: PurchaseController
    @StateObject private var ads: AdsController
    @StateObject private var appleAge: AppleAgeController
    @State private var hasOpenedApp = false
    @State private var deferredGoogleURL: URL?
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
                let ageStore: any AdAgeBandStoring
                if arguments.contains("--ui-test-age-gate") {
                    let defaults = UserDefaults(suiteName: "PimPoPomAgeGateUITests")!
                    if arguments.contains("--ui-test-age-reset") {
                        defaults.removePersistentDomain(forName: "PimPoPomAgeGateUITests")
                    }
                    ageStore = UserDefaultsAdAgeBandStore(defaults: defaults)
                } else {
                    ageStore = MemoryAdAgeBandStore(.adult)
                }
                adsController = AdsController(
                    configuration: .uiTesting(
                        adsEnabled: arguments.contains("--ui-test-ads-enabled")
                    ),
                    consentService: consent,
                    adsService: fakeAds,
                    progressStore: MemoryInterstitialProgressStore(),
                    ageStore: ageStore
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
        let audio = AudioController()
        _audio = StateObject(wrappedValue: audio)
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
        _multiplayer = StateObject(
            wrappedValue: MultiplayerController(
                backend: backend,
                gameCenter: gameCenter,
                audio: audio
            )
        )
        _purchases = StateObject(
            wrappedValue: PurchaseController(
                storeKit: storeKit, creditService: backend, startListeners: false
            )
        )
        _ads = StateObject(wrappedValue: adsController)
        var usesAppleAge = true
        var ageService: any AppleAgeServing = AppleAgeService()
        var ageLock: any AppleAgeLockStoring = UserDefaultsAppleAgeLockStore()
        #if DEBUG
            usesAppleAge = !ProcessInfo.processInfo.arguments.contains("--uitesting")
            if let mode = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--ui-test-apple-age=") }) {
                usesAppleAge = true
                ageService = UITestAppleAgeService(mode: String(mode.dropFirst("--ui-test-apple-age=".count)))
                ageLock = UITestAppleAgeLockStore()
            }
        #endif
        let ageController = AppleAgeController(
            ads: adsController, service: ageService, store: ageLock, isEnabled: usesAppleAge
        )
        _appleAge = StateObject(wrappedValue: ageController)
        googleIdentity.waitForAgeAuthorization = { [weak ageController] in
            guard let ageController else { throw CancellationError() }
            try await ageController.waitForAuthorization()
        }
        appleIdentity.waitForAgeAuthorization = { [weak ageController] in
            guard let ageController else { throw CancellationError() }
            try await ageController.waitForAuthorization()
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if ads.allowsApp || (hasOpenedApp && appleAge.state == .checking) {
                    RootView(
                        googleIdentity: googleIdentity,
                        appleIdentity: appleIdentity
                    )
                    .environment(\.scenePhase, ads.allowsApp ? scenePhase : .background)
                    .opacity(ads.allowsApp ? 1 : 0)
                    .disabled(!ads.allowsApp)
                    .accessibilityHidden(!ads.allowsApp)
                }
                if !ads.allowsApp {
                    AppleAgeGateView(controller: appleAge)
                }
            }
            .environmentObject(backend)
            .environmentObject(preferences)
            .environmentObject(cosmetics)
            .environmentObject(achievements)
            .environmentObject(audio)
            .environmentObject(appIcons)
            .environmentObject(quickActions)
            .environmentObject(gameCenter)
            .environmentObject(gameCenterAutoLink)
            .environmentObject(multiplayer)
            .environmentObject(purchases)
            .environmentObject(ads)
            .task(id: scenePhase) {
                if scenePhase == .active { appleAge.startIfNeeded() }
            }
            .onChange(of: scenePhase) { _, phase in
                // System permission sheets briefly make the scene inactive.
                // Only a real background/foreground cycle invalidates the result.
                if phase == .background { appleAge.setInBackground(true) }
                if phase == .active { appleAge.setInBackground(false) }
            }
            .onChange(of: ads.allowsApp) { _, allowed in
                if allowed {
                    hasOpenedApp = true
                    if let url = deferredGoogleURL {
                        deferredGoogleURL = nil
                        _ = googleIdentity.handle(url)
                    }
                } else {
                    purchases.stopTransactionListeners()
                    gameCenterAutoLink.reset()
                    gameCenter.suspendAuthentication()
                    audio.setApplicationActive(false)
                    multiplayer.setApplicationActive(false)
                }
            }
            .onChange(of: appleAge.state) { _, state in
                if state != .checking, !ads.allowsApp {
                    hasOpenedApp = false
                    deferredGoogleURL = nil
                }
            }
            .onOpenURL {
                guard ads.allowsApp else {
                    if HomeQuickAction.isChangeIcon($0) { _ = quickActions.handle($0) }
                    if appleAge.state == .checking, googleIdentity.recognizesCallback($0) {
                        deferredGoogleURL = $0
                    }
                    return
                }
                if !quickActions.handle($0) {
                    _ = googleIdentity.handle($0)
                }
            }
            .preferredColorScheme(cosmetics.theme.isLight ? .light : .dark)
        }
    }
}
