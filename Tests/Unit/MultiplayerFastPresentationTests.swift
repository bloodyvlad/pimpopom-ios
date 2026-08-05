import PimPoPomCore
import XCTest

@testable import PimPoPom

final class MultiplayerFastPresentationTests: XCTestCase {
    func testFiveContactBurstAllocatesOneInputIDForOneActivation() {
        var prediction = MultiplayerLocalInputPrediction()
        let activation = MultiplayerPresentedActivationID(kind: .target, entityID: 7)

        let first = prediction.begin(
            seat: 0,
            activationID: activation,
            tappedCell: 4,
            ownedTargetCell: 4,
            inputAt: 420
        )
        XCTAssertEqual(
            first,
            .accepted(MultiplayerInputID(seat: 0, inputSequence: 1))
        )
        for _ in 0..<4 {
            XCTAssertEqual(
                prediction.begin(
                    seat: 0,
                    activationID: activation,
                    tappedCell: 4,
                    ownedTargetCell: 4,
                    inputAt: 421
                ),
                .blocked(MultiplayerInputID(seat: 0, inputSequence: 1))
            )
        }
        XCTAssertEqual(prediction.nextInputSequence, 2)
    }

    func testOwnedTargetUsesConsumedOverlayWithinTheCaptureCall() {
        var prediction = MultiplayerLocalInputPrediction()
        _ = prediction.begin(
            seat: 0,
            activationID: .init(kind: .target, entityID: 7),
            tappedCell: 4,
            ownedTargetCell: 4,
            inputAt: 420
        )

        XCTAssertEqual(prediction.overlay, .consumedTarget(cell: 4))
        XCTAssertFalse(prediction.allowsInput)
    }

    func testWrongCellUsesNeutralPressureWithoutHidingTarget() {
        var prediction = MultiplayerLocalInputPrediction()
        _ = prediction.begin(
            seat: 0,
            activationID: .init(kind: .target, entityID: 7),
            tappedCell: 9,
            ownedTargetCell: 4,
            inputAt: 420
        )

        XCTAssertEqual(prediction.overlay, .neutralPressure(cell: 9))
        XCTAssertEqual(prediction.hiddenTargetCell, nil)
        XCTAssertFalse(prediction.allowsInput)
    }

    func testIgnoredResolutionRestoresPredictionOnce() {
        var prediction = MultiplayerLocalInputPrediction()
        guard
            case .accepted(let inputID) = prediction.begin(
                seat: 0,
                activationID: .init(kind: .target, entityID: 7),
                tappedCell: 4,
                ownedTargetCell: 4,
                inputAt: 420
            )
        else {
            return XCTFail("Expected the first input to be accepted.")
        }
        let resolution = MultiplayerInputResolution(
            inputID: inputID,
            disposition: .ignored(.staleTarget)
        )

        XCTAssertEqual(prediction.receive(resolution), .corrected)
        XCTAssertEqual(prediction.receive(resolution), .unchanged)
        XCTAssertNil(prediction.pendingInput)
        XCTAssertTrue(prediction.allowsInput)
    }

    func testCommittedResolutionKeepsActivationLatchedUntilCanonicalApply() {
        var prediction = MultiplayerLocalInputPrediction()
        guard
            case .accepted(let inputID) = prediction.begin(
                seat: 0,
                activationID: .init(kind: .target, entityID: 7),
                tappedCell: 4,
                ownedTargetCell: 4,
                inputAt: 420
            )
        else {
            return XCTFail("Expected the first input to be accepted.")
        }

        XCTAssertEqual(
            prediction.receive(
                MultiplayerInputResolution(
                    inputID: inputID,
                    disposition: .committed(eventSequence: 2)
                )
            ),
            .agreement
        )
        XCTAssertFalse(prediction.allowsInput)
        XCTAssertEqual(prediction.overlay, .consumedTarget(cell: 4))
        XCTAssertFalse(prediction.canonicalApplied(eventSequence: 1))
        XCTAssertTrue(prediction.canonicalApplied(eventSequence: 2))
        XCTAssertNil(prediction.pendingInput)
        XCTAssertTrue(prediction.allowsInput)
    }

    func testSnapshotNeverReopensTheSameStillActiveActivation() {
        var prediction = MultiplayerLocalInputPrediction()
        let activation = MultiplayerPresentedActivationID(kind: .target, entityID: 7)
        _ = prediction.begin(
            seat: 0,
            activationID: activation,
            tappedCell: 4,
            ownedTargetCell: 4,
            inputAt: 420
        )

        XCTAssertFalse(prediction.snapshotProvedActivationEnded(activation))
        XCTAssertFalse(prediction.allowsInput)
        XCTAssertTrue(
            prediction.snapshotProvedActivationEnded(
                .init(kind: .target, entityID: 8)
            )
        )
        XCTAssertTrue(prediction.allowsInput)
    }
}
