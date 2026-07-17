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
    @State private var showsGetReady = false
    @State private var submissionStarted = false
    @State private var submissionFailed = false
    @State private var submissionError: String?
    @State private var preparationGeneration = 0
    @State private var frozenTheme = ThemePalette.classic
    @State private var frozenPetID: String?
    @State private var frozenGlyphsEnabled = true
    @State private var gameplayPetFacing = PetFacing.front
    @State private var gameplayPetActivity = 0
    @State private var gameplayScreenWidth: CGFloat = 0
    @State private var didFreezePresentation = false
    @State private var ratingStampPresentation: RatingStampPresentation?
    @State private var ratingStampTask: Task<Void, Never>?

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
                .preference(key: GameplayScreenWidthPreferenceKey.self, value: proxy.size.width)
            }

            if !preparing, coordinator.isFinished || coordinator.wasAbandoned {
                resultOverlay
            }
        }
        .coordinateSpace(name: "game-space")
        .onPreferenceChange(GameplayScreenWidthPreferenceKey.self) { width in
            guard width > 0, width != gameplayScreenWidth else { return }
            Task { @MainActor in gameplayScreenWidth = width }
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
            coordinator.onBoardTap = { location in
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
            showsGetReady = false
            coordinator.stop()
            coordinator.onSoundEvent = nil
            coordinator.onLifecycleEvent = nil
            coordinator.onBoardTap = nil
            abandonTicketIfNeeded()
            audio.setMusicContext(.menu)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                preparationGeneration += 1
                showsGetReady = false
                abandonTicketIfNeeded()
                coordinator.abandonForBackground()
            } else if preparing {
                Task { await prepareAndStart() }
            } else if !coordinator.isFinished, !coordinator.wasAbandoned {
                audio.setMusicContext(.gameplay)
            }
        }
        .onChange(of: coordinator.ratingStampEvent) { _, event in
            guard let event else { return }
            showRatingStamp(event)
        }
        .onDisappear { ratingStampTask?.cancel() }
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

        return VStack(alignment: .leading, spacing: 5) {
            Text("YOUR COLOR")
                .font(palette.appFont(size: 9, weight: .black, relativeTo: .caption2))
                .tracking(0.7)
                .foregroundStyle(Color(hex: palette.muted))
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 12) {
                GameCellPreview(
                    theme: palette,
                    colorIndex: coordinator.mode == .zen ? nil : colorIndex,
                    glyph: glyph,
                    showsGlyphs: frozenGlyphsEnabled,
                    isTarget: true
                )
                .frame(width: 40, height: 40)

                Text(name)
                    .font(palette.appFont(size: 18, weight: .black, relativeTo: .headline))
                    .foregroundStyle(Color(hex: palette.foreground))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
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
        let announcement = GameplayAnnouncementPresentation.resolve(
            showsGetReady: showsGetReady,
            feedback: displayedFeedback
        )

        return ZStack(alignment: .bottom) {
            SpriteView(
                scene: coordinator.scene,
                options: [.allowsTransparency, .ignoresSiblingOrder]
            )
            .allowsHitTesting(!preparing)
            .padding(8)

            if let stamp = ratingStampPresentation {
                GeometryReader { proxy in
                    GlowStampView(
                        text: "\(stamp.event.rating.label) · \(stamp.event.milliseconds) ms",
                        tone: stamp.tone,
                        theme: palette,
                        tilt: stamp.tilt,
                        size: 12,
                        horizontalPadding: 9,
                        verticalPadding: 5
                    )
                    .position(stamp.position(in: proxy.size))
                    .transition(.scale(scale: 0.75).combined(with: .opacity))
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }

            if let announcement {
                GameplayCenterAnnouncementView(
                    announcement: announcement,
                    theme: palette
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .transition(.scale(scale: 0.82).combined(with: .opacity))
                .zIndex(5)
                .accessibilityIdentifier("game-feedback")
            } else {
                Text(displayedFeedback)
                    .font(palette.appFont(size: 12, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(
                        GameplayFeedbackPresentation.isVisuallyHidden(displayedFeedback)
                            ? Color.clear
                            : Color(hex: palette.muted)
                    )
                    .allowsHitTesting(false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .accessibilityHidden(displayedFeedback == "Get ready")
                    .accessibilityIdentifier("game-feedback")
            }
        }
        .frame(width: side, height: side)
        .background(boardShell)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Reaction board")
        .accessibilityIdentifier("reaction-board")
    }

    private var boardShell: some View {
        let shape = RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 22, style: .continuous)
        return ZStack {
            shape.fill(Color(hex: palette.board))
            if palette.id == "disco" {
                GeometryReader { proxy in
                    ZStack {
                        Image("disco-concrete", bundle: .main)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                        Image("disco-concrete-lights", bundle: .main)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .blendMode(.screen)
                            .saturation(1.18)
                            .opacity(0.58)
                            .clipped()
                        Color.black.opacity(0.36)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                }
            }
        }
        .clipShape(shape)
        .overlay {
            shape.stroke(
                palette.id == "disco"
                    ? Color(hex: DiscoThemeTokens.cellBorderHex)
                    : palette.isLight
                        ? Color.white
                        : Color(hex: palette.foreground).opacity(0.12),
                lineWidth: palette.id == "disco" || palette.isPixel ? 2 : 1
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
                    animationTrigger: gameplayPetActivity,
                    facing: gameplayPetFacing
                )
                .frame(width: 54, height: 54)
                .offset(
                    x: screenWidth * 0.40 - (screenWidth - width) / 2 - 27,
                    y: PetArtworkGeometry.gameplayViewVerticalOffset(petID: petID)
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
            .font(palette.appFont(size: 10, weight: .semibold, relativeTo: .caption2))
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
            Color.black.opacity(palette.isLight ? 0.44 : 0.80).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 11) {
                    HStack(spacing: 8) {
                        Button {
                            Task { await prepareAndStart() }
                        } label: {
                            Label("Restart", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(
                            WebSecondaryButtonStyle(
                                theme: palette,
                                accent: Color(hex: palette.accent),
                                minimumHeight: 42
                            )
                        )
                        .disabled(submissionStarted)
                        .accessibilityIdentifier("results-restart")

                        Button(action: { dismiss() }) {
                            Label("Menu", systemImage: "house.fill")
                        }
                        .buttonStyle(WebSecondaryButtonStyle(theme: palette, minimumHeight: 42))
                        .disabled(submissionStarted)
                        .accessibilityIdentifier("results-menu")
                    }

                    VStack(spacing: 4) {
                        Text(resultTitle)
                            .font(palette.appFont(size: 30, weight: .black, relativeTo: .largeTitle))
                            .accessibilityIdentifier("results-title")
                        Text(resultLeadCopy)
                            .font(palette.appFont(size: 12, weight: .bold, relativeTo: .body))
                            .foregroundStyle(Color(hex: palette.muted))
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 3) {
                        Text("SCORE")
                            .font(palette.appFont(size: 9, weight: .black, relativeTo: .caption2))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.78))
                        Text(coordinator.snapshot.points.formatted())
                            .font(palette.appFont(size: 48, weight: .black, relativeTo: .largeTitle))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .minimumScaleFactor(0.70)
                        Text("\(coordinator.snapshot.hits) correct taps")
                            .font(palette.appFont(size: 11, weight: .bold, relativeTo: .caption))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    .frame(maxWidth: .infinity, minHeight: 116)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#7657ff"), Color(hex: "#d33d91"), Color(hex: "#f3a53c")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 18, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 18, style: .continuous)
                            .stroke(.white.opacity(0.35), lineWidth: palette.isPixel ? 2 : 1)
                    }
                    .shadow(color: Color(hex: "#c658ff").opacity(0.35), radius: palette.isPixel ? 0 : 14)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("result-score-card")

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                        spacing: 8
                    ) {
                        resultMetricCard(
                            "Survived",
                            formatDuration(coordinator.snapshot.elapsedMilliseconds),
                            identifier: "result-survived"
                        )
                        resultMetricCard(
                            "Fastest",
                            coordinator.snapshot.fastestReactionMilliseconds.map { "\($0) ms" } ?? "—",
                            identifier: "result-fastest"
                        )
                        resultMetricCard(
                            "Average",
                            coordinator.snapshot.averageReactionMilliseconds.map {
                                "\(Int(floor($0 + 0.5))) ms"
                            } ?? "—",
                            identifier: "result-average"
                        )
                        resultMetricCard(
                            "Dodged",
                            "\(coordinator.snapshot.dodges)",
                            identifier: "result-dodged"
                        )
                    }
                    .accessibilityIdentifier("result-stats")

                    SpeedRatingDistributionView(
                        ratings: coordinator.snapshot.speedRatings,
                        theme: palette
                    )
                    .webCardStyle(theme: palette, padding: 12)
                    .accessibilityIdentifier("result-speed-ratings")

                    if submissionStarted || submissionFailed {
                        VStack(spacing: 8) {
                            if submissionStarted {
                                ProgressView("Saving score…")
                                    .tint(Color(hex: palette.accent))
                            } else {
                                Text(submissionError ?? "Score was not saved.")
                                    .font(palette.appFont(size: 11, weight: .bold, relativeTo: .caption))
                                    .foregroundStyle(.orange)
                                    .multilineTextAlignment(.center)

                                if runTicket != nil {
                                    Button("Retry score upload") { submitRankedRunIfNeeded() }
                                        .buttonStyle(
                                            WebSecondaryButtonStyle(
                                                theme: palette,
                                                accent: Color(hex: palette.accent),
                                                minimumHeight: 38
                                            )
                                        )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .webCardStyle(theme: palette, padding: 10)
                        .accessibilityIdentifier("result-save-status")
                    }
                }
                .foregroundStyle(Color(hex: palette.foreground))
                .padding(16)
                .background(
                    Color(hex: palette.surface).opacity(palette.isLight ? 0.97 : 0.96),
                    in: RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 24, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 24, style: .continuous)
                        .stroke(Color(hex: palette.foreground).opacity(0.13), lineWidth: palette.isPixel ? 2 : 1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: 460)
        }
    }

    private var resultTitle: String {
        coordinator.wasAbandoned
            ? "Run ended"
            : (coordinator.mode == .arcade ? "Game over" : "Zen results")
    }

    private var resultLeadCopy: String {
        if coordinator.wasAbandoned {
            return "The run stopped when the app left the foreground."
        }
        if coordinator.mode == .zen {
            return "A calm practice run with no lives, ranking, or coins."
        }
        return
            "\(coordinator.snapshot.hits) hits · \(coordinator.snapshot.misses) misses · \(coordinator.snapshot.dodges) dodges"
    }

    private func resultMetricCard(
        _ label: String,
        _ value: String,
        identifier: String
    ) -> some View {
        VStack(spacing: 3) {
            Text(label.uppercased())
                .font(palette.appFont(size: 8, weight: .black, relativeTo: .caption2))
                .tracking(0.65)
                .foregroundStyle(Color(hex: palette.muted))
            Text(value)
                .font(palette.appFont(size: 18, weight: .black, relativeTo: .headline))
                .foregroundStyle(Color(hex: palette.foreground))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .webCardStyle(theme: palette, padding: 8)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
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
                .font(palette.appFont(size: 10, weight: .bold, relativeTo: .caption2))
                .foregroundStyle(Color(hex: palette.muted))
            Text(value)
                .font(palette.appFont(size: 17, weight: .semibold, relativeTo: .headline))
                .monospacedDigit()
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
        showsGetReady = false
        audio.setMusicContext(.gameplay)
        submissionStarted = false
        submissionFailed = false
        submissionError = nil
        if let existingTicket = runTicket {
            await backend.abandonRun(existingTicket.runId)
        }
        guard preparation == preparationGeneration, !Task.isCancelled else { return }
        runTicket = nil

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
                } catch {
                    guard preparation == preparationGeneration, !Task.isCancelled else { return }
                }
            }
        }
        guard preparation == preparationGeneration, !Task.isCancelled else { return }
        showsGetReady = true
        do {
            try await Task.sleep(for: GameplayAnnouncementPresentation.getReadyDuration)
        } catch {
            if preparation == preparationGeneration {
                showsGetReady = false
            }
            return
        }
        guard preparation == preparationGeneration, !Task.isCancelled else { return }
        coordinator.startNewRun()
        showsGetReady = false
        preparing = false
    }

    private func submitRankedRunIfNeeded() {
        guard !submissionStarted, let ticket = runTicket else { return }
        submissionStarted = true
        submissionFailed = false
        submissionError = nil
        let events = coordinator.proofEvents()
        Task {
            do {
                _ = try await backend.finishRun(ticket: ticket, events: events)
                _ = try? await backend.loadSession()
                if runTicket?.runId == ticket.runId {
                    runTicket = nil
                }
            } catch {
                submissionError = "Score not saved · \(error.localizedDescription)"
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
        guard frozenPetID != nil, gameplayScreenWidth > 0 else { return }
        gameplayPetFacing = PetTapFollow.resolveGameplay(
            normalizedPointerX: normalizedLocation.x,
            screenWidth: gameplayScreenWidth,
            current: gameplayPetFacing
        )
        gameplayPetActivity += 1
    }

    private func showRatingStamp(_ event: GameplayRatingStampEvent) {
        ratingStampTask?.cancel()
        let deterministic: Bool
        #if DEBUG
            deterministic = ProcessInfo.processInfo.arguments.contains("--uitesting")
        #else
            deterministic = false
        #endif
        withAnimation(.spring(response: 0.20, dampingFraction: 0.72)) {
            ratingStampPresentation = RatingStampPresentation.make(
                event: event,
                deterministic: deterministic
            )
        }
        ratingStampTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(620))
            guard !Task.isCancelled, ratingStampPresentation?.event.id == event.id else { return }
            withAnimation(.easeOut(duration: 0.15)) {
                ratingStampPresentation = nil
            }
        }
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

struct RatingStampPresentation: Equatable {
    enum Edge: Int, CaseIterable {
        case top
        case right
        case bottom
        case left
    }

    let event: GameplayRatingStampEvent
    let edge: Edge
    let laneFraction: CGFloat
    let tilt: Double

    var tone: Color {
        switch event.rating {
        case .godlike: Color(hex: "#ffd84d")
        case .perfect: Color(hex: "#c68cff")
        case .great: Color(hex: "#67adff")
        case .good: Color(hex: "#72e995")
        }
    }

    static func make(event: GameplayRatingStampEvent, deterministic: Bool) -> Self {
        let lanes: [CGFloat] = [0.24, 0.50, 0.76]
        let tilts = [-9.0, -6.0, -3.0, 3.0, 6.0, 9.0]
        if deterministic {
            return Self(
                event: event,
                edge: Edge.allCases[event.id % Edge.allCases.count],
                laneFraction: lanes[event.id % lanes.count],
                tilt: tilts[event.id % tilts.count]
            )
        }
        return Self(
            event: event,
            edge: Edge.allCases.randomElement() ?? .top,
            laneFraction: lanes.randomElement() ?? 0.5,
            tilt: tilts.randomElement() ?? 3
        )
    }

    func position(in size: CGSize) -> CGPoint {
        let horizontalInset = min(68, max(48, size.width * 0.18))
        let verticalInset = min(23, max(17, size.height * 0.055))
        return switch edge {
        case .top:
            CGPoint(x: size.width * laneFraction, y: verticalInset)
        case .right:
            CGPoint(x: size.width - horizontalInset, y: size.height * laneFraction)
        case .bottom:
            CGPoint(x: size.width * laneFraction, y: size.height - verticalInset)
        case .left:
            CGPoint(x: horizontalInset, y: size.height * laneFraction)
        }
    }
}

enum ResponseProgressPresentation {
    static func remainingFraction(_ progress: Double?, isActive: Bool) -> Double? {
        guard isActive, let progress else { return nil }
        return min(1, max(0, progress))
    }
}

enum GameplayFeedbackPresentation {
    static func isVisuallyHidden(_ feedback: String) -> Bool {
        if ["Get ready", "Too early", "Too slow"].contains(feedback) { return true }
        if feedback.hasPrefix("Tap ") { return true }
        return ["Godlike ·", "Perfect ·", "Great ·", "Good ·", "Hit ·"]
            .contains { feedback.hasPrefix($0) }
    }
}

enum GameplayCenterAnnouncement: Equatable, Sendable {
    case getReady
    case tooEarly
    case tooSlow

    var text: String {
        switch self {
        case .getReady: "Get ready"
        case .tooEarly: "Too early"
        case .tooSlow: "Too slow"
        }
    }
}

enum GameplayAnnouncementPresentation {
    static let getReadyDuration = Duration.seconds(1)

    static func resolve(
        showsGetReady: Bool,
        feedback: String
    ) -> GameplayCenterAnnouncement? {
        if showsGetReady { return .getReady }
        if feedback == "Too early" { return .tooEarly }
        if feedback == "Too slow" { return .tooSlow }
        return nil
    }
}

private struct GameplayCenterAnnouncementView: View {
    let announcement: GameplayCenterAnnouncement
    let theme: ThemePalette

    var body: some View {
        GlowStampView(
            text: announcement.text,
            tone: tone,
            theme: theme,
            size: 30,
            horizontalPadding: 22,
            verticalPadding: 13
        )
        .shadow(color: tone.opacity(theme.isLight ? 0.28 : 0.74), radius: theme.isPixel ? 0 : 18)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(announcement.text)
    }

    private var tone: Color {
        switch announcement {
        case .getReady:
            Color(hex: theme.accent)
        case .tooEarly:
            Color(hex: theme.isLight ? "#b94117" : "#ff9b5c")
        case .tooSlow:
            Color(hex: theme.isLight ? "#a52b50" : "#ff6f9f")
        }
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

private struct GameplayScreenWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
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
