import SwiftUI

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
    let onOpenLeaderboard: () -> Void

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
            VStack(alignment: .leading, spacing: 2) {
                Text("AVAILABLE GAMES")
                    .font(palette.appFont(size: 10, weight: .black, relativeTo: .caption2))
                    .tracking(1.0)
                    .foregroundStyle(Color(hex: palette.muted))
                Text("Own your color")
                    .font(palette.appFont(size: 25, weight: .black, relativeTo: .title))
            }
            Spacer()
            Button(action: onOpenLeaderboard) {
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

struct MultiplayerWaitingRoomView: View {
    @EnvironmentObject private var cosmetics: CosmeticsController

    let state: MultiplayerPresentation.WaitingRoomState
    let onToggleReady: (Bool) -> Void
    let onStart: () -> Void
    let onLeave: () -> Void
    let onPetDrag: (CGSize) -> Void

    @State private var settledPetOffset = CGSize.zero
    @GestureState private var activePetDrag = CGSize.zero

    private var palette: ThemePalette { cosmetics.theme }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: palette)

            VStack(spacing: 12) {
                header
                connectionCard
                participantGrid
                Spacer(minLength: 4)
                localPetStage
                actionRow
            }
            .foregroundStyle(Color(hex: palette.foreground))
            .padding(14)
            .frame(maxWidth: 620, maxHeight: .infinity)
            .webCardStyle(theme: palette, padding: 14)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .navigationTitle("Waiting Room")
        .navigationBarBackButtonHidden(true)
        .accessibilityIdentifier("multiplayer-waiting-room")
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("WAITING ROOM")
                    .font(palette.appFont(size: 10, weight: .black, relativeTo: .caption2))
                    .tracking(1)
                    .foregroundStyle(Color(hex: palette.muted))
                Text("\(state.participants.count)/\(state.capacity) players")
                    .font(palette.appFont(size: 24, weight: .black, relativeTo: .title2))
            }
            Spacer()
            Button("Leave", action: onLeave)
                .font(palette.appFont(size: 12, weight: .bold, relativeTo: .caption))
                .buttonStyle(
                    WebSecondaryButtonStyle(
                        theme: palette,
                        accent: Color(hex: palette.petsAccent),
                        minimumHeight: 40
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
            Text(state.connection.title)
                .font(palette.appFont(size: 12, weight: .bold, relativeTo: .caption))
                .foregroundStyle(Color(hex: palette.muted))
            Spacer()
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
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }

    private var connectionColor: Color {
        switch state.connection {
        case .ready:
            Color(hex: "#72e995")
        case .failed:
            Color(hex: palette.petsAccent)
        default:
            Color(hex: palette.chromeAccent)
        }
    }

    private var participantGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 8
        ) {
            ForEach(state.participants.sorted(by: { $0.seat < $1.seat })) { player in
                waitingParticipant(player)
            }
            ForEach(state.participants.count..<state.capacity, id: \.self) { seat in
                emptySeat(seat)
            }
        }
        .accessibilityIdentifier("multiplayer-waiting-participants")
    }

    private func waitingParticipant(
        _ player: MultiplayerPresentation.Participant
    ) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(palette.color(at: player.colorIndex))
                .frame(width: 15, height: 15)
                .overlay { Circle().stroke(.white.opacity(0.86), lineWidth: 2) }
                .shadow(color: palette.color(at: player.colorIndex), radius: palette.isPixel ? 0 : 5)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(player.name)
                        .font(palette.appFont(size: 13, weight: .black, relativeTo: .headline))
                        .lineLimit(1)
                    if player.isCreator {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Color(hex: "#ffd84d"))
                    }
                }
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
        .webCardStyle(
            theme: palette,
            selectedAccent: palette.color(at: player.colorIndex).opacity(0.68),
            padding: 9
        )
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
        .webCardStyle(theme: palette, padding: 9)
        .accessibilityIdentifier("multiplayer-empty-seat-\(seat)")
    }

    @ViewBuilder
    private var localPetStage: some View {
        if let current = state.currentPlayer, let petID = current.petID {
            VStack(spacing: 2) {
                Text("DRAG YOUR PET WHILE YOU WAIT")
                    .font(palette.appFont(size: 8, weight: .black, relativeTo: .caption2))
                    .tracking(0.75)
                    .foregroundStyle(Color(hex: palette.muted))
                PetCompanionView(
                    petID: petID,
                    size: 58,
                    placement: .shop,
                    animationTrigger: 1
                )
                .offset(
                    x: settledPetOffset.width + activePetDrag.width,
                    y: settledPetOffset.height + activePetDrag.height
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($activePetDrag) { value, drag, _ in
                            drag = value.translation
                        }
                        .onEnded { value in
                            let proposed = CGSize(
                                width: settledPetOffset.width + value.translation.width,
                                height: settledPetOffset.height + value.translation.height
                            )
                            settledPetOffset = CGSize(
                                width: min(118, max(-118, proposed.width)),
                                height: min(16, max(-16, proposed.height))
                            )
                            onPetDrag(settledPetOffset)
                        }
                )
                .accessibilityLabel("Your draggable pet")
                .accessibilityIdentifier("multiplayer-draggable-pet")
            }
            .frame(maxWidth: .infinity, minHeight: 92)
        }
    }

    private var actionRow: some View {
        VStack(spacing: 8) {
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
                            : Color(hex: "#72e995")
                    )
                )
                .disabled(state.isMutationPending || state.connection != .ready)
                .accessibilityIdentifier("multiplayer-ready")
            }

            if state.isCreator {
                Button(action: onStart) {
                    Label("Start match", systemImage: "flag.checkered")
                }
                .buttonStyle(
                    WebSecondaryButtonStyle(
                        theme: palette,
                        accent: Color(hex: palette.achievementsAccent)
                    )
                )
                .disabled(!state.canStart)
                .accessibilityIdentifier("start-multiplayer-match")
            } else {
                Text("The host starts when every player is ready.")
                    .font(palette.appFont(size: 11, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(Color(hex: palette.muted))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }
}

struct MultiplayerLiveView: View {
    @EnvironmentObject private var cosmetics: CosmeticsController

    let state: MultiplayerPresentation.LiveMatchState
    let onTapCell: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 4)
    private var palette: ThemePalette { cosmetics.theme }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: palette)

            GeometryReader { proxy in
                let horizontalInset: CGFloat = 14
                let boardSide = min(
                    proxy.size.width - horizontalInset * 2,
                    proxy.size.height * 0.57
                )
                VStack(spacing: 10) {
                    liveHeader
                    board
                        .frame(width: boardSide, height: boardSide)
                    speedBar
                    playerStrip(width: proxy.size.width - horizontalInset * 2)
                }
                .padding(.horizontal, horizontalInset)
                .padding(.vertical, 8)
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
        .accessibilityIdentifier("multiplayer-live-match")
    }

    private var liveHeader: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("MULTIPLAYER")
                    .font(palette.appFont(size: 8, weight: .black, relativeTo: .caption2))
                    .tracking(0.9)
                    .foregroundStyle(Color(hex: palette.muted))
                Text(formatDuration(state.elapsedMilliseconds))
                    .font(palette.appFont(size: 21, weight: .black, relativeTo: .title3))
                    .monospacedDigit()
            }
            Spacer()
            if let local = state.localPlayer {
                HStack(spacing: 8) {
                    Circle()
                        .fill(palette.color(at: local.colorIndex))
                        .frame(width: 18, height: 18)
                        .overlay { Circle().stroke(.white.opacity(0.90), lineWidth: 2) }
                        .shadow(
                            color: palette.color(at: local.colorIndex),
                            radius: palette.isPixel ? 0 : 6
                        )
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("YOUR COLOR")
                            .font(
                                palette.appFont(
                                    size: 8,
                                    weight: .black,
                                    relativeTo: .caption2
                                )
                            )
                            .tracking(0.8)
                            .foregroundStyle(Color(hex: palette.muted))
                        Text(String(repeating: "♥", count: max(0, local.lives)))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: "#ff5370"))
                    }
                }
            }
        }
        .padding(10)
        .webCardStyle(theme: palette, padding: 0)
        .accessibilityIdentifier("multiplayer-live-header")
    }

    private var board: some View {
        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(state.orderedCells) { cell in
                Button {
                    onTapCell(cell.id)
                } label: {
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
                }
                .buttonStyle(.plain)
                .disabled(state.isRecovering)
                .accessibilityLabel(cellAccessibilityLabel(cell))
                .accessibilityIdentifier("multiplayer-cell-\(cell.id)")
            }
        }
        .padding(12)
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
        .accessibilityIdentifier("multiplayer-board")
    }

    private var speedBar: some View {
        HStack(spacing: palette.isPixel ? 2 : 4) {
            Text("SPEED BAR")
                .font(palette.appFont(size: 10, weight: .black, relativeTo: .caption))
                .frame(width: 76)
            ForEach(0..<5, id: \.self) { step in
                RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 5)
                    .fill(
                        step < min(5, max(0, state.streakSteps))
                            ? LinearGradient(
                                colors: [
                                    Color(hex: "#914eff"),
                                    Color(hex: "#ff83d4"),
                                    Color(hex: "#ffe16a"),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color(hex: palette.surface),
                                    Color(hex: palette.surface),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 5)
                            .stroke(Color(hex: palette.foreground).opacity(0.16), lineWidth: 1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            Text("\(state.localPlayer?.multiplier ?? 1)×")
                .font(palette.appFont(size: 18, weight: .black, relativeTo: .headline))
                .frame(width: 45)
        }
        .padding(8)
        .webCardStyle(theme: palette, padding: 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Speed bar \(state.streakSteps) of 5, multiplier \(state.localPlayer?.multiplier ?? 1)"
        )
        .accessibilityIdentifier("multiplayer-speed-bar")
    }

    private func playerStrip(width: CGFloat) -> some View {
        HStack(spacing: 4) {
            ForEach(state.players.sorted(by: { $0.seat < $1.seat })) { player in
                playerTile(player)
                    .frame(
                        width: max(
                            0,
                            (width - CGFloat(max(0, state.players.count - 1)) * 4)
                                * CGFloat(state.stripFraction)
                        )
                    )
            }
        }
        .frame(width: width, alignment: .leading)
        .accessibilityIdentifier("multiplayer-player-strip")
    }

    private func playerTile(_ player: MultiplayerPresentation.LivePlayer) -> some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                if let petID = player.petID {
                    PetCompanionView(
                        petID: petID,
                        size: state.players.count == 4 ? 25 : 31,
                        placement: .gameplay
                    )
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: state.players.count == 4 ? 23 : 28))
                        .foregroundStyle(Color(hex: palette.muted))
                }
                if player.isLeader {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Color(hex: "#ffd84d"))
                        .offset(x: 6, y: -5)
                        .shadow(color: Color(hex: "#ffd84d"), radius: palette.isPixel ? 0 : 4)
                }
            }
            .frame(height: 30)

            Text(player.name)
                .font(
                    palette.appFont(
                        size: state.players.count == 4 ? 8 : 10,
                        weight: .black,
                        relativeTo: .caption2
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(player.points.formatted()) · \(player.multiplier)×")
                .font(
                    palette.appFont(
                        size: state.players.count == 4 ? 8 : 9,
                        weight: .bold,
                        relativeTo: .caption2
                    )
                )
                .foregroundStyle(palette.color(at: player.colorIndex))
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 70)
        .background(
            player.isCurrentPlayer
                ? palette.color(at: player.colorIndex).opacity(0.14)
                : Color(hex: palette.surface).opacity(0.80),
            in: RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 10)
        )
        .overlay {
            RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 10)
                .stroke(
                    palette.color(at: player.colorIndex).opacity(
                        player.isCurrentPlayer ? 0.86 : 0.40
                    ),
                    lineWidth: palette.isPixel ? 2 : 1
                )
        }
        .opacity(player.isConnected ? 1 : 0.52)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(player.name), \(player.points) points, multiplier \(player.multiplier), \(player.lives) lives"
        )
        .accessibilityIdentifier("multiplayer-player-\(player.seat)")
    }

    private func cellAccessibilityLabel(_ cell: MultiplayerPresentation.Cell) -> String {
        if cell.isTarget { return "Your active target, cell \(cell.id + 1)" }
        if cell.isDecoy { return "Decoy, cell \(cell.id + 1)" }
        return "Inactive cell \(cell.id + 1)"
    }

    private func formatDuration(_ milliseconds: Int) -> String {
        let seconds = max(0, milliseconds / 1_000)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct MultiplayerResultsView: View {
    @EnvironmentObject private var cosmetics: CosmeticsController

    let state: MultiplayerPresentation.ResultsState
    let onRefresh: () -> Void
    let onOpenLeaderboard: () -> Void
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
                Button("Leaderboard", action: onOpenLeaderboard)
                    .buttonStyle(
                        WebSecondaryButtonStyle(
                            theme: palette,
                            accent: Color(hex: palette.chromeAccent)
                        )
                    )
                    .accessibilityIdentifier("results-multiplayer-leaderboard")
            }

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

struct MultiplayerLeaderboardView: View {
    @EnvironmentObject private var cosmetics: CosmeticsController

    let state: MultiplayerPresentation.LeaderboardState
    let onRefresh: () -> Void

    private var palette: ThemePalette { cosmetics.theme }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: palette)

            VStack(spacing: 10) {
                header
                positionStrip
                leaderboardContent
            }
            .foregroundStyle(Color(hex: palette.foreground))
            .padding(14)
            .frame(maxWidth: 620, maxHeight: .infinity)
            .webCardStyle(theme: palette, padding: 14)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .navigationTitle("Multiplayer Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("multiplayer-leaderboard")
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("MULTIPLAYER")
                    .font(palette.appFont(size: 10, weight: .black, relativeTo: .caption2))
                    .tracking(1.0)
                    .foregroundStyle(Color(hex: palette.muted))
                Text("Leaderboard")
                    .font(palette.appFont(size: 25, weight: .black, relativeTo: .title))
            }
            Spacer()
            Image(systemName: "person.3.fill")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(Color(hex: palette.chromeAccent))
        }
    }

    private var positionStrip: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(state.playerRank == nil ? "RANKED RESULTS" : "YOUR BEST POSITION")
                    .font(palette.appFont(size: 8, weight: .black, relativeTo: .caption2))
                    .tracking(0.75)
                    .foregroundStyle(Color(hex: palette.muted))
                Text(state.playerRank.map { "#\($0)" } ?? "\(state.totalEntries)")
                    .font(palette.appFont(size: 20, weight: .black, relativeTo: .title3))
                    .foregroundStyle(Color(hex: palette.chromeAccent))
                    .monospacedDigit()
            }
            Spacer()
            if let topPercent = state.topPercent {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("TOP RESULTS")
                        .font(palette.appFont(size: 8, weight: .black, relativeTo: .caption2))
                        .foregroundStyle(Color(hex: palette.muted))
                    Text("\(topPercent)%")
                        .font(palette.appFont(size: 20, weight: .black, relativeTo: .title3))
                        .foregroundStyle(Color(hex: palette.chromeAccent))
                        .monospacedDigit()
                }
            } else {
                Text("\(state.totalEntries) total")
                    .font(palette.appFont(size: 11, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(Color(hex: palette.muted))
            }
        }
        .webCardStyle(
            theme: palette,
            selectedAccent: Color(hex: palette.chromeAccent),
            padding: 10
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("multiplayer-leaderboard-position")
    }

    @ViewBuilder
    private var leaderboardContent: some View {
        if !state.entries.isEmpty {
            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(state.entries) { entry in
                        leaderboardRow(entry)
                    }
                }
                .padding(.vertical, 2)
            }
            .refreshable { onRefresh() }
            .accessibilityIdentifier("multiplayer-leaderboard-results")
        } else if !state.isLoading {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: state.message == nil ? "flag.checkered" : "wifi.exclamationmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color(hex: palette.chromeAccent))
                Text(state.message ?? "No multiplayer results yet")
                    .font(palette.appFont(size: 15, weight: .bold, relativeTo: .body))
                    .foregroundStyle(Color(hex: palette.muted))
                    .multilineTextAlignment(.center)
                Button("Try again", action: onRefresh)
                    .buttonStyle(
                        WebSecondaryButtonStyle(
                            theme: palette,
                            accent: Color(hex: palette.chromeAccent),
                            minimumHeight: 42
                        )
                    )
                    .frame(maxWidth: 180)
                Spacer()
            }
        } else {
            WebLoadingOverlay(theme: palette, label: "Loading multiplayer ranks")
        }
    }

    private func leaderboardRow(
        _ entry: MultiplayerPresentation.LeaderboardEntry
    ) -> some View {
        HStack(spacing: 8) {
            VStack(spacing: 1) {
                Text("#\(entry.rank)")
                    .font(palette.appFont(size: 13, weight: .black, relativeTo: .headline))
                    .foregroundStyle(
                        entry.rank <= 3
                            ? Color(hex: "#ffd84d")
                            : Color(hex: palette.muted)
                    )
                if let petID = entry.petID {
                    PetCompanionView(petID: petID, size: 34, placement: .leaderboard)
                        .frame(width: 42, height: 38)
                }
            }
            .frame(width: 42)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(entry.name)
                        .font(palette.appFont(size: 14, weight: .black, relativeTo: .headline))
                        .lineLimit(1)
                    if entry.place == 1 {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(Color(hex: "#ffd84d"))
                    }
                    if entry.isCurrentPlayer {
                        Text("YOU")
                            .font(palette.appFont(size: 7, weight: .black, relativeTo: .caption2))
                            .foregroundStyle(Color(hex: palette.chromeAccent))
                    }
                }
                Text(
                    "Place \(entry.place)/\(entry.playerCount) · \(entry.hits) hits · \(formatDuration(entry.survivalMilliseconds))"
                )
                .font(palette.appFont(size: 9, weight: .bold, relativeTo: .caption2))
                .foregroundStyle(Color(hex: palette.muted))
                .lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 1) {
                Text("SCORE")
                    .font(palette.appFont(size: 8, weight: .black, relativeTo: .caption2))
                    .foregroundStyle(Color(hex: palette.muted))
                Text(entry.score.formatted())
                    .font(palette.appFont(size: 16, weight: .black, relativeTo: .headline))
                    .foregroundStyle(Color(hex: palette.chromeAccent))
                    .monospacedDigit()
            }
        }
        .webCardStyle(
            theme: palette,
            selectedAccent: entry.isCurrentPlayer
                ? Color(hex: palette.chromeAccent).opacity(0.68)
                : nil,
            padding: 10
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("multiplayer-leaderboard-entry-\(entry.id)")
    }

    private func formatDuration(_ milliseconds: Int) -> String {
        let seconds = max(0, milliseconds / 1_000)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
