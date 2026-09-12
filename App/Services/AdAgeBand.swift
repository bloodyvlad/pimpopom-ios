import Foundation

/// Product policy: use under-consent ad protections below 16 worldwide.
/// This is not a statement of the legal age of consent in each country.
enum AdAgeBand: String, CaseIterable, Sendable {
    case under13 = "under-13"
    case youngTeen = "13-15"
    case olderTeen = "16-17"
    case adult = "18-plus"

    var displayTitle: String {
        switch self {
        case .under13: "Under 13"
        case .youngTeen: "13–15"
        case .olderTeen: "16–17"
        case .adult: "18 or older"
        }
    }

    var allowsApp: Bool { self != .under13 }
    var isUnderAdConsentAge: Bool { self == .youngTeen }
}

@MainActor
protocol AdAgeBandStoring: AnyObject {
    var ageBand: AdAgeBand? { get set }
    var confirmedProfileID: String? { get set }
}

@MainActor
final class UserDefaultsAdAgeBandStore: AdAgeBandStoring {
    private let defaults: UserDefaults
    private let ageKey = "privacy.age-band.v1"
    private let profileKey = "privacy.age-band.profile.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var ageBand: AdAgeBand? {
        get { defaults.string(forKey: ageKey).flatMap(AdAgeBand.init(rawValue:)) }
        set { defaults.set(newValue?.rawValue, forKey: ageKey) }
    }

    // Local account binding lets shared-device account changes ask again.
    // Neither this age band nor this binding is sent to the game's backend.
    var confirmedProfileID: String? {
        get { defaults.string(forKey: profileKey) }
        set { defaults.set(newValue, forKey: profileKey) }
    }
}

#if DEBUG
    @MainActor
    final class MemoryAdAgeBandStore: AdAgeBandStoring {
        var ageBand: AdAgeBand?
        var confirmedProfileID: String?

        init(_ ageBand: AdAgeBand? = nil, confirmedProfileID: String? = nil) {
            self.ageBand = ageBand
            self.confirmedProfileID = confirmedProfileID
        }
    }
#endif
