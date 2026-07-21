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
    @EnvironmentObject private var purchases: PurchaseController
    @EnvironmentObject private var ads: AdsController

    let googleIdentity: GoogleIdentityService
    let appleIdentity: AppleIdentityService

    @State private var navigationPath: [GameMode] = []
    @State private var showsProfile = false
    @State private var showsAchievements = false
    @State private var opensProfileAfterAchievements = false
    @State private var showsCoinStore = false
    @State private var showsRemoveAdsStore = false
    @State private var showsIconSettings = false
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
                GameView(
                    mode: mode,
                    reservesAdSpacingForRun: ads.reservesBannerSlot
                ) { completionID in
                    ads.recordCompletedSession(id: completionID, mode: mode)
                    guard !hasCompletedGameThisLaunch else { return }
                    hasCompletedGameThisLaunch = true
                    advanceMotivation()
                }
            }
        }
        .tint(Color(hex: palette.foreground))
        .sheet(
            isPresented: $showsProfile,
            onDismiss: {
                Task { await achievements.refresh(showLoading: false) }
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
        .task {
            configureDebugLaunch()
            openPendingQuickAction()
            gameCenter.resumeAuthenticationIfOptedIn()
            audio.setApplicationActive(scenePhase == .active)
            ads.setApplicationActive(scenePhase == .active)
            audio.configure(themeID: cosmetics.selectedThemeID, preferences: preferences)
            audio.setMusicContext(.menu)
            audio.playLaunchSting()
            // UMP belongs to the application launch, not to an identity event.
            // Refresh/present consent before restoring or changing the player session;
            // AdsController still waits for authoritative ad-free resolution before GMA starts.
            await ads.bootstrap(session: nil)
            await restoreSession()
            await ads.updateSession(backend.sessionState)
            await ads.retryEligibilityIfNeeded()
            await purchases.loadProducts()
            await purchases.reconcileOutstandingTransactions()
            await cosmetics.refresh()
            await achievements.refresh(showLoading: false)
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
            audio.setApplicationActive(phase == .active)
            ads.setApplicationActive(phase == .active)
            if phase == .active, navigationPath.isEmpty {
                audio.setMusicContext(.menu)
            }
            if phase == .active {
                Task {
                    await ads.retryEligibilityIfNeeded()
                    await purchases.reconcileOutstandingTransactions()
                }
            }
        }
        .onChange(of: backend.sessionState) { _, _ in
            Task {
                await ads.updateSession(backend.sessionState)
                await purchases.reconcileOutstandingTransactions()
            }
        }
        .onChange(of: navigationPath.isEmpty) { wasEmpty, isEmpty in
            guard isEmpty, !wasEmpty else { return }
            Task { await achievements.refresh(showLoading: false) }
        }
        .onChange(of: cosmetics.ownedPetIDs) { oldIDs, newIDs in
            guard newIDs.count > oldIDs.count else { return }
            Task { await achievements.refresh(showLoading: false) }
        }
    }

    private func menuPanel(
        screenWidth: CGFloat,
        usesCompactRemoveAds: Bool
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Main menu")
                .accessibilityValue("Theme \(palette.id)")
                .accessibilityIdentifier("menu-dialog")
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                utilityHeader(usesCompactRemoveAds: usesCompactRemoveAds)
                hintStage(screenWidth: screenWidth)
                actionStack
                Spacer(minLength: 6)
                menuFooter(usesCompactRemoveAds: usesCompactRemoveAds)
            }

            if let petID = cosmetics.displayedPetID {
                PetCompanionView(
                    petID: petID,
                    size: 64,
                    placement: .menu,
                    animationTrigger: menuPetActivity,
                    facing: menuPetFacing,
                    isSleeping: menuPetSleeping
                )
                .offset(
                    x: WebMenuMetrics.menuPetBaseHorizontalOffset
                        - screenWidth * WebMenuMetrics.menuPetHorizontalShiftFraction,
                    y: WebMenuMetrics.headerHeight + 17
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
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16, weight: .bold))
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
                Image(systemName: backend.profile == nil ? "person" : "person.fill")
                    .font(.system(size: 17, weight: .bold))
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

    private func hintStage(screenWidth: CGFloat) -> some View {
        Group {
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
                        size: 16 * WebMenuMetrics.motivationScale,
                        horizontalPadding: 10,
                        verticalPadding: 5
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
                            size: 12,
                            horizontalPadding: 9,
                            verticalPadding: 4
                        )
                    }
                }
                .offset(x: WebMenuMetrics.introRulesHorizontalOffset)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Tap your color. Become the fastest. Collect rewards.")
                .accessibilityIdentifier("menu-intro-stamps")
            }
        }
        .frame(maxWidth: .infinity, minHeight: WebMenuMetrics.hintHeight, alignment: .leading)
        .padding(.trailing, cosmetics.displayedPetID == nil ? 0 : 76)
        .padding(.top, 8)
        .padding(.bottom, 14)
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

                VStack(spacing: WebMenuMetrics.pairedGap) {
                    modeLink(.arcade)
                    modeLink(.zen)
                }
            }

            Color.clear.frame(height: 9)

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
            VStack(spacing: mode == .zen ? 3 : 0) {
                Text(mode.displayName)
                    .font(palette.appFont(size: 20, weight: .black, relativeTo: .title3))
                if mode == .zen {
                    Text("NO COINS AWARDED")
                        .font(palette.appFont(size: 9, weight: .bold, relativeTo: .caption2))
                        .tracking(0.55)
                }
            }
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
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .black))
                    .frame(width: 28)
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
        guard navigationPath.isEmpty, cosmetics.displayedPetID != nil else { return }
        menuPetSleeping = false
        menuPetFacing = PetTapFollow.resolve(
            pointerX: location.x,
            petCenterX: PetTapFollow.resolveMenuPetCenterX(
                screenWidth: screenWidth,
                canvasWidth: 64,
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

    private func restoreSession() async {
        do {
            let session = try await backend.loadSession()
            guard !session.authenticated,
                let token = try await googleIdentity.restoreIDTokenIfAvailable()
            else {
                return
            }
            _ = try await backend.login(googleIDToken: token)
        } catch {
            // Profile presents actionable sign-in errors; launch restoration stays non-blocking.
        }
    }

    private func configureDebugLaunch() {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
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

#Preview {
    let backend = BackendClient()
    let preferences = AppPreferences()
    let cosmetics = CosmeticsController(backend: backend, preferences: preferences)
    let achievements = AchievementsController(backend: backend)
    let purchases = PurchaseController(creditService: backend, startListeners: false)
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
        progressStore: MemoryInterstitialProgressStore()
    )
    RootView(
        googleIdentity: GoogleIdentityService(),
        appleIdentity: AppleIdentityService()
    )
    .environmentObject(backend)
    .environmentObject(preferences)
    .environmentObject(cosmetics)
    .environmentObject(achievements)
    .environmentObject(AudioController())
    .environmentObject(AppIconController())
    .environmentObject(HomeQuickActionController.shared)
    .environmentObject(GameCenterService(arguments: ["--uitesting"]))
    .environmentObject(purchases)
    .environmentObject(ads)
}
