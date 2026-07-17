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
        isPixel ? size * 1.10 : size
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
        board: "#080a0d",
        idleCell: "#15131a",
        accent: "#ff86bc",
        isLight: false,
        isPixel: false,
        tileColors: ["#65e9f1", "#ffe681", "#ff86bc", "#b2ee7c", "#ffb06f", "#c3a8ff"]
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
                backgroundBase

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
    private var backgroundBase: some View {
        if theme.id == "disco" {
            Image("disco-concrete-lights", bundle: .main)
                .resizable()
                .scaledToFill()
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.04), .black.opacity(0.20)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
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

struct ThemePreview: View {
    let theme: ThemePalette
    var showsGlyphs = true

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
            ForEach(Array(gameColors.enumerated()), id: \.offset) { index, color in
                RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 6)
                    .fill(theme.color(at: index))
                    .overlay {
                        if theme.id == "disco" {
                            Image("disco-tile-overlay", bundle: .main)
                                .resizable()
                                .scaledToFill()
                                .blendMode(.screen)
                                .opacity(0.30)
                                .clipped()
                        }
                    }
                    .overlay {
                        if showsGlyphs {
                            Text(color.glyph)
                                .font(theme.appFont(size: 13, weight: .black, relativeTo: .caption))
                                .foregroundStyle(theme.cellInkColor(at: index))
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 6)
                            .stroke(
                                .white.opacity(theme.id == "light" ? 1 : 0.30),
                                lineWidth: theme.id == "light" || theme.isPixel ? 2 : 1)
                    }
                    .shadow(
                        color: theme.color(at: index).opacity(0.30), radius: theme.isPixel ? 0 : 4,
                        y: theme.isPixel ? 0 : 2
                    )
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(7)
        .background {
            ThemePreviewBackground(theme: theme)
        }
        .overlay {
            RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 10)
                .stroke(
                    theme.isLight ? Color.white : Color(hex: theme.accent).opacity(0.34),
                    lineWidth: theme.isPixel || theme.isLight ? 2 : 1
                )
        }
    }
}

private struct ThemePreviewBackground: View {
    let theme: ThemePalette

    var body: some View {
        ZStack {
            if theme.id == "disco" {
                Image("disco-concrete-lights", bundle: .main)
                    .resizable()
                    .scaledToFill()
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
        .clipShape(RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 10))
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
