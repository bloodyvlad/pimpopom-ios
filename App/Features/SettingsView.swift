import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var audio: AudioController
    @EnvironmentObject private var cosmetics: CosmeticsController
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var appIcons: AppIconController

    private var palette: ThemePalette { cosmetics.theme }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: palette)

            ScrollView {
                VStack(spacing: 12) {
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
        .onAppear { appIcons.refresh() }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .font(palette.appFont(size: 19, weight: .black, relativeTo: .headline))
                    .foregroundStyle(Color(hex: palette.foreground))
            }
        }
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
