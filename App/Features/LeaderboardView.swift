import PimPoPomCore
import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject private var backend: BackendClient
    @EnvironmentObject private var cosmetics: CosmeticsController
    @State private var mode: LeaderboardMode
    @State private var response: LeaderboardResponse?
    @State private var multiplayerResponse: MultiplayerLeaderboardResponse?
    @State private var error: String?
    @State private var loading = false
    @State private var loadGeneration = 0

    init(initialMode: LeaderboardMode = .arcade) {
        _mode = State(initialValue: initialMode)
    }

    private var palette: ThemePalette { cosmetics.theme }
    private var visibleResponse: LeaderboardResponse? {
        guard let gameMode = mode.gameMode else { return nil }
        return response?.mode == gameMode.rawValue ? response : nil
    }

    private var visibleMultiplayerResponse: MultiplayerLeaderboardResponse? {
        mode == .multiplayer ? multiplayerResponse : nil
    }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: palette)

            VStack(spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Leaderboard")
                            .font(palette.appFont(size: 25, weight: .black, relativeTo: .title))
                        Text("ALL RESULTS")
                            .font(palette.appFont(size: 9, weight: .black, relativeTo: .caption2))
                            .tracking(1.1)
                            .foregroundStyle(Color(hex: palette.muted))
                    }
                    Spacer()
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 25, weight: .black))
                        .foregroundStyle(Color(hex: "#ffd84d"))
                        .shadow(color: Color(hex: "#ffd84d").opacity(0.42), radius: palette.isPixel ? 0 : 8)
                }

                LeaderboardModeTabs(mode: $mode, theme: palette)

                if let summary = positionSummary {
                    positionStrip(summary)
                }

                ZStack {
                    leaderboardContent

                    if loading {
                        WebLoadingOverlay(theme: palette, label: "Loading leaderboard")
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .foregroundStyle(Color(hex: palette.foreground))
            .padding(14)
            .frame(maxWidth: 620, maxHeight: .infinity)
            .webCardStyle(theme: palette, padding: 14)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Leaderboard")
                    .font(palette.appFont(size: 19, weight: .black, relativeTo: .headline))
                    .foregroundStyle(Color(hex: palette.foreground))
            }
        }
        .task(id: mode) { await load() }
    }

    @ViewBuilder
    private var leaderboardContent: some View {
        if mode == .multiplayer {
            multiplayerLeaderboardContent
        } else if let response = visibleResponse, !response.entries.isEmpty {
            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(Array(response.entries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 {
                            let previousRank = response.entries[index - 1].rank
                            let skipped = entry.rank - previousRank - 1
                            if skipped > 0 {
                                LeaderboardRankGapView(skipped: skipped, theme: palette)
                            }
                        }
                        LeaderboardRowView(entry: entry, theme: palette)
                    }
                }
                .padding(.vertical, 2)
            }
            .refreshable { await load() }
            .accessibilityIdentifier("leaderboard-results")
        } else if !loading {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: error == nil ? "flag.checkered" : "wifi.exclamationmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color(hex: palette.accent))
                Text(error ?? "No leaderboard results yet")
                    .font(palette.appFont(size: 15, weight: .bold, relativeTo: .body))
                    .foregroundStyle(Color(hex: palette.muted))
                    .multilineTextAlignment(.center)
                Button("Try again") { Task { await load() } }
                    .buttonStyle(
                        WebSecondaryButtonStyle(
                            theme: palette,
                            accent: Color(hex: palette.accent),
                            minimumHeight: 42
                        )
                    )
                    .frame(maxWidth: 180)
                Spacer()
            }
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var multiplayerLeaderboardContent: some View {
        if let response = visibleMultiplayerResponse, !response.entries.isEmpty {
            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(response.entries) { entry in
                        MultiplayerLeaderboardRowView(entry: entry, theme: palette)
                    }
                }
                .padding(.vertical, 2)
            }
            .refreshable { await load() }
            .accessibilityIdentifier("multiplayer-leaderboard-results")
        } else if !loading {
            emptyState(
                icon: error == nil ? "person.3.fill" : "wifi.exclamationmark",
                message: error ?? "No multiplayer results yet"
            )
        } else {
            Color.clear
        }
    }

    private struct PositionSummary {
        let playerRank: Int?
        let totalEntries: Int
        let topPercent: Int?
    }

    private var positionSummary: PositionSummary? {
        if let response = visibleMultiplayerResponse {
            return PositionSummary(
                playerRank: response.playerRank,
                totalEntries: response.totalEntries,
                topPercent: response.topPercent
            )
        }
        if let response = visibleResponse {
            return PositionSummary(
                playerRank: response.playerRank,
                totalEntries: response.totalEntries,
                topPercent: response.topPercent
            )
        }
        return nil
    }

    private func positionStrip(_ summary: PositionSummary) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(summary.playerRank == nil ? "RANKED RESULTS" : "YOUR BEST POSITION")
                    .font(palette.appFont(size: 8, weight: .black, relativeTo: .caption2))
                    .tracking(0.75)
                    .foregroundStyle(Color(hex: palette.muted))
                Text(summary.playerRank.map { "#\($0)" } ?? "\(summary.totalEntries)")
                    .font(palette.appFont(size: 20, weight: .black, relativeTo: .title3))
                    .foregroundStyle(positionAccent)
                    .monospacedDigit()
            }
            Spacer()
            if let percent = summary.topPercent {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("TOP RESULTS")
                        .font(palette.appFont(size: 8, weight: .black, relativeTo: .caption2))
                        .tracking(0.75)
                        .foregroundStyle(Color(hex: palette.muted))
                    Text("\(percent)%")
                        .font(palette.appFont(size: 20, weight: .black, relativeTo: .title3))
                        .foregroundStyle(positionAccent)
                        .monospacedDigit()
                }
            } else {
                Text("\(summary.totalEntries) total")
                    .font(palette.appFont(size: 11, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(Color(hex: palette.muted))
            }
        }
        .webCardStyle(theme: palette, selectedAccent: positionAccent, padding: 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("leaderboard-position")
    }

    private var positionAccent: Color {
        Color(hex: mode == .multiplayer ? palette.chromeAccent : palette.accent)
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(positionAccent)
            Text(message)
                .font(palette.appFont(size: 15, weight: .bold, relativeTo: .body))
                .foregroundStyle(Color(hex: palette.muted))
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await load() } }
                .buttonStyle(
                    WebSecondaryButtonStyle(
                        theme: palette,
                        accent: positionAccent,
                        minimumHeight: 42
                    )
                )
                .frame(maxWidth: 180)
            Spacer()
        }
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
            if let gameMode = requestedMode.gameMode {
                let loaded = try await backend.loadLeaderboard(mode: gameMode)
                guard !Task.isCancelled,
                    mode == requestedMode,
                    generation == loadGeneration
                else { return }
                response = loaded
            } else {
                let loaded = try await backend.loadMultiplayerLeaderboard()
                guard !Task.isCancelled,
                    mode == requestedMode,
                    generation == loadGeneration
                else { return }
                multiplayerResponse = loaded
            }
            error = nil
        } catch {
            guard !Task.isCancelled,
                mode == requestedMode,
                generation == loadGeneration
            else { return }
            self.error = error.localizedDescription
            if requestedMode == .multiplayer {
                multiplayerResponse = nil
            } else {
                response = nil
            }
        }
    }
}
