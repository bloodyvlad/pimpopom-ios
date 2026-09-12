import SwiftUI

@MainActor
struct AgeGroupView: View {
    @EnvironmentObject private var cosmetics: CosmeticsController
    @State private var draftBand: AdAgeBand?
    @State private var isReviewingBlockedAge = false
    @State private var isSaving = false

    let currentBand: AdAgeBand?
    let onSave: @MainActor (AdAgeBand) async -> Void
    let onCancel: (() -> Void)?

    init(
        currentBand: AdAgeBand?,
        onSave: @escaping @MainActor (AdAgeBand) async -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.currentBand = currentBand
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var theme: ThemePalette { cosmetics.theme }
    private var selectedBand: AdAgeBand? { draftBand ?? currentBand }
    private var isEditing: Bool { onCancel != nil }
    private var showsBlockedState: Bool {
        !isEditing && currentBand?.allowsApp == false && !isReviewingBlockedAge
    }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: theme)

            ScrollView {
                VStack(spacing: 16) {
                    if showsBlockedState {
                        blockedCard
                    } else {
                        selectionCard
                    }
                    legalCard
                }
                .padding(16)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .id(showsBlockedState)
        }
        .foregroundStyle(Color(hex: theme.foreground))
        .preferredColorScheme(theme.isLight ? .light : .dark)
        .interactiveDismissDisabled(isSaving)
        .onChange(of: currentBand) {
            draftBand = nil
            isReviewingBlockedAge = false
        }
    }

    private var selectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEditing ? "Review your age group" : "Choose your age group")
                .font(theme.ageGroupFont(size: 24, weight: .black, relativeTo: .title2))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                // Keep the screen marker on a leaf so child control IDs remain intact.
                .accessibilityIdentifier("age-gate")

            Text(
                "We save your age group on this device and use it to set advertising privacy protections. We do not ask for your birthday."
            )
            .font(theme.ageGroupFont(size: 16, weight: .regular, relativeTo: .body))
            .fixedSize(horizontal: false, vertical: true)

            Text("For eligible players, Google receives an age-related signal for advertising privacy.")
                .font(theme.ageGroupFont(size: 14, weight: .regular, relativeTo: .subheadline))
                .foregroundStyle(Color(hex: theme.muted))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                ForEach(AdAgeBand.allCases, id: \.rawValue) { band in
                    AgeGroupChoiceButton(
                        theme: theme,
                        band: band,
                        isSelected: selectedBand == band
                    ) {
                        draftBand = band
                    }
                    .disabled(isSaving)
                }
            }

            Button(action: saveSelection) {
                Text(isSaving ? "Saving…" : (isEditing ? "Save" : "Continue"))
                    .font(theme.ageGroupFont(size: 16, weight: .bold, relativeTo: .body))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: theme,
                    accent: Color(hex: theme.chromeAccent),
                    minimumHeight: 48
                )
            )
            .disabled(selectedBand == nil || isSaving)
            .accessibilityHint(selectedBand == nil ? "Choose an age group first" : "Saves your age group")
            .accessibilityIdentifier(isEditing ? "age-save" : "age-continue")

            if let onCancel {
                Button("Cancel", action: onCancel)
                    .font(theme.ageGroupFont(size: 16, weight: .bold, relativeTo: .body))
                    .buttonStyle(WebSecondaryButtonStyle(theme: theme, minimumHeight: 48))
                    .disabled(isSaving)
                    .accessibilityIdentifier("age-cancel")
            }
        }
        .webCardStyle(theme: theme, padding: 16)
    }

    private var blockedCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ages 13 and over")
                .font(theme.ageGroupFont(size: 24, weight: .black, relativeTo: .title2))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("age-blocked")

            Text(
                "PimPoPom is available to players aged 13 and over. You can still read our legal and support information below."
            )
            .font(theme.ageGroupFont(size: 16, weight: .regular, relativeTo: .body))
            .fixedSize(horizontal: false, vertical: true)

            Button("Review age group") {
                draftBand = nil
                isReviewingBlockedAge = true
            }
            .font(theme.ageGroupFont(size: 16, weight: .bold, relativeTo: .body))
            .buttonStyle(WebSecondaryButtonStyle(theme: theme, minimumHeight: 48))
            .accessibilityHint("Returns to age group selection")
            .accessibilityIdentifier("age-review")
        }
        .webCardStyle(theme: theme, padding: 16)
    }

    private var legalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Support & Legal")
                .font(theme.ageGroupFont(size: 18, weight: .black, relativeTo: .headline))
                .accessibilityAddTraits(.isHeader)
            legalLink("Privacy Policy", page: "privacy")
            legalLink("Terms of Use", page: "terms")
            legalLink("Refunds", page: "refunds")
            legalLink("Support", page: "support")
        }
        .webCardStyle(theme: theme, padding: 16)
    }

    private func legalLink(_ title: String, page: String) -> some View {
        Link(destination: URL(string: "https://www.otcsoft.com/pimpopom-legal/\(page).html")!) {
            HStack(spacing: 12) {
                Text(title)
                    .font(theme.ageGroupFont(size: 16, weight: .bold, relativeTo: .body))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(WebSecondaryButtonStyle(theme: theme, minimumHeight: 48))
        .accessibilityHint("Opens \(title) on otcsoft.com")
        .accessibilityIdentifier("age-legal-\(page)")
    }

    private func saveSelection() {
        guard let selectedBand, !isSaving else { return }
        isSaving = true
        Task { @MainActor in
            await onSave(selectedBand)
            draftBand = nil
            isReviewingBlockedAge = false
            isSaving = false
        }
    }
}

private struct AgeGroupChoiceButton: View {
    let theme: ThemePalette
    let band: AdAgeBand
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(band.displayTitle)
                    .font(theme.ageGroupFont(size: 18, weight: .bold, relativeTo: .headline))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(
            WebSecondaryButtonStyle(
                theme: theme,
                accent: isSelected ? Color(hex: theme.chromeAccent) : nil,
                minimumHeight: 52
            )
        )
        .accessibilityLabel(band.displayTitle)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("age-band-\(band.rawValue)")
    }
}

extension ThemePalette {
    fileprivate func ageGroupFont(
        size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle
    ) -> Font {
        if isPixel {
            return appFont(size: size, weight: weight, relativeTo: style)
        }
        return .system(style, design: fontDesign).weight(weight)
    }
}
