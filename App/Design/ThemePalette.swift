import PimPoPomCore
import SwiftUI

struct ThemePalette: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let backgroundTop: String
    let backgroundBottom: String
    let foreground: String
    let muted: String
    let surface: String
    let board: String
    let idleCell: String
    let accent: String
    let isLight: Bool
    let isPixel: Bool
    let tileColors: [String]

    var fontDesign: Font.Design { isPixel ? .monospaced : .rounded }
    var cornerRadius: CGFloat { isPixel ? 3 : 18 }

    func resolvedFontSize(_ size: CGFloat) -> CGFloat {
        isPixel ? size * 1.25 : size
    }

    var chromeAccent: String {
        switch id {
        case "light": "#087fa7"
        default: "#63efff"
        }
    }

    var achievementsAccent: String {
        switch id {
        case "disco": "#ffe66f"
        case "light": "#a66a00"
        case "pixel": "#ffe14f"
        default: "#ffd84d"
        }
    }

    var petsAccent: String {
        switch id {
        case "disco": "#ff68d6"
        case "light": "#c53868"
        case "pixel": "#ff5fc8"
        default: "#ff79ad"
        }
    }

    var themesAccent: String {
        switch id {
        case "disco": "#61f5ff"
        case "light": "#087fa7"
        default: "#63efff"
        }
    }

    func appFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        if isPixel {
            return .custom(
                "Jersey10-Regular",
                size: resolvedFontSize(size),
                relativeTo: textStyle
            )
        }
        return .system(size: size, weight: weight, design: .rounded)
    }

    func color(at index: Int) -> Color {
        Color(hex: tileColors[index % tileColors.count])
    }

    func uiColor(at index: Int) -> UIColor {
        UIColor(hexString: tileColors[index % tileColors.count])
    }

    func promptInkColor(at index: Int) -> Color {
        Color(hex: gameColors[index % gameColors.count].ink)
    }

    func cellInkColor(at index: Int) -> Color {
        isLight ? .white : promptInkColor(at: index)
    }

    func cellInkUIColor(at index: Int) -> UIColor {
        isLight ? .white : UIColor(hexString: gameColors[index % gameColors.count].ink)
    }

    static func resolve(_ id: String?) -> ThemePalette {
        all.first(where: { $0.id == id }) ?? classic
    }

    static let classic = ThemePalette(
        id: "classic",
        displayName: "Default",
        backgroundTop: "#101326",
        backgroundBottom: "#080a12",
        foreground: "#f7f8ff",
        muted: "#9da4bc",
        surface: "#191d30",
        board: "#0d1422",
        idleCell: "#121a29",
        accent: "#35e6df",
        isLight: false,
        isPixel: false,
        tileColors: ["#35e6df", "#ffd84d", "#ff5ba8", "#8ee85a", "#ff914d", "#a987ff"]
    )

    static let disco = ThemePalette(
        id: "disco",
        displayName: "Disco",
        backgroundTop: "#030404",
        backgroundBottom: "#030404",
        foreground: "#f7f8ff",
        muted: "#a8afb9",
        surface: "#0c0f16",
        board: "#07090d",
        idleCell: DiscoThemeTokens.idleCellHex,
        accent: "#ff86bc",
        isLight: false,
        isPixel: false,
        tileColors: DiscoThemeTokens.activeCellHexes
    )

    static let light = ThemePalette(
        id: "light",
        displayName: "Light",
        backgroundTop: "#bce9ff",
        backgroundBottom: "#eaf8ff",
        foreground: "#17263b",
        muted: "#5e7187",
        surface: "#ffffff",
        board: "#ffffff",
        idleCell: "#f5fbff",
        accent: "#087d9f",
        isLight: true,
        isPixel: false,
        tileColors: ["#00b8d9", "#f2bd14", "#ee3d8f", "#73c43d", "#f47b2a", "#a18ff0"]
    )

    static let pixel = ThemePalette(
        id: "pixel",
        displayName: "Pixel",
        backgroundTop: "#1a1635",
        backgroundBottom: "#0c0c1d",
        foreground: "#f7f5ff",
        muted: "#b0aed0",
        surface: "#14142b",
        board: "#0e1024",
        idleCell: "#1a1d38",
        accent: "#69e8ff",
        isLight: false,
        isPixel: true,
        tileColors: ["#18d7d0", "#ffd13d", "#ff4f9f", "#82dd48", "#ff7c35", "#9875ff"]
    )

    static let all: [ThemePalette] = [.classic, .disco, .light, .pixel]
}

struct AppThemeBackground: View {
    let theme: ThemePalette

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                backgroundBase(size: proxy.size)

                if theme.id == "classic" {
                    RadialGradient(
                        colors: [Color(hex: "#6651d6").opacity(0.30), .clear],
                        center: UnitPoint(x: 0.5, y: -0.10),
                        startRadius: 0,
                        endRadius: max(220, proxy.size.width * 0.72)
                    )
                } else if theme.id == "pixel" {
                    PixelGrid(spacing: 16, color: Color(hex: "#5fe5ff").opacity(0.07))
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func backgroundBase(size: CGSize) -> some View {
        if theme.id == "disco" {
            DiscoConcreteBackdrop(context: .screen)
                .frame(width: size.width, height: size.height)
                .clipped()
        } else if theme.id == "light" {
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "#bce9ff"), location: 0),
                    .init(color: Color(hex: "#eaf8ff"), location: 0.72),
                    .init(color: Color(hex: "#dff4ff"), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            LinearGradient(
                colors: [Color(hex: theme.backgroundTop), Color(hex: theme.backgroundBottom)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

}

struct DiscoConcreteBackdrop: View {
    enum Context {
        case screen
        case preview
    }

    let context: Context

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                Image("disco-concrete", bundle: .main)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .brightness(concreteBrightness)
                    .contrast(1.12)
                    .opacity(concreteOpacity)
                    .clipped()
                Image("disco-concrete-lights", bundle: .main)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .blendMode(.screen)
                    .saturation(1.42)
                    .contrast(1.08)
                    .opacity(reflectionOpacity)
                    .clipped()
                reflectedLight(
                    color: Color(hex: "#00d9ff"),
                    center: UnitPoint(x: 0.08, y: 0.10)
                )
                reflectedLight(
                    color: Color(hex: "#a65cff"),
                    center: UnitPoint(x: 0.92, y: 0.18)
                )
                reflectedLight(
                    color: Color(hex: "#ff537d"),
                    center: UnitPoint(x: 0.18, y: 0.72)
                )
                Image("disco-concrete", bundle: .main)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .brightness(0.10)
                    .contrast(1.35)
                    .blendMode(.overlay)
                    .opacity(textureOverlayOpacity)
                    .clipped()
                Color.black.opacity(blackVeilOpacity)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var concreteOpacity: Double {
        switch context {
        case .screen: 1.0
        case .preview: 0.92
        }
    }

    private var concreteBrightness: Double {
        switch context {
        case .screen: 0.08
        case .preview: 0.05
        }
    }

    private var fixedReflectionOpacity: Double {
        switch context {
        case .screen: 0.30
        case .preview: 0.24
        }
    }

    private var textureOverlayOpacity: Double {
        switch context {
        case .screen: 0.58
        case .preview: 0.52
        }
    }

    private func reflectedLight(color: Color, center: UnitPoint) -> some View {
        RadialGradient(
            colors: [color.opacity(fixedReflectionOpacity), .clear],
            center: center,
            startRadius: 0,
            endRadius: context == .screen ? 260 : 150
        )
        .blendMode(.screen)
    }

    private var reflectionOpacity: Double {
        switch context {
        case .screen: 0.82
        case .preview: 0.70
        }
    }

    private var blackVeilOpacity: Double {
        switch context {
        case .screen: 0.12
        case .preview: 0.18
        }
    }
}

struct PixelGrid: View {
    let spacing: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            for x in stride(from: CGFloat.zero, through: size.width, by: spacing) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: CGFloat.zero, through: size.height, by: spacing) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(color), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

enum DiscoThemeTokens {
    static let idleCellHex = "#0d0f12"
    static let cellBorderHex = "#4a5056"
    static let activeBorderHex = "#d9dde0"
    static let activeCellHexes = [
        "#65e9f1", "#ffe681", "#ff86bc", "#b2ee7c", "#ffb06f", "#c3a8ff",
    ]
    static let idleScratchOpacity = 0.16
    static let activeScratchOpacity = 0.34

    static func activeBorderColor(for color: UIColor) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return UIColor(hexString: activeBorderHex)
        }
        let whiteMix: CGFloat = 0.38
        return UIColor(
            red: red * (1 - whiteMix) + whiteMix,
            green: green * (1 - whiteMix) + whiteMix,
            blue: blue * (1 - whiteMix) + whiteMix,
            alpha: 1
        )
    }
}

enum ThemePreviewStyle {
    static let discoBackgroundHex = "#080909"
    static let aspectRatio: CGFloat = 1.45
}

enum GameCellVisualMetrics {
    static let targetBorderWidth: CGFloat = 3
    static let activeBorderWidth: CGFloat = 2
    static let previewGlyphScale: CGFloat = 3

    static func cornerRadius(
        theme: ThemePalette,
        side: CGFloat,
        minimum: CGFloat = 0
    ) -> CGFloat {
        theme.isPixel ? .zero : max(minimum, side * 0.10)
    }

    static func liveCornerRadius(
        theme: ThemePalette,
        gridDimension: Int
    ) -> CGFloat {
        guard !theme.isPixel else { return 0 }
        // Match the parent game's clamp(11px, 30px / grid-size, 22px)
        // instead of allowing a one-cell board to grow an oversized curve.
        return min(22, max(11, 30 / CGFloat(max(1, gridDimension))))
    }

    static func glyphBoxSide(
        side: CGFloat,
        minimumBaseSide: CGFloat = 14,
        scale: CGFloat = 1
    ) -> CGFloat {
        max(minimumBaseSide, side * 0.30) / 2.5 * max(0, scale)
    }

    static func liveGlyphScale(gridDimension: Int) -> CGFloat {
        switch gridDimension {
        case 2: 2
        case 4: 3
        default: 1
        }
    }
}

enum GameBoardVisualMetrics {
    static func shellCornerRadius(theme: ThemePalette) -> CGFloat {
        theme.isPixel ? 0 : 22
    }
}

struct GameCellPreview: View {
    let theme: ThemePalette
    let colorIndex: Int?
    let glyph: String
    var showsGlyphs = true
    var isTarget = true
    var textureSeed: Int?
    var glyphScale: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cornerRadius = GameCellVisualMetrics.cornerRadius(theme: theme, side: side)
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let effects = GameCellSurfaceEffects.resolve(
                theme: theme,
                isLit: colorIndex != nil,
                seed: textureSeed ?? colorIndex ?? 0
            )
            let primaryGlowRadius =
                theme.id == "disco" ? CGFloat.zero : (isTarget ? 6 : 3)

            ZStack {
                shape
                    .fill(fillColor)
                    .overlay {
                        GameCellSurfaceOverlay(
                            theme: theme,
                            cornerRadius: cornerRadius,
                            effects: effects,
                            activeColor: colorIndex.map { theme.color(at: $0) }
                        )
                    }
                    .overlay {
                        if theme.id == "disco" {
                            Image("disco-tile-overlay", bundle: .main)
                                .resizable()
                                .scaledToFill()
                                .blendMode(.screen)
                                .opacity(
                                    colorIndex == nil
                                        ? DiscoThemeTokens.idleScratchOpacity
                                        : DiscoThemeTokens.activeScratchOpacity
                                )
                                .clipShape(shape)
                        }
                    }
                    .overlay {
                        if showsGlyphs {
                            CenteredColorGlyphView(
                                glyph: glyph,
                                color: glyphColor,
                                size: GameCellVisualMetrics.glyphBoxSide(
                                    side: side,
                                    scale: glyphScale
                                ),
                                style: effects.glyphStyle
                            )
                        }
                    }
                    .overlay {
                        shape.stroke(
                            strokeColor,
                            lineWidth: isTarget
                                ? GameCellVisualMetrics.targetBorderWidth
                                : GameCellVisualMetrics.activeBorderWidth
                        )
                    }
                    .shadow(
                        color: primaryGlowColor,
                        radius: theme.isPixel ? 0 : primaryGlowRadius
                    )

            }
            .frame(width: side, height: side)
            .overlay {
                if effects.discoGlow, let colorIndex {
                    DiscoOutgoingGlowView(
                        color: theme.color(at: colorIndex),
                        cellSide: side,
                        cornerRadius: cornerRadius
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var fillColor: Color {
        guard let colorIndex else {
            return Color(hex: theme.idleCell)
        }
        return theme.color(at: colorIndex)
    }

    private var glyphColor: Color {
        guard let colorIndex else { return Color(hex: theme.foreground) }
        return theme.cellInkColor(at: colorIndex)
    }

    private var strokeColor: Color {
        guard colorIndex != nil else {
            return theme.id == "disco"
                ? Color(hex: DiscoThemeTokens.cellBorderHex)
                : Color(hex: theme.foreground).opacity(0.18)
        }
        if theme.id == "disco" {
            guard let colorIndex else {
                return Color(hex: DiscoThemeTokens.activeBorderHex)
            }
            return Color(
                uiColor: DiscoThemeTokens.activeBorderColor(
                    for: theme.uiColor(at: colorIndex)
                )
            )
        }
        return .white.opacity(isTarget ? 0.85 : 0.35)
    }

    private var primaryGlowColor: Color {
        guard let colorIndex else { return .clear }
        return theme.color(at: colorIndex).opacity(
            theme.id == "disco" ? 0 : 0.30
        )
    }
}

enum ZenAnyCellTokens {
    static let previewSide: CGFloat = 40
    static let horizontalLogoGradientHexes = [
        "#16b887", "#39c85f", "#86bd3c", "#ffe659", "#ff9a56", "#ff6fc8",
        "#a58aff", "#69d7ff",
    ]
}

struct ZenAnyCellPreview: View {
    let theme: ThemePalette

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cornerRadius = GameCellVisualMetrics.cornerRadius(theme: theme, side: side)
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

            shape
                .fill(
                    LinearGradient(
                        colors: ZenAnyCellTokens.horizontalLogoGradientHexes.map {
                            Color(hex: $0)
                        },
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay {
                    shape.stroke(
                        Color.white.opacity(0.92),
                        lineWidth: GameCellVisualMetrics.targetBorderWidth
                    )
                }
                .shadow(
                    color: Color(hex: "#6c9cff").opacity(theme.isPixel ? 0 : 0.42),
                    radius: theme.isPixel ? 0 : 6
                )
                .frame(width: side, height: side)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct GameCellSurfaceOverlay: View {
    let theme: ThemePalette
    let cornerRadius: CGFloat
    let effects: GameCellSurfaceEffects
    let activeColor: Color?

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

            ZStack {
                if effects.discoGlow {
                    if activeColor != nil {
                        RadialGradient(
                            stops: [
                                .init(
                                    color: .white.opacity(
                                        GameCellEffectTokens.discoCenterWhiteOpacity
                                    ),
                                    location: 0
                                ),
                                .init(
                                    color: .white.opacity(
                                        GameCellEffectTokens.discoMidpointWhiteOpacity
                                    ),
                                    location: 0.34
                                ),
                                .init(color: .clear, location: 0.64),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: side * 0.64
                        )
                        .blendMode(.screen)

                        LinearGradient(
                            colors: [
                                .white.opacity(GameCellEffectTokens.discoGlazeWhiteOpacity),
                                .clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .blendMode(.screen)

                        LinearGradient(
                            colors: [
                                .clear,
                                .clear,
                                .black.opacity(GameCellEffectTokens.discoDepthOpacity),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .blendMode(.multiply)
                    }
                }

                if effects.lightGlass {
                    LinearGradient(
                        colors: [
                            .white.opacity(GameCellEffectTokens.lightTopHighlightOpacity),
                            .white.opacity(0.08),
                            Color(hex: "#2e91b8").opacity(
                                GameCellEffectTokens.lightLowerShadeOpacity
                            ),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.screen)

                    Rectangle()
                        .fill(
                            Color.white.opacity(GameCellEffectTokens.lightSpecularOpacity)
                        )
                        .frame(width: side * 0.18, height: side * 1.55)
                        .rotationEffect(.degrees(38))
                        .offset(x: -side * 0.15, y: -side * 0.08)

                    RoundedRectangle(
                        cornerRadius: max(0, cornerRadius - 2),
                        style: .continuous
                    )
                    .stroke(
                        Color.white.opacity(GameCellEffectTokens.lightInnerStrokeOpacity),
                        lineWidth: 1.5
                    )
                    .padding(2)
                }

                if effects.pixelNoise {
                    PixelTileNoiseView(seed: effects.seed)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(shape)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ThemePreview: View {
    let theme: ThemePalette
    var showsGlyphs = true

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ThemePreviewBackground(theme: theme)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3),
                    spacing: 5
                ) {
                    ForEach(Array(gameColors.enumerated()), id: \.offset) { index, color in
                        GameCellPreview(
                            theme: theme,
                            colorIndex: index,
                            glyph: color.glyph,
                            showsGlyphs: showsGlyphs,
                            isTarget: false,
                            textureSeed: index,
                            glyphScale: GameCellVisualMetrics.previewGlyphScale
                        )
                    }
                }
                .padding(7)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(ThemePreviewStyle.aspectRatio, contentMode: .fit)
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 10))
        .overlay {
            RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 10)
                .stroke(
                    theme.isLight ? Color.white : Color(hex: theme.accent).opacity(0.34),
                    lineWidth: theme.isPixel || theme.isLight ? 2 : 1
                )
        }
        .accessibilityIdentifier("theme-preview-\(theme.id)")
    }

}

private struct ThemePreviewBackground: View {
    let theme: ThemePalette

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if theme.id == "disco" {
                    DiscoConcreteBackdrop(context: .preview)
                } else if theme.id == "light" {
                    LinearGradient(
                        colors: [Color(hex: "#bdeaff"), Color(hex: "#f4fbff")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else if theme.id == "pixel" {
                    Color(hex: "#111126")
                    PixelGrid(spacing: 8, color: Color(hex: "#69e8ff").opacity(0.10))
                } else {
                    Color(hex: theme.board)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }
}

extension UIColor {
    convenience init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(cleaned, radix: 16) ?? 0
        self.init(
            red: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255,
            alpha: 1
        )
    }
}
