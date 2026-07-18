import Combine
import SwiftUI

@MainActor
final class AchievementsController: ObservableObject {
    @Published private(set) var payload: AchievementsResponse
    @Published private(set) var hasLoaded = false
    @Published private(set) var isLoading = false
    @Published private(set) var pendingClaimID: String?
    @Published private(set) var statusMessage: String
    @Published private(set) var statusIsError = false

    private let backend: BackendClient
    private var sessionObservation: AnyCancellable?
    private var requestGeneration = 0
    private var activePlayerID: String?
    private var activeAuthentication = false

    init(backend: BackendClient) {
        self.backend = backend
        activePlayerID = backend.profile?.id
        activeAuthentication = backend.isAuthenticated
        let initialPayload = AchievementCatalog.lockedResponse(
            authenticated: backend.isAuthenticated,
            coinBalance: backend.profile?.coins ?? 0
        )
        payload = initialPayload
        statusMessage = Self.defaultStatus(for: initialPayload)
        sessionObservation = backend.$sessionState.sink { [weak self] session in
            self?.applySessionIdentity(session)
        }
    }

    var claimedCount: Int { payload.claimedCount }
    var totalCount: Int { payload.totalCount }
    var claimableCount: Int { payload.claimableCount }

    var menuSummary: String {
        if !backend.isAuthenticated { return "Sign in to claim" }
        guard hasLoaded else { return "Loading…" }
        if statusIsError { return "Unavailable" }
        return "\(payload.claimedCount) / \(payload.totalCount) claimed"
    }

    func refresh(showLoading: Bool = true) async {
        guard pendingClaimID == nil else { return }
        requestGeneration += 1
        let generation = requestGeneration
        let playerID = backend.profile?.id
        if showLoading { isLoading = true }
        statusIsError = false
        if showLoading { statusMessage = "Loading achievements…" }
        defer {
            if generation == requestGeneration { isLoading = false }
        }

        do {
            let response = try await backend.loadAchievements()
            guard generation == requestGeneration,
                playerID == backend.profile?.id,
                !Task.isCancelled
            else { return }
            payload = response
            hasLoaded = true
            statusMessage = Self.defaultStatus(for: response)
        } catch {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            hasLoaded = true
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }

    func claim(_ achievement: AchievementItem) async {
        guard payload.authenticated,
            achievement.state == .claimable,
            pendingClaimID == nil
        else { return }

        requestGeneration += 1
        let generation = requestGeneration
        let playerID = backend.profile?.id
        pendingClaimID = achievement.id
        statusMessage = "Claiming “\(achievement.title)”…"
        statusIsError = false
        defer {
            if pendingClaimID == achievement.id { pendingClaimID = nil }
        }

        do {
            let response = try await backend.claimAchievement(achievement.id)
            guard generation == requestGeneration,
                playerID == backend.profile?.id,
                !Task.isCancelled
            else { return }
            payload = response
            hasLoaded = true
            let coins = response.coinsEarned ?? 0
            statusMessage =
                response.duplicate == true
                ? "“\(achievement.title)” was already claimed."
                : "\(achievement.title) claimed — \(coins) \(coins == 1 ? "coin" : "coins") credited."
        } catch {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }

    private func applySessionIdentity(_ session: SessionResponse?) {
        let playerID = session?.profile?.id
        let authenticated = session?.authenticated == true
        guard playerID != activePlayerID || authenticated != activeAuthentication else { return }
        activePlayerID = playerID
        activeAuthentication = authenticated
        requestGeneration += 1
        hasLoaded = false
        isLoading = false
        pendingClaimID = nil
        statusIsError = false
        payload = AchievementCatalog.lockedResponse(
            authenticated: authenticated,
            coinBalance: session?.profile?.coins ?? 0
        )
        statusMessage = Self.defaultStatus(for: payload)
        if authenticated {
            Task { [weak self] in
                await self?.refresh(showLoading: false)
            }
        }
    }

    private static func defaultStatus(for payload: AchievementsResponse) -> String {
        if !payload.authenticated {
            return "Sign in with Google in Profile to track and claim achievements."
        }
        if payload.claimableCount > 0 {
            return "Tap a green check to collect its coin reward."
        }
        return "Keep playing to unlock more achievements."
    }
}

struct AchievementsView: View {
    @EnvironmentObject private var achievements: AchievementsController
    @EnvironmentObject private var cosmetics: CosmeticsController

    let onDismiss: () -> Void
    let onOpenProfile: () -> Void

    private var palette: ThemePalette { cosmetics.theme }
    private var rewardGreen: Color { Color(hex: palette.isLight ? "#18894a" : "#72e995") }

    var body: some View {
        NavigationStack {
            ZStack {
                AppThemeBackground(theme: palette)

                ScrollView {
                    LazyVStack(spacing: 11) {
                        progressHeader

                        ForEach(achievements.payload.achievements) { achievement in
                            achievementButton(achievement)
                        }

                        Text(achievements.statusMessage)
                            .font(
                                palette.appFont(
                                    size: 13,
                                    weight: .semibold,
                                    relativeTo: .footnote
                                )
                            )
                            .foregroundStyle(
                                achievements.statusIsError
                                    ? Color.orange
                                    : Color(hex: palette.muted)
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("achievements-status")

                        if !achievements.payload.authenticated {
                            Button(action: onOpenProfile) {
                                Label("Open Profile", systemImage: "person.badge.key.fill")
                            }
                            .buttonStyle(
                                WebSecondaryButtonStyle(
                                    theme: palette,
                                    accent: Color(hex: palette.achievementsAccent),
                                    minimumHeight: 48
                                )
                            )
                            .accessibilityIdentifier("achievements-open-profile")
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
                }

                if achievements.isLoading {
                    WebLoadingOverlay(theme: palette, label: "Loading achievements")
                }
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Achievements")
                        .font(
                            palette.appFont(
                                size: 19,
                                weight: .black,
                                relativeTo: .headline
                            )
                        )
                        .foregroundStyle(Color(hex: palette.foreground))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .task { await achievements.refresh() }
    }

    private var progressHeader: some View {
        VStack(spacing: 11) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 12)
                        .fill(Color(hex: palette.achievementsAccent).opacity(0.16))
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Color(hex: palette.achievementsAccent))
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text("REWARD BOARD")
                        .font(
                            palette.appFont(
                                size: 11,
                                weight: .black,
                                relativeTo: .caption
                            )
                        )
                        .tracking(palette.isPixel ? 0 : 1.1)
                        .foregroundStyle(Color(hex: palette.muted))
                    Text("\(achievements.claimedCount) of \(achievements.totalCount) claimed")
                        .font(
                            palette.appFont(
                                size: 20,
                                weight: .black,
                                relativeTo: .title3
                            )
                        )
                }

                Spacer(minLength: 8)
            }

            GeometryReader { proxy in
                let fraction =
                    achievements.totalCount > 0
                    ? CGFloat(achievements.claimedCount) / CGFloat(achievements.totalCount)
                    : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: palette.foreground).opacity(0.10))
                    Capsule()
                        .fill(Color(hex: palette.achievementsAccent))
                        .frame(width: proxy.size.width * min(1, max(0, fraction)))
                }
            }
            .frame(height: palette.isPixel ? 8 : 7)
            .clipShape(palette.isPixel ? AnyShape(Rectangle()) : AnyShape(Capsule()))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Achievement progress")
            .accessibilityValue("\(achievements.claimedCount) of \(achievements.totalCount)")
            .accessibilityIdentifier("achievements-progress")
        }
        .foregroundStyle(Color(hex: palette.foreground))
        .webCardStyle(
            theme: palette,
            selectedAccent: Color(hex: palette.achievementsAccent),
            padding: 14
        )
    }

    private func achievementButton(_ item: AchievementItem) -> some View {
        Button {
            Task { await achievements.claim(item) }
        } label: {
            HStack(spacing: 11) {
                statusIcon(for: item)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(
                            palette.appFont(
                                size: 16,
                                weight: .black,
                                relativeTo: .body
                            )
                        )
                        .foregroundStyle(Color(hex: palette.foreground))
                    Text(item.description)
                        .font(palette.appFont(size: 12, relativeTo: .caption))
                        .foregroundStyle(Color(hex: palette.muted))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                reward(for: item)
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
            .modifier(
                AchievementCardModifier(
                    theme: palette,
                    state: item.state,
                    rewardGreen: rewardGreen
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(item.state != .claimable || achievements.pendingClaimID != nil)
        .opacity(item.state == .claimed ? 0.76 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityValue(accessibilityValue(for: item))
        .accessibilityHint(item.state == .claimable ? "Double tap to claim the coin reward" : "")
        .accessibilityIdentifier("achievement-card-\(item.id)")
    }

    private func statusIcon(for item: AchievementItem) -> some View {
        let shape = RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 11)
        let foreground: Color =
            switch item.state {
            case .locked: Color(hex: palette.muted).opacity(0.75)
            case .claimable: palette.isLight ? Color.white : Color(hex: "#092a17")
            case .claimed: Color(hex: palette.isLight ? "#ffffff" : "#272b35")
            }
        let fill: Color =
            switch item.state {
            case .locked: Color(hex: palette.foreground).opacity(0.04)
            case .claimable: rewardGreen
            case .claimed: Color(hex: palette.isLight ? "#7c8797" : "#969dab")
            }

        return ZStack {
            shape.fill(fill)
            shape.stroke(
                item.state == .claimable
                    ? rewardGreen
                    : Color(hex: palette.foreground).opacity(0.14),
                lineWidth: palette.isPixel ? 2 : 1
            )
            Image(systemName: item.state == .locked ? "lock.fill" : "checkmark")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(foreground)
        }
        .frame(width: 40, height: 40)
        .shadow(
            color: item.state == .claimable ? rewardGreen.opacity(0.32) : .clear,
            radius: palette.isPixel ? 0 : 9
        )
    }

    private func reward(for item: AchievementItem) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 4) {
                Text("+\(item.rewardCoins)")
                PixelCoinView(size: 16)
            }
            .font(palette.appFont(size: 13, weight: .black, relativeTo: .caption))
            .foregroundStyle(item.state == .claimable ? rewardGreen : Color(hex: palette.muted))

            if achievements.pendingClaimID == item.id {
                ProgressView().controlSize(.small).tint(rewardGreen)
            } else if item.state == .claimable {
                Text("CLAIM")
                    .foregroundStyle(rewardGreen)
            } else if item.state == .claimed {
                Text("CLAIMED")
                    .foregroundStyle(Color(hex: palette.muted))
            }
        }
        .font(palette.appFont(size: 10, weight: .black, relativeTo: .caption2))
        .frame(minWidth: 57, alignment: .trailing)
    }

    private func accessibilityValue(for item: AchievementItem) -> String {
        let state =
            switch item.state {
            case .locked: "Locked"
            case .claimable: achievements.pendingClaimID == item.id ? "Claiming" : "Ready to claim"
            case .claimed: "Claimed"
            }
        return "\(state). Reward: \(item.rewardCoins) \(item.rewardCoins == 1 ? "coin" : "coins")"
    }
}

private struct AchievementCardModifier: ViewModifier {
    let theme: ThemePalette
    let state: AchievementState
    let rewardGreen: Color

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 14, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .background {
                if theme.isPixel {
                    shape
                        .fill(Color(hex: "#070713"))
                        .offset(x: 4, y: 4)
                }
                shape
                    .fill(Color(hex: theme.surface).opacity(theme.isLight ? 0.86 : 0.90))
                if state == .claimable {
                    shape.fill(rewardGreen.opacity(theme.isLight ? 0.10 : 0.13))
                } else if state == .claimed {
                    shape.fill(Color(hex: theme.foreground).opacity(0.035))
                }
            }
            .overlay {
                shape.stroke(
                    state == .claimable
                        ? rewardGreen.opacity(0.78)
                        : Color(hex: theme.foreground).opacity(state == .claimed ? 0.09 : 0.14),
                    lineWidth: theme.isPixel ? 2 : 1
                )
            }
            .shadow(
                color: state == .claimable && !theme.isPixel
                    ? rewardGreen.opacity(0.16)
                    : .clear,
                radius: 12
            )
    }
}
