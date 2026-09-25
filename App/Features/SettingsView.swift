import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var audio: AudioController
    @EnvironmentObject private var cosmetics: CosmeticsController
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var appIcons: AppIconController
    @EnvironmentObject private var ads: AdsController
    @State private var tutorialMode: HowToPlayMode?

    private var palette: ThemePalette { cosmetics.theme }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: palette)

            ScrollView {
                VStack(spacing: 12) {
                    settingCard(title: "How to play", systemImage: "hand.tap.fill") {
                        ForEach(HowToPlayMode.allCases) { mode in
                            Button("Replay \(mode.title) tutorial") { tutorialMode = mode }
                                .buttonStyle(WebSecondaryButtonStyle(theme: palette, minimumHeight: 44))
                                .accessibilityIdentifier("replay-tutorial-\(mode.rawValue)")
                        }
                        Text("Practice safely, and change whether each tutorial appears before you play.")
                            .font(palette.appFont(size: 12, weight: .medium, relativeTo: .caption))
                            .foregroundStyle(Color(hex: palette.muted))
                    }
                    settingCard(title: "App Icon", systemImage: "app.badge") {
                        HStack(spacing: 12) {
                            ForEach(AppIconChoice.allCases) { choice in
                                iconChoiceButton(choice)
                            }
                        }

                        Text("iOS shows a confirmation before changing the Home Screen icon.")
                            .font(palette.appFont(size: 12, weight: .medium, relativeTo: .caption))
                            .foregroundStyle(Color(hex: palette.muted))

                        if !appIcons.supportsAlternateIcons {
                            Text("Alternate app icons are unavailable on this device.")
                                .font(
                                    palette.appFont(
                                        size: 12,
                                        weight: .bold,
                                        relativeTo: .caption
                                    )
                                )
                                .foregroundStyle(.orange)
                        }

                        if let status = appIcons.statusMessage {
                            Text(status)
                                .font(
                                    palette.appFont(
                                        size: 12,
                                        weight: .bold,
                                        relativeTo: .caption
                                    )
                                )
                                .foregroundStyle(.orange)
                        }
                    }

                    settingCard(title: "Glyphs", systemImage: "character.cursor.ibeam") {
                        Toggle("Color-blind glyphs", isOn: $preferences.glyphsEnabled)
                            .tint(Color(hex: palette.chromeAccent))
                            .accessibilityIdentifier("glyphs-toggle")
                        Text("Show a shape inside each color tile and in the target header.")
                            .font(palette.appFont(size: 12, weight: .medium, relativeTo: .caption))
                            .foregroundStyle(Color(hex: palette.muted))
                    }

                    settingCard(title: "Sound Effects", systemImage: "speaker.wave.2.fill") {
                        Toggle("Sound Effects", isOn: $preferences.soundEffectsEnabled)
                            .tint(Color(hex: palette.chromeAccent))
                            .accessibilityIdentifier("sound-effects-toggle")
                        HStack {
                            Image(systemName: "speaker.fill")
                            Slider(value: $preferences.soundEffectsVolume, in: 0...1)
                                .tint(Color(hex: palette.chromeAccent))
                                .disabled(!preferences.soundEffectsEnabled)
                            Image(systemName: "speaker.wave.3.fill")
                        }
                        Button("Test tap sound") { audio.playTap(hitNumber: 1) }
                            .buttonStyle(
                                WebSecondaryButtonStyle(
                                    theme: palette,
                                    accent: Color(hex: palette.chromeAccent),
                                    minimumHeight: 44
                                )
                            )
                            .disabled(!preferences.soundEffectsEnabled)
                    }

                    settingCard(title: "Music", systemImage: "music.note") {
                        Toggle("Music", isOn: $preferences.musicEnabled)
                            .tint(Color(hex: palette.chromeAccent))
                            .accessibilityIdentifier("music-toggle")
                        HStack {
                            Image(systemName: "speaker.fill")
                            Slider(value: $preferences.musicVolume, in: 0...1)
                                .tint(Color(hex: palette.chromeAccent))
                                .disabled(!preferences.musicEnabled)
                            Image(systemName: "speaker.wave.3.fill")
                        }
                        Text("Menu and gameplay loops are independent from Sound Effects.")
                            .font(palette.appFont(size: 12, weight: .medium, relativeTo: .caption))
                            .foregroundStyle(Color(hex: palette.muted))
                    }

                    if ads.isPrivacyChoicesVisible {
                        settingCard(title: "Privacy", systemImage: "hand.raised.fill") {
                            Button {
                                Task { await ads.presentPrivacyChoices() }
                            } label: {
                                HStack(spacing: 12) {
                                    Text("Privacy choices")
                                    Spacer()
                                    if ads.isPresentingPrivacyOptions {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .accessibilityIdentifier(
                                                "privacy-choices-disclosure"
                                            )
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .buttonStyle(
                                WebSecondaryButtonStyle(
                                    theme: palette,
                                    accent: Color(hex: palette.chromeAccent),
                                    minimumHeight: 44
                                )
                            )
                            .disabled(ads.isPresentingPrivacyOptions)
                            .accessibilityLabel("Privacy choices")
                            .accessibilityHint("Opens Google's privacy choices form")
                            .accessibilityIdentifier("privacy-choices")

                            if let status = ads.statusMessage {
                                Text(status)
                                    .font(
                                        palette.appFont(
                                            size: 12,
                                            weight: .semibold,
                                            relativeTo: .caption
                                        )
                                    )
                                    .foregroundStyle(.orange)
                                    .accessibilityIdentifier("privacy-choices-status")
                            }
                        }
                    }

                    if let appleAgeDescription = ads.appleAgeDescription {
                        settingCard(title: "Apple age range", systemImage: "person.crop.circle") {
                            Text("Apple age range: \(appleAgeDescription)")
                                .accessibilityIdentifier("settings-apple-age-range")
                            Text(
                                ads.appleParentalControls
                                    ? "Parental controls apply. You cannot change this age range in PimPoPom. Ask your parent or guardian to review your Apple Account settings."
                                    : "Apple supplies this age range. To correct it, review your Apple Account settings. It cannot be edited in PimPoPom."
                            )
                            .font(palette.appFont(size: 12, weight: .medium, relativeTo: .caption))
                            .foregroundStyle(Color(hex: palette.muted))
                        }
                    }

                    settingCard(title: "Support & Legal", systemImage: "doc.text.fill") {
                        legalLink("Privacy Policy", page: "privacy")
                        legalLink("Terms of Use", page: "terms")
                        legalLink("Refunds", page: "refunds")
                        legalLink("Support", page: "support")
                    }

                    if let status = audio.statusMessage {
                        Text(status)
                            .font(palette.appFont(size: 13, weight: .bold, relativeTo: .footnote))
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .webCardStyle(theme: palette, padding: 14)
                    }
                }
                .padding(16)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $tutorialMode) { mode in
            HowToPlayReplayView(mode: mode)
        }
        .onAppear { appIcons.refresh() }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .font(palette.appFont(size: 19, weight: .black, relativeTo: .headline))
                    .foregroundStyle(Color(hex: palette.foreground))
            }
        }
    }

    private func legalLink(_ title: String, page: String) -> some View {
        Link(destination: URL(string: "https://www.otcsoft.com/pimpopom-legal/\(page).html")!) {
            HStack(spacing: 12) {
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
        }
        .buttonStyle(WebSecondaryButtonStyle(theme: palette, minimumHeight: 44))
        .accessibilityHint("Opens \(title) on otcsoft.com")
        .accessibilityIdentifier("settings-legal-\(page)")
    }

    private func iconChoiceButton(_ choice: AppIconChoice) -> some View {
        let isSelected = appIcons.selectedChoice == choice

        return Button {
            Task { await appIcons.select(choice) }
        } label: {
            VStack(spacing: 8) {
                Image(choice.previewAssetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.34), lineWidth: 1)
                    }

                HStack(spacing: 5) {
                    Text(choice.title)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                }
                .font(palette.appFont(size: 14, weight: .black, relativeTo: .subheadline))
                .foregroundStyle(
                    isSelected
                        ? Color(hex: palette.chromeAccent)
                        : Color(hex: palette.foreground)
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(hex: palette.surface).opacity(isSelected ? 0.96 : 0.62))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected
                            ? Color(hex: palette.chromeAccent)
                            : Color(hex: palette.foreground).opacity(0.22),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(appIcons.isChanging || !appIcons.supportsAlternateIcons)
        .accessibilityLabel("\(choice.title) app icon")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityIdentifier("app-icon-\(choice.rawValue)")
    }

    private func settingCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(palette.appFont(size: 18, weight: .black, relativeTo: .headline))
                .foregroundStyle(Color(hex: palette.foreground))
            content()
                .font(palette.appFont(size: 16, weight: .semibold, relativeTo: .body))
                .foregroundStyle(Color(hex: palette.foreground))
        }
        .webCardStyle(theme: palette, padding: 16)
    }
}
