import XCTest

@testable import PimPoPom

@MainActor
final class PurchaseControllerTests: XCTestCase {
    func testCatalogUsesTheExactFiveProductsInStoreOrder() {
        XCTAssertEqual(
            StoreProductID.catalogOrder.map(\.rawValue),
            [
                "com.otcsoftware.pimpopom.coins.50.v1",
                "com.otcsoftware.pimpopom.coins.100.v1",
                "com.otcsoftware.pimpopom.coins.500.v1",
                "com.otcsoftware.pimpopom.coins.1000.v1",
                "com.otcsoftware.pimpopom.removeads.lifetime",
            ]
        )
        XCTAssertEqual(StoreProductID.catalogOrder.map(\.coinQuantity), [50, 100, 500, 1_000, 0])
        XCTAssertEqual(
            StoreProductID.catalogOrder.map(\.kind),
            [.consumable, .consumable, .consumable, .consumable, .nonConsumable]
        )
        XCTAssertTrue(StoreProductID.catalogOrder.allSatisfy(\.grantsAdFree))
        XCTAssertEqual(StoreProductID.catalogOrder.filter(\.isRestorable), [.removeAdsLifetime])
    }

    func testProductsArePublishedInCatalogOrder() async {
        let products = StoreProductID.catalogOrder.reversed().map(storeProduct)
        let store = FakeStoreKitService(products: products)
        let credit = FakeStoreKitCreditService(account: account)
        let controller = PurchaseController(
            storeKit: store,
            creditService: credit,
            startListeners: false
        )

        await controller.loadProducts()

        XCTAssertEqual(controller.products.map(\.id), StoreProductID.catalogOrder)
        XCTAssertEqual(controller.state, .ready)
    }

    func testVerifiedPurchaseIsServerCreditedBeforeItIsFinished() async {
        let recorder = StoreTestRecorder()
        let transaction = storeTransaction(id: 41, productID: .coins100)
        let store = FakeStoreKitService(
            purchaseResult: .success(transaction),
            recorder: recorder
        )
        let credit = FakeStoreKitCreditService(account: account, recorder: recorder)
        let controller = PurchaseController(
            storeKit: store,
            creditService: credit,
            startListeners: false
        )

        await controller.purchase(.coins100)

        let events = await recorder.values()
        XCTAssertEqual(
            events,
            [
                .purchase(.coins100, account.appAccountToken),
                .credit("41", .coins100),
                .finish(41),
            ]
        )
        guard case .success(let result) = controller.state else {
            return XCTFail("Expected a successful purchase, got \(controller.state)")
        }
        XCTAssertEqual(result.productID, .coins100)
        XCTAssertEqual(result.transactionID, "41")
        XCTAssertEqual(result.wallet.total, 100)
        XCTAssertTrue(result.adFree)
    }

    func testServerFailureLeavesTheVerifiedTransactionUnfinished() async {
        let recorder = StoreTestRecorder()
        let store = FakeStoreKitService(
            purchaseResult: .success(storeTransaction(id: 42, productID: .coins50)),
            recorder: recorder
        )
        let credit = FakeStoreKitCreditService(
            account: account,
            shouldFail: true,
            recorder: recorder
        )
        let controller = PurchaseController(
            storeKit: store,
            creditService: credit,
            startListeners: false
        )

        await controller.purchase(.coins50)

        let events = await recorder.values()
        XCTAssertEqual(
            events,
            [
                .purchase(.coins50, account.appAccountToken),
                .credit("42", .coins50),
            ]
        )
        XCTAssertEqual(controller.state, .failure(.server("Fake server failure.")))
    }

    func testMismatchedAccountTokenIsNeverCreditedOrFinished() async {
        let recorder = StoreTestRecorder()
        let transaction = storeTransaction(
            id: 43,
            productID: .coins500,
            appAccountToken: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        )
        let store = FakeStoreKitService(purchaseResult: .success(transaction), recorder: recorder)
        let credit = FakeStoreKitCreditService(account: account, recorder: recorder)
        let controller = PurchaseController(
            storeKit: store,
            creditService: credit,
            startListeners: false
        )

        await controller.purchase(.coins500)

        let events = await recorder.values()
        XCTAssertEqual(
            events,
            [.purchase(.coins500, account.appAccountToken)]
        )
        XCTAssertEqual(controller.state, .failure(.accountTokenMismatch))
    }

    func testPurchaseRejectsAResultForAnotherAllowlistedProduct() async {
        let recorder = StoreTestRecorder()
        let store = FakeStoreKitService(
            purchaseResult: .success(storeTransaction(id: 44, productID: .coins1000)),
            recorder: recorder
        )
        let credit = FakeStoreKitCreditService(account: account, recorder: recorder)
        let controller = PurchaseController(
            storeKit: store,
            creditService: credit,
            startListeners: false
        )

        await controller.purchase(.coins50)

        XCTAssertEqual(
            controller.state,
            .failure(.unexpectedProduct(expected: .coins50, actual: .coins1000))
        )
        let events = await recorder.values()
        XCTAssertEqual(
            events,
            [.purchase(.coins50, account.appAccountToken)]
        )
    }

    func testMismatchedServerTransactionIDIsNotFinished() async {
        let recorder = StoreTestRecorder()
        let store = FakeStoreKitService(
            purchaseResult: .success(storeTransaction(id: 45, productID: .coins50)),
            recorder: recorder
        )
        let credit = FakeStoreKitCreditService(
            account: account,
            responseTransactionID: "different-transaction",
            recorder: recorder
        )
        let controller = PurchaseController(
            storeKit: store,
            creditService: credit,
            startListeners: false
        )

        await controller.purchase(.coins50)

        XCTAssertEqual(
            controller.state,
            .failure(
                .serverResponseMismatch(
                    expected: "45",
                    actual: "different-transaction"
                )
            )
        )
        let events = await recorder.values()
        XCTAssertEqual(
            events,
            [
                .purchase(.coins50, account.appAccountToken),
                .credit("45", .coins50),
            ]
        )
    }

    func testAccountChangeAfterServerCreditKeepsTransactionUnfinished() async {
        let recorder = StoreTestRecorder()
        let store = FakeStoreKitService(
            purchaseResult: .success(storeTransaction(id: 451, productID: .coins50)),
            recorder: recorder
        )
        let changedAccount = StoreAccountBinding(
            profileID: "profile-2",
            appAccountToken: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!
        )
        let credit = FakeStoreKitCreditService(
            account: account,
            accountAfterCredit: changedAccount,
            recorder: recorder
        )
        let controller = PurchaseController(
            storeKit: store,
            creditService: credit,
            startListeners: false
        )

        await controller.purchase(.coins50)

        XCTAssertEqual(controller.state, .failure(.accountChangedBeforeFinish))
        let events = await recorder.values()
        XCTAssertEqual(
            events,
            [
                .purchase(.coins50, account.appAccountToken),
                .credit("451", .coins50),
            ]
        )
    }

    func testPendingCancelledAndUnverifiedAreExplicitStates() async {
        let store = FakeStoreKitService(purchaseResult: .pending)
        let credit = FakeStoreKitCreditService(account: account)
        let controller = PurchaseController(
            storeKit: store,
            creditService: credit,
            startListeners: false
        )

        await controller.purchase(.coins50)
        XCTAssertEqual(controller.state, .pending(.coins50))

        await store.setPurchaseResult(.cancelled)
        await controller.purchase(.coins100)
        XCTAssertEqual(controller.state, .cancelled(.coins100))

        await store.setPurchaseResult(
            .unverified(productID: StoreProductID.coins500.rawValue)
        )
        await controller.purchase(.coins500)
        XCTAssertEqual(controller.state, .unverified(.coins500))
    }

    func testLaunchRecoveryCoalescesDuplicateUnfinishedTransactions() async {
        let recorder = StoreTestRecorder()
        let transaction = storeTransaction(id: 46, productID: .coins100)
        let store = FakeStoreKitService(
            unfinished: [.verified(transaction), .verified(transaction)],
            recorder: recorder
        )
        let credit = FakeStoreKitCreditService(account: account, recorder: recorder)
        let controller = PurchaseController(
            storeKit: store,
            creditService: credit,
            startListeners: true
        )

        let completed = await eventually {
            if case .success = controller.state { return true }
            return false
        }

        XCTAssertTrue(completed)
        let events = await recorder.values()
        XCTAssertEqual(events.filter { if case .credit = $0 { true } else { false } }.count, 1)
        XCTAssertEqual(events.filter { if case .finish = $0 { true } else { false } }.count, 1)
    }

    func testTransactionUpdatesAreObservedAfterListenersStart() async {
        let recorder = StoreTestRecorder()
        let store = FakeStoreKitService(recorder: recorder)
        let credit = FakeStoreKitCreditService(account: account, recorder: recorder)
        let controller = PurchaseController(
            storeKit: store,
            creditService: credit,
            startListeners: true
        )

        await store.emit(
            .verified(storeTransaction(id: 461, productID: .coins500))
        )
        let completed = await eventually {
            if case .success(let result) = controller.state {
                return result.transactionID == "461"
            }
            return false
        }

        XCTAssertTrue(completed)
        let events = await recorder.values()
        XCTAssertEqual(
            events.filter { if case .credit = $0 { true } else { false } }.count,
            1
        )
    }

    func testRestoreSyncsAndReconcilesOnlyStandaloneRemoveAds() async {
        let recorder = StoreTestRecorder()
        let coin = storeTransaction(id: 47, productID: .coins100, requiresFinish: false)
        let removeAds = storeTransaction(
            id: 48,
            productID: .removeAdsLifetime,
            appAccountToken: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"),
            ownership: .familyShared,
            requiresFinish: false
        )
        let store = FakeStoreKitService(
            currentEntitlements: [.verified(coin), .verified(removeAds)],
            recorder: recorder
        )
        let credit = FakeStoreKitCreditService(account: account, recorder: recorder)
        let controller = PurchaseController(
            storeKit: store,
            creditService: credit,
            startListeners: false
        )

        await controller.restorePurchases()

        let events = await recorder.values()
        XCTAssertEqual(
            events,
            [
                .sync,
                .credit("48", .removeAdsLifetime),
            ]
        )
        guard case .success(let result) = controller.state else {
            return XCTFail("Expected Remove Ads restoration")
        }
        XCTAssertEqual(result.productID, .removeAdsLifetime)
    }

    func testFamilySharingIsRejectedForConsumables() async {
        let recorder = StoreTestRecorder()
        let transaction = storeTransaction(
            id: 49,
            productID: .coins1000,
            appAccountToken: nil,
            ownership: .familyShared
        )
        let store = FakeStoreKitService(
            unfinished: [.verified(transaction)],
            recorder: recorder
        )
        let credit = FakeStoreKitCreditService(account: account, recorder: recorder)
        let controller = PurchaseController(
            storeKit: store,
            creditService: credit,
            startListeners: false
        )

        await controller.reconcileOutstandingTransactions()

        XCTAssertEqual(controller.state, .failure(.familySharingNotAllowed(.coins1000)))
        let events = await recorder.values()
        XCTAssertTrue(events.isEmpty)
    }
}

private let account = StoreAccountBinding(
    profileID: "profile-1",
    appAccountToken: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
)

private func storeProduct(_ productID: StoreProductID) -> StoreProduct {
    StoreProduct(
        id: productID,
        displayName: productID.rawValue,
        description: "Localized description",
        displayPrice: "$1.99",
        isFamilyShareable: productID == .removeAdsLifetime
    )
}

private func storeTransaction(
    id: UInt64,
    productID: StoreProductID,
    appAccountToken: UUID? = account.appAccountToken,
    ownership: StoreTransactionOwnership = .purchased,
    requiresFinish: Bool = true
) -> StoreTransaction {
    StoreTransaction(
        id: id,
        productID: productID,
        appAccountToken: appAccountToken,
        signedTransaction: "signed-jws-\(id)",
        ownership: ownership,
        revocationDate: nil,
        requiresFinish: requiresFinish
    )
}

private enum StoreTestEvent: Equatable, Sendable {
    case purchase(StoreProductID, UUID)
    case credit(String, StoreProductID)
    case finish(UInt64)
    case sync
}

private actor StoreTestRecorder {
    private var events: [StoreTestEvent] = []

    func append(_ event: StoreTestEvent) {
        events.append(event)
    }

    func values() -> [StoreTestEvent] {
        events
    }
}

private actor FakeStoreKitService: StoreKitServing {
    private let products: [StoreProduct]
    private var purchaseResult: StorePurchaseResult
    private let unfinished: [StoreTransactionObservation]
    private let currentEntitlements: [StoreTransactionObservation]
    private let recorder: StoreTestRecorder?
    private let updates: AsyncStream<StoreTransactionObservation>
    private let updatesContinuation: AsyncStream<StoreTransactionObservation>.Continuation

    init(
        products: [StoreProduct] = StoreProductID.catalogOrder.map(storeProduct),
        purchaseResult: StorePurchaseResult = .cancelled,
        unfinished: [StoreTransactionObservation] = [],
        currentEntitlements: [StoreTransactionObservation] = [],
        recorder: StoreTestRecorder? = nil
    ) {
        self.products = products
        self.purchaseResult = purchaseResult
        self.unfinished = unfinished
        self.currentEntitlements = currentEntitlements
        self.recorder = recorder
        let stream = AsyncStream<StoreTransactionObservation>.makeStream()
        updates = stream.stream
        updatesContinuation = stream.continuation
    }

    deinit {
        updatesContinuation.finish()
    }

    func setPurchaseResult(_ result: StorePurchaseResult) {
        purchaseResult = result
    }

    func emit(_ observation: StoreTransactionObservation) {
        updatesContinuation.yield(observation)
    }

    func loadProducts() -> [StoreProduct] {
        products
    }

    func purchase(
        _ productID: StoreProductID,
        appAccountToken: UUID
    ) async -> StorePurchaseResult {
        await recorder?.append(.purchase(productID, appAccountToken))
        return purchaseResult
    }

    func transactionUpdates() -> AsyncStream<StoreTransactionObservation> {
        updates
    }

    func unfinishedTransactions() -> [StoreTransactionObservation] {
        unfinished
    }

    func currentNonConsumableEntitlements() -> [StoreTransactionObservation] {
        currentEntitlements
    }

    func finish(transactionID: UInt64) async {
        await recorder?.append(.finish(transactionID))
    }

    func sync() async {
        await recorder?.append(.sync)
    }
}

private enum FakeStoreCreditError: LocalizedError, Sendable {
    case failed

    var errorDescription: String? { "Fake server failure." }
}

private actor FakeStoreKitCreditService: StoreKitCreditServing {
    private var account: StoreAccountBinding?
    private let responseTransactionID: String?
    private let accountAfterCredit: StoreAccountBinding?
    private let shouldFail: Bool
    private let recorder: StoreTestRecorder?

    init(
        account: StoreAccountBinding?,
        responseTransactionID: String? = nil,
        accountAfterCredit: StoreAccountBinding? = nil,
        shouldFail: Bool = false,
        recorder: StoreTestRecorder? = nil
    ) {
        self.account = account
        self.responseTransactionID = responseTransactionID
        self.accountAfterCredit = accountAfterCredit
        self.shouldFail = shouldFail
        self.recorder = recorder
    }

    func setAccount(_ account: StoreAccountBinding?) {
        self.account = account
    }

    func currentStoreAccount() -> StoreAccountBinding? {
        account
    }

    func credit(_ request: StoreCreditRequest) async throws -> StoreCreditResponse {
        await recorder?.append(.credit(request.transactionID, request.productID))
        if shouldFail {
            throw FakeStoreCreditError.failed
        }
        if let accountAfterCredit {
            account = accountAfterCredit
        }
        return StoreCreditResponse(
            transactionID: responseTransactionID ?? request.transactionID,
            disposition: .credited,
            wallet: StoreWalletSummary(
                earned: 0,
                purchased: request.productID.coinQuantity,
                earnedDebt: 0,
                refundDebt: 0,
                total: request.productID.coinQuantity
            ),
            adFree: true
        )
    }
}

@MainActor
private func eventually(
    attempts: Int = 200,
    condition: @MainActor () -> Bool
) async -> Bool {
    for _ in 0..<attempts {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return false
}
