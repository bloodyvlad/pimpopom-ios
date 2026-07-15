import PimPoPomCore
import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject private var backend: BackendClient
    @EnvironmentObject private var cosmetics: CosmeticsController
    @State private var mode = GameMode.arcade
    @State private var response: LeaderboardResponse?
    @State private var error: String?
    @State private var loading = false
    @State private var loadGeneration = 0

    private var palette: ThemePalette { cosmetics.theme }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: palette)
            VStack(spacing: 12) {
                Picker("Mode", selection: $mode) {
                    Text("Arcade").tag(GameMode.arcade)
                    Text("Zen history").tag(GameMode.zen)
                }
                .pickerStyle(.segmented)

                if loading, response == nil {
                    Spacer()
                    ProgressView("Loading Season 1")
                        .foregroundStyle(Color(hex: palette.foreground))
                    Spacer()
                } else if let response {
                    ScrollView {
                        LazyVStack(spacing: 9) {
                            ForEach(response.entries) { entry in
                                leaderboardRow(entry)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    if let rank = response.playerRank {
                        Text("Your best: #\(rank) of \(response.totalEntries)")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Color(hex: palette.accent))
                    } else {
                        Text("\(response.totalEntries) ranked results")
                            .font(.footnote)
                            .foregroundStyle(Color(hex: palette.muted))
                    }
                } else {
                    Spacer()
                    Text(error ?? "No leaderboard results")
                        .foregroundStyle(Color(hex: palette.muted))
                        .multilineTextAlignment(.center)
                    Button("Try again") { Task { await load() } }
                        .buttonStyle(.bordered)
                    Spacer()
                }
            }
            .padding(16)
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: mode) { await load() }
        .refreshable { await load() }
    }

    private func leaderboardRow(_ entry: LeaderboardEntry) -> some View {
        HStack(spacing: 12) {
            Text("#\(entry.rank)")
                .font(.headline.monospacedDigit().weight(.black))
                .foregroundStyle(entry.rank <= 3 ? .yellow : Color(hex: palette.muted))
                .frame(width: 40, alignment: .leading)
            if let petID = entry.petId {
                PetCompanionView(petID: petID, size: 38, includesHabitat: true, animated: false)
                    .frame(width: 48)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.name).font(.headline)
                    if entry.verification == "verified" {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(Color(hex: palette.accent))
                    }
                }
                Text("\(entry.hits) hits · \(entry.dodges) dodges · \(formatDuration(entry.survivalMs))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color(hex: palette.muted))
            }
            Spacer()
            Text(entry.score.formatted())
                .font(.headline.monospacedDigit().weight(.bold))
                .foregroundStyle(Color(hex: palette.accent))
        }
        .foregroundStyle(Color(hex: palette.foreground))
        .padding(13)
        .background(
            entry.isCurrentPlayer
                ? Color(hex: palette.accent).opacity(0.16)
                : Color(hex: palette.surface).opacity(0.80),
            in: RoundedRectangle(cornerRadius: palette.isPixel ? 0 : 14)
        )
    }

    private func load() async {
        let requestedMode = mode
        loadGeneration += 1
        let generation = loadGeneration
        loading = true
        defer {
            if generation == loadGeneration { loading = false }
        }
        do {
            let loaded = try await backend.loadLeaderboard(mode: requestedMode)
            guard !Task.isCancelled,
                mode == requestedMode,
                generation == loadGeneration
            else { return }
            response = loaded
            error = nil
        } catch {
            guard !Task.isCancelled,
                mode == requestedMode,
                generation == loadGeneration
            else { return }
            self.error = error.localizedDescription
            response = nil
        }
    }

    private func formatDuration(_ milliseconds: Int) -> String {
        let seconds = milliseconds / 1_000
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
