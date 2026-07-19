import PimPoPomCore
import SwiftUI

private enum ProfileAccountDeletionError: LocalizedError {
    case accountChanged

    var errorDescription: String? {
        switch self {
        case .accountChanged:
            "A different Google account was selected. No account was deleted, and PimPoPom signed out."
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var backend: BackendClient
    @EnvironmentObject private var cosmetics: CosmeticsController
    @EnvironmentObject private var gameCenter: GameCenterService

    let googleIdentity: GoogleIdentityService
    let onDismiss: () -> Void

    @State private var nickname = ""
    @State private var mode = GameMode.arcade
    @State private var response: ProfileResponse?
    @State private var status: String?
    @State private var busy = false
    @State private var loadGeneration = 0
    @State private var showsAccountDeletionConfirmation = false
    @State private var accountDeletionConfirmation = ""
    @State private var accountDeletionStatus: String?

    private var palette: ThemePalette { cosmetics.theme }

    var body: some View {
        NavigationStack {
            ZStack {
                AppThemeBackground(theme: palette)

                ScrollView {
                    VStack(spacing: 12) {
                        profileHeading
                        if let profile = backend.profile {
                            signedInContent(profile)
                        } else {
                            signedOutContent
                            gameCenterCard
                        }
                    }
                    .frame(maxWidth: WebMenuMetrics.maximumPanelWidth)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                }

                if busy {
                    WebLoadingOverlay(theme: palette, label: "Updating profile")
                }
            }
            .foregroundStyle(Color(hex: palette.foreground))
            .navigationTitle("My Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
            .task {
                nickname = backend.profile?.nickname ?? ""
            }
            .task(id: mode) {
                guard backend.isAuthenticated else { return }
                await loadProfile()
            }
            .onChange(of: backend.profile?.id) { oldPlayerID, newPlayerID in
                if oldPlayerID != newPlayerID { resetAccountDeletionForm() }
            }
        }
    }

    private var profileHeading: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: palette.accent).opacity(0.14))
                Image(systemName: backend.isAuthenticated ? "person.fill" : "person")
                    .font(.system(size: 23, weight: .black))
                    .foregroundStyle(Color(hex: palette.accent))
            }
            .frame(width: 50, height: 50)
            .overlay { Circle().stroke(Color(hex: palette.accent).opacity(0.50), lineWidth: 1) }

            VStack(alignment: .leading, spacing: 2) {
                Text("My Profile")
                    .font(palette.appFont(size: 25, weight: .black, relativeTo: .title))
                Text(backend.isAuthenticated ? "PLAYER ACCOUNT" : "PLAY ACROSS DEVICES")
                    .font(palette.appFont(size: 9, weight: .black, relativeTo: .caption2))
                    .tracking(1)
                    .foregroundStyle(Color(hex: palette.muted))
            }
            Spacer()
        }
        .webCardStyle(theme: palette, selectedAccent: Color(hex: palette.accent), padding: 14)
    }

    private var signedOutContent: some View {
        VStack(spacing: 13) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Keep your progress")
                    .font(palette.appFont(size: 20, weight: .black, relativeTo: .title3))
                Text(
                    "Sign in to use the same players, coins, pets, themes, achievements, and Arcade leaderboard as the web game."
                )
                .font(palette.appFont(size: 14, weight: .medium, relativeTo: .body))
                .foregroundStyle(Color(hex: palette.muted))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(Color(hex: "#ffd84d"))
                Text(
                    "Ranked Arcade results and one coin per verified play minute are saved only after sign-in and nickname confirmation."
                )
                .font(palette.appFont(size: 12, weight: .bold, relativeTo: .caption))
                .foregroundStyle(Color(hex: palette.muted))
            }
            .padding(12)
            .background(
                Color(hex: "#ffd84d").opacity(0.10), in: RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 12)
                    .stroke(Color(hex: "#ffd84d").opacity(0.44), lineWidth: palette.isPixel ? 2 : 1)
            }

            Button {
                Task { await signIn() }
            } label: {
                Label("Continue with Google", systemImage: "person.badge.key.fill")
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: palette,
                    accent: Color(hex: palette.chromeAccent)
                )
            )
            .disabled(!googleIdentity.isConfigured || busy)
            .accessibilityIdentifier("profile-google-sign-in")

            if !googleIdentity.isConfigured {
                Text("Google placeholder active: add the iOS OAuth client ID in Config/Local.xcconfig.")
                    .font(palette.appFont(size: 10, weight: .bold, relativeTo: .caption2))
                    .foregroundStyle(Color(hex: "#966700"))
            }

            statusMessage
        }
        .webCardStyle(theme: palette, padding: 16)
    }

    private func signedInContent(_ profile: PlayerProfile) -> some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.nickname)
                            .font(palette.appFont(size: 22, weight: .black, relativeTo: .title3))
                        HStack(spacing: 4) {
                            PixelCoinView(size: 13)
                            Text("\(profile.coins)")
                                .foregroundStyle(Color(hex: "#ffc629"))
                            Text("· \(profile.totalPlayMs / 60_000) verified minutes")
                                .foregroundStyle(Color(hex: palette.muted))
                        }
                        .font(palette.appFont(size: 11, weight: .bold, relativeTo: .caption))
                        .monospacedDigit()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            "\(profile.coins) coins, \(profile.totalPlayMs / 60_000) verified minutes"
                        )
                    }
                    Spacer()
                    Button("Log out") { Task { await signOut() } }
                        .font(palette.appFont(size: 11, weight: .black, relativeTo: .caption))
                        .foregroundStyle(Color(hex: palette.accent))
                }

                Text("PUBLIC NICKNAME")
                    .font(palette.appFont(size: 9, weight: .black, relativeTo: .caption2))
                    .tracking(0.9)
                    .foregroundStyle(Color(hex: palette.muted))

                HStack(spacing: 8) {
                    TextField("Public nickname", text: $nickname)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(palette.appFont(size: 14, weight: .bold, relativeTo: .body))
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(
                            Color.black.opacity(palette.isLight ? 0.05 : 0.24),
                            in: RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 12)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 12)
                                .stroke(Color(hex: palette.foreground).opacity(0.14), lineWidth: 1)
                        }
                        .accessibilityIdentifier("profile-nickname")

                    Button("Save") { Task { await saveNickname() } }
                        .buttonStyle(
                            WebSecondaryButtonStyle(
                                theme: palette,
                                accent: Color(hex: palette.chromeAccent),
                                minimumHeight: 44
                            )
                        )
                        .frame(width: 82)
                        .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("profile-save-nickname")
                }
            }
            .webCardStyle(theme: palette, padding: 14)

            gameCenterCard

            WebModeTabs(mode: $mode, theme: palette)

            if let rank = response?.ranks[mode.rawValue] {
                rankCard(rank)
            }

            if let entries = response?.leaderboard.entries, !entries.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("NEAR YOUR BEST")
                        .font(palette.appFont(size: 9, weight: .black, relativeTo: .caption2))
                        .tracking(0.9)
                        .foregroundStyle(Color(hex: palette.muted))
                    ForEach(entries) { entry in
                        LeaderboardRowView(entry: entry, theme: palette)
                    }
                }
            } else if !busy {
                Text("No ranked results in this mode yet.")
                    .font(palette.appFont(size: 13, weight: .bold, relativeTo: .body))
                    .foregroundStyle(Color(hex: palette.muted))
                    .webCardStyle(theme: palette, padding: 14)
            }

            statusMessage

            accountDeletionDangerZone(profile)
        }
    }

    private var gameCenterCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 23, weight: .black))
                .foregroundStyle(Color(hex: palette.accent))
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text("Game Center")
                    .font(palette.appFont(size: 15, weight: .black, relativeTo: .headline))
                    .accessibilityIdentifier("profile-game-center-card")
                Text(gameCenterStatus)
                    .font(palette.appFont(size: 10, weight: .bold, relativeTo: .caption2))
                    .foregroundStyle(Color(hex: palette.muted))
                    .accessibilityIdentifier("profile-game-center-status")
            }
            .accessibilityElement(children: .contain)

            Spacer(minLength: 8)

            Button(gameCenterButtonTitle) { gameCenter.retryAuthentication() }
                .buttonStyle(
                    WebSecondaryButtonStyle(
                        theme: palette,
                        accent: Color(hex: palette.accent),
                        minimumHeight: 40
                    )
                )
                .frame(width: 105)
                .disabled(!canRetryGameCenter)
                .accessibilityIdentifier("profile-game-center")
        }
        .webCardStyle(theme: palette, padding: 12)
    }

    private func accountDeletionDangerZone(_ profile: PlayerProfile) -> some View {
        let danger = Color(hex: "#ff647b")
        return VStack(alignment: .leading, spacing: 11) {
            if showsAccountDeletionConfirmation {
                Text("Delete account permanently?")
                    .font(palette.appFont(size: 17, weight: .black, relativeTo: .headline))
                    .foregroundStyle(danger)

                Text(
                    "This removes your PimPoPom identity, nickname, public results, coins, pets, themes, achievements, and active sessions. Detached Apple purchase and refund records may be retained where required for reconciliation. This cannot be undone."
                )
                .font(palette.appFont(size: 12, weight: .medium, relativeTo: .caption))
                .foregroundStyle(Color(hex: palette.muted))

                (Text("Type ")
                    + Text(BackendClient.accountDeletionConfirmation).bold()
                    + Text(" to continue."))
                    .font(palette.appFont(size: 11, weight: .medium, relativeTo: .caption))

                TextField("DELETE MY ACCOUNT", text: $accountDeletionConfirmation)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(palette.appFont(size: 14, weight: .bold, relativeTo: .body))
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(
                        Color.black.opacity(palette.isLight ? 0.05 : 0.24),
                        in: RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 12)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 12)
                            .stroke(danger.opacity(0.52), lineWidth: palette.isPixel ? 2 : 1)
                    }
                    .submitLabel(.done)
                    .accessibilityIdentifier("profile-delete-confirmation")

                HStack(spacing: 8) {
                    Button("Cancel") { resetAccountDeletionForm() }
                        .buttonStyle(
                            WebSecondaryButtonStyle(
                                theme: palette,
                                accent: Color(hex: palette.muted),
                                minimumHeight: 44
                            )
                        )
                        .accessibilityIdentifier("profile-delete-cancel")

                    Button("Permanently delete", role: .destructive) {
                        Task { await deleteAccount(profile) }
                    }
                    .buttonStyle(
                        WebSecondaryButtonStyle(
                            theme: palette,
                            accent: danger,
                            minimumHeight: 44
                        )
                    )
                    .disabled(
                        busy
                            || accountDeletionConfirmation
                                != BackendClient.accountDeletionConfirmation
                    )
                    .accessibilityIdentifier("profile-delete-confirm")
                }

                if let accountDeletionStatus {
                    Text(accountDeletionStatus)
                        .font(palette.appFont(size: 11, weight: .bold, relativeTo: .caption))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("profile-delete-status")
                }
            } else {
                Button("Delete Account", role: .destructive) {
                    showsAccountDeletionConfirmation = true
                    accountDeletionConfirmation = ""
                    accountDeletionStatus = nil
                }
                .buttonStyle(
                    WebSecondaryButtonStyle(
                        theme: palette,
                        accent: danger,
                        minimumHeight: 44
                    )
                )
                .disabled(busy)
                .accessibilityIdentifier("profile-delete-account")
            }
        }
        .webCardStyle(theme: palette, selectedAccent: danger, padding: 14)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile-danger-zone")
    }

    private var gameCenterStatus: String {
        switch gameCenter.state {
        case .idle:
            "Not started · PimPoPom play still works"
        case .authenticating:
            "Connecting… · PimPoPom play still works"
        case .authenticated(let player):
            "Connected as \(player.displayName)"
        case .unavailable:
            "Unavailable · PimPoPom play still works"
        }
    }

    private var gameCenterButtonTitle: String {
        switch gameCenter.state {
        case .idle:
            "Connect"
        case .authenticating:
            "Connecting…"
        case .authenticated:
            "Connected"
        case .unavailable:
            "Retry"
        }
    }

    private var canRetryGameCenter: Bool {
        if case .unavailable = gameCenter.state { return true }
        return false
    }

    private func rankCard(_ rank: RankInfo) -> some View {
        HStack(spacing: 12) {
            metric("POSITION", value: rank.rank.map { "#\($0)" } ?? "—")
            Divider().overlay(Color(hex: palette.foreground).opacity(0.12))
            metric("TOP RESULTS", value: rank.topPercent.map { "\($0)%" } ?? "—")
        }
        .frame(height: 64)
        .webCardStyle(theme: palette, selectedAccent: Color(hex: palette.accent), padding: 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile-rank-card")
    }

    private func metric(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(palette.appFont(size: 8, weight: .black, relativeTo: .caption2))
                .tracking(0.7)
                .foregroundStyle(Color(hex: palette.muted))
            Text(value)
                .font(palette.appFont(size: 22, weight: .black, relativeTo: .title3))
                .foregroundStyle(Color(hex: palette.accent))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var statusMessage: some View {
        if let message = status ?? backend.lastError {
            Text(message)
                .font(palette.appFont(size: 11, weight: .bold, relativeTo: .caption))
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("profile-status")
        }
    }

    private func loadProfile() async {
        let requestedMode = mode
        loadGeneration += 1
        let generation = loadGeneration
        busy = true
        defer {
            if generation == loadGeneration { busy = false }
        }
        do {
            let loaded = try await backend.loadProfile(mode: requestedMode)
            guard !Task.isCancelled, mode == requestedMode, generation == loadGeneration else { return }
            response = loaded
            nickname = loaded.profile.nickname
            status = nil
        } catch {
            guard !Task.isCancelled, generation == loadGeneration else { return }
            status = error.localizedDescription
        }
    }

    private func signIn() async {
        busy = true
        defer { busy = false }
        do {
            let token = try await googleIdentity.signIn()
            let session = try await backend.login(googleIDToken: token)
            nickname = session.profile?.nickname ?? ""
            status = nil
            await cosmetics.refresh()
            await loadProfile()
        } catch {
            status = error.localizedDescription
        }
    }

    private func signOut() async {
        busy = true
        defer { busy = false }
        do {
            _ = try await backend.logout()
            googleIdentity.signOut()
            response = nil
            nickname = ""
            status = nil
            resetAccountDeletionForm()
            await cosmetics.refresh()
        } catch {
            status = error.localizedDescription
        }
    }

    private func saveNickname() async {
        busy = true
        defer { busy = false }
        do {
            _ = try await backend.updateNickname(nickname)
            status = "Nickname saved."
            await loadProfile()
        } catch {
            status = error.localizedDescription
        }
    }

    private func deleteAccount(_ profile: PlayerProfile) async {
        guard accountDeletionConfirmation == BackendClient.accountDeletionConfirmation else {
            accountDeletionStatus = "Type DELETE MY ACCOUNT exactly to continue."
            return
        }

        busy = true
        accountDeletionStatus = nil
        defer { busy = false }
        do {
            let credential = try await accountDeletionCredential()
            _ = try await backend.reauthenticateForAccountDeletion(
                googleIDToken: credential,
                expectedPlayerID: profile.id
            )

            _ = try await backend.deleteAccount(
                confirmation: accountDeletionConfirmation,
                expectedPlayerID: profile.id
            )
            googleIdentity.signOut()
            response = nil
            nickname = ""
            status = nil
            resetAccountDeletionForm()
            onDismiss()
        } catch let error as BackendError
            where error.code == BackendClient.accountDeletionAccountMismatchCode
        {
            googleIdentity.signOut()
            response = nil
            nickname = ""
            status = ProfileAccountDeletionError.accountChanged.localizedDescription
            resetAccountDeletionForm()
        } catch {
            accountDeletionStatus = error.localizedDescription
        }
    }

    private func accountDeletionCredential() async throws -> String {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--uitesting"),
                arguments.contains("--ui-test-account-deletion")
            {
                return BackendClient.uiTestAccountDeletionCredential
            }
        #endif
        return try await googleIdentity.signIn()
    }

    private func resetAccountDeletionForm() {
        showsAccountDeletionConfirmation = false
        accountDeletionConfirmation = ""
        accountDeletionStatus = nil
    }
}
