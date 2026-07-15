import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var audio: AudioController
    @EnvironmentObject private var cosmetics: CosmeticsController
    @EnvironmentObject private var preferences: AppPreferences

    private var palette: ThemePalette { cosmetics.theme }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: palette)

            Form {
                Section("Sound Effects") {
                    Toggle("Sound Effects", isOn: $preferences.soundEffectsEnabled)
                        .accessibilityIdentifier("sound-effects-toggle")
                    HStack {
                        Image(systemName: "speaker.fill")
                        Slider(value: $preferences.soundEffectsVolume, in: 0...1)
                            .disabled(!preferences.soundEffectsEnabled)
                        Image(systemName: "speaker.wave.3.fill")
                    }
                    Button("Test tap sound") { audio.playTap(hitNumber: 1) }
                        .disabled(!preferences.soundEffectsEnabled)
                }

                Section("Music") {
                    Toggle("Music", isOn: $preferences.musicEnabled)
                        .accessibilityIdentifier("music-toggle")
                    HStack {
                        Image(systemName: "speaker.fill")
                        Slider(value: $preferences.musicVolume, in: 0...1)
                            .disabled(!preferences.musicEnabled)
                        Image(systemName: "speaker.wave.3.fill")
                    }
                    Text("Menu and gameplay loops are independent from Sound Effects and follow the selected theme.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Current Theme") {
                    HStack {
                        ThemePreview(theme: palette).frame(width: 74)
                        Text(palette.displayName).font(.headline)
                    }
                }

                if let status = audio.statusMessage {
                    Section("Audio Status") {
                        Text(status).foregroundStyle(.orange)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
