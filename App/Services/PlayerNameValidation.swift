import Foundation

enum PlayerNameValidation {
    static let whitespaceMessage = "Player names cannot contain spaces."

    static func localError(for candidate: String) -> String? {
        if candidate.isEmpty {
            return "Enter a player name."
        }
        if containsWhitespace(candidate) {
            return whitespaceMessage
        }
        return nil
    }

    static func containsWhitespace(_ candidate: String) -> Bool {
        candidate.unicodeScalars.contains { $0.properties.isWhitespace }
    }

    static func serverNormalizedCandidate(_ candidate: String) -> String {
        candidate.precomposedStringWithCompatibilityMapping.unicodeScalars.reduce(into: "") {
            result, scalar in
            let category = scalar.properties.generalCategory
            if category != .control, category != .format {
                result.unicodeScalars.append(scalar)
            }
        }
    }
}

enum PlayerNameAvailabilityState: Equatable {
    enum Tone {
        case neutral
        case success
        case warning
        case error
    }

    case idle
    case checking
    case available
    case taken
    case unavailable
    case invalid(String)

    var allowsSave: Bool {
        switch self {
        case .available, .unavailable:
            true
        case .idle, .checking, .taken, .invalid:
            false
        }
    }

    var notice: String? {
        switch self {
        case .idle:
            nil
        case .checking:
            "Checking player name…"
        case .available:
            "This player name is available."
        case .taken:
            "This player name is already taken."
        case .unavailable:
            "Player name validation is temporarily unavailable. You can still try Save."
        case .invalid(let message):
            message
        }
    }

    var tone: Tone {
        switch self {
        case .idle, .checking:
            .neutral
        case .available:
            .success
        case .unavailable:
            .warning
        case .taken, .invalid:
            .error
        }
    }
}
