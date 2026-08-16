import Combine
import CryptoKit
import Foundation
import OSLog
import PimPoPomCore

enum MultiplayerFlowPhase: Equatable {
    case hub
    case waiting
    case live
    case results
}

enum MultiplayerCoordinatorFramePolicy {
    static func handledAt(
        inputAt: Int,
        receivedAt: Int,
        engineClock: Int,
        watermark: Int
    ) -> Int {
        let latestHandledAt = min(inputAt + 10_000, watermark)
        return max(
            inputAt,
            min(max(receivedAt, engineClock), latestHandledAt)
        )
    }

    static func shouldAdvance(_ phase: MultiplayerLivePhase) -> Bool {
        phase == .running
    }

    static func shouldProcess(
        phase: MultiplayerLivePhase,
        isPaused: Bool
    ) -> Bool {
        !isPaused && shouldAdvance(phase)
    }
}

enum MultiplayerStartSchedulingPolicy {
    static let sendMarginMilliseconds = 250

    static func coordinatorStart(
        now: Int,
        presentationLeadMilliseconds: Int
    ) -> Int {
        now + presentationLeadMilliseconds + sendMarginMilliseconds
    }
}

private struct MultiplayerTerminalDrainState: Equatable {
    let finishEventSequence: Int
    let deadlineMonotonicMilliseconds: Int
    let localSeal: MultiplayerInputSeal
}

@MainActor
final class MultiplayerController: ObservableObject {
    static let gameCenterProofMaximumAge: TimeInterval = 10 * 60
    static let lobbyPollInterval: Duration = .milliseconds(1_250)
    static let recoveryGrace: Duration = .seconds(15)
    static let clockSynchronizationInterval: Duration = .milliseconds(140)
    static let clockSynchronizationTimeoutMilliseconds = 10_000

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

    private struct PendingSubmission: Codable, Equatable {
        let matchID: String
        let manifestHash: String
        let transcript: MultiplayerTranscriptSubmission
        let participantCount: Int
        let createdAt: Date
    }

    private struct PendingSubmissionStore {
        private let fileURL: URL?

        init(fileManager: FileManager = .default) {
            fileURL = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first?
            .appendingPathComponent("PimPoPom", isDirectory: true)
            .appendingPathComponent(
                "multiplayer-pending-submission-v1.json",
                isDirectory: false
            )
        }

        func load() -> PendingSubmission? {
            guard let fileURL,
                let data = try? Data(contentsOf: fileURL),
                let value = try? JSONDecoder().decode(
                    PendingSubmission.self,
                    from: data
                )
            else { return nil }
            return value
        }

        func save(_ value: PendingSubmission) {
            guard let fileURL,
                let data = try? JSONEncoder().encode(value)
            else { return }
            let directory = fileURL.deletingLastPathComponent()
            do {
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                var mutableDirectory = directory
                try? mutableDirectory.setResourceValues(resourceValues)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                // Settlement remains recoverable in memory for this process.
            }
        }

        func clear() {
            guard let fileURL else { return }
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private let backend: BackendClient
    private let gameCenter: GameCenterService
    private let audio: AudioController
    private let transport: any MultiplayerGameKitTransporting
    private let frameScheduler: any MultiplayerFrameScheduling
    private let latencyRecorder: any MultiplayerLatencyRecording

    private var currentMatch: MultiplayerMatch?
    private var pollTask: Task<Void, Never>?
    private var settlementTask: Task<Void, Never>?
    private var submissionTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private var recoveryTaskGeneration: UUID?
    private var terminalDeliveryTask: Task<Void, Never>?
    private var terminalDeliveryTaskGeneration: UUID?
    private var announcementTask: Task<Void, Never>?
    private var matchmakingTask: Task<Void, Never>?
    private var matchmakingGeneration: UInt64 = 0
    private var matchRuntimeGeneration: UInt64 = 0
    private var lobbySnapshotRevision: UInt64 = 0
    private var rosterConfirmationGeneration: UInt64 = 0
    private var waitingConnectionGeneration: UInt64 = 0
    private var clockSynchronizationTask: Task<Void, Never>?
    private var clockSynchronizationGeneration: UUID?
    private var matchmakingAttemptGate = MultiplayerMatchmakingAttemptGate()
    private var readyIntent = MultiplayerReadyIntent()
    private var isApplicationActive = true
    private var isTransportRecovering = false
    private var isConfirmingRoster = false
    private var didRejectIncompatibleLiveWire = false
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
    private var localPrediction = MultiplayerLocalInputPrediction()
    private var latencyCorrelation = MultiplayerLocalLatencyCorrelation()
    private var latencySampleByInputID: [MultiplayerInputID: MultiplayerLatencySampleID] = [:]
    private var latencySampleByEventSequence: [Int: MultiplayerLatencySampleID] = [:]
    private var localTouchLocationByInputID: [MultiplayerInputID: CGPoint] = [:]
    private var localTouchLocationByEventSequence: [Int: CGPoint] = [:]
    private var lastVisibleTargetActivationID: MultiplayerPresentedActivationID?
    private var localSealEmitter = MultiplayerLocalSealEmitter()
    private var resolutionWatchdog = MultiplayerResolutionWatchdog()
    private var inputFrontier: MultiplayerInputFrontier?
    private var inputReceivedAtByID: [MultiplayerInputID: Int] = [:]
    private var inputLedger = MultiplayerInputLedger()
    private var terminalDrainTracker: MultiplayerTerminalDrainTracker?
    private var terminalGate = MultiplayerTerminalGate()
    private var terminalDrainState: MultiplayerTerminalDrainState?
    private var pendingFinishPacket: MultiplayerFinishPacket?
    private var pendingStartManifest: MultiplayerStartManifest?
    private var didSendTerminalInputSeal = false
    private var pendingRecoverySnapshot: MultiplayerSnapshotPacket?
    private var pendingReconnectSnapshotRecipients: Set<String> = []
    private var snapshotAssembler = MultiplayerSnapshotAssembler()
    private var lastSnapshotRequestAtMonotonicMilliseconds: Int?
    private var frontierRecoveryBeganAtMonotonicMilliseconds: Int?
    private var fastNetworkPolicy: MultiplayerFrozenNetworkPolicy?
    private var pendingCanonicalBatches: [Int: [MultiplayerEvent]] = [:]
    private var pendingCoordinatorEvents: [MultiplayerEvent] = []
    private var pendingCoordinatorPlans = MultiplayerCoordinatorPlanOutbox()
    private var pendingCoordinatorCancellations: Set<Int> = []
    private var coordinatorSendRecoveryBeganAtMonotonicMilliseconds: Int?
    private var pauseRecoveryBeganAtMonotonicMilliseconds: Int?
    private var reliableRecoveryBeganAtMonotonicMilliseconds: Int?
    private var peerCanonicalRecoveryBeganAtMonotonicMilliseconds: Int?
    private var peerConsistencyIntact = true
    private var pendingPlans: [Int: MultiplayerWireActivationPlan] = [:]
    private var latestPlanMetadataControlSequence = 0
    private var latestPauseMetadataControlSequence = 0
    private var sentPlanIDs: Set<Int> = []
    private var coordinatorEngine: MultiplayerCoordinatorEngine?
    private var playbackReducer: MultiplayerStateReducer?
    private var coreManifest: PimPoPomCore.MultiplayerManifest?
    private var transcriptEvents: [MultiplayerEvent] = []
    private var currentAnnouncement: String?
    private var currentHitFeedbackEvent: GameplayHitFeedbackEvent?
    private var settlementRecovery: MultiplayerPresentation.SettlementRecovery<PendingSubmission>?
    private var isSubmittingTranscript = false
    private let pendingSubmissionStore = PendingSubmissionStore()
    private let logger = Logger(
        subsystem: "com.otcsoftware.pimpopom",
        category: "Multiplayer"
    )

    private func debugMultiplayerLog(_ message: String) {
        #if DEBUG
            print("[PimPoPom Multiplayer] \(message)")
        #endif
    }

    private func logMultiplayerError(_ message: String) {
        logger.error("\(message, privacy: .public)")
        #if DEBUG
            print("[PimPoPom Multiplayer] ERROR \(message)")
        #endif
    }

    init(
        backend: BackendClient,
        gameCenter: GameCenterService,
        audio: AudioController,
        transport: (any MultiplayerGameKitTransporting)? = nil,
        frameScheduler: (any MultiplayerFrameScheduling)? = nil,
        latencyRecorder: (any MultiplayerLatencyRecording)? = nil
    ) {
        self.backend = backend
        self.gameCenter = gameCenter
        self.audio = audio
        self.transport = transport ?? MultiplayerGameKitTransport()
        self.frameScheduler = frameScheduler ?? MultiplayerDisplayLinkScheduler()
        self.latencyRecorder = latencyRecorder ?? MultiplayerLatencyRecorderFactory.make()
        self.transport.eventHandler = { [weak self] event in
            self?.handleTransportEvent(event)
        }
        restorePendingSubmission()
        refreshAvailability()
        #if DEBUG
            configureUITestFixture(arguments: ProcessInfo.processInfo.arguments)
        #endif
    }

    deinit {
        pollTask?.cancel()
        settlementTask?.cancel()
        submissionTask?.cancel()
        recoveryTask?.cancel()
        terminalDeliveryTask?.cancel()
        announcementTask?.cancel()
        matchmakingTask?.cancel()
        clockSynchronizationTask?.cancel()
    }

    #if DEBUG
        private func configureUITestFixture(arguments: [String]) {
            let participants = [
                MultiplayerPresentation.Participant(
                    id: "fixture-player-0",
                    seat: 0,
                    colorIndex: 0,
                    name: "pimpovlad",
                    petID: "foka",
                    ready: true,
                    isCurrentPlayer: true,
                    isCreator: true
                ),
                MultiplayerPresentation.Participant(
                    id: "fixture-player-1",
                    seat: 1,
                    colorIndex: 1,
                    name: "alenka",
                    petID: "kesha",
                    ready: true,
                    isCurrentPlayer: false
                ),
                MultiplayerPresentation.Participant(
                    id: "fixture-player-2",
                    seat: 2,
                    colorIndex: 2,
                    name: "PixelPilot",
                    petID: "misha",
                    ready: true,
                    isCurrentPlayer: false
                ),
                MultiplayerPresentation.Participant(
                    id: "fixture-player-3",
                    seat: 3,
                    colorIndex: 3,
                    name: "TapMaster",
                    petID: "pancake",
                    ready: true,
                    isCurrentPlayer: false
                ),
            ]

            if arguments.contains("--ui-test-multiplayer-hub-fixture") {
                phase = .hub
                hubState = MultiplayerPresentation.HubState(
                    availability: .available,
                    lobbies: [
                        MultiplayerPresentation.Lobby(
                            id: "fixture-lobby",
                            capacity: 4,
                            playerCount: 2,
                            hostName: "PixelPilot",
                            hostPetID: "foka"
                        )
                    ]
                )
                return
            }

            if arguments.contains("--ui-test-multiplayer-waiting-fixture") {
                phase = .waiting
                waitingState = MultiplayerPresentation.WaitingRoomState(
                    matchID: "fixture-match",
                    capacity: 4,
                    isCreator: true,
                    participants: participants,
                    connection: .ready,
                    isMutationPending: false
                )
                return
            }

            let usesCatchUpFixture = arguments.contains(
                "--ui-test-multiplayer-catch-up-fixture"
            )
            guard
                arguments.contains("--ui-test-multiplayer-live-fixture")
                    || usesCatchUpFixture
            else {
                return
            }

            let livePlayers = [
                MultiplayerPresentation.LivePlayer(
                    id: "fixture-player-0",
                    seat: 0,
                    colorIndex: 0,
                    name: "pimpovlad",
                    petID: "foka",
                    points: 15_460,
                    multiplier: 4,
                    lives: 2,
                    isLeader: true,
                    isCurrentPlayer: true,
                    isConnected: true
                ),
                MultiplayerPresentation.LivePlayer(
                    id: "fixture-player-1",
                    seat: 1,
                    colorIndex: 1,
                    name: "alenka",
                    petID: "kesha",
                    points: 8_320,
                    multiplier: 3,
                    lives: 3,
                    isLeader: false,
                    isCurrentPlayer: false,
                    isConnected: true
                ),
                MultiplayerPresentation.LivePlayer(
                    id: "fixture-player-2",
                    seat: 2,
                    colorIndex: 2,
                    name: "PixelPilot",
                    petID: "misha",
                    points: 6_905,
                    multiplier: 2,
                    lives: 1,
                    isLeader: false,
                    isCurrentPlayer: false,
                    isConnected: true
                ),
                MultiplayerPresentation.LivePlayer(
                    id: "fixture-player-3",
                    seat: 3,
                    colorIndex: 3,
                    name: "TapMaster",
                    petID: "pancake",
                    points: 4_210,
                    multiplier: 1,
                    lives: 3,
                    isLeader: false,
                    isCurrentPlayer: false,
                    isConnected: true
                ),
            ]
            let cells = (0..<16).map { cellID in
                switch cellID {
                case 6:
                    MultiplayerPresentation.Cell(
                        id: cellID,
                        colorIndex: 0,
                        ownerSeat: 0,
                        glyph: gameColors[0].glyph,
                        isTarget: true
                    )
                case 12:
                    MultiplayerPresentation.Cell(
                        id: cellID,
                        colorIndex: 5,
                        ownerSeat: 2,
                        glyph: gameColors[5].glyph,
                        isDecoy: true
                    )
                default:
                    MultiplayerPresentation.Cell(id: cellID, colorIndex: nil)
                }
            }
            phase = .live
            liveState = MultiplayerPresentation.LiveMatchState(
                matchID: "fixture-match",
                elapsedMilliseconds: 46_000,
                cells: cells,
                players: livePlayers,
                localSeat: 0,
                streakSteps: 3,
                isRecovering: usesCatchUpFixture,
                networkStatus: usesCatchUpFixture ? .catchingUp : nil,
                announcement: nil,
                hitFeedbackEvent: GameplayHitFeedbackEvent(
                    id: 9,
                    rating: .godlike,
                    milliseconds: 200,
                    pointsAwarded: 541,
                    normalizedLocation: CGPoint(x: 0.625, y: 0.375)
                ),
                inputMode: .interactive
            )
        }
    #endif

    func open() {
        phase = .hub
        audio.setMusicContext(.menu)
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-test-multiplayer-hub-fixture") {
                return
            }
        #endif
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
        if isActive,
            phase == .results,
            settlementRecovery?.shouldRetrySubmission == true
        {
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
        guard waitingState?.canToggleReady == true else { return }
        readyIntent.request(ready)
        updateReadyIntentPresentation()
        waitingState?.message = nil
        flushReadyIntentIfPossible()
    }

    private func updateReadyIntentPresentation() {
        waitingState?.pendingReadyIntent = readyIntent.projectedReady
    }

    private func flushReadyIntentIfPossible() {
        guard let match = currentMatch,
            waitingState?.isMutationPending == false,
            let serverReady = match.participants.first(where: \.isCurrentPlayer)?.ready,
            let ready = readyIntent.takePendingMutation(
                serverReady: serverReady,
                compatibility: transport.liveCompatibility
            )
        else {
            updateReadyIntentPresentation()
            return
        }
        waitingState?.isMutationPending = true
        updateReadyIntentPresentation()
        let matchID = match.matchId
        lobbySnapshotRevision &+= 1
        let operationIdentity = MultiplayerLobbyOperationIdentity(
            matchID: matchID,
            runtimeGeneration: matchRuntimeGeneration,
            revision: lobbySnapshotRevision
        )
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if operationIdentity.isCurrent(
                    matchID: currentMatch?.matchId,
                    runtimeGeneration: matchRuntimeGeneration,
                    revision: lobbySnapshotRevision
                ) {
                    waitingState?.isMutationPending = false
                    updateReadyIntentPresentation()
                }
            }
            do {
                let updated = try await backend.setMultiplayerReadiness(
                    matchID,
                    ready: ready
                )
                guard !Task.isCancelled,
                    operationIdentity.isCurrent(
                        matchID: currentMatch?.matchId,
                        runtimeGeneration: matchRuntimeGeneration,
                        revision: lobbySnapshotRevision
                    )
                else { return }
                let acknowledgedReady =
                    updated.participants.first(where: \.isCurrentPlayer)?.ready ?? ready
                readyIntent.acknowledge(serverReady: acknowledgedReady)
                applyMatch(updated)
            } catch {
                guard !Task.isCancelled,
                    operationIdentity.isCurrent(
                        matchID: currentMatch?.matchId,
                        runtimeGeneration: matchRuntimeGeneration,
                        revision: lobbySnapshotRevision
                    )
                else { return }
                readyIntent.mutationFailed()
                waitingState?.message = error.localizedDescription
            }
        }
    }

    func startMatch() {
        guard let match = currentMatch,
            transport.liveCompatibility == .unanimous,
            transport.frozenNetworkPolicy != nil,
            disconnectedGamePlayerIDs.isEmpty,
            waitingState?.canStart == true,
            waitingState?.isMutationPending == false
        else { return }
        waitingState?.isMutationPending = true
        lobbySnapshotRevision &+= 1
        let operationIdentity = MultiplayerLobbyOperationIdentity(
            matchID: match.matchId,
            runtimeGeneration: matchRuntimeGeneration,
            revision: lobbySnapshotRevision
        )
        let connectionGeneration = waitingConnectionGeneration
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if operationIdentity.isCurrent(
                    matchID: currentMatch?.matchId,
                    runtimeGeneration: matchRuntimeGeneration,
                    revision: lobbySnapshotRevision
                ) {
                    waitingState?.isMutationPending = false
                }
            }
            do {
                try await ensureFreshGameCenterProof()
                try Task.checkCancellation()
                guard
                    operationIdentity.isCurrent(
                        matchID: currentMatch?.matchId,
                        runtimeGeneration: matchRuntimeGeneration,
                        revision: lobbySnapshotRevision
                    ),
                    waitingConnectionGeneration == connectionGeneration,
                    phase == .waiting,
                    waitingState?.connection == .ready,
                    transport.state == .connected,
                    transport.roster != nil,
                    disconnectedGamePlayerIDs.isEmpty
                else { return }
                let response = try await backend.startMultiplayerMatch(match.matchId)
                guard !Task.isCancelled,
                    operationIdentity.isCurrent(
                        matchID: currentMatch?.matchId,
                        runtimeGeneration: matchRuntimeGeneration,
                        revision: lobbySnapshotRevision
                    ),
                    waitingConnectionGeneration == connectionGeneration,
                    phase == .waiting,
                    waitingState?.connection == .ready,
                    transport.state == .connected,
                    transport.roster != nil,
                    disconnectedGamePlayerIDs.isEmpty
                else { return }
                do {
                    try handleAvailableManifest(response.manifest)
                } catch {
                    latchWaitingFailure(.failed(error.localizedDescription))
                    return
                }
            } catch {
                guard !Task.isCancelled,
                    operationIdentity.isCurrent(
                        matchID: currentMatch?.matchId,
                        runtimeGeneration: matchRuntimeGeneration,
                        revision: lobbySnapshotRevision
                    ),
                    waitingConnectionGeneration == connectionGeneration,
                    phase == .waiting,
                    waitingState?.connection == .ready
                else { return }
                waitingState?.message = error.localizedDescription
            }
        }
    }

    func retryGameKitConnection() {
        guard phase == .waiting else { return }
        readyIntent.reset()
        updateReadyIntentPresentation()
        matchRuntimeGeneration &+= 1
        lobbySnapshotRevision &+= 1
        rosterConfirmationGeneration &+= 1
        waitingConnectionGeneration &+= 1
        isConfirmingRoster = false
        matchmakingGeneration &+= 1
        matchmakingTask?.cancel()
        matchmakingTask = nil
        clockSynchronizationGeneration = nil
        clockSynchronizationTask?.cancel()
        clockSynchronizationTask = nil
        transport.disconnect()
        matchmakingAttemptGate.clear()
        helloRoster = [:]
        confirmedHelloRoster = nil
        hasConfirmedRoster = false
        greatestRosterConfirmationCount = 0
        rosterConfirmationCounts = [:]
        disconnectedGamePlayerIDs = []
        waitingState?.isMutationPending = false
        waitingState?.connection = .matching
        waitingState?.message = nil
        startLobbyPolling()
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

    func handleTap(
        cell: Int,
        localMonotonicMilliseconds: Int,
        normalizedLocation: CGPoint
    ) {
        guard phase == .live,
            terminalDrainState == nil,
            isApplicationActive,
            disconnectedGamePlayerIDs.isEmpty,
            !isTransportRecovering,
            let match = currentMatch,
            let local = match.participants.first(where: \.isCurrentPlayer),
            let localPlayer = playbackReducer?.state.players.first(where: {
                $0.seat == local.seat
            }),
            localPlayer.lives > 0,
            liveState?.inputMode == .interactive,
            let visibleTarget = liveState?.cells.first(where: \.isTarget),
            let activationID = visibleTarget.activationID,
            (0..<MultiplayerProtocolConstants.boardCellCount).contains(cell),
            let inputAt = inputLogicalMilliseconds(
                forLocalMonotonicMilliseconds: localMonotonicMilliseconds
            ),
            localPlayer.recoveryUntil.map({ inputAt >= $0 }) ?? true,
            inputAt > 0
        else { return }

        guard
            case .accepted(let inputID) = localPrediction.begin(
                seat: local.seat,
                activationID: activationID,
                tappedCell: cell,
                ownedTargetCell: visibleTarget.ownerSeat == local.seat
                    ? visibleTarget.id
                    : nil,
                inputAt: inputAt
            )
        else { return }
        localTouchLocationByInputID[inputID] = normalizedLocation
        let latencySampleID = MultiplayerLatencySampleID()
        latencyCorrelation.arm(
            inputID: inputID,
            sampleID: latencySampleID
        )
        latencySampleByInputID[inputID] = latencySampleID
        latencyRecorder.record(
            .touch,
            sampleID: latencySampleID,
            monotonicMilliseconds: localMonotonicMilliseconds,
            frameSequence: nil
        )
        resolutionWatchdog.begin(
            inputID: inputID,
            monotonicMilliseconds: localMonotonicMilliseconds
        )
        updateLivePresentation(at: currentLogicalMilliseconds())

        let packet = MultiplayerInputPacket(
            inputSequence: inputID.inputSequence,
            seat: local.seat,
            cell: cell,
            coordinatorInputMilliseconds: inputAt
        )
        do {
            try transport.stageInput(packet)
        } catch {
            peerConsistencyIntact = false
            failLiveMatch(error.localizedDescription)
            return
        }
        let runtimeGeneration = matchRuntimeGeneration
        let matchID = match.matchId
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self,
                matchRuntimeGeneration == runtimeGeneration,
                currentMatch?.matchId == matchID
            else { return }
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
            // Prediction has left the reaction touch-handler turn. Evidence was
            // journaled above, so a send failure remains recoverable.
            try? transport.sendStagedInput(
                packet,
                logicalMatchMilliseconds: inputAt
            )
        }
    }

    func refreshSettlement() {
        guard let matchID = activeSettlementMatchID else { return }
        if settlementRecovery?.shouldRetrySubmission == true {
            submitPendingTranscript()
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
                if activeSettlementMatchID == matchID {
                    resultsState = MultiplayerPresentation.ResultsState(
                        settlement: resultsState.settlement,
                        results: resultsState.results,
                        isRefreshing: false,
                        localSubmissionAccepted: resultsState.localSubmissionAccepted,
                        message: resultsState.message
                    )
                }
            }
            do {
                let response = try await backend.loadMultiplayerSettlement(matchID)
                applySettlement(
                    response,
                    source: .settlement,
                    matchID: matchID
                )
            } catch {
                guard activeSettlementMatchID == matchID else { return }
                guard var recovery = settlementRecovery,
                    recovery.recordSettlementResponseFailure(error.localizedDescription)
                else { return }
                settlementRecovery = recovery
                resultsState = MultiplayerPresentation.ResultsState(
                    settlement: recovery.settlement,
                    results: resultsState.results,
                    isRefreshing: false,
                    localSubmissionAccepted: recovery.localSubmissionAccepted,
                    message: recovery.message
                )
            }
        }
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
        let runtimeGeneration = matchRuntimeGeneration
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.lobbyPollInterval)
                guard let self, !Task.isCancelled,
                    phase == .waiting,
                    currentMatch?.matchId == matchID
                else { return }
                guard waitingState?.isMutationPending != true else { continue }
                let operationIdentity = MultiplayerLobbyOperationIdentity(
                    matchID: matchID,
                    runtimeGeneration: runtimeGeneration,
                    revision: lobbySnapshotRevision
                )
                let connectionGeneration = waitingConnectionGeneration
                do {
                    let updated = try await backend.loadMultiplayerMatch(matchID)
                    guard !Task.isCancelled,
                        phase == .waiting,
                        currentMatch?.matchId == matchID,
                        matchRuntimeGeneration == runtimeGeneration
                    else { return }
                    guard
                        operationIdentity.isCurrent(
                            matchID: currentMatch?.matchId,
                            runtimeGeneration: matchRuntimeGeneration,
                            revision: lobbySnapshotRevision
                        )
                    else { continue }
                    applyMatch(updated)
                    beginMatchmakingIfFull()
                    let canUseGameKit =
                        MultiplayerWaitingConnectionOperationPolicy.canContinue(
                            isWaiting: phase == .waiting,
                            isTransportConnected: transport.state == .connected,
                            hasDisconnectedPlayers: !disconnectedGamePlayerIDs.isEmpty,
                            expectedConnectionGeneration: connectionGeneration,
                            currentConnectionGeneration: waitingConnectionGeneration
                        )
                    guard canUseGameKit else {
                        if let manifest = updated.manifest, transport.isCoordinator {
                            pendingStartManifest = manifest
                        }
                        waitingState?.message = nil
                        continue
                    }
                    sendCurrentHelloIfNeeded()
                    try? transport.serviceRecovery()
                    if let manifest = updated.manifest {
                        do {
                            try handleAvailableManifest(manifest)
                        } catch {
                            latchWaitingFailure(.failed(error.localizedDescription))
                            return
                        }
                    }
                    waitingState?.message = nil
                } catch {
                    guard !Task.isCancelled,
                        phase == .waiting,
                        currentMatch?.matchId == matchID,
                        matchRuntimeGeneration == runtimeGeneration
                    else { return }
                    guard
                        operationIdentity.isCurrent(
                            matchID: currentMatch?.matchId,
                            runtimeGeneration: matchRuntimeGeneration,
                            revision: lobbySnapshotRevision
                        )
                    else { continue }
                    guard
                        MultiplayerWaitingConnectionOperationPolicy.canContinue(
                            isWaiting: phase == .waiting,
                            isTransportConnected: transport.state == .connected,
                            hasDisconnectedPlayers: !disconnectedGamePlayerIDs.isEmpty,
                            expectedConnectionGeneration: connectionGeneration,
                            currentConnectionGeneration: waitingConnectionGeneration
                        )
                    else { continue }
                    waitingState?.message = error.localizedDescription
                }
            }
        }
    }

    private func applyMatch(_ match: MultiplayerMatch) {
        currentMatch = match
        if let serverReady = match.participants.first(where: \.isCurrentPlayer)?.ready {
            readyIntent.observe(serverReady: serverReady)
        }
        let creatorSeat =
            match.isCreator
            ? match.participants.first(where: \.isCurrentPlayer)?.seat
            : match.participants.map(\.seat).min()
        let connectedParticipantIDs = Set(
            helloRoster.compactMap { gamePlayerID, hello in
                disconnectedGamePlayerIDs.contains(gamePlayerID)
                    ? nil
                    : hello.participantId
            }
        )
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
            expiresAt: Self.parseDate(match.expiresAt),
            pendingReadyIntent: readyIntent.projectedReady
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
        guard matchmakingAttemptGate.beginAttempt() else { return }
        waitingState?.connection = .matching
        matchmakingGeneration &+= 1
        let generation = matchmakingGeneration
        matchmakingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if matchmakingGeneration == generation {
                    matchmakingTask = nil
                }
            }
            do {
                try await ensureFreshGameCenterProof()
                try Task.checkCancellation()
                guard matchmakingGeneration == generation,
                    currentMatch?.matchId == match.matchId
                else { return }
                try await transport.connect(
                    matchID: match.matchId,
                    playerGroup: match.playerGroup,
                    participantCount: match.capacity
                )
            } catch {
                guard !Task.isCancelled,
                    matchmakingGeneration == generation,
                    currentMatch?.matchId == match.matchId
                else { return }
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
        latchWaitingFailure(
            failure.kind == .iCloudUnavailable
                ? .cloudSyncRequired
                : .connectionFailed(failure.message)
        )
    }

    private func handleTransportEvent(_ event: MultiplayerGameKitTransportEvent) {
        switch event {
        case .rosterReady:
            if phase == .live {
                isTransportRecovering = false
                updateRecoveryPresentation()
            }
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
            if transport.liveCompatibility == .incompatible {
                rejectIncompatibleLiveWire()
                return
            }
            confirmRosterIfComplete()
            flushReadyIntentIfPossible()
        case .packet(let received):
            handlePacket(received)
        case .playerDisconnected(let playerID):
            disconnectedGamePlayerIDs.insert(playerID)
            waitingConnectionGeneration &+= 1
            if phase == .waiting {
                rosterConfirmationGeneration &+= 1
                isConfirmingRoster = false
            }
            updateWaitingParticipantConnectivity()
            refreshWaitingConnectionState()
            if phase == .live, terminalDrainState == nil, !didBroadcastFinish {
                if transport.isCoordinator {
                    beginCoordinatedPause()
                } else if pausedAtLogicalMilliseconds == nil {
                    pausedAtLogicalMilliseconds = currentLogicalMilliseconds()
                }
            }
            markRecovering()
        case .playerReconnected(let playerID):
            disconnectedGamePlayerIDs.remove(playerID)
            isTransportRecovering = false
            waitingConnectionGeneration &+= 1
            updateWaitingParticipantConnectivity()
            if phase == .waiting {
                sendCurrentHelloIfNeeded(force: true)
                startClockSynchronization()
                confirmRosterIfComplete()
                refreshWaitingConnectionState()
                resumePendingStartIfPossible()
            }
            if phase == .live, transport.isCoordinator {
                pendingReconnectSnapshotRecipients.insert(playerID)
                serviceCoordinatorReconnectSnapshotsIfPossible(
                    logicalMilliseconds: currentLogicalMilliseconds()
                )
            } else if phase == .live {
                try? transport.requestSnapshot(
                    afterEventSequence: transcriptEvents.count,
                    logicalMatchMilliseconds: currentLogicalMilliseconds()
                )
            }
            if phase == .live, transport.isCoordinator,
                disconnectedGamePlayerIDs.isEmpty
            {
                resumeCoordinatedPause()
            }
            updateRecoveryPresentation()
        case .failed(let message):
            if phase == .live {
                isTransportRecovering = true
                markRecovering()
            } else if phase == .waiting {
                waitingConnectionGeneration &+= 1
                pendingStartManifest = nil
                if transport.networkPolicyError != nil {
                    latchWaitingFailure(.failed("Network Not Supported"))
                    waitingState?.message =
                        "This connection cannot keep FAST Multiplayer deterministic."
                    if let matchID = currentMatch?.matchId {
                        Task { @MainActor [weak self] in
                            _ = try? await self?.backend.leaveMultiplayerMatch(matchID)
                        }
                    }
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
    }

    private func handlePacket(_ received: MultiplayerReceivedPacket) {
        switch received.envelope.payload {
        case .networkMeasurement, .networkPolicyVote:
            confirmRosterIfComplete()
            flushReadyIntentIfPossible()
            refreshWaitingConnectionState()
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
            guard disconnectedGamePlayerIDs.isEmpty else {
                pendingStartManifest = signal.manifest
                return
            }
            do {
                try beginLiveMatch(manifest: signal.manifest)
            } catch {
                latchWaitingFailure(.failed(error.localizedDescription))
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
        case .inputSeal(let seal):
            guard transport.isCoordinator,
                let expectedSeat = confirmedHelloRoster?[received.senderGamePlayerID]?.seat,
                seal.seat == expectedSeat
            else { return }
            recordInputSeal(seal)
        case .inputResolution(let resolution):
            guard
                received.senderGamePlayerID
                    == transport.roster?.coordinatorGamePlayerID
            else {
                peerConsistencyIntact = false
                return
            }
            recordInputResolution(resolution)
            drainPendingCanonicalBatches()
            attemptTerminalCompletion()
        case .terminalInputSeal(let packet):
            guard transport.isCoordinator,
                packet.finishEventSequence == terminalDrainState?.finishEventSequence,
                confirmedHelloRoster?[received.senderGamePlayerID]?.seat
                    == packet.seal.seat
            else { return }
            recordTerminalInputSeal(packet.seal)
        case .terminalCancel(let cancellation):
            guard
                received.senderGamePlayerID
                    == transport.roster?.coordinatorGamePlayerID
            else {
                peerConsistencyIntact = false
                return
            }
            cancelLiveWithoutSettlement(
                reason: cancellation.reason,
                message: "The coordinator cancelled settlement because live input could not be reconciled.",
                broadcastsToPeers: false
            )
        case .activationPlans(let packet):
            guard !transport.isCoordinator else { return }
            latestPlanMetadataControlSequence = max(
                latestPlanMetadataControlSequence,
                received.envelope.packetSequence
            )
            for plan in packet.plans {
                pendingPlans[plan.planId] = plan
            }
            updateLivePresentation(at: currentLogicalMilliseconds())
        case .cancelActivationPlans(let packet):
            latestPlanMetadataControlSequence = max(
                latestPlanMetadataControlSequence,
                received.envelope.packetSequence
            )
            for planID in packet.planIds {
                pendingPlans.removeValue(forKey: planID)
            }
            updateLivePresentation(at: currentLogicalMilliseconds())
        case .events(let packet):
            guard !transport.isCoordinator else { return }
            applyCanonicalTuples(packet.events)
        case .snapshot(let snapshot):
            guard !transport.isCoordinator else { return }
            receiveSnapshotChunk(snapshot)
        case .snapshotRequest(let request):
            guard transport.isCoordinator else { return }
            let remaining =
                transcriptEvents
                .filter { $0.sequence > request.afterEventSequence }
                .map(\.integerTuple)
            do {
                try transport.sendSnapshot(
                    events: remaining,
                    pendingPlans: Array(pendingPlans.values),
                    afterEventSequence: request.afterEventSequence,
                    logicalMatchMilliseconds: currentLogicalMilliseconds(),
                    to: received.senderGamePlayerID
                )
            } catch {
                pendingReconnectSnapshotRecipients.insert(received.senderGamePlayerID)
            }
        case .pause(let pause):
            latestPauseMetadataControlSequence = max(
                latestPauseMetadataControlSequence,
                received.envelope.packetSequence
            )
            pausedAtLogicalMilliseconds = pause.pausedAtLogicalMilliseconds
            if pauseRecoveryBeganAtMonotonicMilliseconds == nil {
                pauseRecoveryBeganAtMonotonicMilliseconds =
                    MultiplayerGameKitTransport.monotonicMilliseconds()
            }
            markRecovering()
        case .resume:
            latestPauseMetadataControlSequence = max(
                latestPauseMetadataControlSequence,
                received.envelope.packetSequence
            )
            guard pausedAtLogicalMilliseconds != nil else { return }
            pausedAtLogicalMilliseconds = nil
            pauseRecoveryBeganAtMonotonicMilliseconds = nil
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
        guard
            MultiplayerClockSynchronizationPolicy.shouldStart(
                isCoordinator: transport.isCoordinator,
                isWaiting: phase == .waiting,
                isTransportConnected: transport.state == .connected,
                connectionPresentsFailure: waitingState?.connection.shouldPresentFailure ?? true,
                hasMeasurement: transport.clockEstimator.hasNetworkMeasurement,
                hasTask: clockSynchronizationTask != nil,
                hasMatchID: currentMatch?.matchId != nil
            ),
            let matchID = currentMatch?.matchId
        else { return }
        let generation = UUID()
        clockSynchronizationGeneration = generation
        clockSynchronizationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if clockSynchronizationGeneration == generation {
                    clockSynchronizationTask = nil
                    clockSynchronizationGeneration = nil
                }
            }
            let deadline =
                MultiplayerGameKitTransport.monotonicMilliseconds()
                + Self.clockSynchronizationTimeoutMilliseconds
            while MultiplayerClockSynchronizationPolicy.shouldContinue(
                now: MultiplayerGameKitTransport.monotonicMilliseconds(),
                deadline: deadline,
                hasMeasurement: transport.clockEstimator.hasNetworkMeasurement
            ) {
                guard !Task.isCancelled,
                    phase == .waiting,
                    currentMatch?.matchId == matchID
                else { return }
                if transport.clockEstimator.hasNetworkMeasurement {
                    confirmRosterIfComplete()
                    refreshWaitingConnectionState()
                    return
                }
                if !disconnectedGamePlayerIDs.isEmpty {
                    try? await Task.sleep(for: Self.clockSynchronizationInterval)
                    continue
                }
                try? transport.sendClockPing(
                    localMonotonicMilliseconds:
                        MultiplayerGameKitTransport.monotonicMilliseconds()
                )
                try? await Task.sleep(for: Self.clockSynchronizationInterval)
            }
            guard !Task.isCancelled,
                !transport.clockEstimator.hasNetworkMeasurement
            else {
                confirmRosterIfComplete()
                refreshWaitingConnectionState()
                return
            }
            failClockSynchronization(matchID: matchID, generation: generation)
        }
    }

    private func failClockSynchronization(matchID: String, generation: UUID) {
        guard phase == .waiting,
            currentMatch?.matchId == matchID,
            clockSynchronizationGeneration == generation,
            transport.state == .connected,
            waitingState?.connection.shouldPresentFailure == false
        else { return }
        waitingState?.connection = .connectionFailed(
            "Clock synchronization did not complete. Please retry."
        )
        waitingState?.message = nil
        transport.disconnect()
    }

    private func sendCurrentHelloIfNeeded(force: Bool = false) {
        guard phase == .waiting,
            transport.state == .connected,
            disconnectedGamePlayerIDs.isEmpty,
            waitingState?.connection.shouldPresentFailure == false,
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
            startClockSynchronization()
        } catch {
            guard phase == .waiting,
                transport.state == .connected,
                waitingState?.connection.shouldPresentFailure == false
            else { return }
            waitingState?.message = error.localizedDescription
        }
    }

    private func confirmRosterIfComplete() {
        let connectionGeneration = waitingConnectionGeneration
        guard !isConfirmingRoster,
            !hasConfirmedRoster,
            MultiplayerWaitingConnectionOperationPolicy.canContinue(
                isWaiting: phase == .waiting,
                isTransportConnected: transport.state == .connected,
                hasDisconnectedPlayers: !disconnectedGamePlayerIDs.isEmpty,
                expectedConnectionGeneration: connectionGeneration,
                currentConnectionGeneration: waitingConnectionGeneration
            ),
            transport.liveCompatibility == .unanimous,
            transport.frozenNetworkPolicy != nil,
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
        rosterConfirmationGeneration &+= 1
        let confirmationGeneration = rosterConfirmationGeneration
        let runtimeGeneration = matchRuntimeGeneration
        let gameKitGeneration = matchmakingGeneration
        let helloSnapshot = helloRoster
        waitingState?.connection = .confirmingRoster(
            confirmed: greatestRosterConfirmationCount,
            total: match.capacity
        )
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if rosterConfirmationGeneration == confirmationGeneration {
                    isConfirmingRoster = false
                }
            }
            do {
                try await ensureFreshGameCenterProof()
                try Task.checkCancellation()
                guard
                    MultiplayerWaitingConnectionOperationPolicy.canContinue(
                        isWaiting: phase == .waiting,
                        isTransportConnected: transport.state == .connected,
                        hasDisconnectedPlayers: !disconnectedGamePlayerIDs.isEmpty,
                        expectedConnectionGeneration: connectionGeneration,
                        currentConnectionGeneration: waitingConnectionGeneration
                    ),
                    currentMatch?.matchId == match.matchId,
                    matchRuntimeGeneration == runtimeGeneration,
                    matchmakingGeneration == gameKitGeneration,
                    rosterConfirmationGeneration == confirmationGeneration,
                    transport.roster == roster,
                    helloRoster == helloSnapshot
                else { return }
                let response = try await backend.confirmMultiplayerGameKitRoster(
                    match.matchId,
                    roster: roster
                )
                guard !Task.isCancelled,
                    MultiplayerWaitingConnectionOperationPolicy.canContinue(
                        isWaiting: phase == .waiting,
                        isTransportConnected: transport.state == .connected,
                        hasDisconnectedPlayers: !disconnectedGamePlayerIDs.isEmpty,
                        expectedConnectionGeneration: connectionGeneration,
                        currentConnectionGeneration: waitingConnectionGeneration
                    ),
                    currentMatch?.matchId == match.matchId,
                    matchRuntimeGeneration == runtimeGeneration,
                    matchmakingGeneration == gameKitGeneration,
                    rosterConfirmationGeneration == confirmationGeneration,
                    transport.roster == roster,
                    helloRoster == helloSnapshot
                else { return }
                confirmedHelloRoster = helloSnapshot
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
                do {
                    try transport.sendRosterConfirmed(
                        confirmedCount: response.confirmedCount,
                        participantCount: response.participantCount
                    )
                } catch {
                    waitingState?.message = error.localizedDescription
                    try? transport.serviceRecovery()
                    refreshWaitingConnectionState()
                    return
                }
                waitingState?.message = nil
                refreshWaitingConnectionState()
            } catch {
                guard !Task.isCancelled,
                    MultiplayerWaitingConnectionOperationPolicy.canContinue(
                        isWaiting: phase == .waiting,
                        isTransportConnected: transport.state == .connected,
                        hasDisconnectedPlayers: !disconnectedGamePlayerIDs.isEmpty,
                        expectedConnectionGeneration: connectionGeneration,
                        currentConnectionGeneration: waitingConnectionGeneration
                    ),
                    currentMatch?.matchId == match.matchId,
                    matchRuntimeGeneration == runtimeGeneration,
                    matchmakingGeneration == gameKitGeneration,
                    rosterConfirmationGeneration == confirmationGeneration,
                    transport.roster == roster,
                    helloRoster == helloSnapshot
                else { return }
                waitingState?.message = error.localizedDescription
                refreshWaitingConnectionState()
            }
        }
    }

    private func refreshWaitingConnectionState() {
        guard phase == .waiting,
            let match = currentMatch,
            let currentWaitingState = waitingState,
            MultiplayerPresentation.WaitingConnectionRefreshPolicy.canRefresh(
                isTransportConnected: transport.state == .connected,
                current: currentWaitingState.connection
            )
        else { return }
        if transport.liveCompatibility == .incompatible {
            rejectIncompatibleLiveWire()
            return
        }
        let clockReady =
            transport.isCoordinator || transport.clockEstimator.hasNetworkMeasurement
        if hasConfirmedRoster,
            greatestRosterConfirmationCount == match.capacity,
            transport.liveCompatibility == .unanimous,
            transport.frozenNetworkPolicy != nil,
            clockReady,
            disconnectedGamePlayerIDs.isEmpty
        {
            waitingState?.connection = .ready
            debugMultiplayerLog(
                "roster start-ready confirmed=\(greatestRosterConfirmationCount)/"
                    + "\(match.capacity) clockReady=\(clockReady)"
            )
            resumePendingStartIfPossible()
        } else {
            waitingState?.connection = .confirmingRoster(
                confirmed: greatestRosterConfirmationCount,
                total: match.capacity
            )
        }
    }

    private func rejectIncompatibleLiveWire() {
        guard phase == .waiting, !didRejectIncompatibleLiveWire else { return }
        didRejectIncompatibleLiveWire = true
        readyIntent.reset()
        matchRuntimeGeneration &+= 1
        lobbySnapshotRevision &+= 1
        rosterConfirmationGeneration &+= 1
        isConfirmingRoster = false
        pollTask?.cancel()
        pollTask = nil
        matchmakingGeneration &+= 1
        matchmakingTask?.cancel()
        matchmakingTask = nil
        clockSynchronizationGeneration = nil
        clockSynchronizationTask?.cancel()
        clockSynchronizationTask = nil
        waitingState?.connection = .failed("Update Required")
        waitingState?.isMutationPending = false
        waitingState?.message = "Every player needs the latest Multiplayer update."
        transport.disconnect()
        guard let matchID = currentMatch?.matchId else { return }
        Task { @MainActor [weak self] in
            _ = try? await self?.backend.leaveMultiplayerMatch(matchID)
        }
    }

    private func updateWaitingParticipantConnectivity() {
        guard let match = currentMatch else { return }
        applyMatch(match)
    }

    private func handleAvailableManifest(_ manifest: MultiplayerStartManifest) throws {
        guard transport.liveCompatibility == .unanimous,
            transport.frozenNetworkPolicy != nil,
            transport.state == .connected
        else {
            throw MultiplayerGameKitError.incompatibleLiveWire
        }
        guard transport.isCoordinator else { return }
        guard waitingState?.connection == .ready,
            transport.roster != nil,
            !transport.hasActivePause,
            !transport.hasPendingReliableRecovery
        else {
            pendingStartManifest = manifest
            return
        }
        guard disconnectedGamePlayerIDs.isEmpty else {
            pendingStartManifest = manifest
            return
        }
        guard !didBroadcastStart else { return }
        let presentationLeadMilliseconds = 1_000
        let start = MultiplayerStartSchedulingPolicy.coordinatorStart(
            now: MultiplayerGameKitTransport.monotonicMilliseconds(),
            presentationLeadMilliseconds: presentationLeadMilliseconds
        )
        do {
            try transport.sendStartManifest(
                manifest,
                coordinatorStartMonotonicMilliseconds: start,
                presentationLeadMilliseconds: presentationLeadMilliseconds
            )
        } catch {
            pendingStartManifest = manifest
            return
        }
        didBroadcastStart = true
        try beginLiveMatch(manifest: manifest)
    }

    private func resumePendingStartIfPossible() {
        guard phase == .waiting,
            disconnectedGamePlayerIDs.isEmpty,
            waitingState?.connection == .ready,
            transport.state == .connected,
            let manifest = pendingStartManifest
        else { return }
        pendingStartManifest = nil
        do {
            if transport.isCoordinator {
                try handleAvailableManifest(manifest)
            } else {
                try beginLiveMatch(manifest: manifest)
            }
        } catch {
            latchWaitingFailure(.failed(error.localizedDescription))
        }
    }

    private func latchWaitingFailure(
        _ connection: MultiplayerPresentation.WaitingConnectionState
    ) {
        guard phase == .waiting else { return }
        readyIntent.reset()
        updateReadyIntentPresentation()
        matchRuntimeGeneration &+= 1
        lobbySnapshotRevision &+= 1
        rosterConfirmationGeneration &+= 1
        waitingConnectionGeneration &+= 1
        matchmakingGeneration &+= 1
        isConfirmingRoster = false
        pendingStartManifest = nil
        pollTask?.cancel()
        pollTask = nil
        matchmakingTask?.cancel()
        matchmakingTask = nil
        clockSynchronizationGeneration = nil
        clockSynchronizationTask?.cancel()
        clockSynchronizationTask = nil
        transport.disconnect()
        waitingState?.isMutationPending = false
        waitingState?.connection = connection
    }

    private func beginLiveMatch(manifest: MultiplayerStartManifest) throws {
        guard transport.liveCompatibility == .unanimous,
            let frozenNetworkPolicy = transport.frozenNetworkPolicy,
            transport.state == .connected,
            !transport.hasActivePause
        else {
            throw MultiplayerGameKitError.incompatibleLiveWire
        }
        guard !didBeginLiveMatch else { return }
        let core = try Self.coreManifest(from: manifest)
        let reducer = try MultiplayerStateReducer(manifest: core)
        coreManifest = core
        playbackReducer = reducer
        transcriptEvents = []
        pendingPlans = [:]
        latestPlanMetadataControlSequence = 0
        latestPauseMetadataControlSequence = 0
        sentPlanIDs = []
        localPrediction.reset()
        latencyCorrelation.reset()
        latencySampleByInputID = [:]
        latencySampleByEventSequence = [:]
        localTouchLocationByInputID = [:]
        localTouchLocationByEventSequence = [:]
        currentHitFeedbackEvent = nil
        lastVisibleTargetActivationID = nil
        localSealEmitter.reset()
        resolutionWatchdog.reset()
        inputFrontier = try MultiplayerInputFrontier(
            seats: core.participants.map(\.seat).sorted()
        )
        terminalDrainTracker = try MultiplayerTerminalDrainTracker(
            seats: core.participants.map(\.seat).sorted()
        )
        terminalDrainState = nil
        terminalGate.reset()
        pendingFinishPacket = nil
        pendingStartManifest = nil
        didSendTerminalInputSeal = false
        inputReceivedAtByID = [:]
        inputLedger = MultiplayerInputLedger()
        fastNetworkPolicy = frozenNetworkPolicy
        pendingRecoverySnapshot = nil
        pendingReconnectSnapshotRecipients = []
        snapshotAssembler.reset()
        lastSnapshotRequestAtMonotonicMilliseconds = nil
        frontierRecoveryBeganAtMonotonicMilliseconds = nil
        pendingCanonicalBatches = [:]
        pendingCoordinatorEvents = []
        pendingCoordinatorPlans.reset()
        pendingCoordinatorCancellations = []
        coordinatorSendRecoveryBeganAtMonotonicMilliseconds = nil
        pauseRecoveryBeganAtMonotonicMilliseconds = nil
        reliableRecoveryBeganAtMonotonicMilliseconds = nil
        peerCanonicalRecoveryBeganAtMonotonicMilliseconds = nil
        peerConsistencyIntact = confirmedHelloRoster != nil
        pausedAtLogicalMilliseconds = nil
        isTransportRecovering = false
        didSubmitTranscript = false
        didBroadcastFinish = false

        var initialCoordinatorPlans: [MultiplayerActivationPlan] = []
        if transport.isCoordinator {
            let engine = try MultiplayerCoordinatorEngine(
                manifest: core,
                presentationLeadMilliseconds: 1_200
            )
            coordinatorEngine = engine
            initialCoordinatorPlans = try engine.start()
        }

        didBeginLiveMatch = true
        clockSynchronizationGeneration = nil
        clockSynchronizationTask?.cancel()
        clockSynchronizationTask = nil
        pollTask?.cancel()
        pollTask = nil
        phase = .live
        audio.setMusicContext(.gameplay)
        showAnnouncement("GET READY")
        publishCoordinatorPlans(initialCoordinatorPlans, logicalMilliseconds: 0)
        startLiveTick()
    }

    private func startLiveTick() {
        frameScheduler.stop()
        frameScheduler.onFrame = { [weak self] frame in
            self?.handleDisplayFrame(frame)
        }
        frameScheduler.start()
    }

    private func handleDisplayFrame(_ frame: MultiplayerDisplayFrame) {
        guard phase == .live else {
            frameScheduler.stop()
            return
        }
        if let (sampleID, acknowledgedFrame) =
            latencyCorrelation.takeAcknowledgement(on: frame)
        {
            latencyRecorder.record(
                .localAcknowledgement,
                sampleID: sampleID,
                monotonicMilliseconds: Int(
                    (acknowledgedFrame.targetTimestamp * 1_000).rounded()
                ),
                frameSequence: acknowledgedFrame.sequence
            )
        }
        let logicalMilliseconds = currentLogicalMilliseconds()
        try? transport.serviceRecovery()
        serviceCoordinatorReconnectSnapshotsIfPossible(
            logicalMilliseconds: logicalMilliseconds
        )
        refreshReliableRecoveryState()
        refreshPeerCanonicalRecoveryState()
        servicePeerSnapshotRecoveryIfNeeded(
            logicalMilliseconds: logicalMilliseconds
        )
        if enforceBoundedRecoveryDeadlines() { return }
        if transport.isCoordinator,
            disconnectedGamePlayerIDs.isEmpty,
            isApplicationActive,
            pausedAtLogicalMilliseconds != nil
        {
            flushPendingCoordinatorTransportOutput(
                logicalMilliseconds: logicalMilliseconds
            )
            if pendingCoordinatorEvents.isEmpty,
                pendingCoordinatorPlans.isEmpty,
                pendingCoordinatorCancellations.isEmpty
            {
                resumeCoordinatedPause()
            }
        }
        if pausedAtLogicalMilliseconds == nil {
            if terminalDrainState == nil {
                emitLocalInputSeal(logicalMilliseconds: logicalMilliseconds)
                if transport.isCoordinator {
                    processCoordinatorFrame(logicalMilliseconds: logicalMilliseconds)
                }
            } else {
                emitTerminalInputSealIfNeeded(
                    logicalMilliseconds: logicalMilliseconds
                )
                attemptTerminalCompletion()
                enforceTerminalDrainDeadline()
            }
        }
        processResolutionWatchdog()
        updateLivePresentation(at: logicalMilliseconds)
        recordFirstVisibleTarget(on: frame)
    }

    private func recordFirstVisibleTarget(on frame: MultiplayerDisplayFrame) {
        guard let activationID = liveState?.cells.first(where: \.isTarget)?.activationID,
            activationID != lastVisibleTargetActivationID
        else { return }
        lastVisibleTargetActivationID = activationID
        latencyRecorder.record(
            .targetFirstVisible,
            sampleID: MultiplayerLatencySampleID(),
            monotonicMilliseconds: Int((frame.targetTimestamp * 1_000).rounded()),
            frameSequence: frame.sequence
        )
    }

    private func enqueueInput(
        _ input: MultiplayerInputPacket,
        receivedAt: Int,
        expectedSeat: Int,
        recordEvidence: Bool
    ) {
        let maximumAcceptedInputAt = MultiplayerInputAdmissionPolicy.maximumAcceptedInputAt(
            currentLogicalMilliseconds: currentLogicalMilliseconds(),
            isPausedForRecovery: pausedAtLogicalMilliseconds != nil,
            recoveryLimitMilliseconds:
                fastNetworkPolicy?.evidenceRecoveryMilliseconds ?? 15_000
        )
        guard input.seat == expectedSeat,
            input.coordinatorInputMilliseconds >= 0,
            input.coordinatorInputMilliseconds <= maximumAcceptedInputAt
        else { return }
        let latencySampleID =
            latencySampleByInputID[input.id]
            ?? MultiplayerLatencySampleID()
        latencySampleByInputID[input.id] = latencySampleID
        latencyRecorder.record(
            .coordinatorReceipt,
            sampleID: latencySampleID,
            monotonicMilliseconds: MultiplayerGameKitTransport.monotonicMilliseconds(),
            frameSequence: nil
        )
        do {
            if recordEvidence {
                _ = try inputLedger.recordEvidence(input.sealedInput)
                try recordTerminalEvidence(input.sealedInput)
            }
            if terminalDrainState != nil
                || coordinatorEngine?.state.phase == .finished
            {
                try resolveInputWithoutCanonicalEvent(
                    input,
                    reason: .finished,
                    logicalMilliseconds: currentLogicalMilliseconds()
                )
                attemptTerminalCompletion()
                return
            }
            if playbackReducer?.state.players.first(where: {
                $0.seat == input.seat
            })?.lives == 0 {
                let playerOutAt = transcriptEvents.reversed().compactMap {
                    event -> Int? in
                    guard case .playerOut(_, let at, let seat) = event,
                        seat == input.seat
                    else { return nil }
                    return at
                }.first
                guard let playerOutAt,
                    input.coordinatorInputMilliseconds >= playerOutAt
                else {
                    throw MultiplayerControllerError.lateEvidenceBeforePlayerOut
                }
                try resolveInputWithoutCanonicalEvent(
                    input,
                    reason: .eliminated,
                    logicalMilliseconds: currentLogicalMilliseconds()
                )
                return
            }
            guard var inputFrontier else {
                throw MultiplayerControllerError.liveStateUnavailable
            }
            _ = try inputFrontier.recordInput(input.sealedInput)
            self.inputFrontier = inputFrontier
            inputReceivedAtByID[input.id] = min(
                inputReceivedAtByID[input.id] ?? Int.max,
                max(receivedAt, input.coordinatorInputMilliseconds)
            )
            processCoordinatorFrame(
                logicalMilliseconds: currentLogicalMilliseconds()
            )
        } catch {
            peerConsistencyIntact = false
            failLiveMatch(error.localizedDescription)
        }
    }

    private func recordInputEvidence(
        _ input: MultiplayerInputPacket,
        expectedSeat: Int
    ) {
        let maximumAcceptedInputAt = MultiplayerInputAdmissionPolicy.maximumAcceptedInputAt(
            currentLogicalMilliseconds: currentLogicalMilliseconds(),
            isPausedForRecovery: pausedAtLogicalMilliseconds != nil,
            recoveryLimitMilliseconds:
                fastNetworkPolicy?.evidenceRecoveryMilliseconds ?? 15_000
        )
        guard input.seat == expectedSeat,
            input.coordinatorInputMilliseconds >= 0,
            input.coordinatorInputMilliseconds <= maximumAcceptedInputAt
        else {
            peerConsistencyIntact = false
            return
        }
        do {
            _ = try inputLedger.recordEvidence(input.sealedInput)
            try recordTerminalEvidence(input.sealedInput)
            drainPendingRecoverySnapshot()
            attemptTerminalCompletion()
        } catch {
            peerConsistencyIntact = false
            failLiveMatch(error.localizedDescription)
        }
    }

    private func recordInputSeal(_ seal: MultiplayerInputSeal) {
        do {
            guard var inputFrontier else {
                throw MultiplayerControllerError.liveStateUnavailable
            }
            try inputFrontier.recordSeal(seal)
            self.inputFrontier = inputFrontier
            processCoordinatorFrame(
                logicalMilliseconds: currentLogicalMilliseconds()
            )
        } catch {
            peerConsistencyIntact = false
            failLiveMatch(error.localizedDescription)
        }
    }

    private func recordInputResolution(_ resolution: MultiplayerInputResolution) {
        do {
            try recordInputResolutionThrowing(resolution)
        } catch {
            peerConsistencyIntact = false
            failLiveMatch(error.localizedDescription)
        }
    }

    private func recordInputResolutionThrowing(
        _ resolution: MultiplayerInputResolution
    ) throws {
        _ = try inputLedger.recordResolution(resolution)
        let latencySampleID =
            latencySampleByInputID[resolution.inputID]
            ?? MultiplayerLatencySampleID()
        latencySampleByInputID[resolution.inputID] = latencySampleID
        latencyRecorder.record(
            .disposition,
            sampleID: latencySampleID,
            monotonicMilliseconds: MultiplayerGameKitTransport.monotonicMilliseconds(),
            frameSequence: nil
        )
        switch resolution.disposition {
        case .committed(let eventSequence):
            latencySampleByEventSequence[eventSequence] = latencySampleID
            if let location = localTouchLocationByInputID.removeValue(
                forKey: resolution.inputID
            ) {
                localTouchLocationByEventSequence[eventSequence] = location
            }
        case .ignored:
            latencySampleByInputID.removeValue(forKey: resolution.inputID)
            localTouchLocationByInputID.removeValue(forKey: resolution.inputID)
            latencyCorrelation.finish(inputID: resolution.inputID)
        }
        if resolution.inputID.seat == localSeat {
            _ = localPrediction.receive(resolution)
            if case .ignored = resolution.disposition {
                resolutionWatchdog.resolve(resolution.inputID)
            }
            updateLivePresentation(at: currentLogicalMilliseconds())
        }
        drainPendingRecoverySnapshot()
        attemptTerminalCompletion()
    }

    private func emitLocalInputSeal(logicalMilliseconds: Int) {
        guard
            let emission = localSealEmitter.next(
                seat: localSeat,
                highestInputSequence: localPrediction.nextInputSequence - 1,
                logicalMilliseconds: logicalMilliseconds
            )
        else { return }
        if transport.isCoordinator {
            recordInputSeal(emission.seal)
        }
        do {
            try transport.sendInputSeal(
                emission.seal,
                logicalMatchMilliseconds: logicalMilliseconds,
                includesReliableCheckpoint: emission.includesReliableCheckpoint
            )
        } catch {
            // A later seal or reliable checkpoint supersedes this send.
        }
    }

    private func recordTerminalEvidence(
        _ evidence: MultiplayerSealedInput
    ) throws {
        guard var tracker = terminalDrainTracker else {
            throw MultiplayerControllerError.liveStateUnavailable
        }
        try tracker.recordEvidence(evidence)
        terminalDrainTracker = tracker
    }

    private func recordTerminalInputSeal(_ seal: MultiplayerInputSeal) {
        do {
            guard var tracker = terminalDrainTracker else {
                throw MultiplayerControllerError.liveStateUnavailable
            }
            try tracker.recordTerminalSeal(seal)
            terminalDrainTracker = tracker
            attemptTerminalCompletion()
        } catch {
            peerConsistencyIntact = false
            cancelLiveWithoutSettlement(
                reason: .inputReconciliationFailed,
                message: error.localizedDescription
            )
        }
    }

    private func resolveInputWithoutCanonicalEvent(
        _ input: MultiplayerInputPacket,
        reason: MultiplayerIgnoredInputReason,
        logicalMilliseconds: Int
    ) throws {
        let resolution = MultiplayerInputResolution(
            inputID: input.id,
            disposition: .ignored(reason)
        )
        try recordInputResolutionThrowing(resolution)
        do {
            try transport.sendInputResolution(
                resolution,
                logicalMatchMilliseconds: logicalMilliseconds
            )
        } catch {
            // The immutable resolution journal retries this exact disposition.
        }
    }

    private func emitTerminalInputSealIfNeeded(
        logicalMilliseconds: Int
    ) {
        guard !didSendTerminalInputSeal,
            let state = terminalDrainState
        else { return }
        if transport.isCoordinator {
            recordTerminalInputSeal(state.localSeal)
            didSendTerminalInputSeal = true
            return
        }
        do {
            try transport.sendTerminalInputSeal(
                state.localSeal,
                logicalMatchMilliseconds: max(
                    logicalMilliseconds,
                    state.localSeal.throughInputAt
                )
            )
            didSendTerminalInputSeal = true
        } catch {
            // Retained terminal evidence is retried on subsequent frames.
        }
    }

    private func processResolutionWatchdog() {
        guard let fastNetworkPolicy else { return }
        switch resolutionWatchdog.action(
            monotonicMilliseconds: MultiplayerGameKitTransport.monotonicMilliseconds(),
            noticeAfterMilliseconds: fastNetworkPolicy.frontierStalenessMilliseconds,
            cancelAfterMilliseconds: fastNetworkPolicy.evidenceRecoveryMilliseconds
        ) {
        case .none:
            break
        case .requestSnapshot:
            if !transport.isCoordinator {
                try? transport.requestSnapshot(
                    afterEventSequence: transcriptEvents.count,
                    logicalMatchMilliseconds: currentLogicalMilliseconds()
                )
            }
        case .cancelWithoutSettlement:
            peerConsistencyIntact = false
            cancelLiveWithoutSettlement(
                reason: .inputReconciliationFailed,
                message: "Input reconciliation exceeded the supported network budget."
            )
        }
    }

    private func processCoordinatorFrame(logicalMilliseconds: Int) {
        guard let engine = coordinatorEngine,
            let fastNetworkPolicy,
            MultiplayerCoordinatorFramePolicy.shouldProcess(
                phase: engine.state.phase,
                isPaused: pausedAtLogicalMilliseconds != nil
            )
        else { return }
        flushPendingCoordinatorTransportOutput(
            logicalMilliseconds: logicalMilliseconds
        )
        if enforceCoordinatorSendRecoveryDeadline(policy: fastNetworkPolicy) {
            return
        }
        guard pendingCoordinatorEvents.isEmpty,
            pendingCoordinatorPlans.isEmpty,
            pendingCoordinatorCancellations.isEmpty,
            var inputFrontier,
            engine.state.phase == .running
        else { return }
        let publishWatermark = inputFrontier.publishWatermark
        let hasDeclaredGap = !inputFrontier.missingInputIDs.isEmpty
        let frontierIsStale =
            publishWatermark.map {
                logicalMilliseconds - $0
                    > fastNetworkPolicy.frontierStalenessMilliseconds
            } ?? (logicalMilliseconds > fastNetworkPolicy.frontierStalenessMilliseconds)
        if hasDeclaredGap || frontierIsStale {
            let monotonic = MultiplayerGameKitTransport.monotonicMilliseconds()
            let began =
                frontierRecoveryBeganAtMonotonicMilliseconds
                ?? (frontierIsStale && !hasDeclaredGap
                    ? monotonic - fastNetworkPolicy.frontierStalenessMilliseconds
                    : monotonic)
            frontierRecoveryBeganAtMonotonicMilliseconds = began
            if MultiplayerRecoveryWindow.phase(
                now: monotonic,
                beganAt: began,
                noticeAfterMilliseconds: fastNetworkPolicy.frontierStalenessMilliseconds,
                cancelAfterMilliseconds: fastNetworkPolicy.evidenceRecoveryMilliseconds
            ) == .expired {
                peerConsistencyIntact = false
                cancelLiveWithoutSettlement(
                    reason: .frontierRecoveryExceeded,
                    message: "The sealed input frontier could not be recovered in time."
                )
                return
            }
        } else if frontierRecoveryBeganAtMonotonicMilliseconds != nil {
            frontierRecoveryBeganAtMonotonicMilliseconds = nil
        }
        guard let publishWatermark else {
            self.inputFrontier = inputFrontier
            return
        }
        let watermark = max(
            engine.clockMilliseconds,
            min(logicalMilliseconds, publishWatermark)
        )
        let readyInputs = inputFrontier.takeReadyInputs(through: watermark)
        self.inputFrontier = inputFrontier

        var events: [MultiplayerEvent] = []
        var plans: [MultiplayerActivationPlan] = []
        var cancellations: [Int] = []
        var resolutions: [MultiplayerInputResolution] = []
        do {
            for input in readyInputs {
                guard MultiplayerCoordinatorFramePolicy.shouldAdvance(engine.state.phase)
                else {
                    resolutions.append(
                        MultiplayerInputResolution(
                            inputID: input.id,
                            disposition: .ignored(.finished)
                        )
                    )
                    continue
                }
                let handledAt = MultiplayerCoordinatorFramePolicy.handledAt(
                    inputAt: input.inputAt,
                    receivedAt: inputReceivedAtByID[input.id] ?? input.inputAt,
                    engineClock: engine.clockMilliseconds,
                    watermark: watermark
                )
                let output = try engine.handleTap(
                    seat: input.id.seat,
                    cell: input.cell,
                    inputAt: input.inputAt,
                    handledAt: handledAt
                )
                resolutions.append(
                    try MultiplayerCoordinatorResolutionPolicy.resolution(
                        inputID: input.id,
                        input: input,
                        result: output
                    )
                )
                events.append(contentsOf: output.committedEvents)
                plans.append(contentsOf: output.plannedActivations)
                cancellations.append(contentsOf: output.cancelledPlanIds)
            }
            if MultiplayerCoordinatorFramePolicy.shouldAdvance(engine.state.phase) {
                let advance = try engine.advance(to: watermark)
                events.append(contentsOf: advance.committedEvents)
                plans.append(contentsOf: advance.plannedActivations)
                cancellations.append(contentsOf: advance.cancelledPlanIds)
            }
            emitCoordinatorOutput(
                events: events,
                plans: plans,
                cancellations: cancellations,
                resolutions: resolutions,
                logicalMilliseconds: max(watermark, engine.clockMilliseconds)
            )
        } catch {
            failLiveMatch(error.localizedDescription)
        }
    }

    private func emitCoordinatorOutput(
        events: [MultiplayerEvent],
        plans: [MultiplayerActivationPlan],
        cancellations: [Int],
        resolutions: [MultiplayerInputResolution],
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

        let uniqueCancellations = Set(cancellations)
        let visibleCancellations = uniqueCancellations.intersection(sentPlanIDs)
        if !uniqueCancellations.isEmpty {
            pendingCoordinatorCancellations.formUnion(visibleCancellations)
            for planID in uniqueCancellations {
                sentPlanIDs.remove(planID)
                pendingPlans.removeValue(forKey: planID)
                pendingCoordinatorPlans.remove(planIDs: [planID])
            }
            flushPendingCoordinatorTransportOutput(
                logicalMilliseconds: logicalMilliseconds
            )
        }

        for resolution in resolutions {
            do {
                try recordInputResolutionThrowing(resolution)
            } catch {
                peerConsistencyIntact = false
                failLiveMatch(error.localizedDescription)
                return
            }
            do {
                try transport.sendInputResolution(
                    resolution,
                    logicalMatchMilliseconds: logicalMilliseconds
                )
            } catch {
                // The immutable resolution journal retries this exact disposition.
            }
        }

        guard !events.isEmpty else { return }
        pendingCoordinatorEvents.append(contentsOf: events)
        flushPendingCoordinatorTransportOutput(
            logicalMilliseconds: logicalMilliseconds
        )
    }

    private func publishCoordinatorPlans(
        _ plans: some Sequence<MultiplayerActivationPlan>,
        logicalMilliseconds: Int
    ) {
        let wire = plans.map(Self.wirePlan)
        guard !wire.isEmpty else { return }
        for plan in wire {
            pendingCoordinatorPlans.enqueue(
                plan,
                logicalMilliseconds: logicalMilliseconds
            )
        }
        flushPendingCoordinatorTransportOutput(
            logicalMilliseconds: logicalMilliseconds
        )
    }

    private func flushPendingCoordinatorTransportOutput(
        logicalMilliseconds: Int
    ) {
        if let batch = pendingCoordinatorPlans.nextBatch() {
            do {
                try transport.sendActivationPlans(
                    batch.plans,
                    logicalMatchMilliseconds: batch.queuedAt
                )
                pendingCoordinatorPlans.remove(planIDs: batch.plans.map(\.planId))
                for plan in batch.plans {
                    pendingPlans[plan.planId] = plan
                    sentPlanIDs.insert(plan.planId)
                }
            } catch {
                beginCoordinatorSendRecoveryIfNeeded()
                return
            }
        }

        if !pendingCoordinatorCancellations.isEmpty {
            let cancellations = pendingCoordinatorCancellations.sorted()
            do {
                try transport.cancelActivationPlans(
                    cancellations,
                    logicalMatchMilliseconds: logicalMilliseconds
                )
                pendingCoordinatorCancellations.subtract(cancellations)
            } catch {
                beginCoordinatorSendRecoveryIfNeeded()
                return
            }
        }

        if !pendingCoordinatorEvents.isEmpty {
            let events = pendingCoordinatorEvents
            do {
                try transport.broadcastEvents(
                    events.map(\.integerTuple),
                    logicalMatchMilliseconds: logicalMilliseconds
                )
                pendingCoordinatorEvents = []
                let commitTimestamp = MultiplayerGameKitTransport.monotonicMilliseconds()
                for event in events {
                    guard let sampleID = latencySampleByEventSequence[event.sequence] else {
                        continue
                    }
                    latencyRecorder.record(
                        .canonicalCommit,
                        sampleID: sampleID,
                        monotonicMilliseconds: commitTimestamp,
                        frameSequence: nil
                    )
                }
                applyCanonicalEvents(events)
            } catch {
                beginCoordinatorSendRecoveryIfNeeded()
                return
            }
        }

        if pendingCoordinatorEvents.isEmpty,
            pendingCoordinatorPlans.isEmpty,
            pendingCoordinatorCancellations.isEmpty
        {
            coordinatorSendRecoveryBeganAtMonotonicMilliseconds = nil
        }
    }

    private func beginCoordinatorSendRecoveryIfNeeded() {
        if coordinatorSendRecoveryBeganAtMonotonicMilliseconds == nil {
            coordinatorSendRecoveryBeganAtMonotonicMilliseconds =
                MultiplayerGameKitTransport.monotonicMilliseconds()
        }
        beginCoordinatedPause()
    }

    @discardableResult
    private func enforceCoordinatorSendRecoveryDeadline(
        policy: MultiplayerFrozenNetworkPolicy
    ) -> Bool {
        guard let began = coordinatorSendRecoveryBeganAtMonotonicMilliseconds else {
            return false
        }
        guard
            MultiplayerRecoveryWindow.phase(
                now: MultiplayerGameKitTransport.monotonicMilliseconds(),
                beganAt: began,
                noticeAfterMilliseconds: policy.frontierStalenessMilliseconds,
                cancelAfterMilliseconds: policy.evidenceRecoveryMilliseconds
            ) == .expired
        else { return false }
        peerConsistencyIntact = false
        cancelLiveWithoutSettlement(
            reason: .inputReconciliationFailed,
            message: "Canonical delivery could not recover in time."
        )
        return true
    }

    private func refreshReliableRecoveryState() {
        reliableRecoveryBeganAtMonotonicMilliseconds =
            transport.oldestPendingReliableRecoveryMonotonicMilliseconds
    }

    private func refreshPeerCanonicalRecoveryState() {
        if MultiplayerPeerCanonicalRecoveryPolicy.isRequired(
            pendingBatchCount: pendingCanonicalBatches.count,
            hasPendingSnapshot: pendingRecoverySnapshot != nil,
            isSnapshotAssemblyPending: snapshotAssembler.isPending,
            pendingFinishEventSequence: pendingFinishPacket?.finalEventSequence,
            transcriptEventCount: transcriptEvents.count
        ) {
            if peerCanonicalRecoveryBeganAtMonotonicMilliseconds == nil {
                peerCanonicalRecoveryBeganAtMonotonicMilliseconds =
                    MultiplayerGameKitTransport.monotonicMilliseconds()
            }
        } else {
            peerCanonicalRecoveryBeganAtMonotonicMilliseconds = nil
            if !resolutionWatchdog.isCatchingUp {
                lastSnapshotRequestAtMonotonicMilliseconds = nil
            }
        }
    }

    private func servicePeerSnapshotRecoveryIfNeeded(
        logicalMilliseconds: Int
    ) {
        let now = MultiplayerGameKitTransport.monotonicMilliseconds()
        guard
            MultiplayerSnapshotRecoveryRequestPolicy.shouldRequest(
                isCoordinator: transport.isCoordinator,
                hasPeerCanonicalRecovery:
                    peerCanonicalRecoveryBeganAtMonotonicMilliseconds != nil,
                hasResolutionRecovery: resolutionWatchdog.isCatchingUp,
                now: now,
                lastRequestAt: lastSnapshotRequestAtMonotonicMilliseconds
            )
        else { return }
        lastSnapshotRequestAtMonotonicMilliseconds = now
        try? transport.requestSnapshot(
            afterEventSequence: transcriptEvents.count,
            logicalMatchMilliseconds: logicalMilliseconds
        )
    }

    private func serviceCoordinatorReconnectSnapshotsIfPossible(
        logicalMilliseconds: Int
    ) {
        guard
            MultiplayerReconnectSnapshotPolicy.shouldSend(
                isCoordinator: transport.isCoordinator,
                hasPendingResumeRecovery: transport.hasPendingResumeRecovery
            )
        else { return }
        for playerID in pendingReconnectSnapshotRecipients.sorted() {
            do {
                try transport.sendSnapshot(
                    events: transcriptEvents.map(\.integerTuple),
                    pendingPlans: Array(pendingPlans.values),
                    afterEventSequence: 0,
                    logicalMatchMilliseconds: logicalMilliseconds,
                    to: playerID
                )
                pendingReconnectSnapshotRecipients.remove(playerID)
            } catch {
                return
            }
        }
    }

    @discardableResult
    private func enforceBoundedRecoveryDeadlines() -> Bool {
        guard let fastNetworkPolicy else { return false }
        if enforceCoordinatorSendRecoveryDeadline(policy: fastNetworkPolicy) {
            return true
        }
        let now = MultiplayerGameKitTransport.monotonicMilliseconds()
        let expiredMessage = MultiplayerRecoveryDeadlinePolicy.firstExpiredMessage(
            now: now,
            noticeAfterMilliseconds: fastNetworkPolicy.frontierStalenessMilliseconds,
            cancelAfterMilliseconds: fastNetworkPolicy.evidenceRecoveryMilliseconds,
            recoveries: [
                (
                    beganAt: reliableRecoveryBeganAtMonotonicMilliseconds,
                    message: "Reliable multiplayer delivery could not recover in time."
                ),
                (
                    beganAt: peerCanonicalRecoveryBeganAtMonotonicMilliseconds,
                    message: "Peer input evidence could not recover in time."
                ),
                (
                    beganAt: pauseRecoveryBeganAtMonotonicMilliseconds,
                    message: "The coordinated pause could not recover in time."
                ),
            ]
        )
        guard let expiredMessage else { return false }
        peerConsistencyIntact = false
        cancelLiveWithoutSettlement(
            reason: .inputReconciliationFailed,
            message: expiredMessage
        )
        return true
    }

    private func applyCanonicalTuples(_ tuples: [[Int]]) {
        do {
            let events = try tuples.map(MultiplayerEvent.init(integerTuple:))
            guard !events.isEmpty else { return }
            if transport.isCoordinator {
                try applyCanonicalEventsThrowing(events)
            } else {
                pendingCanonicalBatches =
                    try MultiplayerCanonicalBatchReconciler.inserting(
                        events,
                        into: pendingCanonicalBatches,
                        after: transcriptEvents
                    )
                drainPendingCanonicalBatches()
            }
        } catch {
            peerConsistencyIntact = false
            failLiveMatch("The coordinator sent invalid canonical input evidence.")
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
        defer { refreshPeerCanonicalRecoveryState() }
        while let events = pendingCanonicalBatches[transcriptEvents.count + 1] {
            do {
                guard try consumeInputEvidence(for: events) else { return }
                pendingCanonicalBatches.removeValue(forKey: transcriptEvents.count + 1)
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

    private func consumeInputEvidence(
        for events: [MultiplayerEvent]
    ) throws -> Bool {
        try inputLedger.consume(events: events)
    }

    private func applyCanonicalEventsThrowing(
        _ events: [MultiplayerEvent],
        playsFeedback: Bool = true,
        consumesEvidence: Bool = true
    ) throws {
        guard let reducer = playbackReducer else {
            throw MultiplayerControllerError.liveStateUnavailable
        }
        if consumesEvidence, try consumeInputEvidence(for: events) == false {
            throw MultiplayerControllerError.missingPeerInputEvidence
        }
        for event in events {
            guard event.sequence == transcriptEvents.count + 1 else {
                throw MultiplayerControllerError.noncontiguousTranscript
            }
            let targetBefore = reducer.state.target
            let localScoreBefore =
                reducer.state.players.first(where: {
                    $0.seat == localSeat
                })?.score ?? 0
            try reducer.apply(event)
            transcriptEvents.append(event)
            if let sampleID = latencySampleByEventSequence.removeValue(
                forKey: event.sequence
            ) {
                latencyRecorder.record(
                    .canonicalApplication,
                    sampleID: sampleID,
                    monotonicMilliseconds:
                        MultiplayerGameKitTransport.monotonicMilliseconds(),
                    frameSequence: nil
                )
                let completedInputIDs = latencySampleByInputID.compactMap {
                    $0.value == sampleID ? $0.key : nil
                }
                for inputID in completedInputIDs {
                    latencySampleByInputID.removeValue(forKey: inputID)
                    latencyCorrelation.finish(inputID: inputID)
                }
            }
            if let resolvedInputID = localPrediction.takeCanonicalAppliedInputID(
                eventSequence: event.sequence
            ) {
                resolutionWatchdog.resolve(resolvedInputID)
            }
            if case .playerOut(_, _, let seat) = event,
                var inputFrontier
            {
                try inputFrontier.removeSeatAfterPlayerOut(seat)
                self.inputFrontier = inputFrontier
            }
            removeCommittedPlan(for: event)
            if playsFeedback {
                playFeedback(
                    for: event,
                    targetBefore: targetBefore,
                    state: reducer.state,
                    localScoreBefore: localScoreBefore,
                    normalizedLocation: localTouchLocationByEventSequence.removeValue(
                        forKey: event.sequence
                    )
                )
            }
        }
        updateLivePresentation(at: currentLogicalMilliseconds())
        if reducer.state.phase == .finished {
            beginTerminalDrain()
        }
    }

    private func receiveSnapshotChunk(_ snapshot: MultiplayerSnapshotPacket) {
        do {
            if let assembled = try snapshotAssembler.ingest(snapshot) {
                applySnapshot(assembled)
            }
            refreshPeerCanonicalRecoveryState()
        } catch {
            peerConsistencyIntact = false
            failLiveMatch(error.localizedDescription)
        }
    }

    private func applySnapshot(_ snapshot: MultiplayerSnapshotPacket) {
        defer { refreshPeerCanonicalRecoveryState() }
        do {
            let events = try MultiplayerSnapshotTranscriptReconciler.unappliedEvents(
                from: snapshot.events,
                after: transcriptEvents
            )
            if try consumeInputEvidence(for: events) == false {
                pendingRecoverySnapshot = snapshot
                return
            }
            pendingRecoverySnapshot = nil
            try applyCanonicalEventsThrowing(
                events,
                playsFeedback: false,
                consumesEvidence: false
            )
            try prunePendingCanonicalBatchesCoveredBySnapshot()
            if MultiplayerSnapshotMetadataPolicy.shouldCommitInController(
                snapshotThroughEventSequence: snapshot.throughEventSequence,
                transcriptEventCount: transcriptEvents.count,
                snapshotControlWatermark: snapshot.controlWatermark,
                latestMetadataControlSequence: latestPlanMetadataControlSequence
            ) {
                pendingPlans = Dictionary(
                    uniqueKeysWithValues: snapshot.pendingPlans.map { ($0.planId, $0) }
                )
            }
            if MultiplayerSnapshotMetadataPolicy.shouldCommitInController(
                snapshotThroughEventSequence: snapshot.throughEventSequence,
                transcriptEventCount: transcriptEvents.count,
                snapshotControlWatermark: snapshot.controlWatermark,
                latestMetadataControlSequence: latestPauseMetadataControlSequence
            ) {
                pausedAtLogicalMilliseconds = snapshot.pausedAtLogicalMilliseconds
                pauseRecoveryBeganAtMonotonicMilliseconds =
                    MultiplayerPauseRecoveryAnchorPolicy.applyingSnapshot(
                        pausedAtLogicalMilliseconds: snapshot.pausedAtLogicalMilliseconds,
                        existingAnchor: pauseRecoveryBeganAtMonotonicMilliseconds,
                        now: MultiplayerGameKitTransport.monotonicMilliseconds()
                    )
            }
        } catch {
            peerConsistencyIntact = false
            failLiveMatch(error.localizedDescription)
        }
        updateRecoveryPresentation()
    }

    private func prunePendingCanonicalBatchesCoveredBySnapshot() throws {
        pendingCanonicalBatches =
            try MultiplayerCanonicalBatchReconciler
            .retainingUnapplied(
                pendingCanonicalBatches,
                after: transcriptEvents
            )
        drainPendingCanonicalBatches()
    }

    private func drainPendingRecoverySnapshot() {
        guard let snapshot = pendingRecoverySnapshot else { return }
        pendingRecoverySnapshot = nil
        applySnapshot(snapshot)
    }

    private func playFeedback(
        for event: MultiplayerEvent,
        targetBefore: MultiplayerTargetState?,
        state: MultiplayerLiveState,
        localScoreBefore: Int,
        normalizedLocation: CGPoint?
    ) {
        switch event {
        case .hit(_, _, _, let seat, _, _):
            audio.playTap(hitNumber: max(1, state.totalHits))
            guard seat == localSeat,
                let targetBefore,
                let normalizedLocation,
                let localScoreAfter = state.players.first(where: {
                    $0.seat == localSeat
                })?.score,
                let feedback = MultiplayerHitFeedbackPresentation.make(
                    event: event,
                    targetPresentedAt: targetBefore.presentedAt,
                    localSeat: localSeat,
                    scoreBefore: localScoreBefore,
                    scoreAfter: localScoreAfter,
                    normalizedLocation: normalizedLocation
                )
            else { return }
            currentHitFeedbackEvent = feedback
            updateLivePresentation(at: currentLogicalMilliseconds())
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
        var targetCandidates: [MultiplayerPresentedTargetCandidate] = []
        if let target = reducer.state.target,
            logicalMilliseconds >= target.presentedAt,
            logicalMilliseconds < target.deadline
        {
            targetCandidates.append(
                MultiplayerPresentedTargetCandidate(
                    activationID: MultiplayerPresentedActivationID(
                        kind: .target,
                        entityID: target.targetId
                    ),
                    presentedAt: target.presentedAt,
                    cell: target.cell,
                    colorIndex: target.colorIndex,
                    ownerSeat: target.ownerSeat
                )
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
                isDecoy: true,
                activationID: MultiplayerPresentedActivationID(
                    kind: .decoy,
                    entityID: decoy.decoyId
                )
            )
        }
        for plan in pendingPlans.values
        where logicalMilliseconds >= plan.at
            && (plan.lifetimeMs.map { logicalMilliseconds < plan.at + $0 } ?? true)
        {
            let activationID = MultiplayerPresentedActivationID(
                kind: plan.kind == .target ? .target : .decoy,
                entityID: plan.entityId
            )
            if plan.kind == .target {
                targetCandidates.append(
                    MultiplayerPresentedTargetCandidate(
                        activationID: activationID,
                        presentedAt: plan.at,
                        cell: plan.cell,
                        colorIndex: plan.colorIndex,
                        ownerSeat: plan.ownerSeat
                    )
                )
            } else if cells[plan.cell] == nil {
                cells[plan.cell] = MultiplayerPresentation.Cell(
                    id: plan.cell,
                    colorIndex: plan.colorIndex,
                    ownerSeat: plan.ownerSeat,
                    glyph: Self.glyph(for: plan.colorIndex),
                    isDecoy: true,
                    activationID: activationID
                )
            }
        }
        let presentedTarget = MultiplayerPresentedTargetSelection.latest(
            in: targetCandidates
        )
        let presentedTargetActivationID = presentedTarget?.activationID
        if let presentedTarget,
            !localPrediction.hidesTarget(for: presentedTarget.activationID)
        {
            cells[presentedTarget.cell] = MultiplayerPresentation.Cell(
                id: presentedTarget.cell,
                colorIndex: presentedTarget.colorIndex,
                ownerSeat: presentedTarget.ownerSeat,
                glyph: Self.glyph(for: presentedTarget.colorIndex),
                isTarget: true,
                activationID: presentedTarget.activationID
            )
        }
        if let presentedTargetActivationID,
            case .neutralPressure(let pendingCell) = localPrediction.overlay(
                for: presentedTargetActivationID
            )
        {
            let existing =
                cells[pendingCell]
                ?? MultiplayerPresentation.Cell(id: pendingCell, colorIndex: nil)
            cells[pendingCell] = MultiplayerPresentation.Cell(
                id: existing.id,
                colorIndex: existing.colorIndex,
                ownerSeat: existing.ownerSeat,
                glyph: existing.glyph,
                isTarget: existing.isTarget,
                isDecoy: existing.isDecoy,
                activationID: existing.activationID,
                isPendingLocalInput: true
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
        let monotonic = MultiplayerGameKitTransport.monotonicMilliseconds()
        let frontierIsVisible =
            frontierRecoveryBeganAtMonotonicMilliseconds.map {
                began in
                guard let fastNetworkPolicy else { return false }
                return MultiplayerRecoveryWindow.phase(
                    now: monotonic,
                    beganAt: began,
                    noticeAfterMilliseconds: fastNetworkPolicy.frontierStalenessMilliseconds,
                    cancelAfterMilliseconds: fastNetworkPolicy.evidenceRecoveryMilliseconds
                ) == .visible
            } ?? false
        let coordinatorSendRecoveryIsVisible =
            coordinatorSendRecoveryBeganAtMonotonicMilliseconds.map { began in
                guard let fastNetworkPolicy else { return false }
                return MultiplayerRecoveryWindow.phase(
                    now: monotonic,
                    beganAt: began,
                    noticeAfterMilliseconds: fastNetworkPolicy.frontierStalenessMilliseconds,
                    cancelAfterMilliseconds: fastNetworkPolicy.evidenceRecoveryMilliseconds
                ) == .visible
            } ?? false
        let reliableRecoveryIsVisible =
            reliableRecoveryBeganAtMonotonicMilliseconds.map { began in
                guard let fastNetworkPolicy else { return false }
                return MultiplayerRecoveryWindow.phase(
                    now: monotonic,
                    beganAt: began,
                    noticeAfterMilliseconds: fastNetworkPolicy.frontierStalenessMilliseconds,
                    cancelAfterMilliseconds: fastNetworkPolicy.evidenceRecoveryMilliseconds
                ) == .visible
            } ?? false
        let peerCanonicalRecoveryIsVisible =
            peerCanonicalRecoveryBeganAtMonotonicMilliseconds.map { began in
                guard let fastNetworkPolicy else { return false }
                return MultiplayerRecoveryWindow.phase(
                    now: monotonic,
                    beganAt: began,
                    noticeAfterMilliseconds: fastNetworkPolicy.frontierStalenessMilliseconds,
                    cancelAfterMilliseconds: fastNetworkPolicy.evidenceRecoveryMilliseconds
                ) == .visible
            } ?? false
        let pauseRecoveryIsVisible =
            pauseRecoveryBeganAtMonotonicMilliseconds.map { began in
                guard let fastNetworkPolicy else { return false }
                return MultiplayerRecoveryWindow.phase(
                    now: monotonic,
                    beganAt: began,
                    noticeAfterMilliseconds: fastNetworkPolicy.frontierStalenessMilliseconds,
                    cancelAfterMilliseconds: fastNetworkPolicy.evidenceRecoveryMilliseconds
                ) == .visible
            } ?? false
        let interaction = MultiplayerLiveInteractionPolicy.resolve(
            localHasLives: (local?.lives ?? 0) > 0,
            isApplicationActive: isApplicationActive && !isTransportRecovering,
            hasDisconnectedPlayers: !disconnectedGamePlayerIDs.isEmpty,
            isPaused: pausedAtLogicalMilliseconds != nil,
            isTerminalDraining: terminalDrainState != nil,
            hasPendingInputForPresentedActivation: presentedTargetActivationID.map {
                !localPrediction.allowsInput(for: $0)
            } ?? false,
            isCatchUpVisible: frontierIsVisible
                || resolutionWatchdog.isCatchingUp
                || coordinatorSendRecoveryIsVisible
                || reliableRecoveryIsVisible
                || peerCanonicalRecoveryIsVisible
                || pauseRecoveryIsVisible
        )
        let candidate = MultiplayerPresentation.LiveMatchState(
            matchID: match.matchId,
            elapsedMilliseconds: logicalMilliseconds,
            cells: Array(cells.values),
            players: players,
            localSeat: localSeat,
            streakSteps: local?.streakProgress ?? 0,
            isRecovering: interaction.networkStatus != nil,
            networkStatus: interaction.networkStatus,
            announcement: currentAnnouncement
                ?? (local?.lives == 0 ? "SPECTATING" : nil),
            hitFeedbackEvent: currentHitFeedbackEvent,
            inputMode: interaction.inputMode
        )
        if MultiplayerPresentationPublicationPolicy.shouldPublish(
            previous: liveState,
            next: candidate
        ) {
            liveState = candidate
        }
    }

    private func removeCommittedPlan(for event: MultiplayerEvent) {
        guard let entity = Self.committedPlanEntity(event) else { return }
        let planIDs = pendingPlans.values
            .filter { Self.wirePlanEntity($0) == entity }
            .map(\.planId)
        for planID in planIDs {
            pendingPlans.removeValue(forKey: planID)
            pendingCoordinatorPlans.remove(planIDs: [planID])
            sentPlanIDs.remove(planID)
        }
    }

    private func beginTerminalDrain() {
        guard terminalDrainState == nil,
            let fastNetworkPolicy,
            let finishEvent = transcriptEvents.last,
            case .finish(let finishEventSequence, let finishAt) = finishEvent
        else {
            attemptTerminalCompletion()
            return
        }
        let throughInputAt = max(
            finishAt,
            currentLogicalMilliseconds(),
            localPrediction.latestPendingInputAt ?? 0
        )
        terminalDrainState = MultiplayerTerminalDrainState(
            finishEventSequence: finishEventSequence,
            deadlineMonotonicMilliseconds:
                MultiplayerGameKitTransport.monotonicMilliseconds()
                + fastNetworkPolicy.evidenceRecoveryMilliseconds,
            localSeal: MultiplayerInputSeal(
                seat: localSeat,
                throughInputAt: throughInputAt,
                highestInputSequence: localPrediction.nextInputSequence - 1
            )
        )
        updateLivePresentation(at: currentLogicalMilliseconds())
        emitTerminalInputSealIfNeeded(
            logicalMilliseconds: throughInputAt
        )
        attemptTerminalCompletion()
    }

    private func enforceTerminalDrainDeadline() {
        guard let state = terminalDrainState else { return }
        let now = MultiplayerGameKitTransport.monotonicMilliseconds()
        guard
            MultiplayerTerminalDrainDeadlinePolicy.hasExpired(
                now: now,
                deadline: state.deadlineMonotonicMilliseconds
            )
        else { return }
        if transport.isCoordinator {
            cancelLiveWithoutSettlement(
                reason: .terminalDrainExceeded,
                message: "Terminal input evidence did not reconcile in time."
            )
        } else {
            cancelLiveWithoutSettlement(
                reason: .terminalDrainExceeded,
                message: "The coordinator did not complete terminal reconciliation.",
                broadcastsToPeers: false
            )
        }
    }

    private func attemptTerminalCompletion() {
        guard phase == .live,
            let state = terminalDrainState,
            !didSubmitTranscript,
            peerConsistencyIntact,
            pendingCanonicalBatches.isEmpty,
            inputLedger.isTerminallyComplete,
            !localPrediction.hasPendingInputs,
            !resolutionWatchdog.hasPendingInputs,
            pendingCoordinatorEvents.isEmpty,
            pendingCoordinatorPlans.isEmpty,
            pendingCoordinatorCancellations.isEmpty,
            disconnectedGamePlayerIDs.isEmpty,
            !isTransportRecovering
        else { return }

        if transport.isCoordinator {
            guard terminalDrainTracker?.isComplete == true else { return }
            if !didBroadcastFinish {
                guard !transport.hasPendingReliableRecovery else { return }
                guard let manifest = coreManifest else { return }
                do {
                    try transport.sendFinish(
                        finalEventSequence: state.finishEventSequence,
                        manifestHash: manifest.manifestHash,
                        transcriptDigest: Self.transcriptDigest(transcriptEvents),
                        logicalMatchMilliseconds: currentLogicalMilliseconds()
                    )
                    didBroadcastFinish = true
                } catch {
                    return
                }
                return
            }
            guard !transport.hasPendingReliableRecovery else { return }
        } else {
            guard !transport.hasPendingReliableRecovery else { return }
            guard let finish = pendingFinishPacket else { return }
            guard finish.finalEventSequence == transcriptEvents.count,
                finish.finalEventSequence == state.finishEventSequence
            else {
                if finish.finalEventSequence > transcriptEvents.count {
                    try? transport.requestSnapshot(
                        afterEventSequence: transcriptEvents.count,
                        logicalMatchMilliseconds: currentLogicalMilliseconds()
                    )
                    return
                }
                cancelLiveWithoutSettlement(
                    reason: .inputReconciliationFailed,
                    message: "Peer finish sequence did not match the canonical transcript.",
                    broadcastsToPeers: false
                )
                return
            }
            guard finish.transcriptDigest == Self.transcriptDigest(transcriptEvents),
                finish.manifestHash == coreManifest?.manifestHash
            else {
                cancelLiveWithoutSettlement(
                    reason: .inputReconciliationFailed,
                    message: "Peer transcript digest mismatch.",
                    broadcastsToPeers: false
                )
                return
            }
        }

        guard terminalGate.authorizeSubmission(ifConsistent: true) else { return }
        completeLiveMatchSubmission()
    }

    private func completeLiveMatchSubmission() {
        guard phase == .live,
            !didSubmitTranscript,
            peerConsistencyIntact,
            let manifest = coreManifest,
            let match = currentMatch
        else { return }
        frameScheduler.stop()
        audio.setMusicContext(.menu)
        didSubmitTranscript = true
        phase = .results
        let pendingSubmission = PendingSubmission(
            matchID: match.matchId,
            manifestHash: manifest.manifestHash,
            transcript: MultiplayerTranscriptSubmission(
                matchId: match.matchId,
                events: transcriptEvents.map(\.integerTuple)
            ),
            participantCount: match.participants.count,
            createdAt: Date()
        )
        pendingSubmissionStore.save(pendingSubmission)
        settlementRecovery = MultiplayerPresentation.SettlementRecovery(
            pendingSubmission: pendingSubmission,
            participantCount: match.participants.count
        )
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
        submitPendingTranscript()
    }

    private func submitPendingTranscript(
        startsSettlementPolling: Bool = true
    ) {
        guard !isSubmittingTranscript,
            let recovery = settlementRecovery,
            recovery.shouldRetrySubmission,
            let pendingSubmission = recovery.pendingSubmission
        else { return }
        let matchID = pendingSubmission.matchID
        isSubmittingTranscript = true
        resultsState = MultiplayerPresentation.ResultsState(
            settlement: resultsState.settlement,
            results: resultsState.results,
            isRefreshing: true,
            localSubmissionAccepted: recovery.localSubmissionAccepted,
            message: "Submitting the retained peer-consistent transcript."
        )
        submissionTask?.cancel()
        submissionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if activeSettlementMatchID == matchID
                    || settlementRecovery?.isTerminal == true
                {
                    isSubmittingTranscript = false
                    submissionTask = nil
                }
            }
            do {
                let response = try await backend.submitMultiplayerTranscript(
                    matchID: matchID,
                    manifestHash: pendingSubmission.manifestHash,
                    transcript: pendingSubmission.transcript
                )
                guard !Task.isCancelled,
                    activeSettlementMatchID == matchID
                else { return }
                applySettlement(
                    response,
                    source: .submission,
                    matchID: matchID
                )
                if startsSettlementPolling,
                    settlementRecovery?.shouldPoll == true
                {
                    startSettlementPolling()
                }
            } catch {
                let failure =
                    "Submission unavailable · \(error.localizedDescription) "
                    + "Retrying automatically."
                if let backendError = error as? BackendError {
                    logMultiplayerError(
                        "transcript submission failed status=\(backendError.status) "
                            + "code=\(backendError.code ?? "none") "
                            + "message=\(backendError.message)"
                    )
                } else {
                    logMultiplayerError(
                        "transcript submission failed message=\(error.localizedDescription)"
                    )
                }
                guard !Task.isCancelled,
                    activeSettlementMatchID == matchID
                else { return }
                guard var recovery = settlementRecovery,
                    recovery.recordSubmissionResponseFailure(failure)
                else { return }
                settlementRecovery = recovery
                resultsState = MultiplayerPresentation.ResultsState(
                    settlement: recovery.settlement,
                    results: resultsState.results.isEmpty
                        ? provisionalResults()
                        : resultsState.results,
                    isRefreshing: false,
                    localSubmissionAccepted: recovery.localSubmissionAccepted,
                    message: recovery.message
                )
                if startsSettlementPolling, recovery.shouldPoll {
                    startSettlementPolling()
                }
            }
        }
    }

    private func handleFinishPacket(_ finish: MultiplayerFinishPacket) {
        guard phase == .live else { return }
        if let pendingFinishPacket,
            pendingFinishPacket != finish
        {
            cancelLiveWithoutSettlement(
                reason: .inputReconciliationFailed,
                message: "The coordinator sent conflicting finish evidence.",
                broadcastsToPeers: false
            )
            return
        }
        pendingFinishPacket = finish
        guard finish.finalEventSequence <= transcriptEvents.count else {
            try? transport.requestSnapshot(
                afterEventSequence: transcriptEvents.count,
                logicalMatchMilliseconds: currentLogicalMilliseconds()
            )
            return
        }
        attemptTerminalCompletion()
    }

    private func startSettlementPolling() {
        settlementTask?.cancel()
        guard let matchID = activeSettlementMatchID else { return }
        settlementTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1_500))
                guard let self,
                    phase == .results,
                    activeSettlementMatchID == matchID
                else { return }
                guard settlementRecovery?.shouldPoll == true else { return }
                if settlementRecovery?.shouldRetrySubmission == true,
                    !isSubmittingTranscript
                {
                    submitPendingTranscript(
                        startsSettlementPolling: false
                    )
                }
                do {
                    let response = try await backend.loadMultiplayerSettlement(matchID)
                    applySettlement(
                        response,
                        source: .settlement,
                        matchID: matchID
                    )
                    if settlementRecovery?.shouldPoll != true { return }
                } catch {
                    guard activeSettlementMatchID == matchID else { return }
                    guard var recovery = settlementRecovery,
                        recovery.recordSettlementResponseFailure(
                            error.localizedDescription
                        )
                    else { return }
                    settlementRecovery = recovery
                    resultsState = MultiplayerPresentation.ResultsState(
                        settlement: recovery.settlement,
                        results: resultsState.results,
                        isRefreshing: false,
                        localSubmissionAccepted: recovery.localSubmissionAccepted,
                        message: recovery.message
                    )
                }
            }
        }
    }

    private func applySettlement(
        _ response: MultiplayerSettlementResponse,
        source: MultiplayerPresentation.SettlementRecovery<PendingSubmission>.ResponseSource,
        matchID: String
    ) {
        guard activeSettlementMatchID == matchID,
            var recovery = settlementRecovery
        else { return }
        let previousSettlement = recovery.settlement
        let settlement: MultiplayerPresentation.SettlementState
        switch response.state {
        case "settled":
            settlement = .settled(
                leaderboardEligible: response.leaderboardEligible
            )
        case "review", "cancelled":
            settlement = .review(reason: response.reviewReason)
        default:
            let previousCounts =
                if case .collecting(let submitted, let total) = previousSettlement {
                    (submitted, total)
                } else {
                    (0, currentMatch?.participants.count ?? 2)
                }
            settlement = .collecting(
                submitted: response.submittedCount ?? previousCounts.0,
                total: response.participantCount
                    ?? previousCounts.1
            )
        }
        guard
            recovery.applyServerResponse(
                settlement: settlement,
                source: source
            )
        else { return }
        settlementRecovery = recovery
        if recovery.isTerminal {
            pendingSubmissionStore.clear()
        }
        let serverResults = response.results?.map(Self.presentedResult) ?? []
        let results =
            serverResults.isEmpty
            ? (resultsState.results.isEmpty ? provisionalResults() : resultsState.results)
            : serverResults
        resultsState = MultiplayerPresentation.ResultsState(
            settlement: recovery.settlement,
            results: results,
            isRefreshing: false,
            localSubmissionAccepted: recovery.localSubmissionAccepted,
            message: recovery.message
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
        guard
            MultiplayerCoordinatedPausePolicy.shouldBegin(
                isCoordinator: transport.isCoordinator,
                isAlreadyPaused: pausedAtLogicalMilliseconds != nil,
                isTerminalDraining: terminalDrainState != nil,
                didBroadcastFinish: didBroadcastFinish
            )
        else { return }
        let logical = currentLogicalMilliseconds()
        pauseID += 1
        pausedAtLogicalMilliseconds = logical
        pauseRecoveryBeganAtMonotonicMilliseconds =
            MultiplayerGameKitTransport.monotonicMilliseconds()
        do {
            try transport.sendPause(
                pauseID: pauseID,
                logicalMatchMilliseconds: logical
            )
        } catch {
            // The pause is retained by the transport and retried on reconnect.
        }
    }

    private func resumeCoordinatedPause() {
        guard transport.isCoordinator,
            let pausedAtLogicalMilliseconds,
            pendingCoordinatorEvents.isEmpty,
            pendingCoordinatorPlans.isEmpty,
            pendingCoordinatorCancellations.isEmpty
        else { return }
        if transport.hasPendingResumeRecovery { return }
        if !transport.hasActivePause {
            self.pausedAtLogicalMilliseconds = nil
            pauseRecoveryBeganAtMonotonicMilliseconds = nil
            updateRecoveryPresentation()
            return
        }
        do {
            try transport.sendResume(
                pauseID: pauseID,
                logicalMatchMilliseconds: pausedAtLogicalMilliseconds
            )
            if !transport.hasPendingResumeRecovery,
                !transport.hasActivePause
            {
                self.pausedAtLogicalMilliseconds = nil
                pauseRecoveryBeganAtMonotonicMilliseconds = nil
                updateRecoveryPresentation()
            }
        } catch {
            // Stay paused and retry on the next display frame.
        }
    }

    private func markRecovering() {
        guard phase == .live else { return }
        updateLivePresentation(at: currentLogicalMilliseconds())
        guard recoveryTask == nil else { return }
        let generation = UUID()
        recoveryTaskGeneration = generation
        recoveryTask = Task { @MainActor [weak self] in
            defer {
                if self?.recoveryTaskGeneration == generation {
                    self?.recoveryTaskGeneration = nil
                    self?.recoveryTask = nil
                }
            }
            try? await Task.sleep(for: Self.recoveryGrace)
            guard let self, !Task.isCancelled,
                phase == .live,
                !disconnectedGamePlayerIDs.isEmpty
                    || !isApplicationActive
                    || pausedAtLogicalMilliseconds != nil
                    || isTransportRecovering
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
            pausedAtLogicalMilliseconds == nil,
            !isTransportRecovering
        {
            recoveryTaskGeneration = nil
            recoveryTask?.cancel()
            recoveryTask = nil
        }
        updateLivePresentation(at: currentLogicalMilliseconds())
    }

    private func failLiveMatch(_ message: String) {
        cancelLiveWithoutSettlement(
            reason: .inputReconciliationFailed,
            message: message
        )
    }

    private func cancelLiveWithoutSettlement(
        reason: MultiplayerTerminalCancelReason,
        message: String,
        broadcastsToPeers: Bool = true
    ) {
        guard phase == .live || phase == .waiting else { return }
        if phase == .live,
            broadcastsToPeers,
            transport.isCoordinator,
            transport.liveCompatibility == .unanimous
        {
            try? transport.sendTerminalCancel(
                reason: reason,
                throughEventSequence: transcriptEvents.count,
                logicalMatchMilliseconds: currentLogicalMilliseconds()
            )
        }
        frameScheduler.stop()
        audio.setMusicContext(.menu)
        submissionTask?.cancel()
        settlementTask?.cancel()
        recoveryTaskGeneration = nil
        recoveryTask?.cancel()
        submissionTask = nil
        settlementTask = nil
        recoveryTask = nil
        isSubmittingTranscript = false
        peerConsistencyIntact = false
        terminalGate.cancel()
        pendingFinishPacket = nil
        terminalDrainState = nil
        if pendingSubmissionStore.load()?.matchID == currentMatch?.matchId {
            pendingSubmissionStore.clear()
        }
        phase = .results
        settlementRecovery = nil
        resultsState = MultiplayerPresentation.ResultsState(
            settlement: .review(reason: message),
            results: provisionalResults(),
            isRefreshing: false,
            localSubmissionAccepted: false,
            message: "This match is not leaderboard eligible."
        )
        beginTerminalDeliveryRecoveryIfNeeded()
    }

    private func beginTerminalDeliveryRecoveryIfNeeded() {
        guard transport.hasPendingReliableRecovery else { return }
        terminalDeliveryTaskGeneration = nil
        terminalDeliveryTask?.cancel()
        let generation = UUID()
        terminalDeliveryTaskGeneration = generation
        terminalDeliveryTask = Task { @MainActor [weak self] in
            defer {
                if self?.terminalDeliveryTaskGeneration == generation {
                    self?.terminalDeliveryTaskGeneration = nil
                    self?.terminalDeliveryTask = nil
                }
            }
            let deadline = MultiplayerGameKitTransport.monotonicMilliseconds() + 15_000
            while let self, !Task.isCancelled,
                phase == .results,
                transport.hasPendingReliableRecovery,
                MultiplayerGameKitTransport.monotonicMilliseconds() < deadline
            {
                try? transport.serviceRecovery()
                try? await Task.sleep(
                    for: .milliseconds(
                        MultiplayerGameKitTransport.recoveryRetryIntervalMilliseconds
                    )
                )
            }
        }
    }

    private func resetMatchRuntime(disconnect: Bool) {
        pollTask?.cancel()
        frameScheduler.stop()
        settlementTask?.cancel()
        submissionTask?.cancel()
        terminalDeliveryTaskGeneration = nil
        terminalDeliveryTask?.cancel()
        recoveryTaskGeneration = nil
        recoveryTask?.cancel()
        announcementTask?.cancel()
        matchRuntimeGeneration &+= 1
        lobbySnapshotRevision &+= 1
        rosterConfirmationGeneration &+= 1
        waitingConnectionGeneration &+= 1
        matchmakingGeneration &+= 1
        matchmakingTask?.cancel()
        clockSynchronizationGeneration = nil
        clockSynchronizationTask?.cancel()
        pollTask = nil
        settlementTask = nil
        submissionTask = nil
        terminalDeliveryTask = nil
        recoveryTask = nil
        announcementTask = nil
        matchmakingTask = nil
        clockSynchronizationTask = nil
        matchmakingAttemptGate.clear()
        readyIntent.reset()
        isTransportRecovering = false
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
        didRejectIncompatibleLiveWire = false
        hasConfirmedRoster = false
        greatestRosterConfirmationCount = 0
        rosterConfirmationCounts = [:]
        didBeginLiveMatch = false
        didBroadcastStart = false
        didSubmitTranscript = false
        didBroadcastFinish = false
        localPrediction.reset()
        latencyCorrelation.reset()
        latencySampleByInputID = [:]
        latencySampleByEventSequence = [:]
        localTouchLocationByInputID = [:]
        localTouchLocationByEventSequence = [:]
        lastVisibleTargetActivationID = nil
        localSealEmitter.reset()
        resolutionWatchdog.reset()
        inputFrontier = nil
        inputReceivedAtByID = [:]
        inputLedger = MultiplayerInputLedger()
        terminalDrainTracker = nil
        terminalGate.reset()
        terminalDrainState = nil
        pendingFinishPacket = nil
        pendingStartManifest = nil
        didSendTerminalInputSeal = false
        pendingRecoverySnapshot = nil
        pendingReconnectSnapshotRecipients = []
        snapshotAssembler.reset()
        lastSnapshotRequestAtMonotonicMilliseconds = nil
        frontierRecoveryBeganAtMonotonicMilliseconds = nil
        fastNetworkPolicy = nil
        pendingCanonicalBatches = [:]
        pendingCoordinatorEvents = []
        pendingCoordinatorPlans.reset()
        pendingCoordinatorCancellations = []
        coordinatorSendRecoveryBeganAtMonotonicMilliseconds = nil
        pauseRecoveryBeganAtMonotonicMilliseconds = nil
        reliableRecoveryBeganAtMonotonicMilliseconds = nil
        peerCanonicalRecoveryBeganAtMonotonicMilliseconds = nil
        peerConsistencyIntact = true
        pendingPlans = [:]
        latestPlanMetadataControlSequence = 0
        latestPauseMetadataControlSequence = 0
        sentPlanIDs = []
        coordinatorEngine = nil
        playbackReducer = nil
        coreManifest = nil
        transcriptEvents = []
        currentAnnouncement = nil
        currentHitFeedbackEvent = nil
        settlementRecovery = nil
        isSubmittingTranscript = false
    }

    private var activeSettlementMatchID: String? {
        settlementRecovery?.pendingSubmission?.matchID
            ?? currentMatch?.matchId
    }

    private func restorePendingSubmission() {
        guard let pending = pendingSubmissionStore.load() else { return }
        let maximumAge: TimeInterval = 24 * 60 * 60
        let age = Date().timeIntervalSince(pending.createdAt)
        guard (2...4).contains(pending.participantCount),
            pending.transcript.matchId == pending.matchID,
            pending.transcript.buildId == MultiplayerAPIContract.buildID,
            pending.transcript.ruleset == MultiplayerAPIContract.ruleset,
            pending.transcript.protocolVersion == MultiplayerAPIContract.protocolVersion,
            pending.transcript.proofVersion == MultiplayerAPIContract.proofVersion,
            !pending.transcript.events.isEmpty,
            age >= 0,
            age <= maximumAge
        else {
            pendingSubmissionStore.clear()
            return
        }
        settlementRecovery = MultiplayerPresentation.SettlementRecovery(
            pendingSubmission: pending,
            participantCount: pending.participantCount
        )
        phase = .results
        resultsState = MultiplayerPresentation.ResultsState(
            settlement: .collecting(
                submitted: 0,
                total: max(2, pending.participantCount)
            ),
            results: [],
            isRefreshing: false,
            localSubmissionAccepted: false,
            message: "Restoring the retained Multiplayer result."
        )
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

    private func inputLogicalMilliseconds(
        forLocalMonotonicMilliseconds milliseconds: Int
    ) -> Int? {
        if let pausedAtLogicalMilliseconds,
            isApplicationActive,
            disconnectedGamePlayerIDs.isEmpty,
            !isTransportRecovering
        {
            return pausedAtLogicalMilliseconds
        }
        return try? transport.coordinatorLogicalMilliseconds(
            forLocalMonotonicMilliseconds: milliseconds
        )
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
    case lateEvidenceBeforePlayerOut

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
        case .lateEvidenceBeforePlayerOut:
            "Late multiplayer evidence contradicted the canonical elimination frontier."
        }
    }
}
