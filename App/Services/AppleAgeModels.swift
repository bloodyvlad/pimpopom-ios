import Foundation

struct AppleSharedAgeRange: Codable, Equatable, Sendable {
    let lowerBound: Int?
    let upperBound: Int?
    let hasParentalControls: Bool

    var isValid: Bool {
        guard lowerBound != nil || upperBound != nil else { return false }
        if let lowerBound, lowerBound < 0 { return false }
        if let upperBound, upperBound < 0 { return false }
        if let lowerBound, let upperBound, lowerBound > upperBound { return false }
        return true
    }

    // Apple may return jurisdiction-specific ranges instead of our requested gates.
    // The youngest possible age controls access and advertising protections.
    var adBand: AdAgeBand {
        guard isValid, let lowerBound, lowerBound >= 13 else { return .under13 }
        if lowerBound >= 18 { return .adult }
        if lowerBound >= 16 { return .olderTeen }
        return .youngTeen
    }

    var displayTitle: String {
        if let lowerBound, let upperBound { return "\(lowerBound)–\(upperBound)" }
        if let lowerBound { return "\(lowerBound) or older" }
        if let upperBound { return "\(upperBound) or younger" }
        return "Not shared"
    }
}

/// Actual Apple range when available; older installs retain their known protective band.
struct AppleAgeProtection: Codable, Equatable, Sendable {
    let band: AdAgeBand
    let range: AppleSharedAgeRange?
}

enum AppleAgeResponse: Equatable, Sendable {
    case shared(AppleSharedAgeRange)
    case declined
    case unsupported
}

enum AppleAgeRequirement: Equatable, Sendable {
    case required
    case optional
    // Older systems do not expose a regional query; no age is assumed.
    case legacy
}

struct AppleAgeDiagnostic: Equatable, Sendable {
    let stage: String
    let domain: String
    let code: Int
}

@MainActor
protocol AppleAgeServing: AnyObject {
    func regulatoryRequirement() async throws -> AppleAgeRequirement
    func requestAgeRange() async throws -> AppleAgeResponse
}

@MainActor
protocol AppleAgeLockStoring: AnyObject {
    var hasSharedAppleRange: Bool { get set }
    var lastKnownProtection: AppleAgeProtection? { get set }
}

@MainActor
final class UserDefaultsAppleAgeLockStore: AppleAgeLockStoring {
    private let defaults: UserDefaults
    private let key = "privacy.apple-age.shared.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var lastKnownProtection: AppleAgeProtection? {
        get {
            guard let data = defaults.data(forKey: "privacy.apple-age.protection.v1") else { return nil }
            return try? JSONDecoder().decode(AppleAgeProtection.self, from: data)
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: "privacy.apple-age.protection.v1")
        }
    }

    var hasSharedAppleRange: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }
}
