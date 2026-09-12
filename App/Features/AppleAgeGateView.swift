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
                        Text(
                            "PimPoPom does not receive your birthday. Eligible players receive age-related advertising protections."
                        )
                        .font(.footnote)
                        .foregroundStyle(Color(hex: theme.muted))
                    }
                    .webCardStyle(theme: theme, padding: 16)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Support & Legal").font(.headline)
                        legalLink("Privacy Policy", page: "privacy")
                        legalLink("Terms of Use", page: "terms")
                        legalLink("Refunds", page: "refunds")
                        legalLink("Support", page: "support")
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
        default: "Checking your Apple age range"
        }
    }

    private var message: String {
        switch controller.state {
        case .under13:
            "Apple's shared range does not establish that you are 13 or older. PimPoPom is for players aged 13 and over. To correct the range, review your Apple Account settings with your parent or guardian."
        case .sharingRequired:
            "We need a current Apple age range to continue. Sharing may be required in your region, or Apple previously supplied your age range. You can review sharing in your Apple Account settings."
        case .failed:
            "We could not complete Apple's age check. Please try again when connected. We will not guess your age or replace an Apple-supplied range with a manual choice."
        default:
            "Apple may ask you or your parent or guardian to share an age range. We use it to apply PimPoPom's 13+ access rule and advertising privacy protections."
        }
    }

    private func legalLink(_ title: String, page: String) -> some View {
        Link(title, destination: URL(string: "https://www.otcsoft.com/pimpopom-legal/\(page).html")!)
            .font(.body.weight(.semibold))
            .buttonStyle(WebSecondaryButtonStyle(theme: theme, minimumHeight: 48))
            .accessibilityIdentifier("age-legal-\(page)")
    }
}
