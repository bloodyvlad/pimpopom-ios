import Foundation

protocol AdServing: Sendable {
    var availability: AlphaServiceAvailability { get }
}

protocol PurchaseServing: Sendable {
    var availability: AlphaServiceAvailability { get }
}

enum AlphaServiceAvailability: Equatable, Sendable {
    case disabledForLocalAlpha
}

struct DisabledAdService: AdServing {
    let availability = AlphaServiceAvailability.disabledForLocalAlpha
}

struct DisabledPurchaseService: PurchaseServing {
    let availability = AlphaServiceAvailability.disabledForLocalAlpha
}

struct AlphaServices: Sendable {
    let ads: any AdServing
    let purchases: any PurchaseServing

    static let localOnly = AlphaServices(
        ads: DisabledAdService(),
        purchases: DisabledPurchaseService()
    )
}
