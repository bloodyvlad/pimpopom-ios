import SwiftUI

struct CoinStorePlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var cosmetics: CosmeticsController

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 52, weight: .black))
                        .foregroundStyle(.yellow)
                        .padding(.top, 24)

                    Text("Coin Store")
                        .font(.largeTitle.weight(.black))
                    Text("\(cosmetics.coinBalance) coins")
                        .font(.title2.monospacedDigit().weight(.bold))
                        .foregroundStyle(.cyan)

                    VStack(alignment: .leading, spacing: 10) {
                        Label(
                            "StoreKit coin packs are disabled in this internal alpha.",
                            systemImage: "hammer.fill")
                        Label(
                            "Verified Arcade time and achievement rewards remain the only coin sources.",
                            systemImage: "checkmark.shield.fill")
                        Label(
                            "Pet and theme purchases always use the balance confirmed by Hostinger.",
                            systemImage: "server.rack")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                }
                .padding(20)
            }
            .navigationTitle("Buy Coins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("coin-store-placeholder")
    }
}
