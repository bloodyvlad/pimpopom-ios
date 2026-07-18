import PimPoPomCore
import SwiftUI

enum WebMenuMetrics {
    static let maximumPanelWidth: CGFloat = 460
    static let compactOuterInset: CGFloat = 10
    static let panelPadding: CGFloat = 22
    static let narrowPanelPadding: CGFloat = 16
    static let utilityTarget: CGFloat = 44
    static let headerHeight: CGFloat = 48
    static let hintHeight: CGFloat = 112
    static let modeHeight: CGFloat = 56
    static let standardControlHeight: CGFloat = 51
    static let featureControlHeight: CGFloat = 48
    static let featureIconLeadingInset: CGFloat = 19
    static let actionGap: CGFloat = 9
    static let pairedGap: CGFloat = 8
    static let menuPetHorizontalShiftFraction: CGFloat = 0.15
    static let motivationHorizontalShiftFraction: CGFloat = 0.10
    static let motivationScale: CGFloat = 1.15
}

enum PimPoPomBrandColors {
    static let pimGradient = ["#16b887", "#39c85f", "#86bd3c"]
}

struct PimPoPomWordmark: View {
    let theme: ThemePalette
    var size: CGFloat = 22

    var body: some View {
        HStack(alignment: .center, spacing: -1.5) {
            wordPart("Pim", colors: PimPoPomBrandColors.pimGradient)
            wordPart("Po", colors: ["#ffe659", "#ff9a56", "#ff6fc8"])
            wordPart("Pom", colors: ["#ff6fc8", "#a58aff", "#69d7ff"])

            Circle()
                .stroke(Color(hex: "#63fff2"), lineWidth: 1.5)
                .frame(width: 7, height: 7)
                .shadow(color: Color(hex: "#63fff2"), radius: 5)
                .padding(.leading, 5)
                .offset(y: -7)
        }
        .padding(.horizontal, theme.isLight ? 8 : 0)
        .padding(.vertical, theme.isLight ? 6 : 0)
        .background {
            if theme.isLight {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.86))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(hex: "#3f799d").opacity(0.24), lineWidth: 1)
                    }
                    .shadow(color: Color(hex: "#3f799d").opacity(0.16), radius: 8, y: 4)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .shadow(color: Color(hex: "#43f4ff").opacity(0.26), radius: theme.isPixel ? 0 : 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PimPoPom")
        .accessibilityIdentifier("menu-wordmark")
    }

    @ViewBuilder
    private func wordPart(_ text: String, colors: [String]) -> some View {
        let label = Text(text)
            .font(theme.appFont(size: size, weight: .black, relativeTo: .title))
            .foregroundStyle(
                LinearGradient(
                    colors: colors.map { Color(hex: $0) },
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

        if theme.isPixel {
            label
        } else {
            label.italic()
        }
    }
}

struct GlowStampView: View {
    let text: String
    let tone: Color
    let theme: ThemePalette
    var tilt: Double = 0
    var size: CGFloat = 15
    var horizontalPadding: CGFloat = 11
    var verticalPadding: CGFloat = 7
    var uppercasesText = true
    var usesTransparentBackground = false

    var body: some View {
        Text(text)
            .font(theme.appFont(size: size, weight: .black, relativeTo: .body))
            .italic(!theme.isPixel)
            .textCase(uppercasesText ? .uppercase : nil)
            .lineLimit(1)
            .minimumScaleFactor(0.70)
            .foregroundStyle(tone)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                usesTransparentBackground
                    ? Color.clear
                    : theme.isLight
                        ? Color.white.opacity(0.91)
                        : Color(hex: "#04060c").opacity(0.84),
                in: RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 11, style: .continuous)
                    .stroke(tone.opacity(theme.isLight ? 0.80 : 0.96), lineWidth: 2)
            }
            .shadow(color: tone.opacity(theme.isLight ? 0.20 : 0.62), radius: theme.isPixel ? 0 : 8)
            .rotationEffect(.degrees(tilt))
    }
}

struct WebLoadingOverlay: View {
    let theme: ThemePalette
    var label = "Loading"

    var body: some View {
        ZStack {
            Color.black.opacity(theme.isLight ? 0.10 : 0.30)
                .ignoresSafeArea()

            TimelineView(.animation) { timeline in
                let turn =
                    timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 1.15) / 1.15
                ZStack {
                    Circle()
                        .stroke(Color(hex: theme.foreground).opacity(0.12), lineWidth: 5)
                    Circle()
                        .trim(from: 0.08, to: 0.72)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color(hex: theme.accent).opacity(0.15),
                                    Color(hex: theme.accent),
                                    Color(hex: theme.petsAccent),
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(turn * 360))
                }
                .frame(width: 46, height: 46)
                .padding(17)
                .background(
                    Color(hex: theme.surface).opacity(theme.isLight ? 0.94 : 0.91),
                    in: RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 18, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 18, style: .continuous)
                        .stroke(Color(hex: theme.accent).opacity(0.38), lineWidth: theme.isPixel ? 2 : 1)
                }
                .shadow(color: Color(hex: theme.accent).opacity(0.34), radius: theme.isPixel ? 0 : 16)
            }
        }
        .transition(.opacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("loading-overlay")
    }
}

struct PixelCoinView: View {
    var size: CGFloat = 18

    var body: some View {
        Canvas(opaque: false, colorMode: .nonLinear) { context, canvasSize in
            let scale = min(canvasSize.width, canvasSize.height) / 12

            func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
                CGRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)
            }

            func polygon(_ points: [CGPoint]) -> Path {
                var path = Path()
                guard let first = points.first else { return path }
                path.move(to: CGPoint(x: first.x * scale, y: first.y * scale))
                for point in points.dropFirst() {
                    path.addLine(to: CGPoint(x: point.x * scale, y: point.y * scale))
                }
                path.closeSubpath()
                return path
            }

            // Exact geometry and colors from the web game's inline 12 x 12 coin SVG.
            context.fill(
                polygon([
                    CGPoint(x: 3, y: 1), CGPoint(x: 9, y: 1), CGPoint(x: 9, y: 2),
                    CGPoint(x: 11, y: 2), CGPoint(x: 11, y: 4), CGPoint(x: 12, y: 4),
                    CGPoint(x: 12, y: 8), CGPoint(x: 11, y: 8), CGPoint(x: 11, y: 10),
                    CGPoint(x: 9, y: 10), CGPoint(x: 9, y: 11), CGPoint(x: 3, y: 11),
                    CGPoint(x: 3, y: 10), CGPoint(x: 1, y: 10), CGPoint(x: 1, y: 8),
                    CGPoint(x: 0, y: 8), CGPoint(x: 0, y: 4), CGPoint(x: 1, y: 4),
                    CGPoint(x: 1, y: 2), CGPoint(x: 3, y: 2),
                ]),
                with: .color(Color(hex: "#8d5100"))
            )
            context.fill(
                polygon([
                    CGPoint(x: 3, y: 2), CGPoint(x: 9, y: 2), CGPoint(x: 9, y: 3),
                    CGPoint(x: 10, y: 3), CGPoint(x: 10, y: 4), CGPoint(x: 11, y: 4),
                    CGPoint(x: 11, y: 8), CGPoint(x: 10, y: 8), CGPoint(x: 10, y: 9),
                    CGPoint(x: 9, y: 9), CGPoint(x: 9, y: 10), CGPoint(x: 3, y: 10),
                    CGPoint(x: 3, y: 9), CGPoint(x: 2, y: 9), CGPoint(x: 2, y: 8),
                    CGPoint(x: 1, y: 8), CGPoint(x: 1, y: 4), CGPoint(x: 2, y: 4),
                    CGPoint(x: 2, y: 3), CGPoint(x: 3, y: 3),
                ]),
                with: .color(Color(hex: "#ffc629"))
            )
            context.fill(Path(rect(3, 3, 4, 1)), with: .color(Color(hex: "#fff09a")))
            context.fill(Path(rect(2, 4, 1, 3)), with: .color(Color(hex: "#fff09a")))
            context.fill(Path(rect(4, 5, 1, 3)), with: .color(Color(hex: "#fff09a")))
            context.fill(Path(rect(8, 4, 2, 4)), with: .color(Color(hex: "#e18b00")))
            context.fill(Path(rect(9, 8, 1, 1)), with: .color(Color(hex: "#e18b00")))
            context.fill(Path(rect(6, 8, 3, 1)), with: .color(Color(hex: "#e18b00")))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct WebUtilityBadge: View {
    enum Kind {
        case coin
        case rank

        var background: Color {
            switch self {
            case .coin: Color(hex: "#ffd84d")
            case .rank: Color(hex: "#63fff2")
            }
        }

        var foreground: Color {
            switch self {
            case .coin: Color(hex: "#291e00")
            case .rank: Color(hex: "#061e1c")
            }
        }
    }

    let text: String
    let kind: Kind
    let theme: ThemePalette

    var body: some View {
        Text(text)
            .font(theme.appFont(size: 9, weight: .black, relativeTo: .caption2))
            .foregroundColor(kind.foreground)
            .monospacedDigit()
            .lineLimit(1)
            .padding(.horizontal, 5)
            .frame(minWidth: 26, minHeight: 19)
            .background { Capsule().fill(kind.background) }
            .overlay { Capsule().stroke(Color(hex: "#111426"), lineWidth: 2) }
            .compositingGroup()
            .shadow(
                color: kind == .rank ? Color(hex: "#63fff2").opacity(0.55) : .clear,
                radius: kind == .rank ? 5 : 0
            )
    }
}

struct CenteredColorGlyphView: View {
    let glyph: String
    let color: Color
    var size: CGFloat = 20
    var style = GameGlyphStyle.smooth

    var body: some View {
        Canvas(opaque: false, colorMode: .nonLinear) { context, canvasSize in
            let side = min(canvasSize.width, canvasSize.height)
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let rect = CGRect(
                x: center.x - side / 2,
                y: center.y - side / 2,
                width: side,
                height: side
            )
            if let path = GameGlyphGeometry.path(
                for: glyph,
                in: rect,
                style: style,
                yAxis: .down
            ) {
                context.fill(Path(path), with: .color(color))
            } else {
                context.draw(
                    Text(glyph).font(.system(size: side * 0.78, weight: .black)).foregroundStyle(color),
                    at: center,
                    anchor: .center
                )
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct WebMenuPanelModifier: ViewModifier {
    let theme: ThemePalette

    func body(content: Content) -> some View {
        content
            .padding(WebMenuMetrics.panelPadding)
            .background { panelBackground }
            .clipShape(panelShape)
            .overlay {
                panelShape.stroke(panelBorder, lineWidth: theme.isPixel ? 2 : 1)
            }
            .shadow(
                color: panelShadow,
                radius: theme.isPixel ? 0 : 34,
                x: theme.isPixel ? 8 : 0,
                y: theme.isPixel ? 8 : 20
            )
    }

    @ViewBuilder
    private var panelBackground: some View {
        if theme.id == "classic" {
            LinearGradient(
                colors: [Color(hex: "#222641").opacity(0.98), Color(hex: "#0e101d").opacity(0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if theme.id == "disco" {
            Image("disco-concrete-lights", bundle: .main)
                .resizable()
                .scaledToFill()
                .overlay {
                    LinearGradient(
                        colors: [Color(hex: "#0a0f18").opacity(0.80), Color(hex: "#05070b").opacity(0.90)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        } else if theme.id == "light" {
            Color.white.opacity(0.94)
        } else {
            Color(hex: "#121228").opacity(0.98)
        }
    }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 24, style: .continuous)
    }

    private var panelBorder: Color {
        switch theme.id {
        case "disco": Color(hex: "#b9d3d9").opacity(0.22)
        case "light": Color(hex: "#507a99").opacity(0.20)
        case "pixel": Color(hex: "#7aeaff")
        default: .white.opacity(0.12)
        }
    }

    private var panelShadow: Color {
        switch theme.id {
        case "light": Color(hex: "#4381a6").opacity(0.25)
        case "pixel": Color(hex: "#03030c").opacity(0.90)
        default: .black.opacity(theme.id == "disco" ? 0.76 : 0.55)
        }
    }
}

struct WebCardModifier: ViewModifier {
    let theme: ThemePalette
    let selectedAccent: Color?
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                Color(hex: theme.surface).opacity(theme.isLight ? 0.80 : 0.86),
                in: RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 13)
            )
            .overlay {
                RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 13)
                    .stroke(
                        selectedAccent
                            ?? (theme.isLight
                                ? Color(hex: "#3e6c8b").opacity(0.20)
                                : Color(hex: theme.foreground).opacity(0.11)),
                        lineWidth: theme.isPixel ? 2 : 1
                    )
            }
            .shadow(
                color: theme.isPixel
                    ? Color(hex: "#070713")
                    : (theme.isLight ? Color(hex: "#3f799d").opacity(0.09) : .black.opacity(0.12)),
                radius: theme.isPixel ? 0 : 10,
                x: theme.isPixel ? 4 : 0,
                y: theme.isPixel ? 4 : 5
            )
    }
}

extension View {
    func webMenuPanelStyle(theme: ThemePalette) -> some View {
        modifier(WebMenuPanelModifier(theme: theme))
    }

    func webCardStyle(
        theme: ThemePalette,
        selectedAccent: Color? = nil,
        padding: CGFloat = 14
    ) -> some View {
        modifier(WebCardModifier(theme: theme, selectedAccent: selectedAccent, padding: padding))
    }
}

struct WebSecondaryButtonStyle: ButtonStyle {
    let theme: ThemePalette
    var accent: Color?
    var minimumHeight: CGFloat = WebMenuMetrics.standardControlHeight

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(
            configuration: configuration,
            theme: theme,
            accent: accent,
            minimumHeight: minimumHeight
        )
    }

    private struct StyledBody: View {
        @Environment(\.isEnabled) private var isEnabled

        let configuration: Configuration
        let theme: ThemePalette
        let accent: Color?
        let minimumHeight: CGFloat

        var body: some View {
            configuration.label
                .font(theme.appFont(size: 16, weight: .bold, relativeTo: .body))
                .foregroundStyle(accent ?? Color(hex: theme.foreground))
                .frame(maxWidth: .infinity, minHeight: minimumHeight)
                .background {
                    ZStack {
                        if theme.isPixel {
                            shape
                                .fill(shadowColor)
                                .offset(x: 4, y: 4)
                        }
                        background.clipShape(shape)
                    }
                }
                .overlay { shape.stroke(borderColor, lineWidth: theme.isPixel ? 2 : 1) }
                .shadow(
                    color: theme.isPixel ? .clear : shadowColor,
                    radius: 7,
                    y: 4
                )
                .offset(y: configuration.isPressed ? 1 : 0)
                .saturation(isEnabled ? 1 : 0.45)
                .opacity(isEnabled ? 1 : 0.50)
        }

        private var shape: RoundedRectangle {
            RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 15, style: .continuous)
        }

        @ViewBuilder
        private var background: some View {
            if let accent {
                LinearGradient(
                    colors: [
                        accent.opacity(theme.isLight ? 0.09 : 0.10),
                        Color(hex: theme.surface).opacity(theme.isLight ? 0.92 : 0.86),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                theme.isLight
                    ? Color.white.opacity(0.82)
                    : Color(hex: theme.surface).opacity(0.70)
            }
        }

        private var borderColor: Color {
            if let accent {
                return accent.opacity(theme.isLight ? 0.72 : 0.78)
            }
            return theme.isLight
                ? Color(hex: "#3e6c8b").opacity(0.20)
                : Color(hex: theme.foreground).opacity(0.14)
        }

        private var shadowColor: Color {
            if theme.isPixel { return accent?.opacity(0.24) ?? Color(hex: "#070713") }
            if theme.isLight { return accent?.opacity(0.12) ?? Color(hex: "#3f799d").opacity(0.09) }
            return accent?.opacity(theme.id == "disco" ? 0.31 : 0.19) ?? .black.opacity(0.16)
        }
    }
}

struct WebModeButtonStyle: ButtonStyle {
    enum Kind {
        case arcade
        case zen
    }

    let theme: ThemePalette
    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: WebMenuMetrics.modeHeight)
            .background {
                ZStack {
                    LinearGradient(
                        colors: kind == .arcade
                            ? [Color(hex: "#f45198"), Color(hex: "#c92d70")]
                            : [Color(hex: "#93dc63"), Color(hex: "#3d9b58")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    RadialGradient(
                        colors: [.white.opacity(kind == .arcade ? 0.45 : 0.44), .clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: 105
                    )
                }
            }
            .clipShape(shape)
            .overlay {
                shape.stroke(
                    kind == .arcade
                        ? Color(hex: "#ff9eca").opacity(0.92)
                        : Color(hex: "#c9ffa4").opacity(0.90),
                    lineWidth: theme.isPixel ? 2 : 1
                )
            }
            .shadow(
                color: kind == .arcade
                    ? Color(hex: "#ff499b").opacity(0.58)
                    : Color(hex: "#91ec66").opacity(0.42),
                radius: theme.isPixel ? 0 : 10
            )
            .shadow(
                color: kind == .arcade
                    ? Color(hex: "#790f3e").opacity(0.32)
                    : Color(hex: "#165b2b").opacity(0.28),
                radius: theme.isPixel ? 0 : 12,
                y: theme.isPixel ? 4 : 8
            )
            .offset(y: configuration.isPressed ? 1 : 0)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 15, style: .continuous)
    }
}
