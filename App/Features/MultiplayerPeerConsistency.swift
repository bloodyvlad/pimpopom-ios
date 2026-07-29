import PimPoPomCore

struct MultiplayerInputEvidenceKey: Hashable {
    let seat: Int
    let cell: Int
    let inputAt: Int
}

enum MultiplayerPeerConsistency {
    static func consume(
        events: [MultiplayerEvent],
        from counts: inout [MultiplayerInputEvidenceKey: Int]
    ) -> Bool {
        var remaining = counts
        for event in events {
            guard let evidence = requiredEvidence(for: event) else { continue }
            guard let count = remaining[evidence], count > 0 else { return false }
            if count == 1 {
                remaining.removeValue(forKey: evidence)
            } else {
                remaining[evidence] = count - 1
            }
        }
        counts = remaining
        return true
    }

    static func requiredEvidence(
        for event: MultiplayerEvent
    ) -> MultiplayerInputEvidenceKey? {
        switch event {
        case .hit(_, let inputAt, _, let seat, _, let cell):
            MultiplayerInputEvidenceKey(seat: seat, cell: cell, inputAt: inputAt)
        case .miss(_, let inputAt, _, let seat, let reason, let cell):
            reason == .late && cell == -1
                ? nil
                : MultiplayerInputEvidenceKey(
                    seat: seat,
                    cell: cell,
                    inputAt: inputAt
                )
        default:
            nil
        }
    }

    static func rosterMatches(
        _ roster: [String: MultiplayerHelloPacket],
        participants: [MultiplayerParticipant]
    ) -> Bool {
        let expected = Dictionary(
            uniqueKeysWithValues: participants.map {
                (
                    $0.participantId.lowercased(),
                    ($0.seat, $0.colorIndex)
                )
            }
        )
        guard roster.count == expected.count,
            Set(roster.values.map(\.participantId)) == Set(expected.keys)
        else { return false }
        return roster.allSatisfy { gamePlayerID, hello in
            hello.gamePlayerId == gamePlayerID
                && expected[hello.participantId]?.0 == hello.seat
                && expected[hello.participantId]?.1 == hello.colorIndex
        }
    }
}
