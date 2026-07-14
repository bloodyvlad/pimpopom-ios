import SwiftUI

@main
struct PimPoPomApp: App {
    private let services = AlphaServices.localOnly

    var body: some Scene {
        WindowGroup {
            RootView(services: services)
        }
    }
}
