import Foundation

public enum MultiplayerProtocolConstants {
    public static let buildID = "20260729-1"
    public static let ruleset = "multiplayer-own-color-v1"
    public static let protocolVersion = 1
    public static let proofVersion = 1
    public static let minimumPlayers = 2
    public static let maximumPlayers = 4
    public static let startingLives = 3
    public static let boardCellCount = 16
    public static let maximumEvents = 2_500
    public static let maximumDurationMilliseconds = 15 * 60 * 1_000
    public static let recoveryMilliseconds = 1_500
    public static let dodgePoints = 550
    /// Hold local and remote inputs this long before advancing canonical time.
    ///
    /// Integration sorts queued inputs by `(inputAt, seat, inputSequence)`,
    /// applies every input at or before `now - coordinatorReorderMilliseconds`,
    /// then advances the coordinator only to that watermark.
    public static let coordinatorReorderMilliseconds = 250
}

public enum MultiplayerProtocolError: Error, Equatable, CustomStringConvertible, Sendable {
    case invalidManifest(String)
    case invalidTranscript(String)
    case invalidEvent(String)
    case unexpectedSequence(expected: Int, actual: Int)
    case nonMonotonicTime(previous: Int, actual: Int)
    case illegalTransition(String)

    public var description: String {
        switch self {
        case .invalidManifest(let message):
            "Invalid multiplayer manifest: \(message)"
        case .invalidTranscript(let message):
            "Invalid multiplayer transcript: \(message)"
        case .invalidEvent(let message):
            "Invalid multiplayer event: \(message)"
        case .unexpectedSequence(let expected, let actual):
            "Expected multiplayer event sequence \(expected), received \(actual)."
        case .nonMonotonicTime(let previous, let actual):
            "Multiplayer event time \(actual) precedes \(previous)."
        case .illegalTransition(let message):
            "Illegal multiplayer transition: \(message)"
        }
    }
}

public struct MultiplayerManifestParticipant: Codable, Equatable, Hashable, Sendable {
    public let participantId: String
    public let seat: Int
    public let colorIndex: Int

    public init(participantId: String, seat: Int, colorIndex: Int) {
        self.participantId = participantId
        self.seat = seat
        self.colorIndex = colorIndex
    }
}

public struct MultiplayerManifest: Codable, Equatable, Sendable {
    public let protocolVersion: Int
    public let ruleset: String
    public let proofVersion: Int
    public let matchId: String
    public let buildId: String
    public let seed: String
    public let startingLives: Int
    public let participants: [MultiplayerManifestParticipant]
    public let manifestHash: String

    public init(
        protocolVersion: Int = MultiplayerProtocolConstants.protocolVersion,
        ruleset: String = MultiplayerProtocolConstants.ruleset,
        proofVersion: Int = MultiplayerProtocolConstants.proofVersion,
        matchId: String,
        buildId: String = MultiplayerProtocolConstants.buildID,
        seed: String,
        startingLives: Int = MultiplayerProtocolConstants.startingLives,
        participants: [MultiplayerManifestParticipant],
        manifestHash: String
    ) {
        self.protocolVersion = protocolVersion
        self.ruleset = ruleset
        self.proofVersion = proofVersion
        self.matchId = matchId
        self.buildId = buildId
        self.seed = seed
        self.startingLives = startingLives
        self.participants = participants
        self.manifestHash = manifestHash
    }

    public func validate() throws {
        guard protocolVersion == MultiplayerProtocolConstants.protocolVersion else {
            throw MultiplayerProtocolError.invalidManifest("unsupported protocolVersion")
        }
        guard proofVersion == MultiplayerProtocolConstants.proofVersion else {
            throw MultiplayerProtocolError.invalidManifest("unsupported proofVersion")
        }
        guard ruleset == MultiplayerProtocolConstants.ruleset else {
            throw MultiplayerProtocolError.invalidManifest("unsupported ruleset")
        }
        guard buildId == MultiplayerProtocolConstants.buildID else {
            throw MultiplayerProtocolError.invalidManifest("unsupported buildId")
        }
        guard isUUIDv4(matchId) else {
            throw MultiplayerProtocolError.invalidManifest("matchId is not a UUIDv4")
        }
        guard startingLives == MultiplayerProtocolConstants.startingLives else {
            throw MultiplayerProtocolError.invalidManifest("startingLives must be 3")
        }
        guard
            (MultiplayerProtocolConstants.minimumPlayers...MultiplayerProtocolConstants.maximumPlayers)
                .contains(participants.count)
        else {
            throw MultiplayerProtocolError.invalidManifest("participant count must be 2...4")
        }

        let participantIDs = Set(participants.map(\.participantId))
        let seats = Set(participants.map(\.seat))
        let colors = Set(participants.map(\.colorIndex))
        guard participantIDs.count == participants.count,
            seats.count == participants.count,
            colors.count == participants.count
        else {
            throw MultiplayerProtocolError.invalidManifest(
                "participant IDs, seats, and color indexes must be unique"
            )
        }
        guard
            participants.allSatisfy({
                isUUIDv4($0.participantId)
                    && (0..<participants.count).contains($0.seat)
                    && (0..<gameColors.count).contains($0.colorIndex)
            })
        else {
            throw MultiplayerProtocolError.invalidManifest("participant fields are out of bounds")
        }
        guard seats == Set(0..<participants.count) else {
            throw MultiplayerProtocolError.invalidManifest("participant seats must be contiguous")
        }
        guard base64URLByteCount(seed) == 32 else {
            throw MultiplayerProtocolError.invalidManifest("seed must be unpadded base64url for 32 bytes")
        }
        guard base64URLByteCount(manifestHash) == 32 else {
            throw MultiplayerProtocolError.invalidManifest(
                "manifestHash must be unpadded base64url SHA-256"
            )
        }
    }
}

public enum MultiplayerMissReason: Int, Codable, CaseIterable, Sendable {
    case empty = 0
    case wrong = 1
    case late = 2
}

/// The exact compact integer event vocabulary replayed by PHP.
///
/// The custom Codable implementation intentionally emits and accepts only the
/// version-1 unkeyed tuples. Do not replace it with synthesized keyed JSON.
public enum MultiplayerEvent: Equatable, Sendable {
    case target(
        sequence: Int,
        at: Int,
        ownerSeat: Int,
        targetId: Int,
        cell: Int,
        colorIndex: Int
    )
    case hit(
        sequence: Int,
        inputAt: Int,
        handledAt: Int,
        seat: Int,
        targetId: Int,
        cell: Int
    )
    case miss(
        sequence: Int,
        inputAt: Int,
        handledAt: Int,
        seat: Int,
        reason: MultiplayerMissReason,
        cell: Int
    )
    case decoyActivate(
        sequence: Int,
        at: Int,
        ownerSeat: Int,
        decoyId: Int,
        cell: Int,
        colorIndex: Int,
        lifetimeMilliseconds: Int
    )
    case decoyExpire(sequence: Int, at: Int, decoyId: Int)
    case playerOut(sequence: Int, at: Int, seat: Int)
    case finish(sequence: Int, at: Int)

    public var sequence: Int {
        switch self {
        case .target(let sequence, _, _, _, _, _),
            .hit(let sequence, _, _, _, _, _),
            .miss(let sequence, _, _, _, _, _),
            .decoyActivate(let sequence, _, _, _, _, _, _),
            .decoyExpire(let sequence, _, _),
            .playerOut(let sequence, _, _),
            .finish(let sequence, _):
            sequence
        }
    }

    /// The authoritative tuple time used by PHP to order events.
    ///
    /// Input events are ordered by `inputAt`; `handledAt` is retained
    /// separately as handler-lag evidence and for subsequent scheduling bounds.
    public var logicalMilliseconds: Int {
        switch self {
        case .target(_, let at, _, _, _, _),
            .decoyActivate(_, let at, _, _, _, _, _),
            .decoyExpire(_, let at, _),
            .playerOut(_, let at, _),
            .finish(_, let at):
            at
        case .hit(_, let inputAt, _, _, _, _),
            .miss(_, let inputAt, _, _, _, _):
            inputAt
        }
    }

    /// Coordinator-clock time after any input handler delay.
    public var handledMilliseconds: Int {
        switch self {
        case .hit(_, _, let handledAt, _, _, _),
            .miss(_, _, let handledAt, _, _, _):
            handledAt
        default:
            logicalMilliseconds
        }
    }

    public var integerTuple: [Int] {
        switch self {
        case .target(let sequence, let at, let ownerSeat, let targetId, let cell, let colorIndex):
            [0, sequence, at, ownerSeat, targetId, cell, colorIndex]
        case .hit(let sequence, let inputAt, let handledAt, let seat, let targetId, let cell):
            [1, sequence, inputAt, handledAt, seat, targetId, cell]
        case .miss(let sequence, let inputAt, let handledAt, let seat, let reason, let cell):
            [2, sequence, inputAt, handledAt, seat, reason.rawValue, cell]
        case .decoyActivate(
            let
                sequence,
            let
                at,
            let
                ownerSeat,
            let
                decoyId,
            let
                cell,
            let
                colorIndex,
            let
                lifetimeMilliseconds
        ):
            [3, sequence, at, ownerSeat, decoyId, cell, colorIndex, lifetimeMilliseconds]
        case .decoyExpire(let sequence, let at, let decoyId):
            [4, sequence, at, decoyId]
        case .playerOut(let sequence, let at, let seat):
            [5, sequence, at, seat]
        case .finish(let sequence, let at):
            [6, sequence, at]
        }
    }

    public init(integerTuple tuple: [Int]) throws {
        guard let opcode = tuple.first else {
            throw MultiplayerProtocolError.invalidEvent("event tuple is empty")
        }
        switch opcode {
        case 0 where tuple.count == 7:
            self = .target(
                sequence: tuple[1],
                at: tuple[2],
                ownerSeat: tuple[3],
                targetId: tuple[4],
                cell: tuple[5],
                colorIndex: tuple[6]
            )
        case 1 where tuple.count == 7:
            self = .hit(
                sequence: tuple[1],
                inputAt: tuple[2],
                handledAt: tuple[3],
                seat: tuple[4],
                targetId: tuple[5],
                cell: tuple[6]
            )
        case 2 where tuple.count == 7:
            guard let reason = MultiplayerMissReason(rawValue: tuple[5]) else {
                throw MultiplayerProtocolError.invalidEvent("unknown miss reason")
            }
            self = .miss(
                sequence: tuple[1],
                inputAt: tuple[2],
                handledAt: tuple[3],
                seat: tuple[4],
                reason: reason,
                cell: tuple[6]
            )
        case 3 where tuple.count == 8:
            self = .decoyActivate(
                sequence: tuple[1],
                at: tuple[2],
                ownerSeat: tuple[3],
                decoyId: tuple[4],
                cell: tuple[5],
                colorIndex: tuple[6],
                lifetimeMilliseconds: tuple[7]
            )
        case 4 where tuple.count == 4:
            self = .decoyExpire(sequence: tuple[1], at: tuple[2], decoyId: tuple[3])
        case 5 where tuple.count == 4:
            self = .playerOut(sequence: tuple[1], at: tuple[2], seat: tuple[3])
        case 6 where tuple.count == 3:
            self = .finish(sequence: tuple[1], at: tuple[2])
        default:
            throw MultiplayerProtocolError.invalidEvent(
                "unknown opcode or unexpected tuple length"
            )
        }
    }
}

extension MultiplayerEvent: Codable {
    public init(from decoder: Decoder) throws {
        var tuple = try decoder.unkeyedContainer()
        let opcode = try tuple.decode(Int.self)

        switch opcode {
        case 0:
            self = try .target(
                sequence: tuple.decode(Int.self),
                at: tuple.decode(Int.self),
                ownerSeat: tuple.decode(Int.self),
                targetId: tuple.decode(Int.self),
                cell: tuple.decode(Int.self),
                colorIndex: tuple.decode(Int.self)
            )
        case 1:
            self = try .hit(
                sequence: tuple.decode(Int.self),
                inputAt: tuple.decode(Int.self),
                handledAt: tuple.decode(Int.self),
                seat: tuple.decode(Int.self),
                targetId: tuple.decode(Int.self),
                cell: tuple.decode(Int.self)
            )
        case 2:
            let sequence = try tuple.decode(Int.self)
            let inputAt = try tuple.decode(Int.self)
            let handledAt = try tuple.decode(Int.self)
            let seat = try tuple.decode(Int.self)
            let reasonValue = try tuple.decode(Int.self)
            guard let reason = MultiplayerMissReason(rawValue: reasonValue) else {
                throw DecodingError.dataCorruptedError(
                    in: tuple,
                    debugDescription: "Unknown multiplayer miss reason \(reasonValue)."
                )
            }
            self = try .miss(
                sequence: sequence,
                inputAt: inputAt,
                handledAt: handledAt,
                seat: seat,
                reason: reason,
                cell: tuple.decode(Int.self)
            )
        case 3:
            self = try .decoyActivate(
                sequence: tuple.decode(Int.self),
                at: tuple.decode(Int.self),
                ownerSeat: tuple.decode(Int.self),
                decoyId: tuple.decode(Int.self),
                cell: tuple.decode(Int.self),
                colorIndex: tuple.decode(Int.self),
                lifetimeMilliseconds: tuple.decode(Int.self)
            )
        case 4:
            self = try .decoyExpire(
                sequence: tuple.decode(Int.self),
                at: tuple.decode(Int.self),
                decoyId: tuple.decode(Int.self)
            )
        case 5:
            self = try .playerOut(
                sequence: tuple.decode(Int.self),
                at: tuple.decode(Int.self),
                seat: tuple.decode(Int.self)
            )
        case 6:
            self = try .finish(
                sequence: tuple.decode(Int.self),
                at: tuple.decode(Int.self)
            )
        default:
            throw DecodingError.dataCorruptedError(
                in: tuple,
                debugDescription: "Unknown multiplayer opcode \(opcode)."
            )
        }

        guard tuple.isAtEnd else {
            throw DecodingError.dataCorruptedError(
                in: tuple,
                debugDescription: "Multiplayer event contains unexpected fields."
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var tuple = encoder.unkeyedContainer()
        for member in integerTuple {
            try tuple.encode(member)
        }
    }
}

public struct MultiplayerTranscript: Codable, Equatable, Sendable {
    public let matchId: String
    public let buildId: String
    public let ruleset: String
    public let protocolVersion: Int
    public let proofVersion: Int
    public let events: [MultiplayerEvent]

    public init(
        matchId: String,
        buildId: String = MultiplayerProtocolConstants.buildID,
        ruleset: String = MultiplayerProtocolConstants.ruleset,
        protocolVersion: Int = MultiplayerProtocolConstants.protocolVersion,
        proofVersion: Int = MultiplayerProtocolConstants.proofVersion,
        events: [MultiplayerEvent]
    ) {
        self.matchId = matchId
        self.buildId = buildId
        self.ruleset = ruleset
        self.protocolVersion = protocolVersion
        self.proofVersion = proofVersion
        self.events = events
    }

    public func validate(against manifest: MultiplayerManifest) throws {
        try manifest.validate()
        guard matchId == manifest.matchId,
            buildId == manifest.buildId,
            ruleset == manifest.ruleset,
            protocolVersion == manifest.protocolVersion,
            proofVersion == manifest.proofVersion
        else {
            throw MultiplayerProtocolError.invalidTranscript("manifest tuple does not match")
        }
        guard events.count <= MultiplayerProtocolConstants.maximumEvents else {
            throw MultiplayerProtocolError.invalidTranscript("event cap exceeded")
        }

        var previousTime = 0
        for (offset, event) in events.enumerated() {
            let expected = offset + 1
            guard event.sequence == expected else {
                throw MultiplayerProtocolError.unexpectedSequence(
                    expected: expected,
                    actual: event.sequence
                )
            }
            guard event.logicalMilliseconds >= previousTime else {
                throw MultiplayerProtocolError.nonMonotonicTime(
                    previous: previousTime,
                    actual: event.logicalMilliseconds
                )
            }
            guard
                (0...MultiplayerProtocolConstants.maximumDurationMilliseconds)
                    .contains(event.logicalMilliseconds)
            else {
                throw MultiplayerProtocolError.invalidTranscript("event time is out of bounds")
            }
            previousTime = event.logicalMilliseconds
        }
    }
}

private func base64URLByteCount(_ value: String) -> Int? {
    guard !value.isEmpty,
        !value.contains("="),
        value.unicodeScalars.allSatisfy({
            CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_"
        })
    else {
        return nil
    }
    var normalized = value.replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    normalized.append(String(repeating: "=", count: (4 - normalized.count % 4) % 4))
    return Data(base64Encoded: normalized)?.count
}

private func isUUIDv4(_ value: String) -> Bool {
    guard UUID(uuidString: value) != nil else { return false }
    let normalized = value.lowercased()
    guard normalized.count == 36 else { return false }
    let characters = Array(normalized)
    return characters[14] == "4" && "89ab".contains(characters[19])
}
