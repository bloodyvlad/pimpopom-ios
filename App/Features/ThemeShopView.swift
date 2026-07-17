import SwiftUI

struct ThemeShopView: View {
    @EnvironmentObject private var cosmetics: CosmeticsController
    @EnvironmentObject private var preferences: AppPreferences
    @State private var showsCoinStore = false

    private var palette: ThemePalette { cosmetics.theme }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: palette)

            ScrollView {
                VStack(spacing: 12) {
                    walletHeader

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                        ],
                        spacing: 8
                    ) {
                        ForEach(cosmetics.themes) { theme in
                            themeCard(theme)
                        }
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

            if cosmetics.isLoading {
                WebLoadingOverlay(theme: palette, label: "Loading themes")
            }
        }
        .navigationTitle("Theme Shop")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Theme Shop")
                    .font(palette.appFont(size: 19, weight: .black, relativeTo: .headline))
                    .foregroundStyle(Color(hex: palette.foreground))
            }
        }
        .task { await cosmetics.refresh() }
        .sheet(isPresented: $showsCoinStore) {
            CoinStorePlaceholderView()
                .environmentObject(cosmetics)
        }
    }

    private var walletHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                PixelCoinView(size: 18)
                Text("\(cosmetics.coinBalance)")
                    .font(.headline.monospacedDigit().weight(.black))
            }
            .foregroundStyle(.yellow)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(cosmetics.coinBalance) coins")
            Spacer()
            Button {
                showsCoinStore = true
            } label: {
                Label("Buy Coins", systemImage: "plus.circle.fill")
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: palette,
                    accent: Color(hex: palette.themesAccent),
                    minimumHeight: 44
                )
            )
            .accessibilityIdentifier("theme-buy-coins")
        }
        .foregroundStyle(Color(hex: palette.foreground))
        .webCardStyle(theme: palette, padding: 12)
    }

    private func themeCard(_ item: CosmeticCatalogItem) -> some View {
        let theme = ThemePalette.resolve(item.id)
        let action = CosmeticCatalog.themeAction(
            themeID: item.id,
            owned: cosmetics.ownedThemeIDs,
            selectedID: cosmetics.selectedThemeID
        )

        return VStack(spacing: 6) {
            ThemePreview(theme: theme, showsGlyphs: preferences.glyphsEnabled)
                .frame(maxWidth: .infinity)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(item.name)
                    .font(palette.appFont(size: 15, weight: .black, relativeTo: .body))
                    .lineLimit(1)
                Spacer(minLength: 3)
                if cosmetics.ownedThemeIDs.contains(item.id) {
                    Text(item.priceCoins == 0 ? "Free" : "Owned")
                        .font(palette.appFont(size: 11, weight: .bold, relativeTo: .caption))
                        .foregroundStyle(Color(hex: palette.muted))
                } else {
                    HStack(spacing: 3) {
                        PixelCoinView(size: 12)
                        Text("\(item.priceCoins)")
                    }
                    .font(palette.appFont(size: 12, weight: .black, relativeTo: .caption))
                    .foregroundStyle(.yellow)
                }
            }

            Button {
                Task { await cosmetics.performThemeAction(item) }
            } label: {
                HStack(spacing: 5) {
                    if cosmetics.pendingThemeID == item.id { ProgressView().controlSize(.small) }
                    Text(themeActionLabel(action, item: item))
                }
                .frame(maxWidth: .infinity)
                .font(palette.appFont(size: 12, weight: .bold, relativeTo: .caption))
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: palette,
                    accent: action == .selected
                        ? Color(hex: palette.isLight ? "#159dc7" : theme.accent)
                        : nil,
                    minimumHeight: 32
                )
            )
            .disabled(
                action == .selected || cosmetics.isLoading
                    || cosmetics.isEconomyMutationPending
            )
            .accessibilityIdentifier("theme-action-\(item.id)")
        }
        .foregroundStyle(Color(hex: palette.foreground))
        .webCardStyle(
            theme: palette,
            selectedAccent: item.id == cosmetics.selectedThemeID
                ? Color(hex: palette.isLight ? "#159dc7" : theme.accent)
                : nil,
            padding: 7
        )
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
