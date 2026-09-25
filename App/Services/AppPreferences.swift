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
        static let skipArcadeTutorial = "tutorial.arcade.skip-next-time"
        static let skipMultiplayerTutorial = "tutorial.multiplayer.skip-next-time"
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

    @Published var skipArcadeTutorial: Bool {
        didSet { defaults.set(skipArcadeTutorial, forKey: Key.skipArcadeTutorial) }
    }

    @Published var skipMultiplayerTutorial: Bool {
        didSet { defaults.set(skipMultiplayerTutorial, forKey: Key.skipMultiplayerTutorial) }
    }

    func skipsTutorial(for mode: HowToPlayMode) -> Bool {
        mode == .arcade ? skipArcadeTutorial : skipMultiplayerTutorial
    }

    func setSkipsTutorial(_ value: Bool, for mode: HowToPlayMode) {
        if mode == .arcade { skipArcadeTutorial = value } else { skipMultiplayerTutorial = value }
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
        skipArcadeTutorial = defaults.object(forKey: Key.skipArcadeTutorial) as? Bool ?? false
        skipMultiplayerTutorial = defaults.object(forKey: Key.skipMultiplayerTutorial) as? Bool ?? false
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
