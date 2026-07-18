import Combine
import UIKit

enum HomeQuickAction {
    static let changeIconURL = URL(string: "pimpopom://settings/icon")!

    static func isChangeIcon(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "pimpopom"
            && url.host?.lowercased() == "settings"
            && url.path.lowercased() == "/icon"
    }
}

@MainActor
final class HomeQuickActionController: ObservableObject {
    static let shared = HomeQuickActionController()

    @Published private(set) var hasPendingChangeIconRequest = false

    init() {}

    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard HomeQuickAction.isChangeIcon(url) else { return false }
        requestChangeIcon()
        return true
    }

    @discardableResult
    func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        if let rawURL = shortcutItem.userInfo?["url"] as? String,
            let url = URL(string: rawURL),
            handle(url)
        {
            return true
        }

        guard shortcutItem.type.hasSuffix(".change-icon") else { return false }
        requestChangeIcon()
        return true
    }

    func requestChangeIcon() {
        hasPendingChangeIconRequest = true
    }

    func consumeChangeIconRequest() -> Bool {
        guard hasPendingChangeIconRequest else { return false }
        hasPendingChangeIconRequest = false
        return true
    }
}

final class PimPoPomAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = PimPoPomSceneDelegate.self

        if let shortcutItem = options.shortcutItem {
            Task { @MainActor in
                HomeQuickActionController.shared.handle(shortcutItem)
            }
        }

        return configuration
    }
}

final class PimPoPomSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            completionHandler(HomeQuickActionController.shared.handle(shortcutItem))
        }
    }
}
