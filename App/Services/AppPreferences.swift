import Combine
import Foundation

@MainActor
final class AppPreferences: ObservableObject {
    private enum Key {
        static let soundEffectsEnabled = "audio.sound-effects.enabled"
        static let soundEffectsVolume = "audio.sound-effects.volume"
        static let musicEnabled = "audio.music.enabled"
        static let musicVolume = "audio.music.volume"
        static let selectedThemeID = "cosmetics.local-theme-id"
        static let glyphsEnabled = "appearance.glyphs.enabled"
    }

    @Published var soundEffectsEnabled: Bool {
        didSet { defaults.set(soundEffectsEnabled, forKey: Key.soundEffectsEnabled) }
    }

    @Published var soundEffectsVolume: Double {
        didSet { defaults.set(soundEffectsVolume, forKey: Key.soundEffectsVolume) }
    }

    @Published var musicEnabled: Bool {
        didSet { defaults.set(musicEnabled, forKey: Key.musicEnabled) }
    }

    @Published var musicVolume: Double {
        didSet { defaults.set(musicVolume, forKey: Key.musicVolume) }
    }

    @Published var selectedThemeID: String {
        didSet { defaults.set(selectedThemeID, forKey: Key.selectedThemeID) }
    }

    @Published var glyphsEnabled: Bool {
        didSet { defaults.set(glyphsEnabled, forKey: Key.glyphsEnabled) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        soundEffectsEnabled = defaults.object(forKey: Key.soundEffectsEnabled) as? Bool ?? true
        soundEffectsVolume = Self.clamp(defaults.object(forKey: Key.soundEffectsVolume) as? Double ?? 1)
        musicEnabled = defaults.object(forKey: Key.musicEnabled) as? Bool ?? true
        musicVolume = Self.clamp(defaults.object(forKey: Key.musicVolume) as? Double ?? 1)
        selectedThemeID = defaults.string(forKey: Key.selectedThemeID) ?? "classic"
        glyphsEnabled = defaults.object(forKey: Key.glyphsEnabled) as? Bool ?? true
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
