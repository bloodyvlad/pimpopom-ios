import SwiftUI

struct AppleAgeGateView: View {
    @ObservedObject var controller: AppleAgeController
    @EnvironmentObject private var cosmetics: CosmeticsController

    private var theme: ThemePalette { cosmetics.theme }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: theme)
            ScrollView {
                VStack(spacing: 16) {
                    PimPoPomWordmark(theme: theme, size: 32, identifier: "age-wordmark")
                        .padding(.vertical, 16)
                    VStack(alignment: .leading, spacing: 16) {
                        Text(title)
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("apple-age-gate")
                        Text(message)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("apple-age-message")
                        if let range = controller.sharedRange {
                            Text("Apple age range: \(range.displayTitle)")
                                .font(.headline)
                                .accessibilityIdentifier("apple-age-range")
                        }
                        if controller.isWorking {
                            ProgressView("Checking with Apple…")
                                .accessibilityIdentifier("apple-age-progress")
                        } else {
                            Button("Check with Apple again") { controller.scheduleRefresh() }
                                .buttonStyle(WebSecondaryButtonStyle(theme: theme, minimumHeight: 48))
                                .accessibilityIdentifier("apple-age-retry")
                        }
                        Text("Your birthday and passcodes are never shared with PimPoPom.")
                            .font(.footnote)
                            .foregroundStyle(Color(hex: theme.muted))
                    }
                    .webCardStyle(theme: theme, padding: 16)
                }
                .padding(16)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(Color(hex: theme.foreground))
    }

    private var title: String {
        switch controller.state {
        case .under13: "Ages 13 and over"
        case .sharingRequired: "Apple age range needed"
        case .failed: "Apple age check unavailable"
        default: "Checking age requirements"
        }
    }

    private var message: String {
        switch controller.state {
        case .under13:
            "PimPoPom is for players aged 13 and over. The age information available for this account is below that range."
        case .sharingRequired:
            "An Apple age range is needed for your account. Review Age Range for Apps in your Apple Account settings, then try again."
        case .failed:
            "Apple could not complete this check. Try again, or review Age Range for Apps in your Apple Account settings."
        default:
            "Checking whether your Apple Account requires age confirmation."
        }
    }

}
