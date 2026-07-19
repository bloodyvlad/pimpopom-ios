import Foundation
import StoreKit

enum StoreKitServiceError: LocalizedError, Equatable, Sendable {
    case productUnavailable(StoreProductID)
    case productTypeMismatch(StoreProductID)
    case transactionNotRetained(UInt64)
    case unknownPurchaseResult

    var errorDescription: String? {
        switch self {
        case .productUnavailable(let productID):
            "The App Store product is unavailable: \(productID.rawValue)."
        case .productTypeMismatch(let productID):
            "The App Store product type does not match the PimPoPom catalog: \(productID.rawValue)."
        case .transactionNotRetained(let transactionID):
            "The verified StoreKit transaction is no longer available to finish: \(transactionID)."
        case .unknownPurchaseResult:
            "The App Store returned an unsupported purchase result."
        }
    }
}

actor StoreKitService: StoreKitServing {
    private var productsByID: [StoreProductID: Product] = [:]
    private var retainedTransactions: [UInt64: Transaction] = [:]

    func loadProducts() async throws -> [StoreProduct] {
        let identifiers = StoreProductID.catalogOrder.map(\.rawValue)
        let appStoreProducts = try await Product.products(for: identifiers)
        var loadedProducts: [StoreProductID: Product] = [:]

        for product in appStoreProducts {
            guard let productID = StoreProductID(rawValue: product.id) else { continue }
            guard product.type.matches(productID.kind) else {
                throw StoreKitServiceError.productTypeMismatch(productID)
            }
            loadedProducts[productID] = product
        }

        productsByID = loadedProducts
        return StoreProductID.catalogOrder.compactMap { productID in
            loadedProducts[productID].map { product in
                StoreProduct(
                    id: productID,
                    displayName: product.displayName,
                    description: product.description,
                    displayPrice: product.displayPrice,
                    isFamilyShareable: product.isFamilyShareable
                )
            }
        }
    }

    func purchase(
        _ productID: StoreProductID,
        appAccountToken: UUID
    ) async throws -> StorePurchaseResult {
        if productsByID[productID] == nil {
            _ = try await loadProducts()
        }
        guard let product = productsByID[productID] else {
            throw StoreKitServiceError.productUnavailable(productID)
        }

        let result = try await product.purchase(
            options: [.appAccountToken(appAccountToken)]
        )
        switch result {
        case .success(let verification):
            switch capture(verification, retainingForFinish: true) {
            case .verified(let transaction):
                return .success(transaction)
            case .unverified(let rawProductID):
                return .unverified(productID: rawProductID)
            case .rejected(let rawProductID, let reason):
                return .rejected(productID: rawProductID, reason: reason)
            }
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            throw StoreKitServiceError.unknownPurchaseResult
        }
    }

    func transactionUpdates() -> AsyncStream<StoreTransactionObservation> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                for await result in Transaction.updates {
                    guard !Task.isCancelled, let self else { break }
                    let observation = await self.capture(
                        result,
                        retainingForFinish: true
                    )
                    continuation.yield(observation)
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    func unfinishedTransactions() async -> [StoreTransactionObservation] {
        var observations: [StoreTransactionObservation] = []
        for await result in Transaction.unfinished {
            observations.append(capture(result, retainingForFinish: true))
        }
        return observations
    }

    func currentNonConsumableEntitlements() async -> [StoreTransactionObservation] {
        // Capture unfinished transactions first so an unfinished Remove Ads entitlement
        // remains finishable even if the current-entitlement sequence is consumed first.
        _ = await unfinishedTransactions()

        var observations: [StoreTransactionObservation] = []
        for await result in Transaction.currentEntitlements {
            let rawProductID: String
            switch result {
            case .verified(let transaction), .unverified(let transaction, _):
                rawProductID = transaction.productID
            }
            guard rawProductID == StoreProductID.removeAdsLifetime.rawValue else { continue }
            observations.append(capture(result, retainingForFinish: false))
        }
        return observations
    }

    func finish(transactionID: UInt64) async throws {
        guard let transaction = retainedTransactions[transactionID] else {
            throw StoreKitServiceError.transactionNotRetained(transactionID)
        }
        await transaction.finish()
        retainedTransactions.removeValue(forKey: transactionID)
    }

    func sync() async throws {
        try await AppStore.sync()
    }

    private func capture(
        _ result: VerificationResult<Transaction>,
        retainingForFinish: Bool
    ) -> StoreTransactionObservation {
        switch result {
        case .unverified(let transaction, _):
            return .unverified(productID: transaction.productID)
        case .verified(let transaction):
            guard let productID = StoreProductID(rawValue: transaction.productID) else {
                return .rejected(
                    productID: transaction.productID,
                    reason: .unsupportedProduct
                )
            }
            guard transaction.productType.matches(productID.kind) else {
                return .rejected(
                    productID: transaction.productID,
                    reason: .productTypeMismatch
                )
            }

            if retainingForFinish {
                retainedTransactions[transaction.id] = transaction
            }
            let requiresFinish = retainingForFinish || retainedTransactions[transaction.id] != nil
            return .verified(
                StoreTransaction(
                    id: transaction.id,
                    productID: productID,
                    appAccountToken: transaction.appAccountToken,
                    signedTransaction: result.jwsRepresentation,
                    ownership: transaction.ownershipType.storeTransactionOwnership,
                    revocationDate: transaction.revocationDate,
                    requiresFinish: requiresFinish
                )
            )
        }
    }
}

extension Product.ProductType {
    fileprivate func matches(_ kind: StoreProductKind) -> Bool {
        switch kind {
        case .consumable:
            self == .consumable
        case .nonConsumable:
            self == .nonConsumable
        }
    }
}

extension Transaction.OwnershipType {
    fileprivate var storeTransactionOwnership: StoreTransactionOwnership {
        if self == .purchased {
            .purchased
        } else if self == .familyShared {
            .familyShared
        } else {
            .unknown(rawValue)
        }
    }
}
