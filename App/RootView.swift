import PimPoPomCore
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var backend: BackendClient

    let services: AlphaServices
    let googleIdentity: GoogleIdentityService

    @State private var accountStatus: String?
    @State private var nickname = ""
    @State private var accountBusy = false
    @State private var navigationPath: [GameMode] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.03, green: 0.07, blue: 0.14), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

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
        .tint(.white)
        .task {
            configureDebugLaunch()
            await restoreSession()
        }
    }

    private var title: some View {
        VStack(spacing: 7) {
            Text("PimPoPom")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.75)
            Text("Native iOS · Internal Alpha")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
            if let season = backend.sessionState?.season {
                Text(season.id == "ui-test" ? season.name : "Hostinger · \(season.name)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.cyan.opacity(0.82))
                    .accessibilityIdentifier("backend-environment")
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
        NavigationLink {
            LeaderboardView()
        } label: {
            Label("Season leaderboard", systemImage: "trophy.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
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
                            .foregroundStyle(.white.opacity(0.62))
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
                        .foregroundStyle(.white.opacity(0.60))
                }
            } else {
                Text("Play locally now. Sign in to use the existing players, coins, and ranked leaderboard.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
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
        .foregroundStyle(.white)
        .padding(16)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }

    private var footer: some View {
        HStack(alignment: .bottom) {
            Text("Build \(appBuildNumber) · API \(BackendClient.deployedBuildID)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.38))
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
            .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .accessibilityIdentifier("mode-\(mode.rawValue)")
    }

    private func restoreSession() async {
        do {
            let session = try await backend.loadSession()
            guard !session.authenticated,
                let token = try await googleIdentity.restoreIDTokenIfAvailable()
            else { return }
            _ = try await backend.login(googleIDToken: token)
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
}

#Preview {
    RootView(services: .localOnly, googleIdentity: GoogleIdentityService())
        .environmentObject(BackendClient())
}
