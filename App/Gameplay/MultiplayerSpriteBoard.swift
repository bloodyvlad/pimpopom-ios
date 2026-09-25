import PimPoPomCore
import SpriteKit
import SwiftUI

/// Physical touches go straight to the shared Arcade scene. Accessibility
/// activates that same path instead of maintaining a second hit-test grid.
struct MultiplayerSpriteBoard: UIViewRepresentable {
    let scene: GameScene
    let state: MultiplayerPresentation.LiveMatchState

    func makeUIView(context: Context) -> MultiplayerSKView {
        let view = MultiplayerSKView()
        view.backgroundColor = .clear
        view.renderer.allowsTransparency = true
        view.renderer.preferredFramesPerSecond = 60
        view.renderer.presentScene(scene)
        return view
    }

    func updateUIView(_ view: MultiplayerSKView, context: Context) {
        guard view.boardState != state else { return }
        view.boardState = state
        view.refreshAccessibility()
    }
}

final class MultiplayerSKView: UIView {
    let renderer = SKView()
    var boardState: MultiplayerPresentation.LiveMatchState?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        renderer.backgroundColor = .clear
        renderer.accessibilityElementsHidden = true
        addSubview(renderer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        renderer.frame = bounds
        refreshAccessibility()
    }

    func refreshAccessibility() {
        guard let boardState, let scene = renderer.scene as? GameScene else { return }
        let layout = GameBoardLayout(size: bounds.size, dimension: boardState.gridDimension)
        accessibilityElements = boardState.orderedCells.map { cell in
            let element = MultiplayerBoardAccessibilityElement(accessibilityContainer: self)
            element.accessibilityIdentifier = "multiplayer-cell-\(cell.id)"
            element.accessibilityLabel =
                cell.isHeart
                ? "Heart, cell \(cell.id + 1), first player to tap restores one life"
                : cell.isDecoy
                    ? "Decoy, cell \(cell.id + 1)"
                    : cell.isTarget
                        ? (cell.ownerSeat == boardState.localSeat ? "Your active target" : "Other player's target")
                        : "Inactive cell \(cell.id + 1)"
            element.accessibilityTraits = boardState.isSpectating ? [.button, .notEnabled] : .button
            element.accessibilityFrameInContainerSpace = layout.cellFrame(at: cell.id, yAxis: .down)
            element.activate = { [weak scene] in
                guard !boardState.isSpectating, let scene,
                    let point = scene.tapPoint(forCellAt: cell.id, horizontalFraction: 0.5, verticalFraction: 0.5)
                else { return false }
                let now = ProcessInfo.processInfo.systemUptime * 1_000
                scene.handleBoardTouch(at: point, inputAt: now, handledAt: now)
                return true
            }
            return element
        }
    }
}

private final class MultiplayerBoardAccessibilityElement: UIAccessibilityElement {
    var activate: (() -> Bool)?
    override func accessibilityActivate() -> Bool { activate?() ?? false }
}
