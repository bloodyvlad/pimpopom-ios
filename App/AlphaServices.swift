import Foundation

protocol AdServing: Sendable {
    var availability: AlphaServiceAvailability { get }
}

enum AlphaServiceAvailability: Equatable, Sendable {
    case disabledForLocalAlpha
}

struct DisabledAdService: AdServing {
    let availability = AlphaServiceAvailability.disabledForLocalAlpha
}

struct AlphaServices: Sendable {
    let ads: any AdServing

    static let localOnly = AlphaServices(
        ads: DisabledAdService()
    )
}
