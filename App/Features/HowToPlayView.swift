import PimPoPomCore
import SwiftUI

struct HowToPlayView: View {
    @EnvironmentObject private var cosmetics: CosmeticsController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var practice: HowToPlayPractice
    @State private var doNotShowAgain: Bool

    let completionTitle: String
    let onFinish: (Bool) -> Void

    init(
        mode: HowToPlayMode, capabilities: HowToPlayCapabilities = .current,
        doNotShowAgain: Bool = false, completionTitle: String = "Let's play",
        onFinish: @escaping (Bool) -> Void
    ) {
        _practice = State(initialValue: HowToPlayPractice(mode: mode, capabilities: capabilities))
        _doNotShowAgain = State(initialValue: doNotShowAgain)
        self.completionTitle = completionTitle
        self.onFinish = onFinish
    }

    private var theme: ThemePalette { cosmetics.theme }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: theme)
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("How to play · \(practice.mode.title)")
                            .font(theme.appFont(size: 18, weight: .black, relativeTo: .headline))
                        Text("PRACTICE ONLY · No timers or rewards")
                            .font(theme.appFont(size: 10, weight: .bold, relativeTo: .caption))
                            .foregroundStyle(Color(hex: theme.muted))
                    }
                    Spacer(minLength: 8)
                    Button("Skip") { onFinish(doNotShowAgain) }
                        .buttonStyle(WebSecondaryButtonStyle(theme: theme, minimumHeight: 44))
                        .frame(width: 60)
                        .accessibilityIdentifier("tutorial-skip")
                }
                .padding(.horizontal, 14)

                ScrollViewReader { scroll in
                    ScrollView {
                        VStack(spacing: 12) {
                            HowToPlayInstruction(practice: practice, theme: theme)
                                .id("tutorial-step-top")
                            HowToPlayHUD(practice: practice, theme: theme)
                            if practice.step == .rewards || (practice.step == .competition && practice.mode == .arcade)
                            {
                                HowToPlayRewardCard(practice: practice, theme: theme)
                            } else {
                                HowToPlayBoard(practice: practice, theme: theme) { practice.tap(cell: $0) }
                                if practice.mode == .multiplayer, practice.step == .competition {
                                    HowToPlayCompetitors(theme: theme, highlighted: true)
                                }
                            }
                            HowToPlaySpeedBar(practice: practice, theme: theme)
                            if let feedback = practice.feedback {
                                Text(feedback)
                                    .font(theme.appFont(size: 13, weight: .bold, relativeTo: .subheadline))
                                    .foregroundStyle(Color(hex: theme.chromeAccent))
                                    .multilineTextAlignment(.center)
                                    .accessibilityIdentifier("tutorial-feedback")
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: 440)
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: practice.step) {
                        // No automatic progression or timed spotlight; Reduce Motion stays still.
                        if reduceMotion {
                            scroll.scrollTo("tutorial-step-top", anchor: .top)
                        } else {
                            withAnimation(.easeOut(duration: 0.15)) {
                                scroll.scrollTo("tutorial-step-top", anchor: .top)
                            }
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
        .foregroundStyle(Color(hex: theme.foreground))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                Toggle("Do not show next time", isOn: $doNotShowAgain)
                    .font(theme.appFont(size: 13, weight: .bold, relativeTo: .subheadline))
                    .tint(Color(hex: theme.chromeAccent))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("tutorial-remember")
                Button(practice.isLastStep ? completionTitle : "Next") {
                    if practice.isLastStep { onFinish(doNotShowAgain) } else { practice.advance() }
                }
                .buttonStyle(
                    WebSecondaryButtonStyle(theme: theme, accent: Color(hex: theme.chromeAccent), minimumHeight: 44)
                )
                .disabled(!practice.canAdvance)
                .accessibilityHint(
                    practice.canAdvance ? "Continue the tutorial" : "Complete the highlighted practice tap first"
                )
                .accessibilityIdentifier("tutorial-next")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: 440)
            .background(Color(hex: theme.backgroundBottom))
        }
        .navigationTitle("How to play")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("tutorial-\(practice.mode.rawValue)")
    }
}

private struct HowToPlayInstruction: View {
    let practice: HowToPlayPractice
    let theme: ThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("STEP \(practice.step.rawValue + 1) OF \(HowToPlayStep.allCases.count)")
                .font(theme.appFont(size: 10, weight: .bold, relativeTo: .caption))
                .foregroundStyle(Color(hex: theme.chromeAccent))
                .accessibilityIdentifier("tutorial-step")
            Text(practice.title)
                .font(theme.appFont(size: 19, weight: .black, relativeTo: .headline))
                .accessibilityAddTraits(.isHeader)
            Text(practice.instruction)
                .font(theme.appFont(size: 14, weight: .medium, relativeTo: .body))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HowToPlayHUD: View {
    let practice: HowToPlayPractice
    let theme: ThemePalette

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("EXAMPLE POINTS")
                    .font(theme.appFont(size: 9, weight: .bold, relativeTo: .caption))
                Text("\(practice.exampleScore)")
                    .font(theme.appFont(size: 20, weight: .black, relativeTo: .title3))
                GameplayLivesView(remaining: 3, theme: theme)
            }
            Spacer(minLength: 0)
            VStack(spacing: 4) {
                Text("YOUR COLOR")
                    .font(theme.appFont(size: 10, weight: .bold, relativeTo: .caption))
                HStack(spacing: 6) {
                    GameCellPreview(
                        theme: theme, colorIndex: practice.colorIndex, glyph: gameColors[practice.colorIndex].glyph,
                        showsGlyphs: true, isTarget: true, textureSeed: 0,
                        glyphScale: GameCellVisualMetrics.previewGlyphScale
                    )
                    .frame(width: 36, height: 36)
                    Text(gameColors[practice.colorIndex].name)
                        .font(theme.appFont(size: 16, weight: .black, relativeTo: .subheadline))
                }
            }
            .padding(8)
            .background(theme.color(at: practice.colorIndex).opacity(0.15))
            .overlay {
                RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 10)
                    .stroke(theme.color(at: practice.colorIndex), lineWidth: 3)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Your color: \(gameColors[practice.colorIndex].name)")
            .accessibilityIdentifier("tutorial-your-color")
        }
        .webCardStyle(theme: theme, padding: 10)
    }
}

private struct HowToPlayBoard: View {
    let practice: HowToPlayPractice
    let theme: ThemePalette
    let onTap: (Int) -> Void

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(minimum: 44), spacing: 6), count: practice.gridDimension)
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<(practice.gridDimension * practice.gridDimension), id: \.self) { cell in
                HowToPlayCell(tile: practice.tile(at: cell), cell: cell, colorIndex: practice.colorIndex, theme: theme)
                {
                    onTap(cell)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: practice.gridDimension == 1 ? 150 : 280)
        .webCardStyle(theme: theme, selectedAccent: Color(hex: theme.chromeAccent), padding: 4)
        .accessibilityIdentifier("tutorial-board")
    }
}

private struct HowToPlayCell: View {
    let tile: HowToPlayTile
    let cell: Int
    let colorIndex: Int
    let theme: ThemePalette
    let onTap: () -> Void

    private var label: String {
        switch tile {
        case .target: "Your color target, \(gameColors[colorIndex].name)"
        case .otherColor: "Other color, wait for your color"
        case .heart: "Heart, restores a life"
        case .clock: "Rewind clock, slows the pace"
        case .empty: "Empty square"
        }
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 10)
                    .fill(Color(hex: theme.surface))
                switch tile {
                case .target, .otherColor:
                    let index = tile == .target ? colorIndex : 4
                    GameCellPreview(
                        theme: theme, colorIndex: index, glyph: gameColors[index].glyph,
                        showsGlyphs: true, isTarget: tile == .target, textureSeed: cell,
                        glyphScale: GameCellVisualMetrics.previewGlyphScale)
                case .heart, .clock:
                    GameplayPickupIcon(symbol: tile == .heart ? .heart : .clock, theme: theme)
                        .padding(10)
                case .empty:
                    Color.clear
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(minWidth: 44, minHeight: 44)
            .overlay {
                RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 10)
                    .stroke(
                        Color(hex: theme.chromeAccent).opacity(tile == .empty ? 0.2 : 1),
                        lineWidth: tile == .empty ? 1 : 3)
            }
        }
        .buttonStyle(.plain)
        .disabled(tile == .empty)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityIdentifier("tutorial-cell-\(cell)")
    }
}

private struct HowToPlaySpeedBar: View {
    let practice: HowToPlayPractice
    let theme: ThemePalette

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text("SPEED BAR")
                    .font(theme.appFont(size: 11, weight: .black, relativeTo: .caption))
                ProgressView(value: practice.speedProgress)
                    .tint(Color(hex: theme.chromeAccent))
            }
            Text("\(practice.multiplier)×")
                .font(theme.appFont(size: 24, weight: .black, relativeTo: .title2))
        }
        .webCardStyle(
            theme: theme, selectedAccent: practice.step == .speedBar ? Color(hex: theme.chromeAccent) : nil, padding: 10
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Speed Bar, example multiplier \(practice.multiplier)")
        .accessibilityIdentifier("tutorial-speed-bar")
    }
}

private struct HowToPlayCompetitors: View {
    let theme: ThemePalette
    let highlighted: Bool

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { seat in
                VStack(spacing: 3) {
                    Text(seat == 0 ? "YOU" : "P\(seat + 1)")
                    Text("\(1_000 - seat * 100)")
                    GameplayLivesView(remaining: 3 - seat % 2, theme: theme)
                }
                .font(theme.appFont(size: 10, weight: .bold, relativeTo: .caption))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(theme.color(at: seat + 2).opacity(0.25))
                .accessibilityElement(children: .combine)
            }
        }
        .webCardStyle(theme: theme, selectedAccent: highlighted ? Color(hex: theme.chromeAccent) : nil, padding: 6)
        .accessibilityIdentifier("tutorial-competitors")
    }
}

private struct HowToPlayRewardCard: View {
    let practice: HowToPlayPractice
    let theme: ThemePalette

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: practice.step == .competition ? "trophy.fill" : "star.circle.fill")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(Color(hex: theme.achievementsAccent))
            Text(practice.step == .competition ? "YOUR NEXT PERSONAL BEST" : "READY TO PLAY?")
                .font(theme.appFont(size: 16, weight: .black, relativeTo: .headline))
            Text("This was a safe practice example. Nothing here is saved to your account.")
                .font(theme.appFont(size: 13, weight: .medium, relativeTo: .body))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .webCardStyle(theme: theme, selectedAccent: Color(hex: theme.achievementsAccent), padding: 16)
    }
}
