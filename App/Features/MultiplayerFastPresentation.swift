import PimPoPomCore

enum MultiplayerPresentedActivationKind: String, Codable, Equatable, Sendable {
    case target
    case decoy
}

struct MultiplayerPresentedActivationID: Codable, Equatable, Hashable, Sendable {
    let kind: MultiplayerPresentedActivationKind
    let entityID: Int
}

enum MultiplayerLocalPredictionOverlay: Equatable, Sendable {
    case consumedTarget(cell: Int)
    case neutralPressure(cell: Int)
}

struct MultiplayerPendingLocalInput: Equatable, Sendable {
    let inputID: MultiplayerInputID
    let activationID: MultiplayerPresentedActivationID
    let tappedCell: Int
    let inputAt: Int
    let overlay: MultiplayerLocalPredictionOverlay
    var committedEventSequence: Int?
}

enum MultiplayerLocalInputCapture: Equatable, Sendable {
    case accepted(MultiplayerInputID)
    case blocked(MultiplayerInputID)
}

enum MultiplayerLocalReconciliation: Equatable, Sendable {
    case agreement
    case corrected
    case unchanged
}

struct MultiplayerLocalInputPrediction: Equatable, Sendable {
    private(set) var nextInputSequence = 1
    private(set) var pendingInput: MultiplayerPendingLocalInput?

    var overlay: MultiplayerLocalPredictionOverlay? {
        pendingInput?.overlay
    }

    var hiddenTargetCell: Int? {
        guard case .consumedTarget(let cell) = overlay else { return nil }
        return cell
    }

    var allowsInput: Bool { pendingInput == nil }

    mutating func begin(
        seat: Int,
        activationID: MultiplayerPresentedActivationID,
        tappedCell: Int,
        ownedTargetCell: Int?,
        inputAt: Int
    ) -> MultiplayerLocalInputCapture {
        if let pendingInput {
            return .blocked(pendingInput.inputID)
        }
        let inputID = MultiplayerInputID(
            seat: seat,
            inputSequence: nextInputSequence
        )
        nextInputSequence += 1
        let overlay: MultiplayerLocalPredictionOverlay =
            tappedCell == ownedTargetCell
            ? .consumedTarget(cell: tappedCell)
            : .neutralPressure(cell: tappedCell)
        pendingInput = MultiplayerPendingLocalInput(
            inputID: inputID,
            activationID: activationID,
            tappedCell: tappedCell,
            inputAt: inputAt,
            overlay: overlay,
            committedEventSequence: nil
        )
        return .accepted(inputID)
    }

    mutating func receive(
        _ resolution: MultiplayerInputResolution
    ) -> MultiplayerLocalReconciliation {
        guard var pendingInput,
            pendingInput.inputID == resolution.inputID
        else { return .unchanged }
        switch resolution.disposition {
        case .committed(let eventSequence):
            if pendingInput.committedEventSequence == eventSequence {
                return .unchanged
            }
            pendingInput.committedEventSequence = eventSequence
            self.pendingInput = pendingInput
            return .agreement
        case .ignored:
            self.pendingInput = nil
            return .corrected
        }
    }

    mutating func canonicalApplied(eventSequence: Int) -> Bool {
        guard pendingInput?.committedEventSequence == eventSequence else {
            return false
        }
        pendingInput = nil
        return true
    }

    mutating func snapshotProvedActivationEnded(
        _ activeActivationID: MultiplayerPresentedActivationID?
    ) -> Bool {
        guard let pendingInput else { return false }
        guard pendingInput.activationID != activeActivationID else { return false }
        self.pendingInput = nil
        return true
    }

    mutating func reset() {
        nextInputSequence = 1
        pendingInput = nil
    }
}
