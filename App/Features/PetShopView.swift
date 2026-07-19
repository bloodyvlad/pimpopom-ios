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

                    if !cosmetics.petMessage.isEmpty {
                        Text(cosmetics.petMessage)
                            .font(palette.appFont(size: 13, weight: .semibold, relativeTo: .footnote))
                            .foregroundStyle(Color(hex: palette.muted))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("pet-shop-status")
                    }

                    ForEach(cosmetics.pets) { pet in
                        petCard(pet)
                    }
                }
                .padding(16)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }

            if cosmetics.isLoading {
                WebLoadingOverlay(theme: palette, label: "Loading pets")
            }
        }
        .navigationTitle("Pet Shop")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Pet Shop")
                    .font(palette.appFont(size: 19, weight: .black, relativeTo: .headline))
                    .foregroundStyle(Color(hex: palette.foreground))
            }
        }
        .task { await cosmetics.refresh() }
        .sheet(isPresented: $showsCoinStore) {
            CoinStoreView()
        }
    }

    private var walletHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                PixelCoinView(size: 18)
                Text("\(cosmetics.coinBalance)")
                    .font(palette.appFont(size: 17, weight: .black, relativeTo: .headline))
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
                    accent: Color(hex: palette.petsAccent),
                    minimumHeight: 44
                )
            )
            .accessibilityIdentifier("pet-buy-coins")
        }
        .foregroundStyle(Color(hex: palette.foreground))
        .webCardStyle(theme: palette, padding: 12)
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
            PetShopPreviewButton(item: item, palette: palette)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(item.name)
                        .font(palette.appFont(size: 20, weight: .black, relativeTo: .title3))
                    if presentation.usesPlaceholderArt {
                        Text("PLACEHOLDER")
                            .font(palette.appFont(size: 8, weight: .black, relativeTo: .caption2))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(.orange.opacity(0.20), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
                Text(presentation.kind)
                    .font(palette.appFont(size: 12, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(Color(hex: palette.muted))
                if cosmetics.ownedPetIDs.contains(item.id) {
                    Text("Owned")
                        .font(palette.appFont(size: 12, weight: .bold, relativeTo: .caption))
                        .foregroundStyle(Color(hex: palette.muted))
                } else {
                    HStack(spacing: 4) {
                        PixelCoinView(size: 13)
                        Text("\(item.priceCoins)")
                    }
                    .font(palette.appFont(size: 12, weight: .black, relativeTo: .caption))
                    .foregroundStyle(Color(hex: "#ffc629"))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(item.priceCoins) coins")
                }

                Button {
                    Task { await cosmetics.performPetAction(item) }
                } label: {
                    HStack(spacing: 6) {
                        if cosmetics.pendingPetID == item.id { ProgressView().controlSize(.small) }
                        if action == .buy, cosmetics.isAuthenticated {
                            PixelCoinView(size: 13)
                        }
                        Text(petActionLabel(action, item: item))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    WebSecondaryButtonStyle(
                        theme: palette,
                        accent: Color(hex: palette.petsAccent),
                        minimumHeight: 44
                    )
                )
                .disabled(cosmetics.isLoading || cosmetics.isEconomyMutationPending)
                .accessibilityIdentifier("pet-action-\(item.id)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Color(hex: palette.foreground))
        .webCardStyle(
            theme: palette,
            selectedAccent: item.id == cosmetics.selectedPetID
                ? Color(hex: palette.petsAccent)
                : nil,
            padding: 14
        )
    }

    private func petActionLabel(_ action: PetShopAction, item: CosmeticCatalogItem) -> String {
        switch action {
        case .buy:
            return cosmetics.isAuthenticated ? "Buy · \(item.priceCoins)" : "Sign in to buy"
        case .select: return "Select"
        case .hide: return "Hide"
        case .show: return "Show"
        }
    }
}

private struct PetShopPreviewButton: View {
    let item: CosmeticCatalogItem
    let palette: ThemePalette

    @State private var animationTrigger = 0
    @State private var isAnimating = false
    @State private var resetTask: Task<Void, Never>?
    @State private var facing = PetFacing.front

    var body: some View {
        PetCompanionView(
            petID: item.id,
            size: 64,
            placement: .shop,
            animationTrigger: animationTrigger,
            facing: facing
        )
        .frame(width: 80, height: 80)
        .background(
            Color(hex: palette.backgroundTop).opacity(palette.isLight ? 0.24 : 0.70),
            in: RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 13)
        )
        .overlay {
            RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 13)
                .stroke(Color(hex: palette.foreground).opacity(0.10))
        }
        .contentShape(Rectangle())
        .gesture(
            SpatialTapGesture()
                .onEnded { value in play(at: value.location) }
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { play(at: CGPoint(x: 72, y: 40)) }
        .accessibilityLabel("Play \(item.name) animation")
        .accessibilityValue(
            "\(isAnimating ? "Animating" : "Idle") · preview \(animationTrigger)"
        )
        .accessibilityIdentifier("pet-preview-\(item.id)")
        .onDisappear { resetTask?.cancel() }
    }

    private func play(at location: CGPoint) {
        let geometry = PetArtworkGeometry.resolve(
            placement: .shop,
            petID: item.id,
            spriteSize: 64
        )
        facing = PetTapFollow.resolve(
            pointerX: location.x,
            petCenterX: geometry.spriteOffset.width + 32,
            interactionWidth: 80,
            current: facing
        )
        animationTrigger += 1
        isAnimating = true
        resetTask?.cancel()
        let trigger = animationTrigger
        resetTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1_500))
            guard !Task.isCancelled, animationTrigger == trigger else { return }
            isAnimating = false
        }
    }
}
