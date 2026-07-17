import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var audio: AudioController
    @EnvironmentObject private var cosmetics: CosmeticsController
    @EnvironmentObject private var preferences: AppPreferences

    private var palette: ThemePalette { cosmetics.theme }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: palette)

            ScrollView {
                VStack(spacing: 12) {
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
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .font(palette.appFont(size: 19, weight: .black, relativeTo: .headline))
                    .foregroundStyle(Color(hex: palette.foreground))
            }
        }
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
