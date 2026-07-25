import AuthenticationServices
import PimPoPomCore
import SwiftUI

private enum ProfileAccountDeletionError: LocalizedError {
    case accountChanged

    var errorDescription: String? {
        switch self {
        case .accountChanged:
            "A different account was selected. No account was deleted, and PimPoPom signed out."
        }
    }
}

private enum PendingProfileRegistration {
    case apple
    case google(idToken: String)
}

private enum ProfileReauthenticationProvider {
    case apple
    case google
}

struct ProfileView: View {
    @EnvironmentObject private var backend: BackendClient
    @EnvironmentObject private var cosmetics: CosmeticsController
    @EnvironmentObject private var gameCenter: GameCenterService

    let googleIdentity: GoogleIdentityService
    let appleIdentity: AppleIdentityService
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
    @State private var pendingRegistration: PendingProfileRegistration?
    @State private var showsRegistrationConfirmation = false
    @State private var pendingDeletionProfileID: String?
    @State private var showsDeletionProviderChoice = false
    @State private var pendingGameCenterLink = false
    @State private var gameCenterLinking = false
    @State private var gameCenterLinkTask: Task<Void, Never>?
    @State private var gameCenterLinkGeneration = 0
    @State private var gameCenterLinkIssue: GameCenterLinkIssue?

    private var palette: ThemePalette { cosmetics.theme }
    private var appleSignInEnabled: Bool {
        backend.sessionState?.appleSignIn?.enabled ?? true
    }
    private var identityBindings: IdentityBindings {
        backend.sessionState?.identityBindings
            ?? IdentityBindings(
                google: backend.isAuthenticated,
                apple: false,
                gameCenter: false
            )
    }
    private var accountOperationBusy: Bool { busy || gameCenterLinking }
    private var gameCenterServerStatus: GameCenterServerStatus? {
        backend.sessionState?.gameCenter
    }
    private var gameCenterProfileState: GameCenterProfileState {
        GameCenterProfileStateResolver.resolve(
            connection: gameCenter.state,
            primaryProfileAuthenticated: backend.isAuthenticated,
            identityBinding: identityBindings.gameCenter,
            serverStatus: gameCenterServerStatus,
            issue: gameCenterLinkIssue
        )
    }

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

                if accountOperationBusy {
                    WebLoadingOverlay(
                        theme: palette,
                        label: gameCenterLinking ? "Verifying Game Center" : "Updating profile"
                    )
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
                if oldPlayerID != newPlayerID {
                    resetAccountDeletionForm()
                    gameCenterLinkGeneration += 1
                    gameCenterLinkTask?.cancel()
                    gameCenterLinkTask = nil
                    gameCenterLinking = false
                    gameCenterLinkIssue = nil
                    pendingGameCenterLink = false
                }
            }
            .onChange(of: gameCenter.state) { _, state in
                gameCenterLinkIssue = nil
                guard pendingGameCenterLink,
                    case .authenticated = state
                else { return }
                startGameCenterLinkIfNeeded()
            }
            .confirmationDialog(
                "Create a new PimPoPom profile?",
                isPresented: $showsRegistrationConfirmation,
                titleVisibility: .visible
            ) {
                Button("Create New Profile") {
                    Task { await registerPendingIdentity() }
                }
                Button("Cancel", role: .cancel) {
                    cancelPendingRegistration()
                }
            } message: {
                Text(
                    "No existing profile is linked to this sign-in. A new profile has a separate wallet, scores, pets, themes, and purchases. To keep an existing profile, sign in with its linked method and add this one afterward."
                )
            }
            .confirmationDialog(
                "Verify before deleting",
                isPresented: $showsDeletionProviderChoice,
                titleVisibility: .visible
            ) {
                Button("Verify with Apple") {
                    beginConfirmedDeletion(using: .apple)
                }
                Button("Verify with Google") {
                    beginConfirmedDeletion(using: .google)
                }
                Button("Cancel", role: .cancel) {
                    pendingDeletionProfileID = nil
                }
            } message: {
                Text("Choose a linked sign-in method to confirm that this profile is yours.")
            }
            .onDisappear {
                gameCenterLinkTask?.cancel()
                gameCenterLinkTask = nil
                if pendingRegistration != nil {
                    cancelPendingRegistration()
                }
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

            if appleSignInEnabled {
                AppleSignInButton(
                    style: palette.isLight ? .black : .white,
                    accessibilityIdentifier: "profile-apple-sign-in"
                ) {
                    Task { await signInWithApple() }
                }
                .id(palette.isLight ? "apple-black" : "apple-white")
                .frame(height: 50)
                .disabled(accountOperationBusy)
            } else {
                Text("Sign in with Apple is temporarily unavailable.")
                    .font(palette.appFont(size: 10, weight: .bold, relativeTo: .caption2))
                    .foregroundStyle(Color(hex: "#966700"))
            }

            Button {
                Task { await signInWithGoogle() }
            } label: {
                Label("Continue with Google", systemImage: "person.badge.key.fill")
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: palette,
                    accent: Color(hex: palette.chromeAccent)
                )
            )
            .disabled(!googleIdentity.isConfigured || accountOperationBusy)
            .accessibilityIdentifier("profile-google-sign-in")

            if !googleIdentity.isConfigured {
                Text("Google sign-in needs the iOS OAuth client ID in Config/Local.xcconfig.")
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
                        .disabled(accountOperationBusy)
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
                        .disabled(
                            accountOperationBusy
                                || nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                        .accessibilityIdentifier("profile-save-nickname")
                }
            }
            .webCardStyle(theme: palette, padding: 14)

            identityMethodsCard(profile)

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

    private func identityMethodsCard(_ profile: PlayerProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SIGN-IN METHODS")
                .font(palette.appFont(size: 9, weight: .black, relativeTo: .caption2))
                .tracking(0.9)
                .foregroundStyle(Color(hex: palette.muted))

            identityMethodRow(
                title: "Apple",
                systemImage: "apple.logo",
                linked: identityBindings.apple,
                linkTitle: "Link Apple",
                enabled: appleSignInEnabled
            ) {
                Task { await linkApple(to: profile) }
            }

            Divider().overlay(Color(hex: palette.foreground).opacity(0.12))

            identityMethodRow(
                title: "Google",
                systemImage: "person.badge.key.fill",
                linked: identityBindings.google,
                linkTitle: "Link Google",
                enabled: googleIdentity.isConfigured
            ) {
                Task { await linkGoogle(to: profile) }
            }

            Text(
                "Sign-in methods are linked only after you verify this profile. PimPoPom never merges accounts by email or nickname."
            )
            .font(palette.appFont(size: 9, weight: .medium, relativeTo: .caption2))
            .foregroundStyle(Color(hex: palette.muted))
            .fixedSize(horizontal: false, vertical: true)
        }
        .webCardStyle(theme: palette, padding: 12)
        .accessibilityIdentifier("profile-identity-methods")
    }

    private func identityMethodRow(
        title: String,
        systemImage: String,
        linked: Bool,
        linkTitle: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .frame(width: 28)
                .foregroundStyle(Color(hex: palette.accent))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(palette.appFont(size: 14, weight: .black, relativeTo: .body))
                Text(linked ? "Linked" : "Not linked")
                    .font(palette.appFont(size: 9, weight: .bold, relativeTo: .caption2))
                    .foregroundStyle(Color(hex: linked ? "#4dcc72" : palette.muted))
            }
            Spacer()
            if linked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: "#4dcc72"))
                    .accessibilityLabel("Linked")
            } else {
                Button(linkTitle, action: action)
                    .font(palette.appFont(size: 10, weight: .black, relativeTo: .caption))
                    .foregroundStyle(Color(hex: palette.accent))
                    .disabled(accountOperationBusy || !enabled)
            }
        }
    }

    private var gameCenterCard: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("profile-game-center-status")
                }
                .accessibilityElement(children: .contain)

                Spacer(minLength: 8)

                Button(gameCenterButtonTitle, action: handleGameCenterAction)
                    .buttonStyle(
                        WebSecondaryButtonStyle(
                            theme: palette,
                            accent: Color(hex: palette.accent),
                            minimumHeight: 40
                        )
                    )
                    .frame(width: 118)
                    .disabled(isGameCenterActionDisabled)
                    .accessibilityIdentifier("profile-game-center")
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(
                    "Game Center is optional. PimPoPom stays authoritative and publishes only protocol-verified Arcade bests and unlocked achievements after you enable it. It never grants profile, wallet, or purchase access."
                )
                .font(palette.appFont(size: 9, weight: .medium, relativeTo: .caption2))
                .foregroundStyle(Color(hex: palette.muted))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("profile-game-center-explanation")

                if showsGameCenterSecondaryAction {
                    Button(gameCenterSecondaryActionTitle) {
                        handleGameCenterSecondaryAction()
                    }
                    .font(palette.appFont(size: 9, weight: .black, relativeTo: .caption2))
                    .foregroundStyle(Color(hex: palette.accent))
                    .disabled(gameCenterLinking)
                    .accessibilityIdentifier("profile-game-center-turn-off")
                }
            }
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
                        requestConfirmedDeletion(for: profile)
                    }
                    .buttonStyle(
                        WebSecondaryButtonStyle(
                            theme: palette,
                            accent: danger,
                            minimumHeight: 44
                        )
                    )
                    .disabled(
                        accountOperationBusy
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
                .disabled(accountOperationBusy)
                .accessibilityIdentifier("profile-delete-account")
            }
        }
        .webCardStyle(theme: palette, selectedAccent: danger, padding: 14)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile-danger-zone")
    }

    private var gameCenterStatus: String {
        switch gameCenterProfileState {
        case .gameCenterSignedOut:
            if case .authenticating = gameCenter.state {
                return "Connecting… · PimPoPom play still works"
            }
            if gameCenterServerStatus?.publicationEnabled == true {
                return "Off locally · verified results still publish for the linked profile"
            }
            return identityBindings.gameCenter
                ? "Linked to this profile · publishing is off"
                : "Off · no Game Center data shared"
        case .gameCenterUnavailable:
            return "Unavailable · PimPoPom play still works"
        case .primaryProfileRequired:
            return "Connected as \(currentGameCenterDisplayName) · sign in to PimPoPom first"
        case .primaryReauthenticationRequired:
            return "Confirm your Apple or Google PimPoPom sign-in to continue"
        case .scopedIDsTransient:
            return "Game Center player IDs are temporary · try again later"
        case .unlinked:
            return "Connected as \(currentGameCenterDisplayName) · link and enable publishing"
        case .linkedIdentityOnly:
            if gameCenterServerStatus?.serverPublicationAvailable == false {
                return "Identity linked · server publishing is temporarily unavailable"
            } else {
                return "Identity linked · publishing is off"
            }
        case .publicationQueued(let count):
            return "Publishing enabled · \(count) Game Center update\(count == 1 ? "" : "s") queued"
        case .mirrorReady:
            return "Ready · verified Arcade bests and achievements mirror automatically"
        case .publicationHeld:
            return "Apple delivery needs support · your PimPoPom progress is safe"
        case .conflict:
            return "This Game Center account conflicts with an existing profile link"
        case .resetNeedsSupport:
            return "Apple leaderboard reset needs support · PimPoPom play still works"
        }
    }

    private var currentGameCenterDisplayName: String {
        guard case .authenticated(let player) = gameCenter.state else {
            return "Game Center"
        }
        return player.displayName
    }

    private var gameCenterButtonTitle: String {
        switch gameCenterProfileState {
        case .gameCenterSignedOut:
            if case .authenticating = gameCenter.state {
                return "Connecting…"
            }
            return "Connect"
        case .gameCenterUnavailable:
            return gameCenter.participationEnabled ? "Turn Off" : "Retry"
        case .primaryProfileRequired, .scopedIDsTransient, .conflict:
            return "Turn Off"
        case .primaryReauthenticationRequired:
            return "Verify Sign-In"
        case .unlinked:
            return "Link & Publish"
        case .linkedIdentityOnly:
            return "Enable"
        case .publicationQueued, .mirrorReady, .publicationHeld, .resetNeedsSupport:
            return "Turn Off"
        }
    }

    private var isGameCenterActionDisabled: Bool {
        if case .authenticating = gameCenter.state { return true }
        return busy || gameCenterLinking
    }

    private var showsGameCenterSecondaryAction: Bool {
        if gameCenterServerStatus?.publicationEnabled == true,
            case .gameCenterSignedOut = gameCenterProfileState
        {
            return true
        }
        guard gameCenter.participationEnabled else { return false }
        switch gameCenterProfileState {
        case .primaryProfileRequired, .scopedIDsTransient, .unlinked,
            .linkedIdentityOnly, .conflict:
            return true
        default:
            return false
        }
    }

    private var gameCenterSecondaryActionTitle: String {
        gameCenterServerStatus?.publicationEnabled == true
            ? "Stop publishing"
            : "Turn Off locally"
    }

    private func handleGameCenterSecondaryAction() {
        if gameCenterServerStatus?.publicationEnabled == true {
            turnOffGameCenter()
        } else {
            turnOffGameCenterLocally()
        }
    }

    private func handleGameCenterAction() {
        switch gameCenterProfileState {
        case .gameCenterSignedOut:
            pendingGameCenterLink =
                backend.isAuthenticated
                && gameCenterServerStatus?.mirrorReady != true
            gameCenter.connect()
        case .gameCenterUnavailable:
            if gameCenter.participationEnabled {
                turnOffGameCenter()
            } else {
                pendingGameCenterLink =
                    backend.isAuthenticated
                    && gameCenterServerStatus?.mirrorReady != true
                gameCenter.retryAuthentication()
            }
        case .primaryProfileRequired, .scopedIDsTransient, .conflict:
            turnOffGameCenter()
        case .primaryReauthenticationRequired, .unlinked, .linkedIdentityOnly:
            pendingGameCenterLink = true
            startGameCenterLinkIfNeeded()
        case .publicationQueued, .mirrorReady, .publicationHeld, .resetNeedsSupport:
            turnOffGameCenter()
        }
    }

    private func turnOffGameCenterLocally() {
        gameCenterLinkGeneration += 1
        pendingGameCenterLink = false
        gameCenterLinkTask?.cancel()
        gameCenterLinkTask = nil
        gameCenterLinking = false
        gameCenterLinkIssue = nil
        gameCenter.disableParticipation()
    }

    private func turnOffGameCenter() {
        guard backend.isAuthenticated,
            let playerID = backend.profile?.id,
            gameCenterServerStatus?.publicationEnabled == true
        else {
            turnOffGameCenterLocally()
            return
        }
        startGameCenterPublicationDisable(playerID: playerID)
    }

    private func startGameCenterPublicationDisable(playerID: String) {
        guard !gameCenterLinking, gameCenterLinkTask == nil else { return }
        gameCenterLinkGeneration += 1
        let generation = gameCenterLinkGeneration
        gameCenterLinking = true
        gameCenterLinkTask = Task { @MainActor in
            defer {
                if generation == gameCenterLinkGeneration {
                    gameCenterLinking = false
                    gameCenterLinkTask = nil
                }
            }
            do {
                try await disableGameCenterPublication(
                    playerID: playerID,
                    allowsReauthentication: true
                )
                guard generation == gameCenterLinkGeneration else { return }
                status = "Game Center publishing is off. The verified identity link is retained."
                turnOffGameCenterLocally()
            } catch is CancellationError {
                return
            } catch {
                guard generation == gameCenterLinkGeneration else { return }
                recordGameCenterError(error)
            }
        }
    }

    private func disableGameCenterPublication(
        playerID: String,
        allowsReauthentication: Bool
    ) async throws {
        do {
            _ = try await backend.disableGameCenterPublication(
                expectedPlayerID: playerID
            )
        } catch let error as BackendError
            where allowsReauthentication && (error.status == 401 || error.status == 403)
        {
            gameCenterLinkIssue = .primaryReauthenticationRequired
            try await reauthenticateCurrentProfile(playerID)
            try Task.checkCancellation()
            _ = try await backend.loadSession()
            gameCenterLinkIssue = nil
            _ = try await backend.disableGameCenterPublication(
                expectedPlayerID: playerID
            )
        }
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

    private func signInWithGoogle() async {
        busy = true
        defer { busy = false }
        var attemptedToken: String?
        do {
            let token = try await googleIdentity.signIn()
            attemptedToken = token
            let session = try await backend.login(googleIDToken: token)
            await finishAuthentication(session)
        } catch let error as BackendError where error.status == 409 && !backend.isAuthenticated {
            status = error.localizedDescription
            if let token = attemptedToken {
                pendingRegistration = .google(idToken: token)
                showsRegistrationConfirmation = true
            }
        } catch {
            status = error.localizedDescription
        }
    }

    private func signInWithApple() async {
        busy = true
        defer { busy = false }
        do {
            let session = try await authorizeWithApple(intent: .login)
            await finishAuthentication(session)
        } catch let error as BackendError where error.status == 409 && !backend.isAuthenticated {
            status = error.localizedDescription
            pendingRegistration = .apple
            showsRegistrationConfirmation = true
        } catch {
            status = error.localizedDescription
        }
    }

    private func registerPendingIdentity() async {
        guard let pendingRegistration else { return }
        self.pendingRegistration = nil
        busy = true
        defer { busy = false }
        do {
            let session: SessionResponse
            switch pendingRegistration {
            case .apple:
                session = try await authorizeWithApple(intent: .register)
            case .google(let idToken):
                session = try await backend.registerWithGoogle(googleIDToken: idToken)
            }
            await finishAuthentication(session)
        } catch let error as BackendError where error.status == 409 {
            if case .google = pendingRegistration {
                googleIdentity.signOut()
            }
            status = error.localizedDescription
        } catch {
            status = error.localizedDescription
        }
    }

    private func finishAuthentication(_ session: SessionResponse) async {
        nickname = session.profile?.nicknameConfirmed == false ? "" : session.profile?.nickname ?? ""
        status = nil
        await cosmetics.refresh()
        await loadProfile()
    }

    private func authorizeWithApple(
        intent: PrimaryAuthenticationIntent,
        expectedPlayerID: String? = nil
    ) async throws -> SessionResponse {
        let challenge = try await backend.issueAppleSignInChallenge(intent: intent)
        let proof = try await appleIdentity.authorize(challenge: challenge)
        return try await backend.completeAppleAuthorization(
            challenge: challenge,
            proof: proof,
            expectedPlayerID: expectedPlayerID
        )
    }

    private func linkApple(to profile: PlayerProfile) async {
        busy = true
        defer { busy = false }
        do {
            try await reauthenticateCurrentProfile(profile.id)
            _ = try await authorizeWithApple(
                intent: .link,
                expectedPlayerID: profile.id
            )
            status = "Apple is now linked to this profile."
        } catch {
            status = error.localizedDescription
        }
    }

    private func linkGoogle(to profile: PlayerProfile) async {
        busy = true
        defer { busy = false }
        do {
            try await reauthenticateCurrentProfile(profile.id)
            let token = try await googleIdentity.signIn()
            _ = try await backend.linkGoogle(
                googleIDToken: token,
                expectedPlayerID: profile.id
            )
            status = "Google is now linked to this profile."
        } catch let error as BackendError where error.status == 409 {
            googleIdentity.signOut()
            status = error.localizedDescription
        } catch {
            status = error.localizedDescription
        }
    }

    private func reauthenticateCurrentProfile(_ playerID: String) async throws {
        if identityBindings.apple {
            _ = try await authorizeWithApple(
                intent: .reauth,
                expectedPlayerID: playerID
            )
            return
        }
        if identityBindings.google {
            let credential = try await googleReauthenticationCredential()
            do {
                _ = try await backend.reauthenticateWithGoogle(
                    googleIDToken: credential,
                    expectedPlayerID: playerID
                )
            } catch let error as BackendError where error.status == 409 {
                googleIdentity.signOut()
                throw error
            }
            return
        }
        throw BackendError(
            status: 401,
            message: "Link Apple or Google before continuing.",
            code: "primary-authentication-unavailable"
        )
    }

    private func startGameCenterLinkIfNeeded() {
        guard pendingGameCenterLink,
            !gameCenterLinking,
            gameCenterLinkTask == nil,
            let playerID = backend.profile?.id,
            case .authenticated(let player) = gameCenter.state
        else { return }
        guard player.scopedIDsArePersistent else {
            pendingGameCenterLink = false
            gameCenterLinkIssue = .unavailable(
                GameCenterServiceError.scopedIDsTransient.localizedDescription
            )
            return
        }

        gameCenterLinkGeneration += 1
        let generation = gameCenterLinkGeneration
        gameCenterLinking = true
        gameCenterLinkTask = Task { @MainActor in
            defer {
                if generation == gameCenterLinkGeneration {
                    gameCenterLinking = false
                    gameCenterLinkTask = nil
                }
            }
            do {
                let linked = try await performGameCenterLink(
                    playerID: playerID,
                    allowsReauthentication: true
                )
                guard generation == gameCenterLinkGeneration else { return }
                pendingGameCenterLink = false
                gameCenterLinkIssue = nil
                if linked {
                    let pending = backend.sessionState?.gameCenter?.pendingJobs ?? 0
                    status =
                        pending > 0
                        ? "Game Center publishing is enabled. \(pending) update\(pending == 1 ? "" : "s") queued."
                        : "Game Center publishing is enabled."
                } else {
                    status = "Game Center publishing is already ready."
                }
            } catch is CancellationError {
                return
            } catch {
                guard generation == gameCenterLinkGeneration else { return }
                pendingGameCenterLink = false
                recordGameCenterError(error)
            }
        }
    }

    private func performGameCenterLink(
        playerID: String,
        allowsReauthentication: Bool
    ) async throws -> Bool {
        do {
            return try await performSingleGameCenterLink(playerID: playerID)
        } catch let error as BackendError
            where allowsReauthentication && (error.status == 401 || error.status == 403)
        {
            gameCenterLinkIssue = .primaryReauthenticationRequired
            try await reauthenticateCurrentProfile(playerID)
            try Task.checkCancellation()
            _ = try await backend.loadSession()
            gameCenterLinkIssue = nil
            return try await performSingleGameCenterLink(playerID: playerID)
        }
    }

    private func performSingleGameCenterLink(playerID: String) async throws -> Bool {
        let session = try await backend.loadSession()
        guard session.authenticated, session.profile?.id == playerID else {
            throw BackendError(
                status: 401,
                message: "Sign in to the intended PimPoPom profile before linking Game Center.",
                code: "primary-profile-required"
            )
        }
        if session.gameCenter?.mirrorReady == true,
            session.gameCenter?.publicationEnabled == true
        {
            return false
        }
        guard pendingGameCenterLink,
            gameCenter.participationEnabled,
            backend.profile?.id == playerID,
            case .authenticated(let player) = gameCenter.state
        else { throw CancellationError() }
        guard player.scopedIDsArePersistent else {
            throw GameCenterServiceError.scopedIDsTransient
        }

        let challenge = try await backend.issueGameCenterLinkChallenge(
            expectedPlayerID: playerID
        )
        try Task.checkCancellation()
        guard pendingGameCenterLink,
            gameCenter.participationEnabled,
            backend.profile?.id == playerID,
            case .authenticated(let currentPlayer) = gameCenter.state,
            currentPlayer.scopedIDsArePersistent
        else { throw CancellationError() }

        let proof = try await gameCenter.fetchIdentityVerification()
        try Task.checkCancellation()
        _ = try await backend.linkGameCenter(
            challenge: challenge,
            verification: proof,
            expectedPlayerID: playerID
        )
        _ = try await backend.loadSession()
        return true
    }

    private func recordGameCenterError(_ error: Error) {
        if let backendError = error as? BackendError {
            switch backendError.status {
            case 409:
                gameCenterLinkIssue = .conflict(backendError.localizedDescription)
            case 401, 403:
                gameCenterLinkIssue = .primaryReauthenticationRequired
            default:
                gameCenterLinkIssue = .unavailable(backendError.localizedDescription)
            }
        } else {
            gameCenterLinkIssue = .unavailable(error.localizedDescription)
        }
        status = error.localizedDescription
    }

    private func signOut() async {
        busy = true
        defer { busy = false }
        do {
            _ = try await backend.logout()
            googleIdentity.signOut()
            pendingGameCenterLink = false
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

    private func requestConfirmedDeletion(for profile: PlayerProfile) {
        guard accountDeletionConfirmation == BackendClient.accountDeletionConfirmation else {
            accountDeletionStatus = "Type DELETE MY ACCOUNT exactly to continue."
            return
        }

        pendingDeletionProfileID = profile.id
        if identityBindings.apple, identityBindings.google {
            showsDeletionProviderChoice = true
        } else if identityBindings.apple {
            beginConfirmedDeletion(using: .apple)
        } else if identityBindings.google {
            beginConfirmedDeletion(using: .google)
        } else {
            pendingDeletionProfileID = nil
            accountDeletionStatus =
                "No verified sign-in method is linked to this profile. Refresh Profile and try again."
        }
    }

    private func beginConfirmedDeletion(using provider: ProfileReauthenticationProvider) {
        guard let playerID = pendingDeletionProfileID,
            backend.profile?.id == playerID
        else {
            accountDeletionStatus = ProfileAccountDeletionError.accountChanged.localizedDescription
            pendingDeletionProfileID = nil
            return
        }
        Task { await deleteAccount(playerID: playerID, using: provider) }
    }

    private func deleteAccount(
        playerID: String,
        using provider: ProfileReauthenticationProvider
    ) async {
        guard accountDeletionConfirmation == BackendClient.accountDeletionConfirmation else {
            accountDeletionStatus = "Type DELETE MY ACCOUNT exactly to continue."
            return
        }

        busy = true
        accountDeletionStatus = nil
        defer { busy = false }
        do {
            switch provider {
            case .apple:
                _ = try await authorizeWithApple(
                    intent: .reauth,
                    expectedPlayerID: playerID
                )
            case .google:
                let credential = try await googleReauthenticationCredential()
                _ = try await backend.reauthenticateWithGoogle(
                    googleIDToken: credential,
                    expectedPlayerID: playerID
                )
            }

            _ = try await backend.deleteAccount(
                confirmation: accountDeletionConfirmation,
                expectedPlayerID: playerID
            )
            googleIdentity.signOut()
            response = nil
            nickname = ""
            status = nil
            resetAccountDeletionForm()
            pendingDeletionProfileID = nil
            onDismiss()
        } catch let error as BackendError
            where error.code == BackendClient.accountDeletionAccountMismatchCode
        {
            googleIdentity.signOut()
            response = nil
            nickname = ""
            status = ProfileAccountDeletionError.accountChanged.localizedDescription
            resetAccountDeletionForm()
            pendingDeletionProfileID = nil
        } catch let error as BackendError where error.status == 409 {
            if case .google = provider {
                googleIdentity.signOut()
            }
            accountDeletionStatus = error.localizedDescription
        } catch {
            accountDeletionStatus = error.localizedDescription
        }
    }

    private func googleReauthenticationCredential() async throws -> String {
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

    private func cancelPendingRegistration() {
        if case .google? = pendingRegistration {
            googleIdentity.signOut()
        }
        pendingRegistration = nil
    }

    private func resetAccountDeletionForm() {
        showsAccountDeletionConfirmation = false
        showsDeletionProviderChoice = false
        accountDeletionConfirmation = ""
        accountDeletionStatus = nil
        pendingDeletionProfileID = nil
    }
}
