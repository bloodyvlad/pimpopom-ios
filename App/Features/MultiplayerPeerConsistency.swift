import PimPoPomCore

struct MultiplayerInputEvidenceKey: Hashable {
    let seat: Int
    let cell: Int
    let inputAt: Int
}

enum MultiplayerLedgerRecordResult: Equatable {
    case inserted
    case duplicate
    case resolvedIgnored
}

enum MultiplayerInputLedgerError: Error, Equatable {
    case conflictingEvidence(MultiplayerInputID)
    case conflictingResolution(MultiplayerInputID)
    case invalidResolution(MultiplayerInputID)
    case committedEventMismatch(MultiplayerInputID)
    case duplicateCommittedEvent(Int)
}

struct MultiplayerInputLedger {
    private struct ResolvedPair: Equatable {
        let evidence: MultiplayerSealedInput
        let resolution: MultiplayerInputResolution
    }

    private var evidenceByID: [MultiplayerInputID: MultiplayerSealedInput] = [:]
    private var resolutionByID: [MultiplayerInputID: MultiplayerInputResolution] = [:]
    private var resolvedByID: [MultiplayerInputID: ResolvedPair] = [:]

    var unresolvedInputIDs: [MultiplayerInputID] {
        Set(evidenceByID.keys).union(resolutionByID.keys).sorted {
            if $0.seat != $1.seat { return $0.seat < $1.seat }
            return $0.inputSequence < $1.inputSequence
        }
    }

    var isTerminallyComplete: Bool {
        evidenceByID.isEmpty && resolutionByID.isEmpty
    }

    mutating func recordEvidence(
        _ evidence: MultiplayerSealedInput
    ) throws -> MultiplayerLedgerRecordResult {
        if let resolved = resolvedByID[evidence.id] {
            guard resolved.evidence == evidence else {
                throw MultiplayerInputLedgerError.conflictingEvidence(evidence.id)
            }
            return .duplicate
        }
        if let existing = evidenceByID[evidence.id] {
            guard existing == evidence else {
                throw MultiplayerInputLedgerError.conflictingEvidence(evidence.id)
            }
            return .duplicate
        }
        evidenceByID[evidence.id] = evidence
        return closeIgnoredPairIfComplete(evidence.id) ? .resolvedIgnored : .inserted
    }

    mutating func recordResolution(
        _ resolution: MultiplayerInputResolution
    ) throws -> MultiplayerLedgerRecordResult {
        guard resolution.version == MultiplayerInputResolution.currentVersion,
            resolution.inputID.seat >= 0,
            resolution.inputID.inputSequence > 0
        else {
            throw MultiplayerInputLedgerError.invalidResolution(resolution.inputID)
        }
        if let resolved = resolvedByID[resolution.inputID] {
            guard resolved.resolution == resolution else {
                throw MultiplayerInputLedgerError.conflictingResolution(
                    resolution.inputID
                )
            }
            return .duplicate
        }
        if let existing = resolutionByID[resolution.inputID] {
            guard existing == resolution else {
                throw MultiplayerInputLedgerError.conflictingResolution(
                    resolution.inputID
                )
            }
            return .duplicate
        }
        resolutionByID[resolution.inputID] = resolution
        return closeIgnoredPairIfComplete(resolution.inputID)
            ? .resolvedIgnored
            : .inserted
    }

    mutating func consume(events: [MultiplayerEvent]) throws -> Bool {
        var pairs: [(MultiplayerInputID, ResolvedPair)] = []
        var claimedSequences: Set<Int> = []
        for event in events {
            guard let eventEvidence = Self.requiredEvidence(for: event) else {
                continue
            }
            let eventSequence = event.sequence
            let matches = resolutionByID.values.filter { resolution in
                if case .committed(let committedSequence) = resolution.disposition {
                    return committedSequence == eventSequence
                }
                return false
            }
            guard !matches.isEmpty else { return false }
            guard matches.count == 1,
                claimedSequences.insert(eventSequence).inserted
            else {
                throw MultiplayerInputLedgerError.duplicateCommittedEvent(eventSequence)
            }
            let resolution = matches[0]
            guard let evidence = evidenceByID[resolution.inputID] else { return false }
            guard evidence.id.seat == eventEvidence.seat,
                evidence.cell == eventEvidence.cell,
                evidence.inputAt == eventEvidence.inputAt
            else {
                throw MultiplayerInputLedgerError.committedEventMismatch(
                    resolution.inputID
                )
            }
            pairs.append(
                (
                    resolution.inputID,
                    ResolvedPair(evidence: evidence, resolution: resolution)
                )
            )
        }
        for (inputID, pair) in pairs {
            evidenceByID.removeValue(forKey: inputID)
            resolutionByID.removeValue(forKey: inputID)
            resolvedByID[inputID] = pair
        }
        return true
    }

    private mutating func closeIgnoredPairIfComplete(
        _ inputID: MultiplayerInputID
    ) -> Bool {
        guard let evidence = evidenceByID[inputID],
            let resolution = resolutionByID[inputID],
            case .ignored = resolution.disposition
        else { return false }
        evidenceByID.removeValue(forKey: inputID)
        resolutionByID.removeValue(forKey: inputID)
        resolvedByID[inputID] = ResolvedPair(
            evidence: evidence,
            resolution: resolution
        )
        return true
    }

    private static func requiredEvidence(
        for event: MultiplayerEvent
    ) -> MultiplayerInputEvidenceKey? {
        MultiplayerPeerConsistency.requiredEvidence(for: event)
    }
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
