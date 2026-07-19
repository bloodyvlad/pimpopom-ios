import Foundation

enum StoreProductID: String, CaseIterable, Codable, Sendable {
    case coins50 = "com.otcsoftware.pimpopom.coins.50.v1"
    case coins100 = "com.otcsoftware.pimpopom.coins.100.v1"
    case coins500 = "com.otcsoftware.pimpopom.coins.500.v1"
    case coins1000 = "com.otcsoftware.pimpopom.coins.1000.v1"
    case removeAdsLifetime = "com.otcsoftware.pimpopom.removeads.lifetime"

    static let catalogOrder: [StoreProductID] = [
        .coins50,
        .coins100,
        .coins500,
        .coins1000,
        .removeAdsLifetime,
    ]

    var kind: StoreProductKind {
        switch self {
        case .coins50, .coins100, .coins500, .coins1000:
            .consumable
        case .removeAdsLifetime:
            .nonConsumable
        }
    }

    var coinQuantity: Int {
        switch self {
        case .coins50:
            50
        case .coins100:
            100
        case .coins500:
            500
        case .coins1000:
            1_000
        case .removeAdsLifetime:
            0
        }
    }

    var grantsAdFree: Bool { true }

    var isRestorable: Bool {
        self == .removeAdsLifetime
    }
}

enum StoreProductKind: String, Codable, Equatable, Sendable {
    case consumable
    case nonConsumable
}

struct StoreProduct: Identifiable, Equatable, Sendable {
    let id: StoreProductID
    let displayName: String
    let description: String
    let displayPrice: String
    let isFamilyShareable: Bool
}

enum StoreTransactionOwnership: Equatable, Sendable {
    case purchased
    case familyShared
    case unknown(String)
}

struct StoreTransaction: Identifiable, Equatable, Sendable {
    let id: UInt64
    let productID: StoreProductID
    let appAccountToken: UUID?
    let signedTransaction: String
    let ownership: StoreTransactionOwnership
    let revocationDate: Date?
    let requiresFinish: Bool
}

enum StoreTransactionRejection: Equatable, Sendable {
    case unsupportedProduct
    case productTypeMismatch
}

enum StoreTransactionObservation: Equatable, Sendable {
    case verified(StoreTransaction)
    case unverified(productID: String)
    case rejected(productID: String, reason: StoreTransactionRejection)
}

enum StorePurchaseResult: Equatable, Sendable {
    case success(StoreTransaction)
    case pending
    case cancelled
    case unverified(productID: String)
    case rejected(productID: String, reason: StoreTransactionRejection)
}

protocol StoreKitServing: Sendable {
    func loadProducts() async throws -> [StoreProduct]
    func purchase(
        _ productID: StoreProductID,
        appAccountToken: UUID
    ) async throws -> StorePurchaseResult
    func transactionUpdates() async -> AsyncStream<StoreTransactionObservation>
    func unfinishedTransactions() async -> [StoreTransactionObservation]
    func currentNonConsumableEntitlements() async -> [StoreTransactionObservation]
    func finish(transactionID: UInt64) async throws
    func sync() async throws
}

struct StoreAccountBinding: Equatable, Sendable {
    let profileID: String
    let appAccountToken: UUID
}

struct StoreCreditRequest: Equatable, Sendable {
    let transactionID: String
    let productID: StoreProductID
    let signedTransaction: String
    let appAccountToken: UUID
}

struct StoreWalletSummary: Equatable, Sendable {
    let earned: Int
    let purchased: Int
    let earnedDebt: Int
    let refundDebt: Int
    let total: Int
}

enum StoreCreditDisposition: Equatable, Sendable {
    case credited
    case duplicate
    case reconciled
    case reversed
}

struct StoreCreditResponse: Equatable, Sendable {
    let transactionID: String
    let disposition: StoreCreditDisposition
    let wallet: StoreWalletSummary
    let adFree: Bool
}

protocol StoreKitCreditServing: Sendable {
    func currentStoreAccount() async -> StoreAccountBinding?
    func credit(_ request: StoreCreditRequest) async throws -> StoreCreditResponse
}
