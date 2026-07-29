import PimPoPomCore
import XCTest

@testable import PimPoPom

final class MultiplayerPeerConsistencyTests: XCTestCase {
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
}
