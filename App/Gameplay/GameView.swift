import PimPoPomCore
import SpriteKit
import SwiftUI

struct GameView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var backend: BackendClient
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var cosmetics: CosmeticsController
    @EnvironmentObject private var audio: AudioController
    @StateObject private var coordinator: GameCoordinator
    @State private var runTicket: RunTicket?
    @State private var preparing = true
    @State private var runStatus = ""
    @State private var submissionStarted = false
    @State private var submissionFailed = false
    @State private var preparationGeneration = 0
    @State private var frozenTheme = ThemePalette.classic
    @State private var frozenPetID: String?
    @State private var frozenGlyphsEnabled = true
    @State private var gameplayPetFacing = PetFacing.front
    @State private var boardSceneFrame = CGRect.zero
    @State private var gameplayPetFrame = CGRect.zero
    @State private var didFreezePresentation = false

    private var palette: ThemePalette { frozenTheme }

    init(mode: GameMode) {
        _coordinator = StateObject(wrappedValue: GameCoordinator(mode: mode))
    }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: palette)

            GeometryReader { proxy in
                let boardWidth = min(proxy.size.width - 24, 680)
                let reservedHeight: CGFloat = frozenPetID == nil ? 218 : 246
                let boardSide = min(boardWidth, max(220, proxy.size.height - reservedHeight))

                VStack(spacing: 8) {
                    gameUtilityHeader
                    gameplayHUD
                    gameBoard(side: boardSide)
                    Spacer(minLength: 0)
                    streakAndPet(width: boardSide, screenWidth: proxy.size.width)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }

            if coordinator.isFinished || coordinator.wasAbandoned {
                resultOverlay
            }

            if preparing {
                Color.black.opacity(0.72).ignoresSafeArea()
                ProgressView("Preparing \(coordinator.mode.displayName)…")
                    .tint(Color(hex: palette.accent))
                    .foregroundStyle(Color(hex: palette.foreground))
                    .padding(22)
                    .background(
                        Color(hex: palette.surface),
                        in: RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 18)
                    )
            }
        }
        .coordinateSpace(name: "game-space")
        .onPreferenceChange(BoardSceneFramePreferenceKey.self) { frame in
            guard frame != boardSceneFrame else { return }
            Task { @MainActor in boardSceneFrame = frame }
        }
        .onPreferenceChange(GameplayPetFramePreferenceKey.self) { frame in
            guard frame != gameplayPetFrame else { return }
            Task { @MainActor in gameplayPetFrame = frame }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !coordinator.isFinished, !coordinator.wasAbandoned {
                adPlaceholder
                    .opacity(preparing ? 0 : 1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(hex: palette.backgroundBottom).opacity(0.96))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(submissionStarted)
        .task {
            coordinator.onSoundEvent = { event in
                switch event {
                case .correctTap(let hitNumber):
                    audio.playTap(hitNumber: hitNumber)
                case .lifeLoss:
                    audio.playLifeLoss()
                }
            }
            coordinator.onLifecycleEvent = { event in
                audio.setMusicContext(GameplayMusicRouting.context(for: event))
                if event == .finished {
                    if coordinator.mode == .arcade {
                        preferences.menuMotivationUnlocked = true
                    }
                    submitRankedRunIfNeeded()
                }
            }
            coordinator.onAcceptedBoardTap = { location in
                handleGameplayTap(at: location)
            }
            await cosmetics.refresh()
            guard !Task.isCancelled else { return }
            freezePresentationIfNeeded()
            audio.setMusicContext(.gameplay)
            await prepareAndStart()
        }
        .onDisappear {
            preparationGeneration += 1
            coordinator.stop()
            coordinator.onSoundEvent = nil
            coordinator.onLifecycleEvent = nil
            coordinator.onAcceptedBoardTap = nil
            abandonTicketIfNeeded()
            audio.setMusicContext(.menu)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                preparationGeneration += 1
                abandonTicketIfNeeded()
                coordinator.abandonForBackground()
            } else if preparing {
                Task { await prepareAndStart() }
            } else if !coordinator.isFinished, !coordinator.wasAbandoned {
                audio.setMusicContext(.gameplay)
            }
        }
    }

    private var gameUtilityHeader: some View {
        HStack(spacing: 8) {
            PimPoPomWordmark(theme: palette, size: 18)
                .frame(maxWidth: .infinity, alignment: .leading)

            if coordinator.mode == .arcade {
                gameHeaderButton("Restart", systemImage: "arrow.clockwise", width: 82) {
                    Task { await prepareAndStart() }
                }
                .accessibilityIdentifier("game-restart")

                gameHeaderButton("Menu", systemImage: "house.fill", width: 74) {
                    dismiss()
                }
                .accessibilityIdentifier("game-menu")
            } else {
                gameHeaderButton("End run", systemImage: "flag.checkered", width: 100) {
                    coordinator.endZenRun()
                }
                .accessibilityIdentifier("end-zen-run")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
    }

    private func gameHeaderButton(
        _ title: String,
        systemImage: String,
        width: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(palette.appFont(size: 12, weight: .bold, relativeTo: .caption))
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(
            WebSecondaryButtonStyle(
                theme: palette,
                minimumHeight: 44
            )
        )
        .frame(width: width)
    }

    private var gameplayHUD: some View {
        GeometryReader { proxy in
            let gap: CGFloat = 7
            let usableWidth = max(0, proxy.size.width - 24 - gap * 2)
            let sideWidth = max(64, usableWidth * 0.78 / 3.21)
            let centerWidth = max(140, usableWidth - sideWidth * 2)

            HStack(spacing: gap) {
                VStack(spacing: 5) {
                    compactStat(
                        "Points",
                        "\(coordinator.snapshot.points)",
                        identifier: "game-score"
                    )
                    compactStat("Top score", "—", identifier: "game-top-score")
                }
                .frame(width: sideWidth)

                colorHero
                    .frame(width: centerWidth)

                VStack(spacing: 5) {
                    compactStat(
                        coordinator.mode == .arcade ? "Survived" : "Time",
                        formatDuration(coordinator.snapshot.elapsedMilliseconds),
                        identifier: "game-time"
                    )
                    compactStat("Lives", livesPresentation, identifier: "game-lives")
                }
                .frame(width: sideWidth)
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 90)
    }

    private var colorHero: some View {
        let remainingFraction = ResponseProgressPresentation.remainingFraction(
            coordinator.snapshot.reactionProgress,
            isActive: coordinator.snapshot.state == .active && coordinator.mode == .arcade
        )
        let colorIndex = coordinator.snapshot.playerColorIndex
        let name = coordinator.mode == .zen ? "Any" : coordinator.snapshot.playerColor.name
        let glyph = coordinator.mode == .zen ? "☯" : coordinator.snapshot.playerColor.glyph

        return VStack(spacing: 5) {
            Text("YOUR COLOR")
                .font(palette.appFont(size: 9, weight: .black, relativeTo: .caption2))
                .tracking(0.7)
                .foregroundStyle(Color(hex: palette.muted))

            HStack(spacing: 8) {
                Circle()
                    .fill(
                        coordinator.mode == .zen
                            ? Color(hex: palette.foreground).opacity(0.12)
                            : palette.color(at: colorIndex)
                    )
                    .overlay {
                        if frozenGlyphsEnabled {
                            Text(glyph)
                                .font(palette.appFont(size: 19, weight: .black, relativeTo: .headline))
                                .foregroundStyle(
                                    coordinator.mode == .zen
                                        ? Color(hex: palette.foreground)
                                        : palette.promptInkColor(at: colorIndex)
                                )
                        }
                    }
                    .overlay { Circle().stroke(.white.opacity(0.80), lineWidth: 2) }
                    .frame(width: 40, height: 40)

                Text(name)
                    .font(palette.appFont(size: 18, weight: .black, relativeTo: .headline))
                    .foregroundStyle(Color(hex: palette.foreground))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 7)
        .padding(.bottom, 4)
        .background(
            Color(hex: palette.surface).opacity(palette.isLight ? 0.88 : 0.82),
            in: RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 11)
        )
        .overlay {
            RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 11)
                .stroke(
                    palette.isLight
                        ? Color(hex: "#477694").opacity(0.18)
                        : coordinator.mode == .zen
                            ? Color(hex: palette.foreground).opacity(0.18)
                            : palette.color(at: colorIndex).opacity(palette.isLight ? 0.74 : 0.55),
                    lineWidth: palette.isPixel ? 2 : 1
                )
        }
        .overlay(alignment: .bottomLeading) {
            if let remainingFraction {
                ResponseProgressBar(remainingFraction: remainingFraction)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 11))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(targetAccessibilityLabel(name: name, glyph: glyph))
        .accessibilityIdentifier("target-color")
    }

    private var livesPresentation: String {
        guard coordinator.mode == .arcade else { return "∞" }
        let remaining = max(0, min(3, coordinator.snapshot.lives))
        return String(repeating: "♥", count: remaining)
            + String(repeating: "♡", count: 3 - remaining)
    }

    private var displayedFeedback: String {
        guard !frozenGlyphsEnabled,
            coordinator.feedback.hasPrefix("Tap ")
        else { return coordinator.feedback }
        return "Tap \(coordinator.snapshot.playerColor.name)"
    }

    private func targetAccessibilityLabel(name: String, glyph: String) -> String {
        frozenGlyphsEnabled
            ? "Target color \(name), symbol \(glyph)"
            : "Target color \(name)"
    }

    private func compactStat(_ label: String, _ value: String, identifier: String) -> some View {
        VStack(spacing: 1) {
            Text(label.uppercased())
                .font(palette.appFont(size: 8, weight: .black, relativeTo: .caption2))
                .tracking(0.35)
                .foregroundStyle(Color(hex: palette.muted))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(value)
                .font(palette.appFont(size: 15, weight: .black, relativeTo: .headline))
                .monospacedDigit()
                .foregroundStyle(Color(hex: palette.foreground))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 3)
        .background(
            Color(hex: palette.surface).opacity(palette.isLight ? 0.88 : 0.78),
            in: RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 11)
        )
        .overlay {
            RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 11)
                .stroke(
                    palette.isLight
                        ? Color(hex: "#477694").opacity(0.18)
                        : Color(hex: palette.foreground).opacity(0.10),
                    lineWidth: palette.isPixel ? 2 : 1
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private func gameBoard(side: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            SpriteView(
                scene: coordinator.scene,
                options: [.allowsTransparency, .ignoresSiblingOrder]
            )
            .padding(8)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: BoardSceneFramePreferenceKey.self,
                        value: proxy.frame(in: .named("game-space"))
                    )
                }
            }

            Text(displayedFeedback)
                .font(palette.appFont(size: 12, weight: .bold, relativeTo: .caption))
                .foregroundStyle(Color(hex: palette.muted))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .accessibilityIdentifier("game-feedback")
        }
        .frame(width: side, height: side)
        .background(boardShell)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Reaction board")
        .accessibilityIdentifier("reaction-board")
    }

    private var boardShell: some View {
        let shape = RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 22, style: .continuous)
        return
            shape
            .fill(Color(hex: palette.board))
            .overlay {
                shape.stroke(
                    palette.isLight
                        ? Color.white
                        : Color(hex: palette.foreground).opacity(0.12),
                    lineWidth: palette.isPixel ? 2 : 1
                )
            }
            .shadow(
                color: palette.isLight
                    ? Color(hex: "#3d789e").opacity(0.20)
                    : .black.opacity(0.34),
                radius: palette.isPixel ? 0 : 14,
                y: palette.isPixel ? 0 : 7
            )
    }

    private func streakAndPet(width: CGFloat, screenWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            streakMeter
                .padding(.top, frozenPetID == nil ? 0 : 28)

            if let petID = frozenPetID {
                PetCompanionView(
                    petID: petID,
                    size: 54,
                    placement: .gameplay,
                    facing: gameplayPetFacing
                )
                .frame(width: 54, height: 54)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: GameplayPetFramePreferenceKey.self,
                            value: proxy.frame(in: .named("game-space"))
                        )
                    }
                }
                .offset(
                    x: screenWidth * 0.40 - (screenWidth - width) / 2 - 27
                )
                .allowsHitTesting(false)
                .accessibilityIdentifier("gameplay-pet-\(petID)")
            }
        }
        .frame(width: width, height: frozenPetID == nil ? 50 : 78, alignment: .bottom)
    }

    private var streakMeter: some View {
        HStack(spacing: 7) {
            GeometryReader { proxy in
                let progressWidth = proxy.size.width * streakProgressFraction
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(streakTierColor.opacity(coordinator.snapshot.multiplier == 1 ? 0.10 : 0.28))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#7657ff"),
                                    Color(hex: "#c658ff"),
                                    Color(hex: "#ffd84d"),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: progressWidth)
                        .clipShape(Capsule())
                    Text("SPEED STREAK")
                        .font(palette.appFont(size: 10, weight: .black, relativeTo: .caption2))
                        .tracking(0.65)
                        .foregroundStyle(Color(hex: palette.foreground))
                        .shadow(color: .black.opacity(palette.isLight ? 0.12 : 0.65), radius: 2)
                        .padding(.leading, 12)
                }
            }
            .frame(height: 36)

            Text("\(coordinator.snapshot.multiplier)×")
                .font(palette.appFont(size: 21, weight: .black, relativeTo: .title3))
                .foregroundStyle(coordinator.snapshot.multiplier == 1 ? Color(hex: palette.foreground) : .black)
                .frame(width: 46, height: 36)
                .background(streakTierColor, in: Capsule())
                .shadow(
                    color: streakTierColor.opacity(coordinator.snapshot.multiplier == 1 ? 0.10 : 0.55),
                    radius: palette.isPixel ? 0 : 8
                )
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(height: 50)
        .background(
            Color(hex: palette.surface).opacity(palette.isLight ? 0.88 : 0.82),
            in: RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 14)
        )
        .overlay {
            RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 14)
                .stroke(streakTierColor.opacity(0.42), lineWidth: palette.isPixel ? 2 : 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Speed streak")
        .accessibilityValue(
            "Multiplier \(coordinator.snapshot.multiplier), \(coordinator.snapshot.streakProgress) of \(coordinator.snapshot.streakTarget)"
        )
        .accessibilityIdentifier("speed-streak")
    }

    private var streakProgressFraction: CGFloat {
        guard coordinator.snapshot.streakTarget > 0 else { return 0 }
        if coordinator.snapshot.multiplier >= 5 { return 1 }
        return min(
            1,
            max(
                0,
                CGFloat(coordinator.snapshot.streakProgress)
                    / CGFloat(coordinator.snapshot.streakTarget)
            )
        )
    }

    private var streakTierColor: Color {
        switch coordinator.snapshot.multiplier {
        case 2: Color(hex: "#72e995")
        case 3: Color(hex: "#67adff")
        case 4: Color(hex: "#c68cff")
        case 5...: Color(hex: "#ffd84d")
        default: Color(hex: palette.foreground).opacity(0.18)
        }
    }

    private var adPlaceholder: some View {
        Text("Ads disabled · internal alpha")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color(hex: palette.muted).opacity(0.78))
            .frame(maxWidth: .infinity, minHeight: 26)
            .background(
                Color(hex: palette.surface).opacity(0.78),
                in: RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 8)
            )
            .accessibilityIdentifier("ad-placeholder")
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(
                    coordinator.wasAbandoned ? "Run ended" : (coordinator.mode == .arcade ? "Game over" : "Zen results")
                )
                .font(.largeTitle.weight(.black))
                .accessibilityIdentifier("results-title")
                Text("\(coordinator.snapshot.points)")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: palette.accent))
                Text(
                    "\(coordinator.snapshot.hits) hits · \(coordinator.snapshot.misses) misses · \(coordinator.snapshot.dodges) dodges"
                )
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color(hex: palette.muted))
                Text("\(formatDuration(coordinator.snapshot.elapsedMilliseconds)) elapsed")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color(hex: palette.muted))

                if coordinator.snapshot.hits > 0 {
                    Text(reactionSummary)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color(hex: palette.muted))
                    Text(ratingSummary)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Color(hex: palette.muted).opacity(0.82))
                        .multilineTextAlignment(.center)
                }

                if !runStatus.isEmpty {
                    Text(runStatus)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: palette.accent))
                        .multilineTextAlignment(.center)
                }

                if submissionStarted {
                    ProgressView("Saving score…")
                        .tint(.cyan)
                } else if submissionFailed, runTicket != nil {
                    Button("Retry score upload") { submitRankedRunIfNeeded() }
                        .buttonStyle(.bordered)
                }

                Button("Play again") { Task { await prepareAndStart() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: palette.accent))
                    .foregroundStyle(.black)
                    .disabled(submissionStarted)
                Button("Main menu") { dismiss() }
                    .buttonStyle(.bordered)
                    .disabled(submissionStarted)
            }
            .foregroundStyle(Color(hex: palette.foreground))
            .padding(22)
            .frame(maxWidth: 330)
            .background(
                Color(hex: palette.surface),
                in: RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 28)
            )
        }
    }

    private var reactionSummary: String {
        let fastest = coordinator.snapshot.fastestReactionMilliseconds ?? 0
        let average = Int(floor((coordinator.snapshot.averageReactionMilliseconds ?? 0) + 0.5))
        return "Fastest \(fastest) ms · Average \(average) ms"
    }

    private var ratingSummary: String {
        let ratings = coordinator.snapshot.speedRatings
        return
            "Godlike \(ratings[.godlike, default: 0]) · Perfect \(ratings[.perfect, default: 0]) · Great \(ratings[.great, default: 0]) · Good \(ratings[.good, default: 0])"
    }

    private func stat(_ label: String, _ value: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color(hex: palette.muted))
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(Color(hex: palette.foreground))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private func formatDuration(_ milliseconds: Double) -> String {
        let totalSeconds = max(0, Int(milliseconds / 1_000))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func prepareAndStart() async {
        coordinator.stop()
        preparationGeneration += 1
        let preparation = preparationGeneration
        preparing = true
        audio.setMusicContext(.gameplay)
        submissionStarted = false
        submissionFailed = false
        if let existingTicket = runTicket {
            await backend.abandonRun(existingTicket.runId)
        }
        guard preparation == preparationGeneration, !Task.isCancelled else { return }
        runTicket = nil
        runStatus = coordinator.mode == .arcade ? "Local practice" : "Local Zen"

        if coordinator.mode == .arcade {
            if backend.sessionState == nil {
                _ = try? await backend.loadSession()
                guard preparation == preparationGeneration, !Task.isCancelled else { return }
            }
            if backend.canStartRankedRun {
                do {
                    let ticket = try await backend.startRun()
                    guard preparation == preparationGeneration, !Task.isCancelled else {
                        await backend.abandonRun(ticket.runId)
                        return
                    }
                    runTicket = ticket
                    runStatus = "Ranked · Hostinger Season 1"
                } catch {
                    guard preparation == preparationGeneration, !Task.isCancelled else { return }
                    runStatus = "Local practice · \(error.localizedDescription)"
                }
            }
        }
        guard preparation == preparationGeneration, !Task.isCancelled else { return }
        coordinator.startNewRun()
        preparing = false
    }

    private func submitRankedRunIfNeeded() {
        guard !submissionStarted, let ticket = runTicket else { return }
        submissionStarted = true
        submissionFailed = false
        runStatus = "Saving · Hostinger Season 1"
        let events = coordinator.proofEvents()
        Task {
            do {
                let result = try await backend.finishRun(ticket: ticket, events: events)
                runStatus =
                    result.verificationStatus == "verified"
                    ? "Saved · rank #\(result.submittedRank ?? result.rank ?? 0)"
                    : "Submitted for review"
                _ = try? await backend.loadSession()
                if runTicket?.runId == ticket.runId {
                    runTicket = nil
                }
            } catch {
                runStatus = "Score not saved · \(error.localizedDescription)"
                submissionFailed = true
            }
            submissionStarted = false
        }
    }

    private func abandonTicketIfNeeded() {
        guard let ticket = runTicket, !submissionStarted else { return }
        runTicket = nil
        Task { await backend.abandonRun(ticket.runId) }
    }

    private func handleGameplayTap(at normalizedLocation: CGPoint) {
        guard frozenPetID != nil,
            boardSceneFrame.width > 0,
            boardSceneFrame.height > 0,
            gameplayPetFrame.width > 0,
            gameplayPetFrame.height > 0
        else { return }

        let pointer = CGPoint(
            x: boardSceneFrame.minX + normalizedLocation.x * boardSceneFrame.width,
            y: boardSceneFrame.minY + normalizedLocation.y * boardSceneFrame.height
        )
        gameplayPetFacing = PetFacing.resolve(
            pointer: pointer,
            petFrame: gameplayPetFrame,
            fallback: gameplayPetFacing
        )
    }

    private func freezePresentationIfNeeded() {
        guard !didFreezePresentation else { return }
        didFreezePresentation = true
        frozenTheme = cosmetics.theme
        frozenPetID = cosmetics.displayedPetID
        frozenGlyphsEnabled = preferences.glyphsEnabled
        coordinator.applyTheme(frozenTheme.id)
        coordinator.applyGlyphsEnabled(frozenGlyphsEnabled)
    }
}

enum ResponseProgressPresentation {
    static func remainingFraction(_ progress: Double?, isActive: Bool) -> Double? {
        guard isActive, let progress else { return nil }
        return min(1, max(0, progress))
    }
}

private struct ResponseProgressBar: View {
    let remainingFraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Color.white.opacity(0.12)
                Color.white.opacity(0.60)
                    .frame(width: geometry.size.width * remainingFraction)
                    .shadow(color: .white.opacity(0.28), radius: 4.5)
            }
        }
        .frame(height: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time left")
        .accessibilityValue("\(Int((remainingFraction * 100).rounded()))")
        .accessibilityIdentifier("response-progress")
    }
}

private struct BoardSceneFramePreferenceKey: PreferenceKey {
    static let defaultValue = CGRect.zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct GameplayPetFramePreferenceKey: PreferenceKey {
    static let defaultValue = CGRect.zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(cleaned, radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }
}
