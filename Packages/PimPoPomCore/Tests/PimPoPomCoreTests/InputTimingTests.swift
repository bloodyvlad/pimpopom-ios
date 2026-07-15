import Testing

@testable import PimPoPomCore

@Test("Touch timestamps preserve contact time and reject incompatible values")
func inputTimestamps() {
    #expect(
        InputTiming.resolveInputTimestamp(eventTimestampMilliseconds: 1_025.4, currentTimeMilliseconds: 1_041.8)
            == 1_025.4)
    #expect(
        InputTiming.resolveInputTimestamp(eventTimestampMilliseconds: 0, currentTimeMilliseconds: 1_041.8) == 1_041.8)
    #expect(
        InputTiming.resolveInputTimestamp(eventTimestampMilliseconds: .nan, currentTimeMilliseconds: 1_041.8) == 1_041.8
    )
    #expect(
        InputTiming.resolveInputTimestamp(eventTimestampMilliseconds: 1_043, currentTimeMilliseconds: 1_041.8)
            == 1_041.8)
    #expect(
        InputTiming.resolveInputTimestamp(eventTimestampMilliseconds: 10, currentTimeMilliseconds: 70_011) == 70_011)
}

@Test("Deadlines remain anchored to presentation")
func deadlineHelpers() {
    let deadline = InputTiming.reactionDeadline(
        visibleAtMilliseconds: 2_000.25,
        responseWindowMilliseconds: 200
    )
    #expect(deadline == 2_200.25)
    #expect(
        InputTiming.remainingUntilDeadline(deadlineAtMilliseconds: deadline, currentTimeMilliseconds: 2_017.7) == 183)
    #expect(!InputTiming.reachedDeadline(inputAtMilliseconds: 2_200.249, deadlineAtMilliseconds: deadline))
    #expect(InputTiming.reachedDeadline(inputAtMilliseconds: deadline, deadlineAtMilliseconds: deadline))
}

@Test("Presentation and resolution guards use inclusive source semantics")
func inputGuards() {
    #expect(InputTiming.predatesPresentation(inputAtMilliseconds: 999.9, visibleAtMilliseconds: 1_000))
    #expect(!InputTiming.predatesPresentation(inputAtMilliseconds: 1_000, visibleAtMilliseconds: 1_000))
    #expect(InputTiming.wasCoveredByDeadlineResolution(inputAtMilliseconds: 1_200, resolvedAtMilliseconds: 1_200))
    #expect(!InputTiming.wasCoveredByDeadlineResolution(inputAtMilliseconds: 1_201, resolvedAtMilliseconds: 1_200))
}
