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
    @StateObject private var purchases: PurchaseController
    private let services = AlphaServices.localOnly
    private let googleIdentity = GoogleIdentityService()

    init() {
        let backend = BackendClient()
        let preferences = AppPreferences()
        let storeKit: any StoreKitServing
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                storeKit = UITestStoreKitService()
            } else {
                storeKit = StoreKitService()
            }
        #else
            storeKit = StoreKitService()
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
        _gameCenter = StateObject(wrappedValue: GameCenterService())
        _purchases = StateObject(
            wrappedValue: PurchaseController(storeKit: storeKit, creditService: backend)
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(services: services, googleIdentity: googleIdentity)
                .environmentObject(backend)
                .environmentObject(preferences)
                .environmentObject(cosmetics)
                .environmentObject(achievements)
                .environmentObject(audio)
                .environmentObject(appIcons)
                .environmentObject(quickActions)
                .environmentObject(gameCenter)
                .environmentObject(purchases)
                .onOpenURL {
                    if !quickActions.handle($0) {
                        _ = googleIdentity.handle($0)
                    }
                }
                .preferredColorScheme(cosmetics.theme.isLight ? .light : .dark)
        }
    }
}
