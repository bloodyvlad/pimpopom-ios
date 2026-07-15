import AVFoundation
import Combine
import Foundation

enum MusicContext: Equatable, Sendable {
    case menu
    case gameplay
    case silent
}

struct AudioTaskGenerations: Equatable, Sendable {
    private(set) var load = 0
    private(set) var transition = 0

    mutating func beginLoad() -> Int {
        load += 1
        return load
    }

    mutating func beginTransition() -> Int {
        transition += 1
        return transition
    }

    mutating func invalidateLoad() {
        load += 1
    }

    mutating func invalidateTransition() {
        transition += 1
    }
}

struct ThemeAudioManifest: Equatable, Sendable {
    let themeID: String
    let menuFile: String
    let gameplayFile: String
    let toneBankFile: String

    static func resolve(_ themeID: String) -> ThemeAudioManifest {
        manifests[themeID] ?? manifests["classic"]!
    }

    private static let manifests: [String: ThemeAudioManifest] = [
        "classic": ThemeAudioManifest(
            themeID: "classic",
            menuFile: "audio-classic-menu.m4a",
            gameplayFile: "audio-classic-run.m4a",
            toneBankFile: "audio-classic-tones.wav"
        ),
        "disco": ThemeAudioManifest(
            themeID: "disco",
            menuFile: "audio-disco-menu.m4a",
            gameplayFile: "audio-disco-run.m4a",
            toneBankFile: "audio-disco-tones.wav"
        ),
        "light": ThemeAudioManifest(
            themeID: "light",
            menuFile: "audio-light-menu.m4a",
            gameplayFile: "audio-light-run.m4a",
            toneBankFile: "audio-light-tones.wav"
        ),
        "pixel": ThemeAudioManifest(
            themeID: "pixel",
            menuFile: "audio-pixel-menu.m4a",
            gameplayFile: "audio-pixel-run.m4a",
            toneBankFile: "audio-pixel-tones.wav"
        ),
    ]
}

@MainActor
final class AudioController: NSObject, ObservableObject {
    @Published private(set) var statusMessage: String?

    private static let soundBaseGain = 0.375
    private static let musicBaseGain = 0.42

    private var soundEffectsEnabled = true
    private var soundEffectsVolume = 1.0
    private var musicEnabled = true
    private var musicVolume = 1.0
    private var selectedThemeID = "classic"
    private var pendingThemeID: String?
    private var requestedMusicContext = MusicContext.menu
    private var applicationIsActive = false
    private var audioSessionIsInterrupted = false
    private var outputRequiresUserResume = false
    private var hasConfiguration = false

    private var engine: AVAudioEngine?
    private var soundMixer: AVAudioMixerNode?
    private var musicMixer: AVAudioMixerNode?
    private var tapVoices: [TapVoice] = []
    private var lossNode: AVAudioPlayerNode?
    private var launchNode: AVAudioPlayerNode?
    private var lossBusyUntil = 0.0
    private var musicNode: AVAudioPlayerNode?

    private var soundSuite: DecodedSoundSuite?
    private var sharedSoundEffects: DecodedSharedSoundEffects?
    private var musicSuite: DecodedMusicSuite?
    private var playingMusicThemeID: String?
    private var playingMusicContext: MusicContext?

    private var soundLoadTask: Task<Void, Never>?
    private var musicLoadTask: Task<Void, Never>?
    private var soundLoadingThemeID: String?
    private var musicLoadingThemeID: String?
    private var musicTransitionTask: Task<Void, Never>?
    private var soundVolumeTask: Task<Void, Never>?
    private var launchFadeTask: Task<Void, Never>?
    private var soundGeneration = 0
    private var musicGenerations = AudioTaskGenerations()
    private var hasRequestedLaunchSting = false
    private var launchStingAwaitingActivation = false
    private var launchStingDeadline: TimeInterval?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func configure(themeID: String, preferences: AppPreferences) {
        let normalizedThemeID = ThemeAudioManifest.resolve(themeID).themeID
        let themeChanged: Bool
        if requestedMusicContext == .menu {
            themeChanged = normalizedThemeID != selectedThemeID
            selectedThemeID = normalizedThemeID
            pendingThemeID = nil
        } else {
            themeChanged = false
            pendingThemeID = normalizedThemeID == selectedThemeID ? nil : normalizedThemeID
        }
        let soundWasEnabled = soundEffectsEnabled
        let musicWasEnabled = musicEnabled

        soundEffectsEnabled = preferences.soundEffectsEnabled
        soundEffectsVolume = preferences.soundEffectsVolume
        musicEnabled = preferences.musicEnabled
        musicVolume = preferences.musicVolume
        hasConfiguration = true

        if !soundEffectsEnabled, !musicEnabled {
            tearDownAudio()
            return
        }

        guard applicationIsActive else {
            if !soundEffectsEnabled { disableSoundEffects() }
            if !musicEnabled { disableMusic() }
            return
        }

        _ = ensureEngineRunning()

        if soundEffectsEnabled {
            if themeChanged || !soundWasEnabled || soundSuite?.themeID != selectedThemeID {
                loadSoundSuite()
            }
            rampSoundVolume()
        } else {
            disableSoundEffects()
        }

        if musicEnabled {
            if themeChanged || !musicWasEnabled || musicSuite?.themeID != selectedThemeID {
                loadMusicSuite()
            } else {
                transitionToRequestedMusicIfReady()
            }
        } else {
            disableMusic()
        }
    }

    func setMusicContext(_ context: MusicContext) {
        if context != .menu { cancelLaunchStingForGameplay() }
        guard requestedMusicContext != context else { return }
        requestedMusicContext = context
        if context == .menu { applyPendingThemeIfNeeded() }
        transitionToRequestedMusicIfReady()
    }

    func playLaunchSting() {
        guard !hasRequestedLaunchSting else { return }
        hasRequestedLaunchSting = true
        guard soundEffectsEnabled, requestedMusicContext == .menu else { return }
        guard applicationIsActive else {
            launchStingAwaitingActivation = true
            return
        }
        launchStingDeadline = ProcessInfo.processInfo.systemUptime + 1
        playLaunchStingIfReady()
    }

    func playTap(hitNumber: Int) {
        resumeAfterUserAction()
        guard soundEffectsEnabled,
            applicationIsActive,
            hitNumber > 0,
            let soundSuite,
            soundSuite.themeID == selectedThemeID,
            ensureEngineRunning()
        else { return }

        let now = ProcessInfo.processInfo.systemUptime
        guard let voice = tapVoices.min(by: { $0.busyUntil < $1.busyUntil }),
            voice.busyUntil <= now
        else {
            // A third overlapping note is skipped instead of being played late
            // or cutting a non-zero waveform.
            return
        }

        let slot = (hitNumber - 1) % soundSuite.tones.count
        voice.node.stop()
        voice.node.scheduleBuffer(
            soundSuite.tones[slot],
            at: nil,
            options: [],
            completionHandler: nil
        )
        voice.node.play()
        voice.busyUntil = now + 0.42
    }

    func playLifeLoss() {
        guard soundEffectsEnabled,
            applicationIsActive,
            let loss = sharedSoundEffects?.loss,
            let lossNode,
            ensureEngineRunning()
        else { return }

        let now = ProcessInfo.processInfo.systemUptime
        guard lossBusyUntil <= now else { return }
        lossNode.stop()
        lossNode.scheduleBuffer(loss, at: nil, options: [], completionHandler: nil)
        lossNode.play()
        lossBusyUntil = now + 0.62
    }

    func resumeAfterUserAction() {
        guard outputRequiresUserResume,
            !audioSessionIsInterrupted,
            applicationIsActive,
            hasConfiguration
        else { return }
        outputRequiresUserResume = false
        if soundEffectsEnabled || musicEnabled {
            _ = ensureEngineRunning()
        }
        if soundEffectsEnabled, soundSuite?.themeID != selectedThemeID {
            loadSoundSuite()
        }
        if musicEnabled, musicSuite?.themeID != selectedThemeID {
            loadMusicSuite()
        } else {
            transitionToRequestedMusicIfReady(forceRestart: true)
        }
    }

    func setApplicationActive(_ active: Bool) {
        applicationIsActive = active
        guard hasConfiguration else { return }
        if active {
            if soundEffectsEnabled || musicEnabled {
                _ = ensureEngineRunning()
            }
            if soundEffectsEnabled, soundSuite?.themeID != selectedThemeID {
                loadSoundSuite()
            }
            if musicEnabled, musicSuite?.themeID != selectedThemeID {
                loadMusicSuite()
            } else {
                transitionToRequestedMusicIfReady()
            }
            if launchStingAwaitingActivation {
                launchStingAwaitingActivation = false
                if requestedMusicContext == .menu {
                    launchStingDeadline = ProcessInfo.processInfo.systemUptime + 1
                }
            }
            playLaunchStingIfReady()
        } else {
            stopOutputImmediately()
        }
    }

    private func loadSoundSuite() {
        guard soundLoadingThemeID != selectedThemeID else { return }
        soundGeneration += 1
        let generation = soundGeneration
        soundLoadTask?.cancel()
        soundLoadingThemeID = selectedThemeID
        soundSuite = nil
        for voice in tapVoices {
            voice.node.stop()
            voice.busyUntil = 0
        }
        lossNode?.stop()
        lossBusyUntil = 0
        let manifest = ThemeAudioManifest.resolve(selectedThemeID)
        let reusableSharedEffects = sharedSoundEffects

        soundLoadTask = Task { [weak self] in
            let loaded = await Task.detached(priority: .utility) {
                try? DecodedSoundSuite.load(
                    manifest: manifest,
                    sharedEffects: reusableSharedEffects
                )
            }.value
            guard let self, generation == soundGeneration else { return }
            soundLoadingThemeID = nil
            guard !Task.isCancelled,
                soundEffectsEnabled,
                selectedThemeID == manifest.themeID
            else { return }
            soundSuite = loaded
            sharedSoundEffects = loaded?.sharedEffects
            statusMessage = loaded == nil ? "Sound effects could not be prepared." : nil
            playLaunchStingIfReady()
        }
    }

    private func loadMusicSuite() {
        guard musicLoadingThemeID != selectedThemeID else { return }
        let generation = musicGenerations.beginLoad()
        musicLoadTask?.cancel()
        musicLoadingThemeID = selectedThemeID
        let manifest = ThemeAudioManifest.resolve(selectedThemeID)

        musicLoadTask = Task { [weak self] in
            let loaded = await Task.detached(priority: .utility) {
                try? DecodedMusicSuite.load(manifest: manifest)
            }.value
            guard let self, generation == musicGenerations.load else { return }
            musicLoadingThemeID = nil
            guard !Task.isCancelled,
                musicEnabled,
                selectedThemeID == manifest.themeID
            else { return }
            guard let loaded else {
                statusMessage = "Music could not be prepared."
                return
            }
            musicSuite = loaded
            statusMessage = nil
            transitionToRequestedMusicIfReady(forceRestart: true)
        }
    }

    private func transitionToRequestedMusicIfReady(forceRestart: Bool = false) {
        guard musicEnabled, applicationIsActive else { return }
        guard requestedMusicContext != .silent else {
            fadeOutAndStopMusic()
            return
        }
        guard let musicSuite,
            musicSuite.themeID == selectedThemeID,
            ensureEngineRunning(),
            let musicNode,
            let musicMixer
        else { return }

        if !forceRestart,
            playingMusicThemeID == selectedThemeID,
            playingMusicContext == requestedMusicContext,
            musicNode.isPlaying
        {
            rampMusicVolume(to: targetMusicGain, durationMilliseconds: 25)
            return
        }

        let buffer = requestedMusicContext == .menu ? musicSuite.menu : musicSuite.gameplay
        let generation = musicGenerations.beginTransition()
        musicTransitionTask?.cancel()
        musicTransitionTask = Task { [weak self] in
            guard let self else { return }
            if musicNode.isPlaying {
                await rampMusicVolumeAsync(to: 0, durationMilliseconds: 80)
            }
            guard !Task.isCancelled,
                generation == musicGenerations.transition,
                musicEnabled,
                applicationIsActive,
                requestedMusicContext != .silent
            else { return }
            musicNode.stop()
            scheduleLoop(buffer, on: musicNode)
            musicMixer.outputVolume = 0
            musicNode.play()
            playingMusicThemeID = selectedThemeID
            playingMusicContext = requestedMusicContext
            await rampMusicVolumeAsync(to: targetMusicGain, durationMilliseconds: 120)
        }
    }

    private func fadeOutAndStopMusic() {
        let generation = musicGenerations.beginTransition()
        musicTransitionTask?.cancel()
        musicTransitionTask = Task { [weak self] in
            guard let self else { return }
            await rampMusicVolumeAsync(to: 0, durationMilliseconds: 80)
            guard !Task.isCancelled, generation == musicGenerations.transition else { return }
            musicNode?.stop()
            playingMusicContext = nil
            playingMusicThemeID = nil
        }
    }

    private func scheduleLoop(_ buffer: AVAudioPCMBuffer, on node: AVAudioPlayerNode) {
        node.scheduleBuffer(
            buffer,
            at: nil,
            options: [.loops],
            completionHandler: nil
        )
    }

    private func disableSoundEffects() {
        soundGeneration += 1
        soundLoadTask?.cancel()
        soundLoadTask = nil
        soundVolumeTask?.cancel()
        soundVolumeTask = nil
        soundLoadingThemeID = nil
        soundSuite = nil
        sharedSoundEffects = nil
        launchStingAwaitingActivation = false
        launchStingDeadline = nil
        launchFadeTask?.cancel()
        launchFadeTask = nil
        for voice in tapVoices {
            voice.node.stop()
            voice.busyUntil = 0
        }
        lossNode?.stop()
        launchNode?.stop()
        lossBusyUntil = 0
        soundMixer?.outputVolume = 0
    }

    private func disableMusic() {
        musicGenerations.invalidateLoad()
        musicGenerations.invalidateTransition()
        musicLoadTask?.cancel()
        musicLoadTask = nil
        musicLoadingThemeID = nil
        musicSuite = nil
        musicTransitionTask?.cancel()
        musicTransitionTask = nil
        musicNode?.stop()
        musicMixer?.outputVolume = 0
        playingMusicContext = nil
        playingMusicThemeID = nil
    }

    private func ensureEngineRunning() -> Bool {
        guard applicationIsActive,
            !audioSessionIsInterrupted,
            !outputRequiresUserResume
        else { return false }
        do {
            if engine == nil { createEngine() }
            guard let engine else { return false }
            if !engine.isRunning {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
                try engine.start()
            }
            return true
        } catch {
            statusMessage = "Audio output is unavailable."
            return false
        }
    }

    private func createEngine() {
        let engine = AVAudioEngine()
        let soundMixer = AVAudioMixerNode()
        let musicMixer = AVAudioMixerNode()
        let musicNode = AVAudioPlayerNode()
        let lossNode = AVAudioPlayerNode()
        let launchNode = AVAudioPlayerNode()
        let tapVoices = [TapVoice(), TapVoice()]
        guard
            let monoFormat = AVAudioFormat(
                standardFormatWithSampleRate: 48_000,
                channels: 1
            ),
            let stereoFormat = AVAudioFormat(
                standardFormatWithSampleRate: 48_000,
                channels: 2
            )
        else {
            statusMessage = "Audio output is unavailable."
            return
        }

        engine.attach(soundMixer)
        engine.attach(musicMixer)
        engine.attach(musicNode)
        engine.attach(lossNode)
        engine.attach(launchNode)
        for voice in tapVoices { engine.attach(voice.node) }

        engine.connect(soundMixer, to: engine.mainMixerNode, format: nil)
        engine.connect(musicMixer, to: engine.mainMixerNode, format: nil)
        engine.connect(musicNode, to: musicMixer, format: stereoFormat)
        engine.connect(lossNode, to: soundMixer, format: monoFormat)
        engine.connect(launchNode, to: soundMixer, format: monoFormat)
        for voice in tapVoices {
            engine.connect(voice.node, to: soundMixer, format: monoFormat)
        }

        soundMixer.outputVolume = Float(Self.soundBaseGain * soundEffectsVolume)
        musicMixer.outputVolume = 0
        engine.prepare()

        self.engine = engine
        self.soundMixer = soundMixer
        self.musicMixer = musicMixer
        self.musicNode = musicNode
        self.lossNode = lossNode
        self.launchNode = launchNode
        self.tapVoices = tapVoices
    }

    private func rampSoundVolume() {
        guard let soundMixer else { return }
        soundVolumeTask?.cancel()
        let target = Float(Self.soundBaseGain * soundEffectsVolume)
        let start = soundMixer.outputVolume
        soundVolumeTask = Task {
            for step in 1...5 {
                guard !Task.isCancelled else { return }
                soundMixer.outputVolume = start + (target - start) * Float(step) / 5
                try? await Task.sleep(for: .milliseconds(5))
            }
        }
    }

    private func playLaunchStingIfReady() {
        guard let deadline = launchStingDeadline else { return }
        guard ProcessInfo.processInfo.systemUptime <= deadline else {
            launchStingDeadline = nil
            return
        }
        guard soundEffectsEnabled,
            applicationIsActive,
            requestedMusicContext == .menu,
            let launchSting = sharedSoundEffects?.launchSting,
            let launchNode,
            ensureEngineRunning()
        else { return }

        launchFadeTask?.cancel()
        launchNode.volume = 1
        launchNode.stop()
        launchNode.scheduleBuffer(
            launchSting,
            at: nil,
            options: [],
            completionHandler: nil
        )
        launchNode.play()
        launchStingDeadline = nil
    }

    private func cancelLaunchStingForGameplay() {
        launchStingAwaitingActivation = false
        launchStingDeadline = nil
        guard let launchNode, launchNode.isPlaying else { return }
        launchFadeTask?.cancel()
        let startVolume = launchNode.volume
        launchFadeTask = Task { [weak self] in
            for step in 1...4 {
                guard !Task.isCancelled else { return }
                launchNode.volume = startVolume * (1 - Float(step) / 4)
                try? await Task.sleep(for: .milliseconds(3))
            }
            guard !Task.isCancelled else { return }
            launchNode.stop()
            launchNode.volume = 1
            self?.launchFadeTask = nil
        }
    }

    private func applyPendingThemeIfNeeded() {
        guard let pendingThemeID, pendingThemeID != selectedThemeID else {
            self.pendingThemeID = nil
            return
        }
        selectedThemeID = pendingThemeID
        self.pendingThemeID = nil
        if soundEffectsEnabled, applicationIsActive { loadSoundSuite() }
        if musicEnabled, applicationIsActive { loadMusicSuite() }
    }

    private var targetMusicGain: Float {
        Float(Self.musicBaseGain * musicVolume)
    }

    private func rampMusicVolume(to target: Float, durationMilliseconds: Int) {
        musicTransitionTask?.cancel()
        musicTransitionTask = Task { [weak self] in
            await self?.rampMusicVolumeAsync(to: target, durationMilliseconds: durationMilliseconds)
        }
    }

    private func rampMusicVolumeAsync(to target: Float, durationMilliseconds: Int) async {
        guard let musicMixer else { return }
        let steps = max(1, min(12, durationMilliseconds / 10))
        let start = musicMixer.outputVolume
        for step in 1...steps {
            guard !Task.isCancelled else { return }
            musicMixer.outputVolume = start + (target - start) * Float(step) / Float(steps)
            try? await Task.sleep(for: .milliseconds(durationMilliseconds / steps))
        }
    }

    private func stopOutputImmediately() {
        musicGenerations.invalidateTransition()
        musicTransitionTask?.cancel()
        musicNode?.stop()
        for voice in tapVoices {
            voice.node.stop()
            voice.busyUntil = 0
        }
        lossNode?.stop()
        launchNode?.stop()
        launchFadeTask?.cancel()
        launchFadeTask = nil
        lossBusyUntil = 0
        playingMusicContext = nil
        playingMusicThemeID = nil
        engine?.pause()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func tearDownAudio() {
        disableSoundEffects()
        disableMusic()
        engine?.stop()
        engine = nil
        soundMixer = nil
        musicMixer = nil
        musicNode = nil
        lossNode = nil
        launchNode = nil
        tapVoices = []
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    @objc nonisolated private func handleInterruption(_ notification: Notification) {
        guard let typeRawValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
        else { return }
        let optionsRawValue =
            notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        Task { @MainActor [weak self] in
            self?.processInterruption(
                typeRawValue: typeRawValue,
                optionsRawValue: optionsRawValue
            )
        }
    }

    @objc nonisolated private func handleRouteChange(_ notification: Notification) {
        guard let reasonRawValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
        else { return }
        Task { @MainActor [weak self] in
            self?.processRouteChange(reasonRawValue: reasonRawValue)
        }
    }

    private func processInterruption(typeRawValue: UInt, optionsRawValue: UInt) {
        guard let type = AVAudioSession.InterruptionType(rawValue: typeRawValue) else { return }
        if type == .began {
            audioSessionIsInterrupted = true
            stopOutputImmediately()
            return
        }

        audioSessionIsInterrupted = false
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsRawValue)
        guard options.contains(.shouldResume), applicationIsActive else {
            outputRequiresUserResume = true
            return
        }
        outputRequiresUserResume = false
        if soundEffectsEnabled || musicEnabled {
            _ = ensureEngineRunning()
        }
        if soundEffectsEnabled, soundSuite?.themeID != selectedThemeID {
            loadSoundSuite()
        }
        if musicEnabled, musicSuite?.themeID != selectedThemeID {
            loadMusicSuite()
        } else {
            transitionToRequestedMusicIfReady(forceRestart: true)
        }
    }

    private func processRouteChange(reasonRawValue: UInt) {
        guard let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRawValue),
            reason == .oldDeviceUnavailable
        else { return }
        outputRequiresUserResume = true
        stopOutputImmediately()
    }
}

@MainActor
private final class TapVoice {
    let node = AVAudioPlayerNode()
    var busyUntil = 0.0
}

private final class DecodedSoundSuite: @unchecked Sendable {
    let themeID: String
    let tones: [AVAudioPCMBuffer]
    let sharedEffects: DecodedSharedSoundEffects

    init(
        themeID: String,
        tones: [AVAudioPCMBuffer],
        sharedEffects: DecodedSharedSoundEffects
    ) {
        self.themeID = themeID
        self.tones = tones
        self.sharedEffects = sharedEffects
    }

    static func load(
        manifest: ThemeAudioManifest,
        sharedEffects: DecodedSharedSoundEffects?
    ) throws -> DecodedSoundSuite {
        let bank = try AudioDecoding.buffer(named: manifest.toneBankFile)
        let tones = try AudioDecoding.split(bank: bank, slots: 16, slotDuration: 0.5)
        let resolvedSharedEffects = try sharedEffects ?? DecodedSharedSoundEffects.load()
        return DecodedSoundSuite(
            themeID: manifest.themeID,
            tones: tones,
            sharedEffects: resolvedSharedEffects
        )
    }
}

private final class DecodedSharedSoundEffects: @unchecked Sendable {
    let loss: AVAudioPCMBuffer
    let launchSting: AVAudioPCMBuffer

    init(loss: AVAudioPCMBuffer, launchSting: AVAudioPCMBuffer) {
        self.loss = loss
        self.launchSting = launchSting
    }

    static func load() throws -> DecodedSharedSoundEffects {
        try DecodedSharedSoundEffects(
            loss: AudioDecoding.buffer(named: "audio-oops.wav"),
            launchSting: AudioDecoding.buffer(named: "audio-pimpopom-sting.wav")
        )
    }
}

private final class DecodedMusicSuite: @unchecked Sendable {
    let themeID: String
    let menu: AVAudioPCMBuffer
    let gameplay: AVAudioPCMBuffer

    init(themeID: String, menu: AVAudioPCMBuffer, gameplay: AVAudioPCMBuffer) {
        self.themeID = themeID
        self.menu = menu
        self.gameplay = gameplay
    }

    static func load(manifest: ThemeAudioManifest) throws -> DecodedMusicSuite {
        DecodedMusicSuite(
            themeID: manifest.themeID,
            menu: try AudioDecoding.buffer(named: manifest.menuFile),
            gameplay: try AudioDecoding.buffer(named: manifest.gameplayFile)
        )
    }
}

private enum AudioDecoding {
    enum Error: Swift.Error {
        case missingResource(String)
        case invalidAudio(String)
    }

    static func buffer(named fileName: String) throws -> AVAudioPCMBuffer {
        let path = fileName as NSString
        let name = path.deletingPathExtension
        let fileExtension = path.pathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else {
            throw Error.missingResource(fileName)
        }
        let file = try AVAudioFile(forReading: url)
        guard file.length > 0,
            file.length <= Int64(UInt32.max),
            let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            )
        else {
            throw Error.invalidAudio(fileName)
        }
        try file.read(into: buffer)
        return buffer
    }

    static func split(
        bank: AVAudioPCMBuffer,
        slots: Int,
        slotDuration: Double
    ) throws -> [AVAudioPCMBuffer] {
        let framesPerSlot = AVAudioFrameCount((bank.format.sampleRate * slotDuration).rounded())
        guard slots > 0,
            framesPerSlot > 0,
            bank.frameLength >= framesPerSlot * AVAudioFrameCount(slots),
            let sourceChannels = bank.floatChannelData
        else {
            throw Error.invalidAudio("tone bank")
        }

        return try (0..<slots).map { slot in
            guard
                let output = AVAudioPCMBuffer(
                    pcmFormat: bank.format,
                    frameCapacity: framesPerSlot
                ), let destinationChannels = output.floatChannelData
            else {
                throw Error.invalidAudio("tone bank slot")
            }
            let channelCount = Int(bank.format.channelCount)
            let offset = Int(framesPerSlot) * slot
            for channel in 0..<channelCount {
                destinationChannels[channel].update(
                    from: sourceChannels[channel].advanced(by: offset),
                    count: Int(framesPerSlot)
                )
            }
            output.frameLength = framesPerSlot
            return output
        }
    }
}
