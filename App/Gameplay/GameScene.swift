import PimPoPomCore
import SpriteKit
import UIKit

@MainActor
protocol GameSceneEventDelegate: AnyObject {
    func gameScene(_ scene: GameScene, requestsRoundActivationAt milliseconds: Double)
    func gameScene(_ scene: GameScene, requestsDecoyActivationAt milliseconds: Double)
    func gameScene(_ scene: GameScene, didAdvanceTo milliseconds: Double)
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
        guard let touch = touches.first,
            snapshot != nil,
            boardFrame.contains(touch.location(in: self))
        else { return }
        let location = touch.location(in: self)
        guard let index = cellFrames.firstIndex(where: { $0.contains(location) }) else { return }
        let normalizedLocation = CGPoint(
            x: min(1, max(0, location.x / max(size.width, 1))),
            y: min(1, max(0, 1 - (location.y / max(size.height, 1))))
        )
        let handledAt = ProcessInfo.processInfo.systemUptime * 1_000
        eventDelegate?.gameScene(
            self,
            didTapCell: index,
            normalizedLocation: normalizedLocation,
            inputAt: touch.timestamp * 1_000,
            handledAt: handledAt
        )
    }

    private func rebuildBoard() {
        guard let snapshot, size.width > 0, size.height > 0 else { return }
        removeAllChildren()
        cellFrames.removeAll(keepingCapacity: true)

        let boardSide = min(size.width, size.height) - 8
        boardFrame = CGRect(
            x: (size.width - boardSide) / 2,
            y: (size.height - boardSide) / 2,
            width: boardSide,
            height: boardSide
        )
        let dimension = snapshot.difficulty.gridDimension
        let gap = dimension == 4 ? CGFloat(5) : CGFloat(8)
        let cellSide = (boardSide - gap * CGFloat(dimension - 1)) / CGFloat(dimension)

        for (index, cell) in snapshot.cells.enumerated() {
            let rowFromTop = index / dimension
            let column = index % dimension
            let rowFromBottom = dimension - 1 - rowFromTop
            let rect = CGRect(
                x: boardFrame.minX + CGFloat(column) * (cellSide + gap),
                y: boardFrame.minY + CGFloat(rowFromBottom) * (cellSide + gap),
                width: cellSide,
                height: cellSide
            )
            let cornerRadius = GameCellVisualMetrics.cornerRadius(
                theme: theme,
                side: cellSide,
                minimum: 12
            )
            let node = SKShapeNode(rect: rect, cornerRadius: cornerRadius)
            node.name = "cell-\(index)"
            node.lineWidth = 2
            node.strokeColor =
                theme.id == "disco"
                ? UIColor(hexString: DiscoThemeTokens.cellBorderHex)
                : theme.id == "light"
                    ? UIColor.white
                    : UIColor(hexString: theme.accent).withAlphaComponent(0.18)
            node.fillColor = UIColor(hexString: theme.idleCell)
            var isLit = false

            if let colorIndex = cell.colorIndex,
                !(roundPresentationExpired && cell.kind == .target)
            {
                isLit = true
                let spec = gameColors[colorIndex]
                node.fillColor = theme.uiColor(at: colorIndex)
                node.strokeColor =
                    theme.id == "disco"
                    ? UIColor(hexString: DiscoThemeTokens.activeBorderHex)
                    : cell.kind == .target
                        ? UIColor.white.withAlphaComponent(0.85)
                        : UIColor.white.withAlphaComponent(0.35)
                node.lineWidth =
                    cell.kind == .target
                    ? GameCellVisualMetrics.targetBorderWidth
                    : GameCellVisualMetrics.activeBorderWidth
                if theme.id == "disco" {
                    node.glowWidth = cell.kind == .target ? 6 : 3
                }

                if glyphsEnabled {
                    let glyph = SKLabelNode(text: spec.glyph)
                    glyph.fontName = theme.isPixel ? "Jersey10-Regular" : "AvenirNext-Heavy"
                    glyph.fontSize = GameCellVisualMetrics.glyphSize(
                        theme: theme,
                        side: cellSide,
                        minimumBaseSize: 24
                    )
                    glyph.fontColor = theme.cellInkUIColor(at: colorIndex)
                    glyph.verticalAlignmentMode = .center
                    glyph.horizontalAlignmentMode = .center
                    glyph.position = CGPoint(x: rect.midX, y: rect.midY)
                    glyph.zPosition = 2
                    addChild(glyph)
                }
            }
            node.zPosition = 1
            addChild(node)
            if theme.id == "disco" {
                addDiscoWear(
                    in: rect,
                    cornerRadius: cornerRadius,
                    isLit: isLit,
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
        wear.blendMode = isLit ? .screen : .multiply

        let mask = SKShapeNode(rectOf: rect.size, cornerRadius: cornerRadius)
        mask.fillColor = .white
        mask.strokeColor = .clear
        mask.lineWidth = 0

        let crop = SKCropNode()
        crop.name = "cell-wear-\(index)"
        crop.position = CGPoint(x: rect.midX, y: rect.midY)
        crop.maskNode = mask
        crop.zPosition = 1.5
        crop.addChild(wear)
        addChild(crop)
    }
}
