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

    func testUnresolvedEarlierActivationDoesNotBlockTheNextPresentedActivation() {
        var prediction = MultiplayerLocalInputPrediction()
        let firstActivation = MultiplayerPresentedActivationID(kind: .target, entityID: 7)
        let secondActivation = MultiplayerPresentedActivationID(kind: .target, entityID: 8)

        XCTAssertEqual(
            prediction.begin(
                seat: 0,
                activationID: firstActivation,
                tappedCell: 4,
                ownedTargetCell: 4,
                inputAt: 420
            ),
            .accepted(MultiplayerInputID(seat: 0, inputSequence: 1))
        )
        XCTAssertEqual(
            prediction.begin(
                seat: 0,
                activationID: secondActivation,
                tappedCell: 4,
                ownedTargetCell: 4,
                inputAt: 650
            ),
            .accepted(MultiplayerInputID(seat: 0, inputSequence: 2))
        )
        XCTAssertEqual(
            prediction.begin(
                seat: 0,
                activationID: secondActivation,
                tappedCell: 4,
                ownedTargetCell: 4,
                inputAt: 651
            ),
            .blocked(MultiplayerInputID(seat: 0, inputSequence: 2))
        )
        XCTAssertTrue(prediction.hasPendingInputs)
        XCTAssertEqual(prediction.latestPendingInputAt, 650)
        XCTAssertFalse(prediction.allowsInput(for: secondActivation))
    }

    func testHiddenPreviousTargetDoesNotOwnSelectionOverVisibleNextTarget() {
        let previous = MultiplayerPresentedActivationID(kind: .target, entityID: 7)
        let next = MultiplayerPresentedActivationID(kind: .target, entityID: 8)
        let candidates = [
            MultiplayerPresentedTargetCandidate(
                activationID: next,
                presentedAt: 1_200,
                cell: 5,
                colorIndex: 1,
                ownerSeat: 1
            ),
            MultiplayerPresentedTargetCandidate(
                activationID: previous,
                presentedAt: 1_000,
                cell: 4,
                colorIndex: 0,
                ownerSeat: 0
            ),
        ]

        XCTAssertEqual(
            MultiplayerPresentedTargetSelection.latest(in: candidates)?.activationID,
            next
        )
    }

    func testPausedRecoveryAcceptsFutureInputThroughTheFifteenSecondWindow() {
        XCTAssertEqual(
            MultiplayerInputAdmissionPolicy.maximumAcceptedInputAt(
                currentLogicalMilliseconds: 10_000,
                isPausedForRecovery: false,
                recoveryLimitMilliseconds: 15_000
            ),
            12_000
        )
        XCTAssertEqual(
            MultiplayerInputAdmissionPolicy.maximumAcceptedInputAt(
                currentLogicalMilliseconds: 10_000,
                isPausedForRecovery: true,
                recoveryLimitMilliseconds: 15_000
            ),
            25_000
        )
    }

    func testConsumedEarlierActivationDoesNotHideAReusedCellForTheNextActivation() {
        var prediction = MultiplayerLocalInputPrediction()
        let firstActivation = MultiplayerPresentedActivationID(kind: .target, entityID: 7)
        let secondActivation = MultiplayerPresentedActivationID(kind: .target, entityID: 8)
        _ = prediction.begin(
            seat: 0,
            activationID: firstActivation,
            tappedCell: 4,
            ownedTargetCell: 4,
            inputAt: 420
        )

        XCTAssertTrue(prediction.hidesTarget(for: firstActivation))
        XCTAssertFalse(prediction.hidesTarget(for: secondActivation))
        XCTAssertEqual(
            prediction.overlay(for: firstActivation),
            .consumedTarget(cell: 4)
        )
        XCTAssertNil(prediction.overlay(for: secondActivation))
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

    func testActivationEndingDoesNotEraseAnUnresolvedInput() {
        var prediction = MultiplayerLocalInputPrediction()
        let activation = MultiplayerPresentedActivationID(kind: .target, entityID: 7)
        _ = prediction.begin(
            seat: 0,
            activationID: activation,
            tappedCell: 4,
            ownedTargetCell: 4,
            inputAt: 420
        )

        XCTAssertNotNil(prediction.pendingInput(for: activation))
        XCTAssertTrue(prediction.hasPendingInputs)
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

    func testResolutionWatchdogRequestsAtOneSecondAndCancelsAtFifteenSeconds() {
        let inputID = MultiplayerInputID(seat: 0, inputSequence: 1)
        var watchdog = MultiplayerResolutionWatchdog()
        watchdog.begin(inputID: inputID, monotonicMilliseconds: 100)

        XCTAssertEqual(
            watchdog.action(
                monotonicMilliseconds: 1_099,
                noticeAfterMilliseconds: 1_000,
                cancelAfterMilliseconds: 15_000
            ),
            .none
        )
        XCTAssertEqual(
            watchdog.action(
                monotonicMilliseconds: 1_100,
                noticeAfterMilliseconds: 1_000,
                cancelAfterMilliseconds: 15_000
            ),
            .requestSnapshot(inputID)
        )
        XCTAssertEqual(
            watchdog.action(
                monotonicMilliseconds: 15_099,
                noticeAfterMilliseconds: 1_000,
                cancelAfterMilliseconds: 15_000
            ),
            .none
        )
        XCTAssertEqual(
            watchdog.action(
                monotonicMilliseconds: 15_100,
                noticeAfterMilliseconds: 1_000,
                cancelAfterMilliseconds: 15_000
            ),
            .cancelWithoutSettlement(inputID)
        )
        XCTAssertTrue(watchdog.hasPendingInputs)
    }

    func testResolutionWatchdogRetainsMultipleInputsAndResolutionStopsOneEntry() {
        let first = MultiplayerInputID(seat: 0, inputSequence: 1)
        let second = MultiplayerInputID(seat: 0, inputSequence: 2)
        var watchdog = MultiplayerResolutionWatchdog()
        watchdog.begin(inputID: first, monotonicMilliseconds: 100)
        watchdog.begin(inputID: second, monotonicMilliseconds: 600)

        XCTAssertEqual(
            watchdog.action(
                monotonicMilliseconds: 1_100,
                noticeAfterMilliseconds: 1_000,
                cancelAfterMilliseconds: 15_000
            ),
            .requestSnapshot(first)
        )
        watchdog.resolve(first)
        XCTAssertEqual(
            watchdog.action(
                monotonicMilliseconds: 1_600,
                noticeAfterMilliseconds: 1_000,
                cancelAfterMilliseconds: 15_000
            ),
            .requestSnapshot(second)
        )
        XCTAssertEqual(watchdog.pendingInputIDs, [second])
    }

    func testRecoveryWindowIsSilentForOneSecondAndExpiresAtFifteenSeconds() {
        XCTAssertEqual(
            MultiplayerRecoveryWindow.phase(
                now: 1_099,
                beganAt: 100,
                noticeAfterMilliseconds: 1_000,
                cancelAfterMilliseconds: 15_000
            ),
            .silent
        )
        XCTAssertEqual(
            MultiplayerRecoveryWindow.phase(
                now: 1_100,
                beganAt: 100,
                noticeAfterMilliseconds: 1_000,
                cancelAfterMilliseconds: 15_000
            ),
            .visible
        )
        XCTAssertEqual(
            MultiplayerRecoveryWindow.phase(
                now: 15_099,
                beganAt: 100,
                noticeAfterMilliseconds: 1_000,
                cancelAfterMilliseconds: 15_000
            ),
            .visible
        )
        XCTAssertEqual(
            MultiplayerRecoveryWindow.phase(
                now: 15_100,
                beganAt: 100,
                noticeAfterMilliseconds: 1_000,
                cancelAfterMilliseconds: 15_000
            ),
            .expired
        )
    }

    func testFutureFinishStartsTheSameBoundedCanonicalRecoveryWindow() {
        XCTAssertTrue(
            MultiplayerPeerCanonicalRecoveryPolicy.isRequired(
                pendingBatchCount: 0,
                hasPendingSnapshot: false,
                isSnapshotAssemblyPending: false,
                pendingFinishEventSequence: 11,
                transcriptEventCount: 10
            )
        )
        XCTAssertFalse(
            MultiplayerPeerCanonicalRecoveryPolicy.isRequired(
                pendingBatchCount: 0,
                hasPendingSnapshot: false,
                isSnapshotAssemblyPending: false,
                pendingFinishEventSequence: 10,
                transcriptEventCount: 10
            )
        )
        XCTAssertEqual(
            MultiplayerRecoveryWindow.phase(
                now: 1_099,
                beganAt: 100,
                noticeAfterMilliseconds: 1_000,
                cancelAfterMilliseconds: 15_000
            ),
            .silent
        )
        XCTAssertEqual(
            MultiplayerRecoveryWindow.phase(
                now: 1_100,
                beganAt: 100,
                noticeAfterMilliseconds: 1_000,
                cancelAfterMilliseconds: 15_000
            ),
            .visible
        )
        XCTAssertEqual(
            MultiplayerRecoveryWindow.phase(
                now: 15_100,
                beganAt: 100,
                noticeAfterMilliseconds: 1_000,
                cancelAfterMilliseconds: 15_000
            ),
            .expired
        )
    }

    func testResolutionOnlyRecoveryRetriesSnapshotsAtTheBoundedCadence() {
        XCTAssertTrue(
            MultiplayerSnapshotRecoveryRequestPolicy.shouldRequest(
                isCoordinator: false,
                hasPeerCanonicalRecovery: false,
                hasResolutionRecovery: true,
                now: 100,
                lastRequestAt: nil
            )
        )
        XCTAssertFalse(
            MultiplayerSnapshotRecoveryRequestPolicy.shouldRequest(
                isCoordinator: false,
                hasPeerCanonicalRecovery: false,
                hasResolutionRecovery: true,
                now: 349,
                lastRequestAt: 100
            )
        )
        XCTAssertTrue(
            MultiplayerSnapshotRecoveryRequestPolicy.shouldRequest(
                isCoordinator: false,
                hasPeerCanonicalRecovery: false,
                hasResolutionRecovery: true,
                now: 350,
                lastRequestAt: 100
            )
        )
        XCTAssertFalse(
            MultiplayerSnapshotRecoveryRequestPolicy.shouldRequest(
                isCoordinator: false,
                hasPeerCanonicalRecovery: false,
                hasResolutionRecovery: false,
                now: 350,
                lastRequestAt: 100
            )
        )
    }

    func testReconnectSnapshotWaitsUntilRetainedResumeCommits() {
        XCTAssertFalse(
            MultiplayerReconnectSnapshotPolicy.shouldSend(
                isCoordinator: true,
                hasPendingResumeRecovery: true
            )
        )
        XCTAssertTrue(
            MultiplayerReconnectSnapshotPolicy.shouldSend(
                isCoordinator: true,
                hasPendingResumeRecovery: false
            )
        )
        XCTAssertFalse(
            MultiplayerReconnectSnapshotPolicy.shouldSend(
                isCoordinator: false,
                hasPendingResumeRecovery: false
            )
        )
    }

    func testTerminalRecoveryNeverQueuesAGameplayPauseAfterFinish() {
        XCTAssertTrue(
            MultiplayerCoordinatedPausePolicy.shouldBegin(
                isCoordinator: true,
                isAlreadyPaused: false,
                isTerminalDraining: false,
                didBroadcastFinish: false
            )
        )
        XCTAssertFalse(
            MultiplayerCoordinatedPausePolicy.shouldBegin(
                isCoordinator: true,
                isAlreadyPaused: false,
                isTerminalDraining: true,
                didBroadcastFinish: false
            )
        )
        XCTAssertFalse(
            MultiplayerCoordinatedPausePolicy.shouldBegin(
                isCoordinator: true,
                isAlreadyPaused: false,
                isTerminalDraining: false,
                didBroadcastFinish: true
            )
        )
    }

    func testTerminalDrainKeepsOneFifteenSecondDeadlineThroughFinishDelivery() {
        XCTAssertFalse(
            MultiplayerTerminalDrainDeadlinePolicy.hasExpired(
                now: 14_999,
                deadline: 15_000
            )
        )
        XCTAssertTrue(
            MultiplayerTerminalDrainDeadlinePolicy.hasExpired(
                now: 15_000,
                deadline: 15_000
            )
        )
        XCTAssertTrue(
            MultiplayerTerminalDrainDeadlinePolicy.hasExpired(
                now: 15_001,
                deadline: 15_000
            )
        )
    }

    func testPauseRecoveryKeepsTheOriginalDeadlineAcrossALateResumeRetry() {
        XCTAssertNil(
            MultiplayerRecoveryDeadlinePolicy.firstExpiredMessage(
                now: 14_999,
                noticeAfterMilliseconds: 1_000,
                cancelAfterMilliseconds: 15_000,
                recoveries: [
                    (beganAt: 14_900, message: "resume"),
                    (beganAt: 0, message: "pause"),
                ]
            )
        )
        XCTAssertEqual(
            MultiplayerRecoveryDeadlinePolicy.firstExpiredMessage(
                now: 15_000,
                noticeAfterMilliseconds: 1_000,
                cancelAfterMilliseconds: 15_000,
                recoveries: [
                    (beganAt: 14_900, message: "resume"),
                    (beganAt: 0, message: "pause"),
                ]
            ),
            "pause"
        )
    }

    func testCoordinatorPlanOutboxRetainsOriginalBatchUntilSentOrCancelled() throws {
        let plan = MultiplayerWireActivationPlan(
            planId: 7,
            kind: .target,
            at: 2_000,
            ownerSeat: 0,
            entityId: 4,
            cell: 6,
            colorIndex: 0,
            lifetimeMs: nil
        )
        var outbox = MultiplayerCoordinatorPlanOutbox()

        outbox.enqueue(plan, logicalMilliseconds: 100)
        let retained = try XCTUnwrap(outbox.nextBatch())
        XCTAssertEqual(retained.plans, [plan])
        XCTAssertEqual(retained.queuedAt, 100)

        outbox.remove(planIDs: [plan.planId])
        XCTAssertTrue(outbox.isEmpty)
        XCTAssertNil(outbox.nextBatch())
    }

    func testSnapshotPrunesOverlappingCanonicalBatchWithoutApplyingItTwice() throws {
        let first = MultiplayerEvent.hit(
            sequence: 1,
            inputAt: 10,
            handledAt: 12,
            seat: 0,
            targetId: 1,
            cell: 4
        )
        let second = MultiplayerEvent.hit(
            sequence: 2,
            inputAt: 20,
            handledAt: 22,
            seat: 0,
            targetId: 2,
            cell: 5
        )

        XCTAssertEqual(
            try MultiplayerCanonicalBatchReconciler.retainingUnapplied(
                [1: [first, second]],
                after: [first]
            ),
            [2: [second]]
        )
        XCTAssertTrue(
            try MultiplayerCanonicalBatchReconciler.retainingUnapplied(
                [1: [first, second]],
                after: [first, second]
            ).isEmpty
        )

        let conflicting = MultiplayerEvent.miss(
            sequence: 1,
            inputAt: 10,
            handledAt: 12,
            seat: 0,
            reason: .wrong,
            cell: 4
        )
        XCTAssertThrowsError(
            try MultiplayerCanonicalBatchReconciler.inserting(
                [conflicting],
                into: [1: [first]],
                after: []
            )
        )
    }

    func testSnapshotReconciliationRejectsConflictingOrMalformedAppliedHistory() throws {
        let applied = MultiplayerEvent.hit(
            sequence: 1,
            inputAt: 10,
            handledAt: 12,
            seat: 0,
            targetId: 1,
            cell: 4
        )
        let next = MultiplayerEvent.hit(
            sequence: 2,
            inputAt: 20,
            handledAt: 22,
            seat: 0,
            targetId: 2,
            cell: 5
        )
        XCTAssertEqual(
            try MultiplayerSnapshotTranscriptReconciler.unappliedEvents(
                from: [applied.integerTuple, next.integerTuple],
                after: [applied]
            ),
            [next]
        )

        let conflicting = MultiplayerEvent.miss(
            sequence: 1,
            inputAt: 10,
            handledAt: 12,
            seat: 0,
            reason: .wrong,
            cell: 4
        )
        XCTAssertThrowsError(
            try MultiplayerSnapshotTranscriptReconciler.unappliedEvents(
                from: [conflicting.integerTuple],
                after: [applied]
            )
        )
        XCTAssertThrowsError(
            try MultiplayerSnapshotTranscriptReconciler.unappliedEvents(
                from: [[999, 1]],
                after: [applied]
            )
        )
        XCTAssertThrowsError(
            try MultiplayerSnapshotTranscriptReconciler.unappliedEvents(
                from: [[6, 0, 10]],
                after: [applied]
            )
        )
    }

    func testSnapshotAssemblerWaitsForEveryChunkAndRejectsUnsafeMetadata() throws {
        let plan = MultiplayerWireActivationPlan(
            planId: 7,
            kind: .target,
            at: 2_000,
            ownerSeat: 0,
            entityId: 4,
            cell: 6,
            colorIndex: 0,
            lifetimeMs: nil
        )
        let first = MultiplayerSnapshotPacket(
            afterEventSequence: 0,
            throughEventSequence: 2,
            chunkIndex: 0,
            chunkCount: 2,
            controlWatermark: 4,
            events: [[0, 1, 10, 0, 1, 4, 0]],
            pendingPlans: [plan],
            coordinatorMatchStartMonotonicMilliseconds: 1_000,
            pauseId: nil,
            pausedAtLogicalMilliseconds: nil
        )
        let second = MultiplayerSnapshotPacket(
            afterEventSequence: 0,
            throughEventSequence: 2,
            chunkIndex: 1,
            chunkCount: 2,
            controlWatermark: 4,
            events: [[0, 2, 20, 0, 2, 5, 0]],
            pendingPlans: [plan],
            coordinatorMatchStartMonotonicMilliseconds: 1_000,
            pauseId: nil,
            pausedAtLogicalMilliseconds: nil
        )
        var assembler = MultiplayerSnapshotAssembler()
        XCTAssertNil(try assembler.ingest(first))
        XCTAssertTrue(assembler.isPending)
        let assembled = try XCTUnwrap(assembler.ingest(second))
        XCTAssertEqual(assembled.events, first.events + second.events)
        XCTAssertFalse(assembler.isPending)

        let duplicatePlans = MultiplayerSnapshotPacket(
            afterEventSequence: 0,
            throughEventSequence: 0,
            chunkIndex: 0,
            chunkCount: 1,
            controlWatermark: 4,
            events: [],
            pendingPlans: [plan, plan],
            coordinatorMatchStartMonotonicMilliseconds: 1_000,
            pauseId: nil,
            pausedAtLogicalMilliseconds: nil
        )
        XCTAssertThrowsError(try assembler.ingest(duplicatePlans))

        let nonemptyZeroSpan = MultiplayerSnapshotPacket(
            afterEventSequence: 1,
            throughEventSequence: 1,
            chunkIndex: 0,
            chunkCount: 1,
            controlWatermark: 4,
            events: [[0, 2, 20, 0, 2, 5, 0]],
            pendingPlans: [],
            coordinatorMatchStartMonotonicMilliseconds: 1_000,
            pauseId: nil,
            pausedAtLogicalMilliseconds: nil
        )
        XCTAssertThrowsError(try assembler.ingest(nonemptyZeroSpan))
    }

    func testStaleSnapshotMetadataCannotReopenPlansOrRewindPauseState() {
        XCTAssertFalse(
            MultiplayerSnapshotMetadataPolicy.shouldCommitInController(
                snapshotThroughEventSequence: 10,
                transcriptEventCount: 11,
                snapshotControlWatermark: 20,
                latestMetadataControlSequence: 20
            )
        )
        XCTAssertFalse(
            MultiplayerSnapshotMetadataPolicy.shouldCommitInController(
                snapshotThroughEventSequence: 11,
                transcriptEventCount: 11,
                snapshotControlWatermark: 19,
                latestMetadataControlSequence: 20
            )
        )
        XCTAssertTrue(
            MultiplayerSnapshotMetadataPolicy.shouldCommitInController(
                snapshotThroughEventSequence: 11,
                transcriptEventCount: 11,
                snapshotControlWatermark: 20,
                latestMetadataControlSequence: 20
            )
        )
        XCTAssertFalse(
            MultiplayerSnapshotMetadataPolicy.shouldStageInTransport(
                snapshotThroughEventSequence: 10,
                appliedEventSequence: 11,
                snapshotControlWatermark: 20,
                latestMetadataControlSequence: 20
            )
        )
    }

    func testCatchUpStaysInteractiveWhileReconnectAndTerminalDoNot() {
        let catchUp = MultiplayerLiveInteractionPolicy.resolve(
            localHasLives: true,
            isApplicationActive: true,
            hasDisconnectedPlayers: false,
            isPaused: false,
            isTerminalDraining: false,
            hasPendingInputForPresentedActivation: false,
            isCatchUpVisible: true
        )
        XCTAssertEqual(catchUp.inputMode, .interactive)
        XCTAssertEqual(catchUp.networkStatus, .catchingUp)

        let silentOutputPause = MultiplayerLiveInteractionPolicy.resolve(
            localHasLives: true,
            isApplicationActive: true,
            hasDisconnectedPlayers: false,
            isPaused: true,
            isTerminalDraining: false,
            hasPendingInputForPresentedActivation: false,
            isCatchUpVisible: false
        )
        XCTAssertEqual(silentOutputPause.inputMode, .interactive)
        XCTAssertNil(silentOutputPause.networkStatus)

        let visibleOutputPause = MultiplayerLiveInteractionPolicy.resolve(
            localHasLives: true,
            isApplicationActive: true,
            hasDisconnectedPlayers: false,
            isPaused: true,
            isTerminalDraining: false,
            hasPendingInputForPresentedActivation: false,
            isCatchUpVisible: true
        )
        XCTAssertEqual(visibleOutputPause.inputMode, .interactive)
        XCTAssertEqual(visibleOutputPause.networkStatus, .catchingUp)

        let reconnect = MultiplayerLiveInteractionPolicy.resolve(
            localHasLives: true,
            isApplicationActive: true,
            hasDisconnectedPlayers: true,
            isPaused: true,
            isTerminalDraining: false,
            hasPendingInputForPresentedActivation: false,
            isCatchUpVisible: true
        )
        XCTAssertEqual(reconnect.inputMode, .syncing)
        XCTAssertEqual(reconnect.networkStatus, .reconnecting)

        let finalizing = MultiplayerLiveInteractionPolicy.resolve(
            localHasLives: true,
            isApplicationActive: true,
            hasDisconnectedPlayers: false,
            isPaused: false,
            isTerminalDraining: true,
            hasPendingInputForPresentedActivation: false,
            isCatchUpVisible: true
        )
        XCTAssertEqual(finalizing.inputMode, .finalizing)
        XCTAssertEqual(finalizing.networkStatus, .finalizing)
    }

    func testReadyIntentRespondsLocallyAndFlushesOnceAfterCompatibility() {
        var intent = MultiplayerReadyIntent()

        intent.request(true)
        XCTAssertTrue(intent.displayedReady(serverReady: false))
        XCTAssertNil(
            intent.takePendingMutation(
                serverReady: false,
                compatibility: .collecting
            )
        )
        XCTAssertNil(
            intent.takePendingMutation(
                serverReady: false,
                compatibility: .incompatible
            )
        )
        XCTAssertEqual(
            intent.takePendingMutation(
                serverReady: false,
                compatibility: .unanimous
            ),
            true
        )
        XCTAssertNil(
            intent.takePendingMutation(
                serverReady: false,
                compatibility: .unanimous
            )
        )

        intent.acknowledge(serverReady: true)
        XCTAssertTrue(intent.displayedReady(serverReady: true))
        XCTAssertNil(
            intent.takePendingMutation(
                serverReady: true,
                compatibility: .unanimous
            )
        )
    }

    func testReadyIntentCanUndoQueuedReadyAndClearsOnRetryOrLeave() {
        var intent = MultiplayerReadyIntent()
        intent.request(false)
        XCTAssertEqual(
            intent.takePendingMutation(
                serverReady: true,
                compatibility: .collecting
            ),
            false
        )
        intent.acknowledge(serverReady: false)

        intent.request(true)
        intent.request(false)

        XCTAssertFalse(intent.displayedReady(serverReady: false))
        XCTAssertNil(
            intent.takePendingMutation(
                serverReady: false,
                compatibility: .collecting
            )
        )

        intent.request(true)
        intent.reset()
        XCTAssertFalse(intent.displayedReady(serverReady: false))
        XCTAssertNil(
            intent.takePendingMutation(
                serverReady: false,
                compatibility: .unanimous
            )
        )

        intent.request(true)
        XCTAssertEqual(
            intent.takePendingMutation(
                serverReady: false,
                compatibility: .unanimous
            ),
            true
        )
        intent.mutationFailed()
        XCTAssertFalse(intent.displayedReady(serverReady: false))
    }

    func testClockSynchronizationKeepsProbingUntilTheTenSecondDeadline() {
        XCTAssertTrue(
            MultiplayerClockSynchronizationPolicy.shouldContinue(
                now: 1_680,
                deadline: 10_000,
                hasMeasurement: false
            )
        )
        XCTAssertTrue(
            MultiplayerClockSynchronizationPolicy.shouldContinue(
                now: 9_999,
                deadline: 10_000,
                hasMeasurement: false
            )
        )
        XCTAssertFalse(
            MultiplayerClockSynchronizationPolicy.shouldContinue(
                now: 10_000,
                deadline: 10_000,
                hasMeasurement: false
            )
        )
        XCTAssertFalse(
            MultiplayerClockSynchronizationPolicy.shouldContinue(
                now: 1_000,
                deadline: 10_000,
                hasMeasurement: true
            )
        )
    }

    func testClockSynchronizationCannotRestartAfterWaitingFailure() {
        XCTAssertFalse(
            MultiplayerClockSynchronizationPolicy.shouldStart(
                isCoordinator: false,
                isWaiting: true,
                isTransportConnected: false,
                connectionPresentsFailure: true,
                hasMeasurement: false,
                hasTask: false,
                hasMatchID: true
            )
        )
        XCTAssertFalse(
            MultiplayerClockSynchronizationPolicy.shouldStart(
                isCoordinator: false,
                isWaiting: true,
                isTransportConnected: true,
                connectionPresentsFailure: true,
                hasMeasurement: false,
                hasTask: false,
                hasMatchID: true
            )
        )
        XCTAssertTrue(
            MultiplayerClockSynchronizationPolicy.shouldStart(
                isCoordinator: false,
                isWaiting: true,
                isTransportConnected: true,
                connectionPresentsFailure: false,
                hasMeasurement: false,
                hasTask: false,
                hasMatchID: true
            )
        )
    }

    func testRosterConfirmationRejectsDisconnectAndRecoveringTransportResults() {
        XCTAssertTrue(
            MultiplayerWaitingConnectionOperationPolicy.canContinue(
                isWaiting: true,
                isTransportConnected: true,
                hasDisconnectedPlayers: false,
                expectedConnectionGeneration: 7,
                currentConnectionGeneration: 7
            )
        )
        XCTAssertFalse(
            MultiplayerWaitingConnectionOperationPolicy.canContinue(
                isWaiting: true,
                isTransportConnected: false,
                hasDisconnectedPlayers: true,
                expectedConnectionGeneration: 7,
                currentConnectionGeneration: 8
            )
        )
    }

    func testAuthoritativeSnapshotKeepsPauseRecoveryAnchorInSync() {
        XCTAssertNil(
            MultiplayerPauseRecoveryAnchorPolicy.applyingSnapshot(
                pausedAtLogicalMilliseconds: nil,
                existingAnchor: 1_000,
                now: 2_000
            )
        )
        XCTAssertEqual(
            MultiplayerPauseRecoveryAnchorPolicy.applyingSnapshot(
                pausedAtLogicalMilliseconds: 250,
                existingAnchor: nil,
                now: 2_000
            ),
            2_000
        )
        XCTAssertEqual(
            MultiplayerPauseRecoveryAnchorPolicy.applyingSnapshot(
                pausedAtLogicalMilliseconds: 250,
                existingAnchor: 1_000,
                now: 2_000
            ),
            1_000
        )
    }

    func testLobbyOperationIdentityRejectsStaleRuntimeAndResponseRevision() {
        let identity = MultiplayerLobbyOperationIdentity(
            matchID: "match-a",
            runtimeGeneration: 7,
            revision: 11
        )

        XCTAssertTrue(
            identity.isCurrent(
                matchID: "match-a",
                runtimeGeneration: 7,
                revision: 11
            )
        )
        XCTAssertFalse(
            identity.isCurrent(
                matchID: "match-a",
                runtimeGeneration: 8,
                revision: 11
            )
        )
        XCTAssertFalse(
            identity.isCurrent(
                matchID: "match-a",
                runtimeGeneration: 7,
                revision: 12
            )
        )
        XCTAssertFalse(
            identity.isCurrent(
                matchID: "match-b",
                runtimeGeneration: 7,
                revision: 11
            )
        )
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
