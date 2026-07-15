import PimPoPomCore
import SpriteKit
import SwiftUI

struct GameView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var backend: BackendClient
    @StateObject private var coordinator: GameCoordinator
    @State private var runTicket: RunTicket?
    @State private var preparing = true
    @State private var runStatus = ""
    @State private var submissionStarted = false
    @State private var submissionFailed = false
    @State private var preparationGeneration = 0

    init(mode: GameMode) {
        _coordinator = StateObject(wrappedValue: GameCoordinator(mode: mode))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.05, blue: 0.11), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                hud
                targetPrompt
                responseProgress

                SpriteView(scene: coordinator.scene, options: [.ignoresSiblingOrder])
                    .aspectRatio(1, contentMode: .fit)
                    .background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 22))
                    .accessibilityLabel("Reaction board")
                    .accessibilityIdentifier("reaction-board")

                Text(coordinator.feedback)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.76))
                    .frame(height: 22)
                    .accessibilityIdentifier("game-feedback")

                if coordinator.mode == .zen {
                    Button("End run") { coordinator.endZenRun() }
                        .buttonStyle(.bordered)
                        .tint(.white.opacity(0.8))
                        .accessibilityIdentifier("end-zen-run")
                }

                Spacer(minLength: 0)
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
                    .background(Color.black.opacity(0.96))
            }
        }
        .navigationTitle(coordinator.mode.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(submissionStarted)
        .toolbarBackground(Color(red: 0.02, green: 0.05, blue: 0.11), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await prepareAndStart() }
        .onDisappear {
            preparationGeneration += 1
            coordinator.stop()
            abandonTicketIfNeeded()
        }
        .onChange(of: coordinator.isFinished) { _, finished in
            if finished { submitRankedRunIfNeeded() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                preparationGeneration += 1
                abandonTicketIfNeeded()
                coordinator.abandonForBackground()
            } else if preparing {
                Task { await prepareAndStart() }
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
        .foregroundStyle(Color(hex: coordinator.snapshot.playerColor.ink))
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Color(hex: coordinator.snapshot.playerColor.value), in: Capsule())
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
            .foregroundStyle(.white.opacity(0.72))

            HStack(spacing: 5) {
                ForEach(0..<coordinator.snapshot.streakTarget, id: \.self) { index in
                    Capsule()
                        .fill(index < coordinator.snapshot.streakProgress ? Color.cyan : .white.opacity(0.12))
                        .frame(height: 7)
                }
            }
        }
    }

    private var adPlaceholder: some View {
        Text("Ads disabled · internal alpha")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.42))
            .frame(maxWidth: .infinity, minHeight: 26)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
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
                    .foregroundStyle(.cyan)
                Text(
                    "\(coordinator.snapshot.hits) hits · \(coordinator.snapshot.misses) misses · \(coordinator.snapshot.dodges) dodges"
                )
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.white.opacity(0.72))
                Text("\(formatDuration(coordinator.snapshot.elapsedMilliseconds)) elapsed")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.72))

                if coordinator.snapshot.hits > 0 {
                    Text(reactionSummary)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.72))
                    Text(ratingSummary)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                }

                if !runStatus.isEmpty {
                    Text(runStatus)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.yellow)
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
                    .tint(.cyan)
                    .foregroundStyle(.black)
                    .disabled(submissionStarted)
                Button("Main menu") { dismiss() }
                    .buttonStyle(.bordered)
                    .disabled(submissionStarted)
            }
            .foregroundStyle(.white)
            .padding(22)
            .frame(maxWidth: 330)
            .background(Color(red: 0.05, green: 0.08, blue: 0.14), in: RoundedRectangle(cornerRadius: 28))
        }
    }

    private var responseTint: Color {
        let progress = coordinator.snapshot.reactionProgress ?? 0
        return progress > 0.55 ? .cyan : (progress > 0.25 ? .yellow : .pink)
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
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
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
