import Foundation

enum MenuMotivation {
    static let rotationInterval = Duration.seconds(10)

    static let hints = [
        "Go get your pet!",
        "You are achiever!",
        "Go faster, play longer!",
        "1 minute - 1 coin!",
        "Coconut in ukrainian?",
        "Who is misha_boy?",
        "Tiny taps, giant scores!",
        "Your pet believes in you!",
        "Tap first. Blink later.",
        "Coins don’t collect themselves!",
        "Faster fingers, happier pets!",
        "One more run. Obviously.",
        "That square looked nervous.",
        "Speed is your superpower!",
        "Almost legendary. Go again!",
        "Warm up those thumbs!",
        "Misha saw that miss.",
        "Foka demands a rematch!",
        "Pancake believes in you!",
        "Zen later. Arcade now!",
        "Was that your fastest?",
        "Three lives. Zero excuses.",
        "The leaderboard is watching.",
        "Tap like rent is due!",
        "Your next score is bigger!",
        "Blink between rounds!",
    ]

    static let tones = ["cyan", "pink", "gold", "green", "violet"]
    static let tilts = [-3.0, 2.0, -2.0, 3.0, -1.0, 1.0]

    static func nextIndex(previous: Int?, randomValue: Double) -> Int {
        let normalized = randomValue.isFinite ? min(0.999_999_999, max(0, randomValue)) : 0
        var next = Int(floor(normalized * Double(hints.count)))
        if hints.count > 1, next == previous {
            next = (next + 1) % hints.count
        }
        return next
    }
}
