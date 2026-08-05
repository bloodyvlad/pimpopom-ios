import Combine
import Foundation
@preconcurrency import GameKit
import PimPoPomCore

struct MultiplayerGameKitPlayer: Equatable, Identifiable, Sendable {
    let gamePlayerID: String
    let displayName: String

    var id: String { gamePlayerID }
}

struct MultiplayerMatchmakingConfiguration: Equatable, Sendable {
    let playerGroup: Int
    let participantCount: Int

    init(playerGroup: Int, participantCount: Int) throws {
        guard (1...Int(Int32.max)).contains(playerGroup),
            (MultiplayerAPIContract.minimumPlayers...MultiplayerAPIContract.maximumPlayers)
                .contains(participantCount)
        else {
            throw MultiplayerGameKitError.invalidMatchmakingConfiguration
        }
        self.playerGroup = playerGroup
        self.participantCount = participantCount
    }
}

struct MultiplayerGameKitRoster: Equatable, Sendable {
    let localGamePlayerID: String
    let observedGamePlayerIDs: [String]
    let coordinatorGamePlayerID: String

    init(localGamePlayerID: String, observedGamePlayerIDs: [String]) throws {
        let observed = observedGamePlayerIDs.sorted()
        let allPlayers = [localGamePlayerID] + observed
        guard !localGamePlayerID.isEmpty,
            (MultiplayerAPIContract.minimumPlayers...MultiplayerAPIContract.maximumPlayers)
                .contains(allPlayers.count),
            !observed.contains(where: \.isEmpty),
            Set(allPlayers).count == allPlayers.count
        else {
            throw MultiplayerGameKitError.invalidRoster
        }
        self.localGamePlayerID = localGamePlayerID
        self.observedGamePlayerIDs = observed
        coordinatorGamePlayerID = allPlayers.min()!
    }

    var gamePlayerIDs: [String] {
        ([localGamePlayerID] + observedGamePlayerIDs).sorted()
    }

    var confirmationRequest: MultiplayerRosterConfirmationRequest {
        MultiplayerRosterConfirmationRequest(
            localGamePlayerId: localGamePlayerID,
            observedGamePlayerIds: observedGamePlayerIDs,
            coordinatorGamePlayerId: coordinatorGamePlayerID
        )
    }
}

enum MultiplayerGameKitConnectionStatus: Equatable, Sendable {
    case connected
    case disconnected
    case unknown
}

struct MultiplayerGameKitFailure: LocalizedError, Equatable, Sendable {
    // GKError.Code.iCloudUnavailable is raw value 35. The typed case is
    // available from iOS 17.2, while PimPoPom still supports iOS 17.0.
    static let iCloudUnavailableCode = 35

    enum Kind: Equatable, Sendable {
        case iCloudUnavailable
        case other
    }

    let domain: String
    let code: Int
    let message: String

    init(error: any Error) {
        let nsError = error as NSError
        self.init(
            domain: nsError.domain,
            code: nsError.code,
            message: nsError.localizedDescription
        )
    }

    init(domain: String, code: Int, message: String) {
        self.domain = domain
        self.code = code
        self.message = message
    }

    var kind: Kind {
        if domain == GKErrorDomain,
            code == Self.iCloudUnavailableCode
        {
            return .iCloudUnavailable
        }
        return .other
    }

    var errorDescription: String? { message }
}

struct MultiplayerMatchmakingAttemptGate: Equatable, Sendable {
    private(set) var hasStartedAttempt = false
    private(set) var failure: MultiplayerGameKitFailure?

    var allowsAttempt: Bool { !hasStartedAttempt && failure == nil }

    @discardableResult
    mutating func beginAttempt() -> Bool {
        guard allowsAttempt else { return false }
        hasStartedAttempt = true
        return true
    }

    mutating func block(with failure: MultiplayerGameKitFailure) {
        hasStartedAttempt = true
        self.failure = failure
    }

    mutating func clear() {
        hasStartedAttempt = false
        failure = nil
    }
}

enum MultiplayerGameKitClientEvent: Equatable, Sendable {
    case rosterChanged
    case received(Data, fromGamePlayerID: String)
    case connectionChanged(String, MultiplayerGameKitConnectionStatus)
    case failed(String)
}

enum MultiplayerGameKitSendMode: Equatable, Sendable {
    case reliable
    case unreliable
}

@MainActor
protocol MultiplayerGameKitClientProtocol: AnyObject {
    var eventHandler: ((MultiplayerGameKitClientEvent) -> Void)? { get set }
    var isAuthenticated: Bool { get }
    var scopedIDsArePersistent: Bool { get }
    var localGamePlayerID: String { get }
    var remotePlayers: [MultiplayerGameKitPlayer] { get }
    var expectedPlayerCount: Int { get }

    func findMatch(configuration: MultiplayerMatchmakingConfiguration) async throws
    func send(
        _ data: Data,
        to gamePlayerIDs: [String]?,
        mode: MultiplayerGameKitSendMode
    ) throws
    func cancel()
}

@MainActor
final class LiveMultiplayerGameKitClient: NSObject, MultiplayerGameKitClientProtocol {
    var eventHandler: ((MultiplayerGameKitClientEvent) -> Void)?

    var isAuthenticated: Bool { GKLocalPlayer.local.isAuthenticated }
    var scopedIDsArePersistent: Bool { GKLocalPlayer.local.scopedIDsArePersistent() }
    var localGamePlayerID: String { GKLocalPlayer.local.gamePlayerID }
    var remotePlayers: [MultiplayerGameKitPlayer] {
        match?.players.map {
            MultiplayerGameKitPlayer(
                gamePlayerID: $0.gamePlayerID,
                displayName: $0.displayName
            )
        } ?? []
    }
    var expectedPlayerCount: Int { match?.expectedPlayerCount ?? 0 }

    private var match: GKMatch?

    private struct UncheckedMatch: @unchecked Sendable {
        let value: GKMatch
    }

    func findMatch(configuration: MultiplayerMatchmakingConfiguration) async throws {
        #if DEBUG
            print(
                "[PimPoPom Multiplayer] GameKit request "
                    + "authenticated=\(isAuthenticated) "
                    + "persistentIDs=\(scopedIDsArePersistent) "
                    + "participants=\(configuration.participantCount) "
                    + "playerGroup=\(configuration.playerGroup)"
            )
        #endif
        guard isAuthenticated, scopedIDsArePersistent, !localGamePlayerID.isEmpty else {
            throw MultiplayerGameKitError.notAuthenticated
        }
        cancel()
        let request = GKMatchRequest()
        request.minPlayers = configuration.participantCount
        request.maxPlayers = configuration.participantCount
        request.defaultNumberOfPlayers = configuration.participantCount
        request.playerGroup = configuration.playerGroup

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, any Error>) in
            GKMatchmaker.shared().findMatch(for: request) { match, error in
                if let error {
                    let failure = MultiplayerGameKitFailure(error: error)
                    Task { @MainActor in
                        continuation.resume(throwing: failure)
                    }
                } else if let match {
                    let uncheckedMatch = UncheckedMatch(value: match)
                    Task { @MainActor [weak self] in
                        guard let self else {
                            continuation.resume(
                                throwing: MultiplayerGameKitError.matchUnavailable
                            )
                            return
                        }
                        self.match = uncheckedMatch.value
                        uncheckedMatch.value.delegate = self
                        GKMatchmaker.shared().finishMatchmaking(for: uncheckedMatch.value)
                        #if DEBUG
                            print(
                                "[PimPoPom Multiplayer] GameKit match acquired "
                                    + "remotePlayers=\(uncheckedMatch.value.players.count) "
                                    + "expectedPlayers=\(uncheckedMatch.value.expectedPlayerCount)"
                            )
                        #endif
                        self.eventHandler?(.rosterChanged)
                        continuation.resume()
                    }
                } else {
                    Task { @MainActor in
                        continuation.resume(throwing: MultiplayerGameKitError.matchUnavailable)
                    }
                }
            }
        }
    }

    func send(
        _ data: Data,
        to gamePlayerIDs: [String]?,
        mode: MultiplayerGameKitSendMode
    ) throws {
        guard let match else { throw MultiplayerGameKitError.matchUnavailable }
        let gameKitMode: GKMatch.SendDataMode =
            mode == .unreliable ? .unreliable : .reliable
        if let gamePlayerIDs {
            let requested = Set(gamePlayerIDs)
            let players = match.players.filter { requested.contains($0.gamePlayerID) }
            guard players.count == requested.count else {
                throw MultiplayerGameKitError.playerUnavailable
            }
            try match.send(data, to: players, dataMode: gameKitMode)
        } else {
            try match.sendData(toAllPlayers: data, with: gameKitMode)
        }
    }

    func cancel() {
        GKMatchmaker.shared().cancel()
        match?.delegate = nil
        match?.disconnect()
        match = nil
    }
}

extension LiveMultiplayerGameKitClient: @preconcurrency GKMatchDelegate {
    func match(
        _: GKMatch,
        didReceive data: Data,
        fromRemotePlayer player: GKPlayer
    ) {
        eventHandler?(.received(data, fromGamePlayerID: player.gamePlayerID))
    }

    func match(
        _: GKMatch,
        player: GKPlayer,
        didChange state: GKPlayerConnectionState
    ) {
        let status: MultiplayerGameKitConnectionStatus =
            switch state {
            case .connected: .connected
            case .disconnected: .disconnected
            default: .unknown
            }
        eventHandler?(.connectionChanged(player.gamePlayerID, status))
        eventHandler?(.rosterChanged)
    }

    func match(_: GKMatch, didFailWithError error: (any Error)?) {
        eventHandler?(
            .failed(error?.localizedDescription ?? "The Game Center match failed.")
        )
    }

    func match(
        _ match: GKMatch,
        shouldReinviteDisconnectedPlayer _: GKPlayer
    ) -> Bool {
        // Apple's automatic reinvite path is supported only for a 1v1 match.
        match.players.count <= 1
    }
}

enum MultiplayerLiveCompatibility: Equatable {
    case collecting
    case unanimous
    case incompatible
}

enum MultiplayerLiveWire {
    static let version = 2
    static let requiredCapabilities: Set<String> = [
        "fast-input-v1",
        "input-resolution-v1",
        "sealed-frontier-v1",
    ]

    static func isCompatible(_ hello: MultiplayerHelloPacket) -> Bool {
        guard hello.liveWireVersion == version,
            let capabilities = hello.capabilities,
            Set(capabilities).count == capabilities.count
        else { return false }
        return Set(capabilities) == requiredCapabilities
    }
}

struct MultiplayerHelloPacket: Codable, Equatable {
    let participantId: String
    let seat: Int
    let colorIndex: Int
    let gamePlayerId: String
    let liveWireVersion: Int?
    let capabilities: [String]?

    init(
        participantId: String,
        seat: Int,
        colorIndex: Int,
        gamePlayerId: String,
        liveWireVersion: Int? = nil,
        capabilities: [String]? = nil
    ) {
        self.participantId = participantId
        self.seat = seat
        self.colorIndex = colorIndex
        self.gamePlayerId = gamePlayerId
        self.liveWireVersion = liveWireVersion
        self.capabilities = capabilities
    }
}

struct MultiplayerRosterConfirmedPacket: Codable, Equatable {
    let confirmedCount: Int
    let participantCount: Int
}

struct MultiplayerClockPingPacket: Codable, Equatable {
    let nonce: Int
    let requesterSendMonotonicMilliseconds: Int
}

struct MultiplayerClockPongPacket: Codable, Equatable {
    let nonce: Int
    let requesterSendMonotonicMilliseconds: Int
    let coordinatorReceiveMonotonicMilliseconds: Int
    let coordinatorSendMonotonicMilliseconds: Int
}

struct MultiplayerStartSignalPacket: Codable, Equatable {
    let manifest: MultiplayerStartManifest
    let coordinatorStartMonotonicMilliseconds: Int
    let presentationLeadMilliseconds: Int
}

struct MultiplayerInputPacket: Codable, Equatable {
    let inputSequence: Int
    let seat: Int
    let cell: Int
    let coordinatorInputMilliseconds: Int

    var id: MultiplayerInputID {
        MultiplayerInputID(seat: seat, inputSequence: inputSequence)
    }

    var sealedInput: MultiplayerSealedInput {
        MultiplayerSealedInput(
            id: id,
            cell: cell,
            inputAt: coordinatorInputMilliseconds
        )
    }
}

enum MultiplayerWireActivationKind: String, Codable, Equatable {
    case target
    case decoy
}

struct MultiplayerWireActivationPlan: Codable, Equatable, Identifiable {
    let planId: Int
    let kind: MultiplayerWireActivationKind
    let at: Int
    let ownerSeat: Int
    let entityId: Int
    let cell: Int
    let colorIndex: Int
    let lifetimeMs: Int?

    var id: Int { planId }
}

struct MultiplayerActivationPlansPacket: Codable, Equatable {
    let plans: [MultiplayerWireActivationPlan]
}

struct MultiplayerCancelActivationPlansPacket: Codable, Equatable {
    let planIds: [Int]
}

struct MultiplayerEventBatchPacket: Codable, Equatable {
    let events: [[Int]]
}

struct MultiplayerAcknowledgementPacket: Codable, Equatable {
    let acknowledgedPacketSequence: Int
    let acknowledgedLane: MultiplayerTransportLane
    let appliedEventSequence: Int

    private enum CodingKeys: String, CodingKey {
        case acknowledgedPacketSequence
        case acknowledgedLane
        case appliedEventSequence
    }

    init(
        acknowledgedPacketSequence: Int,
        acknowledgedLane: MultiplayerTransportLane = .control,
        appliedEventSequence: Int
    ) {
        self.acknowledgedPacketSequence = acknowledgedPacketSequence
        self.acknowledgedLane = acknowledgedLane
        self.appliedEventSequence = appliedEventSequence
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        acknowledgedPacketSequence = try container.decode(
            Int.self,
            forKey: .acknowledgedPacketSequence
        )
        acknowledgedLane =
            try container.decodeIfPresent(
                MultiplayerTransportLane.self,
                forKey: .acknowledgedLane
            ) ?? .control
        appliedEventSequence = try container.decode(
            Int.self,
            forKey: .appliedEventSequence
        )
    }
}

struct MultiplayerSnapshotPacket: Codable, Equatable {
    let afterEventSequence: Int
    let throughEventSequence: Int
    let chunkIndex: Int
    let chunkCount: Int
    let events: [[Int]]
    let pendingPlans: [MultiplayerWireActivationPlan]
    let coordinatorMatchStartMonotonicMilliseconds: Int
    let pauseId: Int?
    let pausedAtLogicalMilliseconds: Int?
}

struct MultiplayerSnapshotRequestPacket: Codable, Equatable {
    let afterEventSequence: Int
}

struct MultiplayerPausePacket: Codable, Equatable {
    let pauseId: Int
    let pausedAtLogicalMilliseconds: Int
}

struct MultiplayerResumePacket: Codable, Equatable {
    let pauseId: Int
    let coordinatorMatchStartMonotonicMilliseconds: Int
}

struct MultiplayerFinishPacket: Codable, Equatable {
    let finalEventSequence: Int
    let manifestHash: String
    let transcriptDigest: String
}

enum MultiplayerPacketPayload: Equatable {
    case hello(MultiplayerHelloPacket)
    case rosterConfirmed(MultiplayerRosterConfirmedPacket)
    case clockPing(MultiplayerClockPingPacket)
    case clockPong(MultiplayerClockPongPacket)
    case startManifest(MultiplayerStartSignalPacket)
    case input(MultiplayerInputPacket)
    case inputSeal(MultiplayerInputSeal)
    case inputResolution(MultiplayerInputResolution)
    case activationPlans(MultiplayerActivationPlansPacket)
    case cancelActivationPlans(MultiplayerCancelActivationPlansPacket)
    case events(MultiplayerEventBatchPacket)
    case acknowledgement(MultiplayerAcknowledgementPacket)
    case snapshot(MultiplayerSnapshotPacket)
    case snapshotRequest(MultiplayerSnapshotRequestPacket)
    case pause(MultiplayerPausePacket)
    case resume(MultiplayerResumePacket)
    case finish(MultiplayerFinishPacket)
}

extension MultiplayerPacketPayload: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case body
    }

    private enum Kind: String, Codable {
        case hello
        case rosterConfirmed
        case clockPing
        case clockPong
        case startManifest
        case input
        case inputSeal
        case inputResolution
        case activationPlans
        case cancelActivationPlans
        case events
        case acknowledgement
        case snapshot
        case snapshotRequest
        case pause
        case resume
        case finish
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .hello:
            self = .hello(try container.decode(MultiplayerHelloPacket.self, forKey: .body))
        case .rosterConfirmed:
            self = .rosterConfirmed(
                try container.decode(MultiplayerRosterConfirmedPacket.self, forKey: .body)
            )
        case .clockPing:
            self = .clockPing(
                try container.decode(MultiplayerClockPingPacket.self, forKey: .body)
            )
        case .clockPong:
            self = .clockPong(
                try container.decode(MultiplayerClockPongPacket.self, forKey: .body)
            )
        case .startManifest:
            self = .startManifest(
                try container.decode(MultiplayerStartSignalPacket.self, forKey: .body)
            )
        case .input:
            self = .input(try container.decode(MultiplayerInputPacket.self, forKey: .body))
        case .inputSeal:
            self = .inputSeal(
                try container.decode(MultiplayerInputSeal.self, forKey: .body)
            )
        case .inputResolution:
            self = .inputResolution(
                try container.decode(MultiplayerInputResolution.self, forKey: .body)
            )
        case .activationPlans:
            self = .activationPlans(
                try container.decode(MultiplayerActivationPlansPacket.self, forKey: .body)
            )
        case .cancelActivationPlans:
            self = .cancelActivationPlans(
                try container.decode(
                    MultiplayerCancelActivationPlansPacket.self,
                    forKey: .body
                )
            )
        case .events:
            self = .events(
                try container.decode(MultiplayerEventBatchPacket.self, forKey: .body)
            )
        case .acknowledgement:
            self = .acknowledgement(
                try container.decode(MultiplayerAcknowledgementPacket.self, forKey: .body)
            )
        case .snapshot:
            self = .snapshot(
                try container.decode(MultiplayerSnapshotPacket.self, forKey: .body)
            )
        case .snapshotRequest:
            self = .snapshotRequest(
                try container.decode(MultiplayerSnapshotRequestPacket.self, forKey: .body)
            )
        case .pause:
            self = .pause(
                try container.decode(MultiplayerPausePacket.self, forKey: .body)
            )
        case .resume:
            self = .resume(
                try container.decode(MultiplayerResumePacket.self, forKey: .body)
            )
        case .finish:
            self = .finish(try container.decode(MultiplayerFinishPacket.self, forKey: .body))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .hello(let body):
            try container.encode(Kind.hello, forKey: .kind)
            try container.encode(body, forKey: .body)
        case .rosterConfirmed(let body):
            try container.encode(Kind.rosterConfirmed, forKey: .kind)
            try container.encode(body, forKey: .body)
        case .clockPing(let body):
            try container.encode(Kind.clockPing, forKey: .kind)
            try container.encode(body, forKey: .body)
        case .clockPong(let body):
            try container.encode(Kind.clockPong, forKey: .kind)
            try container.encode(body, forKey: .body)
        case .startManifest(let body):
            try container.encode(Kind.startManifest, forKey: .kind)
            try container.encode(body, forKey: .body)
        case .input(let body):
            try container.encode(Kind.input, forKey: .kind)
            try container.encode(body, forKey: .body)
        case .inputSeal(let body):
            try container.encode(Kind.inputSeal, forKey: .kind)
            try container.encode(body, forKey: .body)
        case .inputResolution(let body):
            try container.encode(Kind.inputResolution, forKey: .kind)
            try container.encode(body, forKey: .body)
        case .activationPlans(let body):
            try container.encode(Kind.activationPlans, forKey: .kind)
            try container.encode(body, forKey: .body)
        case .cancelActivationPlans(let body):
            try container.encode(Kind.cancelActivationPlans, forKey: .kind)
            try container.encode(body, forKey: .body)
        case .events(let body):
            try container.encode(Kind.events, forKey: .kind)
            try container.encode(body, forKey: .body)
        case .acknowledgement(let body):
            try container.encode(Kind.acknowledgement, forKey: .kind)
            try container.encode(body, forKey: .body)
        case .snapshot(let body):
            try container.encode(Kind.snapshot, forKey: .kind)
            try container.encode(body, forKey: .body)
        case .snapshotRequest(let body):
            try container.encode(Kind.snapshotRequest, forKey: .kind)
            try container.encode(body, forKey: .body)
        case .pause(let body):
            try container.encode(Kind.pause, forKey: .kind)
            try container.encode(body, forKey: .body)
        case .resume(let body):
            try container.encode(Kind.resume, forKey: .kind)
            try container.encode(body, forKey: .body)
        case .finish(let body):
            try container.encode(Kind.finish, forKey: .kind)
            try container.encode(body, forKey: .body)
        }
    }
}

enum MultiplayerTransportLane: String, Codable, CaseIterable, Equatable, Hashable {
    case fastInput
    case evidence
    case canonical
    case control

    var sendMode: MultiplayerGameKitSendMode {
        self == .fastInput ? .unreliable : .reliable
    }
}

private struct MultiplayerLaneSequence: Hashable {
    let lane: MultiplayerTransportLane
    let sequence: Int
}

struct MultiplayerPacketEnvelope: Codable, Equatable {
    static let version = 1

    let version: Int
    let matchId: String
    let packetSequence: Int
    let eventSequence: Int
    let logicalMatchMilliseconds: Int
    let lane: MultiplayerTransportLane
    let payload: MultiplayerPacketPayload

    private enum CodingKeys: String, CodingKey {
        case version
        case matchId
        case packetSequence
        case eventSequence
        case logicalMatchMilliseconds
        case lane
        case payload
    }

    init(
        version: Int,
        matchId: String,
        packetSequence: Int,
        eventSequence: Int,
        logicalMatchMilliseconds: Int,
        lane: MultiplayerTransportLane = .control,
        payload: MultiplayerPacketPayload
    ) {
        self.version = version
        self.matchId = matchId
        self.packetSequence = packetSequence
        self.eventSequence = eventSequence
        self.logicalMatchMilliseconds = logicalMatchMilliseconds
        self.lane = lane
        self.payload = payload
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        matchId = try container.decode(String.self, forKey: .matchId)
        packetSequence = try container.decode(Int.self, forKey: .packetSequence)
        eventSequence = try container.decode(Int.self, forKey: .eventSequence)
        logicalMatchMilliseconds = try container.decode(
            Int.self,
            forKey: .logicalMatchMilliseconds
        )
        lane =
            try container.decodeIfPresent(
                MultiplayerTransportLane.self,
                forKey: .lane
            ) ?? .control
        payload = try container.decode(MultiplayerPacketPayload.self, forKey: .payload)
    }
}

struct MultiplayerReceivedPacket: Equatable {
    let senderGamePlayerID: String
    let envelope: MultiplayerPacketEnvelope
}

struct MultiplayerClockSample: Equatable, Sendable {
    let roundTripMilliseconds: Int
    let coordinatorOffsetMilliseconds: Double
}

struct MultiplayerClockEstimator: Equatable, Sendable {
    private(set) var samples: [MultiplayerClockSample] = []

    var hasEstimate: Bool { !samples.isEmpty }
    var roundTripMilliseconds: Int? {
        samples.min(by: { $0.roundTripMilliseconds < $1.roundTripMilliseconds })?
            .roundTripMilliseconds
    }
    var coordinatorOffsetMilliseconds: Double {
        guard !samples.isEmpty else { return 0 }
        let best = samples.sorted {
            $0.roundTripMilliseconds < $1.roundTripMilliseconds
        }.prefix(5)
        let offsets = best.map(\.coordinatorOffsetMilliseconds).sorted()
        return offsets[offsets.count / 2]
    }

    mutating func register(
        requesterSendMilliseconds t1: Int,
        coordinatorReceiveMilliseconds t2: Int,
        coordinatorSendMilliseconds t3: Int,
        requesterReceiveMilliseconds t4: Int
    ) {
        guard t1 >= 0, t2 >= 0, t3 >= t2, t4 >= t1 else { return }
        let roundTrip = (t4 - t1) - (t3 - t2)
        guard roundTrip >= 0 else { return }
        let offset = (Double(t2 - t1) + Double(t3 - t4)) / 2
        samples.append(
            MultiplayerClockSample(
                roundTripMilliseconds: roundTrip,
                coordinatorOffsetMilliseconds: offset
            )
        )
        samples.sort { $0.roundTripMilliseconds < $1.roundTripMilliseconds }
        if samples.count > 12 {
            samples.removeLast(samples.count - 12)
        }
    }

    func coordinatorMilliseconds(forLocalMilliseconds milliseconds: Int) -> Int {
        Int((Double(milliseconds) + coordinatorOffsetMilliseconds).rounded())
    }

    func localMilliseconds(forCoordinatorMilliseconds milliseconds: Int) -> Int {
        Int((Double(milliseconds) - coordinatorOffsetMilliseconds).rounded())
    }
}

enum MultiplayerGameKitTransportState: Equatable {
    case idle
    case matching
    case waitingForPlayers(connected: Int, required: Int)
    case connected
    case recovering(disconnectedGamePlayerIDs: Set<String>)
    case failed(String)
}

enum MultiplayerGameKitTransportEvent: Equatable {
    case rosterReady(MultiplayerGameKitRoster)
    case helloRosterChanged([String: MultiplayerHelloPacket])
    case packet(MultiplayerReceivedPacket)
    case playerDisconnected(String)
    case playerReconnected(String)
    case failed(String)
}

enum MultiplayerGameKitError: LocalizedError, Equatable {
    case notAuthenticated
    case invalidMatchmakingConfiguration
    case matchUnavailable
    case playerUnavailable
    case invalidRoster
    case invalidPacket
    case packetTooLarge
    case notConnected
    case incompatibleLiveWire
    case evidenceJournalFull
    case coordinatorRequired
    case clockNotSynchronized

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "Game Center must be connected before multiplayer."
        case .invalidMatchmakingConfiguration:
            "The multiplayer matchmaking configuration is invalid."
        case .matchUnavailable:
            "The Game Center match is unavailable."
        case .playerUnavailable:
            "A Game Center participant is no longer connected."
        case .invalidRoster:
            "The Game Center roster is invalid."
        case .invalidPacket:
            "The multiplayer packet is invalid."
        case .packetTooLarge:
            "The multiplayer packet is too large."
        case .notConnected:
            "The multiplayer transport is not connected."
        case .incompatibleLiveWire:
            "Update Required"
        case .evidenceJournalFull:
            "Multiplayer input recovery exceeded its safe bound."
        case .coordinatorRequired:
            "Only the elected multiplayer coordinator can send this packet."
        case .clockNotSynchronized:
            "The multiplayer clock is not synchronized yet."
        }
    }
}

@MainActor
protocol MultiplayerGameKitTransporting: AnyObject {
    var state: MultiplayerGameKitTransportState { get }
    var roster: MultiplayerGameKitRoster? { get }
    var clockEstimator: MultiplayerClockEstimator { get }
    var isCoordinator: Bool { get }
    var liveCompatibility: MultiplayerLiveCompatibility { get }
    var eventHandler: ((MultiplayerGameKitTransportEvent) -> Void)? { get set }

    func connect(matchID: String, playerGroup: Int, participantCount: Int) async throws
    func disconnect()
    func sendHello(participantID: String, seat: Int, colorIndex: Int) throws
    func sendRosterConfirmed(confirmedCount: Int, participantCount: Int) throws
    func sendClockPing(localMonotonicMilliseconds: Int) throws
    func sendStartManifest(
        _ manifest: MultiplayerStartManifest,
        coordinatorStartMonotonicMilliseconds: Int,
        presentationLeadMilliseconds: Int
    ) throws
    func sendInput(_ input: MultiplayerInputPacket, logicalMatchMilliseconds: Int) throws
    func sendInputSeal(
        _ seal: MultiplayerInputSeal,
        logicalMatchMilliseconds: Int,
        includesReliableCheckpoint: Bool
    ) throws
    func sendInputResolution(
        _ resolution: MultiplayerInputResolution,
        logicalMatchMilliseconds: Int
    ) throws
    func sendActivationPlans(
        _ plans: [MultiplayerWireActivationPlan],
        logicalMatchMilliseconds: Int
    ) throws
    func cancelActivationPlans(
        _ planIDs: [Int],
        logicalMatchMilliseconds: Int
    ) throws
    func broadcastEvents(_ events: [[Int]], logicalMatchMilliseconds: Int) throws
    func sendSnapshot(
        events: [[Int]],
        pendingPlans: [MultiplayerWireActivationPlan],
        afterEventSequence: Int,
        logicalMatchMilliseconds: Int,
        to gamePlayerID: String
    ) throws
    func requestSnapshot(afterEventSequence: Int, logicalMatchMilliseconds: Int) throws
    func sendPause(pauseID: Int, logicalMatchMilliseconds: Int) throws
    func sendResume(pauseID: Int, logicalMatchMilliseconds: Int) throws
    func sendFinish(
        finalEventSequence: Int,
        manifestHash: String,
        transcriptDigest: String,
        logicalMatchMilliseconds: Int
    ) throws
    func coordinatorLogicalMilliseconds(
        forLocalMonotonicMilliseconds milliseconds: Int
    ) throws -> Int
    func localMonotonicMilliseconds(
        forCoordinatorLogicalMilliseconds logicalMilliseconds: Int
    ) throws -> Int
}

@MainActor
final class MultiplayerGameKitTransport: ObservableObject, MultiplayerGameKitTransporting {
    static let defaultPresentationLeadMilliseconds = 180
    static let maximumPacketBytes = 64 * 1_024
    static let snapshotChunkEventCount = 100

    @Published private(set) var state: MultiplayerGameKitTransportState = .idle
    @Published private(set) var roster: MultiplayerGameKitRoster?
    @Published private(set) var clockEstimator = MultiplayerClockEstimator()
    @Published private(set) var helloRoster: [String: MultiplayerHelloPacket] = [:]
    @Published private(set) var highestAppliedEventSequence = 0
    @Published private(set) var coordinatorMatchStartMonotonicMilliseconds: Int?

    var eventHandler: ((MultiplayerGameKitTransportEvent) -> Void)?

    var isCoordinator: Bool {
        roster?.coordinatorGamePlayerID == client.localGamePlayerID
    }

    var liveCompatibility: MultiplayerLiveCompatibility {
        guard let roster,
            helloRoster.count == requiredParticipantCount,
            Set(helloRoster.keys) == Set(roster.gamePlayerIDs)
        else { return .collecting }
        return helloRoster.values.allSatisfy(MultiplayerLiveWire.isCompatible)
            ? .unanimous
            : .incompatible
    }

    var unacknowledgedPacketSequences: Set<Int> {
        Set(
            pendingAcknowledgements
                .filter { !$0.value.isEmpty }
                .map(\.key.sequence)
        )
    }

    var unacknowledgedEvidenceInputIDs: Set<MultiplayerInputID> {
        Set(evidenceJournal.keys)
    }

    private let client: any MultiplayerGameKitClientProtocol
    private let monotonicMilliseconds: () -> Int
    private let maximumEvidenceJournalEntries: Int
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()
    private var matchID: String?
    private var requiredParticipantCount = 0
    private var nextPacketSequenceByLane = Dictionary(
        uniqueKeysWithValues: MultiplayerTransportLane.allCases.map { ($0, 1) }
    )
    private var nextClockNonce = 1
    private var lastReliableSequenceByPlayerLane: [String: [MultiplayerTransportLane: Int]] = [:]
    private var seenFastSequencesByPlayer: [String: Set<Int>] = [:]
    private var pendingAcknowledgements: [MultiplayerLaneSequence: Set<String>] = [:]
    private var evidenceJournal: [MultiplayerInputID: MultiplayerInputPacket] = [:]
    private var evidenceInputIDByLaneSequence: [MultiplayerLaneSequence: MultiplayerInputID] =
        [:]
    private var disconnectedPlayerIDs: Set<String> = []
    private var startSignal: MultiplayerStartSignalPacket?
    private var activePause:
        (
            id: Int,
            coordinatorBeganMonotonicMilliseconds: Int,
            logicalMilliseconds: Int
        )?

    init(
        client: any MultiplayerGameKitClientProtocol = LiveMultiplayerGameKitClient(),
        maximumEvidenceJournalEntries: Int = MultiplayerProtocolConstants.maximumEvents,
        monotonicMilliseconds: @escaping () -> Int = MultiplayerGameKitTransport
            .monotonicMilliseconds
    ) {
        self.client = client
        self.maximumEvidenceJournalEntries = max(1, maximumEvidenceJournalEntries)
        self.monotonicMilliseconds = monotonicMilliseconds
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        client.eventHandler = { [weak self] event in
            self?.handleClientEvent(event)
        }
    }

    func connect(matchID: String, playerGroup: Int, participantCount: Int) async throws {
        guard UUID(uuidString: matchID) != nil else {
            throw MultiplayerGameKitError.invalidMatchmakingConfiguration
        }
        let configuration = try MultiplayerMatchmakingConfiguration(
            playerGroup: playerGroup,
            participantCount: participantCount
        )
        resetSession(keepingClient: true)
        self.matchID = matchID.lowercased()
        requiredParticipantCount = participantCount
        state = .matching
        do {
            try await client.findMatch(configuration: configuration)
            refreshRoster()
        } catch {
            let message = error.localizedDescription
            state = .failed(message)
            eventHandler?(.failed(message))
            throw error
        }
    }

    func disconnect() {
        client.cancel()
        resetSession(keepingClient: true)
    }

    func sendHello(participantID: String, seat: Int, colorIndex: Int) throws {
        guard UUID(uuidString: participantID) != nil,
            (0..<MultiplayerAPIContract.maximumPlayers).contains(seat),
            (0..<MultiplayerAPIContract.maximumPlayers).contains(colorIndex),
            !client.localGamePlayerID.isEmpty
        else {
            throw MultiplayerGameKitError.invalidPacket
        }
        let hello = MultiplayerHelloPacket(
            participantId: participantID.lowercased(),
            seat: seat,
            colorIndex: colorIndex,
            gamePlayerId: client.localGamePlayerID,
            liveWireVersion: MultiplayerLiveWire.version,
            capabilities: MultiplayerLiveWire.requiredCapabilities.sorted()
        )
        helloRoster[client.localGamePlayerID] = hello
        try send(
            payload: .hello(hello),
            eventSequence: highestAppliedEventSequence,
            logicalMatchMilliseconds: 0
        )
        publishHelloRoster()
    }

    func sendRosterConfirmed(
        confirmedCount: Int,
        participantCount: Int
    ) throws {
        guard confirmedCount > 0,
            confirmedCount <= participantCount,
            participantCount == requiredParticipantCount
        else {
            throw MultiplayerGameKitError.invalidPacket
        }
        try send(
            payload: .rosterConfirmed(
                MultiplayerRosterConfirmedPacket(
                    confirmedCount: confirmedCount,
                    participantCount: participantCount
                )
            ),
            eventSequence: highestAppliedEventSequence,
            logicalMatchMilliseconds: 0
        )
    }

    func sendClockPing(localMonotonicMilliseconds: Int) throws {
        guard let roster, !isCoordinator else { return }
        let ping = MultiplayerClockPingPacket(
            nonce: nextClockNonce,
            requesterSendMonotonicMilliseconds: localMonotonicMilliseconds
        )
        nextClockNonce += 1
        try send(
            payload: .clockPing(ping),
            eventSequence: highestAppliedEventSequence,
            logicalMatchMilliseconds: 0,
            to: [roster.coordinatorGamePlayerID],
            expectsAcknowledgement: false
        )
    }

    func sendStartManifest(
        _ manifest: MultiplayerStartManifest,
        coordinatorStartMonotonicMilliseconds: Int,
        presentationLeadMilliseconds: Int = defaultPresentationLeadMilliseconds
    ) throws {
        guard isCoordinator,
            manifest.matchId.lowercased() == matchID,
            presentationLeadMilliseconds >= Self.defaultPresentationLeadMilliseconds,
            coordinatorStartMonotonicMilliseconds
                >= monotonicMilliseconds() + presentationLeadMilliseconds
        else {
            throw MultiplayerGameKitError.coordinatorRequired
        }
        let signal = MultiplayerStartSignalPacket(
            manifest: manifest,
            coordinatorStartMonotonicMilliseconds: coordinatorStartMonotonicMilliseconds,
            presentationLeadMilliseconds: presentationLeadMilliseconds
        )
        startSignal = signal
        self.coordinatorMatchStartMonotonicMilliseconds =
            coordinatorStartMonotonicMilliseconds
        try send(
            payload: .startManifest(signal),
            eventSequence: 0,
            logicalMatchMilliseconds: 0
        )
    }

    func sendInput(
        _ input: MultiplayerInputPacket,
        logicalMatchMilliseconds: Int
    ) throws {
        guard roster != nil else { throw MultiplayerGameKitError.notConnected }
        guard liveCompatibility == .unanimous else {
            throw MultiplayerGameKitError.incompatibleLiveWire
        }
        if let existing = evidenceJournal[input.id] {
            guard existing == input else {
                throw MultiplayerGameKitError.invalidPacket
            }
        } else {
            guard evidenceJournal.count < maximumEvidenceJournalEntries else {
                throw MultiplayerGameKitError.evidenceJournalFull
            }
            evidenceJournal[input.id] = input
        }
        // Every peer must witness immutable input evidence. Sending only to the
        // coordinator would let one modified coordinator fabricate another
        // participant's accepted taps before all peers submit the transcript.
        try send(
            payload: .input(input),
            eventSequence: highestAppliedEventSequence,
            logicalMatchMilliseconds: logicalMatchMilliseconds,
            expectsAcknowledgement: false,
            lane: .fastInput
        )
        let evidenceSequence = try send(
            payload: .input(input),
            eventSequence: highestAppliedEventSequence,
            logicalMatchMilliseconds: logicalMatchMilliseconds,
            lane: .evidence
        )
        evidenceInputIDByLaneSequence[evidenceSequence] = input.id
    }

    func sendInputSeal(
        _ seal: MultiplayerInputSeal,
        logicalMatchMilliseconds: Int,
        includesReliableCheckpoint: Bool
    ) throws {
        guard liveCompatibility == .unanimous else {
            throw MultiplayerGameKitError.incompatibleLiveWire
        }
        guard (0..<requiredParticipantCount).contains(seal.seat),
            seal.throughInputAt >= 0,
            seal.throughInputAt < logicalMatchMilliseconds,
            seal.highestInputSequence >= 0,
            seal.highestInputSequence <= MultiplayerProtocolConstants.maximumEvents
        else {
            throw MultiplayerGameKitError.invalidPacket
        }
        try send(
            payload: .inputSeal(seal),
            eventSequence: highestAppliedEventSequence,
            logicalMatchMilliseconds: logicalMatchMilliseconds,
            expectsAcknowledgement: false,
            lane: .fastInput
        )
        if includesReliableCheckpoint {
            try send(
                payload: .inputSeal(seal),
                eventSequence: highestAppliedEventSequence,
                logicalMatchMilliseconds: logicalMatchMilliseconds,
                lane: .evidence
            )
        }
    }

    func sendInputResolution(
        _ resolution: MultiplayerInputResolution,
        logicalMatchMilliseconds: Int
    ) throws {
        guard liveCompatibility == .unanimous else {
            throw MultiplayerGameKitError.incompatibleLiveWire
        }
        guard isCoordinator,
            resolution.version == MultiplayerInputResolution.currentVersion,
            (0..<requiredParticipantCount).contains(resolution.inputID.seat),
            resolution.inputID.inputSequence > 0
        else {
            throw MultiplayerGameKitError.coordinatorRequired
        }
        try send(
            payload: .inputResolution(resolution),
            eventSequence: highestAppliedEventSequence,
            logicalMatchMilliseconds: logicalMatchMilliseconds,
            lane: .canonical
        )
    }

    func sendActivationPlans(
        _ plans: [MultiplayerWireActivationPlan],
        logicalMatchMilliseconds: Int
    ) throws {
        guard isCoordinator,
            !plans.isEmpty,
            Set(plans.map(\.planId)).count == plans.count,
            plans.allSatisfy({
                Self.isValidActivationPlan(
                    $0,
                    participantCount: requiredParticipantCount,
                    minimumAt: logicalMatchMilliseconds
                        + Self.defaultPresentationLeadMilliseconds
                )
            })
        else {
            throw MultiplayerGameKitError.coordinatorRequired
        }
        try send(
            payload: .activationPlans(MultiplayerActivationPlansPacket(plans: plans)),
            eventSequence: highestAppliedEventSequence,
            logicalMatchMilliseconds: logicalMatchMilliseconds
        )
    }

    func cancelActivationPlans(
        _ planIDs: [Int],
        logicalMatchMilliseconds: Int
    ) throws {
        guard isCoordinator,
            !planIDs.isEmpty,
            planIDs.allSatisfy({ $0 > 0 }),
            Set(planIDs).count == planIDs.count
        else {
            throw MultiplayerGameKitError.coordinatorRequired
        }
        try send(
            payload: .cancelActivationPlans(
                MultiplayerCancelActivationPlansPacket(planIds: planIDs.sorted())
            ),
            eventSequence: highestAppliedEventSequence,
            logicalMatchMilliseconds: logicalMatchMilliseconds
        )
    }

    func broadcastEvents(
        _ events: [[Int]],
        logicalMatchMilliseconds: Int
    ) throws {
        guard isCoordinator,
            Self.eventsAreContiguous(
                events,
                afterEventSequence: highestAppliedEventSequence
            ),
            let finalSequence = events.last?[safe: 1]
        else {
            throw MultiplayerGameKitError.coordinatorRequired
        }
        try send(
            payload: .events(MultiplayerEventBatchPacket(events: events)),
            eventSequence: finalSequence,
            logicalMatchMilliseconds: logicalMatchMilliseconds
        )
        highestAppliedEventSequence = finalSequence
    }

    func sendAcknowledgement(
        packetSequence: Int,
        lane acknowledgedLane: MultiplayerTransportLane = .control,
        appliedEventSequence: Int,
        to gamePlayerID: String,
        logicalMatchMilliseconds: Int
    ) throws {
        try send(
            payload: .acknowledgement(
                MultiplayerAcknowledgementPacket(
                    acknowledgedPacketSequence: packetSequence,
                    acknowledgedLane: acknowledgedLane,
                    appliedEventSequence: appliedEventSequence
                )
            ),
            eventSequence: appliedEventSequence,
            logicalMatchMilliseconds: logicalMatchMilliseconds,
            to: [gamePlayerID],
            expectsAcknowledgement: false
        )
    }

    func sendSnapshot(
        events: [[Int]],
        pendingPlans: [MultiplayerWireActivationPlan],
        afterEventSequence: Int,
        logicalMatchMilliseconds: Int,
        to gamePlayerID: String
    ) throws {
        guard isCoordinator,
            events.first?[safe: 1] == afterEventSequence + 1 || events.isEmpty,
            let coordinatorMatchStartMonotonicMilliseconds
        else {
            throw MultiplayerGameKitError.coordinatorRequired
        }
        let chunks = events.chunked(into: Self.snapshotChunkEventCount)
        let snapshotChunks = chunks.isEmpty ? [[]] : chunks
        for (index, chunk) in snapshotChunks.enumerated() {
            try send(
                payload: .snapshot(
                    MultiplayerSnapshotPacket(
                        afterEventSequence: afterEventSequence,
                        throughEventSequence: events.last?[safe: 1] ?? afterEventSequence,
                        chunkIndex: index,
                        chunkCount: snapshotChunks.count,
                        events: chunk,
                        pendingPlans: pendingPlans.sorted { $0.planId < $1.planId },
                        coordinatorMatchStartMonotonicMilliseconds:
                            coordinatorMatchStartMonotonicMilliseconds,
                        pauseId: activePause?.id,
                        pausedAtLogicalMilliseconds: activePause?.logicalMilliseconds
                    )
                ),
                eventSequence: events.last?[safe: 1] ?? afterEventSequence,
                logicalMatchMilliseconds: logicalMatchMilliseconds,
                to: [gamePlayerID]
            )
        }
    }

    func requestSnapshot(
        afterEventSequence: Int,
        logicalMatchMilliseconds: Int
    ) throws {
        guard let roster, !isCoordinator else { return }
        try send(
            payload: .snapshotRequest(
                MultiplayerSnapshotRequestPacket(afterEventSequence: afterEventSequence)
            ),
            eventSequence: highestAppliedEventSequence,
            logicalMatchMilliseconds: logicalMatchMilliseconds,
            to: [roster.coordinatorGamePlayerID]
        )
    }

    func sendPause(pauseID: Int, logicalMatchMilliseconds: Int) throws {
        guard isCoordinator,
            pauseID > 0,
            activePause == nil
        else {
            throw MultiplayerGameKitError.coordinatorRequired
        }
        let packet = MultiplayerPausePacket(
            pauseId: pauseID,
            pausedAtLogicalMilliseconds: logicalMatchMilliseconds
        )
        try send(
            payload: .pause(packet),
            eventSequence: highestAppliedEventSequence,
            logicalMatchMilliseconds: logicalMatchMilliseconds
        )
        activePause = (
            id: pauseID,
            coordinatorBeganMonotonicMilliseconds: monotonicMilliseconds(),
            logicalMilliseconds: logicalMatchMilliseconds
        )
    }

    func sendResume(pauseID: Int, logicalMatchMilliseconds: Int) throws {
        guard isCoordinator,
            let pause = activePause,
            pause.id == pauseID,
            let start = coordinatorMatchStartMonotonicMilliseconds
        else {
            throw MultiplayerGameKitError.coordinatorRequired
        }
        let resumedAt = monotonicMilliseconds()
        let adjustedStart =
            start + max(0, resumedAt - pause.coordinatorBeganMonotonicMilliseconds)
        coordinatorMatchStartMonotonicMilliseconds = adjustedStart
        let packet = MultiplayerResumePacket(
            pauseId: pauseID,
            coordinatorMatchStartMonotonicMilliseconds: adjustedStart
        )
        try send(
            payload: .resume(packet),
            eventSequence: highestAppliedEventSequence,
            logicalMatchMilliseconds: logicalMatchMilliseconds
        )
        activePause = nil
    }

    func sendFinish(
        finalEventSequence: Int,
        manifestHash: String,
        transcriptDigest: String,
        logicalMatchMilliseconds: Int
    ) throws {
        guard isCoordinator,
            finalEventSequence == highestAppliedEventSequence,
            !manifestHash.isEmpty,
            !transcriptDigest.isEmpty
        else {
            throw MultiplayerGameKitError.coordinatorRequired
        }
        try send(
            payload: .finish(
                MultiplayerFinishPacket(
                    finalEventSequence: finalEventSequence,
                    manifestHash: manifestHash,
                    transcriptDigest: transcriptDigest
                )
            ),
            eventSequence: finalEventSequence,
            logicalMatchMilliseconds: logicalMatchMilliseconds
        )
    }

    func coordinatorLogicalMilliseconds(
        forLocalMonotonicMilliseconds milliseconds: Int
    ) throws -> Int {
        guard let start = coordinatorMatchStartMonotonicMilliseconds else {
            throw MultiplayerGameKitError.clockNotSynchronized
        }
        if !isCoordinator, !clockEstimator.hasEstimate {
            throw MultiplayerGameKitError.clockNotSynchronized
        }
        return max(
            0,
            clockEstimator.coordinatorMilliseconds(forLocalMilliseconds: milliseconds) - start
        )
    }

    func localMonotonicMilliseconds(
        forCoordinatorLogicalMilliseconds logicalMilliseconds: Int
    ) throws -> Int {
        guard let start = coordinatorMatchStartMonotonicMilliseconds else {
            throw MultiplayerGameKitError.clockNotSynchronized
        }
        return clockEstimator.localMilliseconds(
            forCoordinatorMilliseconds: start + logicalMilliseconds
        )
    }

    nonisolated static func monotonicMilliseconds() -> Int {
        Int((ProcessInfo.processInfo.systemUptime * 1_000).rounded())
    }

    private func handleClientEvent(_ event: MultiplayerGameKitClientEvent) {
        switch event {
        case .rosterChanged:
            refreshRoster()
        case .received(let data, let sender):
            receive(data, from: sender)
        case .connectionChanged(let playerID, let status):
            handleConnectionChange(playerID: playerID, status: status)
        case .failed(let message):
            state = .failed(message)
            eventHandler?(.failed(message))
        }
    }

    private func refreshRoster() {
        guard requiredParticipantCount > 0 else { return }
        let connected = client.remotePlayers.count + 1
        guard client.expectedPlayerCount == 0, connected == requiredParticipantCount else {
            state = .waitingForPlayers(
                connected: connected,
                required: requiredParticipantCount
            )
            return
        }
        do {
            let roster = try MultiplayerGameKitRoster(
                localGamePlayerID: client.localGamePlayerID,
                observedGamePlayerIDs: client.remotePlayers.map(\.gamePlayerID)
            )
            self.roster = roster
            disconnectedPlayerIDs.subtract(Set(roster.gamePlayerIDs))
            state =
                disconnectedPlayerIDs.isEmpty
                ? .connected
                : .recovering(disconnectedGamePlayerIDs: disconnectedPlayerIDs)
            eventHandler?(.rosterReady(roster))
        } catch {
            let message = error.localizedDescription
            state = .failed(message)
            eventHandler?(.failed(message))
        }
    }

    private func handleConnectionChange(
        playerID: String,
        status: MultiplayerGameKitConnectionStatus
    ) {
        switch status {
        case .disconnected:
            disconnectedPlayerIDs.insert(playerID)
            state = .recovering(disconnectedGamePlayerIDs: disconnectedPlayerIDs)
            eventHandler?(.playerDisconnected(playerID))
        case .connected:
            disconnectedPlayerIDs.remove(playerID)
            refreshRoster()
            try? resendUnacknowledgedEvidence(to: playerID)
            eventHandler?(.playerReconnected(playerID))
            if roster?.coordinatorGamePlayerID == playerID, !isCoordinator {
                try? requestSnapshot(
                    afterEventSequence: highestAppliedEventSequence,
                    logicalMatchMilliseconds: currentLogicalMillisecondsOrZero()
                )
            }
        case .unknown:
            break
        }
    }

    private func receive(_ data: Data, from senderGamePlayerID: String) {
        guard roster?.observedGamePlayerIDs.contains(senderGamePlayerID) == true,
            let envelope = try? decoder.decode(MultiplayerPacketEnvelope.self, from: data),
            isValidIncoming(envelope, senderGamePlayerID: senderGamePlayerID)
        else {
            return
        }
        guard acceptIncomingSequence(envelope, from: senderGamePlayerID) else {
            return
        }

        switch envelope.payload {
        case .hello(let hello):
            helloRoster[senderGamePlayerID] = hello
            publishHelloRoster()
        case .clockPing(let ping):
            receiveClockPing(ping, from: senderGamePlayerID)
        case .clockPong(let pong):
            receiveClockPong(pong, from: senderGamePlayerID)
        case .startManifest(let signal):
            startSignal = signal
            coordinatorMatchStartMonotonicMilliseconds =
                signal.coordinatorStartMonotonicMilliseconds
        case .events(let batch):
            if Self.eventsAreContiguous(
                batch.events,
                afterEventSequence: highestAppliedEventSequence
            ) {
                highestAppliedEventSequence =
                    batch.events.last?[safe: 1] ?? highestAppliedEventSequence
            } else if !isCoordinator {
                try? requestSnapshot(
                    afterEventSequence: highestAppliedEventSequence,
                    logicalMatchMilliseconds: currentLogicalMillisecondsOrZero()
                )
                return
            }
        case .snapshot(let snapshot):
            if snapshot.events.first?[safe: 1] == highestAppliedEventSequence + 1 {
                highestAppliedEventSequence =
                    snapshot.events.last?[safe: 1] ?? highestAppliedEventSequence
            }
            coordinatorMatchStartMonotonicMilliseconds =
                snapshot.coordinatorMatchStartMonotonicMilliseconds
            if let pauseID = snapshot.pauseId,
                let pausedAt = snapshot.pausedAtLogicalMilliseconds
            {
                activePause = (
                    id: pauseID,
                    coordinatorBeganMonotonicMilliseconds: monotonicMilliseconds(),
                    logicalMilliseconds: pausedAt
                )
            } else {
                activePause = nil
            }
        case .acknowledgement(let acknowledgement):
            acknowledge(
                through: acknowledgement.acknowledgedPacketSequence,
                lane: acknowledgement.acknowledgedLane,
                from: senderGamePlayerID
            )
        case .finish(let finish):
            if finish.finalEventSequence >= highestAppliedEventSequence {
                highestAppliedEventSequence = finish.finalEventSequence
            }
        case .pause(let pause):
            activePause = (
                id: pause.pauseId,
                coordinatorBeganMonotonicMilliseconds: monotonicMilliseconds(),
                logicalMilliseconds: pause.pausedAtLogicalMilliseconds
            )
        case .resume(let resume):
            coordinatorMatchStartMonotonicMilliseconds =
                resume.coordinatorMatchStartMonotonicMilliseconds
            activePause = nil
        case .rosterConfirmed, .input, .inputSeal, .inputResolution,
            .activationPlans, .cancelActivationPlans, .snapshotRequest:
            break
        }

        if envelope.payload.expectsAcknowledgement,
            envelope.lane.sendMode == .reliable
        {
            try? sendAcknowledgement(
                packetSequence: envelope.packetSequence,
                lane: envelope.lane,
                appliedEventSequence: highestAppliedEventSequence,
                to: senderGamePlayerID,
                logicalMatchMilliseconds: currentLogicalMillisecondsOrZero()
            )
        }
        eventHandler?(
            .packet(
                MultiplayerReceivedPacket(
                    senderGamePlayerID: senderGamePlayerID,
                    envelope: envelope
                )
            )
        )
    }

    private func receiveClockPing(
        _ ping: MultiplayerClockPingPacket,
        from senderGamePlayerID: String
    ) {
        guard isCoordinator else { return }
        let receive = monotonicMilliseconds()
        let send = monotonicMilliseconds()
        _ = try? self.send(
            payload: .clockPong(
                MultiplayerClockPongPacket(
                    nonce: ping.nonce,
                    requesterSendMonotonicMilliseconds:
                        ping.requesterSendMonotonicMilliseconds,
                    coordinatorReceiveMonotonicMilliseconds: receive,
                    coordinatorSendMonotonicMilliseconds: send
                )
            ),
            eventSequence: highestAppliedEventSequence,
            logicalMatchMilliseconds: currentLogicalMillisecondsOrZero(),
            to: [senderGamePlayerID],
            expectsAcknowledgement: false
        )
    }

    private func receiveClockPong(
        _ pong: MultiplayerClockPongPacket,
        from senderGamePlayerID: String
    ) {
        guard roster?.coordinatorGamePlayerID == senderGamePlayerID, !isCoordinator else {
            return
        }
        clockEstimator.register(
            requesterSendMilliseconds: pong.requesterSendMonotonicMilliseconds,
            coordinatorReceiveMilliseconds: pong.coordinatorReceiveMonotonicMilliseconds,
            coordinatorSendMilliseconds: pong.coordinatorSendMonotonicMilliseconds,
            requesterReceiveMilliseconds: monotonicMilliseconds()
        )
    }

    @discardableResult
    private func send(
        payload: MultiplayerPacketPayload,
        eventSequence: Int,
        logicalMatchMilliseconds: Int,
        to gamePlayerIDs: [String]? = nil,
        expectsAcknowledgement: Bool = true,
        lane requestedLane: MultiplayerTransportLane? = nil
    ) throws -> MultiplayerLaneSequence {
        guard state.isConnected, let matchID else {
            throw MultiplayerGameKitError.notConnected
        }
        guard eventSequence >= 0,
            (0...MultiplayerAPIContract.maximumDurationMilliseconds)
                .contains(logicalMatchMilliseconds)
        else {
            throw MultiplayerGameKitError.invalidPacket
        }
        let lane = requestedLane ?? payload.defaultLane
        guard payload.isValid(on: lane) else {
            throw MultiplayerGameKitError.invalidPacket
        }
        let packetSequence = nextPacketSequenceByLane[lane, default: 1]
        nextPacketSequenceByLane[lane] = packetSequence + 1
        let envelope = MultiplayerPacketEnvelope(
            version: MultiplayerPacketEnvelope.version,
            matchId: matchID,
            packetSequence: packetSequence,
            eventSequence: eventSequence,
            logicalMatchMilliseconds: logicalMatchMilliseconds,
            lane: lane,
            payload: payload
        )
        let data = try encoder.encode(envelope)
        guard data.count <= Self.maximumPacketBytes else {
            throw MultiplayerGameKitError.packetTooLarge
        }
        try client.send(data, to: gamePlayerIDs, mode: lane.sendMode)
        if expectsAcknowledgement {
            pendingAcknowledgements[
                MultiplayerLaneSequence(lane: lane, sequence: packetSequence)
            ] =
                Set(gamePlayerIDs ?? roster?.observedGamePlayerIDs ?? [])
        }
        return MultiplayerLaneSequence(lane: lane, sequence: packetSequence)
    }

    private func acknowledge(
        through packetSequence: Int,
        lane: MultiplayerTransportLane,
        from senderGamePlayerID: String
    ) {
        let acknowledgedKeys = pendingAcknowledgements.keys.filter {
            $0.lane == lane && $0.sequence <= packetSequence
        }
        for key in acknowledgedKeys {
            pendingAcknowledgements[key]?.remove(senderGamePlayerID)
        }
        removeFullyAcknowledgedEvidence()
    }

    private func removeFullyAcknowledgedEvidence() {
        let completedKeys = Set(
            pendingAcknowledgements.compactMap { key, players in
                players.isEmpty ? key : nil
            }
        )
        for key in completedKeys {
            pendingAcknowledgements.removeValue(forKey: key)
            evidenceInputIDByLaneSequence.removeValue(forKey: key)
        }
        let retainedInputIDs = Set(evidenceInputIDByLaneSequence.values)
        evidenceJournal = evidenceJournal.filter { retainedInputIDs.contains($0.key) }
    }

    private func resendUnacknowledgedEvidence(to gamePlayerID: String) throws {
        let inputIDs = Set(
            evidenceInputIDByLaneSequence.compactMap { key, inputID in
                pendingAcknowledgements[key]?.contains(gamePlayerID) == true
                    ? inputID
                    : nil
            }
        ).sorted {
            if $0.seat != $1.seat { return $0.seat < $1.seat }
            return $0.inputSequence < $1.inputSequence
        }
        for inputID in inputIDs {
            guard let input = evidenceJournal[inputID] else { continue }
            let oldKeys = evidenceInputIDByLaneSequence.compactMap { key, value in
                value == inputID ? key : nil
            }
            let newKey = try send(
                payload: .input(input),
                eventSequence: highestAppliedEventSequence,
                logicalMatchMilliseconds: currentLogicalMillisecondsOrZero(),
                to: [gamePlayerID],
                lane: .evidence
            )
            evidenceInputIDByLaneSequence[newKey] = inputID
            for key in oldKeys where key != newKey {
                pendingAcknowledgements[key]?.remove(gamePlayerID)
            }
        }
        removeFullyAcknowledgedEvidence()
    }

    private func acceptIncomingSequence(
        _ envelope: MultiplayerPacketEnvelope,
        from senderGamePlayerID: String
    ) -> Bool {
        if envelope.lane == .fastInput {
            var seen = seenFastSequencesByPlayer[senderGamePlayerID] ?? []
            guard seen.insert(envelope.packetSequence).inserted else { return false }
            let oldestRetained = max(1, (seen.max() ?? 1) - 128)
            seen = Set(seen.filter { $0 >= oldestRetained })
            seenFastSequencesByPlayer[senderGamePlayerID] = seen
            return true
        }

        var laneSequences = lastReliableSequenceByPlayerLane[senderGamePlayerID] ?? [:]
        let previous = laneSequences[envelope.lane] ?? 0
        guard envelope.packetSequence > previous else { return false }
        laneSequences[envelope.lane] = envelope.packetSequence
        lastReliableSequenceByPlayerLane[senderGamePlayerID] = laneSequences
        return true
    }

    private func isValidIncoming(
        _ envelope: MultiplayerPacketEnvelope,
        senderGamePlayerID: String
    ) -> Bool {
        guard envelope.version == MultiplayerPacketEnvelope.version,
            envelope.matchId.lowercased() == matchID,
            envelope.packetSequence > 0,
            envelope.eventSequence >= 0,
            envelope.payload.isValid(on: envelope.lane),
            (0...MultiplayerAPIContract.maximumDurationMilliseconds)
                .contains(envelope.logicalMatchMilliseconds)
        else { return false }

        switch envelope.payload {
        case .hello(let hello):
            return hello.gamePlayerId == senderGamePlayerID
                && UUID(uuidString: hello.participantId) != nil
                && (0..<requiredParticipantCount).contains(hello.seat)
                && (0..<requiredParticipantCount).contains(hello.colorIndex)
        case .rosterConfirmed(let confirmed):
            return confirmed.confirmedCount > 0
                && confirmed.confirmedCount <= confirmed.participantCount
                && confirmed.participantCount == requiredParticipantCount
        case .clockPing(let ping):
            return ping.nonce > 0 && ping.requesterSendMonotonicMilliseconds >= 0
        case .clockPong(let pong):
            return pong.nonce > 0
                && pong.requesterSendMonotonicMilliseconds >= 0
                && pong.coordinatorReceiveMonotonicMilliseconds >= 0
                && pong.coordinatorSendMonotonicMilliseconds
                    >= pong.coordinatorReceiveMonotonicMilliseconds
        case .startManifest(let signal):
            return senderGamePlayerID == roster?.coordinatorGamePlayerID
                && signal.manifest.matchId.lowercased() == matchID
                && signal.manifest.buildId == MultiplayerAPIContract.buildID
                && signal.manifest.ruleset == MultiplayerAPIContract.ruleset
                && signal.manifest.protocolVersion == MultiplayerAPIContract.protocolVersion
                && signal.manifest.proofVersion == MultiplayerAPIContract.proofVersion
                && signal.manifest.manifestHash.count == 43
                && signal.presentationLeadMilliseconds
                    >= Self.defaultPresentationLeadMilliseconds
        case .input(let input):
            return input.inputSequence > 0
                && (0..<requiredParticipantCount).contains(input.seat)
                && (0...15).contains(input.cell)
                && input.coordinatorInputMilliseconds >= 0
        case .inputSeal(let seal):
            return (0..<requiredParticipantCount).contains(seal.seat)
                && seal.throughInputAt >= 0
                && seal.throughInputAt < envelope.logicalMatchMilliseconds
                && seal.highestInputSequence >= 0
                && seal.highestInputSequence
                    <= MultiplayerProtocolConstants.maximumEvents
        case .inputResolution(let resolution):
            return senderGamePlayerID == roster?.coordinatorGamePlayerID
                && resolution.version == MultiplayerInputResolution.currentVersion
                && (0..<requiredParticipantCount).contains(resolution.inputID.seat)
                && resolution.inputID.inputSequence > 0
                && {
                    if case .committed(let eventSequence) = resolution.disposition {
                        return eventSequence > 0
                    }
                    return true
                }()
        case .activationPlans(let packet):
            return senderGamePlayerID == roster?.coordinatorGamePlayerID
                && !packet.plans.isEmpty
                && Set(packet.plans.map(\.planId)).count == packet.plans.count
                && packet.plans.allSatisfy({
                    Self.isValidActivationPlan(
                        $0,
                        participantCount: requiredParticipantCount,
                        minimumAt: envelope.logicalMatchMilliseconds
                            + Self.defaultPresentationLeadMilliseconds
                    )
                })
        case .cancelActivationPlans(let packet):
            return senderGamePlayerID == roster?.coordinatorGamePlayerID
                && !packet.planIds.isEmpty
                && packet.planIds.allSatisfy({ $0 > 0 })
                && Set(packet.planIds).count == packet.planIds.count
        case .events(let batch):
            return senderGamePlayerID == roster?.coordinatorGamePlayerID
                && !batch.events.isEmpty
                && batch.events.last?[safe: 1] == envelope.eventSequence
        case .acknowledgement(let acknowledgement):
            return acknowledgement.acknowledgedPacketSequence > 0
                && acknowledgement.acknowledgedLane != .fastInput
                && acknowledgement.acknowledgedPacketSequence
                    < nextPacketSequenceByLane[
                        acknowledgement.acknowledgedLane,
                        default: 1
                    ]
                && acknowledgement.appliedEventSequence >= 0
        case .snapshot(let snapshot):
            return senderGamePlayerID == roster?.coordinatorGamePlayerID
                && snapshot.afterEventSequence >= 0
                && snapshot.throughEventSequence >= snapshot.afterEventSequence
                && snapshot.chunkIndex >= 0
                && snapshot.chunkIndex < snapshot.chunkCount
                && snapshot.chunkCount > 0
                && snapshot.coordinatorMatchStartMonotonicMilliseconds > 0
                && snapshot.pendingPlans.allSatisfy({
                    Self.isValidActivationPlan(
                        $0,
                        participantCount: requiredParticipantCount,
                        minimumAt: 0
                    )
                })
                && ((snapshot.pauseId == nil
                    && snapshot.pausedAtLogicalMilliseconds == nil)
                    || ((snapshot.pauseId ?? 0) > 0
                        && (snapshot.pausedAtLogicalMilliseconds ?? -1) >= 0))
        case .snapshotRequest(let request):
            return request.afterEventSequence >= 0
        case .pause(let pause):
            return senderGamePlayerID == roster?.coordinatorGamePlayerID
                && pause.pauseId > 0
                && pause.pausedAtLogicalMilliseconds
                    == envelope.logicalMatchMilliseconds
        case .resume(let resume):
            return senderGamePlayerID == roster?.coordinatorGamePlayerID
                && resume.pauseId > 0
                && resume.coordinatorMatchStartMonotonicMilliseconds > 0
        case .finish(let finish):
            return senderGamePlayerID == roster?.coordinatorGamePlayerID
                && finish.finalEventSequence == envelope.eventSequence
                && !finish.manifestHash.isEmpty
                && !finish.transcriptDigest.isEmpty
        }
    }

    private func publishHelloRoster() {
        eventHandler?(.helloRosterChanged(helloRoster))
    }

    private func currentLogicalMillisecondsOrZero() -> Int {
        (try? coordinatorLogicalMilliseconds(
            forLocalMonotonicMilliseconds: monotonicMilliseconds()
        )) ?? 0
    }

    private func resetSession(keepingClient: Bool) {
        if !keepingClient { client.cancel() }
        matchID = nil
        requiredParticipantCount = 0
        nextPacketSequenceByLane = Dictionary(
            uniqueKeysWithValues: MultiplayerTransportLane.allCases.map { ($0, 1) }
        )
        nextClockNonce = 1
        lastReliableSequenceByPlayerLane = [:]
        seenFastSequencesByPlayer = [:]
        pendingAcknowledgements = [:]
        evidenceJournal = [:]
        evidenceInputIDByLaneSequence = [:]
        disconnectedPlayerIDs = []
        roster = nil
        helloRoster = [:]
        highestAppliedEventSequence = 0
        clockEstimator = MultiplayerClockEstimator()
        startSignal = nil
        activePause = nil
        coordinatorMatchStartMonotonicMilliseconds = nil
        state = .idle
    }

    private static func eventsAreContiguous(
        _ events: [[Int]],
        afterEventSequence: Int
    ) -> Bool {
        guard !events.isEmpty else { return false }
        return events.enumerated().allSatisfy { index, event in
            event[safe: 1] == afterEventSequence + index + 1
        }
    }

    private static func isValidActivationPlan(
        _ plan: MultiplayerWireActivationPlan,
        participantCount: Int,
        minimumAt: Int
    ) -> Bool {
        guard plan.planId > 0,
            plan.entityId > 0,
            plan.at >= minimumAt,
            plan.at <= MultiplayerAPIContract.maximumDurationMilliseconds,
            (0..<participantCount).contains(plan.ownerSeat),
            (0...15).contains(plan.cell),
            plan.colorIndex >= 0
        else { return false }
        switch plan.kind {
        case .target:
            return plan.lifetimeMs == nil
        case .decoy:
            guard let lifetime = plan.lifetimeMs else { return false }
            return (1_000...3_000).contains(lifetime)
        }
    }
}

extension MultiplayerPacketPayload {
    fileprivate var defaultLane: MultiplayerTransportLane {
        switch self {
        case .input, .inputSeal:
            .evidence
        case .events, .inputResolution:
            .canonical
        default:
            .control
        }
    }

    fileprivate func isValid(on lane: MultiplayerTransportLane) -> Bool {
        switch self {
        case .input, .inputSeal:
            lane == .fastInput || lane == .evidence
        case .events, .inputResolution:
            lane == .canonical
        default:
            lane == .control
        }
    }

    fileprivate var expectsAcknowledgement: Bool {
        switch self {
        case .acknowledgement, .clockPing, .clockPong:
            false
        default:
            true
        }
    }
}

extension MultiplayerGameKitTransportState {
    fileprivate var isConnected: Bool {
        switch self {
        case .connected, .recovering:
            true
        case .idle, .matching, .waitingForPlayers, .failed:
            false
        }
    }
}

extension Collection {
    fileprivate subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Array {
    fileprivate func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
