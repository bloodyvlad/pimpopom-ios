import PimPoPomCore
import SwiftUI
import UIKit

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var backend: BackendClient
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var cosmetics: CosmeticsController
    @EnvironmentObject private var achievements: AchievementsController
    @EnvironmentObject private var audio: AudioController
    @EnvironmentObject private var quickActions: HomeQuickActionController
    @EnvironmentObject private var gameCenter: GameCenterService
    @EnvironmentObject private var gameCenterAutoLink: GameCenterAutoLinkController
    @EnvironmentObject private var multiplayer: MultiplayerController
    @EnvironmentObject private var purchases: PurchaseController
    @EnvironmentObject private var ads: AdsController

    let googleIdentity: GoogleIdentityService
    let appleIdentity: AppleIdentityService

    @State private var navigationPath: [GameMode] = []
    @State private var completedAccountStartup: AdsController.ConfirmedAccountStartupID?
    @State private var showsProfile = false
    @State private var showsAchievements = false
    @State private var opensProfileAfterAchievements = false
    @State private var showsCoinStore = false
    @State private var showsRemoveAdsStore = false
    @State private var showsIconSettings = false
    @State private var showsScreenshotThemeShop = false
    @State private var showsScreenshotPetShop = false
    @State private var showsScreenshotLeaderboard = false
    @State private var showsMultiplayerUITestFixture = false
    @State private var tutorialFixtureMode: HowToPlayMode?
    @State private var motivationIndex: Int?
    @State private var hasCompletedGameThisLaunch = false
    @State private var isMenuSurfaceVisible = true
    @State private var menuPetFacing = PetFacing.front
    @State private var menuPetSleeping = false
    @State private var menuPetActivity = 0
    @State private var introStampSeed = MenuMotivation.introStampSeed(
        arguments: ProcessInfo.processInfo.arguments
    )

    private var palette: ThemePalette { cosmetics.theme }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppThemeBackground(theme: palette)

                GeometryReader { proxy in
                    menuPanel(
                        screenWidth: proxy.size.width,
                        screenHeight: proxy.size.height,
                        usesCompactRemoveAds: MenuRemoveAdsPlacement.usesCompactHeader(
                            screenSize: UIScreen.main.bounds.size
                        )
                    )
                    .frame(maxWidth: WebMenuMetrics.maximumPanelWidth)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height,
                        alignment: .top
                    )
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        SpatialTapGesture(coordinateSpace: .named("menu-space"))
                            .onEnded {
                                handleMenuTap(
                                    at: $0.location,
                                    screenWidth: proxy.size.width
                                )
                            }
                    )
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isMenuSurfaceVisible, ads.reservesBannerSlot {
                    AdBannerSlot(
                        placement: .menu,
                        isSurfaceVisible: isMenuSurfaceVisible
                    )
                    .frame(maxWidth: WebMenuMetrics.maximumPanelWidth)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                }
            }
            .onAppear { isMenuSurfaceVisible = true }
            .onDisappear { isMenuSurfaceVisible = false }
            .coordinateSpace(name: "menu-space")
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: GameMode.self) { mode in
                if mode == .arcade {
                    HowToPlayEntryView(mode: .arcade) { gameDestination(mode) }
                } else {
                    gameDestination(mode)
                }
            }
            .navigationDestination(isPresented: $showsScreenshotThemeShop) {
                ThemeShopView()
            }
            .navigationDestination(isPresented: $showsScreenshotPetShop) {
                PetShopView()
            }
            .navigationDestination(isPresented: $showsScreenshotLeaderboard) {
                LeaderboardView()
            }
        }
        .tint(Color(hex: palette.foreground))
        .sheet(
            isPresented: $showsProfile,
            onDismiss: {
                Task {
                    guard ads.isAgeConfirmed(for: backend.sessionState) else { return }
                    await achievements.refresh(showLoading: false)
                }
            }
        ) {
            ProfileView(
                googleIdentity: googleIdentity,
                appleIdentity: appleIdentity,
                onDismiss: { showsProfile = false }
            )
            .environmentObject(backend)
            .environmentObject(cosmetics)
            .environmentObject(gameCenter)
        }
        .sheet(
            isPresented: $showsAchievements,
            onDismiss: {
                guard opensProfileAfterAchievements else { return }
                opensProfileAfterAchievements = false
                showsProfile = true
            }
        ) {
            AchievementsView(
                onDismiss: { showsAchievements = false },
                onOpenProfile: {
                    opensProfileAfterAchievements = true
                    showsAchievements = false
                }
            )
        }
        .sheet(isPresented: $showsCoinStore) {
            CoinStoreView()
        }
        .sheet(isPresented: $showsRemoveAdsStore) {
            CoinStoreView(offer: .removeAds)
        }
        .sheet(isPresented: $showsIconSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showsIconSettings = false }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showsMultiplayerUITestFixture) {
            NavigationStack {
                MultiplayerFlowView()
            }
        }
        .fullScreenCover(item: $tutorialFixtureMode) { mode in
            HowToPlayReplayView(mode: mode)
        }
        .task(id: ads.ageConfirmationGeneration) {
            let generation = ads.ageConfirmationGeneration
            guard isCurrentAge(generation) else { return }
            configureDebugLaunch()
            openPendingQuickAction()
            audio.setApplicationActive(scenePhase == .active)
            ads.setApplicationActive(scenePhase == .active)
            multiplayer.setApplicationActive(scenePhase == .active)
            audio.configure(themeID: cosmetics.selectedThemeID, preferences: preferences)
            audio.setMusicContext(.menu)
            audio.playLaunchSting()
            // Resolve the saved account before UMP, so a different player cannot
            // inherit the previous player's stored adult advertising treatment.
            await restoreSession(ageGeneration: generation)
            guard isCurrentAge(generation) else { return }
            await ads.bootstrap(session: backend.sessionState)
        }
        // A later successful session lookup must resume deferred account services
        // even when an offline launch kept the same locally declared age.
        .task(id: ads.confirmedAccountStartupID(for: backend.sessionState)) {
            guard let startup = ads.confirmedAccountStartupID(for: backend.sessionState) else { return }
            guard completedAccountStartup != startup else { return }
            let generation = startup.ageGeneration
            @MainActor func isCurrentAccount() -> Bool {
                isCurrentAge(generation)
                    && ads.confirmedAccountStartupID(for: backend.sessionState) == startup
            }
            guard isCurrentAccount() else { return }
            gameCenter.authenticateAtLaunch()
            gameCenterAutoLink.reconcile()
            purchases.startTransactionListeners()
            await purchases.loadProducts()
            guard isCurrentAccount() else { return }
            await purchases.reconcileOutstandingTransactions()
            guard isCurrentAccount() else { return }
            await cosmetics.refresh()
            guard isCurrentAccount() else { return }
            await achievements.refresh(showLoading: false)
            guard isCurrentAccount() else { return }
            completedAccountStartup = startup
        }
        .onChange(of: cosmetics.selectedThemeID) { _, themeID in
            audio.configure(themeID: themeID, preferences: preferences)
        }
        .onChange(of: preferences.soundEffectsEnabled) { _, _ in configureAudio() }
        .onChange(of: preferences.soundEffectsVolume) { _, _ in configureAudio() }
        .onChange(of: preferences.musicEnabled) { _, _ in configureAudio() }
        .onChange(of: preferences.musicVolume) { _, _ in configureAudio() }
        .onChange(of: quickActions.hasPendingChangeIconRequest) { _, pending in
            if pending { openPendingQuickAction() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard ads.allowsApp else { return }
            let generation = ads.ageConfirmationGeneration
            audio.setApplicationActive(phase == .active)
            ads.setApplicationActive(phase == .active)
            multiplayer.setApplicationActive(phase == .active)
            if phase == .active, navigationPath.isEmpty {
                audio.setMusicContext(.menu)
            }
            if phase == .active, let startup = ads.confirmedAccountStartupID(for: backend.sessionState) {
                Task {
                    guard isCurrentAge(generation) else { return }
                    await ads.retryEligibilityIfNeeded()
                    guard isCurrentAge(generation),
                        ads.confirmedAccountStartupID(for: backend.sessionState) == startup
                    else { return }
                    gameCenter.authenticateAtLaunch()
                    gameCenterAutoLink.reconcile()
                    await purchases.reconcileOutstandingTransactions()
                }
            }
        }
        .onChange(of: backend.sessionState) { _, _ in
            guard ads.allowsApp else { return }
            let generation = ads.ageConfirmationGeneration
            Task {
                await ads.updateSession(backend.sessionState)
                guard isCurrentAge(generation),
                    ads.confirmedAccountStartupID(for: backend.sessionState) != nil
                else { return }
                gameCenterAutoLink.reconcile()
                multiplayer.refreshAvailability()
                await purchases.reconcileOutstandingTransactions()
            }
        }
        .onChange(of: backend.isAuthenticated) { wasAuthenticated, isAuthenticated in
            guard wasAuthenticated != isAuthenticated,
                ads.isAgeConfirmed(for: backend.sessionState)
            else { return }
            gameCenterAutoLink.reconcile()
        }
        .onChange(of: backend.profile?.id) { oldPlayerID, newPlayerID in
            guard oldPlayerID != newPlayerID,
                ads.isAgeConfirmed(for: backend.sessionState)
            else { return }
            gameCenter.clearRuntimeVerification()
            gameCenterAutoLink.reconcile()
        }
        .onChange(of: gameCenter.state) { _, _ in
            guard ads.isAgeConfirmed(for: backend.sessionState) else { return }
            gameCenterAutoLink.reconcile()
            multiplayer.refreshAvailability()
        }
        .onChange(of: navigationPath.isEmpty) { wasEmpty, isEmpty in
            guard isEmpty, !wasEmpty else { return }
            Task {
                guard ads.isAgeConfirmed(for: backend.sessionState) else { return }
                await achievements.refresh(showLoading: false)
            }
        }
        .onChange(of: cosmetics.ownedPetIDs) { oldIDs, newIDs in
            guard newIDs.count > oldIDs.count else { return }
            Task {
                guard ads.isAgeConfirmed(for: backend.sessionState) else { return }
                await achievements.refresh(showLoading: false)
            }
        }
    }

    private func menuPanel(
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        usesCompactRemoveAds: Bool
    ) -> some View {
        let largePhoneScale = WebMenuMetrics.largePhoneScale(screenWidth: screenWidth)
        let menuPetSize = WebMenuMetrics.menuPetSize(screenWidth: screenWidth)

        return ZStack(alignment: .topTrailing) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Main menu")
                .accessibilityValue("Theme \(palette.id)")
                .accessibilityIdentifier("menu-dialog")
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                utilityHeader(usesCompactRemoveAds: usesCompactRemoveAds)
                hintStage(
                    screenWidth: screenWidth,
                    usesCompactHeight: screenHeight < 700
                )
                actionStack
                Spacer(minLength: 6)
                menuFooter(usesCompactRemoveAds: usesCompactRemoveAds)
            }

            if let petID = cosmetics.displayedPetID {
                PetCompanionView(
                    petID: petID,
                    size: menuPetSize,
                    placement: .menu,
                    animationTrigger: menuPetActivity,
                    facing: menuPetFacing,
                    isSleeping: menuPetSleeping
                )
                .offset(
                    x: WebMenuMetrics.menuPetBaseHorizontalOffset
                        - screenWidth * WebMenuMetrics.menuPetHorizontalShiftFraction,
                    y: WebMenuMetrics.headerHeight + 17 * largePhoneScale
                )
                .task(id: "\(petID)-\(menuPetActivity)-\(scenePhase)") {
                    menuPetSleeping = false
                    guard scenePhase == .active, navigationPath.isEmpty else { return }
                    try? await Task.sleep(for: .seconds(5))
                    guard !Task.isCancelled else { return }
                    menuPetSleeping = true
                }
                .allowsHitTesting(false)
                .accessibilityIdentifier("menu-pet-\(petID)")
            }
        }
        .foregroundStyle(Color(hex: palette.foreground))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task(id: "\(cosmetics.displayedPetID ?? "none")-\(scenePhase)") {
            await runScreenshotMenuAutoplay(screenWidth: screenWidth)
        }
    }

    private func utilityHeader(usesCompactRemoveAds: Bool) -> some View {
        HStack(spacing: 8) {
            PimPoPomWordmark(theme: palette)
                .frame(maxWidth: .infinity, alignment: .leading)

            if usesCompactRemoveAds, shouldShowRemoveAds {
                Button {
                    showsRemoveAdsStore = true
                } label: {
                    ZStack {
                        Text("Ad")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                        Image(systemName: "nosign")
                            .font(.system(size: 27.5, weight: .bold))
                    }
                    .frame(
                        width: WebMenuMetrics.utilityTarget,
                        height: WebMenuMetrics.utilityTarget
                    )
                }
                .buttonStyle(
                    WebSecondaryButtonStyle(
                        theme: palette,
                        accent: Color(hex: palette.petsAccent),
                        minimumHeight: WebMenuMetrics.utilityTarget
                    )
                )
                .frame(width: WebMenuMetrics.utilityTarget)
                .accessibilityLabel("Remove Ads")
                .accessibilityHint("Opens the App Store purchase and restore options")
                .accessibilityIdentifier("remove-ads")
            }

            Button {
                showsCoinStore = true
            } label: {
                ZStack {
                    PixelCoinView(size: 19)
                }
                .frame(
                    width: WebMenuMetrics.utilityTarget,
                    height: WebMenuMetrics.utilityTarget
                )
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: palette,
                    accent: Color(hex: palette.achievementsAccent),
                    minimumHeight: WebMenuMetrics.utilityTarget
                )
            )
            .frame(width: WebMenuMetrics.utilityTarget)
            .accessibilityLabel("Buy Coins. \(cosmetics.coinBalance) coins")
            .accessibilityIdentifier("open-coin-store")
            .overlay(alignment: .bottomTrailing) {
                WebUtilityBadge(
                    text: "\(cosmetics.coinBalance)",
                    kind: .coin,
                    theme: palette
                )
                .offset(x: 5, y: 5)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .accessibilityIdentifier("coin-balance-badge")
            }

            NavigationLink {
                LeaderboardView()
            } label: {
                ZStack {
                    if palette.isPixel {
                        ThemedMenuFeatureIcon(systemImage: "trophy.fill", theme: palette)
                            .frame(width: 22, height: 22)
                    } else {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .frame(
                    width: WebMenuMetrics.utilityTarget,
                    height: WebMenuMetrics.utilityTarget
                )
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: palette,
                    borderAccent: Color(
                        hex: WebMenuBorderAccents.leaderboardHex(theme: palette)
                    ),
                    minimumHeight: WebMenuMetrics.utilityTarget
                )
            )
            .frame(width: WebMenuMetrics.utilityTarget)
            .accessibilityLabel("Leaderboard")
            .accessibilityValue(arcadeRank.map { "Position #\($0)" } ?? "Unranked")
            .accessibilityIdentifier("open-leaderboard")
            .overlay(alignment: .topTrailing) {
                if let rank = arcadeRank {
                    WebUtilityBadge(text: "#\(rank)", kind: .rank, theme: palette)
                        .offset(x: 5, y: -5)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .accessibilityIdentifier("leaderboard-rank-badge")
                }
            }

            Button {
                showsProfile = true
            } label: {
                if palette.isPixel {
                    ThemedMenuFeatureIcon(
                        systemImage: backend.profile == nil ? "person" : "person.fill", theme: palette
                    )
                    .frame(width: 22, height: 22)
                } else {
                    Image(systemName: backend.profile == nil ? "person" : "person.fill")
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: palette,
                    borderAccent: Color(
                        hex: WebMenuBorderAccents.profileHex(theme: palette)
                    ),
                    minimumHeight: WebMenuMetrics.utilityTarget
                )
            )
            .frame(width: WebMenuMetrics.utilityTarget)
            .accessibilityLabel(backend.profile == nil ? "Profile. Signed out" : "Profile. Signed in")
            .accessibilityIdentifier("open-profile")
        }
        .frame(minHeight: WebMenuMetrics.headerHeight)
    }

    private func hintStage(
        screenWidth: CGFloat,
        usesCompactHeight: Bool
    ) -> some View {
        let largePhoneScale = WebMenuMetrics.largePhoneScale(screenWidth: screenWidth)
        let menuPetSize = WebMenuMetrics.menuPetSize(screenWidth: screenWidth)

        return Group {
            if motivationIsVisible {
                Button {
                    advanceMotivation()
                } label: {
                    GlowStampView(
                        text: MenuMotivation.hints[currentMotivationIndex],
                        tone: motivationColor,
                        theme: palette,
                        tilt: MenuMotivation.tilts[
                            currentMotivationIndex % MenuMotivation.tilts.count
                        ],
                        size: 16 * WebMenuMetrics.motivationScale * largePhoneScale,
                        horizontalPadding: 10 * largePhoneScale,
                        verticalPadding: 5 * largePhoneScale
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(
                    x: screenWidth * WebMenuMetrics.motivationHorizontalShiftFraction
                        + WebMenuMetrics.motivationHorizontalNudge
                )
                .accessibilityIdentifier("menu-motivation")
                .task(id: motivationTaskID) {
                    guard motivationCanRotate else { return }
                    if motivationIndex == nil {
                        advanceMotivation()
                        return
                    }
                    try? await Task.sleep(for: MenuMotivation.rotationInterval)
                    guard !Task.isCancelled, motivationCanRotate else { return }
                    advanceMotivation()
                }
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(introHints.enumerated()), id: \.offset) { index, hint in
                        GlowStampView(
                            text: hint.text,
                            tone: Color(hex: hint.color),
                            theme: palette,
                            tilt: MenuMotivation.tilts[
                                (introStampSeed + index) % MenuMotivation.tilts.count
                            ],
                            size: 12 * largePhoneScale,
                            horizontalPadding: 9 * largePhoneScale,
                            verticalPadding: 4 * largePhoneScale
                        )
                    }
                }
                .offset(x: WebMenuMetrics.introRulesHorizontalOffset)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Tap your color. Become the fastest. Collect rewards.")
                .accessibilityIdentifier("menu-intro-stamps")
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: usesCompactHeight ? 78 : WebMenuMetrics.hintHeight,
            alignment: .leading
        )
        .padding(.trailing, cosmetics.displayedPetID == nil ? 0 : menuPetSize + 12)
        .padding(.top, usesCompactHeight ? 2 : 8)
        .padding(.bottom, usesCompactHeight ? 4 : 14)
    }

    private var introHints: [(text: String, color: String)] {
        if palette.isLight {
            [
                ("Tap your color", "#087c9b"),
                ("Become the fastest", "#bb257b"),
                ("Collect rewards!", "#6942b7"),
            ]
        } else {
            [
                ("Tap your color", "#62f8ff"),
                ("Become the fastest", "#ff71c7"),
                ("Collect rewards!", "#b798ff"),
            ]
        }
    }

    private var actionStack: some View {
        VStack(spacing: WebMenuMetrics.actionGap) {
            VStack(alignment: .leading, spacing: 7) {
                Text("GAME MODE")
                    .font(palette.appFont(size: 11, weight: .black, relativeTo: .caption))
                    .tracking(1.1)
                    .foregroundStyle(Color(hex: palette.muted))
                    .accessibilityIdentifier("menu-game-mode-label")

                VStack(spacing: WebMenuMetrics.pairedGap) {
                    modeLink(.arcade)
                    modeLink(.zen)
                    MultiplayerMenuLink(
                        availability: multiplayer.availability,
                        theme: palette
                    ) {
                        HowToPlayEntryView(mode: .multiplayer) { MultiplayerFlowView() }
                    }
                }
            }
            .offset(y: WebMenuMetrics.gameModeVerticalOffset)

            Color.clear.frame(
                height: 9 + WebMenuMetrics.achievementsSectionTopOffset
            )

            Button {
                showsAchievements = true
            } label: {
                HStack(spacing: 8) {
                    Text("Achievements")
                        .font(palette.appFont(size: 16, weight: .bold, relativeTo: .body))
                    Spacer(minLength: 6)
                    Text(achievements.menuSummary)
                        .font(palette.appFont(size: 12, weight: .bold, relativeTo: .caption))
                        .foregroundStyle(Color(hex: palette.muted))
                }
                .padding(.horizontal, 14)
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: palette,
                    accent: Color(hex: palette.achievementsAccent)
                )
            )
            .overlay(alignment: .topTrailing) {
                if achievements.payload.authenticated, achievements.claimableCount > 0 {
                    GlowStampView(
                        text: "*",
                        tone: Color(hex: palette.achievementsAccent),
                        theme: palette,
                        tilt: -9,
                        size: 11,
                        horizontalPadding: 6,
                        verticalPadding: 2
                    )
                    .offset(x: 5, y: -6)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .accessibilityLabel("Achievements")
            .accessibilityValue(
                achievements.claimableCount > 0
                    ? "\(achievements.claimableCount) "
                        + (achievements.claimableCount == 1 ? "reward" : "rewards")
                        + " ready to claim"
                    : achievements.menuSummary
            )
            .accessibilityIdentifier("open-achievements")

            HStack(spacing: WebMenuMetrics.pairedGap) {
                NavigationLink {
                    PetShopView()
                } label: {
                    featureLabel(
                        "Pet Shop",
                        systemImage: "pawprint.fill",
                        value: petSummary
                    )
                }
                .buttonStyle(
                    WebSecondaryButtonStyle(
                        theme: palette,
                        accent: Color(hex: palette.petsAccent),
                        minimumHeight: WebMenuMetrics.featureControlHeight
                    )
                )
                .accessibilityIdentifier("open-pet-shop")

                NavigationLink {
                    ThemeShopView()
                } label: {
                    featureLabel(
                        "Themes",
                        systemImage: "paintpalette.fill",
                        value: palette.displayName
                    )
                }
                .buttonStyle(
                    WebSecondaryButtonStyle(
                        theme: palette,
                        accent: Color(hex: palette.themesAccent),
                        minimumHeight: WebMenuMetrics.featureControlHeight
                    )
                )
                .accessibilityIdentifier("open-theme-shop")
            }

            NavigationLink {
                SettingsView()
            } label: {
                HStack(spacing: 12) {
                    Text("Settings")
                    Spacer(minLength: 8)
                    Text(settingsSummary)
                        .font(palette.appFont(size: 12, weight: .bold, relativeTo: .caption))
                        .foregroundStyle(Color(hex: palette.muted))
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: palette,
                    borderAccent: Color.white.opacity(WebMenuBorderAccents.settingsOpacity),
                    borderUnderlay: palette.isLight
                        ? Color(hex: "#3e6c8b").opacity(0.20)
                        : nil
                )
            )
            .accessibilityIdentifier("open-settings")
        }
    }

    private func menuFooter(usesCompactRemoveAds: Bool) -> some View {
        VStack(spacing: 7) {
            if !usesCompactRemoveAds, shouldShowRemoveAds {
                HStack {
                    Spacer(minLength: 0)
                    Button("Remove Ads") { showsRemoveAdsStore = true }
                        .font(palette.appFont(size: 12, weight: .bold, relativeTo: .caption))
                        .buttonStyle(
                            WebSecondaryButtonStyle(
                                theme: palette,
                                minimumHeight: WebMenuMetrics.utilityTarget
                            )
                        )
                        .frame(width: 112)
                        .accessibilityHint("Opens the App Store purchase and restore options")
                        .accessibilityIdentifier("remove-ads")
                }
            }

            Text("© 2026 OTC Software. All rights reserved.")
                .font(palette.appFont(size: 10, weight: .regular, relativeTo: .caption2))
                .foregroundStyle(Color(hex: palette.muted).opacity(0.64))
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("menu-copyright")
        }
        .padding(.top, 8)
    }

    private var shouldShowRemoveAds: Bool {
        guard let session = backend.sessionState else { return false }
        return session.adFree != true
    }

    private func modeLink(_ mode: GameMode) -> some View {
        NavigationLink(value: mode) {
            Text(mode.displayName)
                .font(palette.appFont(size: 20, weight: .black, relativeTo: .title3))
                .foregroundStyle(mode == .arcade ? Color(hex: "#fff7f8") : Color(hex: "#0b2d17"))
        }
        .buttonStyle(
            WebModeButtonStyle(
                theme: palette,
                kind: mode == .arcade ? .arcade : .zen
            )
        )
        .accessibilityIdentifier("mode-\(mode.rawValue)")
    }

    private func gameDestination(_ mode: GameMode) -> some View {
        GameView(mode: mode, reservesAdSpacingForRun: ads.reservesBannerSlot) { completionID in
            ads.recordCompletedSession(id: completionID, mode: mode)
            guard !hasCompletedGameThisLaunch else { return }
            hasCompletedGameThisLaunch = true
            advanceMotivation()
        }
    }

    private func featureLabel(_ title: String, systemImage: String, value: String) -> some View {
        ZStack {
            VStack(spacing: 2) {
                Text(title)
                    .font(palette.appFont(size: 14, weight: .bold, relativeTo: .body))
                    .lineLimit(1)
                Text(value)
                    .font(palette.appFont(size: 11, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(Color(hex: palette.muted))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                ThemedMenuFeatureIcon(systemImage: systemImage, theme: palette)
                    .frame(width: 28, height: 28)
                Spacer(minLength: 0)
            }
            .padding(.leading, WebMenuMetrics.featureIconLeadingInset)
        }
        .frame(maxWidth: .infinity)
    }

    private var arcadeRank: Int? {
        backend.sessionState?.ranks?[GameMode.arcade.rawValue]?.rank
    }

    private var settingsSummary: String {
        "Glyphs \(preferences.glyphsEnabled ? "on" : "off") · FX \(preferences.soundEffectsEnabled ? "on" : "off") · Music \(preferences.musicEnabled ? "on" : "off")"
    }

    private var petSummary: String {
        guard let petID = cosmetics.selectedPetID ?? cosmetics.displayedPetID else { return "No pet" }
        return cosmetics.pets.first(where: { $0.id == petID })?.name ?? petID.capitalized
    }

    private var motivationIsVisible: Bool {
        if hasCompletedGameThisLaunch { return true }
        #if DEBUG
            return ProcessInfo.processInfo.arguments.contains("--ui-test-menu-motivation")
        #else
            return false
        #endif
    }

    private var currentMotivationIndex: Int {
        motivationIndex ?? 0
    }

    private var motivationCanRotate: Bool {
        motivationIsVisible
            && navigationPath.isEmpty
            && scenePhase == .active
            && !showsProfile
            && !showsAchievements
            && !showsCoinStore
            && !showsRemoveAdsStore
    }

    private var motivationTaskID: String {
        "\(motivationIndex ?? -1)-\(navigationPath.count)-\(scenePhase)-\(showsProfile)-\(showsAchievements)-\(showsCoinStore)-\(showsRemoveAdsStore)"
    }

    private var motivationColor: Color {
        let tone = MenuMotivation.tones[currentMotivationIndex % MenuMotivation.tones.count]
        let hex: String
        if palette.isLight {
            hex =
                switch tone {
                case "pink": "#bb257b"
                case "gold": "#966700"
                case "green": "#25812f"
                case "violet": "#6942b7"
                default: "#087c9b"
                }
        } else {
            hex =
                switch tone {
                case "pink": "#ff71c7"
                case "gold": "#ffe15c"
                case "green": "#8df27e"
                case "violet": "#b798ff"
                default: "#62f8ff"
                }
        }
        return Color(hex: hex)
    }

    private func advanceMotivation() {
        let randomValue: Double
        #if DEBUG
            randomValue =
                ProcessInfo.processInfo.arguments.contains("--uitesting")
                ? 0
                : Double.random(in: 0..<1)
        #else
            randomValue = Double.random(in: 0..<1)
        #endif
        motivationIndex = MenuMotivation.nextIndex(
            previous: motivationIndex,
            randomValue: randomValue
        )
    }

    private func handleMenuTap(at location: CGPoint, screenWidth: CGFloat) {
        audio.resumeAfterUserAction()
        guard navigationPath.isEmpty, cosmetics.displayedPetID != nil else { return }
        menuPetSleeping = false
        menuPetFacing = PetTapFollow.resolve(
            pointerX: location.x,
            petCenterX: PetTapFollow.resolveMenuPetCenterX(
                screenWidth: screenWidth,
                canvasWidth: WebMenuMetrics.menuPetSize(screenWidth: screenWidth),
                maximumPanelWidth: WebMenuMetrics.maximumPanelWidth,
                horizontalPadding: 12,
                horizontalOffset: WebMenuMetrics.menuPetBaseHorizontalOffset
                    - screenWidth * WebMenuMetrics.menuPetHorizontalShiftFraction
            ),
            interactionWidth: screenWidth,
            current: menuPetFacing
        )
        menuPetActivity += 1
    }

    private func runScreenshotMenuAutoplay(screenWidth: CGFloat) async {
        #if DEBUG
            guard
                let fixture = ScreenshotFixture.resolve(
                    arguments: ProcessInfo.processInfo.arguments
                ),
                fixture.destination == .menu,
                fixture.autoplayEnabled,
                fixture.petID != nil
            else {
                return
            }

            var pointsRight = true
            while !Task.isCancelled {
                if navigationPath.isEmpty, cosmetics.displayedPetID != nil {
                    handleMenuTap(
                        at: CGPoint(
                            x: screenWidth * (pointsRight ? 0.95 : 0.05),
                            y: 0
                        ),
                        screenWidth: screenWidth
                    )
                    pointsRight.toggle()
                }

                do {
                    try await Task.sleep(for: .seconds(3))
                } catch {
                    return
                }
            }
        #endif
    }

    private func isCurrentAge(_ generation: Int) -> Bool {
        ads.allowsApp && ads.ageConfirmationGeneration == generation && !Task.isCancelled
    }

    private func restoreSession(ageGeneration: Int) async {
        do {
            guard isCurrentAge(ageGeneration) else { return }
            let session = try await backend.loadSession()
            guard isCurrentAge(ageGeneration), !session.authenticated else { return }
            let token = try await googleIdentity.restoreIDTokenIfAvailable()
            guard isCurrentAge(ageGeneration), let token else { return }
            _ = try await backend.login(googleIDToken: token)
        } catch {
            // Profile presents actionable sign-in errors; launch restoration stays non-blocking.
        }
    }

    private func configureDebugLaunch() {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            tutorialFixtureMode = HowToPlayLaunchPolicy.fixtureMode(arguments: arguments)
            if arguments.contains("--ui-test-glyphs-off") {
                preferences.glyphsEnabled = false
            } else if arguments.contains("--ui-test-glyphs-on") {
                preferences.glyphsEnabled = true
            }

            if arguments.contains("--play-arcade") {
                navigationPath = [.arcade]
            } else if arguments.contains("--play-zen") {
                navigationPath = [.zen]
            }
            if arguments.contains("--ui-test-multiplayer-waiting-fixture")
                || arguments.contains("--ui-test-multiplayer-live-fixture")
                || arguments.contains("--ui-test-multiplayer-catch-up-fixture")
                || arguments.contains("--ui-test-multiplayer-hub-fixture")
                || arguments.contains("--ui-test-multiplayer-spectating-fixture")
                || arguments.contains("--ui-test-multiplayer-results-fixture")
            {
                showsMultiplayerUITestFixture = true
            }

            if let fixture = ScreenshotFixture.resolve(arguments: arguments) {
                preferences.glyphsEnabled = true
                preferences.soundEffectsEnabled = true
                preferences.musicEnabled = true
                switch fixture.destination {
                case .menu:
                    break
                case .themeShop:
                    showsScreenshotThemeShop = true
                case .petShop:
                    showsScreenshotPetShop = true
                case .leaderboard:
                    showsScreenshotLeaderboard = true
                case .profile:
                    showsProfile = true
                case .achievements:
                    showsAchievements = true
                case .arcade:
                    navigationPath = [.arcade]
                case .zen:
                    navigationPath = [.zen]
                }
            }
        #endif
    }

    private func configureAudio() {
        audio.resumeAfterUserAction()
        audio.configure(themeID: cosmetics.selectedThemeID, preferences: preferences)
    }

    private func openPendingQuickAction() {
        guard quickActions.consumeChangeIconRequest() else { return }
        showsProfile = false
        showsAchievements = false
        showsCoinStore = false
        showsRemoveAdsStore = false
        showsIconSettings = true
    }
}

#if DEBUG
    #Preview {
        let backend = BackendClient()
        let preferences = AppPreferences()
        let cosmetics = CosmeticsController(backend: backend, preferences: preferences)
        let achievements = AchievementsController(backend: backend)
        let purchases = PurchaseController(creditService: backend, startListeners: false)
        let gameCenter = GameCenterService(arguments: ["--uitesting"])
        let audio = AudioController()
        let gameCenterAutoLink = GameCenterAutoLinkController(
            backend: backend,
            gameCenter: gameCenter
        )
        let multiplayer = MultiplayerController(
            backend: backend,
            gameCenter: gameCenter,
            audio: audio
        )
        let ads = AdsController(
            configuration: AdsConfiguration(
                mode: .disabled,
                appID: AdsConfiguration.realAppID,
                bannerUnitID: "",
                interstitialUnitID: "",
                testDeviceIdentifiers: []
            ),
            consentService: FakeConsentService(),
            adsService: FakeAdsService(),
            progressStore: MemoryInterstitialProgressStore(),
            ageStore: MemoryAdAgeBandStore(.adult)
        )
        RootView(
            googleIdentity: GoogleIdentityService(),
            appleIdentity: AppleIdentityService()
        )
        .environmentObject(backend)
        .environmentObject(preferences)
        .environmentObject(cosmetics)
        .environmentObject(achievements)
        .environmentObject(audio)
        .environmentObject(AppIconController())
        .environmentObject(HomeQuickActionController.shared)
        .environmentObject(gameCenter)
        .environmentObject(gameCenterAutoLink)
        .environmentObject(multiplayer)
        .environmentObject(purchases)
        .environmentObject(ads)
    }
#endif
