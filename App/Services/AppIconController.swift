import Combine
import UIKit

enum AppIconChoice: String, CaseIterable, Identifiable, Sendable {
    case glow
    case light
    case pixel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glow: "Glow"
        case .light: "Light"
        case .pixel: "Pixel"
        }
    }

    var alternateIconName: String? {
        switch self {
        case .glow: nil
        case .light: "AppIconLight"
        case .pixel: "AppIconPixel"
        }
    }

    var previewAssetName: String {
        switch self {
        case .glow: "AppIconGlowPreview"
        case .light: "AppIconLightPreview"
        case .pixel: "AppIconPixelPreview"
        }
    }

    static func resolve(alternateIconName: String?) -> Self {
        allCases.first { $0.alternateIconName == alternateIconName } ?? .glow
    }
}

@MainActor
protocol AppIconApplication: AnyObject {
    var supportsAlternateIcons: Bool { get }
    var alternateIconName: String? { get }
    func setAlternateIconName(_ alternateIconName: String?) async throws
}

extension UIApplication: AppIconApplication {}

@MainActor
final class AppIconController: ObservableObject {
    @Published private(set) var selectedChoice: AppIconChoice
    @Published private(set) var isChanging = false
    @Published private(set) var statusMessage: String?

    private let application: any AppIconApplication

    init(application: any AppIconApplication = UIApplication.shared) {
        self.application = application
        selectedChoice = AppIconChoice.resolve(alternateIconName: application.alternateIconName)
    }

    var supportsAlternateIcons: Bool {
        application.supportsAlternateIcons
    }

    func refresh() {
        selectedChoice = AppIconChoice.resolve(alternateIconName: application.alternateIconName)
    }

    func select(_ choice: AppIconChoice) async {
        guard choice != selectedChoice else { return }
        guard supportsAlternateIcons else {
            statusMessage = "Alternate app icons are not supported on this device."
            return
        }

        isChanging = true
        statusMessage = nil
        defer { isChanging = false }

        do {
            try await application.setAlternateIconName(choice.alternateIconName)
            selectedChoice = AppIconChoice.resolve(
                alternateIconName: application.alternateIconName
            )
            if selectedChoice != choice {
                statusMessage = "iOS kept the previous app icon."
            }
        } catch {
            refresh()
            statusMessage = "Could not change the app icon: \(error.localizedDescription)"
        }
    }
}
