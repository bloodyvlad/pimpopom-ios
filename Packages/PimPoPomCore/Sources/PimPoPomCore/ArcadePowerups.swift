import Foundation

/// Select rules explicitly; existing callers and archived proofs remain v3.
public enum ArcadeRuleset: String, Codable, Sendable {
    case v3 = "reaction-proof-v3"
    case v4 = "reaction-proof-v4"
    case v5 = "reaction-proof-v5"

    public var proofVersion: Int { self == .v3 ? 2 : 3 }

    /// V4 is retained for archived/build-27 proofs; v5 waits for the actual 4×4 field.
    public var minimumPickupGridDimension: Int { self == .v5 ? 4 : 2 }
}

public enum ArcadePickupKind: Int, Codable, CaseIterable, Sendable {
    case heart = 0
    case clock = 1
}

public struct ArcadePickup: Equatable, Codable, Sendable {
    public let id: Int
    public let kind: ArcadePickupKind
    public let cellIndex: Int
    public let visibleAt: Double
    public let expiresAt: Double

    public init(id: Int, kind: ArcadePickupKind, cellIndex: Int, visibleAt: Double, expiresAt: Double) {
        self.id = id
        self.kind = kind
        self.cellIndex = cellIndex
        self.visibleAt = visibleAt
        self.expiresAt = expiresAt
    }
}

/// Integer arithmetic is shared with PHP proof replay; no floating-point tempo
/// accumulation or mutation of already-scheduled deadlines is required.
public enum ArcadePowerupRules {
    public static let opportunityRange = DelayRange(12_000, 20_000)
    public static let retryMilliseconds = 250
    public static let lifetimeMilliseconds = 3_000
    public static let clockRecoveryMilliseconds = 10_000
    public static let normalRateUnits = 100_000

    public static func rateUnits(atMilliseconds: Int, clockClaimHandledAtMilliseconds: Int?) -> Int {
        guard let anchor = clockClaimHandledAtMilliseconds else { return normalRateUnits }
        let elapsed = min(clockRecoveryMilliseconds, max(0, atMilliseconds - anchor))
        return 70_000 + 3 * elapsed
    }

    public static func scaledInterval(baseMilliseconds: Int, rateUnits: Int) -> Int {
        let rate = min(normalRateUnits, max(70_000, rateUnits))
        return (baseMilliseconds * normalRateUnits + rate - 1) / rate
    }
}
