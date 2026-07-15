import SwiftUI

struct ThemeShopView: View {
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
                        ProgressView("Loading themes…")
                            .tint(Color(hex: palette.accent))
                            .foregroundStyle(Color(hex: palette.foreground))
                    }

                    ForEach(cosmetics.themes) { theme in
                        themeCard(theme)
                    }

                    if !cosmetics.themeMessage.isEmpty {
                        Text(cosmetics.themeMessage)
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
        .navigationTitle("Theme Shop")
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
            .accessibilityIdentifier("theme-buy-coins")
        }
        .padding(14)
        .background(
            Color(hex: palette.surface).opacity(palette.isLight ? 0.94 : 0.86),
            in: RoundedRectangle(cornerRadius: palette.cornerRadius))
    }

    private func themeCard(_ item: CosmeticCatalogItem) -> some View {
        let theme = ThemePalette.resolve(item.id)
        let action = CosmeticCatalog.themeAction(
            themeID: item.id,
            owned: cosmetics.ownedThemeIDs,
            selectedID: cosmetics.selectedThemeID
        )

        return HStack(spacing: 14) {
            ThemePreview(theme: theme)
                .frame(width: 92)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.title3.weight(.black))
                Text(cosmetics.ownedThemeIDs.contains(item.id) ? "Owned" : "\(item.priceCoins) coins")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(Color(hex: palette.muted))

                Button {
                    Task { await cosmetics.performThemeAction(item) }
                } label: {
                    HStack(spacing: 6) {
                        if cosmetics.pendingThemeID == item.id { ProgressView().controlSize(.small) }
                        Text(themeActionLabel(action, item: item))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(action == .selected ? .secondary : Color(hex: theme.accent))
                .foregroundStyle(.black)
                .disabled(
                    action == .selected || cosmetics.isLoading
                        || cosmetics.isEconomyMutationPending
                )
                .accessibilityIdentifier("theme-action-\(item.id)")
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
                    item.id == cosmetics.selectedThemeID ? Color(hex: theme.accent) : .clear,
                    lineWidth: 2
                )
        }
    }

    private func themeActionLabel(_ action: ThemeShopAction, item: CosmeticCatalogItem) -> String {
        switch action {
        case .selected: "Selected"
        case .select: "Select"
        case .buy:
            cosmetics.isAuthenticated ? "Buy · \(item.priceCoins)" : "Sign in to buy"
        }
    }
}
