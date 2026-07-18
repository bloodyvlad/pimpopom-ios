import PimPoPomCore
import SwiftUI

struct WebModeTabs: View {
    @Binding var mode: GameMode
    let theme: ThemePalette

    var body: some View {
        HStack(spacing: 6) {
            tab(.arcade, title: "Arcade")
            tab(.zen, title: "Zen history")
        }
        .padding(4)
        .background(
            Color(hex: theme.surface).opacity(theme.isLight ? 0.72 : 0.82),
            in: RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 13)
        )
        .overlay {
            RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 13)
                .stroke(Color(hex: theme.foreground).opacity(0.12), lineWidth: theme.isPixel ? 2 : 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("leaderboard-mode-tabs")
    }

    private func tab(_ value: GameMode, title: String) -> some View {
        let selected = mode == value
        return Button {
            mode = value
        } label: {
            Text(title)
                .font(theme.appFont(size: 14, weight: .black, relativeTo: .body))
                .foregroundStyle(
                    selected
                        ? (value == .arcade ? Color(hex: "#fff7f8") : Color(hex: "#0b2d17"))
                        : Color(hex: theme.muted)
                )
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(
                    selected
                        ? (value == .arcade ? Color(hex: "#d83c82") : Color(hex: "#74c75b"))
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 10)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("leaderboard-mode-\(value.rawValue)")
    }
}

struct SpeedRatingDistributionView: View {
    let godlike: Int
    let perfect: Int
    let great: Int
    let good: Int
    let theme: ThemePalette
    var showsTitle = true
    var showsLegend = true

    init(
        counts: SpeedRatingCounts,
        theme: ThemePalette,
        showsTitle: Bool = true,
        showsLegend: Bool = true
    ) {
        godlike = counts.godlike
        perfect = counts.perfect
        great = counts.great
        good = counts.good
        self.theme = theme
        self.showsTitle = showsTitle
        self.showsLegend = showsLegend
    }

    init(
        ratings: [SpeedRating: Int],
        theme: ThemePalette,
        showsTitle: Bool = true,
        showsLegend: Bool = true
    ) {
        godlike = ratings[.godlike, default: 0]
        perfect = ratings[.perfect, default: 0]
        great = ratings[.great, default: 0]
        good = ratings[.good, default: 0]
        self.theme = theme
        self.showsTitle = showsTitle
        self.showsLegend = showsLegend
    }

    private var total: Int { max(0, godlike + perfect + great + good) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if showsTitle {
                Text("Reaction speed")
                    .font(theme.appFont(size: 13, weight: .black, relativeTo: .headline))
                    .foregroundStyle(Color(hex: theme.foreground))
            }

            GeometryReader { proxy in
                HStack(spacing: 0) {
                    segment(godlike, color: "#ffd84d", width: proxy.size.width)
                    segment(perfect, color: "#c68cff", width: proxy.size.width)
                    segment(great, color: "#67adff", width: proxy.size.width)
                    segment(good, color: "#72e995", width: proxy.size.width)
                }
                .background(Color(hex: theme.foreground).opacity(0.10))
                .clipShape(Capsule())
                .overlay { Capsule().stroke(Color(hex: theme.foreground).opacity(0.12), lineWidth: 1) }
            }
            .frame(height: 7)

            if showsLegend {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    legend("Godlike", value: godlike, color: "#ffd84d")
                    legend("Perfect", value: perfect, color: "#c68cff")
                    legend("Great", value: great, color: "#67adff")
                    legend("Good", value: good, color: "#72e995")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Godlike \(godlike), Perfect \(perfect), Great \(great), Good \(good)"
        )
        .accessibilityIdentifier("speed-rating-distribution")
    }

    private func segment(_ value: Int, color: String, width: CGFloat) -> some View {
        Color(hex: color)
            .frame(width: total == 0 ? 0 : width * CGFloat(value) / CGFloat(total))
    }

    private func legend(_ label: String, value: Int, color: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(Color(hex: color)).frame(width: 7, height: 7)
            Text("\(label) \(value)")
                .font(theme.appFont(size: 10, weight: .bold, relativeTo: .caption2))
                .foregroundStyle(Color(hex: theme.muted))
                .monospacedDigit()
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    let theme: ThemePalette

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 1) {
                Text("#\(entry.rank)")
                    .font(theme.appFont(size: 13, weight: .black, relativeTo: .headline))
                    .foregroundStyle(
                        entry.rank <= 3 ? Color(hex: "#ffd84d") : Color(hex: theme.muted)
                    )
                    .monospacedDigit()
                    .accessibilityIdentifier("leaderboard-entry-rank-\(entry.id)")

                Group {
                    if let petID = entry.petId {
                        PetCompanionView(petID: petID, size: 34, placement: .leaderboard)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 27, weight: .semibold))
                            .foregroundStyle(Color(hex: theme.muted).opacity(0.55))
                    }
                }
                .frame(
                    width: 42,
                    height: entry.petId == "pancake" ? 53 : 38,
                    alignment: .top
                )
                .accessibilityIdentifier("leaderboard-entry-pet-\(entry.id)")
            }
            .frame(width: 42)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(entry.name)
                        .font(theme.appFont(size: 14, weight: .black, relativeTo: .headline))
                        .foregroundStyle(Color(hex: theme.foreground))
                        .lineLimit(1)
                    if entry.isCurrentPlayer {
                        badge("YOU", color: theme.accent)
                    }
                }

                SpeedRatingDistributionView(
                    counts: entry.speedRatings,
                    theme: theme,
                    showsTitle: false,
                    showsLegend: false
                )

                Text("\(entry.hits) taps · \(entry.dodges) dodges · \(formatDuration(entry.survivalMs))")
                    .font(theme.appFont(size: 9, weight: .bold, relativeTo: .caption2))
                    .foregroundStyle(Color(hex: theme.muted))
                    .monospacedDigit()
                    .lineLimit(1)

                Text(reactionCopy)
                    .font(theme.appFont(size: 9, weight: .medium, relativeTo: .caption2))
                    .foregroundStyle(Color(hex: theme.muted).opacity(0.88))
                    .monospacedDigit()
                    .lineLimit(1)

                Text(
                    "Godlike \(entry.speedRatings.godlike) · Perfect \(entry.speedRatings.perfect) · Great \(entry.speedRatings.great) · Good \(entry.speedRatings.good)"
                )
                .font(theme.appFont(size: 8, weight: .medium, relativeTo: .caption2))
                .foregroundStyle(Color(hex: theme.muted).opacity(0.78))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(0)

            VStack(alignment: .trailing, spacing: 1) {
                Text("SCORE")
                    .font(theme.appFont(size: 8, weight: .black, relativeTo: .caption2))
                    .tracking(theme.isPixel ? 0 : 0.45)
                    .foregroundStyle(Color(hex: theme.muted))

                Text(entry.score.formatted())
                    .font(theme.appFont(size: 16, weight: .black, relativeTo: .headline))
                    .foregroundStyle(Color(hex: theme.accent))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(minWidth: 64, alignment: .trailing)
            .layoutPriority(2)
            .padding(.top, 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Score \(entry.score)")
            .accessibilityIdentifier("leaderboard-entry-score-\(entry.id)")
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 62)
        .background(
            entry.isCurrentPlayer
                ? Color(hex: theme.accent).opacity(theme.isLight ? 0.13 : 0.17)
                : Color(hex: theme.surface).opacity(theme.isLight ? 0.79 : 0.84),
            in: RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 12)
        )
        .overlay {
            RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 12)
                .stroke(
                    entry.isCurrentPlayer
                        ? Color(hex: theme.accent).opacity(0.62)
                        : Color(hex: theme.foreground).opacity(0.10),
                    lineWidth: theme.isPixel ? 2 : 1
                )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("leaderboard-entry-\(entry.id)")
    }

    private var reactionCopy: String {
        let fastest = entry.fastestReactionMs.map { "\($0) ms fastest" } ?? "No fastest tap"
        let average = entry.averageReactionMs.map { "\($0) ms avg" } ?? "No average"
        return "\(fastest) · \(average)"
    }

    private func badge(_ text: String, color: String) -> some View {
        Text(text)
            .font(theme.appFont(size: 7, weight: .black, relativeTo: .caption2))
            .foregroundStyle(Color(hex: color))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color(hex: color).opacity(0.12), in: Capsule())
            .overlay { Capsule().stroke(Color(hex: color).opacity(0.48), lineWidth: 1) }
    }

    private func formatDuration(_ milliseconds: Int) -> String {
        let seconds = max(0, milliseconds / 1_000)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct LeaderboardRankGapView: View {
    let skipped: Int
    let theme: ThemePalette

    var body: some View {
        HStack(spacing: 7) {
            Rectangle().fill(Color(hex: theme.muted).opacity(0.22)).frame(height: 1)
            Text(skipped == 1 ? "1 result" : "\(skipped) results")
                .font(theme.appFont(size: 9, weight: .bold, relativeTo: .caption2))
                .foregroundStyle(Color(hex: theme.muted))
            Rectangle().fill(Color(hex: theme.muted).opacity(0.22)).frame(height: 1)
        }
        .padding(.vertical, 1)
        .accessibilityLabel("\(skipped) leaderboard results omitted")
    }
}
