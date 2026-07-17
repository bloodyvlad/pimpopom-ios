import SwiftUI

enum StoreKitPlaceholderOffer: Equatable, Sendable {
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
}

struct CoinStorePlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var cosmetics: CosmeticsController
    var offer = StoreKitPlaceholderOffer.coinPacks

    private var palette: ThemePalette { cosmetics.theme }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: offer.symbol)
                        .font(.system(size: 52, weight: .black))
                        .foregroundStyle(.yellow)
                        .padding(.top, 24)

                    Text(offer.heading)
                        .font(.largeTitle.weight(.black))
                    if offer == .coinPacks {
                        HStack(spacing: 7) {
                            PixelCoinView(size: 24)
                            Text("\(cosmetics.coinBalance)")
                                .font(palette.appFont(size: 22, weight: .black, relativeTo: .title2))
                                .monospacedDigit()
                                .foregroundStyle(Color(hex: "#ffc629"))
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(cosmetics.coinBalance) coins")
                    } else {
                        Text("One-time StoreKit purchase")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.cyan)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        if offer == .coinPacks {
                            Label(
                                "StoreKit coin packs are disabled in this internal alpha.",
                                systemImage: "hammer.fill"
                            )
                            Label(
                                "Verified Arcade time and achievement rewards remain the only coin sources.",
                                systemImage: "checkmark.shield.fill"
                            )
                            Label(
                                "Pet and theme purchases always use the server-confirmed balance.",
                                systemImage: "checkmark.icloud.fill"
                            )
                        } else {
                            Label(
                                "The Remove Ads StoreKit product is disabled in this internal alpha.",
                                systemImage: "hammer.fill"
                            )
                            Label(
                                "This placeholder grants no entitlement and changes no ad state.",
                                systemImage: "checkmark.shield.fill"
                            )
                            Label(
                                "Restore Purchases will be added with the real StoreKit product.",
                                systemImage: "arrow.clockwise.icloud.fill"
                            )
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                }
                .padding(20)
            }
            .navigationTitle(offer.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier(
            offer == .coinPacks ? "coin-store-placeholder" : "remove-ads-store-placeholder"
        )
    }
}
