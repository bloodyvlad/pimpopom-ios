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
    private var visibleResponse: LeaderboardResponse? {
        response?.mode == mode.rawValue ? response : nil
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

                WebModeTabs(mode: $mode, theme: palette)

                if let response = visibleResponse {
                    positionStrip(response)
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
        if let response = visibleResponse, !response.entries.isEmpty {
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

    private func positionStrip(_ response: LeaderboardResponse) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(response.playerRank == nil ? "RANKED RESULTS" : "YOUR BEST POSITION")
                    .font(palette.appFont(size: 8, weight: .black, relativeTo: .caption2))
                    .tracking(0.75)
                    .foregroundStyle(Color(hex: palette.muted))
                Text(response.playerRank.map { "#\($0)" } ?? "\(response.totalEntries)")
                    .font(palette.appFont(size: 20, weight: .black, relativeTo: .title3))
                    .foregroundStyle(Color(hex: palette.accent))
                    .monospacedDigit()
            }
            Spacer()
            if let percent = response.topPercent {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("TOP RESULTS")
                        .font(palette.appFont(size: 8, weight: .black, relativeTo: .caption2))
                        .tracking(0.75)
                        .foregroundStyle(Color(hex: palette.muted))
                    Text("\(percent)%")
                        .font(palette.appFont(size: 20, weight: .black, relativeTo: .title3))
                        .foregroundStyle(Color(hex: palette.accent))
                        .monospacedDigit()
                }
            } else {
                Text("\(response.totalEntries) total")
                    .font(palette.appFont(size: 11, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(Color(hex: palette.muted))
            }
        }
        .webCardStyle(theme: palette, selectedAccent: Color(hex: palette.accent), padding: 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("leaderboard-position")
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
}
