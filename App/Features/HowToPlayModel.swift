import Foundation

enum HowToPlayMode: String, CaseIterable, Identifiable, Sendable {
    case arcade
    case multiplayer

    var id: String { rawValue }
    var title: String { self == .arcade ? "Arcade" : "Multiplayer" }
}

/// Copy follows enabled backend contracts; this type grants no eligibility or rewards.
struct HowToPlayCapabilities: Equatable, Sendable {
    var multiplayerCoinsPerAliveMinute = 0
    var multiplayerLeaderboardEnabled = false

    static let current = HowToPlayCapabilities(
        multiplayerCoinsPerAliveMinute: 2, multiplayerLeaderboardEnabled: true)
}

enum HowToPlayStep: Int, CaseIterable, Identifiable, Sendable {
    case yourColor, changingColor, speedBar, pickups, competition, rewards
    var id: Int { rawValue }
}

enum HowToPlayTile: Equatable, Sendable {
    case empty, target, otherColor, heart, clock
}

/// An untimed, value-only demonstration. It cannot create a run, match or reward.
struct HowToPlayPractice: Equatable, Sendable {
    let mode: HowToPlayMode
    let capabilities: HowToPlayCapabilities
    private(set) var step = HowToPlayStep.yourColor
    private(set) var interactions = 0
    private(set) var feedback: String?

    init(mode: HowToPlayMode, capabilities: HowToPlayCapabilities = .current) {
        self.mode = mode
        self.capabilities = capabilities
    }

    var gridDimension: Int {
        switch step {
        case .yourColor: 1
        case .changingColor, .speedBar: 2
        case .pickups, .competition, .rewards: 4
        }
    }
    var colorIndex: Int { step == .yourColor ? 0 : 2 }
    var targetCell: Int {
        switch step {
        case .yourColor: 0
        case .changingColor: 3
        case .speedBar: [0, 3, 1][min(interactions, 2)]
        default: 0
        }
    }
    var requiredInteractions: Int {
        switch step {
        case .yourColor, .changingColor: 1
        case .speedBar: 3
        case .pickups: mode == .arcade ? 2 : 1
        case .competition: mode == .multiplayer ? 1 : 0
        case .rewards: 0
        }
    }
    var canAdvance: Bool { interactions >= requiredInteractions }
    var isLastStep: Bool { step == .rewards }
    var speedProgress: Double {
        step == .speedBar ? Double(interactions) / 3 : (step.rawValue > 2 ? 1 : 0.2)
    }
    var multiplier: Int { speedProgress >= 1 ? 2 : 1 }
    var exampleScore: Int { 1_000 * interactions }

    var title: String {
        switch step {
        case .yourColor: "Follow your color"
        case .changingColor: "Your color can change"
        case .speedBar: "Fast taps build your multiplier"
        case .pickups: mode == .arcade ? "Hunt lives and slow-downs" : "Race for a life"
        case .competition: mode == .arcade ? "Climb the leaderboard" : "Watch the other players"
        case .rewards: "Make your survival count"
        }
    }
    var instruction: String {
        switch step {
        case .yourColor:
            "The highlighted HUD tells you which color is yours. Tap the matching square. Earlier taps earn more points."
        case .changingColor:
            "Check the HUD again: your color has changed. Tap the new matching color and leave other colors alone."
        case .speedBar:
            "The fastest taps fill the Speed Bar and increase your score multiplier. Tap three matching squares to try it. This practice has no timer."
        case .pickups:
            mode == .arcade
                ? "Power-ups appear only on 4×4. Tap the heart for a life, then the rewind clock to slow the pace temporarily. Lives stop at three."
                : "Hearts appear only on 4×4. Any living player can claim one; the first accepted tap gets the life, up to three. There are no clocks in Multiplayer."
        case .competition:
            mode == .arcade
                ? "Eligible signed-in Arcade results can improve your leaderboard position. Practice scores are not submitted."
                : "Watch everyone's color, score and lives. Wait for your color; there is no fixed turn order. Out of lives? Spectate until the last player is out. The highest final score wins, even if that player was eliminated earlier."
        case .rewards:
            rewardsInstruction
        }
    }
    var rewardsInstruction: String {
        if mode == .arcade {
            return
                "Eligible Arcade survival earns one coin per accumulated minute. Sign in to save eligible scores, improve your rank and collect rewards. This tutorial earns nothing."
        }
        let coins = capabilities.multiplayerCoinsPerAliveMinute
        let reward =
            coins > 0
            ? "Eligible Multiplayer survival earns \(coins) coins per accumulated minute while you are alive. Spectating time does not count."
            : "Multiplayer is currently a playtest with no coin rewards."
        let ranking =
            capabilities.multiplayerLeaderboardEnabled
            ? "Eligible match results can improve your Multiplayer leaderboard position."
            : "Compete in the match standings; global Multiplayer v2 ranking is not enabled."
        return "\(reward) \(ranking) This tutorial earns nothing."
    }

    func tile(at cell: Int) -> HowToPlayTile {
        guard (0..<(gridDimension * gridDimension)).contains(cell) else { return .empty }
        if step == .pickups {
            if cell == 5, interactions == 0 { return .heart }
            if cell == 10, mode == .arcade, interactions == 1 { return .clock }
            return .empty
        }
        guard !canAdvance else { return .empty }
        if cell == targetCell { return .target }
        if cell == 1 || (step == .competition && cell == 9) { return .otherColor }
        return .empty
    }

    mutating func tap(cell: Int) {
        guard !canAdvance else { return }
        switch tile(at: cell) {
        case .target:
            interactions += 1
            feedback = canAdvance ? "Nice! You can continue." : "Good hit! Follow the next matching square."
        case .heart:
            interactions += 1
            feedback = mode == .arcade ? "Life restored. Now try the rewind clock." : "You claimed the life!"
        case .clock:
            interactions += 1
            feedback = "The clock gives you more time."
        case .empty, .otherColor:
            feedback =
                step == .pickups ? "Tap the highlighted power-up." : "Look at YOUR COLOR, then tap its matching square."
        }
    }

    @discardableResult
    mutating func advance() -> Bool {
        guard canAdvance, let next = HowToPlayStep(rawValue: step.rawValue + 1) else { return false }
        step = next
        interactions = 0
        feedback = nil
        return true
    }
}

enum HowToPlayLaunchPolicy {
    static func shouldPresent(rememberedSkip: Bool, arguments: [String]) -> Bool {
        #if DEBUG
            if arguments.contains("--uitesting"), !arguments.contains("--ui-test-tutorial-entry") { return false }
        #endif
        return !rememberedSkip
    }

    static func fixtureMode(arguments: [String]) -> HowToPlayMode? {
        #if DEBUG
            guard arguments.contains("--uitesting") else { return nil }
            let prefix = "--ui-test-tutorial="
            guard let argument = arguments.first(where: { $0.hasPrefix(prefix) }) else { return nil }
            return HowToPlayMode(rawValue: String(argument.dropFirst(prefix.count)))
        #else
            return nil
        #endif
    }
}
