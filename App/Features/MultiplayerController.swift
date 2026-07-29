import Combine
import CryptoKit
import Foundation
import PimPoPomCore

enum MultiplayerFlowPhase: Equatable {
    case hub
    case waiting
    case live
    case results
}

@MainActor
final class MultiplayerController: ObservableObject {
    static let gameCenterProofMaximumAge: TimeInterval = 10 * 60
    static let lobbyPollInterval: Duration = .milliseconds(1_250)
    static let liveTickInterval: Duration = .milliseconds(33)
    static let recoveryGrace: Duration = .seconds(15)

    @Published private(set) var phase: MultiplayerFlowPhase = .hub
    @Published private(set) var hubState = MultiplayerPresentation.HubState(
        availability: .signInRequired
    )
    @Published private(set) var waitingState: MultiplayerPresentation.WaitingRoomState?
    @Published private(set) var liveState: MultiplayerPresentation.LiveMatchState?
    @Published private(set) var resultsState = MultiplayerPresentation.ResultsState(
        settlement: .collecting(submitted: 0, total: 2),
        results: [],
        isRefreshing: false,
        localSubmissionAccepted: false,
        message: nil
    )
    var availability: MultiplayerPresentation.Availability {
        Self.resolveAvailability(backend: backend, gameCenter: gameCenter)
    }

    private struct QueuedInput: Equatable {
        let inputSequence: Int
        let seat: Int
        let cell: Int
        let inputAt: Int
        let receivedAt: Int
    }

    private struct PendingSubmission {
        let matchID: String
        let manifestHash: String
        let transcript: MultiplayerTranscriptSubmission
    }

    private let backend: BackendClient
    private let gameCenter: GameCenterService
    private let audio: AudioController
    private let transport: any MultiplayerGameKitTransporting

    private var currentMatch: MultiplayerMatch?
    private var pollTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var settlementTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private var announcementTask: Task<Void, Never>?
    private var matchmakingTask: Task<Void, Never>?
    private var matchmakingAttemptGate = MultiplayerMatchmakingAttemptGate()
    private var isApplicationActive = true
    private var isConfirmingRoster = false
    private var hasConfirmedRoster = false
    private var greatestRosterConfirmationCount = 0
    private var rosterConfirmationCounts: [String: Int] = [:]
    private var helloRoster: [String: MultiplayerHelloPacket] = [:]
    private var confirmedHelloRoster: [String: MultiplayerHelloPacket]?
    private var disconnectedGamePlayerIDs: Set<String> = []
    private var pauseID = 0
    private var pausedAtLogicalMilliseconds: Int?
    private var didBeginLiveMatch = false
    private var didBroadcastStart = false
    private var didSubmitTranscript = false
    private var didBroadcastFinish = false
    private var localInputSequence = 0
    private var lastInputSequenceBySeat: [Int: Int] = [:]
    private var queuedInputs: [QueuedInput] = []
    private var inputEvidenceCounts: [MultiplayerInputEvidenceKey: Int] = [:]
    private var pendingCanonicalBatches: [Int: [MultiplayerEvent]] = [:]
    private var peerConsistencyIntact = true
    private var pendingPlans: [Int: MultiplayerWireActivationPlan] = [:]
    private var sentPlanIDs: Set<Int> = []
    private var coordinatorEngine: MultiplayerCoordinatorEngine?
    private var playbackReducer: MultiplayerStateReducer?
    private var coreManifest: PimPoPomCore.MultiplayerManifest?
    private var transcriptEvents: [MultiplayerEvent] = []
    private var currentAnnouncement: String?
    private var pendingSubmission: PendingSubmission?
    private var isSubmittingTranscript = false

    private func debugMultiplayerLog(_ message: String) {
        #if DEBUG
            print("[PimPoPom Multiplayer] \(message)")
        #endif
    }

    init(
        backend: BackendClient,
        gameCenter: GameCenterService,
        audio: AudioController,
        transport: (any MultiplayerGameKitTransporting)? = nil
    ) {
        self.backend = backend
        self.gameCenter = gameCenter
        self.audio = audio
        self.transport = transport ?? MultiplayerGameKitTransport()
        self.transport.eventHandler = { [weak self] event in
            self?.handleTransportEvent(event)
        }
        refreshAvailability()
    }

    deinit {
        pollTask?.cancel()
        tickTask?.cancel()
        settlementTask?.cancel()
        recoveryTask?.cancel()
        announcementTask?.cancel()
        matchmakingTask?.cancel()
    }

    func open() {
        phase = .hub
        audio.setMusicContext(.menu)
        refreshAvailability()
        refreshLobbies()
    }

    func refreshAvailability() {
        hubState.availability = availability
        if !availability.isAvailable {
            hubState.lobbies = []
            hubState.message = availability.menuMessage.capitalized
        }
    }

    func setApplicationActive(_ isActive: Bool) {
        isApplicationActive = isActive
        if isActive, phase == .results, pendingSubmission != nil {
            submitPendingTranscript()
        }
        guard phase == .live else { return }
        if isActive {
            if transport.isCoordinator, disconnectedGamePlayerIDs.isEmpty {
                resumeCoordinatedPause()
            }
            if !transport.isCoordinator {
                try? transport.requestSnapshot(
                    afterEventSequence: transcriptEvents.count,
                    logicalMatchMilliseconds: currentLogicalMilliseconds()
                )
            }
            updateRecoveryPresentation()
        } else {
            if transport.isCoordinator {
                beginCoordinatedPause()
            }
            markRecovering()
        }
    }

    func refreshLobbies() {
        refreshAvailability()
        guard availability.isAvailable, !hubState.isRefreshing else { return }
        hubState.isRefreshing = true
        hubState.message = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { hubState.isRefreshing = false }
            do {
                let response = try await backend.loadMultiplayerLobbies(limit: 20)
                guard phase == .hub else { return }
                hubState.lobbies = response.lobbies.map(Self.presentedLobby)
                if response.lobbies.isEmpty {
                    hubState.message = "No open games yet"
                }
            } catch {
                hubState.message = error.localizedDescription
            }
        }
    }

    func createMatch(capacity: Int) {
        guard availability.isAvailable, !hubState.isCreating else { return }
        hubState.isCreating = true
        hubState.message = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { hubState.isCreating = false }
            do {
                try await ensureFreshGameCenterProof()
                let match = try await backend.createMultiplayerMatch(capacity: capacity)
                enterWaitingRoom(match)
            } catch {
                hubState.message = error.localizedDescription
            }
        }
    }

    func joinMatch(_ matchID: String) {
        guard availability.isAvailable, hubState.joiningLobbyID == nil else { return }
        hubState.joiningLobbyID = matchID
        hubState.message = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { hubState.joiningLobbyID = nil }
            do {
                try await ensureFreshGameCenterProof()
                let match = try await backend.joinMultiplayerMatch(matchID)
                enterWaitingRoom(match)
            } catch {
                hubState.message = error.localizedDescription
            }
        }
    }

    func toggleReady(_ ready: Bool) {
        guard let match = currentMatch, waitingState?.isMutationPending == false else {
            return
        }
        waitingState?.isMutationPending = true
        waitingState?.message = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { waitingState?.isMutationPending = false }
            do {
                let updated = try await backend.setMultiplayerReadiness(
                    match.matchId,
                    ready: ready
                )
                applyMatch(updated)
            } catch {
                waitingState?.message = error.localizedDescription
            }
        }
    }

    func startMatch() {
        guard let match = currentMatch,
            waitingState?.canStart == true,
            waitingState?.isMutationPending == false
        else { return }
        waitingState?.isMutationPending = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { waitingState?.isMutationPending = false }
            do {
                try await ensureFreshGameCenterProof()
                let response = try await backend.startMultiplayerMatch(match.matchId)
                try handleAvailableManifest(response.manifest)
            } catch {
                waitingState?.connection = .failed(error.localizedDescription)
            }
        }
    }

    func retryGameKitConnection() {
        guard phase == .waiting else { return }
        transport.disconnect()
        matchmakingAttemptGate.clear()
        waitingState?.connection = .matching
        waitingState?.message = nil
        beginMatchmakingIfFull()
    }

    func leaveMatch() {
        let matchID = currentMatch?.matchId
        resetMatchRuntime(disconnect: true)
        phase = .hub
        audio.setMusicContext(.menu)
        if let matchID {
            Task { @MainActor [weak self] in
                _ = try? await self?.backend.leaveMultiplayerMatch(matchID)
                self?.refreshLobbies()
            }
        } else {
            refreshLobbies()
        }
    }

    func returnToMenuFromResults() {
        guard phase == .results, resultsState.canReturnToMenu else { return }
        // A post-start PHP leave cancels the whole match. Once our immutable
        // transcript is accepted (or this client has already held the match),
        // returning to the menu is local-only.
        resetMatchRuntime(disconnect: true)
        phase = .hub
        audio.setMusicContext(.menu)
        refreshLobbies()
    }

    func handleTap(cell: Int, localMonotonicMilliseconds: Int) {
        guard phase == .live,
            isApplicationActive,
            disconnectedGamePlayerIDs.isEmpty,
            let match = currentMatch,
            let local = match.participants.first(where: \.isCurrentPlayer),
            let localPlayer = playbackReducer?.state.players.first(where: {
                $0.seat == local.seat
            }),
            localPlayer.lives > 0,
            pausedAtLogicalMilliseconds == nil,
            liveState?.cells.contains(where: \.isTarget) == true,
            (0..<MultiplayerProtocolConstants.boardCellCount).contains(cell),
            let inputAt = try? transport.coordinatorLogicalMilliseconds(
                forLocalMonotonicMilliseconds: localMonotonicMilliseconds
            ),
            localPlayer.recoveryUntil.map({ inputAt >= $0 }) ?? true,
            inputAt > 0
        else { return }

        localInputSequence += 1
        let packet = MultiplayerInputPacket(
            inputSequence: localInputSequence,
            seat: local.seat,
            cell: cell,
            coordinatorInputMilliseconds: inputAt
        )
        do {
            try transport.sendInput(packet, logicalMatchMilliseconds: inputAt)
        } catch {
            markRecovering(message: error.localizedDescription)
            return
        }
        if transport.isCoordinator {
            enqueueInput(
                packet,
                receivedAt: currentLogicalMilliseconds(),
                expectedSeat: local.seat,
                recordEvidence: true
            )
        } else {
            recordInputEvidence(packet, expectedSeat: local.seat)
        }
    }

    func refreshSettlement() {
        guard let matchID = currentMatch?.matchId else { return }
        if pendingSubmission != nil {
            submitPendingTranscript()
            return
        }
        resultsState = MultiplayerPresentation.ResultsState(
            settlement: resultsState.settlement,
            results: resultsState.results,
            isRefreshing: true,
            localSubmissionAccepted: resultsState.localSubmissionAccepted,
            message: resultsState.message
        )
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                resultsState = MultiplayerPresentation.ResultsState(
                    settlement: resultsState.settlement,
                    results: resultsState.results,
                    isRefreshing: false,
                    localSubmissionAccepted: resultsState.localSubmissionAccepted,
                    message: resultsState.message
                )
            }
            do {
                let response = try await backend.loadMultiplayerSettlement(matchID)
                applySettlement(response)
            } catch {
                resultsState = MultiplayerPresentation.ResultsState(
                    settlement: resultsState.settlement,
                    results: resultsState.results,
                    isRefreshing: false,
                    localSubmissionAccepted: resultsState.localSubmissionAccepted,
                    message: error.localizedDescription
                )
            }
        }
    }

    func recordLocalPetDrag(_: CGSize) {
        // Waiting-room pet movement is intentionally local presentation only.
    }

    private static func resolveAvailability(
        backend: BackendClient,
        gameCenter: GameCenterService
    ) -> MultiplayerPresentation.Availability {
        let localGameCenterConnected: Bool =
            if case .authenticated(let player) = gameCenter.state {
                player.scopedIDsArePersistent
            } else {
                false
            }
        let serverGameCenterReady =
            backend.sessionState?.identityBindings?.gameCenter == true
            && backend.sessionState?.gameCenter?.identityLinked == true
            && backend.sessionState?.gameCenter?.publicationEnabled == true
        return .resolve(
            isSignedIn: backend.isAuthenticated,
            nicknameConfirmed: backend.profile?.nicknameConfirmed == true,
            gameCenterConnected: localGameCenterConnected && serverGameCenterReady
        )
    }

    private func ensureFreshGameCenterProof() async throws {
        guard backend.isAuthenticated,
            let profileID = backend.profile?.id,
            backend.profile?.nicknameConfirmed == true,
            case .authenticated(let player) = gameCenter.state,
            player.scopedIDsArePersistent
        else {
            throw MultiplayerControllerError.prerequisitesUnavailable
        }
        if gameCenter.isCurrentRuntimePlayerVerified(
            for: profileID,
            maximumAge: Self.gameCenterProofMaximumAge
        ) {
            return
        }
        let challenge = try await backend.issueGameCenterLinkChallenge(
            expectedPlayerID: profileID
        )
        let verification = try await gameCenter.fetchIdentityVerification()
        _ = try await backend.linkGameCenter(
            challenge: challenge,
            verification: verification,
            expectedPlayerID: profileID
        )
        try gameCenter.markRuntimeVerification(
            profileID: profileID,
            verification: verification
        )
        refreshAvailability()
    }

    private func enterWaitingRoom(_ match: MultiplayerMatch) {
        resetMatchRuntime(disconnect: true)
        currentMatch = match
        phase = .waiting
        audio.setMusicContext(.menu)
        applyMatch(match)
        startLobbyPolling()
        beginMatchmakingIfFull()
    }

    private func startLobbyPolling() {
        pollTask?.cancel()
        guard let matchID = currentMatch?.matchId else { return }
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.lobbyPollInterval)
                guard let self, !Task.isCancelled,
                    phase == .waiting,
                    currentMatch?.matchId == matchID
                else { return }
                do {
                    let updated = try await backend.loadMultiplayerMatch(matchID)
                    applyMatch(updated)
                    sendCurrentHelloIfNeeded()
                    beginMatchmakingIfFull()
                    if let manifest = updated.manifest {
                        try handleAvailableManifest(manifest)
                    }
                } catch {
                    waitingState?.connection = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func applyMatch(_ match: MultiplayerMatch) {
        currentMatch = match
        let creatorSeat =
            match.isCreator
            ? match.participants.first(where: \.isCurrentPlayer)?.seat
            : match.participants.map(\.seat).min()
        let connectedParticipantIDs = Set(helloRoster.values.map(\.participantId))
        let hasLiveRoster = !helloRoster.isEmpty
        let connection = waitingState?.connection ?? .matching
        waitingState = MultiplayerPresentation.WaitingRoomState(
            matchID: match.matchId,
            capacity: match.capacity,
            isCreator: match.isCreator,
            participants: match.participants.map {
                MultiplayerPresentation.Participant(
                    id: $0.participantId,
                    seat: $0.seat,
                    colorIndex: $0.colorIndex,
                    name: $0.name,
                    petID: $0.petId,
                    ready: $0.ready,
                    isCurrentPlayer: $0.isCurrentPlayer,
                    isCreator: $0.seat == creatorSeat,
                    isConnected: !hasLiveRoster
                        || connectedParticipantIDs.contains($0.participantId)
                )
            },
            connection: connection,
            isMutationPending: waitingState?.isMutationPending ?? false,
            message: waitingState?.message,
            expiresAt: Self.parseDate(match.expiresAt)
        )
        let readyCount = match.participants.filter(\.ready).count
        let connectedCount = waitingState?.participants.filter(\.isConnected).count ?? 0
        debugMultiplayerLog(
            "lobby participants=\(match.participants.count)/\(match.capacity) "
                + "ready=\(readyCount) connected=\(connectedCount) "
                + "rosterState=\(waitingState?.connection.title ?? "none") "
                + "canStart=\(waitingState?.canStart == true)"
        )
    }

    private func beginMatchmakingIfFull() {
        guard phase == .waiting,
            let match = currentMatch,
            match.participants.count == match.capacity,
            matchmakingTask == nil,
            transport.roster == nil,
            matchmakingAttemptGate.allowsAttempt
        else { return }
        debugMultiplayerLog(
            "matchmaking begin participants=\(match.participants.count) "
                + "playerGroup=\(match.playerGroup)"
        )
        waitingState?.connection = .matching
        matchmakingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { matchmakingTask = nil }
            do {
                try await ensureFreshGameCenterProof()
                try await transport.connect(
                    matchID: match.matchId,
                    playerGroup: match.playerGroup,
                    participantCount: match.capacity
                )
            } catch {
                presentMatchmakingFailure(error)
            }
        }
    }

    private func presentMatchmakingFailure(_ error: any Error) {
        let failure =
            error as? MultiplayerGameKitFailure
            ?? MultiplayerGameKitFailure(error: error)
        debugMultiplayerLog(
            "matchmaking failed domain=\(failure.domain) code=\(failure.code) "
                + "message=\(failure.message)"
        )
        matchmakingAttemptGate.block(with: failure)
        waitingState?.connection =
            failure.kind == .iCloudUnavailable
            ? .cloudSyncRequired
            : .connectionFailed(failure.message)
    }

    private func handleTransportEvent(_ event: MultiplayerGameKitTransportEvent) {
        switch event {
        case .rosterReady:
            debugMultiplayerLog(
                "GameKit roster ready players=\(transport.roster?.gamePlayerIDs.count ?? 0) "
                    + "coordinator=\(transport.isCoordinator)"
            )
            sendCurrentHelloIfNeeded(force: true)
            startClockSynchronization()
        case .helloRosterChanged(let roster):
            if let confirmedHelloRoster, roster != confirmedHelloRoster {
                peerConsistencyIntact = false
                failLiveMatch("The confirmed Game Center roster changed.")
                return
            }
            helloRoster = roster
            debugMultiplayerLog(
                "hello roster count=\(roster.count)/\(currentMatch?.capacity ?? 0)"
            )
            updateWaitingParticipantConnectivity()
            confirmRosterIfComplete()
        case .packet(let received):
            handlePacket(received)
        case .playerDisconnected(let playerID):
            disconnectedGamePlayerIDs.insert(playerID)
            updateWaitingParticipantConnectivity()
            if transport.isCoordinator {
                beginCoordinatedPause()
            } else if pausedAtLogicalMilliseconds == nil {
                pausedAtLogicalMilliseconds = currentLogicalMilliseconds()
            }
            markRecovering()
        case .playerReconnected(let playerID):
            disconnectedGamePlayerIDs.remove(playerID)
            updateWaitingParticipantConnectivity()
            if transport.isCoordinator {
                try? transport.sendSnapshot(
                    events: transcriptEvents.map(\.integerTuple),
                    pendingPlans: Array(pendingPlans.values),
                    afterEventSequence: 0,
                    logicalMatchMilliseconds: currentLogicalMilliseconds(),
                    to: playerID
                )
            } else {
                try? transport.requestSnapshot(
                    afterEventSequence: transcriptEvents.count,
                    logicalMatchMilliseconds: currentLogicalMilliseconds()
                )
            }
            if transport.isCoordinator, disconnectedGamePlayerIDs.isEmpty {
                resumeCoordinatedPause()
            }
            updateRecoveryPresentation()
        case .failed(let message):
            if phase == .live {
                markRecovering(message: message)
            } else {
                presentMatchmakingFailure(
                    MultiplayerGameKitFailure(
                        domain: "PimPoPom.Multiplayer.GameKit",
                        code: 0,
                        message: message
                    )
                )
            }
        }
    }

    private func handlePacket(_ received: MultiplayerReceivedPacket) {
        switch received.envelope.payload {
        case .hello, .clockPing, .clockPong, .acknowledgement:
            refreshWaitingConnectionState()
        case .rosterConfirmed(let confirmation):
            rosterConfirmationCounts[received.senderGamePlayerID] =
                confirmation.confirmedCount
            greatestRosterConfirmationCount = max(
                greatestRosterConfirmationCount,
                confirmation.confirmedCount
            )
            refreshWaitingConnectionState()
        case .startManifest(let signal):
            do {
                try beginLiveMatch(manifest: signal.manifest)
            } catch {
                waitingState?.connection = .failed(error.localizedDescription)
            }
        case .input(let input):
            guard let frozenRoster = confirmedHelloRoster,
                let hello = frozenRoster[received.senderGamePlayerID]
            else {
                peerConsistencyIntact = false
                return
            }
            if transport.isCoordinator {
                enqueueInput(
                    input,
                    receivedAt: currentLogicalMilliseconds(),
                    expectedSeat: hello.seat,
                    recordEvidence: true
                )
            } else {
                recordInputEvidence(input, expectedSeat: hello.seat)
                drainPendingCanonicalBatches()
            }
        case .activationPlans(let packet):
            guard !transport.isCoordinator else { return }
            for plan in packet.plans {
                pendingPlans[plan.planId] = plan
            }
            updateLivePresentation(at: currentLogicalMilliseconds())
        case .cancelActivationPlans(let packet):
            for planID in packet.planIds {
                pendingPlans.removeValue(forKey: planID)
            }
            updateLivePresentation(at: currentLogicalMilliseconds())
        case .events(let packet):
            guard !transport.isCoordinator else { return }
            applyCanonicalTuples(packet.events)
        case .snapshot(let snapshot):
            guard !transport.isCoordinator else { return }
            applySnapshot(snapshot)
        case .snapshotRequest(let request):
            guard transport.isCoordinator else { return }
            let remaining =
                transcriptEvents
                .filter { $0.sequence > request.afterEventSequence }
                .map(\.integerTuple)
            try? transport.sendSnapshot(
                events: remaining,
                pendingPlans: Array(pendingPlans.values),
                afterEventSequence: request.afterEventSequence,
                logicalMatchMilliseconds: currentLogicalMilliseconds(),
                to: received.senderGamePlayerID
            )
        case .pause(let pause):
            pausedAtLogicalMilliseconds = pause.pausedAtLogicalMilliseconds
            markRecovering()
        case .resume:
            guard pausedAtLogicalMilliseconds != nil else { return }
            pausedAtLogicalMilliseconds = nil
            currentAnnouncement = nil
            updateRecoveryPresentation()
        case .finish(let finish):
            handleFinishPacket(finish)
        }
    }

    private func startClockSynchronization() {
        guard !transport.isCoordinator else {
            refreshWaitingConnectionState()
            return
        }
        Task { @MainActor [weak self] in
            for _ in 0..<4 {
                guard let self, !Task.isCancelled else { return }
                try? transport.sendClockPing(
                    localMonotonicMilliseconds:
                        MultiplayerGameKitTransport.monotonicMilliseconds()
                )
                try? await Task.sleep(for: .milliseconds(140))
            }
            self?.refreshWaitingConnectionState()
        }
    }

    private func sendCurrentHelloIfNeeded(force: Bool = false) {
        guard phase == .waiting,
            transport.roster != nil,
            let match = currentMatch,
            let local = match.participants.first(where: \.isCurrentPlayer),
            force
                || !hasConfirmedRoster
                || greatestRosterConfirmationCount < match.capacity
        else { return }
        do {
            try transport.sendHello(
                participantID: local.participantId,
                seat: local.seat,
                colorIndex: local.colorIndex
            )
            if !transport.isCoordinator, !transport.clockEstimator.hasEstimate {
                try transport.sendClockPing(
                    localMonotonicMilliseconds:
                        MultiplayerGameKitTransport.monotonicMilliseconds()
                )
            }
        } catch {
            waitingState?.connection = .failed(error.localizedDescription)
        }
    }

    private func confirmRosterIfComplete() {
        guard !isConfirmingRoster,
            !hasConfirmedRoster,
            let match = currentMatch,
            let roster = transport.roster,
            helloRoster.count == match.capacity,
            Set(helloRoster.keys) == Set(roster.gamePlayerIDs),
            roster.coordinatorGamePlayerID
                == roster.gamePlayerIDs.min(),
            MultiplayerPeerConsistency.rosterMatches(
                helloRoster,
                participants: match.participants
            )
        else { return }
        isConfirmingRoster = true
        waitingState?.connection = .confirmingRoster(
            confirmed: greatestRosterConfirmationCount,
            total: match.capacity
        )
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isConfirmingRoster = false }
            do {
                try await ensureFreshGameCenterProof()
                let response = try await backend.confirmMultiplayerGameKitRoster(
                    match.matchId,
                    roster: roster
                )
                confirmedHelloRoster = helloRoster
                hasConfirmedRoster = true
                greatestRosterConfirmationCount = max(
                    greatestRosterConfirmationCount,
                    response.confirmedCount
                )
                rosterConfirmationCounts[roster.localGamePlayerID] =
                    response.confirmedCount
                debugMultiplayerLog(
                    "PHP roster confirmed=\(response.confirmedCount)/"
                        + "\(response.participantCount)"
                )
                try transport.sendRosterConfirmed(
                    confirmedCount: response.confirmedCount,
                    participantCount: response.participantCount
                )
                refreshWaitingConnectionState()
            } catch {
                waitingState?.connection = .failed(error.localizedDescription)
            }
        }
    }

    private func refreshWaitingConnectionState() {
        guard phase == .waiting, let match = currentMatch else { return }
        let clockReady = transport.isCoordinator || transport.clockEstimator.hasEstimate
        if hasConfirmedRoster,
            greatestRosterConfirmationCount == match.capacity,
            clockReady,
            disconnectedGamePlayerIDs.isEmpty
        {
            waitingState?.connection = .ready
            debugMultiplayerLog(
                "roster start-ready confirmed=\(greatestRosterConfirmationCount)/"
                    + "\(match.capacity) clockReady=\(clockReady)"
            )
        } else {
            waitingState?.connection = .confirmingRoster(
                confirmed: greatestRosterConfirmationCount,
                total: match.capacity
            )
        }
    }

    private func updateWaitingParticipantConnectivity() {
        guard let match = currentMatch else { return }
        applyMatch(match)
    }

    private func handleAvailableManifest(_ manifest: MultiplayerStartManifest) throws {
        guard transport.isCoordinator else { return }
        guard !didBroadcastStart else { return }
        let start = MultiplayerGameKitTransport.monotonicMilliseconds() + 1_000
        try transport.sendStartManifest(
            manifest,
            coordinatorStartMonotonicMilliseconds: start,
            presentationLeadMilliseconds: 1_000
        )
        didBroadcastStart = true
        try beginLiveMatch(manifest: manifest)
    }

    private func beginLiveMatch(manifest: MultiplayerStartManifest) throws {
        guard !didBeginLiveMatch else { return }
        let core = try Self.coreManifest(from: manifest)
        let reducer = try MultiplayerStateReducer(manifest: core)
        coreManifest = core
        playbackReducer = reducer
        transcriptEvents = []
        pendingPlans = [:]
        sentPlanIDs = []
        queuedInputs = []
        lastInputSequenceBySeat = [:]
        inputEvidenceCounts = [:]
        pendingCanonicalBatches = [:]
        peerConsistencyIntact = confirmedHelloRoster != nil
        pausedAtLogicalMilliseconds = nil
        localInputSequence = 0
        didSubmitTranscript = false
        didBroadcastFinish = false

        if transport.isCoordinator {
            let engine = try MultiplayerCoordinatorEngine(
                manifest: core,
                presentationLeadMilliseconds: 1_200
            )
            coordinatorEngine = engine
            let initialPlans = try engine.start()
            publishCoordinatorPlans(initialPlans, logicalMilliseconds: 0)
        }

        didBeginLiveMatch = true
        pollTask?.cancel()
        pollTask = nil
        phase = .live
        audio.setMusicContext(.gameplay)
        showAnnouncement("GET READY")
        startLiveTick()
    }

    private func startLiveTick() {
        tickTask?.cancel()
        tickTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, phase == .live else { return }
                let logical = currentLogicalMilliseconds()
                if transport.isCoordinator, pausedAtLogicalMilliseconds == nil {
                    processCoordinatorFrame(logicalMilliseconds: logical)
                }
                updateLivePresentation(at: logical)
                try? await Task.sleep(for: Self.liveTickInterval)
            }
        }
    }

    private func enqueueInput(
        _ input: MultiplayerInputPacket,
        receivedAt: Int,
        expectedSeat: Int,
        recordEvidence: Bool
    ) {
        guard input.seat == expectedSeat,
            input.inputSequence > (lastInputSequenceBySeat[input.seat] ?? 0),
            input.coordinatorInputMilliseconds >= 0,
            input.coordinatorInputMilliseconds
                <= currentLogicalMilliseconds() + 2_000
        else { return }
        lastInputSequenceBySeat[input.seat] = input.inputSequence
        if recordEvidence {
            incrementInputEvidence(input)
        }
        queuedInputs.append(
            QueuedInput(
                inputSequence: input.inputSequence,
                seat: input.seat,
                cell: input.cell,
                inputAt: input.coordinatorInputMilliseconds,
                receivedAt: max(receivedAt, input.coordinatorInputMilliseconds)
            )
        )
    }

    private func recordInputEvidence(
        _ input: MultiplayerInputPacket,
        expectedSeat: Int
    ) {
        guard input.seat == expectedSeat,
            input.inputSequence > (lastInputSequenceBySeat[input.seat] ?? 0),
            input.coordinatorInputMilliseconds >= 0,
            input.coordinatorInputMilliseconds
                <= currentLogicalMilliseconds() + 2_000
        else {
            peerConsistencyIntact = false
            return
        }
        lastInputSequenceBySeat[input.seat] = input.inputSequence
        incrementInputEvidence(input)
    }

    private func incrementInputEvidence(_ input: MultiplayerInputPacket) {
        let evidence = MultiplayerInputEvidenceKey(
            seat: input.seat,
            cell: input.cell,
            inputAt: input.coordinatorInputMilliseconds
        )
        inputEvidenceCounts[evidence, default: 0] += 1
    }

    private func processCoordinatorFrame(logicalMilliseconds: Int) {
        guard let engine = coordinatorEngine,
            engine.state.phase == .running
        else { return }
        let watermark = max(
            engine.clockMilliseconds,
            logicalMilliseconds
                - MultiplayerProtocolConstants.coordinatorReorderMilliseconds
        )
        let readyInputs =
            queuedInputs
            .filter { $0.inputAt <= watermark }
            .sorted {
                if $0.inputAt != $1.inputAt { return $0.inputAt < $1.inputAt }
                if $0.seat != $1.seat { return $0.seat < $1.seat }
                return $0.inputSequence < $1.inputSequence
            }
        let readySet = Set(
            readyInputs.map { "\($0.seat):\($0.inputSequence)" }
        )
        queuedInputs.removeAll {
            readySet.contains("\($0.seat):\($0.inputSequence)")
        }

        var events: [MultiplayerEvent] = []
        var plans: [MultiplayerActivationPlan] = []
        var cancellations: [Int] = []
        do {
            for input in readyInputs {
                let handledAt = max(
                    input.inputAt,
                    min(
                        max(input.receivedAt, engine.clockMilliseconds),
                        input.inputAt + 10_000
                    )
                )
                let output = try engine.handleTap(
                    seat: input.seat,
                    cell: input.cell,
                    inputAt: input.inputAt,
                    handledAt: handledAt
                )
                events.append(contentsOf: output.committedEvents)
                plans.append(contentsOf: output.plannedActivations)
                cancellations.append(contentsOf: output.cancelledPlanIds)
            }
            let advance = try engine.advance(to: watermark)
            events.append(contentsOf: advance.committedEvents)
            plans.append(contentsOf: advance.plannedActivations)
            cancellations.append(contentsOf: advance.cancelledPlanIds)
            emitCoordinatorOutput(
                events: events,
                plans: plans,
                cancellations: cancellations,
                logicalMilliseconds: watermark
            )
        } catch {
            failLiveMatch(error.localizedDescription)
        }
    }

    private func emitCoordinatorOutput(
        events: [MultiplayerEvent],
        plans: [MultiplayerActivationPlan],
        cancellations: [Int],
        logicalMilliseconds: Int
    ) {
        let committedEntities = Set(events.compactMap(Self.committedPlanEntity))
        let uniquePlans = Dictionary(uniqueKeysWithValues: plans.map { ($0.planId, $0) })
            .values
            .sorted { $0.planId < $1.planId }
            .filter {
                !committedEntities.contains(Self.planEntity($0))
                    && !sentPlanIDs.contains($0.planId)
                    && $0.at >= logicalMilliseconds
                        + MultiplayerGameKitTransport.defaultPresentationLeadMilliseconds
            }
        publishCoordinatorPlans(uniquePlans, logicalMilliseconds: logicalMilliseconds)

        let visibleCancellations = Set(cancellations).intersection(sentPlanIDs).sorted()
        if !visibleCancellations.isEmpty {
            try? transport.cancelActivationPlans(
                visibleCancellations,
                logicalMatchMilliseconds: logicalMilliseconds
            )
            for planID in visibleCancellations {
                sentPlanIDs.remove(planID)
                pendingPlans.removeValue(forKey: planID)
            }
        }

        guard !events.isEmpty else { return }
        let tuples = events.map(\.integerTuple)
        do {
            try transport.broadcastEvents(
                tuples,
                logicalMatchMilliseconds: logicalMilliseconds
            )
            applyCanonicalEvents(events)
        } catch {
            failLiveMatch(error.localizedDescription)
        }
    }

    private func publishCoordinatorPlans(
        _ plans: some Sequence<MultiplayerActivationPlan>,
        logicalMilliseconds: Int
    ) {
        let wire = plans.map(Self.wirePlan)
        guard !wire.isEmpty else { return }
        do {
            try transport.sendActivationPlans(
                wire,
                logicalMatchMilliseconds: logicalMilliseconds
            )
            for plan in wire {
                pendingPlans[plan.planId] = plan
                sentPlanIDs.insert(plan.planId)
            }
        } catch {
            failLiveMatch(error.localizedDescription)
        }
    }

    private func applyCanonicalTuples(_ tuples: [[Int]]) {
        do {
            let events = try tuples.map(MultiplayerEvent.init(integerTuple:))
            guard let firstSequence = events.first?.sequence else { return }
            if transport.isCoordinator {
                try applyCanonicalEventsThrowing(events)
            } else {
                pendingCanonicalBatches[firstSequence] = events
                drainPendingCanonicalBatches()
            }
        } catch {
            if !transport.isCoordinator {
                try? transport.requestSnapshot(
                    afterEventSequence: transcriptEvents.count,
                    logicalMatchMilliseconds: currentLogicalMilliseconds()
                )
            }
        }
    }

    private func applyCanonicalEvents(_ events: [MultiplayerEvent]) {
        do {
            try applyCanonicalEventsThrowing(events)
        } catch {
            failLiveMatch(error.localizedDescription)
        }
    }

    private func drainPendingCanonicalBatches() {
        while let events = pendingCanonicalBatches[transcriptEvents.count + 1] {
            guard consumeInputEvidence(for: events) else { return }
            pendingCanonicalBatches.removeValue(forKey: transcriptEvents.count + 1)
            do {
                try applyCanonicalEventsThrowing(
                    events,
                    consumesEvidence: false
                )
            } catch {
                peerConsistencyIntact = false
                failLiveMatch(error.localizedDescription)
                return
            }
        }
    }

    private func consumeInputEvidence(for events: [MultiplayerEvent]) -> Bool {
        MultiplayerPeerConsistency.consume(
            events: events,
            from: &inputEvidenceCounts
        )
    }

    private func applyCanonicalEventsThrowing(
        _ events: [MultiplayerEvent],
        playsFeedback: Bool = true,
        consumesEvidence: Bool = true
    ) throws {
        guard let reducer = playbackReducer else {
            throw MultiplayerControllerError.liveStateUnavailable
        }
        if consumesEvidence, !consumeInputEvidence(for: events) {
            throw MultiplayerControllerError.missingPeerInputEvidence
        }
        for event in events {
            guard event.sequence == transcriptEvents.count + 1 else {
                throw MultiplayerControllerError.noncontiguousTranscript
            }
            let targetBefore = reducer.state.target
            try reducer.apply(event)
            transcriptEvents.append(event)
            removeCommittedPlan(for: event)
            if playsFeedback {
                playFeedback(for: event, targetBefore: targetBefore, state: reducer.state)
            }
        }
        updateLivePresentation(at: currentLogicalMilliseconds())
        if reducer.state.phase == .finished {
            finishLiveMatch()
        }
    }

    private func applySnapshot(_ snapshot: MultiplayerSnapshotPacket) {
        let newTuples = snapshot.events.filter {
            ($0.count > 1 ? $0[1] : 0) > transcriptEvents.count
        }
        guard
            newTuples.isEmpty
                || ((newTuples.first?.count ?? 0) > 1
                    && newTuples.first?[1] == transcriptEvents.count + 1)
        else {
            try? transport.requestSnapshot(
                afterEventSequence: transcriptEvents.count,
                logicalMatchMilliseconds: currentLogicalMilliseconds()
            )
            return
        }
        do {
            let events = try newTuples.map(MultiplayerEvent.init(integerTuple:))
            if !consumeInputEvidence(for: events) {
                // Reconnect can restore presentation, but a peer that did not
                // independently witness input evidence must not attest that
                // the final transcript is peer-consistent.
                peerConsistencyIntact = false
            }
            try applyCanonicalEventsThrowing(
                events,
                playsFeedback: false,
                consumesEvidence: false
            )
            pendingPlans = Dictionary(
                uniqueKeysWithValues: snapshot.pendingPlans.map { ($0.planId, $0) }
            )
            pausedAtLogicalMilliseconds = snapshot.pausedAtLogicalMilliseconds
        } catch {
            peerConsistencyIntact = false
            failLiveMatch(error.localizedDescription)
        }
        updateRecoveryPresentation()
    }

    private func playFeedback(
        for event: MultiplayerEvent,
        targetBefore: MultiplayerTargetState?,
        state: MultiplayerLiveState
    ) {
        switch event {
        case .hit(_, let inputAt, _, let seat, _, _):
            audio.playTap(hitNumber: max(1, state.totalHits))
            guard seat == localSeat,
                let targetBefore
            else { return }
            let reaction = max(0, inputAt - targetBefore.presentedAt)
            let rating = SpeedRating.classify(
                reactionMilliseconds: Double(reaction)
            )
            showAnnouncement("\(rating.rating.label.uppercased()) · \(rating.displayedMilliseconds)ms")
        case .miss(_, _, _, let seat, _, _):
            audio.playLifeLoss()
            if seat == localSeat {
                showAnnouncement("MISSED")
            }
        default:
            break
        }
    }

    private func showAnnouncement(_ text: String) {
        currentAnnouncement = text
        updateLivePresentation(at: currentLogicalMilliseconds(), announcement: text)
        announcementTask?.cancel()
        announcementTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(950))
            guard !Task.isCancelled else { return }
            self?.currentAnnouncement = nil
            self?.updateLivePresentation(at: self?.currentLogicalMilliseconds() ?? 0)
        }
    }

    private func updateLivePresentation(
        at logicalMilliseconds: Int,
        announcement: String? = nil
    ) {
        guard let reducer = playbackReducer, let match = currentMatch else { return }
        if let announcement {
            currentAnnouncement = announcement
        }
        var cells: [Int: MultiplayerPresentation.Cell] = [:]
        if let target = reducer.state.target,
            logicalMilliseconds >= target.presentedAt,
            logicalMilliseconds < target.deadline
        {
            cells[target.cell] = MultiplayerPresentation.Cell(
                id: target.cell,
                colorIndex: target.colorIndex,
                ownerSeat: target.ownerSeat,
                glyph: Self.glyph(for: target.colorIndex),
                isTarget: true
            )
        }
        for decoy in reducer.state.decoys
        where logicalMilliseconds >= decoy.activatedAt
            && logicalMilliseconds < decoy.expiresAt
        {
            cells[decoy.cell] = MultiplayerPresentation.Cell(
                id: decoy.cell,
                colorIndex: decoy.colorIndex,
                ownerSeat: decoy.ownerSeat,
                glyph: Self.glyph(for: decoy.colorIndex),
                isDecoy: true
            )
        }
        for plan in pendingPlans.values
        where logicalMilliseconds >= plan.at
            && (plan.lifetimeMs.map { logicalMilliseconds < plan.at + $0 } ?? true)
            && cells[plan.cell] == nil
        {
            cells[plan.cell] = MultiplayerPresentation.Cell(
                id: plan.cell,
                colorIndex: plan.colorIndex,
                ownerSeat: plan.ownerSeat,
                glyph: Self.glyph(for: plan.colorIndex),
                isTarget: plan.kind == .target,
                isDecoy: plan.kind == .decoy
            )
        }

        let placements = reducer.placements()
        let leadingParticipantID = placements.first?.participantId
        let participantsByID = Dictionary(
            uniqueKeysWithValues: match.participants.map { ($0.participantId, $0) }
        )
        let players = reducer.state.players.sorted { $0.seat < $1.seat }.compactMap {
            player -> MultiplayerPresentation.LivePlayer? in
            guard let participant = participantsByID[player.participantId] else { return nil }
            return MultiplayerPresentation.LivePlayer(
                id: participant.participantId,
                seat: player.seat,
                colorIndex: player.colorIndex,
                name: participant.name,
                petID: participant.petId,
                points: player.score,
                multiplier: player.multiplier,
                lives: player.lives,
                isLeader: player.participantId == leadingParticipantID,
                isCurrentPlayer: participant.isCurrentPlayer,
                isConnected: isParticipantConnected(participant)
            )
        }
        let local = reducer.state.players.first(where: { $0.seat == localSeat })
        liveState = MultiplayerPresentation.LiveMatchState(
            matchID: match.matchId,
            elapsedMilliseconds: logicalMilliseconds,
            cells: Array(cells.values),
            players: players,
            localSeat: localSeat,
            streakSteps: local?.streakProgress ?? 0,
            isRecovering: !isApplicationActive
                || !disconnectedGamePlayerIDs.isEmpty
                || pausedAtLogicalMilliseconds != nil,
            announcement: currentAnnouncement
                ?? (local?.lives == 0 ? "SPECTATING" : nil)
        )
    }

    private func removeCommittedPlan(for event: MultiplayerEvent) {
        guard let entity = Self.committedPlanEntity(event) else { return }
        let planIDs = pendingPlans.values
            .filter { Self.wirePlanEntity($0) == entity }
            .map(\.planId)
        for planID in planIDs {
            pendingPlans.removeValue(forKey: planID)
            sentPlanIDs.remove(planID)
        }
    }

    private func finishLiveMatch() {
        guard !didSubmitTranscript,
            let manifest = coreManifest,
            let match = currentMatch
        else { return }
        tickTask?.cancel()
        tickTask = nil
        audio.setMusicContext(.menu)
        if transport.isCoordinator, !didBroadcastFinish {
            didBroadcastFinish = true
            try? transport.sendFinish(
                finalEventSequence: transcriptEvents.count,
                manifestHash: manifest.manifestHash,
                transcriptDigest: Self.transcriptDigest(transcriptEvents),
                logicalMatchMilliseconds: currentLogicalMilliseconds()
            )
        }
        guard peerConsistencyIntact,
            pendingCanonicalBatches.isEmpty,
            inputEvidenceCounts.isEmpty
        else {
            failLiveMatch(
                "This device could not independently verify every peer input."
            )
            return
        }
        didSubmitTranscript = true
        phase = .results
        resultsState = MultiplayerPresentation.ResultsState(
            settlement: .collecting(
                submitted: 0,
                total: match.participants.count
            ),
            results: provisionalResults(),
            isRefreshing: true,
            localSubmissionAccepted: false,
            message: "Submitting the retained peer-consistent transcript."
        )
        pendingSubmission = PendingSubmission(
            matchID: match.matchId,
            manifestHash: manifest.manifestHash,
            transcript: MultiplayerTranscriptSubmission(
                matchId: match.matchId,
                events: transcriptEvents.map(\.integerTuple)
            )
        )
        submitPendingTranscript()
    }

    private func submitPendingTranscript() {
        guard !isSubmittingTranscript, let pendingSubmission else { return }
        isSubmittingTranscript = true
        resultsState = MultiplayerPresentation.ResultsState(
            settlement: resultsState.settlement,
            results: resultsState.results,
            isRefreshing: true,
            localSubmissionAccepted: false,
            message: "Submitting the retained peer-consistent transcript."
        )
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isSubmittingTranscript = false }
            do {
                let response = try await backend.submitMultiplayerTranscript(
                    matchID: pendingSubmission.matchID,
                    manifestHash: pendingSubmission.manifestHash,
                    transcript: pendingSubmission.transcript
                )
                self.pendingSubmission = nil
                applySettlement(response)
                if response.state == "collecting" {
                    startSettlementPolling()
                }
            } catch {
                resultsState = MultiplayerPresentation.ResultsState(
                    settlement: resultsState.settlement,
                    results: provisionalResults(),
                    isRefreshing: false,
                    localSubmissionAccepted: false,
                    message:
                        "Submission unavailable. The exact transcript is retained; tap Check status to retry."
                )
            }
        }
    }

    private func handleFinishPacket(_ finish: MultiplayerFinishPacket) {
        guard finish.finalEventSequence == transcriptEvents.count else {
            try? transport.requestSnapshot(
                afterEventSequence: transcriptEvents.count,
                logicalMatchMilliseconds: currentLogicalMilliseconds()
            )
            return
        }
        guard finish.transcriptDigest == Self.transcriptDigest(transcriptEvents),
            finish.manifestHash == coreManifest?.manifestHash
        else {
            failLiveMatch("Peer transcript digest mismatch.")
            return
        }
        finishLiveMatch()
    }

    private func startSettlementPolling() {
        settlementTask?.cancel()
        guard let matchID = currentMatch?.matchId else { return }
        settlementTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1_500))
                guard let self, phase == .results else { return }
                do {
                    let response = try await backend.loadMultiplayerSettlement(matchID)
                    applySettlement(response)
                    if response.state != "collecting" { return }
                } catch {
                    resultsState = MultiplayerPresentation.ResultsState(
                        settlement: resultsState.settlement,
                        results: resultsState.results,
                        isRefreshing: false,
                        localSubmissionAccepted: resultsState.localSubmissionAccepted,
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

    private func applySettlement(_ response: MultiplayerSettlementResponse) {
        let settlement: MultiplayerPresentation.SettlementState =
            switch response.state {
            case "settled":
                .settled(leaderboardEligible: response.leaderboardEligible)
            case "review", "cancelled":
                .review(reason: response.reviewReason)
            default:
                .collecting(
                    submitted: response.submittedCount ?? 0,
                    total: response.participantCount
                        ?? currentMatch?.participants.count
                        ?? 2
                )
            }
        let results =
            response.results?.map(Self.presentedResult)
            ?? provisionalResults()
        resultsState = MultiplayerPresentation.ResultsState(
            settlement: settlement,
            results: results,
            isRefreshing: false,
            localSubmissionAccepted: true,
            message: response.state == "collecting"
                ? "Waiting for matching peer transcripts."
                : nil
        )
    }

    private func provisionalResults() -> [MultiplayerPresentation.Result] {
        guard let reducer = playbackReducer, let match = currentMatch else { return [] }
        let participants = Dictionary(
            uniqueKeysWithValues: match.participants.map { ($0.participantId, $0) }
        )
        return reducer.placements().compactMap { placement in
            guard let participant = participants[placement.participantId] else { return nil }
            return MultiplayerPresentation.Result(
                id: placement.participantId,
                place: placement.place,
                playerCount: match.participants.count,
                name: participant.name,
                petID: participant.petId,
                score: placement.score,
                survivalMilliseconds: reducer.state.finishedAt
                    ?? reducer.state.logicalMilliseconds,
                hits: placement.hits,
                misses: placement.misses,
                dodges: placement.dodges,
                fastestReactionMilliseconds: placement.fastestReactionMilliseconds,
                averageReactionMilliseconds: placement.averageReactionMilliseconds,
                maxMultiplier: placement.maximumMultiplier,
                isCurrentPlayer: participant.isCurrentPlayer
            )
        }
    }

    private func beginCoordinatedPause() {
        guard transport.isCoordinator, pausedAtLogicalMilliseconds == nil else { return }
        let logical = currentLogicalMilliseconds()
        pauseID += 1
        do {
            try transport.sendPause(
                pauseID: pauseID,
                logicalMatchMilliseconds: logical
            )
            pausedAtLogicalMilliseconds = logical
        } catch {
            peerConsistencyIntact = false
            failLiveMatch(error.localizedDescription)
        }
    }

    private func resumeCoordinatedPause() {
        guard transport.isCoordinator,
            let pausedAtLogicalMilliseconds
        else { return }
        do {
            try transport.sendResume(
                pauseID: pauseID,
                logicalMatchMilliseconds: pausedAtLogicalMilliseconds
            )
            self.pausedAtLogicalMilliseconds = nil
            currentAnnouncement = nil
        } catch {
            peerConsistencyIntact = false
            failLiveMatch(error.localizedDescription)
        }
    }

    private func markRecovering(message: String? = nil) {
        guard phase == .live else { return }
        updateLivePresentation(
            at: currentLogicalMilliseconds(),
            announcement: message ?? "RECONNECTING"
        )
        recoveryTask?.cancel()
        recoveryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.recoveryGrace)
            guard let self, !Task.isCancelled,
                phase == .live,
                !disconnectedGamePlayerIDs.isEmpty
                    || !isApplicationActive
                    || pausedAtLogicalMilliseconds != nil
            else { return }
            failLiveMatch("A player did not reconnect in time.")
            if let matchID = currentMatch?.matchId {
                _ = try? await backend.leaveMultiplayerMatch(matchID)
            }
        }
    }

    private func updateRecoveryPresentation() {
        if disconnectedGamePlayerIDs.isEmpty,
            isApplicationActive,
            pausedAtLogicalMilliseconds == nil
        {
            recoveryTask?.cancel()
            recoveryTask = nil
            currentAnnouncement = nil
        }
        updateLivePresentation(
            at: currentLogicalMilliseconds(),
            announcement: disconnectedGamePlayerIDs.isEmpty
                && pausedAtLogicalMilliseconds == nil
                ? nil
                : "RECONNECTING"
        )
    }

    private func failLiveMatch(_ message: String) {
        tickTask?.cancel()
        tickTask = nil
        audio.setMusicContext(.menu)
        phase = .results
        resultsState = MultiplayerPresentation.ResultsState(
            settlement: .review(reason: message),
            results: provisionalResults(),
            isRefreshing: false,
            localSubmissionAccepted: pendingSubmission == nil && didSubmitTranscript,
            message: "This match is not leaderboard eligible."
        )
    }

    private func resetMatchRuntime(disconnect: Bool) {
        pollTask?.cancel()
        tickTask?.cancel()
        settlementTask?.cancel()
        recoveryTask?.cancel()
        announcementTask?.cancel()
        matchmakingTask?.cancel()
        pollTask = nil
        tickTask = nil
        settlementTask = nil
        recoveryTask = nil
        announcementTask = nil
        matchmakingTask = nil
        matchmakingAttemptGate.clear()
        if disconnect { transport.disconnect() }
        currentMatch = nil
        waitingState = nil
        liveState = nil
        helloRoster = [:]
        confirmedHelloRoster = nil
        disconnectedGamePlayerIDs = []
        pauseID = 0
        pausedAtLogicalMilliseconds = nil
        isConfirmingRoster = false
        hasConfirmedRoster = false
        greatestRosterConfirmationCount = 0
        rosterConfirmationCounts = [:]
        didBeginLiveMatch = false
        didBroadcastStart = false
        didSubmitTranscript = false
        didBroadcastFinish = false
        localInputSequence = 0
        lastInputSequenceBySeat = [:]
        queuedInputs = []
        inputEvidenceCounts = [:]
        pendingCanonicalBatches = [:]
        peerConsistencyIntact = true
        pendingPlans = [:]
        sentPlanIDs = []
        coordinatorEngine = nil
        playbackReducer = nil
        coreManifest = nil
        transcriptEvents = []
        currentAnnouncement = nil
        pendingSubmission = nil
        isSubmittingTranscript = false
    }

    private var localSeat: Int {
        currentMatch?.participants.first(where: \.isCurrentPlayer)?.seat ?? 0
    }

    private func currentLogicalMilliseconds() -> Int {
        if let pausedAtLogicalMilliseconds {
            return pausedAtLogicalMilliseconds
        }
        return
            (try? transport.coordinatorLogicalMilliseconds(
                forLocalMonotonicMilliseconds:
                    MultiplayerGameKitTransport.monotonicMilliseconds()
            )) ?? 0
    }

    private func isParticipantConnected(_ participant: MultiplayerParticipant) -> Bool {
        if participant.isCurrentPlayer { return true }
        guard
            let gamePlayerID = helloRoster.first(where: {
                $0.value.participantId == participant.participantId
            })?.key
        else {
            return false
        }
        return !disconnectedGamePlayerIDs.contains(gamePlayerID)
    }

    private static func coreManifest(
        from manifest: MultiplayerStartManifest
    ) throws -> PimPoPomCore.MultiplayerManifest {
        let core = PimPoPomCore.MultiplayerManifest(
            protocolVersion: manifest.protocolVersion,
            ruleset: manifest.ruleset,
            proofVersion: manifest.proofVersion,
            matchId: manifest.matchId,
            buildId: manifest.buildId,
            seed: manifest.seed,
            startingLives: manifest.startingLives,
            participants: manifest.participants.map {
                PimPoPomCore.MultiplayerManifestParticipant(
                    participantId: $0.participantId,
                    seat: $0.seat,
                    colorIndex: $0.colorIndex
                )
            },
            manifestHash: manifest.manifestHash
        )
        try core.validate()
        return core
    }

    private static func wirePlan(
        _ plan: MultiplayerActivationPlan
    ) -> MultiplayerWireActivationPlan {
        MultiplayerWireActivationPlan(
            planId: plan.planId,
            kind: plan.kind == .target ? .target : .decoy,
            at: plan.at,
            ownerSeat: plan.ownerSeat,
            entityId: plan.entityId,
            cell: plan.cell,
            colorIndex: plan.colorIndex,
            lifetimeMs: plan.lifetimeMilliseconds
        )
    }

    private static func planEntity(
        _ plan: MultiplayerActivationPlan
    ) -> String {
        "\(plan.kind.rawValue):\(plan.entityId)"
    }

    private static func wirePlanEntity(
        _ plan: MultiplayerWireActivationPlan
    ) -> String {
        "\(plan.kind.rawValue):\(plan.entityId)"
    }

    private static func committedPlanEntity(
        _ event: MultiplayerEvent
    ) -> String? {
        switch event {
        case .target(_, _, _, let targetID, _, _):
            "target:\(targetID)"
        case .decoyActivate(_, _, _, let decoyID, _, _, _):
            "decoy:\(decoyID)"
        default:
            nil
        }
    }

    private static func transcriptDigest(_ events: [MultiplayerEvent]) -> String {
        let data = (try? JSONEncoder().encode(events.map(\.integerTuple))) ?? Data()
        return Data(SHA256.hash(data: data))
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func glyph(for colorIndex: Int) -> String {
        gameColors.indices.contains(colorIndex) ? gameColors[colorIndex].glyph : "●"
    }

    private static func presentedLobby(_ lobby: MultiplayerLobby)
        -> MultiplayerPresentation.Lobby
    {
        MultiplayerPresentation.Lobby(
            id: lobby.matchId,
            capacity: lobby.capacity,
            playerCount: lobby.playerCount,
            hostName: lobby.host.name,
            hostPetID: lobby.host.petId,
            expiresAt: parseDate(lobby.expiresAt)
        )
    }

    private static func presentedResult(_ result: MultiplayerSettlementResult)
        -> MultiplayerPresentation.Result
    {
        MultiplayerPresentation.Result(
            id: result.resultId,
            place: result.place,
            playerCount: result.playerCount,
            name: result.name,
            petID: result.petId,
            score: result.score,
            survivalMilliseconds: result.survivalMs,
            hits: result.hits,
            misses: result.misses,
            dodges: result.dodges,
            fastestReactionMilliseconds: result.fastestReactionMs,
            averageReactionMilliseconds: result.averageReactionMs,
            maxMultiplier: result.maxMultiplier,
            isCurrentPlayer: result.isCurrentPlayer
        )
    }

    private static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

private enum MultiplayerControllerError: LocalizedError {
    case prerequisitesUnavailable
    case liveStateUnavailable
    case noncontiguousTranscript
    case missingPeerInputEvidence

    var errorDescription: String? {
        switch self {
        case .prerequisitesUnavailable:
            "Sign in, confirm your player name, and connect Game Center first."
        case .liveStateUnavailable:
            "The multiplayer match state is unavailable."
        case .noncontiguousTranscript:
            "The multiplayer event stream has a sequence gap."
        case .missingPeerInputEvidence:
            "A multiplayer result did not have matching peer input evidence."
        }
    }
}
