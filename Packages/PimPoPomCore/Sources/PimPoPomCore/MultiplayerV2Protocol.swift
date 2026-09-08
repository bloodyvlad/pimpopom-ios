import Foundation

/// A separately versioned, server-owned protocol. It never encodes v1 peer evidence.
public enum MP2Protocol {
    public static let version = 2
    public static let ruleset = "multiplayer-shared-arcade-v2"
    public static let lateInputGraceMs = 2_000
    public static let maximumDurationMs = 900_000
    public static let maximumInputID = 1_000_000
}

public struct MP2Player: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var seat: Int
    public var colorIndex: Int
    public var name: String
    public var petID: String?
    public var ready: Bool
    public var readyIntentID: Int
    public var connected: Bool
    public var lives: Int
    public var score: Int
    public var hits: Int
    public var misses: Int
    public var dodges: Int
    public var multiplier: Int
    public var streakProgress: Int
    public var recoveryUntilMs: Int
    public var reactionTotalMs: Int
    public var fastestReactionMs: Int?
    public var challengeBaselineHits: Int?
    public var isOut: Bool { lives == 0 }
    public var averageReactionMs: Int? { hits == 0 ? nil : Int((Double(reactionTotalMs) / Double(hits)).rounded()) }

    public init(
        id: String, seat: Int, colorIndex: Int, name: String, petID: String? = nil,
        ready: Bool = false, readyIntentID: Int = 0, connected: Bool = true,
        lives: Int = 3, score: Int = 0, hits: Int = 0, misses: Int = 0, dodges: Int = 0,
        multiplier: Int = 1, streakProgress: Int = 0, recoveryUntilMs: Int = 0,
        reactionTotalMs: Int = 0, fastestReactionMs: Int? = nil, challengeBaselineHits: Int? = nil
    ) {
        self.id = id
        self.seat = seat
        self.colorIndex = colorIndex
        self.name = name
        self.petID = petID
        self.ready = ready
        self.readyIntentID = readyIntentID
        self.connected = connected
        self.lives = lives
        self.score = score
        self.hits = hits
        self.misses = misses
        self.dodges = dodges
        self.multiplier = multiplier
        self.streakProgress = streakProgress
        self.recoveryUntilMs = recoveryUntilMs
        self.reactionTotalMs = reactionTotalMs
        self.fastestReactionMs = fastestReactionMs
        self.challengeBaselineHits = challengeBaselineHits
    }
}

public struct MP2Target: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let cell: Int
    public let ownerSeat: Int
    public let colorIndex: Int
    public let activateAtMs: Int
    public let responseWindowMs: Int
    public var expiresAtMs: Int { activateAtMs + responseWindowMs }

    public init(id: Int, cell: Int, ownerSeat: Int, colorIndex: Int, activateAtMs: Int, responseWindowMs: Int) {
        self.id = id
        self.cell = cell
        self.ownerSeat = ownerSeat
        self.colorIndex = colorIndex
        self.activateAtMs = activateAtMs
        self.responseWindowMs = responseWindowMs
    }
}

/// Always render an explicit trap marker, including when optional color glyphs are off.
public struct MP2Decoy: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let cell: Int
    public let colorIndex: Int
    public let beneficiarySeat: Int
    public let activateAtMs: Int
    public let expiresAtMs: Int

    public init(id: Int, cell: Int, colorIndex: Int, beneficiarySeat: Int, activateAtMs: Int, expiresAtMs: Int) {
        self.id = id
        self.cell = cell
        self.colorIndex = colorIndex
        self.beneficiarySeat = beneficiarySeat
        self.activateAtMs = activateAtMs
        self.expiresAtMs = expiresAtMs
    }
}

public enum MP2MatchPhase: String, Codable, Sendable {
    case playing, finishing, finished
}

public struct MP2Snapshot: Codable, Equatable, Sendable {
    public let matchID: String
    public let revision: Int
    public let elapsedMs: Int
    public let phase: MP2MatchPhase
    public let gridDimension: Int
    public let players: [MP2Player]
    public let targets: [MP2Target]
    public let decoys: [MP2Decoy]

    public init(
        matchID: String, revision: Int, elapsedMs: Int, phase: MP2MatchPhase,
        gridDimension: Int, players: [MP2Player], targets: [MP2Target], decoys: [MP2Decoy]
    ) {
        self.matchID = matchID
        self.revision = revision
        self.elapsedMs = elapsedMs
        self.phase = phase
        self.gridDimension = gridDimension
        self.players = players
        self.targets = targets
        self.decoys = decoys
    }
}

/// Times are original first-visible/contact timestamps converted to the match clock.
/// They are client evidence, not proof of a visible frame or human interaction.
public struct MP2Input: Codable, Equatable, Sendable {
    public let id: Int
    public let seat: Int
    public let targetID: Int?
    public let cell: Int
    public let presentedAtMs: Int
    public let contactAtMs: Int
    public let lastServerRevision: Int
    public let roomEpoch: String
    public let sessionGeneration: Int

    public init(
        id: Int, seat: Int, targetID: Int?, cell: Int, presentedAtMs: Int,
        contactAtMs: Int, lastServerRevision: Int = 0, roomEpoch: String = "", sessionGeneration: Int = 0
    ) {
        self.id = id
        self.seat = seat
        self.targetID = targetID
        self.cell = cell
        self.presentedAtMs = presentedAtMs
        self.contactAtMs = contactAtMs
        self.lastServerRevision = lastServerRevision
        self.roomEpoch = roomEpoch
        self.sessionGeneration = sessionGeneration
    }
}

public struct MP2InputReceipt: Codable, Equatable, Sendable {
    public let id: Int
    public let accepted: Bool
    public let reason: String
    public let revision: Int

    public init(id: Int, accepted: Bool, reason: String, revision: Int = 0) {
        self.id = id
        self.accepted = accepted
        self.reason = reason
        self.revision = revision
    }
}

public enum MP2RoomPhase: String, Codable, Sendable {
    case waiting, countdown, playing, finished
}

public struct MP2RoomSummary: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var hostName: String
    public var capacity: Int
    public var playerCount: Int
    public var revision: Int
    public var phase: MP2RoomPhase

    public init(id: String, hostName: String, capacity: Int, playerCount: Int, revision: Int, phase: MP2RoomPhase) {
        self.id = id
        self.hostName = hostName
        self.capacity = capacity
        self.playerCount = playerCount
        self.revision = revision
        self.phase = phase
    }
}

public struct MP2Room: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var epoch: String
    public var revision: Int
    public var rosterRevision: Int
    public var hostPlayerID: String
    public var capacity: Int
    public var phase: MP2RoomPhase
    public var players: [MP2Player]
    public var matchID: String?
    public var startsAtServerMs: Int?

    public init(
        id: String, revision: Int, rosterRevision: Int, hostPlayerID: String, capacity: Int,
        phase: MP2RoomPhase, players: [MP2Player], matchID: String? = nil, startsAtServerMs: Int? = nil,
        epoch: String = ""
    ) {
        self.id = id
        self.epoch = epoch
        self.revision = revision
        self.rosterRevision = rosterRevision
        self.hostPlayerID = hostPlayerID
        self.capacity = capacity
        self.phase = phase
        self.players = players
        self.matchID = matchID
        self.startsAtServerMs = startsAtServerMs
    }
}

/// Swift's synthesized enum Codable representation is the v2 JSON wire schema.
/// One ordered authenticated socket owns the seat; the service validates input.seat.
public enum MP2ClientMessage: Codable, Equatable, Sendable {
    case hello(ticket: String, protocolVersion: Int)
    case list
    case create(capacity: Int)
    case join(roomID: String)
    case resume(roomID: String, credential: String, generation: Int)
    case leave
    case ready(value: Bool, intentID: Int, rosterRevision: Int)
    case start
    case ping(id: Int, clientTimeMs: Int)
    case input(MP2Input)
}

public enum MP2ServerMessage: Codable, Equatable, Sendable {
    case welcome(playerID: String, connectionID: String, serverTimeMs: Int)
    case resumeCredential(roomID: String, credential: String, generation: Int)
    case list([MP2RoomSummary])
    case room(MP2Room)
    case snapshot(MP2Snapshot)
    case receipt(MP2InputReceipt)
    case error(code: String, message: String)
    case pong(id: Int, clientTimeMs: Int, serverTimeMs: Int)
}
