import SwiftUI

enum StorefrontOffer: Equatable, Sendable {
    case coinPacks
    case removeAds

    var navigationTitle: String {
        switch self {
        case .coinPacks: "Buy Coins"
        case .removeAds: "Remove Ads"
        }
    }

    var heading: String {
        switch self {
        case .coinPacks: "Coin Store"
        case .removeAds: "Ad-free PimPoPom"
        }
    }

    var symbol: String {
        switch self {
        case .coinPacks: "shippingbox.fill"
        case .removeAds: "rectangle.slash.fill"
        }
    }

    func includes(_ product: StoreProduct) -> Bool {
        switch self {
        case .coinPacks:
            product.id.kind == .consumable
        case .removeAds:
            product.id == .removeAdsLifetime
        }
    }
}

struct CoinStoreView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var backend: BackendClient
    @EnvironmentObject private var cosmetics: CosmeticsController
    @EnvironmentObject private var purchases: PurchaseController

    var offer = StorefrontOffer.coinPacks

    private var palette: ThemePalette { cosmetics.theme }
    private var products: [StoreProduct] { purchases.products.filter(offer.includes) }
    private var hasBoundAccount: Bool { purchases.storefront.binding != nil }
    private var operationIsBlocking: Bool {
        switch purchases.state {
        case .purchasing, .serverCrediting:
            true
        default:
            false
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppThemeBackground(theme: palette)

                ScrollView {
                    VStack(spacing: 14) {
                        hero
                        if isLocalStoreKitTesting {
                            Label("LOCAL STOREKIT TEST · NO PRODUCTION CREDIT", systemImage: "hammer.fill")
                                .font(
                                    palette.appFont(
                                        size: 10,
                                        weight: .black,
                                        relativeTo: .caption2
                                    )
                                )
                                .tracking(0.8)
                                .foregroundStyle(.yellow)
                                .frame(maxWidth: .infinity)
                                .webCardStyle(theme: palette, padding: 10)
                                .accessibilityIdentifier("store-local-testing")
                        }
                        accountSummary
                        productList
                        recoveryActions

                        if let status = statusMessage {
                            statusCard(status)
                        }
                    }
                    .frame(maxWidth: WebMenuMetrics.maximumPanelWidth)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                }
            }
            .foregroundStyle(Color(hex: palette.foreground))
            .navigationTitle(offer.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .disabled(operationIsBlocking)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(operationIsBlocking)
        .accessibilityIdentifier(offer == .coinPacks ? "coin-store" : "remove-ads-store")
        .task {
            await purchases.refreshStorefront()
            if purchases.products.isEmpty {
                await purchases.loadProducts()
            }
        }
    }

    private var hero: some View {
        HStack(spacing: 13) {
            Image(systemName: offer.symbol)
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(Color(hex: offer == .coinPacks ? "#ffc629" : palette.accent))
                .frame(width: 50, height: 50)
                .background(Color(hex: palette.surface), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(offer.heading)
                    .font(palette.appFont(size: 25, weight: .black, relativeTo: .title))
                Text(
                    offer == .coinPacks
                        ? "APPLE-VERIFIED COINS"
                        : "RESTORABLE LIFETIME ACCESS"
                )
                .font(palette.appFont(size: 9, weight: .black, relativeTo: .caption2))
                .tracking(1)
                .foregroundStyle(Color(hex: palette.muted))
            }
            Spacer()
        }
        .webCardStyle(theme: palette, selectedAccent: Color(hex: palette.accent), padding: 14)
    }

    @ViewBuilder
    private var accountSummary: some View {
        if !backend.isAuthenticated {
            accountGate(
                title: "Sign in to purchase",
                message: "Open My Profile and sign in so purchases can be recovered on your PimPoPom account.",
                symbol: "person.crop.circle.badge.exclamationmark"
            )
        } else if !hasBoundAccount {
            accountGate(
                title: "Store account is not ready",
                message:
                    "Refresh your PimPoPom session before purchasing. "
                    + "No App Store charge can start until the server supplies an account binding.",
                symbol: "link.badge.plus"
            )
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    PixelCoinView(size: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Current balance")
                            .font(palette.appFont(size: 10, weight: .black, relativeTo: .caption))
                            .foregroundStyle(Color(hex: palette.muted))
                        Text("\(purchases.storefront.wallet?.total ?? cosmetics.coinBalance)")
                            .font(palette.appFont(size: 24, weight: .black, relativeTo: .title2))
                            .monospacedDigit()
                    }
                    Spacer()
                    if purchases.storefront.adFree == true {
                        Label("Ad-free", systemImage: "checkmark.shield.fill")
                            .font(palette.appFont(size: 12, weight: .black, relativeTo: .caption))
                            .foregroundStyle(Color(hex: palette.accent))
                    }
                }

                if let wallet = purchases.storefront.wallet {
                    Text("Earned \(wallet.earned) · Purchased \(wallet.purchased)")
                        .font(palette.appFont(size: 11, weight: .bold, relativeTo: .caption))
                        .foregroundStyle(Color(hex: palette.muted))
                    if wallet.refundDebt > 0 {
                        Label(
                            "Refund debt: \(wallet.refundDebt) coins. New credits repay this first.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(palette.appFont(size: 12, weight: .bold, relativeTo: .caption))
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("store-refund-debt")
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("store-wallet")
            .webCardStyle(theme: palette, padding: 14)
        }
    }

    private func accountGate(title: String, message: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(hex: palette.accent))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(palette.appFont(size: 17, weight: .black, relativeTo: .headline))
                Text(message)
                    .font(palette.appFont(size: 12, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(Color(hex: palette.muted))
            }
            Spacer(minLength: 0)
        }
        .accessibilityIdentifier("store-account-gate")
        .webCardStyle(theme: palette, padding: 14)
    }

    @ViewBuilder
    private var productList: some View {
        if purchases.state == .loading, products.isEmpty {
            HStack(spacing: 10) {
                ProgressView().tint(Color(hex: palette.accent))
                Text("Loading App Store products…")
                    .font(palette.appFont(size: 14, weight: .bold, relativeTo: .body))
            }
            .frame(maxWidth: .infinity)
            .webCardStyle(theme: palette, padding: 18)
            .accessibilityIdentifier("store-products-loading")
        } else if products.isEmpty {
            accountGate(
                title: "Products unavailable",
                message: "Check your connection, then try loading the App Store catalog again.",
                symbol: "cart.badge.questionmark"
            )
            Button("Try Again") {
                Task { await purchases.loadProducts() }
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: palette,
                    accent: Color(hex: palette.accent),
                    minimumHeight: 44
                )
            )
            .accessibilityIdentifier("store-products-retry")
        } else {
            ForEach(products) { product in
                productCard(product)
            }
        }
    }

    private func productCard(_ product: StoreProduct) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(product.displayName)
                    .font(palette.appFont(size: 19, weight: .black, relativeTo: .title3))
                Spacer(minLength: 8)
                Text(product.displayPrice)
                    .font(palette.appFont(size: 18, weight: .black, relativeTo: .headline))
                    .foregroundStyle(Color(hex: "#ffc629"))
            }
            Text(product.description)
                .font(palette.appFont(size: 12, weight: .medium, relativeTo: .caption))
                .foregroundStyle(Color(hex: palette.muted))

            if product.id.kind == .consumable {
                Label("Includes ad-free play for this PimPoPom profile", systemImage: "checkmark.shield.fill")
                    .font(palette.appFont(size: 11, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(Color(hex: palette.accent))
            } else if product.isFamilyShareable {
                Label("Restorable · Family Sharing", systemImage: "person.3.fill")
                    .font(palette.appFont(size: 11, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(Color(hex: palette.accent))
            }

            Button {
                Task { await purchases.purchase(product.id) }
            } label: {
                HStack(spacing: 7) {
                    if case .purchasing(let activeProduct) = purchases.state,
                        activeProduct == product.id
                    {
                        ProgressView().controlSize(.small)
                    }
                    Text(purchaseButtonTitle(product))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: palette,
                    accent: Color(hex: palette.accent),
                    minimumHeight: 46
                )
            )
            .disabled(!canPurchase(product))
            .accessibilityIdentifier("store-product-\(product.id.rawValue)")
        }
        .webCardStyle(theme: palette, padding: 14)
    }

    private var recoveryActions: some View {
        VStack(spacing: 9) {
            Button {
                Task { await purchases.reconcileOutstandingTransactions() }
            } label: {
                Label("Retry Pending Purchases", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: palette,
                    accent: Color(hex: palette.accent),
                    minimumHeight: 44
                )
            )
            .disabled(!hasBoundAccount || operationIsBlocking)
            .accessibilityIdentifier("store-retry-pending")

            if offer == .removeAds {
                Button {
                    Task { await purchases.restorePurchases() }
                } label: {
                    Label("Restore Purchases", systemImage: "arrow.clockwise.icloud.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    WebSecondaryButtonStyle(
                        theme: palette,
                        accent: Color(hex: palette.accent),
                        minimumHeight: 44
                    )
                )
                .disabled(!hasBoundAccount || operationIsBlocking)
                .accessibilityIdentifier("store-restore-purchases")
            }
        }
    }

    private func statusCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if operationIsBlocking { ProgressView().controlSize(.small) }
            Image(systemName: statusSymbol)
                .foregroundStyle(statusColor)
            Text(message)
                .font(palette.appFont(size: 13, weight: .bold, relativeTo: .footnote))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("store-status")
        .webCardStyle(theme: palette, selectedAccent: statusColor.opacity(0.75), padding: 13)
    }

    private func canPurchase(_ product: StoreProduct) -> Bool {
        guard hasBoundAccount, !operationIsBlocking else { return false }
        if product.id == .removeAdsLifetime, purchases.storefront.adFree == true { return false }
        return true
    }

    private func purchaseButtonTitle(_ product: StoreProduct) -> String {
        if product.id == .removeAdsLifetime, purchases.storefront.adFree == true {
            return "Ad-free Active"
        }
        return "Buy for \(product.displayPrice)"
    }

    private var statusMessage: String? {
        switch purchases.state {
        case .idle, .ready, .loading:
            nil
        case .purchasing:
            "Waiting for the App Store…"
        case .pending:
            "Purchase pending approval. PimPoPom will recover it automatically when Apple completes it."
        case .cancelled:
            "Purchase cancelled. Nothing was charged by PimPoPom."
        case .unverified:
            "Apple returned a transaction that could not be verified. No value was granted."
        case .serverCrediting:
            "Purchase verified. Waiting for the PimPoPom server to secure the credit…"
        case .success(let success):
            successMessage(success)
        case .failure(let failure):
            failure.errorDescription
        }
    }

    private func successMessage(_ success: StorePurchaseSuccess) -> String {
        switch success.disposition {
        case .credited:
            "Purchase complete. Your server-confirmed balance is \(success.wallet.total) coins."
        case .duplicate:
            "This purchase was already secured. Your balance is \(success.wallet.total) coins."
        case .reconciled:
            "Purchase restored and reconciled with your PimPoPom account."
        case .reversed:
            "The refunded or revoked purchase was reconciled with your account."
        }
    }

    private var statusSymbol: String {
        switch purchases.state {
        case .success: "checkmark.circle.fill"
        case .failure, .unverified: "exclamationmark.triangle.fill"
        case .pending: "clock.fill"
        default: "info.circle.fill"
        }
    }

    private var statusColor: Color {
        switch purchases.state {
        case .success: palette.color(at: 3)
        case .failure, .unverified: .orange
        case .pending: Color(hex: "#ffc629")
        default: Color(hex: palette.accent)
        }
    }

    private var isLocalStoreKitTesting: Bool {
        #if DEBUG
            ProcessInfo.processInfo.arguments.contains("--local-storekit-credit")
        #else
            false
        #endif
    }
}
