import PimPoPomCore
import SpriteKit
import SwiftUI

enum GameplayBoardInteraction {
    static func allowsHitTesting(
        preparing: Bool,
        recoveryRemainingMilliseconds: Double
    ) -> Bool {
        !preparing && recoveryRemainingMilliseconds <= 0
    }
}

struct GameView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var backend: BackendClient
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var cosmetics: CosmeticsController
    @EnvironmentObject private var audio: AudioController
    @EnvironmentObject private var ads: AdsController
    @StateObject private var coordinator: GameCoordinator
    @State private var runTicket: RunTicket?
    @State private var preparing = true
    @State private var showsGetReady = false
    @State private var submissionStarted = false
    @State private var submissionFailed = false
    @State private var submissionError: String?
    @State private var submissionConfirmation: String?
    @State private var rankedRunStartError: String?
    @State private var preparationGeneration = 0
    @State private var frozenTheme = ThemePalette.classic
    @State private var frozenPetID: String?
    @State private var frozenGlyphsEnabled = true
    @State private var gameplayPetFacing = PetFacing.front
    @State private var gameplayPetActivity = 0
    @State private var gameplayScreenWidth: CGFloat = 0
    @State private var didFreezePresentation = false
    @State private var hitFeedbackPresentations: [GameplayHitPresentation] = []
    @State private var hitFeedbackTasks: [Int: Task<Void, Never>] = [:]
    @State private var reservesAdSpacingForRun: Bool
    private let onRunFinished: (UUID) -> Void

    private var palette: ThemePalette { frozenTheme }

    init(
        mode: GameMode,
        reservesAdSpacingForRun: Bool = false,
        onRunFinished: @escaping (UUID) -> Void = { _ in }
    ) {
        _coordinator = StateObject(wrappedValue: GameCoordinator(mode: mode))
        _reservesAdSpacingForRun = State(initialValue: reservesAdSpacingForRun)
        self.onRunFinished = onRunFinished
    }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: palette)

            GeometryReader { proxy in
                let layout = GameplayLayoutMetrics.resolve(
                    availableSize: proxy.size,
                    hasPet: frozenPetID != nil
                )

                VStack(spacing: 0) {
                    gameUtilityHeader
                    Color.clear
                        .frame(height: GameplayLayoutMetrics.headerToHUDSpacing)
                        .accessibilityHidden(true)
                    gameplayHUD
                    Color.clear
                        .frame(height: layout.boardTopSpacing)
                        .accessibilityHidden(true)
                    gameBoard(side: layout.boardSide)
                    Color.clear
                        .frame(height: layout.boardToSpeedBarSpacing)
                        .accessibilityHidden(true)
                    streakAndPet(width: layout.boardSide, screenWidth: proxy.size.width)
                    Spacer(minLength: 0)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                .preference(key: GameplayScreenWidthPreferenceKey.self, value: proxy.size.width)
            }

            if !preparing, coordinator.isFinished || coordinator.wasAbandoned {
                resultOverlay
            }

            if let rankedRunStartError {
                rankedRunStartFailure(message: rankedRunStartError)
            }
        }
        .coordinateSpace(name: "game-space")
        .simultaneousGesture(
            SpatialTapGesture(coordinateSpace: .named("game-space"))
                .onEnded { value in
                    handleGameplayScreenTap(atX: value.location.x)
                }
        )
        .onPreferenceChange(GameplayScreenWidthPreferenceKey.self) { width in
            guard width > 0, width != gameplayScreenWidth else { return }
            Task { @MainActor in gameplayScreenWidth = width }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomAdSurface
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
                    onRunFinished(coordinator.gameplaySessionID)
                    submitRankedRunIfNeeded()
                }
            }
            configureScreenshotAutoplayPetFollowing()
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
            clearHitFeedback()
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
        .onChange(of: coordinator.hitFeedbackEvent) { _, event in
            guard let event else { return }
            showHitFeedback(event)
        }
        .onChange(of: submissionStarted) { _, isSubmitting in
            if !isSubmitting {
                presentInterstitialOpportunityIfReady()
            }
        }
    }

    @ViewBuilder
    private var bottomAdSurface: some View {
        if rankedRunStartError == nil {
            if coordinator.isFinished || coordinator.wasAbandoned {
                if ads.reservesBannerSlot {
                    adSurface(placement: .results)
                }
            } else if reservesAdSpacingForRun {
                if ads.reservesBannerSlot {
                    if preparing {
                        Color.clear
                            .frame(height: GameplayLayoutMetrics.adBannerHeight)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .accessibilityHidden(true)
                    } else {
                        adSurface(placement: .activeGameplay)
                    }
                } else {
                    Color.clear
                        .frame(height: GameplayLayoutMetrics.adBannerHeight)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func adSurface(placement: AdBannerPlacement) -> some View {
        AdBannerSlot(placement: placement)
            .id(placement.rawValue)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(hex: palette.backgroundBottom).opacity(0.96))
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
                    compactStat(
                        "Lives",
                        livesPresentation,
                        identifier: "game-lives",
                        valueColor: Color(hex: GameHUDMetrics.livesColorHex)
                    )
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
        let content = GameColorHeroPresentation.resolveContent(
            mode: coordinator.mode,
            hasLoadedRunColor: coordinator.snapshot.state != .idle,
            colorIndex: coordinator.snapshot.playerColorIndex,
            colorName: coordinator.snapshot.playerColor.name,
            glyph: coordinator.snapshot.playerColor.glyph
        )
        let outlineTone = Color(
            hex: GameColorHeroPresentation.outlineHex(
                theme: palette,
                mode: coordinator.mode,
                colorIndex: content.colorIndex
            )
        )
        let outlineOpacity = GameColorHeroPresentation.outlineOpacity(
            theme: palette,
            mode: coordinator.mode
        )

        return VStack(alignment: .leading, spacing: 5) {
            Text("YOUR COLOR")
                .font(palette.appFont(size: 9, weight: .black, relativeTo: .caption2))
                .tracking(0.7)
                .foregroundStyle(Color(hex: palette.muted))
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 12) {
                Group {
                    if coordinator.mode == .zen {
                        ZenAnyCellPreview(theme: palette)
                    } else {
                        GameCellPreview(
                            theme: palette,
                            colorIndex: content.colorIndex,
                            glyph: content.glyph,
                            showsGlyphs: frozenGlyphsEnabled && content.colorIndex != nil,
                            isTarget: true,
                            glyphScale: GameCellVisualMetrics.previewGlyphScale
                        )
                    }
                }
                .frame(
                    width: ZenAnyCellTokens.previewSide,
                    height: ZenAnyCellTokens.previewSide
                )

                Text(content.name)
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
        .clipShape(RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 11))
        .overlay {
            RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 11)
                .stroke(
                    outlineTone.opacity(outlineOpacity),
                    lineWidth: GameHUDMetrics.colorHeroOutlineWidth
                )
                .shadow(
                    color: outlineTone.opacity(GameHUDMetrics.colorHeroGlowOpacity),
                    radius: palette.isPixel ? 3 : GameHUDMetrics.colorHeroGlowRadius
                )
                .shadow(
                    color: outlineTone.opacity(GameHUDMetrics.colorHeroGlowOpacity * 0.58),
                    radius: palette.isPixel ? 1 : GameHUDMetrics.colorHeroGlowRadius * 1.65
                )
        }
        .overlay(alignment: .bottomLeading) {
            if let remainingFraction {
                ResponseProgressBar(remainingFraction: remainingFraction)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 3)
            }
        }
        .id(
            "target-color-\(content.colorIndex.map(String.init) ?? "pending")-\(content.name)"
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            GameColorHeroPresentation.accessibilityLabel(
                mode: coordinator.mode,
                showsGlyphs: frozenGlyphsEnabled,
                content: content
            )
        )
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

    private func compactStat(
        _ label: String,
        _ value: String,
        identifier: String,
        valueColor: Color? = nil
    ) -> some View {
        VStack(spacing: 1) {
            Text(label.uppercased())
                .font(palette.appFont(size: 8, weight: .black, relativeTo: .caption2))
                .tracking(0.35)
                .foregroundStyle(Color(hex: palette.muted))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            if identifier == "game-lives", palette.isPixel, coordinator.mode == .arcade {
                PixelLivesView(
                    remaining: max(0, min(3, coordinator.snapshot.lives)),
                    color: valueColor ?? Color(hex: palette.foreground)
                )
                .frame(height: 16)
            } else {
                Text(value)
                    .font(palette.appFont(size: 15, weight: .black, relativeTo: .headline))
                    .monospacedDigit()
                    .foregroundStyle(valueColor ?? Color(hex: palette.foreground))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
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
        let shell = RoundedRectangle(
            cornerRadius: GameBoardVisualMetrics.shellCornerRadius(theme: palette),
            style: .continuous
        )

        return ZStack(alignment: .bottom) {
            shell
                .fill(
                    palette.id == "disco"
                        ? Color.black.opacity(0.34)
                        : Color(hex: palette.board)
                )
                .shadow(
                    color: palette.isLight
                        ? Color(hex: "#3d789e").opacity(0.20)
                        : .black.opacity(0.34),
                    radius: palette.isPixel ? 0 : 14,
                    y: palette.isPixel ? 0 : 7
                )
                .allowsHitTesting(false)
                .zIndex(GameplayOverlayLayer.boardShell)

            SpriteView(
                scene: coordinator.scene,
                options: [.allowsTransparency, .ignoresSiblingOrder]
            )
            .clipShape(shell)
            .allowsHitTesting(
                GameplayBoardInteraction.allowsHitTesting(
                    preparing: preparing,
                    recoveryRemainingMilliseconds: coordinator.snapshot.recoveryRemainingMilliseconds
                )
            )
            .zIndex(GameplayOverlayLayer.board)

            if palette.id == "disco" {
                DiscoBoardGlowOverlay(
                    snapshot: coordinator.snapshot,
                    theme: palette,
                    roundPresentationExpired: coordinator.isRoundPresentationExpired
                )
                .clipShape(shell)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .zIndex(GameplayOverlayLayer.discoGlow)
            }

            shell
                .stroke(
                    palette.id == "disco"
                        ? Color.white.opacity(0.16)
                        : palette.isLight
                            ? Color.white
                            : Color(hex: palette.foreground).opacity(0.12),
                    lineWidth: palette.isPixel ? 2 : 1
                )
                .allowsHitTesting(false)
                .zIndex(GameplayOverlayLayer.boardShellBorder)

            ForEach(hitFeedbackPresentations) { presentation in
                GeometryReader { proxy in
                    ZStack {
                        Text(presentation.scoreText)
                            .font(
                                palette.appFont(
                                    size: GameplayHitFeedbackMetrics.pointsFontSize,
                                    weight: .black,
                                    relativeTo: .headline
                                )
                            )
                            .monospacedDigit()
                            .position(presentation.tapPosition(in: proxy.size))

                        Text(presentation.ratingText)
                            .font(
                                palette.appFont(
                                    size: GameplayHitFeedbackMetrics.ratingFontSize,
                                    weight: .bold,
                                    relativeTo: .subheadline
                                )
                            )
                            .monospacedDigit()
                            .position(presentation.ratingPosition(in: proxy.size))
                    }
                    .foregroundStyle(presentation.tone)
                    .shadow(color: presentation.tone.opacity(0.98), radius: 5)
                    .shadow(color: presentation.tone.opacity(0.64), radius: 11)
                    .opacity(presentation.opacity)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .zIndex(GameplayOverlayLayer.tapFeedback)
            }

            if let announcement {
                GameplayCenterAnnouncementView(
                    announcement: announcement,
                    theme: palette
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .transition(.scale(scale: 0.82).combined(with: .opacity))
                .zIndex(GameplayOverlayLayer.announcement)
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
                    .zIndex(GameplayOverlayLayer.announcement)
                    .accessibilityHidden(displayedFeedback == "Get ready")
                    .accessibilityIdentifier("game-feedback")
            }
        }
        .frame(width: side, height: side)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Reaction board")
        .accessibilityValue(
            "\(coordinator.snapshot.difficulty.gridDimension) by "
                + "\(coordinator.snapshot.difficulty.gridDimension)"
        )
        .accessibilityIdentifier("reaction-board")
    }

    private func streakAndPet(width: CGFloat, screenWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            streakMeter

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
                    y: -28 + PetArtworkGeometry.gameplayViewVerticalOffset(petID: petID)
                )
                .allowsHitTesting(false)
                .accessibilityIdentifier("gameplay-pet-\(petID)")
            }
        }
        .frame(width: width, height: 50, alignment: .bottom)
        .padding(.bottom, GameplayLayoutMetrics.footerLift)
    }

    private var streakMeter: some View {
        let trackShape = palette.isPixel ? AnyShape(Rectangle()) : AnyShape(Capsule())
        let presentation = SpeedBarPresentation.resolve(
            multiplier: coordinator.snapshot.multiplier,
            progress: coordinator.snapshot.streakProgress,
            target: coordinator.snapshot.streakTarget
        )

        return HStack(spacing: 7) {
            GeometryReader { _ in
                ZStack(alignment: .leading) {
                    trackShape
                        .fill(streakTierColor.opacity(coordinator.snapshot.multiplier == 1 ? 0.10 : 0.28))

                    SpeedBarLayeredFill(
                        presentation: presentation,
                        isPixel: palette.isPixel
                    )

                    if palette.isPixel {
                        HStack(spacing: 0) {
                            ForEach(0..<5, id: \.self) { index in
                                Rectangle()
                                    .fill(Color.clear)
                                    .overlay(alignment: .trailing) {
                                        if index < 4 {
                                            Rectangle()
                                                .fill(Color(hex: palette.board).opacity(0.62))
                                                .frame(width: 2)
                                        }
                                    }
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    Text("SPEED BAR")
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
                .background(streakTierColor, in: trackShape)
                .overlay {
                    if palette.isPixel {
                        Rectangle()
                            .stroke(Color(hex: palette.foreground).opacity(0.36), lineWidth: 2)
                    }
                }
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
        .accessibilityLabel("Speed bar")
        .accessibilityValue(
            "Multiplier \(coordinator.snapshot.multiplier), \(coordinator.snapshot.streakProgress) of \(coordinator.snapshot.streakTarget)"
        )
        .accessibilityIdentifier("speed-streak")
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

                    if submissionFailed {
                        VStack(spacing: 8) {
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
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .webCardStyle(theme: palette, padding: 10)
                        .accessibilityIdentifier("result-save-status")
                    } else if submissionStarted || submissionConfirmation != nil {
                        HStack(spacing: 5) {
                            if submissionStarted {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(Color(hex: palette.accent))
                                Text("Saving score…")
                            } else if let submissionConfirmation {
                                Image(systemName: "checkmark.circle.fill")
                                    .accessibilityHidden(true)
                                Text(submissionConfirmation)
                            }
                        }
                        .font(palette.appFont(size: 10, weight: .bold, relativeTo: .caption2))
                        .foregroundStyle(Color(hex: palette.accent))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
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
        .onAppear { presentInterstitialOpportunityIfReady() }
    }

    private func presentInterstitialOpportunityIfReady() {
        guard coordinator.isFinished,
            !coordinator.wasAbandoned,
            !submissionStarted
        else { return }
        ads.presentInterstitialIfDue(for: coordinator.gameplaySessionID)
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
        clearHitFeedback()
        preparationGeneration += 1
        let preparation = preparationGeneration
        preparing = true
        showsGetReady = false
        audio.setMusicContext(.gameplay)
        submissionStarted = false
        submissionFailed = false
        submissionError = nil
        submissionConfirmation = nil
        rankedRunStartError = nil
        reservesAdSpacingForRun = ads.reservesBannerSlot
        if let existingTicket = runTicket {
            await backend.abandonRun(existingTicket.runId)
        }
        guard preparation == preparationGeneration, !Task.isCancelled else { return }
        runTicket = nil

        if coordinator.mode == .arcade {
            if backend.sessionState == nil {
                do {
                    _ = try await backend.loadSession()
                } catch {
                    guard preparation == preparationGeneration, !Task.isCancelled else { return }
                    rankedRunStartError =
                        "Could not contact the leaderboard. Check the connection and retry."
                    preparing = false
                    return
                }
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
                    rankedRunStartError =
                        "Could not start a ranked run · \(error.localizedDescription)"
                    preparing = false
                    return
                }
            }
        }
        guard preparation == preparationGeneration, !Task.isCancelled else { return }
        reservesAdSpacingForRun = ads.reservesBannerSlot
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
        submissionConfirmation = nil
        let events = coordinator.proofEvents()
        Task {
            do {
                let response = try await backend.finishRun(ticket: ticket, events: events)
                submissionConfirmation = scoreSaveConfirmation(response)
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

    private func scoreSaveConfirmation(_ response: RunFinishResponse) -> String {
        switch response.normalizedVerificationStatus {
        case "verified":
            if let rank = response.submittedRank ?? response.rank {
                return "Score saved to leaderboard · #\(rank)"
            }
            return "Score saved to leaderboard"
        case "review":
            return "Score saved for security review"
        case "quarantined":
            return "Score saved, but not ranked"
        default:
            return "Score saved"
        }
    }

    private func rankedRunStartFailure(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(hex: palette.accent))
                Text("Ranked run unavailable")
                    .font(palette.appFont(size: 20, weight: .black, relativeTo: .title3))
                Text(message)
                    .font(palette.appFont(size: 12, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(Color(hex: palette.muted))
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    Button("Menu") { dismiss() }
                        .buttonStyle(
                            WebSecondaryButtonStyle(theme: palette, minimumHeight: 42)
                        )
                    Button("Retry") { Task { await prepareAndStart() } }
                        .buttonStyle(
                            WebSecondaryButtonStyle(
                                theme: palette,
                                accent: Color(hex: palette.accent),
                                minimumHeight: 42
                            )
                        )
                }
            }
            .foregroundStyle(Color(hex: palette.foreground))
            .padding(18)
            .frame(maxWidth: 330)
            .background(
                Color(hex: palette.surface).opacity(0.98),
                in: RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 20)
            )
            .padding(20)
        }
        .zIndex(300)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ranked-run-start-error")
    }

    private func abandonTicketIfNeeded() {
        guard let ticket = runTicket, !submissionStarted else { return }
        runTicket = nil
        Task { await backend.abandonRun(ticket.runId) }
    }

    private func handleGameplayScreenTap(atX pointerX: CGFloat) {
        guard frozenPetID != nil, gameplayScreenWidth > 0 else { return }
        gameplayPetFacing = PetTapFollow.resolve(
            pointerX: pointerX,
            petCenterX: gameplayScreenWidth * 0.40,
            interactionWidth: gameplayScreenWidth,
            current: gameplayPetFacing
        )
        gameplayPetActivity += 1
    }

    private func configureScreenshotAutoplayPetFollowing() {
        #if DEBUG
            guard
                ScreenshotFixture.resolve(arguments: ProcessInfo.processInfo.arguments)?
                    .autoplayEnabled == true
            else {
                return
            }
            coordinator.onBoardTap = { normalizedLocation in
                guard frozenPetID != nil, gameplayScreenWidth > 0 else { return }
                gameplayPetFacing = PetTapFollow.resolveGameplay(
                    normalizedPointerX: normalizedLocation.x,
                    screenWidth: gameplayScreenWidth,
                    current: gameplayPetFacing
                )
                gameplayPetActivity += 1
            }
        #endif
    }

    private func showHitFeedback(_ event: GameplayHitFeedbackEvent) {
        if hitFeedbackPresentations.count >= 8,
            let oldest = hitFeedbackPresentations.first
        {
            hitFeedbackTasks.removeValue(forKey: oldest.id)?.cancel()
            hitFeedbackPresentations.removeFirst()
        }

        hitFeedbackPresentations.append(
            GameplayHitPresentation(
                event: event,
                phase: .visible
            )
        )
        let task = Task { @MainActor in
            // Keep both local to the tap, then fade them together. The 680 ms
            // hold plus 300 ms fade keeps their complete lifetime under one second.
            try? await Task.sleep(for: GameplayHitFeedbackMetrics.visibleHoldDuration)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: GameplayHitFeedbackMetrics.fadeDurationSeconds)) {
                updateHitFeedback(id: event.id, phase: .hidden)
            }
            try? await Task.sleep(for: GameplayHitFeedbackMetrics.fadeDuration)
            guard !Task.isCancelled else { return }
            hitFeedbackPresentations.removeAll { $0.id == event.id }
            hitFeedbackTasks.removeValue(forKey: event.id)
        }
        hitFeedbackTasks[event.id] = task
    }

    private func updateHitFeedback(
        id: Int,
        phase: GameplayHitAnimationPhase
    ) {
        guard let index = hitFeedbackPresentations.firstIndex(where: { $0.id == id }) else {
            return
        }
        hitFeedbackPresentations[index].phase = phase
    }

    private func clearHitFeedback() {
        for task in hitFeedbackTasks.values { task.cancel() }
        hitFeedbackTasks.removeAll(keepingCapacity: true)
        hitFeedbackPresentations.removeAll(keepingCapacity: true)
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

private struct PixelLivesView: View {
    let remaining: Int
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                PixelHeartIcon(filled: index < remaining, color: color)
                    .frame(width: 14, height: 12)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct PixelHeartIcon: View {
    let filled: Bool
    let color: Color

    private static let filledCells = cells([
        "0110110",
        "1111111",
        "1111111",
        "0111110",
        "0011100",
        "0001000",
    ])
    private static let outlineCells = cells([
        "0110110",
        "1001001",
        "1000001",
        "0100010",
        "0010100",
        "0001000",
    ])

    var body: some View {
        Canvas { context, size in
            let columns = 7
            let rows = 6
            let pixel = min(size.width / CGFloat(columns), size.height / CGFloat(rows))
            let originX = (size.width - pixel * CGFloat(columns)) / 2
            let originY = (size.height - pixel * CGFloat(rows)) / 2
            let cells = filled ? Self.filledCells : Self.outlineCells

            for row in 0..<rows {
                for column in 0..<columns {
                    let cell = row * columns + column
                    guard cells.contains(cell) else { continue }
                    context.fill(
                        Path(
                            CGRect(
                                x: originX + CGFloat(column) * pixel,
                                y: originY + CGFloat(row) * pixel,
                                width: pixel,
                                height: pixel
                            )
                        ),
                        with: .color(color.opacity(filled ? 1 : 0.42))
                    )
                }
            }
        }
    }

    private static func cells(_ rows: [String]) -> Set<Int> {
        Set(
            rows.enumerated().flatMap { row, pattern in
                pattern.enumerated().compactMap { column, value in
                    value == "1" ? row * 7 + column : nil
                }
            }
        )
    }
}

enum GameplayHitAnimationPhase: Equatable {
    case hidden
    case visible
}

enum GameplayHitFeedbackMetrics {
    static let pointsFontSize: CGFloat = 16
    static let ratingFontSize: CGFloat = 12
    static let ratingVerticalOffset: CGFloat = 19
    static let visibleHoldDuration: Duration = .milliseconds(680)
    static let fadeDuration: Duration = .milliseconds(300)
    static let fadeDurationSeconds = 0.30
    static let lifetimeMilliseconds = 980
}

struct GameplayHitPresentation: Equatable, Identifiable {
    let event: GameplayHitFeedbackEvent
    var phase: GameplayHitAnimationPhase

    var id: Int { event.id }

    var scoreText: String {
        GameplayScoreFormatting.flyout(points: event.pointsAwarded)
    }

    var ratingText: String {
        GameplayRatingFormatting.detail(
            rating: event.rating,
            milliseconds: event.milliseconds
        )
    }

    var tone: Color {
        switch event.rating {
        case .godlike: Color(hex: "#ffd84d")
        case .perfect: Color(hex: "#c68cff")
        case .great: Color(hex: "#67adff")
        case .good: Color(hex: "#72e995")
        }
    }

    var opacity: Double {
        phase == .hidden ? 0 : 1
    }

    func tapPosition(in size: CGSize) -> CGPoint {
        CGPoint(
            x: event.normalizedLocation.x * size.width,
            y: event.normalizedLocation.y * size.height
        )
    }

    func ratingPosition(in size: CGSize) -> CGPoint {
        let tap = tapPosition(in: size)
        return CGPoint(
            x: tap.x,
            y: tap.y + GameplayHitFeedbackMetrics.ratingVerticalOffset
        )
    }
}

private struct DiscoBoardGlowOverlay: View {
    let snapshot: GameSnapshot
    let theme: ThemePalette
    let roundPresentationExpired: Bool

    var body: some View {
        GeometryReader { proxy in
            let layout = GameBoardLayout(
                size: proxy.size,
                dimension: snapshot.difficulty.gridDimension
            )
            let cornerRadius = GameCellVisualMetrics.liveCornerRadius(
                theme: theme,
                gridDimension: snapshot.difficulty.gridDimension
            )
            // Resolve the cached bitmap while the board is waiting/Get ready,
            // before the first timed target for each grid dimension appears.
            let _ = DiscoOutgoingGlowArtwork.image(
                cellSide: layout.cellSide,
                cornerRadius: cornerRadius
            )

            ZStack {
                ForEach(snapshot.cells.indices, id: \.self) { index in
                    let cell = snapshot.cells[index]
                    if let colorIndex = cell.colorIndex,
                        !(roundPresentationExpired && cell.kind == .target)
                    {
                        let frame = layout.cellFrame(at: index, yAxis: .down)
                        DiscoOutgoingGlowView(
                            color: theme.color(at: colorIndex),
                            cellSide: layout.cellSide,
                            cornerRadius: cornerRadius
                        )
                        .position(x: frame.midX, y: frame.midY)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

enum GameplayScoreFormatting {
    static func flyout(points: Int) -> String {
        let digits = Array(String(max(0, points)))
        var grouped = ""
        grouped.reserveCapacity(digits.count + digits.count / 3)
        for (index, digit) in digits.enumerated() {
            if index > 0, (digits.count - index).isMultiple(of: 3) {
                grouped.append(",")
            }
            grouped.append(digit)
        }
        return "+\(grouped) points"
    }
}

enum ResponseProgressPresentation {
    static func remainingFraction(_ progress: Double?, isActive: Bool) -> Double? {
        guard isActive, let progress else { return nil }
        return min(1, max(0, progress))
    }
}

enum GameHUDMetrics {
    static let colorHeroOutlineWidth = 4.0
    static let colorHeroGlowOpacity = 0.72
    static let colorHeroGlowRadius: CGFloat = 10
    static let livesColorHex = "#ff5370"
}

enum GameColorHeroPresentation {
    struct Content: Equatable, Sendable {
        let colorIndex: Int?
        let name: String
        let glyph: String
    }

    static func resolveContent(
        mode: GameMode,
        hasLoadedRunColor: Bool,
        colorIndex: Int,
        colorName: String,
        glyph: String
    ) -> Content {
        if mode == .zen {
            return Content(colorIndex: nil, name: "Any", glyph: "")
        }
        guard hasLoadedRunColor else {
            return Content(colorIndex: nil, name: "", glyph: "")
        }
        return Content(colorIndex: colorIndex, name: colorName, glyph: glyph)
    }

    static func outlineHex(
        theme: ThemePalette,
        mode: GameMode,
        colorIndex: Int?
    ) -> String {
        if mode == .zen {
            return theme.isLight ? "#477694" : theme.accent
        }
        guard let colorIndex else {
            return theme.isLight ? theme.muted : theme.foreground
        }
        return theme.tileColors[colorIndex % theme.tileColors.count]
    }

    static func outlineOpacity(theme: ThemePalette, mode: GameMode) -> Double {
        theme.isLight && mode == .zen ? 0.52 : 0.82
    }

    static func accessibilityLabel(
        mode: GameMode,
        showsGlyphs: Bool,
        content: Content
    ) -> String {
        guard mode != .arcade || content.colorIndex != nil else {
            return "Target color pending"
        }
        guard mode == .arcade, showsGlyphs else {
            return "Target color \(content.name)"
        }
        return "Target color \(content.name), symbol \(content.glyph)"
    }
}

struct GameplayLayoutPlan: Equatable, Sendable {
    let boardSide: CGFloat
    let boardTopSpacing: CGFloat
    let boardToSpeedBarSpacing: CGFloat
}

enum GameplayLayoutMetrics {
    static let footerLift: CGFloat = 8
    static let adBannerHeight: CGFloat = 50
    static let horizontalInset: CGFloat = 12
    static let maximumBoardSide: CGFloat = 680
    static let minimumBoardSide: CGFloat = 220
    static let utilityHeaderHeight: CGFloat = 44
    static let hudHeight: CGFloat = 90
    static let headerToHUDSpacing: CGFloat = 8
    static let minimumBoardTopSpacing: CGFloat = 8
    static let maximumAdditionalBoardTopSpacing: CGFloat = 44
    static let boardToSpeedBarSpacing: CGFloat = 14
    static let speedBarHeight: CGFloat = 50
    static let bottomClearance: CGFloat = 4

    static func reservedHeight(hasPet _: Bool) -> CGFloat {
        utilityHeaderHeight
            + headerToHUDSpacing
            + hudHeight
            + minimumBoardTopSpacing
            + boardToSpeedBarSpacing
            + speedBarHeight
            + footerLift
            + bottomClearance
    }

    static func resolve(
        availableSize: CGSize,
        hasPet: Bool
    ) -> GameplayLayoutPlan {
        let boardWidth = min(
            max(0, availableSize.width - horizontalInset * 2),
            maximumBoardSide
        )
        let boardSide = min(
            boardWidth,
            max(
                minimumBoardSide,
                availableSize.height - reservedHeight(hasPet: hasPet)
            )
        )
        let remainingHeight = max(
            0,
            availableSize.height - reservedHeight(hasPet: hasPet) - boardSide
        )
        let additionalTopSpacing = min(
            maximumAdditionalBoardTopSpacing,
            remainingHeight * 0.30
        )

        return GameplayLayoutPlan(
            boardSide: boardSide,
            boardTopSpacing: minimumBoardTopSpacing + additionalTopSpacing,
            boardToSpeedBarSpacing: boardToSpeedBarSpacing
        )
    }
}

struct SpeedBarPresentation: Equatable, Hashable, Sendable {
    static let maximumMultiplier = 5
    static let completedTierOpacity = 0.60

    let multiplier: Int
    let completedOpacity: Double
    let activeFraction: CGFloat

    static func resolve(
        multiplier: Int,
        progress: Int,
        target: Int
    ) -> Self {
        let safeMultiplier = max(1, multiplier)
        let safeTarget = max(1, target)
        let activeFraction =
            safeMultiplier >= maximumMultiplier
            ? CGFloat(1)
            : min(1, max(0, CGFloat(progress) / CGFloat(safeTarget)))

        return Self(
            multiplier: safeMultiplier,
            completedOpacity: safeMultiplier > 1 ? completedTierOpacity : 0,
            activeFraction: activeFraction
        )
    }
}

struct SpeedBarTransitionPlan: Equatable, Sendable {
    let completesOutgoingTier: Bool
    let outgoingCompletionFraction: CGFloat
    let carriedActiveFraction: CGFloat

    static func resolve(
        from current: SpeedBarPresentation,
        to next: SpeedBarPresentation
    ) -> Self {
        let promotes = next.multiplier > current.multiplier
        return Self(
            completesOutgoingTier: promotes,
            outgoingCompletionFraction: promotes ? 1 : next.activeFraction,
            carriedActiveFraction: next.activeFraction
        )
    }
}

private struct SpeedBarLayeredFill: View {
    let presentation: SpeedBarPresentation
    let isPixel: Bool

    @State private var renderedMultiplier: Int
    @State private var renderedCompletedOpacity: Double
    @State private var renderedActiveFraction: CGFloat
    @State private var renderedActiveOpacity: Double

    init(presentation: SpeedBarPresentation, isPixel: Bool) {
        self.presentation = presentation
        self.isPixel = isPixel
        _renderedMultiplier = State(initialValue: presentation.multiplier)
        _renderedCompletedOpacity = State(initialValue: presentation.completedOpacity)
        _renderedActiveFraction = State(initialValue: presentation.activeFraction)
        _renderedActiveOpacity = State(initialValue: 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let shape = isPixel ? AnyShape(Rectangle()) : AnyShape(Capsule())

            ZStack(alignment: .leading) {
                if renderedCompletedOpacity > 0 {
                    shape
                        .fill(fillGradient)
                        .opacity(renderedCompletedOpacity)
                }

                shape
                    .fill(fillGradient)
                    .frame(width: proxy.size.width * renderedActiveFraction)
                    .clipShape(shape)
                    .opacity(renderedActiveOpacity)
            }
        }
        .task(id: presentation) {
            await animate(to: presentation)
        }
    }

    private var fillGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "#7657ff"),
                Color(hex: "#c658ff"),
                Color(hex: "#ffd84d"),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    @MainActor
    private func animate(to next: SpeedBarPresentation) async {
        let current = SpeedBarPresentation(
            multiplier: renderedMultiplier,
            completedOpacity: renderedCompletedOpacity,
            activeFraction: renderedActiveFraction
        )
        let plan = SpeedBarTransitionPlan.resolve(from: current, to: next)

        guard plan.completesOutgoingTier else {
            renderedMultiplier = next.multiplier
            withAnimation(.easeOut(duration: 0.35)) {
                renderedCompletedOpacity = next.completedOpacity
                renderedActiveFraction = next.activeFraction
                renderedActiveOpacity = 1
            }
            return
        }

        // A promotion can carry one Godlike step into the next tier. Finish
        // the outgoing fifth segment before dimming it, then reveal the carry
        // as a fresh bright layer instead of visually skipping completion.
        withAnimation(.easeOut(duration: 0.18)) {
            renderedActiveFraction = plan.outgoingCompletionFraction
            renderedActiveOpacity = 1
        }
        guard await waitForAnimation(milliseconds: 180) else { return }

        withAnimation(.easeInOut(duration: 0.16)) {
            renderedCompletedOpacity = next.completedOpacity
            renderedActiveOpacity = 0
        }
        guard await waitForAnimation(milliseconds: 160) else { return }

        withTransaction(Transaction(animation: nil)) {
            renderedMultiplier = next.multiplier
            renderedActiveFraction = 0
            renderedActiveOpacity = 1
        }

        withAnimation(.easeOut(duration: 0.28)) {
            renderedActiveFraction = plan.carriedActiveFraction
        }
    }

    private func waitForAnimation(milliseconds: Int) async -> Bool {
        do {
            try await Task.sleep(for: .milliseconds(milliseconds))
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}

enum GameplayFeedbackPresentation {
    static func isVisuallyHidden(_ feedback: String) -> Bool {
        if ["Get ready", "Missed", "Too slow", "Too early", "Wrong cell"].contains(feedback) {
            return true
        }
        if feedback.hasPrefix("Tap ") { return true }
        if feedback == "Hit" { return true }
        return ["Godlike •", "Perfect •", "Great •", "Good •"]
            .contains { feedback.hasPrefix($0) }
    }
}

enum GameplayOverlayLayer {
    static let boardShell = -10.0
    static let board = 0.0
    // The additive Disco bloom is deliberately above every active cell and
    // below all copy/feedback layers.
    static let discoGlow = 100.0
    static let boardShellBorder = 150.0
    static let announcement = 200.0
    static let tapFeedback = 310.0
}

enum GameplayCenterAnnouncement: Equatable, Sendable {
    case getReady
    case missed
    case tooSlow

    var text: String {
        switch self {
        case .getReady: "Get ready"
        case .missed: "Missed"
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
        if feedback == "Missed" { return .missed }
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
        Color(hex: GameplayAnnouncementStyle.toneHex(for: announcement, theme: theme))
    }
}

enum GameplayAnnouncementStyle {
    static func toneHex(
        for announcement: GameplayCenterAnnouncement,
        theme: ThemePalette
    ) -> String {
        switch announcement {
        case .getReady:
            theme.accent
        case .missed:
            theme.tileColors[1]
        case .tooSlow:
            theme.isLight ? "#a52b50" : "#ff6f9f"
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
