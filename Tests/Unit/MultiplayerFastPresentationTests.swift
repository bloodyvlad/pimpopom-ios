import PimPoPomCore
import XCTest

@testable import PimPoPom

final class MultiplayerFastPresentationTests: XCTestCase {
    func testLocalCanonicalHitUsesTheSinglePlayerPointsAndRatingFlyoutModel() throws {
        let hit = MultiplayerEvent.hit(
            sequence: 9,
            inputAt: 700,
            handledAt: 710,
            seat: 0,
            targetId: 7,
            cell: 6
        )

        XCTAssertEqual(
            MultiplayerHitFeedbackPresentation.make(
                event: hit,
                targetPresentedAt: 500,
                localSeat: 0,
                scoreBefore: 1_000,
                scoreAfter: 1_541,
                normalizedLocation: CGPoint(x: 0.625, y: 0.375)
            ),
            GameplayHitFeedbackEvent(
                id: 9,
                rating: .godlike,
                milliseconds: 200,
                pointsAwarded: 541,
                normalizedLocation: CGPoint(x: 0.625, y: 0.375)
            )
        )
        XCTAssertNil(
            MultiplayerHitFeedbackPresentation.make(
                event: hit,
                targetPresentedAt: 500,
                localSeat: 1,
                scoreBefore: 0,
                scoreAfter: 0,
                normalizedLocation: CGPoint(x: 0.625, y: 0.375)
            )
        )
    }

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

    func testLocalAcknowledgementUsesFirstDisplayFrameAndStableOpaqueSample() {
        let inputID = MultiplayerInputID(seat: 0, inputSequence: 1)
        let sampleID = MultiplayerLatencySampleID(
            rawValue: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        )
        let firstFrame = MultiplayerDisplayFrame(
            sequence: 41,
            callbackTimestamp: 1.0,
            targetTimestamp: 1.008
        )
        var correlation = MultiplayerLocalLatencyCorrelation()

        correlation.arm(inputID: inputID, sampleID: sampleID)
        XCTAssertEqual(correlation.sampleID(for: inputID), sampleID)
        let acknowledgement = correlation.takeAcknowledgement(on: firstFrame)
        XCTAssertEqual(acknowledgement?.0, sampleID)
        XCTAssertEqual(acknowledgement?.1.sequence, 41)
        XCTAssertNil(
            correlation.takeAcknowledgement(
                on: MultiplayerDisplayFrame(
                    sequence: 42,
                    callbackTimestamp: 1.008,
                    targetTimestamp: 1.016
                )
            )
        )
    }

    func testPendingCellCarriesStableActivationIdentityWithoutChangingAuthority() {
        let activation = MultiplayerPresentedActivationID(kind: .target, entityID: 7)
        let cell = MultiplayerPresentation.Cell(
            id: 4,
            colorIndex: 0,
            ownerSeat: 0,
            isTarget: true,
            activationID: activation,
            isPendingLocalInput: true
        )

        XCTAssertEqual(cell.activationID, activation)
        XCTAssertTrue(cell.isPendingLocalInput)
        XCTAssertTrue(cell.isTarget)
        XCTAssertEqual(cell.ownerSeat, 0)
    }

    func testPresentationPublicationSuppressesElapsedOnlyDisplayFrames() {
        let first = liveState(elapsedMilliseconds: 100)
        let elapsedOnly = liveState(elapsedMilliseconds: 108)
        var changedCells = first.cells
        changedCells[0] = MultiplayerPresentation.Cell(
            id: 0,
            colorIndex: nil,
            isPendingLocalInput: true
        )
        let changed = MultiplayerPresentation.LiveMatchState(
            matchID: first.matchID,
            elapsedMilliseconds: 108,
            cells: changedCells,
            players: first.players,
            localSeat: first.localSeat,
            streakSteps: first.streakSteps,
            isRecovering: first.isRecovering,
            announcement: first.announcement,
            inputMode: first.inputMode
        )
        let feedbackOnly = MultiplayerPresentation.LiveMatchState(
            matchID: first.matchID,
            elapsedMilliseconds: 108,
            cells: first.cells,
            players: first.players,
            localSeat: first.localSeat,
            streakSteps: first.streakSteps,
            isRecovering: first.isRecovering,
            announcement: first.announcement,
            hitFeedbackEvent: GameplayHitFeedbackEvent(
                id: 4,
                rating: .great,
                milliseconds: 400,
                pointsAwarded: 424,
                normalizedLocation: CGPoint(x: 0.5, y: 0.5)
            ),
            inputMode: first.inputMode
        )

        XCTAssertFalse(
            MultiplayerPresentationPublicationPolicy.shouldPublish(
                previous: first,
                next: elapsedOnly
            )
        )
        XCTAssertTrue(
            MultiplayerPresentationPublicationPolicy.shouldPublish(
                previous: first,
                next: changed
            )
        )
        XCTAssertTrue(
            MultiplayerPresentationPublicationPolicy.shouldPublish(
                previous: first,
                next: feedbackOnly
            )
        )
    }

    func testResolutionWatchdogRequestsRecoveryThenCancelsWithoutReopening() {
        let inputID = MultiplayerInputID(seat: 0, inputSequence: 1)
        var watchdog = MultiplayerResolutionWatchdog()
        watchdog.begin(inputID: inputID, monotonicMilliseconds: 100)

        XCTAssertEqual(
            watchdog.action(
                monotonicMilliseconds: 249,
                recoveryBudgetMilliseconds: 150
            ),
            .none
        )
        XCTAssertEqual(
            watchdog.action(
                monotonicMilliseconds: 250,
                recoveryBudgetMilliseconds: 150
            ),
            .requestSnapshot(inputID)
        )
        XCTAssertEqual(
            watchdog.action(
                monotonicMilliseconds: 399,
                recoveryBudgetMilliseconds: 150
            ),
            .none
        )
        XCTAssertEqual(
            watchdog.action(
                monotonicMilliseconds: 400,
                recoveryBudgetMilliseconds: 150
            ),
            .cancelWithoutSettlement(inputID)
        )
        XCTAssertEqual(watchdog.inputID, inputID)
    }

    func testTerminalDrainWaitsForEveryDeclaredInputAcrossAllSeats() throws {
        var drain = try MultiplayerTerminalDrainTracker(seats: [0, 1, 2])
        try drain.recordEvidence(
            MultiplayerSealedInput(
                id: MultiplayerInputID(seat: 0, inputSequence: 1),
                cell: 4,
                inputAt: 80
            )
        )
        try drain.recordEvidence(
            MultiplayerSealedInput(
                id: MultiplayerInputID(seat: 1, inputSequence: 1),
                cell: 5,
                inputAt: 90
            )
        )
        try drain.recordTerminalSeal(
            MultiplayerInputSeal(
                seat: 0,
                throughInputAt: 100,
                highestInputSequence: 1
            )
        )
        try drain.recordTerminalSeal(
            MultiplayerInputSeal(
                seat: 1,
                throughInputAt: 100,
                highestInputSequence: 2
            )
        )
        try drain.recordTerminalSeal(
            MultiplayerInputSeal(
                seat: 2,
                throughInputAt: 100,
                highestInputSequence: 0
            )
        )

        XCTAssertFalse(drain.isComplete)
        XCTAssertEqual(
            drain.missingInputIDs,
            [MultiplayerInputID(seat: 1, inputSequence: 2)]
        )

        try drain.recordEvidence(
            MultiplayerSealedInput(
                id: MultiplayerInputID(seat: 1, inputSequence: 2),
                cell: 6,
                inputAt: 100
            )
        )
        XCTAssertTrue(drain.isComplete)
    }

    func testTerminalSealRejectsEvidenceCreatedAfterTheSeatStoppedInput() throws {
        var drain = try MultiplayerTerminalDrainTracker(seats: [0, 1])
        try drain.recordTerminalSeal(
            MultiplayerInputSeal(
                seat: 1,
                throughInputAt: 100,
                highestInputSequence: 1
            )
        )

        XCTAssertThrowsError(
            try drain.recordEvidence(
                MultiplayerSealedInput(
                    id: MultiplayerInputID(seat: 1, inputSequence: 2),
                    cell: 6,
                    inputAt: 101
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? MultiplayerTerminalDrainError,
                .evidenceAfterTerminalSeal(
                    MultiplayerInputID(seat: 1, inputSequence: 2)
                )
            )
        }
    }

    private func liveState(
        elapsedMilliseconds: Int
    ) -> MultiplayerPresentation.LiveMatchState {
        MultiplayerPresentation.LiveMatchState(
            matchID: "match",
            elapsedMilliseconds: elapsedMilliseconds,
            cells: (0..<16).map {
                MultiplayerPresentation.Cell(id: $0, colorIndex: nil)
            },
            players: [],
            localSeat: 0,
            streakSteps: 0,
            isRecovering: false,
            announcement: nil,
            inputMode: .interactive
        )
    }
}
