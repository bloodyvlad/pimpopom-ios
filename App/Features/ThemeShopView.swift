import SwiftUI

struct ThemeShopView: View {
    @EnvironmentObject private var cosmetics: CosmeticsController
    @EnvironmentObject private var preferences: AppPreferences
    let onOpenProfile: () -> Void
    @State private var showsCoinStore = false
    @State private var opensProfileAfterStore = false

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
                            .font(palette.appFont(size: 13, weight: .semibold, relativeTo: .footnote))
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
        .sheet(
            isPresented: $showsCoinStore,
            onDismiss: openProfileAfterStore
        ) {
            CoinStoreView(onOpenProfile: {
                opensProfileAfterStore = true
                showsCoinStore = false
            })
        }
    }

    private func openProfileAfterStore() {
        guard opensProfileAfterStore else { return }
        opensProfileAfterStore = false
        onOpenProfile()
    }

    private var walletHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                PixelCoinView(size: 18)
                Text("\(cosmetics.coinBalance)")
                    .font(palette.appFont(size: 17, weight: .black, relativeTo: .headline))
                    .monospacedDigit()
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

        return VStack(spacing: 8) {
            Button {
                // A tile selects an owned theme; paid purchases use the explicit button.
                if action == .select { Task { await cosmetics.performThemeAction(item) } }
            } label: {
                VStack(spacing: 7) {
                    ThemePreview(theme: theme, showsGlyphs: preferences.glyphsEnabled)
                        .frame(maxWidth: .infinity)
                    HStack(spacing: 5) {
                        Text(item.name)
                            .font(palette.appFont(size: 15, weight: .black, relativeTo: .body))
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
                            .foregroundStyle(Color(hex: "#ffc629"))
                        }
                    }
                }
                .foregroundStyle(Color(hex: palette.foreground))
                .webCardStyle(
                    theme: palette,
                    selectedAccent: action == .selected ? Color(hex: palette.accent) : nil,
                    padding: 7
                )
            }
            .buttonStyle(.plain)
            .disabled(cosmetics.isLoading || cosmetics.isEconomyMutationPending)
            .accessibilityLabel(item.name)
            .accessibilityIdentifier("theme-preview-\(item.id)")

            Button {
                guard action != .selected else { return }
                if action == .buy, !cosmetics.isAuthenticated {
                    onOpenProfile()
                } else if action == .buy, !cosmetics.canAfford(item) {
                    showsCoinStore = true
                } else {
                    Task { await cosmetics.performThemeAction(item) }
                }
            } label: {
                HStack(spacing: 4) {
                    if cosmetics.pendingThemeID == item.id { ProgressView().controlSize(.small) }
                    Text(themeActionLabel(action, item: item))
                        .font(palette.appFont(size: 12, weight: .bold, relativeTo: .caption))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: palette, accent: Color(hex: palette.themesAccent), minimumHeight: 44
                )
            )
            .disabled(action == .selected || cosmetics.isLoading || cosmetics.isEconomyMutationPending)
            .accessibilityIdentifier("theme-action-\(item.id)")
            .accessibilityAddTraits(action == .selected ? .isSelected : [])
        }
    }

    private func themeActionLabel(_ action: ThemeShopAction, item: CosmeticCatalogItem) -> String {
        switch action {
        case .selected: "Selected"
        case .select: "Select"
        case .buy:
            cosmetics.isAuthenticated ? "Buy for \(item.priceCoins) coins" : "Sign in to buy"
        }
    }
}
