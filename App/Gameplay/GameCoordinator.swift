import Combine
import Foundation
import PimPoPomCore

enum GameplaySoundEvent: Equatable, Sendable {
    case correctTap(hitNumber: Int)
    case lifeLoss
}

enum GameplayLifecycleEvent: Equatable, Sendable {
    case started
    case finished
    case abandoned
}

struct GameplayHitFeedbackEvent: Equatable, Identifiable, Sendable {
    let id: Int
    let rating: SpeedRating
    let milliseconds: Int
    let pointsAwarded: Int
    let normalizedLocation: CGPoint
}

enum GameplayMusicRouting {
    static func context(for event: GameplayLifecycleEvent) -> MusicContext {
        switch event {
        case .started:
            .gameplay
        case .finished, .abandoned:
            .silent
        }
    }
}

enum GameplayMissPresentation {
    static func copy(for reason: String?) -> String {
        reason == "late" ? "Too slow" : "Missed"
    }
}

enum GameplayRatingFormatting {
    static func stamp(rating: SpeedRating, milliseconds: Int) -> String {
        "\(rating.label) - \(milliseconds)ms"
    }
}

@MainActor
final class GameCoordinator: ObservableObject {
    let mode: GameMode
    let scene: GameScene

    @Published private(set) var snapshot: GameSnapshot
    @Published private(set) var feedback = "Get ready"
    @Published private(set) var isFinished = false
    @Published private(set) var wasAbandoned = false
    @Published private(set) var isRoundPresentationExpired = false
    @Published private(set) var hitFeedbackEvent: GameplayHitFeedbackEvent?
    var onSoundEvent: ((GameplaySoundEvent) -> Void)?
    var onLifecycleEvent: ((GameplayLifecycleEvent) -> Void)?
    var onBoardTap: ((CGPoint) -> Void)?

    private let engine: GameEngine
    private var targetTask: Task<Void, Never>?
    private var decoyTask: Task<Void, Never>?
    private var pendingDeadlineCommit: PendingDeadlineCommit?
    private var lastDeadlineResolutionAt: Double?
    private var generation = 0
    private var lastPublishedAt = 0.0
    private var started = false
    private var hitFeedbackSequence = 0

    init(mode: GameMode) {
        self.mode = mode
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            let configuration =
                arguments.contains("--uitesting")
                ? GameConfiguration.standard.overridingComfortableResponseWindow(milliseconds: 5_000)
                : .standard
            let engine =
                arguments.contains("--deterministic-game")
                ? GameEngine(configuration: configuration, random: { 0 })
                : GameEngine(configuration: configuration)
        #else
            let engine = GameEngine()
        #endif
        self.engine = engine
        scene = GameScene()
        snapshot = engine.snapshot(now: 0)
        scene.eventDelegate = self
        scene.apply(snapshot)
    }

    deinit {
        targetTask?.cancel()
        decoyTask?.cancel()
    }

    func startIfNeeded() {
        guard !started else { return }
        startNewRun()
    }

    func applyTheme(_ themeID: String) {
        scene.applyTheme(themeID)
    }

    func applyGlyphsEnabled(_ enabled: Bool) {
        scene.applyGlyphsEnabled(enabled)
    }

    func startNewRun() {
        cancelScheduling()
        generation += 1
        started = true
        isFinished = false
        wasAbandoned = false
        pendingDeadlineCommit = nil
        lastDeadlineResolutionAt = nil
        feedback = "Get ready"
        hitFeedbackEvent = nil
        let now = monotonicMilliseconds()
        snapshot = engine.start(now: now, mode: mode)
        scene.apply(snapshot)
        onLifecycleEvent?(.started)
        scheduleTarget(from: now)
        scheduleDecoy(from: now)
    }

    func endZenRun() {
        guard mode == .zen else { return }
        handle(engine.endZenRun(now: monotonicMilliseconds()))
    }

    func abandonForBackground() {
        guard started, !isFinished, !wasAbandoned else { return }
        cancelScheduling()
        generation += 1
        engine.reset()
        snapshot = engine.snapshot(now: monotonicMilliseconds())
        scene.apply(snapshot)
        wasAbandoned = true
        feedback = "Run ended in background"
        onLifecycleEvent?(.abandoned)
    }

    func stop() {
        cancelScheduling()
    }

    func proofEvents() -> [[Int]] {
        engine.proofEvents()
    }

    private func scheduleTarget(from now: Double, retryDelayMilliseconds: Double = 0) {
        targetTask?.cancel()
        guard engine.state == .waiting else { return }
        let delay = engine.nextDelayMilliseconds(now: now) + retryDelayMilliseconds
        let scheduledGeneration = generation
        targetTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(Int64(max(0, ceil(delay)))))
            guard !Task.isCancelled,
                scheduledGeneration == generation,
                engine.state == .waiting
            else { return }
            targetTask = nil
            scene.queueRoundActivation()
        }
    }

    private func scheduleDecoy(from now: Double) {
        decoyTask?.cancel()
        guard let delay = engine.nextDecoyDelayMilliseconds(now: now) else { return }
        let scheduledGeneration = generation
        decoyTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(Int64(max(0, ceil(delay)))))
            guard !Task.isCancelled,
                scheduledGeneration == generation,
                engine.state != .idle,
                engine.state != .gameOver
            else { return }
            decoyTask = nil
            scene.queueDecoyActivation()
        }
    }

    private func handle(_ transition: GameTransition) {
        if transition.kind == .hit {
            onSoundEvent?(.correctTap(hitNumber: transition.snapshot.hits))
        } else if transition.kind == .miss, transition.lifeLost == true {
            onSoundEvent?(.lifeLoss)
        }
        snapshot = transition.snapshot
        scene.apply(snapshot)
        switch transition.kind {
        case .hit:
            setRoundPresentationExpired(false)
            if let rating = transition.speedRating {
                feedback = GameplayRatingFormatting.stamp(
                    rating: rating,
                    milliseconds: transition.displayedReactionMilliseconds ?? 0
                )
            } else {
                feedback = "Hit"
            }
        case .miss:
            setRoundPresentationExpired(false)
            feedback = GameplayMissPresentation.copy(for: transition.reason)
        case .decoysDodged:
            feedback = transition.dodgesAwarded == 1 ? "Decoy dodged" : "\(transition.dodgesAwarded) decoys dodged"
        case .roundActive:
            setRoundPresentationExpired(false)
            feedback = "Tap \(snapshot.playerColor.name) \(snapshot.playerColor.glyph)"
        case .zenEnded:
            setRoundPresentationExpired(false)
            feedback = "Zen complete"
        case .ignored, .decoyActive:
            break
        }

        if snapshot.state == .gameOver {
            cancelScheduling()
            if !isFinished {
                isFinished = true
                onLifecycleEvent?(.finished)
            }
        }
    }

    private func cancelScheduling() {
        targetTask?.cancel()
        decoyTask?.cancel()
        targetTask = nil
        decoyTask = nil
        pendingDeadlineCommit = nil
        scene.cancelQueuedActivations()
        setRoundPresentationExpired(false)
    }

    private func setRoundPresentationExpired(_ expired: Bool) {
        if isRoundPresentationExpired != expired {
            isRoundPresentationExpired = expired
        }
        scene.setRoundPresentationExpired(expired)
    }

    private func monotonicMilliseconds() -> Double {
        ProcessInfo.processInfo.systemUptime * 1_000
    }
}

extension GameCoordinator: GameSceneEventDelegate {
    func gameScene(_: GameScene, requestsRoundActivationAt milliseconds: Double) {
        let result = engine.activateRound(now: milliseconds)
        handle(result)
        if result.kind == .ignored, engine.state == .waiting {
            scheduleTarget(
                from: milliseconds,
                retryDelayMilliseconds: Double(engine.configuration.decoys.retryDelayMilliseconds)
            )
        }
    }

    func gameScene(_: GameScene, requestsDecoyActivationAt milliseconds: Double) {
        let result = engine.activateDecoy(now: milliseconds)
        handle(result)
        scheduleDecoy(from: milliseconds)
    }

    func gameScene(_: GameScene, didAdvanceTo milliseconds: Double) {
        if let expiry = engine.nextDecoyExpiryAt(), expiry <= milliseconds {
            let result = engine.expireDecoys(now: milliseconds)
            if result.kind != .ignored { handle(result) }
        }
        advanceDeadlineCommit(at: milliseconds)
        if milliseconds - lastPublishedAt >= 33,
            engine.state != .idle,
            engine.state != .gameOver
        {
            lastPublishedAt = milliseconds
            snapshot = engine.snapshot(now: milliseconds)
        }
    }

    func gameScene(_: GameScene, didPointAt normalizedLocation: CGPoint) {
        onBoardTap?(normalizedLocation)
    }

    func gameScene(
        _: GameScene,
        didTapCell index: Int,
        normalizedLocation: CGPoint,
        inputAt milliseconds: Double,
        handledAt: Double
    ) {
        var inputAt = InputTiming.resolveInputTimestamp(
            eventTimestampMilliseconds: milliseconds,
            currentTimeMilliseconds: handledAt
        )
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--uitesting"),
                let optionIndex = arguments.firstIndex(of: "--ui-test-reaction-ms"),
                arguments.indices.contains(optionIndex + 1),
                let forcedReaction = Double(arguments[optionIndex + 1]),
                let activeAt = engine.activeAt
            {
                inputAt = activeAt + max(0, forcedReaction)
            }
        #endif
        if let activeAt = engine.activeAt,
            InputTiming.predatesPresentation(
                inputAtMilliseconds: inputAt,
                visibleAtMilliseconds: activeAt
            )
        {
            return
        }
        if engine.state == .waiting,
            let lastDeadlineResolutionAt,
            InputTiming.wasCoveredByDeadlineResolution(
                inputAtMilliseconds: inputAt,
                resolvedAtMilliseconds: lastDeadlineResolutionAt
            )
        {
            return
        }

        let stateBeforeTap = engine.state
        let result = engine.tap(cellIndex: index, now: inputAt, resolvedAt: handledAt)
        guard result.kind != .ignored else { return }
        pendingDeadlineCommit = nil
        if result.kind == .miss, result.reason == "late" {
            lastDeadlineResolutionAt = handledAt
        }
        restartDecoyCadenceAfterLifeLossIfNeeded(result, at: handledAt)
        handle(result)

        if result.kind == .hit,
            let speedRating = result.speedRating,
            let milliseconds = result.displayedReactionMilliseconds,
            let pointsAwarded = result.pointsAwarded
        {
            hitFeedbackSequence += 1
            hitFeedbackEvent = GameplayHitFeedbackEvent(
                id: hitFeedbackSequence,
                rating: speedRating,
                milliseconds: milliseconds,
                pointsAwarded: pointsAwarded,
                normalizedLocation: normalizedLocation
            )
        }

        let pendingZenTarget = mode == .zen && stateBeforeTap == .waiting
        if engine.state == .waiting, !pendingZenTarget {
            scheduleTarget(from: handledAt)
        }
    }
}

extension GameCoordinator {
    fileprivate struct PendingDeadlineCommit {
        let generation: Int
        let activeAt: Double
        var framesRemaining: Int
    }

    fileprivate func advanceDeadlineCommit(at milliseconds: Double) {
        if var pending = pendingDeadlineCommit {
            guard pending.generation == generation,
                engine.state == .active,
                engine.activeAt == pending.activeAt
            else {
                pendingDeadlineCommit = nil
                setRoundPresentationExpired(false)
                return
            }
            if pending.framesRemaining > 1 {
                pending.framesRemaining -= 1
                pendingDeadlineCommit = pending
                return
            }

            pendingDeadlineCommit = nil
            let result = engine.expireRound(now: milliseconds)
            if result.kind == .miss {
                lastDeadlineResolutionAt = milliseconds
            } else {
                setRoundPresentationExpired(false)
            }
            restartDecoyCadenceAfterLifeLossIfNeeded(result, at: milliseconds)
            handle(result)
            if engine.state == .waiting {
                scheduleTarget(from: milliseconds)
            }
            return
        }

        guard engine.state == .active,
            engine.mode == .arcade,
            let activeAt = engine.activeAt,
            let difficulty = engine.roundDifficulty,
            milliseconds >= activeAt + Double(difficulty.responseWindowMilliseconds)
        else {
            return
        }
        pendingDeadlineCommit = PendingDeadlineCommit(
            generation: generation,
            activeAt: activeAt,
            framesRemaining: 2
        )
        setRoundPresentationExpired(true)
    }

    fileprivate func restartDecoyCadenceAfterLifeLossIfNeeded(
        _ transition: GameTransition,
        at milliseconds: Double
    ) {
        guard transition.kind == .miss, transition.lifeLost == true else { return }
        decoyTask?.cancel()
        decoyTask = nil
        if transition.snapshot.state != .gameOver {
            scheduleDecoy(from: milliseconds)
        }
    }
}
