#if DEBUG
    import Foundation

    enum LocalStoreKitCreditError: LocalizedError, Equatable, Sendable {
        case accountMismatch
        case invalidTransaction
        case transactionConflict

        var errorDescription: String? {
            switch self {
            case .accountMismatch:
                "The local StoreKit transaction belongs to another fixture account."
            case .invalidTransaction:
                "The local StoreKit transaction is incomplete."
            case .transactionConflict:
                "The local StoreKit transaction ID was reused with different purchase data."
            }
        }
    }

    /// A deterministic, network-free credit ledger used only by the Debug
    /// StoreKit scheme. Production and TestFlight builds cannot compile this
    /// implementation and always acknowledge transactions through Hostinger.
    actor LocalStoreKitCreditService: StoreKitCreditServing {
        static let account = StoreAccountBinding(
            profileID: "11111111-2222-4111-8111-111111111111",
            appAccountToken: UUID(uuidString: "22222222-3333-4333-8333-444444444444")!
        )

        private struct CompletedCredit: Equatable, Sendable {
            let productID: StoreProductID
            let signedTransaction: String
            let appAccountToken: UUID
            let response: StoreCreditResponse
        }

        private let account: StoreAccountBinding
        private var wallet: StoreWalletSummary
        private var adFree: Bool
        private var completed: [String: CompletedCredit] = [:]

        init(
            account: StoreAccountBinding = LocalStoreKitCreditService.account,
            wallet: StoreWalletSummary = StoreWalletSummary(
                earned: 75,
                purchased: 0,
                earnedDebt: 0,
                refundDebt: 0,
                total: 75
            ),
            adFree: Bool = false
        ) {
            self.account = account
            self.wallet = wallet
            self.adFree = adFree
        }

        func currentStoreAccount() -> StoreAccountBinding? {
            account
        }

        func currentStorefrontState() -> StorefrontAccountState {
            StorefrontAccountState(binding: account, wallet: wallet, adFree: adFree)
        }

        func credit(_ request: StoreCreditRequest) throws -> StoreCreditResponse {
            guard request.appAccountToken == account.appAccountToken else {
                throw LocalStoreKitCreditError.accountMismatch
            }
            guard UInt64(request.transactionID).map({ $0 > 0 }) == true,
                !request.signedTransaction.isEmpty
            else {
                throw LocalStoreKitCreditError.invalidTransaction
            }

            if let existing = completed[request.transactionID] {
                guard existing.productID == request.productID,
                    existing.signedTransaction == request.signedTransaction,
                    existing.appAccountToken == request.appAccountToken
                else {
                    throw LocalStoreKitCreditError.transactionConflict
                }
                return StoreCreditResponse(
                    transactionID: existing.response.transactionID,
                    disposition: .duplicate,
                    wallet: existing.response.wallet,
                    adFree: existing.response.adFree
                )
            }

            let grossCoins = request.productID.coinQuantity
            let debtPaid = min(wallet.refundDebt, grossCoins)
            let purchased = wallet.purchased + grossCoins - debtPaid
            let refundDebt = wallet.refundDebt - debtPaid
            wallet = StoreWalletSummary(
                earned: wallet.earned,
                purchased: purchased,
                earnedDebt: wallet.earnedDebt,
                refundDebt: refundDebt,
                total: wallet.earned + purchased
            )
            adFree = adFree || request.productID.grantsAdFree

            let response = StoreCreditResponse(
                transactionID: request.transactionID,
                disposition: .credited,
                wallet: wallet,
                adFree: adFree
            )
            completed[request.transactionID] = CompletedCredit(
                productID: request.productID,
                signedTransaction: request.signedTransaction,
                appAccountToken: request.appAccountToken,
                response: response
            )
            return response
        }
    }
#endif
