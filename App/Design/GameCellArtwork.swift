import CoreGraphics
import SwiftUI
import UIKit

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
    let discoGlow: Bool
    let lightGlass: Bool
    let pixelNoise: Bool
    let glyphStyle: GameGlyphStyle
    let seed: Int

    static func resolve(theme: ThemePalette, isLit: Bool, seed: Int) -> Self {
        Self(
            discoGlow: theme.id == "disco" && isLit,
            lightGlass: theme.id == "light",
            pixelNoise: theme.id == "pixel",
            glyphStyle: theme.isPixel ? .pixel : .smooth,
            seed: seed
        )
    }
}

enum GameCellEffectTokens {
    static let discoCenterWhiteOpacity = 0.42
    static let discoMidpointWhiteOpacity = 0.11
    static let discoGlazeWhiteOpacity = 0.23
    static let discoDepthOpacity = 0.18
    static let discoGlowOpacity = 0.88
    static let discoGlowNearOpacity = 0.68
    static let discoGlowFarOpacity = 0.34
    static let discoGlowNearBlurMaximum: CGFloat = 13
    static let discoGlowFarBlurMaximum: CGFloat = 30
    static let lightTopHighlightOpacity = 0.55
    static let lightSpecularOpacity = 0.18
    static let lightLowerShadeOpacity = 0.10
    static let lightInnerStrokeOpacity = 0.82
    static let pixelLightNoiseOpacity = 0.15
    static let pixelDarkNoiseOpacity = 0.03
}

enum GameCellLayerOrder {
    static let cell: CGFloat = 1
    static let discoMaterial: CGFloat = 1.30
    static let discoWear: CGFloat = 1.45
    static let discoBorder: CGFloat = 1.80
    static let glyph: CGFloat = 2
}

enum GameBoardGeometry {
    // GameView gives SpriteKit the full shell. The shared inset keeps live
    // SpriteKit cells and the SwiftUI glow overlay on exactly the same grid.
    static let sceneInset: CGFloat = 12
}

enum GameBoardYAxis: Equatable, Sendable {
    case down
    case up
}

struct GameBoardLayout: Equatable, Sendable {
    let size: CGSize
    let dimension: Int
    let boardFrame: CGRect
    let gap: CGFloat
    let cellSide: CGFloat

    init(size: CGSize, dimension: Int) {
        self.size = size
        self.dimension = dimension
        let boardSide = min(size.width, size.height) - GameBoardGeometry.sceneInset * 2
        boardFrame = CGRect(
            x: (size.width - boardSide) / 2,
            y: (size.height - boardSide) / 2,
            width: boardSide,
            height: boardSide
        )
        gap = dimension == 4 ? 5 : 8
        cellSide = (boardSide - gap * CGFloat(dimension - 1)) / CGFloat(dimension)
    }

    func cellFrame(at index: Int, yAxis: GameBoardYAxis) -> CGRect {
        let rowFromTop = index / dimension
        let column = index % dimension
        let row = yAxis == .down ? rowFromTop : dimension - 1 - rowFromTop
        return CGRect(
            x: boardFrame.minX + CGFloat(column) * (cellSide + gap),
            y: boardFrame.minY + CGFloat(row) * (cellSide + gap),
            width: cellSide,
            height: cellSide
        )
    }
}

struct DiscoGlowGeometry: Equatable, Sendable {
    let cellSide: CGFloat
    let cornerRadius: CGFloat
    let nearBlurRadius: CGFloat
    let farBlurRadius: CGFloat
    let extent: CGFloat

    var imageSize: CGSize {
        CGSize(width: cellSide + extent * 2, height: cellSide + extent * 2)
    }

    var tileRect: CGRect {
        CGRect(x: extent, y: extent, width: cellSide, height: cellSide)
    }

    static func resolve(cellSide: CGFloat, cornerRadius: CGFloat) -> Self {
        let safeSide = max(1, cellSide)
        let nearBlur = min(
            GameCellEffectTokens.discoGlowNearBlurMaximum,
            max(4, safeSide * 0.06)
        )
        let farBlur = min(
            GameCellEffectTokens.discoGlowFarBlurMaximum,
            max(9, safeSide * 0.12)
        )
        return Self(
            cellSide: safeSide,
            cornerRadius: max(0, min(cornerRadius, safeSide / 2)),
            nearBlurRadius: nearBlur,
            farBlurRadius: farBlur,
            extent: ceil(max(12, farBlur * 1.75))
        )
    }
}

@MainActor
enum DiscoOutgoingGlowArtwork {
    private struct CacheKey: Hashable {
        let cellSideTenths: Int
        let cornerRadiusTenths: Int
    }

    private static var images: [CacheKey: UIImage] = [:]

    static func image(cellSide: CGFloat, cornerRadius: CGFloat) -> UIImage {
        let key = CacheKey(
            cellSideTenths: Int((cellSide * 10).rounded()),
            cornerRadiusTenths: Int((cornerRadius * 10).rounded())
        )
        if let image = images[key] { return image }
        let geometry = DiscoGlowGeometry.resolve(
            cellSide: CGFloat(key.cellSideTenths) / 10,
            cornerRadius: CGFloat(key.cornerRadiusTenths) / 10
        )
        let image = makeImage(geometry: geometry)
        images[key] = image
        return image
    }

    private static func makeImage(geometry: DiscoGlowGeometry) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        return UIGraphicsImageRenderer(
            size: geometry.imageSize,
            format: format
        ).image { rendererContext in
            let context = rendererContext.cgContext
            context.setAllowsAntialiasing(true)
            let tilePath = UIBezierPath(
                roundedRect: geometry.tileRect,
                cornerRadius: geometry.cornerRadius
            ).cgPath

            drawBlurredPass(
                in: context,
                path: tilePath,
                blur: geometry.farBlurRadius,
                opacity: GameCellEffectTokens.discoGlowFarOpacity
            )
            drawBlurredPass(
                in: context,
                path: tilePath,
                blur: geometry.nearBlurRadius,
                opacity: GameCellEffectTokens.discoGlowNearOpacity
            )

            // The glow is an outgoing halo rendered above the tile, not a
            // duplicate luminous fill. Clear the tile body after producing
            // the Gaussian passes so only the feathered exterior remains.
            context.saveGState()
            context.setBlendMode(.clear)
            let clearInset: CGFloat = -0.75
            context.addPath(
                UIBezierPath(
                    roundedRect: geometry.tileRect.insetBy(
                        dx: clearInset,
                        dy: clearInset
                    ),
                    cornerRadius: geometry.cornerRadius - clearInset
                ).cgPath
            )
            context.fillPath()
            context.restoreGState()
        }
    }

    private static func drawBlurredPass(
        in context: CGContext,
        path: CGPath,
        blur: CGFloat,
        opacity: CGFloat
    ) {
        context.saveGState()
        context.setShadow(
            offset: .zero,
            blur: blur,
            color: UIColor.white.withAlphaComponent(opacity).cgColor
        )
        context.setFillColor(UIColor.white.cgColor)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
    }
}

struct DiscoOutgoingGlowView: View {
    let color: Color
    let cellSide: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        let image = DiscoOutgoingGlowArtwork.image(
            cellSide: cellSide,
            cornerRadius: cornerRadius
        )
        Image(uiImage: image)
            .renderingMode(.template)
            .resizable()
            .foregroundStyle(color)
            .frame(width: image.size.width, height: image.size.height)
            .opacity(GameCellEffectTokens.discoGlowOpacity)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
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
