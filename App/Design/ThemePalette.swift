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
        backgroundBottom: "#03060d",
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
        backgroundTop: "#17121d",
        backgroundBottom: "#020304",
        foreground: "#f7f8ff",
        muted: "#a8afb9",
        surface: "#11131a",
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
        idleCell: "#d7e7f1",
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
        ZStack {
            LinearGradient(
                colors: [Color(hex: theme.backgroundTop), Color(hex: theme.backgroundBottom)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if theme.id == "disco" {
                RadialGradient(
                    colors: [Color.pink.opacity(0.24), .clear],
                    center: .topTrailing,
                    startRadius: 10,
                    endRadius: 260
                )
                RadialGradient(
                    colors: [Color.cyan.opacity(0.20), .clear],
                    center: .bottomLeading,
                    startRadius: 8,
                    endRadius: 240
                )
            } else if theme.id == "light" {
                VStack(spacing: 70) {
                    Capsule().fill(.white.opacity(0.76)).frame(width: 150, height: 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Capsule().fill(.white.opacity(0.66)).frame(width: 120, height: 10)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Spacer()
                }
                .padding(.horizontal, 26)
                .padding(.top, 90)
            } else if theme.id == "pixel" {
                Canvas { context, size in
                    var path = Path()
                    for x in stride(from: CGFloat.zero, through: size.width, by: 16) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in stride(from: CGFloat.zero, through: size.height, by: 16) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(path, with: .color(Color.cyan.opacity(0.08)), lineWidth: 1)
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct ThemePreview: View {
    let theme: ThemePalette

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
            ForEach(Array(gameColors.enumerated()), id: \.offset) { index, color in
                RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 6)
                    .fill(theme.color(at: index))
                    .overlay {
                        Text(color.glyph)
                            .font(.system(size: 13, weight: .black, design: theme.fontDesign))
                            .foregroundStyle(theme.cellInkColor(at: index))
                    }
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(7)
        .background(Color(hex: theme.board), in: RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 10))
        .overlay {
            RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 10)
                .stroke(Color(hex: theme.accent).opacity(0.34), lineWidth: theme.isPixel ? 2 : 1)
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
