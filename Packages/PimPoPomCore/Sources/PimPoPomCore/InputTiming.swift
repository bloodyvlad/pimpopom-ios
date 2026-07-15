import Foundation

public enum InputTiming {
    public static func resolveInputTimestamp(
        eventTimestampMilliseconds: Double,
        currentTimeMilliseconds: Double
    ) -> Double {
        let fallback = currentTimeMilliseconds.isFinite ? max(0, currentTimeMilliseconds) : 0
        guard eventTimestampMilliseconds.isFinite, eventTimestampMilliseconds > 0 else {
            return fallback
        }
        guard eventTimestampMilliseconds <= fallback + 1 else { return fallback }
        guard fallback - eventTimestampMilliseconds <= 60_000 else { return fallback }
        return min(eventTimestampMilliseconds, fallback)
    }

    public static func reactionDeadline(
        visibleAtMilliseconds: Double,
        responseWindowMilliseconds: Double
    ) -> Double {
        visibleAtMilliseconds + max(0, responseWindowMilliseconds)
    }

    public static func remainingUntilDeadline(
        deadlineAtMilliseconds: Double,
        currentTimeMilliseconds: Double
    ) -> Double {
        max(0, ceil(deadlineAtMilliseconds - currentTimeMilliseconds))
    }

    public static func reachedDeadline(
        inputAtMilliseconds: Double,
        deadlineAtMilliseconds: Double
    ) -> Bool {
        deadlineAtMilliseconds.isFinite && inputAtMilliseconds >= deadlineAtMilliseconds
    }

    public static func predatesPresentation(
        inputAtMilliseconds: Double,
        visibleAtMilliseconds: Double
    ) -> Bool {
        visibleAtMilliseconds.isFinite && inputAtMilliseconds < visibleAtMilliseconds
    }

    public static func wasCoveredByDeadlineResolution(
        inputAtMilliseconds: Double,
        resolvedAtMilliseconds: Double
    ) -> Bool {
        resolvedAtMilliseconds.isFinite && inputAtMilliseconds <= resolvedAtMilliseconds
    }
}
