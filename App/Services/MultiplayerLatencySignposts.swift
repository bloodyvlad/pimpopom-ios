import Foundation
import OSLog

struct MultiplayerLatencySampleID: Hashable, Sendable {
    fileprivate let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

enum MultiplayerLatencyEvent: Sendable {
    case touch
    case localAcknowledgement
    case targetFirstVisible
    case coordinatorReceipt
    case canonicalCommit
    case canonicalApplication
    case disposition

    fileprivate var signpostName: StaticString {
        switch self {
        case .touch: "Touch"
        case .localAcknowledgement: "LocalAcknowledgement"
        case .targetFirstVisible: "TargetFirstVisible"
        case .coordinatorReceipt: "CoordinatorReceipt"
        case .canonicalCommit: "CanonicalCommit"
        case .canonicalApplication: "CanonicalApplication"
        case .disposition: "Disposition"
        }
    }
}

@MainActor
protocol MultiplayerLatencyRecording: AnyObject {
    func record(
        _ event: MultiplayerLatencyEvent,
        sampleID: MultiplayerLatencySampleID,
        monotonicMilliseconds: Int,
        frameSequence: Int?
    )
}

@MainActor
final class MultiplayerNoopLatencyRecorder: MultiplayerLatencyRecording {
    func record(
        _: MultiplayerLatencyEvent,
        sampleID _: MultiplayerLatencySampleID,
        monotonicMilliseconds _: Int,
        frameSequence _: Int?
    ) {}
}

#if DEBUG
    @MainActor
    final class MultiplayerDebugLatencyRecorder: MultiplayerLatencyRecording {
        private let signposter = OSSignposter(
            subsystem: "com.otcsoftware.pimpopom",
            category: "MultiplayerLatency"
        )
        private var signpostIDBySample: [MultiplayerLatencySampleID: OSSignpostID] = [:]

        func record(
            _ event: MultiplayerLatencyEvent,
            sampleID: MultiplayerLatencySampleID,
            monotonicMilliseconds: Int,
            frameSequence: Int?
        ) {
            let signpostID = signpostIDBySample[sampleID] ?? signposter.makeSignpostID()
            signpostIDBySample[sampleID] = signpostID
            signposter.emitEvent(
                event.signpostName,
                id: signpostID,
                "monotonic_ms=\(monotonicMilliseconds) frame=\(frameSequence ?? -1)"
            )
        }
    }
#endif

@MainActor
enum MultiplayerLatencyRecorderFactory {
    static func make() -> any MultiplayerLatencyRecording {
        #if DEBUG
            MultiplayerDebugLatencyRecorder()
        #else
            MultiplayerNoopLatencyRecorder()
        #endif
    }
}
