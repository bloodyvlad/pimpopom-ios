import PimPoPomCore
import SpriteKit
import SwiftUI

/// Keep physical contacts in SpriteKit while exposing the same cells to VoiceOver.
struct ArcadeSpriteBoard: UIViewRepresentable {
    let scene: GameScene
    let snapshot: GameSnapshot
    let roundPresentationExpired: Bool
    let preparing: Bool

    func makeUIView(context: Context) -> ArcadeSKView {
        let view = ArcadeSKView()
        view.renderer.presentScene(scene)
        return view
    }

    func updateUIView(_ view: ArcadeSKView, context: Context) {
        let state = ArcadeBoardAccessibilityState(
            dimension: snapshot.difficulty.gridDimension,
            cells: snapshot.cells,
            pickups: snapshot.activePickups.filter { scene.isPickupPresented($0.id) },
            roundPresentationExpired: roundPresentationExpired,
            enabled: !preparing && snapshot.state != .idle && snapshot.state != .gameOver
                && snapshot.recoveryRemainingMilliseconds <= 0)
        guard state != view.boardState else { return }
        view.boardState = state
        view.refreshAccessibility()
    }
}

struct ArcadeBoardAccessibilityState: Equatable {
    let dimension: Int
    let cells: [Cell]
    let pickups: [ArcadePickup]
    let roundPresentationExpired: Bool
    let enabled: Bool
}

final class ArcadeSKView: UIView {
    let renderer = SKView()
    var boardState: ArcadeBoardAccessibilityState?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isAccessibilityElement = false
        renderer.backgroundColor = .clear
        renderer.allowsTransparency = true
        renderer.ignoresSiblingOrder = true
        renderer.preferredFramesPerSecond = 60
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
        guard let state = boardState, let scene = renderer.scene as? GameScene else { return }
        let layout = GameBoardLayout(size: bounds.size, dimension: state.dimension)
        accessibilityElements = state.cells.enumerated().map { index, cell in
            let element = ArcadeCellAccessibilityElement(accessibilityContainer: self)
            let pickup = state.pickups.first { $0.cellIndex == index }
            element.accessibilityIdentifier = "arcade-cell-\(index)"
            if let pickup {
                element.accessibilityLabel =
                    pickup.kind == .heart
                    ? "Heart, restores one life, cell \(index + 1)"
                    : "Clock, slows pace by 30 percent, cell \(index + 1)"
            } else if cell.kind != .idle, !(cell.kind == .target && state.roundPresentationExpired),
                let color = cell.colorIndex, gameColors.indices.contains(color)
            {
                element.accessibilityLabel = "\(gameColors[color].name), cell \(index + 1)"
            } else {
                element.accessibilityLabel = "Inactive cell \(index + 1)"
            }
            element.accessibilityTraits = state.enabled ? .button : [.button, .notEnabled]
            element.accessibilityFrameInContainerSpace = layout.cellFrame(at: index, yAxis: .down)
            element.activate = { [weak scene] in
                guard state.enabled, let scene,
                    let point = scene.tapPoint(forCellAt: index, horizontalFraction: 0.5, verticalFraction: 0.5)
                else { return false }
                let now = ProcessInfo.processInfo.systemUptime * 1_000
                scene.handleBoardTouch(at: point, inputAt: now, handledAt: now)
                return true
            }
            return element
        }
    }
}

private final class ArcadeCellAccessibilityElement: UIAccessibilityElement {
    var activate: (() -> Bool)?
    override func accessibilityActivate() -> Bool { activate?() ?? false }
}
