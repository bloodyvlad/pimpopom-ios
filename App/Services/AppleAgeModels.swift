import Foundation

struct AppleSharedAgeRange: Equatable, Sendable {
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

enum AppleAgeResponse: Equatable, Sendable {
    case shared(AppleSharedAgeRange)
    case declined(isRequired: Bool)
    case unsupported
}

@MainActor
protocol AppleAgeServing: AnyObject {
    func requestAgeRange() async throws -> AppleAgeResponse
}

@MainActor
protocol AppleAgeLockStoring: AnyObject {
    var hasSharedAppleRange: Bool { get set }
}

@MainActor
final class UserDefaultsAppleAgeLockStore: AppleAgeLockStoring {
    private let defaults: UserDefaults
    private let key = "privacy.apple-age.shared.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var hasSharedAppleRange: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }
}
