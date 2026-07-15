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

    private var palette: ThemePalette { cosmetics.theme }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppThemeBackground(theme: palette)

                ScrollView {
                    VStack(spacing: 20) {
                        title
                        modeButtons
                        serviceButtons
                        accountCard
                        footer
                    }
                    .padding(20)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: GameMode.self) { GameView(mode: $0) }
        }
        .tint(Color(hex: palette.foreground))
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
        .onChange(of: scenePhase) { _, phase in
            audio.setApplicationActive(phase == .active)
            if phase == .active, navigationPath.isEmpty {
                audio.setMusicContext(.menu)
            }
        }
    }

    private var title: some View {
        VStack(spacing: 7) {
            Text("PimPoPom")
                .font(.system(size: 48, weight: .black, design: palette.fontDesign))
                .foregroundStyle(Color(hex: palette.foreground))
                .minimumScaleFactor(0.75)
            Text("Native iOS · Internal Alpha")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hex: palette.muted))
            if let season = backend.sessionState?.season {
                Text(season.id == "ui-test" ? season.name : "Hostinger · \(season.name)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(hex: palette.accent).opacity(0.88))
                    .accessibilityIdentifier("backend-environment")
            }
            if let petID = cosmetics.displayedPetID {
                PetCompanionView(petID: petID, size: 62, includesHabitat: true)
                    .padding(.top, 3)
            }
        }
        .padding(.top, 24)
    }

    private var modeButtons: some View {
        VStack(spacing: 12) {
            modeLink(.arcade, color: .cyan)
            modeLink(.zen, color: .mint)
        }
    }

    private var serviceButtons: some View {
        VStack(spacing: 10) {
            NavigationLink {
                LeaderboardView()
            } label: {
                utilityLabel("Season leaderboard", systemImage: "trophy.fill")
            }

            HStack(spacing: 10) {
                NavigationLink {
                    ThemeShopView()
                } label: {
                    utilityLabel("Themes", systemImage: "paintpalette.fill")
                }
                .accessibilityIdentifier("open-theme-shop")

                NavigationLink {
                    PetShopView()
                } label: {
                    utilityLabel("Pets", systemImage: "pawprint.fill")
                }
                .accessibilityIdentifier("open-pet-shop")
            }

            NavigationLink {
                SettingsView()
            } label: {
                utilityLabel("Music, Sound & Settings", systemImage: "slider.horizontal.3")
            }
            .accessibilityIdentifier("open-settings")
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Player", systemImage: "person.crop.circle")
                    .font(.headline.weight(.bold))
                Spacer()
                if backend.isLoadingSession || accountBusy { ProgressView() }
            }

            if let profile = backend.profile {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(profile.nickname)
                            .font(.title3.weight(.bold))
                        Text("\(profile.coins) coins · \(profile.totalPlayMs / 60_000) verified minutes")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color(hex: palette.muted))
                    }
                    Spacer()
                    Button("Sign out") { Task { await signOut() } }
                        .font(.caption.weight(.bold))
                }

                if !profile.nicknameConfirmed {
                    TextField("Public nickname", text: $nickname)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 12))
                    Button("Confirm nickname") { Task { await saveNickname() } }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        .foregroundStyle(.black)
                        .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Text("Arcade runs use the deployed protocol-verified leaderboard.")
                        .font(.caption)
                        .foregroundStyle(Color(hex: palette.muted))
                }
            } else {
                Text("Play locally now. Sign in to use the existing players, coins, and ranked leaderboard.")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: palette.muted))
                Button {
                    Task { await signIn() }
                } label: {
                    Label("Continue with Google", systemImage: "person.badge.key.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .disabled(!googleIdentity.isConfigured || accountBusy)

                if !googleIdentity.isConfigured {
                    Text("Google placeholder active: add the iOS OAuth client ID in Config/Local.xcconfig.")
                        .font(.caption)
                        .foregroundStyle(.yellow.opacity(0.80))
                }
            }

            if let status = accountStatus ?? backend.lastError {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .foregroundStyle(Color(hex: palette.foreground))
        .padding(16)
        .background(
            Color(hex: palette.surface).opacity(palette.isLight ? 0.94 : 0.84),
            in: RoundedRectangle(cornerRadius: palette.cornerRadius)
        )
    }

    private var footer: some View {
        HStack(alignment: .bottom) {
            Text("Build \(appBuildNumber) · API \(BackendClient.deployedBuildID)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Color(hex: palette.muted).opacity(0.72))
            Spacer()
            Button("Remove Ads") {}
                .buttonStyle(.bordered)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(services.purchases.availability == .disabledForLocalAlpha)
                .accessibilityHint("StoreKit is disabled in the internal alpha")
        }
        .padding(.bottom, 8)
    }

    private var appBuildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }

    private func modeLink(_ mode: GameMode, color: Color) -> some View {
        NavigationLink(value: mode) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.title3.weight(.bold))
                    Text(mode == .arcade ? "Ranked when signed in" : "Endless local practice")
                        .font(.caption.weight(.semibold))
                        .opacity(0.65)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(
                mode == .arcade ? palette.color(at: 0) : palette.color(at: 3),
                in: RoundedRectangle(cornerRadius: palette.cornerRadius, style: .continuous)
            )
        }
        .accessibilityIdentifier("mode-\(mode.rawValue)")
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
            if ProcessInfo.processInfo.arguments.contains("--play-arcade") {
                navigationPath = [.arcade]
            } else if ProcessInfo.processInfo.arguments.contains("--play-zen") {
                navigationPath = [.zen]
            }
        #endif
    }

    private func utilityLabel(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.headline.weight(.bold))
            .foregroundStyle(Color(hex: palette.foreground))
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                Color(hex: palette.surface).opacity(palette.isLight ? 0.94 : 0.84),
                in: RoundedRectangle(cornerRadius: palette.cornerRadius)
            )
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
