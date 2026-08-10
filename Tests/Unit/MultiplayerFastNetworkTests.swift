import Foundation
import PimPoPomCore
import XCTest

@testable import PimPoPom

final class MultiplayerFastNetworkTests: XCTestCase {
    func testHitResolutionNamesTheExactInputEventAfterEarlierDueEvents() throws {
        let inputID = MultiplayerInputID(seat: 1, inputSequence: 4)
        let result = MultiplayerInputResult(
            outcome: .hit,
            committedEvents: [
                .target(
                    sequence: 8,
                    at: 500,
                    ownerSeat: 1,
                    targetId: 3,
                    cell: 4,
                    colorIndex: 1
                ),
                .hit(
                    sequence: 9,
                    inputAt: 520,
                    handledAt: 540,
                    seat: 1,
                    targetId: 3,
                    cell: 4
                ),
            ],
            plannedActivations: [],
            cancelledPlanIds: []
        )

        XCTAssertEqual(
            try MultiplayerCoordinatorResolutionPolicy.resolution(
                inputID: inputID,
                input: MultiplayerSealedInput(id: inputID, cell: 4, inputAt: 520),
                result: result
            ),
            MultiplayerInputResolution(
                inputID: inputID,
                disposition: .committed(eventSequence: 9)
            )
        )
    }

    func testEveryIgnoredCoordinatorOutcomeProducesOneLiveOnlyDisposition() throws {
        let inputID = MultiplayerInputID(seat: 0, inputSequence: 1)
        let input = MultiplayerSealedInput(id: inputID, cell: 4, inputAt: 100)
        let cases: [(MultiplayerInputOutcome, MultiplayerIgnoredInputReason)] = [
            (.ignoredRecovery, .recovery),
            (.ignoredEliminated, .eliminated),
            (.ignoredFinished, .finished),
            (.ignoredExpired, .staleTarget),
        ]

        for (outcome, reason) in cases {
            let result = MultiplayerInputResult(
                outcome: outcome,
                committedEvents: [],
                plannedActivations: [],
                cancelledPlanIds: []
            )
            XCTAssertEqual(
                try MultiplayerCoordinatorResolutionPolicy.resolution(
                    inputID: inputID,
                    input: input,
                    result: result
                ).disposition,
                .ignored(reason)
            )
        }
    }

    func testLocalSealEmitterUsesClosedMillisecondsAndReliableCheckpoints() {
        var emitter = MultiplayerLocalSealEmitter()

        XCTAssertEqual(
            emitter.next(seat: 0, highestInputSequence: 0, logicalMilliseconds: 50),
            MultiplayerLocalSealEmission(
                seal: MultiplayerInputSeal(
                    seat: 0,
                    throughInputAt: 49,
                    highestInputSequence: 0
                ),
                includesReliableCheckpoint: true
            )
        )
        XCTAssertNil(
            emitter.next(seat: 0, highestInputSequence: 0, logicalMilliseconds: 50)
        )
        XCTAssertEqual(
            emitter.next(seat: 0, highestInputSequence: 1, logicalMilliseconds: 149)?
                .includesReliableCheckpoint,
            false
        )
        XCTAssertEqual(
            emitter.next(seat: 0, highestInputSequence: 1, logicalMilliseconds: 150)?
                .includesReliableCheckpoint,
            true
        )
    }

    func testSupportedTwoThreeAndFourSeatProfilesStayBelowNormalLatencyGate() throws {
        let profiles: [(MultiplayerNetworkQuality, Int)] = [
            (.init(p95RoundTripMilliseconds: 10, p95JitterMilliseconds: 2), 40),
            (
                .init(
                    p95RoundTripMilliseconds: 60,
                    p95JitterMilliseconds: 15,
                    lossPercent: 1,
                    reorderPercent: 1
                ),
                62
            ),
            (
                .init(
                    p95RoundTripMilliseconds: 100,
                    p95JitterMilliseconds: 25,
                    lossPercent: 3,
                    reorderPercent: 3
                ),
                92
            ),
        ]

        for seats in 2...4 {
            for (quality, expectedStaleness) in profiles {
                let policy = try MultiplayerFrozenNetworkPolicy.negotiate(
                    Array(repeating: quality, count: seats)
                )
                XCTAssertEqual(policy.frontierStalenessMilliseconds, expectedStaleness)
                if quality.p95RoundTripMilliseconds == 60 {
                    XCTAssertLessThanOrEqual(
                        quality.p95RoundTripMilliseconds
                            + policy.frontierStalenessMilliseconds
                            + 17,
                        150
                    )
                }
            }
        }
    }

    func testReliableRecoveryClosesAReorderedGapForTwoThreeAndFourSeats() throws {
        for seatCount in 2...4 {
            var frontier = try MultiplayerInputFrontier(seats: Array(0..<seatCount))
            for seat in 0..<seatCount {
                if seat == seatCount - 1 {
                    _ = try frontier.recordInput(
                        MultiplayerSealedInput(
                            id: .init(seat: seat, inputSequence: 2),
                            cell: 2,
                            inputAt: 110
                        )
                    )
                    try frontier.recordSeal(
                        .init(
                            seat: seat,
                            throughInputAt: 120,
                            highestInputSequence: 2
                        )
                    )
                } else {
                    try frontier.recordSeal(
                        .init(
                            seat: seat,
                            throughInputAt: 120,
                            highestInputSequence: 0
                        )
                    )
                }
            }

            XCTAssertNil(frontier.publishWatermark)
            XCTAssertEqual(
                frontier.missingInputIDs,
                [
                    MultiplayerInputID(
                        seat: seatCount - 1,
                        inputSequence: 1
                    )
                ]
            )

            _ = try frontier.recordInput(
                MultiplayerSealedInput(
                    id: .init(seat: seatCount - 1, inputSequence: 1),
                    cell: 1,
                    inputAt: 100
                )
            )

            XCTAssertEqual(frontier.publishWatermark, 120)
            XCTAssertEqual(
                frontier.takeReadyInputs().map(\.id.inputSequence),
                [1, 2]
            )
        }
    }

    func testDeterministicTwoThreeFourSeatRoleAndNetworkMatrix() throws {
        let profiles = [
            MatrixProfile(name: "clean", roundTrip: 10, variation: 2, supported: true),
            MatrixProfile(name: "normal", roundTrip: 60, variation: 15, supported: true),
            MatrixProfile(name: "edge", roundTrip: 100, variation: 25, supported: true),
            MatrixProfile(name: "unsupported", roundTrip: 120, variation: 30, supported: false),
        ]
        var exercisedCases = 0

        for seatCount in 2...4 {
            for coordinatorSeat in 0..<seatCount {
                for profile in profiles {
                    exercisedCases += 1
                    var gate = MultiplayerTerminalGate()
                    var consensus = try MultiplayerNetworkPolicyConsensus(
                        seats: Array(0..<seatCount),
                        coordinatorSeat: coordinatorSeat
                    )
                    let measurements = (0..<seatCount).compactMap { seat in
                        seat == coordinatorSeat
                            ? nil
                            : MultiplayerSeatNetworkMeasurement(
                                seat: seat,
                                attemptedSampleCount: 4,
                                completedSampleCount: 4,
                                reorderedSampleCount: 0,
                                p95RoundTripMilliseconds: profile.roundTrip,
                                p95RoundTripVariationMilliseconds: profile.variation
                            )
                    }

                    if !profile.supported {
                        XCTAssertThrowsError(
                            try {
                                for measurement in measurements.reversed() {
                                    try consensus.recordMeasurement(
                                        measurement,
                                        from: measurement.seat
                                    )
                                }
                            }(),
                            "Unsupported profile started for \(seatCount) seats, coordinator \(coordinatorSeat)."
                        )
                        gate.cancel()
                        XCTAssertFalse(gate.authorizeSubmission(ifConsistent: true))
                        XCTAssertFalse(gate.submissionAuthorized)
                        continue
                    }

                    for measurement in measurements.reversed() {
                        try consensus.recordMeasurement(measurement, from: measurement.seat)
                    }
                    let proposal = try XCTUnwrap(consensus.proposal)
                    for seat in (0..<seatCount).reversed() {
                        try consensus.recordVote(
                            MultiplayerNetworkPolicyVote(seat: seat, proposal: proposal),
                            from: seat
                        )
                    }
                    XCTAssertEqual(consensus.frozenProposal, proposal)

                    if profile.name == "clean" || profile.name == "normal" {
                        XCTAssertLessThanOrEqual(
                            profile.roundTrip
                                + proposal.policy.frontierStalenessMilliseconds
                                + 17,
                            150,
                            "Normal canonical p95 gate failed for \(seatCount) seats, coordinator \(coordinatorSeat)."
                        )
                    }

                    let run = try makeFinishedRun(seatCount: seatCount)
                    var encodedSubmissions: [Data] = []
                    for peerSeat in 0..<seatCount {
                        var ledger = MultiplayerInputLedger()
                        switch profile.name {
                        case "normal":
                            for pair in run.pairs.reversed() {
                                _ = try ledger.recordResolution(pair.resolution)
                            }
                            for pair in run.pairs {
                                _ = try ledger.recordEvidence(pair.evidence)
                                _ = try ledger.recordEvidence(pair.evidence)
                            }
                        case "edge":
                            for pair in run.pairs.reversed() {
                                _ = try ledger.recordResolution(pair.resolution)
                                _ = try ledger.recordEvidence(pair.evidence)
                            }
                        default:
                            for pair in run.pairs {
                                _ = try ledger.recordEvidence(pair.evidence)
                                _ = try ledger.recordResolution(pair.resolution)
                            }
                        }
                        XCTAssertTrue(try ledger.consume(events: run.events))
                        XCTAssertTrue(ledger.isTerminallyComplete)

                        let reducer = try MultiplayerStateReducer(manifest: run.manifest)
                        for event in run.events {
                            try reducer.apply(event)
                        }
                        XCTAssertEqual(reducer.state.phase, .finished)

                        let encoder = JSONEncoder()
                        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
                        encodedSubmissions.append(
                            try encoder.encode(
                                MultiplayerTranscriptSubmission(
                                    matchId: run.manifest.matchId,
                                    events: run.events.map(\.integerTuple)
                                )
                            )
                        )
                        XCTAssertTrue((0..<seatCount).contains(peerSeat))
                    }
                    XCTAssertEqual(Set(encodedSubmissions).count, 1)

                    var drain = try MultiplayerTerminalDrainTracker(
                        seats: Array(0..<seatCount)
                    )
                    for pair in run.pairs.reversed() {
                        try drain.recordEvidence(pair.evidence)
                    }
                    for seat in 0..<seatCount {
                        let seatEvidence = run.pairs.map(\.evidence).filter {
                            $0.id.seat == seat
                        }
                        try drain.recordTerminalSeal(
                            MultiplayerInputSeal(
                                seat: seat,
                                throughInputAt: seatEvidence.map(\.inputAt).max() ?? 0,
                                highestInputSequence:
                                    seatEvidence.map(\.id.inputSequence).max() ?? 0
                            )
                        )
                    }
                    XCTAssertTrue(drain.isComplete)
                    XCTAssertTrue(gate.authorizeSubmission(ifConsistent: true))
                    XCTAssertTrue(gate.submissionAuthorized)
                }
            }
        }

        XCTAssertEqual(exercisedCases, 36)
    }

    private struct MatrixProfile {
        let name: String
        let roundTrip: Int
        let variation: Int
        let supported: Bool
    }

    private struct MatrixInputPair {
        let evidence: MultiplayerSealedInput
        let resolution: MultiplayerInputResolution
    }

    private struct FinishedRun {
        let manifest: PimPoPomCore.MultiplayerManifest
        let events: [MultiplayerEvent]
        let pairs: [MatrixInputPair]
    }

    private func makeFinishedRun(seatCount: Int) throws -> FinishedRun {
        let hash = String(repeating: "A", count: 43)
        let manifest = PimPoPomCore.MultiplayerManifest(
            matchId: "11111111-1111-4111-8111-111111111111",
            seed: hash,
            participants: (0..<seatCount).map { seat in
                PimPoPomCore.MultiplayerManifestParticipant(
                    participantId: String(
                        format: "00000000-0000-4000-8000-%012d",
                        seat + 1
                    ),
                    seat: seat,
                    colorIndex: seat
                )
            },
            manifestHash: hash
        )
        let engine = try MultiplayerCoordinatorEngine(
            manifest: manifest,
            random: { 0 }
        )
        var nextTarget = try XCTUnwrap(
            engine.start().first(where: { $0.kind == .target })
        )
        var nextInputSequence = Array(repeating: 1, count: seatCount)
        var pairs: [MatrixInputPair] = []
        var safety = 0

        while engine.state.phase == .running {
            safety += 1
            XCTAssertLessThanOrEqual(safety, seatCount * 4)
            _ = try engine.advance(to: nextTarget.at)
            let occupied = Set(
                [nextTarget.cell] + engine.state.decoys.map(\.cell)
            )
            let wrongCell = try XCTUnwrap(
                (0..<MultiplayerProtocolConstants.boardCellCount).first {
                    !occupied.contains($0)
                }
            )
            let inputAt = nextTarget.at + 10
            let seat = nextTarget.ownerSeat
            let inputID = MultiplayerInputID(
                seat: seat,
                inputSequence: nextInputSequence[seat]
            )
            nextInputSequence[seat] += 1
            let evidence = MultiplayerSealedInput(
                id: inputID,
                cell: wrongCell,
                inputAt: inputAt
            )
            let output = try engine.handleTap(
                seat: seat,
                cell: wrongCell,
                inputAt: inputAt,
                handledAt: inputAt + 1
            )
            pairs.append(
                MatrixInputPair(
                    evidence: evidence,
                    resolution: try MultiplayerCoordinatorResolutionPolicy.resolution(
                        inputID: inputID,
                        input: evidence,
                        result: output
                    )
                )
            )
            if engine.state.phase == .running {
                nextTarget = try XCTUnwrap(
                    output.plannedActivations.first(where: { $0.kind == .target })
                        ?? engine.prepareActivations(
                            now: engine.clockMilliseconds,
                            horizonMilliseconds: max(
                                0,
                                engine.state.nextTargetLatestAt
                                    - engine.clockMilliseconds
                            )
                        ).first(where: { $0.kind == .target })
                )
            }
        }
        return FinishedRun(
            manifest: manifest,
            events: engine.events,
            pairs: pairs
        )
    }
}
