import CoreGraphics
import SwiftUI

enum GameGlyphStyle: Equatable, Sendable {
    case smooth
    case pixel
}

enum GameGlyphYAxis: Equatable, Sendable {
    case down
    case up
}

enum GameGlyphGeometry {
    static let supportedGlyphs = ["●", "▲", "■", "◆", "✚", "★"]
    static let pixelGridSize = 9

    static func path(
        for glyph: String,
        in rect: CGRect,
        style: GameGlyphStyle,
        yAxis: GameGlyphYAxis
    ) -> CGPath? {
        guard supportedGlyphs.contains(glyph), rect.width > 0, rect.height > 0 else { return nil }
        switch style {
        case .smooth:
            return smoothPath(for: glyph, in: rect, yAxis: yAxis)
        case .pixel:
            return pixelPath(for: glyph, in: rect, yAxis: yAxis)
        }
    }

    private static func smoothPath(
        for glyph: String,
        in rect: CGRect,
        yAxis: GameGlyphYAxis
    ) -> CGPath {
        let raw = CGMutablePath()
        switch glyph {
        case "●":
            raw.addEllipse(in: CGRect(x: 0, y: 0, width: 1, height: 1))
        case "▲":
            raw.move(to: CGPoint(x: 0.5, y: yAxis == .down ? 0 : 1))
            raw.addLine(to: CGPoint(x: 1, y: yAxis == .down ? 1 : 0))
            raw.addLine(to: CGPoint(x: 0, y: yAxis == .down ? 1 : 0))
            raw.closeSubpath()
        case "■":
            raw.addRect(CGRect(x: 0, y: 0, width: 1, height: 1))
        case "◆":
            raw.move(to: CGPoint(x: 0.5, y: 0))
            raw.addLine(to: CGPoint(x: 1, y: 0.5))
            raw.addLine(to: CGPoint(x: 0.5, y: 1))
            raw.addLine(to: CGPoint(x: 0, y: 0.5))
            raw.closeSubpath()
        case "✚":
            raw.move(to: CGPoint(x: 0.34, y: 0))
            raw.addLine(to: CGPoint(x: 0.66, y: 0))
            raw.addLine(to: CGPoint(x: 0.66, y: 0.34))
            raw.addLine(to: CGPoint(x: 1, y: 0.34))
            raw.addLine(to: CGPoint(x: 1, y: 0.66))
            raw.addLine(to: CGPoint(x: 0.66, y: 0.66))
            raw.addLine(to: CGPoint(x: 0.66, y: 1))
            raw.addLine(to: CGPoint(x: 0.34, y: 1))
            raw.addLine(to: CGPoint(x: 0.34, y: 0.66))
            raw.addLine(to: CGPoint(x: 0, y: 0.66))
            raw.addLine(to: CGPoint(x: 0, y: 0.34))
            raw.addLine(to: CGPoint(x: 0.34, y: 0.34))
            raw.closeSubpath()
        default:
            let startAngle = yAxis == .down ? -Double.pi / 2 : Double.pi / 2
            for index in 0..<10 {
                let radius = index.isMultiple(of: 2) ? 0.5 : 0.225
                let angle = startAngle + Double(index) * Double.pi / 5
                let point = CGPoint(
                    x: 0.5 + CGFloat(cos(angle)) * radius,
                    y: 0.5 + CGFloat(sin(angle)) * radius
                )
                if index == 0 { raw.move(to: point) } else { raw.addLine(to: point) }
            }
            raw.closeSubpath()
        }
        return fitted(raw, to: rect)
    }

    private static func pixelPath(
        for glyph: String,
        in rect: CGRect,
        yAxis: GameGlyphYAxis
    ) -> CGPath {
        let rows = pixelRows[glyph] ?? pixelRows["■"]!
        let grid = CGFloat(pixelGridSize)
        let cellSide = min(rect.width, rect.height) / grid
        let renderedSide = cellSide * grid
        let origin = CGPoint(
            x: rect.midX - renderedSide / 2,
            y: rect.midY - renderedSide / 2
        )
        let path = CGMutablePath()
        for (rowIndex, row) in rows.enumerated() {
            for (columnIndex, value) in row.enumerated() where value == "#" {
                let renderedRow = yAxis == .down ? rowIndex : pixelGridSize - 1 - rowIndex
                path.addRect(
                    CGRect(
                        x: origin.x + CGFloat(columnIndex) * cellSide,
                        y: origin.y + CGFloat(renderedRow) * cellSide,
                        width: cellSide,
                        height: cellSide
                    )
                )
            }
        }
        return path
    }

    private static func fitted(_ path: CGPath, to rect: CGRect) -> CGPath {
        let bounds = path.boundingBoxOfPath
        guard bounds.width > 0, bounds.height > 0 else { return path }
        let scaleX = rect.width / bounds.width
        let scaleY = rect.height / bounds.height
        var transform = CGAffineTransform(
            a: scaleX,
            b: 0,
            c: 0,
            d: scaleY,
            tx: rect.minX - bounds.minX * scaleX,
            ty: rect.minY - bounds.minY * scaleY
        )
        return path.copy(using: &transform) ?? path
    }

    private static let pixelRows: [String: [[Character]]] = [
        "●": [
            "...###...", "..#####..", ".#######.", "#########", "#########",
            "#########", ".#######.", "..#####..", "...###...",
        ].map(Array.init),
        "▲": [
            "....#....", "...###...", "...###...", "..#####..", "..#####..",
            ".#######.", ".#######.", "#########", "#########",
        ].map(Array.init),
        "■": Array(repeating: Array("#########"), count: 9),
        "◆": [
            "....#....", "...###...", "..#####..", ".#######.", "#########",
            ".#######.", "..#####..", "...###...", "....#....",
        ].map(Array.init),
        "✚": [
            "...###...", "...###...", "...###...", "#########", "#########",
            "#########", "...###...", "...###...", "...###...",
        ].map(Array.init),
        "★": [
            "....#....", "...###...", "...###...", "#########", ".#######.",
            "..#####..", ".##...##.", "##.....##", "#.......#",
        ].map(Array.init),
    ]
}

struct PixelNoiseSample: Equatable, Sendable {
    let x: Int
    let y: Int
    let isLight: Bool
}

enum PixelNoisePattern {
    static let gridSize = 32
    static let sampleCount = 32
    static let lightSampleRatio = 0.75

    static func squareSide(for side: CGFloat) -> CGFloat {
        max(1, floor(side / CGFloat(gridSize)))
    }

    static func samples(seed: Int) -> [PixelNoiseSample] {
        var state = UInt64(bitPattern: Int64(seed)) ^ 0x9E37_79B9_7F4A_7C15
        var occupied: Set<Int> = []
        var result: [PixelNoiseSample] = []
        while result.count < sampleCount {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let x = Int((state >> 18) % UInt64(gridSize))
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let y = Int((state >> 21) % UInt64(gridSize))
            guard occupied.insert(y * gridSize + x).inserted else { continue }
            result.append(
                PixelNoiseSample(
                    x: x,
                    y: y,
                    isLight: Double(result.count) / Double(sampleCount) < lightSampleRatio
                )
            )
        }
        return result
    }
}

struct GameCellSurfaceEffects: Equatable, Sendable {
    let discoBacklight: Bool
    let requiresBlackCornerUnderlay: Bool
    let lightGlass: Bool
    let pixelNoise: Bool
    let glyphStyle: GameGlyphStyle
    let seed: Int

    static func resolve(theme: ThemePalette, isLit: Bool, seed: Int) -> Self {
        Self(
            discoBacklight: theme.id == "disco" && isLit,
            requiresBlackCornerUnderlay: theme.id == "disco",
            lightGlass: theme.id == "light",
            pixelNoise: theme.id == "pixel",
            glyphStyle: theme.isPixel ? .pixel : .smooth,
            seed: seed
        )
    }
}

enum GameCellEffectTokens {
    static let discoCenterWhiteOpacity = 0.08
    static let discoMidpointWhiteOpacity = 0.02
    static let discoColorBoostOpacity = 0.38
    static let discoPrimaryGlowOpacity = 0.90
    static let discoSecondaryGlowOpacity = 0.16
    static let lightTopHighlightOpacity = 0.55
    static let lightSpecularOpacity = 0.18
    static let lightLowerShadeOpacity = 0.10
    static let lightInnerStrokeOpacity = 0.82
    static let pixelLightNoiseOpacity = 0.15
    static let pixelDarkNoiseOpacity = 0.03
}

struct PixelTileNoiseView: View {
    let seed: Int

    var body: some View {
        Canvas(opaque: false, colorMode: .nonLinear) { context, size in
            let side = min(size.width, size.height)
            let pixel = PixelNoisePattern.squareSide(for: side)
            for sample in PixelNoisePattern.samples(seed: seed) {
                let rawX = CGFloat(sample.x) / CGFloat(PixelNoisePattern.gridSize) * size.width
                let rawY = CGFloat(sample.y) / CGFloat(PixelNoisePattern.gridSize) * size.height
                let rect = CGRect(
                    x: floor(rawX / pixel) * pixel,
                    y: floor(rawY / pixel) * pixel,
                    width: pixel,
                    height: pixel
                )
                context.fill(
                    Path(rect),
                    with: .color(
                        sample.isLight
                            ? Color.white.opacity(GameCellEffectTokens.pixelLightNoiseOpacity)
                            : Color.black.opacity(GameCellEffectTokens.pixelDarkNoiseOpacity)
                    )
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
