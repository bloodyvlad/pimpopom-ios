import SwiftUI

struct PetShopView: View {
    @EnvironmentObject private var cosmetics: CosmeticsController
    @State private var showsCoinStore = false

    private var palette: ThemePalette { cosmetics.theme }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: palette)

            ScrollView {
                LazyVStack(spacing: 14) {
                    walletHeader

                    if cosmetics.isLoading {
                        ProgressView("Loading pets…")
                            .tint(Color(hex: palette.accent))
                            .foregroundStyle(Color(hex: palette.foreground))
                    }

                    ForEach(cosmetics.pets) { pet in
                        petCard(pet)
                    }

                    if !cosmetics.petMessage.isEmpty {
                        Text(cosmetics.petMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(hex: palette.muted))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                }
                .padding(16)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Pet Shop")
        .navigationBarTitleDisplayMode(.inline)
        .task { await cosmetics.refresh() }
        .sheet(isPresented: $showsCoinStore) {
            CoinStorePlaceholderView()
                .environmentObject(cosmetics)
        }
    }

    private var walletHeader: some View {
        HStack(spacing: 12) {
            Label("\(cosmetics.coinBalance)", systemImage: "circle.fill")
                .font(.headline.monospacedDigit().weight(.black))
                .foregroundStyle(.yellow)
                .accessibilityLabel("\(cosmetics.coinBalance) coins")
            Spacer()
            Button {
                showsCoinStore = true
            } label: {
                Label("Buy Coins", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: palette.accent))
            .foregroundStyle(.black)
            .accessibilityIdentifier("pet-buy-coins")
        }
        .padding(14)
        .background(
            Color(hex: palette.surface).opacity(palette.isLight ? 0.94 : 0.86),
            in: RoundedRectangle(cornerRadius: palette.cornerRadius))
    }

    private func petCard(_ item: CosmeticCatalogItem) -> some View {
        let presentation = PetPresentation.resolve(item.id)
        let action = CosmeticCatalog.petAction(
            petID: item.id,
            owned: cosmetics.ownedPetIDs,
            selectedID: cosmetics.selectedPetID,
            visible: cosmetics.petVisible
        )

        return HStack(spacing: 14) {
            PetCompanionView(petID: item.id, size: 72, includesHabitat: true)
                .frame(width: 92)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(item.name).font(.title3.weight(.black))
                    if presentation.usesPlaceholderArt {
                        Text("PLACEHOLDER")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(.orange.opacity(0.20), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
                Text(presentation.kind)
                    .font(.caption)
                    .foregroundStyle(Color(hex: palette.muted))
                Text(cosmetics.ownedPetIDs.contains(item.id) ? "Owned" : "\(item.priceCoins) coins")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(Color(hex: palette.muted))

                Button {
                    Task { await cosmetics.performPetAction(item) }
                } label: {
                    HStack(spacing: 6) {
                        if cosmetics.pendingPetID == item.id { ProgressView().controlSize(.small) }
                        Text(petActionLabel(action, item: item))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: palette.accent))
                .foregroundStyle(.black)
                .disabled(cosmetics.isLoading || cosmetics.isEconomyMutationPending)
                .accessibilityIdentifier("pet-action-\(item.id)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Color(hex: palette.foreground))
        .padding(14)
        .background(
            Color(hex: palette.surface).opacity(palette.isLight ? 0.94 : 0.86),
            in: RoundedRectangle(cornerRadius: palette.cornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: palette.cornerRadius)
                .stroke(
                    item.id == cosmetics.selectedPetID ? Color(hex: palette.accent) : .clear,
                    lineWidth: 2
                )
        }
    }

    private func petActionLabel(_ action: PetShopAction, item: CosmeticCatalogItem) -> String {
        switch action {
        case .buy:
            if item.id == "pancake" {
                return "Art pending"
            }
            return cosmetics.isAuthenticated ? "Buy · \(item.priceCoins)" : "Sign in to buy"
        case .select: return "Select"
        case .hide: return "Hide"
        case .show: return "Show"
        }
    }
}
