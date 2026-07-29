import PimPoPomCore
import SwiftUI
import UIKit

struct MultiplayerMenuLink<Destination: View>: View {
    let availability: MultiplayerPresentation.Availability
    let theme: ThemePalette
    private let destination: Destination

    init(
        availability: MultiplayerPresentation.Availability,
        theme: ThemePalette,
        @ViewBuilder destination: () -> Destination
    ) {
        self.availability = availability
        self.theme = theme
        self.destination = destination()
    }

    var body: some View {
        Group {
            if availability.isAvailable {
                NavigationLink(destination: destination) {
                    label
                }
                .buttonStyle(MultiplayerModeButtonStyle(theme: theme))
            } else {
                Button(action: {}) {
                    label
                }
                .buttonStyle(MultiplayerModeButtonStyle(theme: theme))
                .disabled(true)
            }
        }
        .accessibilityLabel("Multiplayer")
        .accessibilityValue(availability.menuMessage)
        .accessibilityHint(
            availability.isAvailable
                ? "Opens available multiplayer games"
                : availability.menuMessage.capitalized
        )
        .accessibilityIdentifier("mode-multiplayer")
    }

    private var label: some View {
        VStack(spacing: 3) {
            HStack(spacing: 7) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 15, weight: .black))
                Text("Multiplayer")
                    .font(theme.appFont(size: 20, weight: .black, relativeTo: .title3))
            }
            Text(availability.menuMessage)
                .font(theme.appFont(size: 9, weight: .bold, relativeTo: .caption2))
                .tracking(0.55)
        }
        .foregroundStyle(Color(hex: "#f8f5ff"))
    }
}

private struct MultiplayerModeButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let theme: ThemePalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: WebMenuMetrics.modeHeight)
            .background {
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: "#43a9ff"), Color(hex: "#6943d7")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    RadialGradient(
                        colors: [.white.opacity(0.42), .clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: 105
                    )
                }
                .saturation(isEnabled ? 1 : 0.18)
                .brightness(isEnabled ? 0 : -0.18)
            }
            .clipShape(shape)
            .overlay {
                shape.stroke(
                    Color(hex: isEnabled ? "#a9e9ff" : "#777b8f").opacity(0.88),
                    lineWidth: theme.isPixel ? 2 : 1
                )
            }
            .shadow(
                color: isEnabled ? Color(hex: "#58bfff").opacity(0.45) : .clear,
                radius: theme.isPixel ? 0 : 10
            )
            .opacity(isEnabled ? 1 : 0.72)
            .offset(y: configuration.isPressed ? 1 : 0)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 15, style: .continuous)
    }
}

struct MultiplayerHubView: View {
    @EnvironmentObject private var cosmetics: CosmeticsController

    let state: MultiplayerPresentation.HubState
    let onRefresh: () -> Void
    let onCreate: (Int) -> Void
    let onJoin: (String) -> Void

    @State private var capacity = 2

    private var palette: ThemePalette { cosmetics.theme }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: palette)

            VStack(spacing: 12) {
                header
                availabilityCard
                createCard
                lobbyList
            }
            .foregroundStyle(Color(hex: palette.foreground))
            .padding(14)
            .frame(maxWidth: 620, maxHeight: .infinity)
            .webCardStyle(theme: palette, padding: 14)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .navigationTitle("Multiplayer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Multiplayer")
                    .font(palette.appFont(size: 19, weight: .black, relativeTo: .headline))
                    .foregroundStyle(Color(hex: palette.foreground))
            }
        }
        .accessibilityIdentifier("multiplayer-hub")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            PimPoPomWordmark(
                theme: palette,
                size: 25,
                suffix: "MP",
                identifier: "multiplayer-wordmark"
            )
            Spacer()
            NavigationLink {
                LeaderboardView(initialMode: .multiplayer)
            } label: {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18, weight: .black))
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: palette,
                    accent: Color(hex: palette.chromeAccent),
                    minimumHeight: 42
                )
            )
            .frame(width: 42)
            .accessibilityLabel("Multiplayer leaderboard")
            .accessibilityIdentifier("open-multiplayer-leaderboard")

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 42, height: 42)
                    .rotationEffect(state.isRefreshing ? .degrees(360) : .zero)
                    .animation(
                        state.isRefreshing
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default,
                        value: state.isRefreshing
                    )
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: palette,
                    minimumHeight: 42
                )
            )
            .frame(width: 42)
            .disabled(state.isRefreshing)
            .accessibilityLabel("Refresh available games")
            .accessibilityIdentifier("refresh-multiplayer-lobbies")
        }
    }

    @ViewBuilder
    private var availabilityCard: some View {
        if !state.availability.isAvailable {
            HStack(spacing: 10) {
                Image(systemName: availabilityIcon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(hex: palette.petsAccent))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Multiplayer needs one more step")
                        .font(palette.appFont(size: 14, weight: .black, relativeTo: .headline))
                    Text(state.availability.menuMessage.capitalized)
                        .font(palette.appFont(size: 11, weight: .bold, relativeTo: .caption))
                        .foregroundStyle(Color(hex: palette.muted))
                }
                Spacer()
            }
            .webCardStyle(
                theme: palette,
                selectedAccent: Color(hex: palette.petsAccent).opacity(0.72),
                padding: 12
            )
            .accessibilityIdentifier("multiplayer-prerequisite")
        }
    }

    private var availabilityIcon: String {
        switch state.availability {
        case .available:
            "checkmark.circle.fill"
        case .signInRequired:
            "person.badge.key.fill"
        case .confirmedNameRequired:
            "person.text.rectangle.fill"
        case .gameCenterRequired:
            "gamecontroller.fill"
        }
    }

    private var createCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CREATE A GAME")
                .font(palette.appFont(size: 10, weight: .black, relativeTo: .caption2))
                .tracking(0.9)
                .foregroundStyle(Color(hex: palette.muted))

            HStack(spacing: 8) {
                ForEach(2...4, id: \.self) { count in
                    Button {
                        capacity = count
                    } label: {
                        VStack(spacing: 1) {
                            Text("\(count)")
                                .font(palette.appFont(size: 18, weight: .black, relativeTo: .headline))
                            Text(count == 2 ? "players" : "players")
                                .font(palette.appFont(size: 8, weight: .bold, relativeTo: .caption2))
                        }
                        .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(
                        WebSecondaryButtonStyle(
                            theme: palette,
                            accent: capacity == count ? Color(hex: palette.chromeAccent) : nil,
                            borderAccent: capacity == count
                                ? Color(hex: palette.chromeAccent)
                                : nil,
                            minimumHeight: 42
                        )
                    )
                    .accessibilityAddTraits(capacity == count ? .isSelected : [])
                    .accessibilityIdentifier("multiplayer-capacity-\(count)")
                }
            }

            Button {
                onCreate(capacity)
            } label: {
                Label(
                    state.isCreating ? "Creating…" : "Create \(capacity)-player game",
                    systemImage: "plus.circle.fill"
                )
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: palette,
                    accent: Color(hex: palette.themesAccent)
                )
            )
            .disabled(
                !state.availability.isAvailable
                    || state.isCreating
                    || state.joiningLobbyID != nil
            )
            .accessibilityIdentifier("create-multiplayer-game")
        }
        .webCardStyle(theme: palette, padding: 12)
    }

    @ViewBuilder
    private var lobbyList: some View {
        if state.lobbies.isEmpty, !state.isRefreshing {
            VStack(spacing: 10) {
                Spacer(minLength: 16)
                Image(systemName: "person.3.sequence.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color(hex: palette.chromeAccent))
                Text(state.message ?? "No open games yet")
                    .font(palette.appFont(size: 15, weight: .bold, relativeTo: .body))
                    .foregroundStyle(Color(hex: palette.muted))
                    .multilineTextAlignment(.center)
                Text("Create one, or pull to refresh.")
                    .font(palette.appFont(size: 11, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(Color(hex: palette.muted).opacity(0.82))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("multiplayer-lobbies-empty")
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(state.lobbies) { lobby in
                        lobbyRow(lobby)
                    }
                }
                .padding(.vertical, 2)
            }
            .refreshable { onRefresh() }
            .accessibilityIdentifier("multiplayer-lobbies")
        }
    }

    private func lobbyRow(_ lobby: MultiplayerPresentation.Lobby) -> some View {
        HStack(spacing: 10) {
            Group {
                if let petID = lobby.hostPetID {
                    PetCompanionView(petID: petID, size: 38, placement: .leaderboard)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color(hex: palette.muted).opacity(0.6))
                }
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(lobby.hostName)
                    .font(palette.appFont(size: 14, weight: .black, relativeTo: .headline))
                    .lineLimit(1)
                Text(
                    "\(lobby.playerCount)/\(lobby.capacity) players · \(lobby.openSeatCount) open"
                )
                .font(palette.appFont(size: 10, weight: .bold, relativeTo: .caption))
                .foregroundStyle(Color(hex: palette.muted))
            }
            Spacer(minLength: 8)
            Button {
                onJoin(lobby.id)
            } label: {
                Text(state.joiningLobbyID == lobby.id ? "Joining…" : "Join")
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: palette,
                    accent: Color(hex: palette.chromeAccent),
                    minimumHeight: 40
                )
            )
            .frame(width: 92)
            .disabled(
                !state.availability.isAvailable
                    || state.joiningLobbyID != nil
                    || state.isCreating
                    || lobby.openSeatCount == 0
            )
            .accessibilityIdentifier("join-multiplayer-\(lobby.id)")
        }
        .webCardStyle(theme: palette, padding: 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("multiplayer-lobby-\(lobby.id)")
    }
}

enum MultiplayerWaitingRoomLayoutMetrics {
    static let participantTopOffset: CGFloat = 20
    static let participantRowHeight: CGFloat = 48
    static let participantCardPadding: CGFloat = 9
    static let actionHeight: CGFloat = 48
}

struct MultiplayerWaitingRoomView: View {
    @EnvironmentObject private var cosmetics: CosmeticsController

    let state: MultiplayerPresentation.WaitingRoomState
    let onToggleReady: (Bool) -> Void
    let onStart: () -> Void
    let onLeave: () -> Void
    let onRetryConnection: () -> Void

    private var palette: ThemePalette { cosmetics.theme }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: palette)

            GeometryReader { proxy in
                let compact =
                    max(proxy.size.width, proxy.size.height) <= 667

                VStack(spacing: compact ? 6 : 12) {
                    header(compact: compact)
                    if let message = state.message {
                        Text(message)
                            .font(
                                palette.appFont(
                                    size: compact ? 9 : 10,
                                    weight: .bold,
                                    relativeTo: .caption
                                )
                            )
                            .foregroundStyle(Color(hex: palette.petsAccent))
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("multiplayer-waiting-message")
                    }
                    Color.clear
                        .frame(height: MultiplayerWaitingRoomLayoutMetrics.participantTopOffset)
                        .accessibilityHidden(true)
                    participantGrid
                    Spacer(minLength: compact ? 0 : 4)
                    actionRow
                }
                .foregroundStyle(Color(hex: palette.foreground))
                .padding(compact ? 10 : 14)
                .frame(maxWidth: 620, maxHeight: .infinity)
                .webCardStyle(theme: palette, padding: compact ? 10 : 14)
                .padding(.horizontal, 12)
                .padding(.vertical, compact ? 4 : 8)
            }
        }
        .navigationTitle("Waiting Room")
        .navigationBarBackButtonHidden(true)
    }

    private func header(compact: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                PimPoPomWordmark(
                    theme: palette,
                    size: compact ? 16 : 18,
                    suffix: "MP",
                    identifier: "multiplayer-waiting-wordmark"
                )
                Text("\(state.participants.count)/\(state.capacity) players")
                    .font(
                        palette.appFont(
                            size: compact ? 20 : 24,
                            weight: .black,
                            relativeTo: .title2
                        )
                    )
            }
            Spacer()
            Button("Leave", action: onLeave)
                .font(palette.appFont(size: 12, weight: .bold, relativeTo: .caption))
                .buttonStyle(
                    WebSecondaryButtonStyle(
                        theme: palette,
                        accent: Color(hex: palette.petsAccent),
                        minimumHeight: compact ? 36 : 40
                    )
                )
                .frame(width: 86)
                .disabled(state.isMutationPending)
                .accessibilityIdentifier("leave-multiplayer")
        }
    }

    private var connectionCard: some View {
        HStack(spacing: 9) {
            Image(systemName: connectionIcon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(connectionColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.connection.title)
                    .font(palette.appFont(size: 12, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(Color(hex: palette.muted))
                if let detail = state.connection.detail {
                    Text(detail)
                        .font(
                            palette.appFont(
                                size: 9,
                                weight: .regular,
                                relativeTo: .caption2
                            )
                        )
                        .foregroundStyle(Color(hex: palette.muted).opacity(0.86))
                }
            }
            Spacer()
            if state.connection.canRetry {
                Button("Retry", action: onRetryConnection)
                    .font(palette.appFont(size: 10, weight: .bold, relativeTo: .caption2))
                    .buttonStyle(
                        WebSecondaryButtonStyle(
                            theme: palette,
                            accent: connectionColor,
                            minimumHeight: 36
                        )
                    )
                    .frame(width: 72)
                    .accessibilityIdentifier("retry-multiplayer-connection")
            }
        }
        .webCardStyle(theme: palette, selectedAccent: connectionColor.opacity(0.55), padding: 10)
        .accessibilityIdentifier("multiplayer-roster-state")
    }

    private var connectionIcon: String {
        switch state.connection {
        case .matching:
            "person.2.wave.2.fill"
        case .confirmingRoster:
            "checkmark.shield.fill"
        case .ready:
            "checkmark.seal.fill"
        case .cloudSyncRequired:
            "icloud.slash.fill"
        case .connectionFailed, .failed:
            "exclamationmark.triangle.fill"
        }
    }

    private var connectionColor: Color {
        switch state.connection {
        case .ready:
            Color(hex: "#72e995")
        case .cloudSyncRequired, .connectionFailed, .failed:
            Color(hex: palette.petsAccent)
        default:
            Color(hex: palette.chromeAccent)
        }
    }

    private var participantGrid: some View {
        VStack(spacing: 8) {
            ForEach(state.participants.sorted(by: { $0.seat < $1.seat })) { player in
                waitingParticipant(player)
            }
            ForEach(state.participants.count..<state.capacity, id: \.self) { seat in
                emptySeat(seat)
            }
        }
    }

    private func waitingParticipant(_ player: MultiplayerPresentation.Participant) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color(hex: palette.muted).opacity(0.72))
                .frame(width: 32, height: 32)

            Circle()
                .fill(palette.color(at: player.colorIndex))
                .frame(width: 15, height: 15)
                .overlay { Circle().stroke(.white.opacity(0.86), lineWidth: 2) }
                .shadow(color: palette.color(at: player.colorIndex), radius: palette.isPixel ? 0 : 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(palette.appFont(size: 13, weight: .black, relativeTo: .headline))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .allowsTightening(true)
                    .layoutPriority(1)
                Text(player.ready ? "READY" : (player.isConnected ? "NOT READY" : "RECONNECTING"))
                    .font(palette.appFont(size: 8, weight: .black, relativeTo: .caption2))
                    .foregroundStyle(
                        player.ready
                            ? Color(hex: "#72e995")
                            : Color(hex: palette.muted)
                    )
            }
            Spacer(minLength: 0)
        }
        .padding(.trailing, player.isCreator ? 18 : 0)
        .frame(
            maxWidth: .infinity,
            minHeight: MultiplayerWaitingRoomLayoutMetrics.participantRowHeight,
            alignment: .leading
        )
        .webCardStyle(
            theme: palette,
            selectedAccent: palette.color(at: player.colorIndex).opacity(0.68),
            padding: MultiplayerWaitingRoomLayoutMetrics.participantCardPadding
        )
        .overlay(alignment: .topTrailing) {
            if player.isCreator {
                Image(systemName: "crown.fill")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(Color(hex: "#ffd84d"))
                    .padding(8)
            }
        }
        .opacity(player.isConnected ? 1 : 0.60)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("multiplayer-waiting-player-\(player.seat)")
    }

    private func emptySeat(_ seat: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 20, weight: .semibold))
            Text("Waiting for player")
                .font(palette.appFont(size: 11, weight: .bold, relativeTo: .caption))
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color(hex: palette.muted).opacity(0.70))
        .frame(
            maxWidth: .infinity,
            minHeight: MultiplayerWaitingRoomLayoutMetrics.participantRowHeight,
            alignment: .leading
        )
        .webCardStyle(
            theme: palette,
            padding: MultiplayerWaitingRoomLayoutMetrics.participantCardPadding
        )
        .accessibilityIdentifier("multiplayer-empty-seat-\(seat)")
    }

    private var actionRow: some View {
        VStack(spacing: 8) {
            if state.connection.shouldPresentFailure {
                connectionCard
            }

            if let current = state.currentPlayer {
                Button {
                    onToggleReady(!current.ready)
                } label: {
                    Label(
                        current.ready ? "Not ready" : "Ready",
                        systemImage: current.ready ? "xmark.circle.fill" : "checkmark.circle.fill"
                    )
                }
                .buttonStyle(
                    WebSecondaryButtonStyle(
                        theme: palette,
                        accent: current.ready
                            ? Color(hex: palette.muted)
                            : Color(hex: "#72e995"),
                        minimumHeight: MultiplayerWaitingRoomLayoutMetrics.actionHeight
                    )
                )
                .disabled(!state.canToggleReady)
                .accessibilityIdentifier("multiplayer-ready")
            }

            Button(action: onStart) {
                Label(
                    state.startMatchControlState.title,
                    systemImage: state.startMatchControlState.systemImage
                )
            }
            .buttonStyle(
                WebSecondaryButtonStyle(
                    theme: palette,
                    accent: Color(hex: palette.achievementsAccent),
                    minimumHeight: MultiplayerWaitingRoomLayoutMetrics.actionHeight
                )
            )
            .disabled(!state.canStart)
            .accessibilityIdentifier("start-multiplayer-match")
        }
    }
}

enum MultiplayerLiveLayoutMetrics {
    static let horizontalInset: CGFloat = 12
    static let hudHeight: CGFloat = 64
    static let badgeHeight: CGFloat = 44
    static let badgeSpacing: CGFloat = 4
    static let boardToSpeedBarSpacing: CGFloat = 14
    static let speedBarHeight: CGFloat = 50
    static let speedBarToBadgesSpacing: CGFloat = 8
    static let verticalPadding: CGFloat = 8
    static let minimumBoardSide: CGFloat = 220

    struct Plan: Equatable {
        let boardSide: CGFloat
        let hudToBoardSpacing: CGFloat
        let playerStripHeight: CGFloat
        let playerBadgeWidth: CGFloat
    }

    static func resolve(availableSize: CGSize, playerCount: Int) -> Plan {
        let count = max(1, min(4, playerCount))
        let hudToBoardSpacing: CGFloat = 5
        let playerStripHeight = count > 0 ? badgeHeight : 0
        let reservedHeight =
            verticalPadding * 2
            + hudHeight
            + hudToBoardSpacing
            + boardToSpeedBarSpacing
            + speedBarHeight
            + speedBarToBadgesSpacing
            + playerStripHeight
        let widthBound = max(0, availableSize.width - horizontalInset * 2)
        let heightBound = max(minimumBoardSide, availableSize.height - reservedHeight)
        let playerBadgeWidth = max(
            0,
            (widthBound
                - CGFloat(max(0, count - 1)) * badgeSpacing) / CGFloat(count)
        )

        return Plan(
            boardSide: min(widthBound, heightBound),
            hudToBoardSpacing: hudToBoardSpacing,
            playerStripHeight: playerStripHeight,
            playerBadgeWidth: playerBadgeWidth
        )
    }
}

struct MultiplayerLiveView: View {
    @EnvironmentObject private var cosmetics: CosmeticsController

    let state: MultiplayerPresentation.LiveMatchState
    let onTapCell: (Int, Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 4)
    private var palette: ThemePalette { cosmetics.theme }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: palette)

            GeometryReader { proxy in
                let layout = MultiplayerLiveLayoutMetrics.resolve(
                    availableSize: proxy.size,
                    playerCount: state.players.count
                )
                VStack(spacing: 0) {
                    liveHeader
                        .frame(height: MultiplayerLiveLayoutMetrics.hudHeight)
                    Color.clear
                        .frame(height: layout.hudToBoardSpacing)
                        .accessibilityHidden(true)
                    board
                        .frame(width: layout.boardSide, height: layout.boardSide)
                    Color.clear
                        .frame(height: MultiplayerLiveLayoutMetrics.boardToSpeedBarSpacing)
                        .accessibilityHidden(true)
                    speedBar
                    Color.clear
                        .frame(height: MultiplayerLiveLayoutMetrics.speedBarToBadgesSpacing)
                        .accessibilityHidden(true)
                    playerStrip(badgeWidth: layout.playerBadgeWidth)
                        .frame(height: layout.playerStripHeight)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, MultiplayerLiveLayoutMetrics.horizontalInset)
                .padding(.vertical, MultiplayerLiveLayoutMetrics.verticalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            if let announcement = state.announcement {
                GlowStampView(
                    text: announcement,
                    tone: Color(hex: palette.achievementsAccent),
                    theme: palette,
                    tilt: -4,
                    size: 18
                )
                .transition(.opacity.combined(with: .scale(scale: 0.88)))
                .zIndex(10)
                .accessibilityIdentifier("multiplayer-announcement")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var liveHeader: some View {
        GeometryReader { proxy in
            let gap: CGFloat = 7
            let usableWidth = max(0, proxy.size.width - gap * 2)
            let sideWidth = min(82, max(70, usableWidth * 0.21))

            HStack(spacing: gap) {
                multiplayerStatCard(
                    label: "Points",
                    value: "\(state.localPlayer?.points ?? 0)",
                    identifier: "multiplayer-points"
                )
                .frame(width: sideWidth)

                localColorCard

                multiplayerLivesCard
                    .frame(width: sideWidth)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("multiplayer-live-header")
    }

    private func multiplayerStatCard(
        label: String,
        value: String,
        identifier: String
    ) -> some View {
        VStack(spacing: 1) {
            Text(label.uppercased())
                .font(palette.appFont(size: 7, weight: .black, relativeTo: .caption2))
                .tracking(0.35)
                .foregroundStyle(Color(hex: palette.muted))
                .lineLimit(1)
            Text(value)
                .font(palette.appFont(size: 13, weight: .black, relativeTo: .headline))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 3)
        .background(
            Color(hex: palette.surface).opacity(palette.isLight ? 0.88 : 0.78),
            in: hudShape
        )
        .overlay {
            hudShape.stroke(
                palette.isLight
                    ? Color(hex: "#477694").opacity(0.18)
                    : Color(hex: palette.foreground).opacity(0.10),
                lineWidth: palette.isPixel ? 2 : 1
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private var localColorCard: some View {
        HStack(spacing: 9) {
            if let local = state.localPlayer {
                GameCellPreview(
                    theme: palette,
                    colorIndex: local.colorIndex,
                    glyph: gameColors.indices.contains(local.colorIndex)
                        ? gameColors[local.colorIndex].glyph
                        : "●",
                    showsGlyphs: true,
                    isTarget: true,
                    glyphScale: GameCellVisualMetrics.previewGlyphScale
                )
                .frame(width: 48, height: 48)

                Text(localColorName(local.colorIndex))
                    .font(palette.appFont(size: 16, weight: .black, relativeTo: .headline))
                    .foregroundStyle(Color(hex: palette.foreground))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Color.clear
                    .frame(width: 48, height: 48)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color(hex: palette.surface).opacity(palette.isLight ? 0.88 : 0.78),
            in: hudShape
        )
        .overlay {
            hudShape
                .stroke(
                    state.localPlayer.map { palette.color(at: $0.colorIndex) }
                        ?? Color(hex: palette.foreground).opacity(0.10),
                    lineWidth: GameHUDMetrics.colorHeroOutlineWidth
                )
                .shadow(
                    color: (state.localPlayer.map { palette.color(at: $0.colorIndex) }
                        ?? .clear).opacity(GameHUDMetrics.colorHeroGlowOpacity),
                    radius: palette.isPixel ? 3 : GameHUDMetrics.colorHeroGlowRadius
                )
                .shadow(
                    color: (state.localPlayer.map { palette.color(at: $0.colorIndex) }
                        ?? .clear).opacity(GameHUDMetrics.colorHeroGlowOpacity * 0.58),
                    radius: palette.isPixel ? 1 : GameHUDMetrics.colorHeroGlowRadius * 1.65
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Assigned color \(localColorName(state.localPlayer?.colorIndex))")
        .accessibilityIdentifier("multiplayer-your-color")
    }

    private var multiplayerLivesCard: some View {
        VStack(spacing: 1) {
            Text("LIVES")
                .font(palette.appFont(size: 7, weight: .black, relativeTo: .caption2))
                .tracking(0.35)
                .foregroundStyle(Color(hex: palette.muted))
            if palette.isPixel {
                PixelLivesView(
                    remaining: max(0, min(3, state.localPlayer?.lives ?? 0)),
                    color: Color(hex: GameHUDMetrics.livesColorHex)
                )
                .frame(height: 14)
            } else {
                Text(multiplayerLivesPresentation)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: GameHUDMetrics.livesColorHex))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 3)
        .background(
            Color(hex: palette.surface).opacity(palette.isLight ? 0.88 : 0.78),
            in: hudShape
        )
        .overlay {
            hudShape.stroke(
                palette.isLight
                    ? Color(hex: "#477694").opacity(0.18)
                    : Color(hex: palette.foreground).opacity(0.10),
                lineWidth: palette.isPixel ? 2 : 1
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("multiplayer-lives")
    }

    private var multiplayerLivesPresentation: String {
        let lives = max(0, min(3, state.localPlayer?.lives ?? 0))
        return String(repeating: "♥", count: lives)
            + String(repeating: "♡", count: 3 - lives)
    }

    private func localColorName(_ colorIndex: Int?) -> String {
        guard let colorIndex, gameColors.indices.contains(colorIndex) else {
            return ""
        }
        return gameColors[colorIndex].name
    }

    private var hudShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 11, style: .continuous)
    }

    private var board: some View {
        ZStack {
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(state.orderedCells) { cell in
                    ZStack {
                        GameCellPreview(
                            theme: palette,
                            colorIndex: cell.colorIndex,
                            glyph: cell.glyph,
                            showsGlyphs: cell.colorIndex != nil,
                            isTarget: cell.isTarget,
                            textureSeed: cell.id,
                            glyphScale: GameCellVisualMetrics.liveGlyphScale(gridDimension: 4)
                        )
                        .overlay(alignment: .topTrailing) {
                            if cell.isDecoy {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundStyle(.white.opacity(0.72))
                                    .padding(5)
                            }
                        }

                        MultiplayerTouchCell(
                            isEnabled: !state.isRecovering && !state.isSpectating,
                            accessibilityLabel: cellAccessibilityLabel(cell),
                            accessibilityIdentifier: "multiplayer-cell-\(cell.id)"
                        ) { touchTimestampMilliseconds in
                            onTapCell(cell.id, touchTimestampMilliseconds)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .padding(12)

            MultiplayerBoardGapTouchLayer(
                isEnabled: !state.isRecovering && !state.isSpectating
            ) {
                cell, touchTimestampMilliseconds in
                onTapCell(cell, touchTimestampMilliseconds)
            }
            .accessibilityHidden(true)
        }
        .background(
            Color(hex: palette.board),
            in: RoundedRectangle(
                cornerRadius: GameBoardVisualMetrics.shellCornerRadius(theme: palette),
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: GameBoardVisualMetrics.shellCornerRadius(theme: palette),
                style: .continuous
            )
            .stroke(Color(hex: palette.foreground).opacity(0.26), lineWidth: palette.isPixel ? 3 : 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("multiplayer-board")
    }

    private var speedBar: some View {
        GameplaySpeedBarView(
            theme: palette,
            multiplier: state.localPlayer?.multiplier ?? 1,
            progress: state.streakSteps,
            target: 5,
            accessibilityIdentifier: "multiplayer-speed-bar"
        )
    }

    private func playerStrip(badgeWidth: CGFloat) -> some View {
        HStack(spacing: MultiplayerLiveLayoutMetrics.badgeSpacing) {
            ForEach(state.players.sorted(by: { $0.seat < $1.seat })) { player in
                playerTile(player, playerCount: state.players.count)
                    .frame(width: badgeWidth)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("multiplayer-player-strip")
    }

    private func playerTile(
        _ player: MultiplayerPresentation.LivePlayer,
        playerCount: Int
    ) -> some View {
        let dense = playerCount >= 4
        let petSide: CGFloat = dense ? 24 : 29
        let tone = palette.color(at: player.colorIndex)
        let shape = RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 9)

        return HStack(spacing: dense ? 2 : 4) {
            Group {
                if let petID = player.petID {
                    PetCompanionView(
                        petID: petID,
                        size: petSide,
                        placement: .gameplay
                    )
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: dense ? 21 : 25))
                        .foregroundStyle(Color(hex: palette.muted))
                }
            }
            .frame(width: petSide + 2)
            .frame(maxHeight: .infinity, alignment: .center)

            VStack(spacing: 0) {
                Text(player.points.formatted())
                    .font(
                        palette.appFont(
                            size: dense ? 10 : 13,
                            weight: .black,
                            relativeTo: .headline
                        )
                    )
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.60)
                Text(player.name)
                    .font(
                        palette.appFont(
                            size: dense ? 7 : 8,
                            weight: .bold,
                            relativeTo: .caption2
                        )
                    )
                    .foregroundStyle(Color(hex: palette.muted))
                    .lineLimit(1)
                    .minimumScaleFactor(0.52)
                    .allowsTightening(true)
            }
            .frame(maxWidth: .infinity)

            Text("\(player.multiplier)×")
                .font(
                    palette.appFont(
                        size: dense ? 15 : 21,
                        weight: .black,
                        relativeTo: .title3
                    )
                )
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .allowsTightening(true)
                .frame(width: dense ? 28 : 31)
        }
        .padding(.horizontal, dense ? 3 : 6)
        .frame(height: MultiplayerLiveLayoutMetrics.badgeHeight)
        .frame(maxWidth: .infinity)
        .background(
            player.isCurrentPlayer
                ? tone.opacity(0.16)
                : Color(hex: palette.surface).opacity(0.80),
            in: shape
        )
        .overlay {
            shape
                .stroke(
                    tone.opacity(player.isCurrentPlayer ? 1 : 0.84),
                    lineWidth: palette.isPixel ? 3 : 2.5
                )
                .shadow(
                    color: tone.opacity(palette.isLight ? 0.38 : 0.62),
                    radius: palette.isPixel ? 2 : 6
                )
                .shadow(
                    color: tone.opacity(palette.isLight ? 0.20 : 0.34),
                    radius: palette.isPixel ? 0 : 10
                )
        }
        .overlay(alignment: .topTrailing) {
            if player.isLeader {
                Image(systemName: "crown.fill")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color(hex: "#ffd84d"))
                    .offset(x: 3, y: -5)
                    .shadow(color: Color(hex: "#ffd84d"), radius: palette.isPixel ? 0 : 4)
                    .accessibilityHidden(true)
            }
        }
        .opacity(player.isConnected ? 1 : 0.52)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(player.name), \(player.points) points, multiplier \(player.multiplier), \(player.lives) lives"
        )
        .accessibilityIdentifier("multiplayer-player-\(player.seat)")
    }

    private func cellAccessibilityLabel(_ cell: MultiplayerPresentation.Cell) -> String {
        if cell.isTarget {
            return cell.ownerSeat == state.localSeat
                ? "Your active target, cell \(cell.id + 1)"
                : "Active target, cell \(cell.id + 1)"
        }
        if cell.isDecoy { return "Decoy, cell \(cell.id + 1)" }
        return "Inactive cell \(cell.id + 1)"
    }

}

private struct MultiplayerTouchCell: UIViewRepresentable {
    let isEnabled: Bool
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let onTap: (Int) -> Void

    func makeUIView(context _: Context) -> MultiplayerTouchCellView {
        MultiplayerTouchCellView()
    }

    func updateUIView(_ view: MultiplayerTouchCellView, context _: Context) {
        view.isUserInteractionEnabled = isEnabled
        view.isAccessibilityElement = true
        view.accessibilityTraits = isEnabled ? .button : [.button, .notEnabled]
        view.accessibilityLabel = accessibilityLabel
        view.accessibilityIdentifier = accessibilityIdentifier
        view.onTap = onTap
    }
}

private final class MultiplayerTouchCellView: UIView {
    var onTap: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer { super.touchesBegan(touches, with: event) }
        guard let timestamp = touches.first?.timestamp else { return }
        onTap?(Int((timestamp * 1_000).rounded()))
    }

    override func accessibilityActivate() -> Bool {
        guard isUserInteractionEnabled else { return false }
        onTap?(Int((ProcessInfo.processInfo.systemUptime * 1_000).rounded()))
        return true
    }
}

private struct MultiplayerBoardGapTouchLayer: UIViewRepresentable {
    let isEnabled: Bool
    let onTap: (Int, Int) -> Void

    func makeUIView(context _: Context) -> MultiplayerBoardGapTouchView {
        MultiplayerBoardGapTouchView()
    }

    func updateUIView(_ view: MultiplayerBoardGapTouchView, context _: Context) {
        view.isUserInteractionEnabled = isEnabled
        view.onTap = onTap
    }
}

private final class MultiplayerBoardGapTouchView: UIView {
    var onTap: ((Int, Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = false
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer { super.touchesBegan(touches, with: event) }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let inset: CGFloat = 12
        let spacing: CGFloat = 5
        let availableWidth = max(0, bounds.width - inset * 2 - spacing * 3)
        let availableHeight = max(0, bounds.height - inset * 2 - spacing * 3)
        let cellWidth = availableWidth / 4
        let cellHeight = availableHeight / 4
        let centersX = (0..<4).map {
            inset + cellWidth / 2 + CGFloat($0) * (cellWidth + spacing)
        }
        let centersY = (0..<4).map {
            inset + cellHeight / 2 + CGFloat($0) * (cellHeight + spacing)
        }
        guard
            let column = centersX.indices.min(by: {
                abs(centersX[$0] - location.x) < abs(centersX[$1] - location.x)
            }),
            let row = centersY.indices.min(by: {
                abs(centersY[$0] - location.y) < abs(centersY[$1] - location.y)
            })
        else { return }
        onTap?(row * 4 + column, Int((touch.timestamp * 1_000).rounded()))
    }
}

struct MultiplayerResultsView: View {
    @EnvironmentObject private var cosmetics: CosmeticsController

    let state: MultiplayerPresentation.ResultsState
    let onRefresh: () -> Void
    let onDone: () -> Void

    private var palette: ThemePalette { cosmetics.theme }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: palette)

            VStack(spacing: 12) {
                settlementHeader
                resultRows
                if let message = state.message {
                    Text(message)
                        .font(palette.appFont(size: 11, weight: .bold, relativeTo: .caption))
                        .foregroundStyle(Color(hex: palette.muted))
                        .multilineTextAlignment(.center)
                }
                actionRow
            }
            .foregroundStyle(Color(hex: palette.foreground))
            .padding(14)
            .frame(maxWidth: 620, maxHeight: .infinity)
            .webCardStyle(theme: palette, padding: 14)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .navigationBarBackButtonHidden(true)
        .accessibilityIdentifier("multiplayer-results")
    }

    private var settlementHeader: some View {
        VStack(spacing: 5) {
            Image(systemName: settlementIcon)
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(settlementColor)
                .shadow(color: settlementColor.opacity(0.45), radius: palette.isPixel ? 0 : 9)
            Text(state.settlement.title)
                .font(palette.appFont(size: 25, weight: .black, relativeTo: .title))
            Text(settlementSubtitle)
                .font(palette.appFont(size: 11, weight: .bold, relativeTo: .caption))
                .foregroundStyle(Color(hex: palette.muted))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private var settlementIcon: String {
        switch state.settlement {
        case .collecting:
            "arrow.trianglehead.2.clockwise.rotate.90"
        case .settled(let eligible):
            eligible ? "checkmark.seal.fill" : "flag.checkered"
        case .review:
            "shield.lefthalf.filled.badge.checkmark"
        }
    }

    private var settlementColor: Color {
        switch state.settlement {
        case .collecting:
            Color(hex: palette.chromeAccent)
        case .settled(let eligible):
            Color(hex: eligible ? "#72e995" : palette.achievementsAccent)
        case .review:
            Color(hex: palette.achievementsAccent)
        }
    }

    private var settlementSubtitle: String {
        switch state.settlement {
        case .collecting(let submitted, let total):
            "\(submitted) of \(total) matching transcripts received"
        case .settled(let eligible):
            eligible
                ? "Protocol-verified, peer-consistent result"
                : "Complete, but not leaderboard eligible"
        case .review(let reason):
            reason ?? "This result is not ranked while review is pending."
        }
    }

    private var resultRows: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(state.results.sorted(by: { $0.place < $1.place })) { result in
                    resultRow(result)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: .infinity)
        .accessibilityIdentifier("multiplayer-result-rows")
    }

    private func resultRow(_ result: MultiplayerPresentation.Result) -> some View {
        HStack(spacing: 9) {
            ZStack {
                Text("#\(result.place)")
                    .font(palette.appFont(size: 18, weight: .black, relativeTo: .headline))
                    .foregroundStyle(
                        result.place == 1
                            ? Color(hex: "#ffd84d")
                            : Color(hex: palette.foreground)
                    )
                if result.place == 1 {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Color(hex: "#ffd84d"))
                        .offset(y: -23)
                }
            }
            .frame(width: 38)

            if let petID = result.petID {
                PetCompanionView(petID: petID, size: 34, placement: .leaderboard)
                    .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(result.name)
                        .font(palette.appFont(size: 14, weight: .black, relativeTo: .headline))
                        .lineLimit(1)
                    if result.isCurrentPlayer {
                        Text("YOU")
                            .font(palette.appFont(size: 7, weight: .black, relativeTo: .caption2))
                            .foregroundStyle(Color(hex: palette.chromeAccent))
                    }
                }
                Text(
                    "\(result.hits) hits · \(result.dodges) dodges · \(result.misses) misses"
                )
                .font(palette.appFont(size: 9, weight: .bold, relativeTo: .caption2))
                .foregroundStyle(Color(hex: palette.muted))
                .lineLimit(1)
                Text(reactionCopy(result))
                    .font(palette.appFont(size: 8, weight: .medium, relativeTo: .caption2))
                    .foregroundStyle(Color(hex: palette.muted).opacity(0.84))
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 1) {
                Text("SCORE")
                    .font(palette.appFont(size: 8, weight: .black, relativeTo: .caption2))
                    .foregroundStyle(Color(hex: palette.muted))
                Text(result.score.formatted())
                    .font(palette.appFont(size: 17, weight: .black, relativeTo: .headline))
                    .foregroundStyle(Color(hex: palette.accent))
                    .monospacedDigit()
                Text("\(result.maxMultiplier)× max")
                    .font(palette.appFont(size: 8, weight: .bold, relativeTo: .caption2))
                    .foregroundStyle(Color(hex: palette.muted))
            }
        }
        .webCardStyle(
            theme: palette,
            selectedAccent: result.isCurrentPlayer
                ? Color(hex: palette.chromeAccent).opacity(0.68)
                : nil,
            padding: 10
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("multiplayer-result-\(result.place)")
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            if case .collecting = state.settlement {
                Button("Check status", action: onRefresh)
                    .buttonStyle(
                        WebSecondaryButtonStyle(
                            theme: palette,
                            accent: Color(hex: palette.chromeAccent)
                        )
                    )
                    .disabled(state.isRefreshing)
                    .accessibilityIdentifier("refresh-multiplayer-settlement")
            } else {
                NavigationLink {
                    LeaderboardView(initialMode: .multiplayer)
                } label: {
                    Text("Leaderboard")
                }
                .buttonStyle(
                    WebSecondaryButtonStyle(
                        theme: palette,
                        accent: Color(hex: palette.chromeAccent)
                    )
                )
                .accessibilityIdentifier("results-multiplayer-leaderboard")
            }

            if state.canReturnToMenu {
                Button("Menu", action: onDone)
                    .buttonStyle(
                        WebSecondaryButtonStyle(
                            theme: palette,
                            accent: Color(hex: palette.petsAccent)
                        )
                    )
                    .accessibilityIdentifier("finish-multiplayer")
            }
        }
    }

    private func reactionCopy(_ result: MultiplayerPresentation.Result) -> String {
        let fastest =
            result.fastestReactionMilliseconds.map { "\($0)ms fastest" }
            ?? "No fastest tap"
        let average =
            result.averageReactionMilliseconds.map { "\($0)ms average" }
            ?? "No average"
        return "\(fastest) · \(average)"
    }
}
