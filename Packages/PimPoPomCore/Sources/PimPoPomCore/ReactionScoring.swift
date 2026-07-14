import Foundation

public enum SpeedRating: String, CaseIterable, Sendable {
    case godlike
    case perfect
    case great
    case good

    public var label: String {
        rawValue.capitalized
    }

    public static func classify(reactionMilliseconds: Double) -> (rating: Self, displayedMilliseconds: Int) {
        let displayed = Int(max(0, reactionMilliseconds).rounded(.toNearestOrAwayFromZero))
        let rating: Self = if displayed < 250 {
            .godlike
        } else if displayed < 350 {
            .perfect
        } else if displayed < 450 {
            .great
        } else {
            .good
        }

        return (rating, displayed)
    }
}

public enum ReactionScoring {
    public static func points(reactionMilliseconds: Double, responseWindowMilliseconds: Double) -> Int {
        guard responseWindowMilliseconds > 0 else { return 100 }

        let remainingRatio = min(
            1,
            max(0, 1 - reactionMilliseconds / responseWindowMilliseconds)
        )
        return Int((100 + 900 * pow(remainingRatio, 2)).rounded(.toNearestOrAwayFromZero))
    }
}
