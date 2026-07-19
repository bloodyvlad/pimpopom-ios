import PimPoPomCore
import SpriteKit
import UIKit

@MainActor
protocol GameSceneEventDelegate: AnyObject {
    func gameScene(_ scene: GameScene, requestsRoundActivationAt milliseconds: Double)
    func gameScene(_ scene: GameScene, requestsDecoyActivationAt milliseconds: Double)
    func gameScene(_ scene: GameScene, didAdvanceTo milliseconds: Double)
    func gameScene(_ scene: GameScene, didPointAt normalizedLocation: CGPoint)
    func gameScene(
        _ scene: GameScene,
        didTapCell index: Int,
        normalizedLocation: CGPoint,
        inputAt milliseconds: Double,
        handledAt: Double
    )
}

@MainActor
final class GameScene: SKScene {
    weak var eventDelegate: GameSceneEventDelegate?

    private var snapshot: GameSnapshot?
    private var cellFrames: [CGRect] = []
    private var pendingRoundActivation = false
    private var pendingDecoyActivation = false
    private var roundPresentationExpired = false
    private var boardFrame = CGRect.zero
    private var theme = ThemePalette.classic
    private var glyphsEnabled = true

    override init() {
        super.init(size: CGSize(width: 320, height: 320))
        scaleMode = .resizeFill
        backgroundColor = .clear
        anchorPoint = .zero
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ snapshot: GameSnapshot) {
        self.snapshot = snapshot
        rebuildBoard()
    }

    func applyTheme(_ themeID: String) {
        theme = ThemePalette.resolve(themeID)
        if theme.id == "disco" {
            GameCellTextureFactory.prewarmDisco()
        }
        rebuildBoard()
    }

    func applyGlyphsEnabled(_ enabled: Bool) {
        glyphsEnabled = enabled
        rebuildBoard()
    }

    func queueRoundActivation() {
        pendingRoundActivation = true
    }

    func queueDecoyActivation() {
        pendingDecoyActivation = true
    }

    func cancelQueuedActivations() {
        pendingRoundActivation = false
        pendingDecoyActivation = false
    }

    func setRoundPresentationExpired(_ expired: Bool) {
        guard roundPresentationExpired != expired else { return }
        roundPresentationExpired = expired
        rebuildBoard()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        rebuildBoard()
    }

    override func update(_: TimeInterval) {
        // Keep presentation, UIKit touch timestamps, and the proof clock in the
        // same monotonic uptime domain. SpriteKit's frame timestamp is not part
        // of the gameplay contract and can use a different epoch.
        let milliseconds = ProcessInfo.processInfo.systemUptime * 1_000
        if pendingRoundActivation {
            pendingRoundActivation = false
            eventDelegate?.gameScene(self, requestsRoundActivationAt: milliseconds)
        }
        if pendingDecoyActivation {
            pendingDecoyActivation = false
            eventDelegate?.gameScene(self, requestsDecoyActivationAt: milliseconds)
        }
        eventDelegate?.gameScene(self, didAdvanceTo: milliseconds)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let touch = touches.first else { return }
        handleBoardTouch(
            at: touch.location(in: self),
            inputAt: touch.timestamp * 1_000,
            handledAt: ProcessInfo.processInfo.systemUptime * 1_000
        )
    }

    func handleBoardTouch(at location: CGPoint, inputAt: Double, handledAt: Double) {
        guard snapshot != nil, boardFrame.contains(location) else { return }
        let normalizedLocation = CGPoint(
            x: min(1, max(0, location.x / max(size.width, 1))),
            y: min(1, max(0, 1 - (location.y / max(size.height, 1))))
        )
        eventDelegate?.gameScene(self, didPointAt: normalizedLocation)
        let index =
            cellFrames.firstIndex(where: { $0.contains(location) })
            ?? gapMissCellIndex(closestTo: location)
        guard let index else { return }
        eventDelegate?.gameScene(
            self,
            didTapCell: index,
            normalizedLocation: normalizedLocation,
            inputAt: inputAt,
            handledAt: handledAt
        )
    }

    private func gapMissCellIndex(closestTo location: CGPoint) -> Int? {
        guard let snapshot, cellFrames.count > 1 else { return nil }
        let excludedTarget = snapshot.state == .active ? snapshot.targetIndex : nil
        return cellFrames.indices
            .filter { $0 != excludedTarget }
            .min { lhs, rhs in
                squaredDistance(
                    from: location,
                    to: CGPoint(x: cellFrames[lhs].midX, y: cellFrames[lhs].midY)
                )
                    < squaredDistance(
                        from: location,
                        to: CGPoint(x: cellFrames[rhs].midX, y: cellFrames[rhs].midY)
                    )
            }
    }

    private func squaredDistance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let x = lhs.x - rhs.x
        let y = lhs.y - rhs.y
        return x * x + y * y
    }

    private func rebuildBoard() {
        guard let snapshot, size.width > 0, size.height > 0 else { return }
        removeAllChildren()
        cellFrames.removeAll(keepingCapacity: true)

        let dimension = snapshot.difficulty.gridDimension
        let layout = GameBoardLayout(size: size, dimension: dimension)
        boardFrame = layout.boardFrame

        for (index, cell) in snapshot.cells.enumerated() {
            let rect = layout.cellFrame(at: index, yAxis: .up)
            let cellSide = layout.cellSide
            let cornerRadius = GameCellVisualMetrics.liveCornerRadius(
                theme: theme,
                gridDimension: dimension
            )
            let node = SKShapeNode(rect: rect, cornerRadius: cornerRadius)
            node.name = "cell-\(index)"
            node.lineWidth = 2
            node.strokeColor =
                theme.id == "light"
                ? UIColor.white
                : UIColor(hexString: theme.accent).withAlphaComponent(0.18)
            node.fillColor = UIColor(hexString: theme.idleCell)
            var isLit = false
            var activeColorIndex: Int?

            if let colorIndex = cell.colorIndex,
                !(roundPresentationExpired && cell.kind == .target)
            {
                isLit = true
                activeColorIndex = colorIndex
                node.fillColor = theme.uiColor(at: colorIndex)
                node.strokeColor =
                    cell.kind == .target
                    ? UIColor.white.withAlphaComponent(0.85)
                    : UIColor.white.withAlphaComponent(0.35)
                node.lineWidth =
                    cell.kind == .target
                    ? GameCellVisualMetrics.targetBorderWidth
                    : GameCellVisualMetrics.activeBorderWidth
            }
            let finalBorderColor = node.strokeColor
            let finalBorderWidth = node.lineWidth
            if theme.id == "pixel" || theme.id == "disco" {
                node.strokeColor = .clear
                node.lineWidth = 0
            }
            node.zPosition = GameCellLayerOrder.cell
            addChild(node)
            if theme.id == "disco" {
                if activeColorIndex != nil {
                    addDiscoActiveMaterial(
                        in: rect,
                        cornerRadius: cornerRadius,
                        index: index
                    )
                }
                addDiscoWear(
                    in: rect,
                    cornerRadius: cornerRadius,
                    isLit: isLit,
                    index: index
                )
                addDiscoBorder(
                    in: rect,
                    cornerRadius: cornerRadius,
                    activeColor: activeColorIndex.map(theme.uiColor(at:)),
                    lineWidth: isLit ? finalBorderWidth : 2,
                    index: index
                )
            } else if theme.id == "light" {
                addLightGlass(in: rect, cornerRadius: cornerRadius, index: index)
            } else if theme.id == "pixel" {
                addPixelNoise(in: rect, cornerRadius: cornerRadius, seed: index)
                addPixelBorder(
                    in: rect,
                    cornerRadius: cornerRadius,
                    color: finalBorderColor,
                    lineWidth: finalBorderWidth,
                    index: index
                )
            }
            if let activeColorIndex, glyphsEnabled {
                addGlyph(
                    gameColors[activeColorIndex].glyph,
                    color: theme.cellInkUIColor(at: activeColorIndex),
                    in: rect,
                    cellSide: cellSide,
                    gridDimension: dimension,
                    index: index
                )
            }
            cellFrames.append(rect)
        }
    }

    private func addDiscoWear(
        in rect: CGRect,
        cornerRadius: CGFloat,
        isLit: Bool,
        index: Int
    ) {
        let texture = SKTexture(imageNamed: "disco-tile-overlay")
        texture.filteringMode = .linear

        let wear = SKSpriteNode(texture: texture)
        wear.size = rect.size
        wear.alpha =
            isLit
            ? DiscoThemeTokens.activeScratchOpacity
            : DiscoThemeTokens.idleScratchOpacity
        wear.blendMode = .screen

        let mask = SKShapeNode(rectOf: rect.size, cornerRadius: cornerRadius)
        mask.fillColor = .white
        mask.strokeColor = .clear
        mask.lineWidth = 0

        let crop = SKCropNode()
        crop.name = "cell-wear-\(index)"
        crop.position = CGPoint(x: rect.midX, y: rect.midY)
        crop.maskNode = mask
        crop.zPosition = GameCellLayerOrder.discoWear
        crop.addChild(wear)
        addChild(crop)
    }

    private func addDiscoActiveMaterial(
        in rect: CGRect,
        cornerRadius: CGFloat,
        index: Int
    ) {
        addClippedTexture(
            GameCellTextureFactory.discoActiveGlaze,
            name: "cell-\(index)-disco-active-glaze",
            in: rect,
            cornerRadius: cornerRadius,
            blendMode: .screen,
            zPosition: GameCellLayerOrder.discoMaterial
        )
        addClippedTexture(
            GameCellTextureFactory.discoActiveDepth,
            name: "cell-\(index)-disco-active-depth",
            in: rect,
            cornerRadius: cornerRadius,
            blendMode: .multiply,
            zPosition: GameCellLayerOrder.discoMaterial + 0.01
        )
    }

    private func addDiscoBorder(
        in rect: CGRect,
        cornerRadius: CGFloat,
        activeColor: UIColor?,
        lineWidth: CGFloat,
        index: Int
    ) {
        let border = SKShapeNode(rect: rect, cornerRadius: cornerRadius)
        border.name = "cell-\(index)-disco-border"
        border.fillColor = .clear
        border.strokeColor =
            activeColor.map(DiscoThemeTokens.activeBorderColor(for:))
            ?? UIColor(hexString: DiscoThemeTokens.cellBorderHex)
        border.lineWidth = lineWidth
        border.zPosition = GameCellLayerOrder.discoBorder
        addChild(border)
    }

    private func addLightGlass(in rect: CGRect, cornerRadius: CGFloat, index: Int) {
        addClippedTexture(
            GameCellTextureFactory.lightGlass,
            name: "cell-\(index)-light-glass",
            in: rect,
            cornerRadius: cornerRadius,
            blendMode: .screen,
            zPosition: 1.5
        )

        let inner = SKShapeNode(
            rect: rect.insetBy(dx: 2, dy: 2),
            cornerRadius: max(0, cornerRadius - 2)
        )
        inner.name = "cell-\(index)-light-inner-stroke"
        inner.fillColor = .clear
        inner.strokeColor = UIColor.white.withAlphaComponent(
            GameCellEffectTokens.lightInnerStrokeOpacity
        )
        inner.lineWidth = 1.5
        inner.zPosition = 1.6
        addChild(inner)
    }

    private func addPixelNoise(in rect: CGRect, cornerRadius: CGFloat, seed: Int) {
        addClippedTexture(
            GameCellTextureFactory.pixelNoise(seed: seed),
            name: "cell-\(seed)-pixel-noise",
            in: rect,
            cornerRadius: cornerRadius,
            blendMode: .alpha,
            zPosition: 1.5
        )
    }

    private func addPixelBorder(
        in rect: CGRect,
        cornerRadius: CGFloat,
        color: UIColor,
        lineWidth: CGFloat,
        index: Int
    ) {
        let border = SKShapeNode(rect: rect, cornerRadius: cornerRadius)
        border.name = "cell-\(index)-pixel-border"
        border.fillColor = .clear
        border.strokeColor = color
        border.lineWidth = lineWidth
        border.isAntialiased = false
        border.zPosition = 1.7
        addChild(border)
    }

    private func addGlyph(
        _ glyph: String,
        color: UIColor,
        in rect: CGRect,
        cellSide: CGFloat,
        gridDimension: Int,
        index: Int
    ) {
        let boxSide = GameCellVisualMetrics.glyphBoxSide(
            side: cellSide,
            minimumBaseSide: 24,
            scale: GameCellVisualMetrics.liveGlyphScale(gridDimension: gridDimension)
        )
        let glyphRect = CGRect(
            x: rect.midX - boxSide / 2,
            y: rect.midY - boxSide / 2,
            width: boxSide,
            height: boxSide
        )
        let style = GameCellSurfaceEffects.resolve(
            theme: theme,
            isLit: true,
            seed: index
        ).glyphStyle
        if let path = GameGlyphGeometry.path(
            for: glyph,
            in: glyphRect,
            style: style,
            yAxis: .up
        ) {
            let node = SKShapeNode(path: path)
            node.name = "cell-glyph-\(index)"
            node.fillColor = color
            node.strokeColor = .clear
            node.lineWidth = 0
            node.isAntialiased = style == .smooth
            node.zPosition = GameCellLayerOrder.glyph
            addChild(node)
            return
        }

        let fallback = SKLabelNode(text: glyph)
        fallback.name = "cell-glyph-\(index)"
        fallback.fontName = "AvenirNext-Heavy"
        fallback.fontSize = boxSide
        fallback.fontColor = color
        fallback.verticalAlignmentMode = .center
        fallback.horizontalAlignmentMode = .center
        fallback.position = CGPoint(x: rect.midX, y: rect.midY)
        fallback.zPosition = GameCellLayerOrder.glyph
        addChild(fallback)
    }

    private func addClippedTexture(
        _ texture: SKTexture,
        name: String,
        in rect: CGRect,
        cornerRadius: CGFloat,
        blendMode: SKBlendMode,
        zPosition: CGFloat
    ) {
        let sprite = SKSpriteNode(texture: texture)
        sprite.size = rect.size
        sprite.blendMode = blendMode

        let mask = SKShapeNode(rectOf: rect.size, cornerRadius: cornerRadius)
        mask.fillColor = .white
        mask.strokeColor = .clear
        mask.lineWidth = 0

        let crop = SKCropNode()
        crop.name = name
        crop.position = CGPoint(x: rect.midX, y: rect.midY)
        crop.maskNode = mask
        crop.zPosition = zPosition
        crop.addChild(sprite)
        addChild(crop)
    }
}

@MainActor
private enum GameCellTextureFactory {
    static let discoActiveGlaze = SKTexture(image: makeDiscoActiveGlazeImage())
    static let discoActiveDepth = SKTexture(image: makeDiscoActiveDepthImage())
    static let lightGlass = SKTexture(image: makeLightGlassImage())
    private static var pixelNoiseTextures: [Int: SKTexture] = [:]

    static func pixelNoise(seed: Int) -> SKTexture {
        if let cached = pixelNoiseTextures[seed] { return cached }
        let texture = SKTexture(image: makePixelNoiseImage(seed: seed))
        texture.filteringMode = .nearest
        pixelNoiseTextures[seed] = texture
        return texture
    }

    static func prewarmDisco() {
        discoActiveGlaze.filteringMode = .linear
        discoActiveDepth.filteringMode = .linear
    }

    private static func makeDiscoActiveGlazeImage() -> UIImage {
        render { context, size in
            let colors =
                [
                    UIColor.white.withAlphaComponent(
                        GameCellEffectTokens.discoCenterWhiteOpacity
                    ).cgColor,
                    UIColor.white.withAlphaComponent(
                        GameCellEffectTokens.discoMidpointWhiteOpacity
                    ).cgColor,
                    UIColor.clear.cgColor,
                ] as CFArray
            let locations: [CGFloat] = [0, 0.34, 0.64]
            guard
                let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors,
                    locations: locations
                )
            else { return }
            context.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                startRadius: 0,
                endCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                endRadius: size.width * 0.64,
                options: [.drawsAfterEndLocation]
            )

            let glazeColors =
                [
                    UIColor.white.withAlphaComponent(
                        GameCellEffectTokens.discoGlazeWhiteOpacity
                    ).cgColor,
                    UIColor.clear.cgColor,
                ] as CFArray
            if let glaze = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: glazeColors,
                locations: [0, 1]
            ) {
                context.drawLinearGradient(
                    glaze,
                    start: .zero,
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }
        }
    }

    private static func makeDiscoActiveDepthImage() -> UIImage {
        render { context, size in
            let colors =
                [
                    UIColor.clear.cgColor,
                    UIColor.black.withAlphaComponent(
                        GameCellEffectTokens.discoDepthOpacity
                    ).cgColor,
                ] as CFArray
            guard
                let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors,
                    locations: [0.35, 1]
                )
            else { return }
            context.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }
    }

    private static func makeLightGlassImage() -> UIImage {
        render { context, size in
            let colors =
                [
                    UIColor.white.withAlphaComponent(
                        GameCellEffectTokens.lightTopHighlightOpacity
                    ).cgColor,
                    UIColor.white.withAlphaComponent(0.08).cgColor,
                    UIColor(hexString: "#2e91b8").withAlphaComponent(
                        GameCellEffectTokens.lightLowerShadeOpacity
                    ).cgColor,
                ] as CFArray
            let locations: [CGFloat] = [0, 0.52, 1]
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: locations
            ) {
                context.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }

            context.setFillColor(
                UIColor.white.withAlphaComponent(
                    GameCellEffectTokens.lightSpecularOpacity
                ).cgColor
            )
            let band = CGMutablePath()
            band.move(to: CGPoint(x: size.width * 0.02, y: size.height * 0.36))
            band.addLine(to: CGPoint(x: size.width * 0.18, y: 0))
            band.addLine(to: CGPoint(x: size.width * 0.39, y: 0))
            band.addLine(to: CGPoint(x: size.width * 0.18, y: size.height * 0.48))
            band.closeSubpath()
            context.addPath(band)
            context.fillPath()
        }
    }

    private static func makePixelNoiseImage(seed: Int) -> UIImage {
        render { context, size in
            let pixel = PixelNoisePattern.squareSide(for: size.width)
            for sample in PixelNoisePattern.samples(seed: seed) {
                let rawX = CGFloat(sample.x) / CGFloat(PixelNoisePattern.gridSize) * size.width
                let rawY = CGFloat(sample.y) / CGFloat(PixelNoisePattern.gridSize) * size.height
                let rect = CGRect(
                    x: min(size.width - pixel, floor(rawX / pixel) * pixel),
                    y: min(size.height - pixel, floor(rawY / pixel) * pixel),
                    width: pixel,
                    height: pixel
                )
                context.setFillColor(
                    (sample.isLight
                        ? UIColor.white.withAlphaComponent(
                            GameCellEffectTokens.pixelLightNoiseOpacity
                        )
                        : UIColor.black.withAlphaComponent(
                            GameCellEffectTokens.pixelDarkNoiseOpacity
                        )).cgColor
                )
                context.fill(rect)
            }
        }
    }

    private static func render(
        drawing: (CGContext, CGSize) -> Void
    ) -> UIImage {
        let size = CGSize(width: 128, height: 128)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            drawing(rendererContext.cgContext, size)
        }
    }
}
