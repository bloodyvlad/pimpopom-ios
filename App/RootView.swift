import PimPoPomCore
import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var backend: BackendClient
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var cosmetics: CosmeticsController
    @EnvironmentObject private var audio: AudioController

    let services: AlphaServices
    let googleIdentity: GoogleIdentityService

    @State private var accountStatus: String?
    @State private var nickname = ""
    @State private var accountBusy = false
    @State private var navigationPath: [GameMode] = []
    @State private var showsProfile = false
    @State private var showsAchievements = false
    @State private var showsCoinStore = false
    @State private var showsRemoveAdsStore = false
    @State private var motivationIndex: Int?
    @State private var menuPetFacing = PetFacing.front
    @State private var menuPetSleeping = false
    @State private var menuPetActivity = 0
    @State private var menuPetFrame = CGRect.zero
    @State private var introStampSeed = MenuMotivation.introStampSeed(
        arguments: ProcessInfo.processInfo.arguments
    )

    private var palette: ThemePalette { cosmetics.theme }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppThemeBackground(theme: palette)

                GeometryReader { proxy in
                    menuPanel(screenWidth: proxy.size.width)
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
                            SpatialTapGesture()
                                .onEnded {
                                    handleMenuTap(
                                        at: $0.location,
                                        screenWidth: proxy.size.width
                                    )
                                }
                        )
                }
            }
            .coordinateSpace(name: "menu-space")
            .onPreferenceChange(MenuPetFramePreferenceKey.self) { frame in
                guard frame != menuPetFrame else { return }
                Task { @MainActor in menuPetFrame = frame }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: GameMode.self) { GameView(mode: $0) }
        }
        .tint(Color(hex: palette.foreground))
        .sheet(isPresented: $showsProfile) {
            ProfileView(
                googleIdentity: googleIdentity,
                onDismiss: { showsProfile = false }
            )
            .environmentObject(backend)
            .environmentObject(cosmetics)
        }
        .sheet(isPresented: $showsAchievements) { achievementsSheet }
        .sheet(isPresented: $showsCoinStore) {
            CoinStorePlaceholderView()
                .environmentObject(cosmetics)
        }
        .sheet(isPresented: $showsRemoveAdsStore) {
            CoinStorePlaceholderView(offer: .removeAds)
                .environmentObject(cosmetics)
        }
        .task {
            configureDebugLaunch()
            audio.setApplicationActive(scenePhase == .active)
            audio.configure(themeID: cosmetics.selectedThemeID, preferences: preferences)
            audio.setMusicContext(.menu)
            audio.playLaunchSting()
            await restoreSession()
            await cosmetics.refresh()
        }
        .onChange(of: cosmetics.selectedThemeID) { _, themeID in
            audio.configure(themeID: themeID, preferences: preferences)
        }
        .onChange(of: preferences.soundEffectsEnabled) { _, _ in configureAudio() }
        .onChange(of: preferences.soundEffectsVolume) { _, _ in configureAudio() }
        .onChange(of: preferences.musicEnabled) { _, _ in configureAudio() }
        .onChange(of: preferences.musicVolume) { _, _ in configureAudio() }
        .onChange(of: preferences.menuMotivationUnlocked) { _, unlocked in
            if unlocked { advanceMotivation() }
        }
        .onChange(of: scenePhase) { _, phase in
            audio.setApplicationActive(phase == .active)
            if phase == .active, navigationPath.isEmpty {
                audio.setMusicContext(.menu)
            }
        }
    }

    private func menuPanel(screenWidth: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Main menu")
                .accessibilityValue("Theme \(palette.id)")
                .accessibilityIdentifier("menu-dialog")
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                utilityHeader
                hintStage(screenWidth: screenWidth)
                actionStack
                Spacer(minLength: 6)
                menuFooter
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
                    x: 10 - screenWidth * WebMenuMetrics.menuPetHorizontalShiftFraction,
                    y: WebMenuMetrics.headerHeight + 17
                )
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: MenuPetFramePreferenceKey.self,
                            value: proxy.frame(in: .named("menu-space"))
                        )
                    }
                }
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

    private var utilityHeader: some View {
        HStack(spacing: 8) {
            PimPoPomWordmark(theme: palette)
                .frame(maxWidth: .infinity, alignment: .leading)

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
                .overlay(alignment: .bottomTrailing) {
                    WebUtilityBadge(
                        text: "\(cosmetics.coinBalance)",
                        kind: .coin,
                        theme: palette
                    )
                    .offset(x: 5, y: 5)
                    .accessibilityIdentifier("coin-balance-badge")
                }
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
                .overlay(alignment: .topTrailing) {
                    if let rank = arcadeRank {
                        WebUtilityBadge(text: "#\(rank)", kind: .rank, theme: palette)
                            .offset(x: 5, y: -5)
                            .accessibilityLabel("Leaderboard position")
                            .accessibilityValue("#\(rank)")
                            .accessibilityIdentifier("leaderboard-rank-badge")
                    }
                }
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: palette,
                    minimumHeight: WebMenuMetrics.utilityTarget
                )
            )
            .frame(width: WebMenuMetrics.utilityTarget)
            .accessibilityLabel("Leaderboard")
            .accessibilityValue(arcadeRank.map { "Position #\($0)" } ?? "Unranked")
            .accessibilityIdentifier("open-leaderboard")

            Button {
                showsProfile = true
            } label: {
                Image(systemName: backend.profile == nil ? "person" : "person.fill")
                    .font(.system(size: 17, weight: .bold))
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: palette,
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
                .offset(x: screenWidth * WebMenuMetrics.motivationHorizontalShiftFraction)
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
                    Text(backend.isAuthenticated ? "0 / 5 claimed" : "Sign in to claim")
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
            .buttonStyle(WebSecondaryButtonStyle(theme: palette))
            .accessibilityIdentifier("open-settings")
        }
    }

    private var menuFooter: some View {
        VStack(spacing: 7) {
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
                    .accessibilityHint("Opens the StoreKit placeholder")
                    .accessibilityIdentifier("remove-ads")
            }

            Text("© 2026 OTC Software. All rights reserved.")
                .font(palette.appFont(size: 10, weight: .regular, relativeTo: .caption2))
                .foregroundStyle(Color(hex: palette.muted).opacity(0.64))
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 8)
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
        if preferences.menuMotivationUnlocked { return true }
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
        menuPetFacing = PetFacing.resolve(
            pointerX: location.x,
            petCenterX: menuPetSpriteFrame.midX,
            interactionWidth: screenWidth,
            fallback: menuPetFacing
        )
        menuPetActivity += 1
    }

    private var menuPetSpriteFrame: CGRect {
        guard let petID = cosmetics.displayedPetID else { return .zero }
        let geometry = PetArtworkGeometry.resolve(
            placement: .menu,
            petID: petID,
            spriteSize: 64
        )
        return CGRect(
            x: menuPetFrame.minX + geometry.spriteOffset.width,
            y: menuPetFrame.minY + geometry.spriteOffset.height,
            width: 64,
            height: 64
        )
    }

    private var profileSheet: some View {
        NavigationStack {
            ZStack {
                AppThemeBackground(theme: palette)
                ScrollView {
                    accountCard
                        .frame(maxWidth: WebMenuMetrics.maximumPanelWidth)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showsProfile = false }
                }
            }
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Player", systemImage: "person.crop.circle")
                    .font(palette.appFont(size: 18, weight: .bold, relativeTo: .headline))
                Spacer()
                if backend.isLoadingSession || accountBusy { ProgressView() }
            }

            if let profile = backend.profile {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(profile.nickname)
                            .font(palette.appFont(size: 22, weight: .bold, relativeTo: .title3))
                        Text("\(profile.coins) coins · \(profile.totalPlayMs / 60_000) verified minutes")
                            .font(palette.appFont(size: 12, weight: .regular, relativeTo: .caption))
                            .monospacedDigit()
                            .foregroundStyle(Color(hex: palette.muted))
                    }
                    Spacer()
                    Button("Sign out") { Task { await signOut() } }
                        .font(palette.appFont(size: 12, weight: .bold, relativeTo: .caption))
                }

                if !profile.nicknameConfirmed {
                    TextField("Public nickname", text: $nickname)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(
                            Color.black.opacity(palette.isLight ? 0.06 : 0.24),
                            in: RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 12)
                        )
                    Button("Confirm nickname") { Task { await saveNickname() } }
                        .buttonStyle(WebSecondaryButtonStyle(theme: palette, accent: Color(hex: palette.chromeAccent)))
                        .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Text("Arcade runs use the deployed protocol-verified leaderboard.")
                        .font(palette.appFont(size: 12, relativeTo: .caption))
                        .foregroundStyle(Color(hex: palette.muted))
                }
            } else {
                Text(
                    "Play locally now. Sign in to use the existing players, coins, achievements, Pet Shop, and ranked leaderboard."
                )
                .font(palette.appFont(size: 15, relativeTo: .body))
                .foregroundStyle(Color(hex: palette.muted))
                Button {
                    Task { await signIn() }
                } label: {
                    Label("Continue with Google", systemImage: "person.badge.key.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WebSecondaryButtonStyle(theme: palette, accent: Color(hex: palette.chromeAccent)))
                .disabled(!googleIdentity.isConfigured || accountBusy)

                if !googleIdentity.isConfigured {
                    Text("Google placeholder active: add the iOS OAuth client ID in Config/Local.xcconfig.")
                        .font(palette.appFont(size: 12, relativeTo: .caption))
                        .foregroundStyle(.yellow.opacity(0.80))
                }
            }

            if let status = accountStatus ?? backend.lastError {
                Text(status)
                    .font(palette.appFont(size: 12, relativeTo: .caption))
                    .foregroundStyle(.orange)
            }
        }
        .foregroundStyle(Color(hex: palette.foreground))
        .webCardStyle(theme: palette, padding: 16)
    }

    private var achievementsSheet: some View {
        NavigationStack {
            ZStack {
                AppThemeBackground(theme: palette)
                VStack(spacing: 16) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 48, weight: .black))
                        .foregroundStyle(Color(hex: palette.achievementsAccent))
                    Text("Achievements")
                        .font(palette.appFont(size: 30, weight: .black, relativeTo: .largeTitle))
                    Text(
                        "The menu entry now matches the original. The native achievement catalog and claim flow are the next backend feature slice."
                    )
                    .font(palette.appFont(size: 15, relativeTo: .body))
                    .foregroundStyle(Color(hex: palette.muted))
                    .multilineTextAlignment(.center)
                }
                .foregroundStyle(Color(hex: palette.foreground))
                .webCardStyle(theme: palette, padding: 20)
                .padding(20)
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showsAchievements = false }
                }
            }
        }
    }

    private func restoreSession() async {
        accountBusy = true
        defer { accountBusy = false }
        do {
            let session = try await backend.loadSession()
            guard !session.authenticated,
                let token = try await googleIdentity.restoreIDTokenIfAvailable()
            else {
                accountStatus = nil
                return
            }
            _ = try await backend.login(googleIDToken: token)
            accountStatus = nil
        } catch {
            accountStatus = error.localizedDescription
        }
    }

    private func signIn() async {
        accountBusy = true
        defer { accountBusy = false }
        do {
            let token = try await googleIdentity.signIn()
            let session = try await backend.login(googleIDToken: token)
            nickname = session.profile?.nicknameConfirmed == false ? "" : session.profile?.nickname ?? ""
            accountStatus = nil
        } catch {
            accountStatus = error.localizedDescription
        }
    }

    private func signOut() async {
        accountBusy = true
        defer { accountBusy = false }
        do {
            _ = try await backend.logout()
            googleIdentity.signOut()
            accountStatus = nil
        } catch {
            accountStatus = error.localizedDescription
        }
    }

    private func saveNickname() async {
        accountBusy = true
        defer { accountBusy = false }
        do {
            _ = try await backend.updateNickname(nickname)
            accountStatus = nil
        } catch {
            accountStatus = error.localizedDescription
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
}

#Preview {
    let backend = BackendClient()
    let preferences = AppPreferences()
    let cosmetics = CosmeticsController(backend: backend, preferences: preferences)
    RootView(services: .localOnly, googleIdentity: GoogleIdentityService())
        .environmentObject(backend)
        .environmentObject(preferences)
        .environmentObject(cosmetics)
        .environmentObject(AudioController())
}

private struct MenuPetFramePreferenceKey: PreferenceKey {
    static let defaultValue = CGRect.zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
