import QuartzCore

struct MultiplayerDisplayFrame: Equatable, Sendable {
    let sequence: Int
    let callbackTimestamp: TimeInterval
    let targetTimestamp: TimeInterval
}

@MainActor
protocol MultiplayerFrameScheduling: AnyObject {
    var onFrame: ((MultiplayerDisplayFrame) -> Void)? { get set }

    func start()
    func stop()
}

@MainActor
final class MultiplayerDisplayLinkScheduler: NSObject, MultiplayerFrameScheduling {
    var onFrame: ((MultiplayerDisplayFrame) -> Void)?

    private var displayLink: CADisplayLink?
    private var frameSequence = 0

    func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(frameDidFire))
        link.preferredFramesPerSecond = 0
        link.add(to: .main, forMode: .common)
        displayLink = link
        frameSequence = 0
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func frameDidFire() {
        guard let displayLink else { return }
        frameSequence += 1
        onFrame?(
            MultiplayerDisplayFrame(
                sequence: frameSequence,
                callbackTimestamp: displayLink.timestamp,
                targetTimestamp: displayLink.targetTimestamp
            )
        )
    }
}
