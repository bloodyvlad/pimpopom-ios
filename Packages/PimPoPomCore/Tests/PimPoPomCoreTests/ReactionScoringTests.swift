import Testing

@testable import PimPoPomCore

@Test("Reaction ratings use the same rounded milliseconds shown to the player")
func reactionRatingBoundaries() {
    #expect(SpeedRating.classify(reactionMilliseconds: 249.49).rating == .godlike)
    #expect(SpeedRating.classify(reactionMilliseconds: 249.5).rating == .perfect)
    #expect(SpeedRating.classify(reactionMilliseconds: 349.49).rating == .perfect)
    #expect(SpeedRating.classify(reactionMilliseconds: 349.5).rating == .great)
    #expect(SpeedRating.classify(reactionMilliseconds: 449.49).rating == .great)
    #expect(SpeedRating.classify(reactionMilliseconds: 449.5).rating == .good)
}

@Test("Reaction score preserves the frozen web formula")
func reactionScoreFormula() {
    #expect(ReactionScoring.points(reactionMilliseconds: 0, responseWindowMilliseconds: 1_000) == 1_000)
    #expect(ReactionScoring.points(reactionMilliseconds: 500, responseWindowMilliseconds: 1_000) == 325)
    #expect(ReactionScoring.points(reactionMilliseconds: 1_000, responseWindowMilliseconds: 1_000) == 100)
    #expect(ReactionScoring.points(reactionMilliseconds: 1_500, responseWindowMilliseconds: 1_000) == 100)
}
