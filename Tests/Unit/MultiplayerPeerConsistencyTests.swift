import PimPoPomCore
import XCTest

@testable import PimPoPom

final class MultiplayerPeerConsistencyTests: XCTestCase {
    func testInputLedgerKeepsSameMillisecondSequencesDistinct() throws {
        var ledger = MultiplayerInputLedger()
        let first = evidence(sequence: 1)
        let second = evidence(sequence: 2)

        XCTAssertEqual(try ledger.recordEvidence(first), .inserted)
        XCTAssertEqual(try ledger.recordEvidence(second), .inserted)
        XCTAssertEqual(
            ledger.unresolvedInputIDs,
            [first.id, second.id]
        )
    }

    func testInputLedgerConvergesEvidenceBeforeResolution() throws {
        var ledger = MultiplayerInputLedger()
        let input = evidence(sequence: 1)
        let resolution = MultiplayerInputResolution(
            inputID: input.id,
            disposition: .committed(eventSequence: 2)
        )

        XCTAssertEqual(try ledger.recordEvidence(input), .inserted)
        XCTAssertEqual(try ledger.recordResolution(resolution), .inserted)
        XCTAssertTrue(try ledger.consume(events: [hit(sequence: 2)]))
        XCTAssertTrue(ledger.isTerminallyComplete)
    }

    func testInputLedgerConvergesResolutionBeforeEvidence() throws {
        var ledger = MultiplayerInputLedger()
        let input = evidence(sequence: 1)
        let resolution = MultiplayerInputResolution(
            inputID: input.id,
            disposition: .committed(eventSequence: 2)
        )

        XCTAssertEqual(try ledger.recordResolution(resolution), .inserted)
        XCTAssertEqual(try ledger.recordEvidence(input), .inserted)
        XCTAssertTrue(try ledger.consume(events: [hit(sequence: 2)]))
        XCTAssertTrue(ledger.isTerminallyComplete)
    }

    func testIgnoredResolutionClosesEvidenceWithoutTranscriptTuple() throws {
        var ledger = MultiplayerInputLedger()
        let input = evidence(sequence: 1)
        _ = try ledger.recordEvidence(input)

        XCTAssertEqual(
            try ledger.recordResolution(
                MultiplayerInputResolution(
                    inputID: input.id,
                    disposition: .ignored(.recovery)
                )
            ),
            .resolvedIgnored
        )
        XCTAssertTrue(ledger.isTerminallyComplete)
        XCTAssertEqual(try ledger.recordEvidence(input), .duplicate)
        XCTAssertTrue(ledger.isTerminallyComplete)
    }

    func testInputLedgerRejectsConflictingEvidenceAndResolution() throws {
        var ledger = MultiplayerInputLedger()
        let input = evidence(sequence: 1)
        _ = try ledger.recordEvidence(input)
        _ = try ledger.recordResolution(
            MultiplayerInputResolution(
                inputID: input.id,
                disposition: .committed(eventSequence: 2)
            )
        )

        XCTAssertThrowsError(
            try ledger.recordEvidence(
                MultiplayerSealedInput(id: input.id, cell: 8, inputAt: input.inputAt)
            )
        )
        XCTAssertThrowsError(
            try ledger.recordResolution(
                MultiplayerInputResolution(
                    inputID: input.id,
                    disposition: .ignored(.alreadyResolved)
                )
            )
        )
    }

    func testCommittedResolutionMustMatchTheExactCanonicalInputEvent() throws {
        var ledger = MultiplayerInputLedger()
        let input = evidence(sequence: 1)
        _ = try ledger.recordEvidence(input)
        _ = try ledger.recordResolution(
            MultiplayerInputResolution(
                inputID: input.id,
                disposition: .committed(eventSequence: 2)
            )
        )

        XCTAssertThrowsError(
            try ledger.consume(
                events: [
                    .hit(
                        sequence: 2,
                        inputAt: input.inputAt,
                        handledAt: 430,
                        seat: input.id.seat,
                        targetId: 1,
                        cell: 8
                    )
                ]
            )
        )
        XCTAssertFalse(ledger.isTerminallyComplete)
    }

    func testFabricatedHitCannotConsumeMissingPeerInput() {
        var evidence: [MultiplayerInputEvidenceKey: Int] = [:]
        let accepted = MultiplayerPeerConsistency.consume(
            events: [
                .hit(
                    sequence: 2,
                    inputAt: 420,
                    handledAt: 430,
                    seat: 1,
                    targetId: 1,
                    cell: 7
                )
            ],
            from: &evidence
        )

        XCTAssertFalse(accepted)
        XCTAssertTrue(evidence.isEmpty)
    }

    func testExactPeerInputIsConsumedOnlyOnce() {
        let key = MultiplayerInputEvidenceKey(seat: 1, cell: 7, inputAt: 420)
        var evidence = [key: 1]
        let hit = MultiplayerEvent.hit(
            sequence: 2,
            inputAt: 420,
            handledAt: 430,
            seat: 1,
            targetId: 1,
            cell: 7
        )

        XCTAssertTrue(
            MultiplayerPeerConsistency.consume(events: [hit], from: &evidence)
        )
        XCTAssertTrue(evidence.isEmpty)
        XCTAssertFalse(
            MultiplayerPeerConsistency.consume(events: [hit], from: &evidence)
        )
    }

    func testNaturalLateTimeoutNeedsNoPeerInput() {
        var evidence: [MultiplayerInputEvidenceKey: Int] = [:]
        XCTAssertTrue(
            MultiplayerPeerConsistency.consume(
                events: [
                    .miss(
                        sequence: 2,
                        inputAt: 1_250,
                        handledAt: 1_250,
                        seat: 0,
                        reason: .late,
                        cell: -1
                    )
                ],
                from: &evidence
            )
        )
    }

    func testRosterMustPreservePHPParticipantSeatAndColorMapping() {
        let participantID = "11111111-1111-4111-8111-111111111111"
        let participants = [
            MultiplayerParticipant(
                participantId: participantID,
                seat: 0,
                colorIndex: 0,
                name: "Pim",
                petId: nil,
                ready: true,
                status: "joined",
                isCurrentPlayer: true
            )
        ]
        let correct = [
            "G:alpha": MultiplayerHelloPacket(
                participantId: participantID,
                seat: 0,
                colorIndex: 0,
                gamePlayerId: "G:alpha"
            )
        ]
        let mutated = [
            "G:alpha": MultiplayerHelloPacket(
                participantId: participantID,
                seat: 1,
                colorIndex: 0,
                gamePlayerId: "G:alpha"
            )
        ]

        XCTAssertTrue(
            MultiplayerPeerConsistency.rosterMatches(
                correct,
                participants: participants
            )
        )
        XCTAssertFalse(
            MultiplayerPeerConsistency.rosterMatches(
                mutated,
                participants: participants
            )
        )
    }

    private func evidence(sequence: Int) -> MultiplayerSealedInput {
        MultiplayerSealedInput(
            id: MultiplayerInputID(seat: 1, inputSequence: sequence),
            cell: 7,
            inputAt: 420
        )
    }

    private func hit(sequence: Int) -> MultiplayerEvent {
        .hit(
            sequence: sequence,
            inputAt: 420,
            handledAt: 430,
            seat: 1,
            targetId: 1,
            cell: 7
        )
    }
}
