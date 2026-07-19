import Combine
import Foundation

struct StorePurchaseSuccess: Equatable, Sendable {
    let productID: StoreProductID
    let transactionID: String
    let disposition: StoreCreditDisposition
    let wallet: StoreWalletSummary
    let adFree: Bool
}

enum PurchaseControllerFailure: LocalizedError, Equatable, Sendable {
    case authenticationRequired
    case purchaseAlreadyInProgress
    case invalidTransaction
    case unexpectedProduct(expected: StoreProductID, actual: StoreProductID)
    case unsupportedProduct(String)
    case productTypeMismatch(String)
    case accountTokenMismatch
    case accountChangedBeforeFinish
    case familySharingNotAllowed(StoreProductID)
    case unknownOwnership
    case serverResponseMismatch(expected: String, actual: String)
    case nothingToRestore
    case storeKit(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            "Sign in to PimPoPom before making or restoring a purchase."
        case .purchaseAlreadyInProgress:
            "Another App Store operation is already in progress."
        case .invalidTransaction:
            "The verified App Store transaction was incomplete."
        case .unexpectedProduct(let expected, let actual):
            "The App Store returned \(actual.rawValue) instead of \(expected.rawValue)."
        case .unsupportedProduct(let productID):
            "The App Store transaction is not in the PimPoPom catalog: \(productID)."
        case .productTypeMismatch(let productID):
            "The App Store transaction has the wrong product type: \(productID)."
        case .accountTokenMismatch:
            "The App Store transaction belongs to a different PimPoPom profile."
        case .accountChangedBeforeFinish:
            "The PimPoPom profile changed before the purchase was acknowledged."
        case .familySharingNotAllowed(let productID):
            "Family Sharing is not allowed for \(productID.rawValue)."
        case .unknownOwnership:
            "The App Store returned an unsupported ownership type."
        case .serverResponseMismatch(let expected, let actual):
            "The server acknowledged transaction \(actual) instead of \(expected)."
        case .nothingToRestore:
            "No Remove Ads purchase was available to restore."
        case .storeKit(let message), .server(let message):
            message
        }
    }
}

enum PurchaseControllerState: Equatable, Sendable {
    case idle
    case loading
    case ready
    case purchasing(StoreProductID)
    case pending(StoreProductID)
    case cancelled(StoreProductID)
    case unverified(StoreProductID?)
    case serverCrediting(StoreProductID, transactionID: String)
    case success(StorePurchaseSuccess)
    case failure(PurchaseControllerFailure)
}

@MainActor
final class PurchaseController: ObservableObject {
    @Published private(set) var state = PurchaseControllerState.idle
    @Published private(set) var products: [StoreProduct] = []
    @Published private(set) var storefront = StorefrontAccountState.unavailable

    private let storeKit: any StoreKitServing
    private let creditService: any StoreKitCreditServing
    private var updatesTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private var hasStartedListeners = false
    private var hasActiveUserOperation = false
    private var transactionsInFlight: Set<CompletedTransactionKey> = []
    private var completedTransactions: [CompletedTransactionKey: StorePurchaseSuccess] = [:]
    private var productLoadGeneration = 0

    private struct CompletedTransactionKey: Hashable {
        let transactionID: UInt64
        let profileID: String
        let appAccountToken: UUID
    }

    init(
        storeKit: any StoreKitServing = StoreKitService(),
        creditService: any StoreKitCreditServing,
        startListeners: Bool = true
    ) {
        self.storeKit = storeKit
        self.creditService = creditService
        if startListeners {
            startTransactionListeners()
        }
    }

    deinit {
        updatesTask?.cancel()
        recoveryTask?.cancel()
    }

    func startTransactionListeners() {
        guard !hasStartedListeners else { return }
        hasStartedListeners = true

        let storeKit = storeKit
        updatesTask = Task { [weak self] in
            let updates = await storeKit.transactionUpdates()
            for await observation in updates {
                guard !Task.isCancelled, let self else { return }
                await self.handle(observation, expectedProduct: nil, account: nil)
            }
        }

        recoveryTask = Task { [weak self] in
            await self?.reconcileOutstandingTransactions()
        }
    }

    func loadProducts() async {
        productLoadGeneration += 1
        let generation = productLoadGeneration
        state = .loading
        do {
            let loaded = try await storeKit.loadProducts()
            guard generation == productLoadGeneration else { return }
            let byID = Dictionary(loaded.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            products = StoreProductID.catalogOrder.compactMap { byID[$0] }
            if case .loading = state { state = .ready }
        } catch {
            guard generation == productLoadGeneration else { return }
            if case .loading = state {
                state = .failure(.storeKit(error.localizedDescription))
            }
        }
    }

    func refreshStorefront() async {
        let refreshed = await creditService.currentStorefrontState()
        if storefront.binding != refreshed.binding {
            state = products.isEmpty ? .idle : .ready
        }
        storefront = refreshed
    }

    func purchase(_ productID: StoreProductID) async {
        guard beginUserOperation() else { return }
        defer { hasActiveUserOperation = false }

        guard let account = await creditService.currentStoreAccount() else {
            state = .failure(.authenticationRequired)
            return
        }

        state = .purchasing(productID)
        do {
            let result = try await storeKit.purchase(
                productID,
                appAccountToken: account.appAccountToken
            )
            switch result {
            case .success(let transaction):
                await reconcile(
                    transaction,
                    expectedProduct: productID,
                    account: account,
                    reportAuthenticationFailure: true
                )
            case .pending:
                state = .pending(productID)
            case .cancelled:
                state = .cancelled(productID)
            case .unverified(let rawProductID):
                state = .unverified(StoreProductID(rawValue: rawProductID))
            case .rejected(let rawProductID, let reason):
                handleRejection(productID: rawProductID, reason: reason)
            }
        } catch {
            state = .failure(.storeKit(error.localizedDescription))
        }
    }

    func restorePurchases() async {
        guard beginUserOperation() else { return }
        defer { hasActiveUserOperation = false }

        guard let account = await creditService.currentStoreAccount() else {
            state = .failure(.authenticationRequired)
            return
        }

        state = .loading
        do {
            try await storeKit.sync()
            let entitlements = await storeKit.currentNonConsumableEntitlements()
            var foundRemoveAds = false

            for observation in entitlements {
                switch observation {
                case .verified(let transaction):
                    guard transaction.productID == .removeAdsLifetime else { continue }
                    foundRemoveAds = true
                case .unverified(let rawProductID), .rejected(let rawProductID, _):
                    guard rawProductID == StoreProductID.removeAdsLifetime.rawValue else {
                        continue
                    }
                    foundRemoveAds = true
                }
                await handle(
                    observation,
                    expectedProduct: .removeAdsLifetime,
                    account: account
                )
            }

            if !foundRemoveAds {
                state = .failure(.nothingToRestore)
            }
        } catch {
            state = .failure(.storeKit(error.localizedDescription))
        }
    }

    /// Call again after PimPoPom login changes so unfinished transactions can be
    /// bound and acknowledged without waiting for another StoreKit update.
    func reconcileOutstandingTransactions() async {
        await refreshStorefront()
        let unfinished = await storeKit.unfinishedTransactions()
        for observation in unfinished {
            await handle(observation, expectedProduct: nil, account: nil)
        }

        let entitlements = await storeKit.currentNonConsumableEntitlements()
        for observation in entitlements {
            await handle(observation, expectedProduct: nil, account: nil)
        }
    }

    private func beginUserOperation() -> Bool {
        guard !hasActiveUserOperation else {
            state = .failure(.purchaseAlreadyInProgress)
            return false
        }
        hasActiveUserOperation = true
        return true
    }

    private func handle(
        _ observation: StoreTransactionObservation,
        expectedProduct: StoreProductID?,
        account: StoreAccountBinding?
    ) async {
        switch observation {
        case .verified(let transaction):
            await reconcile(
                transaction,
                expectedProduct: expectedProduct,
                account: account,
                reportAuthenticationFailure: account != nil
            )
        case .unverified(let rawProductID):
            state = .unverified(StoreProductID(rawValue: rawProductID))
        case .rejected(let rawProductID, let reason):
            handleRejection(productID: rawProductID, reason: reason)
        }
    }

    private func reconcile(
        _ transaction: StoreTransaction,
        expectedProduct: StoreProductID?,
        account suppliedAccount: StoreAccountBinding?,
        reportAuthenticationFailure: Bool
    ) async {
        if let expectedProduct, transaction.productID != expectedProduct {
            state = .failure(
                .unexpectedProduct(expected: expectedProduct, actual: transaction.productID)
            )
            return
        }
        guard transaction.id > 0, !transaction.signedTransaction.isEmpty else {
            state = .failure(.invalidTransaction)
            return
        }

        let currentAccount: StoreAccountBinding?
        if let suppliedAccount {
            currentAccount = suppliedAccount
        } else {
            currentAccount = await creditService.currentStoreAccount()
        }
        guard let account = currentAccount else {
            if reportAuthenticationFailure {
                state = .failure(.authenticationRequired)
            }
            return
        }
        guard validateOwnership(transaction, account: account) else { return }

        let completedKey = CompletedTransactionKey(
            transactionID: transaction.id,
            profileID: account.profileID,
            appAccountToken: account.appAccountToken
        )
        if let completed = completedTransactions[completedKey] {
            state = .success(completed)
            storefront = StorefrontAccountState(
                binding: account,
                wallet: completed.wallet,
                adFree: completed.adFree
            )
            return
        }
        guard !transactionsInFlight.contains(completedKey) else { return }

        transactionsInFlight.insert(completedKey)
        defer { transactionsInFlight.remove(completedKey) }

        let transactionID = String(transaction.id)
        state = .serverCrediting(transaction.productID, transactionID: transactionID)
        let request = StoreCreditRequest(
            transactionID: transactionID,
            productID: transaction.productID,
            signedTransaction: transaction.signedTransaction,
            appAccountToken: account.appAccountToken
        )

        do {
            let response = try await creditService.credit(request)
            guard response.transactionID == transactionID else {
                state = .failure(
                    .serverResponseMismatch(
                        expected: transactionID,
                        actual: response.transactionID
                    )
                )
                return
            }
            guard await creditService.currentStoreAccount() == account else {
                state = .failure(.accountChangedBeforeFinish)
                return
            }

            if transaction.requiresFinish {
                try await storeKit.finish(transactionID: transaction.id)
            }

            let success = StorePurchaseSuccess(
                productID: transaction.productID,
                transactionID: transactionID,
                disposition: response.disposition,
                wallet: response.wallet,
                adFree: response.adFree
            )
            completedTransactions[completedKey] = success
            storefront = StorefrontAccountState(
                binding: account,
                wallet: response.wallet,
                adFree: response.adFree
            )
            state = .success(success)
        } catch {
            state = .failure(.server(error.localizedDescription))
        }
    }

    private func validateOwnership(
        _ transaction: StoreTransaction,
        account: StoreAccountBinding
    ) -> Bool {
        switch transaction.ownership {
        case .purchased:
            guard transaction.appAccountToken == account.appAccountToken else {
                state = .failure(.accountTokenMismatch)
                return false
            }
        case .familyShared:
            // The signed Family Sharing transaction belongs to the purchaser's
            // Apple account, so its optional token is not the recipient profile's
            // binding. The backend receives the current profile token separately.
            guard transaction.productID == .removeAdsLifetime else {
                state = .failure(.familySharingNotAllowed(transaction.productID))
                return false
            }
        case .unknown:
            state = .failure(.unknownOwnership)
            return false
        }
        return true
    }

    private func handleRejection(
        productID: String,
        reason: StoreTransactionRejection
    ) {
        switch reason {
        case .unsupportedProduct:
            state = .failure(.unsupportedProduct(productID))
        case .productTypeMismatch:
            state = .failure(.productTypeMismatch(productID))
        }
    }
}
