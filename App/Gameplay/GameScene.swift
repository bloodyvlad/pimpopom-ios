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
        let handledAt = ProcessInfo.processInfo.systemUptime * 1_000
        eventDelegate?.gameScene(
            self,
            didTapCell: index,
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
            let cornerRadius = theme.isPixel ? CGFloat.zero : max(12, cellSide * 0.10)
            let node = SKShapeNode(rect: rect, cornerRadius: cornerRadius)
            node.name = "cell-\(index)"
            node.lineWidth = 2
            node.strokeColor = UIColor(hexString: theme.accent).withAlphaComponent(0.18)
            node.fillColor = UIColor(hexString: theme.idleCell)

            if let colorIndex = cell.colorIndex,
                !(roundPresentationExpired && cell.kind == .target)
            {
                let spec = gameColors[colorIndex]
                node.fillColor = theme.uiColor(at: colorIndex)
                node.strokeColor =
                    cell.kind == .target
                    ? UIColor.white.withAlphaComponent(0.85)
                    : UIColor.white.withAlphaComponent(0.35)
                node.lineWidth = cell.kind == .target ? 4 : 2

                let glyph = SKLabelNode(text: spec.glyph)
                glyph.fontName = theme.isPixel ? "Menlo-Bold" : "AvenirNext-Heavy"
                glyph.fontSize = max(24, cellSide * 0.30)
                glyph.fontColor = theme.cellInkUIColor(at: colorIndex)
                glyph.verticalAlignmentMode = .center
                glyph.horizontalAlignmentMode = .center
                glyph.position = CGPoint(x: rect.midX, y: rect.midY)
                glyph.zPosition = 2
                addChild(glyph)
            }
            node.zPosition = 1
            addChild(node)
            cellFrames.append(rect)
        }
    }
}
