import SwiftUI

@main
struct PimPoPomApp: App {
    @StateObject private var backend = BackendClient()
    private let services = AlphaServices.localOnly
    private let googleIdentity = GoogleIdentityService()

    var body: some Scene {
        WindowGroup {
            RootView(services: services, googleIdentity: googleIdentity)
                .environmentObject(backend)
                .onOpenURL { _ = googleIdentity.handle($0) }
                .preferredColorScheme(.dark)
        }
    }
}
