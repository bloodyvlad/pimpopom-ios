import SwiftUI

@main
struct PimPoPomApp: App {
    @StateObject private var backend: BackendClient
    @StateObject private var preferences: AppPreferences
    @StateObject private var cosmetics: CosmeticsController
    @StateObject private var audio: AudioController
    private let services = AlphaServices.localOnly
    private let googleIdentity = GoogleIdentityService()

    init() {
        let backend = BackendClient()
        let preferences = AppPreferences()
        _backend = StateObject(wrappedValue: backend)
        _preferences = StateObject(wrappedValue: preferences)
        _cosmetics = StateObject(
            wrappedValue: CosmeticsController(backend: backend, preferences: preferences)
        )
        _audio = StateObject(wrappedValue: AudioController())
    }

    var body: some Scene {
        WindowGroup {
            RootView(services: services, googleIdentity: googleIdentity)
                .environmentObject(backend)
                .environmentObject(preferences)
                .environmentObject(cosmetics)
                .environmentObject(audio)
                .onOpenURL { _ = googleIdentity.handle($0) }
                .preferredColorScheme(cosmetics.theme.isLight ? .light : .dark)
        }
    }
}
