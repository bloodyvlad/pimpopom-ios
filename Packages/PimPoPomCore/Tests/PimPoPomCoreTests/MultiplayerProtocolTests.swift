import Foundation
import Testing

@testable import PimPoPomCore

private let multiplayerBase64URL32 = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

private func protocolManifest() -> MultiplayerManifest {
    MultiplayerManifest(
        matchId: "6B51C40A-FA77-4F31-AC42-BD9A22226280",
        seed: multiplayerBase64URL32,
        participants: [
            MultiplayerManifestParticipant(
                participantId: "00000000-0000-4000-8000-000000000001",
                seat: 0,
                colorIndex: 0
            ),
            MultiplayerManifestParticipant(
                participantId: "00000000-0000-4000-8000-000000000002",
                seat: 1,
                colorIndex: 1
            ),
        ],
        manifestHash: multiplayerBase64URL32
    )
}

@Test("Multiplayer events encode as the exact compact integer tuples")
func multiplayerEventWireTuples() throws {
    let events: [MultiplayerEvent] = [
        .target(sequence: 1, at: 250, ownerSeat: 0, targetId: 1, cell: 3, colorIndex: 0),
        .hit(sequence: 2, inputAt: 420, handledAt: 430, seat: 0, targetId: 1, cell: 3),
        .miss(sequence: 3, inputAt: 700, handledAt: 710, seat: 1, reason: .wrong, cell: 3),
        .decoyActivate(
            sequence: 4,
            at: 10_000,
            ownerSeat: 0,
            decoyId: 1,
            cell: 6,
            colorIndex: 5,
            lifetimeMilliseconds: 1_750
        ),
        .decoyExpire(sequence: 5, at: 11_750, decoyId: 1),
        .playerOut(sequence: 6, at: 12_000, seat: 1),
        .finish(sequence: 7, at: 12_000),
    ]
    #expect(
        events.map(\.integerTuple) == [
            [0, 1, 250, 0, 1, 3, 0],
            [1, 2, 420, 430, 0, 1, 3],
            [2, 3, 700, 710, 1, 1, 3],
            [3, 4, 10_000, 0, 1, 6, 5, 1_750],
            [4, 5, 11_750, 1],
            [5, 6, 12_000, 1],
            [6, 7, 12_000],
        ]
    )

    let encoded = try JSONEncoder().encode(events)
    let decoded = try JSONDecoder().decode([MultiplayerEvent].self, from: encoded)
    #expect(decoded == events)
    #expect(try events.map(\.integerTuple).map(MultiplayerEvent.init(integerTuple:)) == events)
    #expect(
        String(decoding: encoded, as: UTF8.self)
            == "[[0,1,250,0,1,3,0],[1,2,420,430,0,1,3],[2,3,700,710,1,1,3],[3,4,10000,0,1,6,5,1750],[4,5,11750,1],[5,6,12000,1],[6,7,12000]]"
    )
}

@Test("Multiplayer tuple decoder rejects unknown and extended tuples")
func multiplayerEventWireRejection() {
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(MultiplayerEvent.self, from: Data("[7,1,0]".utf8))
    }
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(MultiplayerEvent.self, from: Data("[6,1,0,99]".utf8))
    }
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(MultiplayerEvent.self, from: Data("[2,1,0,0,0,9,0]".utf8))
    }
}

@Test("Manifest and transcript enforce the immutable version tuple")
func multiplayerManifestAndTranscriptValidation() throws {
    let manifest = protocolManifest()
    try manifest.validate()
    let transcript = MultiplayerTranscript(
        matchId: manifest.matchId,
        events: [
            .target(sequence: 1, at: 250, ownerSeat: 0, targetId: 1, cell: 0, colorIndex: 0),
            .hit(sequence: 2, inputAt: 400, handledAt: 410, seat: 0, targetId: 1, cell: 0),
        ]
    )
    try transcript.validate(against: manifest)

    let wrongBuild = MultiplayerTranscript(
        matchId: manifest.matchId,
        buildId: "20260728-2",
        events: transcript.events
    )
    #expect(throws: MultiplayerProtocolError.self) {
        try wrongBuild.validate(against: manifest)
    }
    let badSequence = MultiplayerTranscript(
        matchId: manifest.matchId,
        events: [.finish(sequence: 2, at: 250)]
    )
    #expect(throws: MultiplayerProtocolError.self) {
        try badSequence.validate(against: manifest)
    }
}

@Test("Manifest rejects duplicate seats, colors, and malformed nonce material")
func multiplayerManifestRejection() {
    let duplicate = MultiplayerManifest(
        matchId: "6B51C40A-FA77-4F31-AC42-BD9A22226280",
        seed: multiplayerBase64URL32,
        participants: [
            MultiplayerManifestParticipant(
                participantId: "00000000-0000-4000-8000-000000000001",
                seat: 0,
                colorIndex: 0
            ),
            MultiplayerManifestParticipant(
                participantId: "00000000-0000-4000-8000-000000000002",
                seat: 0,
                colorIndex: 0
            ),
        ],
        manifestHash: multiplayerBase64URL32
    )
    #expect(throws: MultiplayerProtocolError.self) {
        try duplicate.validate()
    }

    let padded = MultiplayerManifest(
        matchId: duplicate.matchId,
        seed: "\(multiplayerBase64URL32)=",
        participants: protocolManifest().participants,
        manifestHash: multiplayerBase64URL32
    )
    #expect(throws: MultiplayerProtocolError.self) {
        try padded.validate()
    }
}
