import PimPoPomCore
import SpriteKit
import SwiftUI

struct GameView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var backend: BackendClient
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
    @State private var didFreezePresentation = false

    private var palette: ThemePalette { frozenTheme }

    init(mode: GameMode) {
        _coordinator = StateObject(wrappedValue: GameCoordinator(mode: mode))
    }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: palette)

            VStack(spacing: 10) {
                hud
                targetPrompt
                responseProgress

                SpriteView(scene: coordinator.scene, options: [.ignoresSiblingOrder])
                    .aspectRatio(1, contentMode: .fit)
                    .background(
                        Color(hex: palette.board).opacity(0.96),
                        in: RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 22)
                    )
                    .accessibilityLabel("Reaction board")
                    .accessibilityIdentifier("reaction-board")

                Text(coordinator.feedback)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(hex: palette.muted))
                    .frame(height: 22)
                    .accessibilityIdentifier("game-feedback")

                if coordinator.mode == .zen {
                    Button("End run") { coordinator.endZenRun() }
                        .buttonStyle(.bordered)
                        .tint(Color(hex: palette.foreground).opacity(0.8))
                        .accessibilityIdentifier("end-zen-run")
                }

                Spacer(minLength: 0)
                if let petID = frozenPetID {
                    PetCompanionView(petID: petID, size: 54, includesHabitat: false)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityIdentifier("gameplay-pet")
                }
                streakMeter
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 2)
            .frame(maxHeight: .infinity, alignment: .top)

            if coordinator.isFinished || coordinator.wasAbandoned {
                resultOverlay
            }

            if preparing {
                Color.black.opacity(0.72).ignoresSafeArea()
                ProgressView("Preparing \(coordinator.mode.displayName)…")
                    .tint(.cyan)
                    .foregroundStyle(.white)
                    .padding(22)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !preparing, !coordinator.isFinished, !coordinator.wasAbandoned {
                adPlaceholder
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color(hex: palette.backgroundBottom).opacity(0.96))
            }
        }
        .navigationTitle(coordinator.mode.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(submissionStarted)
        .toolbarBackground(Color(hex: palette.backgroundTop), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(palette.isLight ? .light : .dark, for: .navigationBar)
        .task {
            freezePresentationIfNeeded()
            coordinator.onSoundEvent = { event in
                switch event {
                case .correctTap(let hitNumber):
                    audio.playTap(hitNumber: hitNumber)
                case .lifeLoss:
                    audio.playLifeLoss()
                }
            }
            audio.setMusicContext(.gameplay)
            await prepareAndStart()
        }
        .onDisappear {
            preparationGeneration += 1
            coordinator.stop()
            coordinator.onSoundEvent = nil
            abandonTicketIfNeeded()
            audio.setMusicContext(.menu)
        }
        .onChange(of: coordinator.isFinished) { _, finished in
            if finished {
                audio.setMusicContext(.silent)
                submitRankedRunIfNeeded()
            }
        }
        .onChange(of: coordinator.wasAbandoned) { _, abandoned in
            if abandoned { audio.setMusicContext(.silent) }
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

    private var hud: some View {
        HStack(alignment: .top) {
            stat("Score", "\(coordinator.snapshot.points)", identifier: "game-score")
            Spacer()
            stat("Time", formatDuration(coordinator.snapshot.elapsedMilliseconds), identifier: "game-time")
            Spacer()
            stat(
                coordinator.mode == .arcade ? "Lives" : "Practice",
                coordinator.mode == .arcade
                    ? String(repeating: "● ", count: coordinator.snapshot.lives).trimmingCharacters(in: .whitespaces)
                    : "∞",
                identifier: "game-lives"
            )
        }
    }

    private var targetPrompt: some View {
        HStack(spacing: 9) {
            Text(coordinator.snapshot.playerColor.glyph)
                .font(.title2.weight(.black))
            Text(coordinator.snapshot.playerColor.name)
                .font(.headline.weight(.black))
        }
        .foregroundStyle(palette.promptInkColor(at: coordinator.snapshot.playerColorIndex))
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(palette.color(at: coordinator.snapshot.playerColorIndex), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Target color \(coordinator.snapshot.playerColor.name), symbol \(coordinator.snapshot.playerColor.glyph)")
    }

    @ViewBuilder
    private var responseProgress: some View {
        if coordinator.mode == .arcade {
            ProgressView(value: coordinator.snapshot.reactionProgress ?? 0)
                .tint(responseTint)
                .animation(.linear(duration: 0.03), value: coordinator.snapshot.reactionProgress)
        } else {
            Color.clear.frame(height: 4)
        }
    }

    private var streakMeter: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Speed streak")
                Spacer()
                Text("\(coordinator.snapshot.multiplier)×")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(Color(hex: palette.muted))

            HStack(spacing: 5) {
                ForEach(0..<coordinator.snapshot.streakTarget, id: \.self) { index in
                    Capsule()
                        .fill(
                            index < coordinator.snapshot.streakProgress
                                ? Color(hex: palette.accent)
                                : Color(hex: palette.foreground).opacity(0.12)
                        )
                        .frame(height: 7)
                }
            }
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

    private var responseTint: Color {
        let progress = coordinator.snapshot.reactionProgress ?? 0
        return progress > 0.55
            ? Color(hex: palette.accent)
            : (progress > 0.25 ? palette.color(at: 1) : palette.color(at: 2))
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

    private func freezePresentationIfNeeded() {
        guard !didFreezePresentation else { return }
        didFreezePresentation = true
        frozenTheme = cosmetics.theme
        frozenPetID = cosmetics.displayedPetID
        coordinator.applyTheme(frozenTheme.id)
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
