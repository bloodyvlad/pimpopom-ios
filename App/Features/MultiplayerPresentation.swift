import Foundation

enum MultiplayerPresentation {
    enum Availability: Equatable, Sendable {
        case available
        case checkingSession
        case signInRequired
        case confirmedNameRequired

        static func resolve(
            isSignedIn: Bool,
            nicknameConfirmed: Bool,
            gameCenterConnected _: Bool = false
        ) -> Self {
            guard isSignedIn else { return .signInRequired }
            guard nicknameConfirmed else { return .confirmedNameRequired }
            return .available
        }

        var isAvailable: Bool { self == .available }

        var menuMessage: String {
            switch self {
            case .available:
                "2–4 PLAYERS · NO COINS"
            case .checkingSession:
                "CHECKING SIGN-IN…"
            case .signInRequired:
                "SIGN IN TO PLAY"
            case .confirmedNameRequired:
                "CONFIRM PLAYER NAME"
            }
        }
    }

    struct Lobby: Equatable, Identifiable, Sendable {
        let id: String
        let capacity: Int
        let playerCount: Int
        let hostName: String
        let hostPetID: String?
        let expiresAt: Date?

        init(
            id: String,
            capacity: Int,
            playerCount: Int,
            hostName: String,
            hostPetID: String?,
            expiresAt: Date? = nil
        ) {
            self.id = id
            self.capacity = capacity
            self.playerCount = playerCount
            self.hostName = hostName
            self.hostPetID = hostPetID
            self.expiresAt = expiresAt
        }

        var openSeatCount: Int { max(0, capacity - playerCount) }
    }

    struct HubState: Equatable, Sendable {
        var availability: Availability
        var lobbies: [Lobby]
        var isRefreshing: Bool
        var isCreating: Bool
        var joiningLobbyID: String?
        var message: String? = nil

        init(
            availability: Availability,
            lobbies: [Lobby] = [],
            isRefreshing: Bool = false,
            isCreating: Bool = false,
            joiningLobbyID: String? = nil,
            message: String? = nil
        ) {
            self.availability = availability
            self.lobbies = lobbies
            self.isRefreshing = isRefreshing
            self.isCreating = isCreating
            self.joiningLobbyID = joiningLobbyID
            self.message = message
        }
    }

    struct Participant: Equatable, Identifiable, Sendable {
        let id: String
        let seat: Int
        let colorIndex: Int
        let name: String
        let petID: String?
        let ready: Bool
        let isCurrentPlayer: Bool
        let isCreator: Bool
        let isConnected: Bool

        init(
            id: String,
            seat: Int,
            colorIndex: Int,
            name: String,
            petID: String?,
            ready: Bool,
            isCurrentPlayer: Bool,
            isCreator: Bool = false,
            isConnected: Bool = true
        ) {
            self.id = id
            self.seat = seat
            self.colorIndex = colorIndex
            self.name = name
            self.petID = petID
            self.ready = ready
            self.isCurrentPlayer = isCurrentPlayer
            self.isCreator = isCreator
            self.isConnected = isConnected
        }
    }

    enum WaitingConnectionState: Equatable, Sendable {
        case matching
        case confirmingRoster(confirmed: Int, total: Int)
        case ready
        case connectionFailed(String)
        case failed(String)

        var title: String {
            switch self {
            case .matching:
                "Connecting to multiplayer…"
            case .confirmingRoster(let confirmed, let total):
                "Confirming players \(confirmed)/\(total)…"
            case .ready:
                "Roster confirmed"
            case .connectionFailed:
                "Connection Failed"
            case .failed(let message):
                message
            }
        }

        var detail: String? {
            switch self {
            case .connectionFailed(let message):
                message
            default:
                nil
            }
        }

        var canRetry: Bool {
            switch self {
            case .connectionFailed:
                true
            default:
                false
            }
        }

        var shouldPresentFailure: Bool {
            switch self {
            case .connectionFailed, .failed:
                true
            case .matching, .confirmingRoster, .ready:
                false
            }
        }
    }

    enum StartMatchControlState: Equatable, Sendable {
        case waitingForPlayers
        case loadingRoster
        case ready

        var title: String {
            switch self {
            case .waitingForPlayers:
                "Waiting for players"
            case .loadingRoster:
                "Loading roster…"
            case .ready:
                "Start match"
            }
        }

        var systemImage: String {
            switch self {
            case .waitingForPlayers:
                "person.2.fill"
            case .loadingRoster:
                "person.2.wave.2.fill"
            case .ready:
                "flag.checkered"
            }
        }
    }

    struct WaitingRoomState: Equatable, Sendable {
        let matchID: String
        let capacity: Int
        let isCreator: Bool
        var participants: [Participant]
        var connection: WaitingConnectionState
        var isMutationPending: Bool
        var message: String?
        var expiresAt: Date?
        var pendingReadyIntent: Bool?

        init(
            matchID: String,
            capacity: Int,
            isCreator: Bool,
            participants: [Participant],
            connection: WaitingConnectionState,
            isMutationPending: Bool,
            message: String? = nil,
            expiresAt: Date? = nil,
            pendingReadyIntent: Bool? = nil
        ) {
            self.matchID = matchID
            self.capacity = capacity
            self.isCreator = isCreator
            self.participants = participants
            self.connection = connection
            self.isMutationPending = isMutationPending
            self.message = message
            self.expiresAt = expiresAt
            self.pendingReadyIntent = pendingReadyIntent
        }

        var currentPlayer: Participant? {
            participants.first(where: \.isCurrentPlayer)
        }

        var canToggleReady: Bool {
            currentPlayer != nil
                && !isMutationPending
        }

        var displayedCurrentPlayerReady: Bool {
            pendingReadyIntent ?? currentPlayer?.ready ?? false
        }

        func displayedReady(for participant: Participant) -> Bool {
            participant.isCurrentPlayer
                ? (pendingReadyIntent ?? participant.ready)
                : participant.ready
        }

        var startMatchControlState: StartMatchControlState {
            let allPlayersReady =
                participants.count == capacity
                && participants.allSatisfy(\.ready)

            guard allPlayersReady else {
                return .waitingForPlayers
            }
            guard connection == .ready, participants.allSatisfy(\.isConnected) else {
                return .loadingRoster
            }
            return .ready
        }

        var canStart: Bool {
            isCreator
                && pendingReadyIntent == nil
                && startMatchControlState == .ready
                && !isMutationPending
        }
    }

    struct Cell: Equatable, Identifiable, Sendable {
        let id: Int
        let colorIndex: Int?
        let ownerSeat: Int?
        let glyph: String
        let isTarget: Bool
        let isDecoy: Bool
        let isHeart: Bool
        let isPendingLocalInput: Bool

        init(
            id: Int,
            colorIndex: Int?,
            ownerSeat: Int? = nil,
            glyph: String = "●",
            isTarget: Bool = false,
            isDecoy: Bool = false,
            isHeart: Bool = false,
            isPendingLocalInput: Bool = false
        ) {
            self.id = id
            self.colorIndex = colorIndex
            self.ownerSeat = ownerSeat
            self.glyph = glyph
            self.isTarget = isTarget
            self.isDecoy = isDecoy
            self.isHeart = isHeart
            self.isPendingLocalInput = isPendingLocalInput
        }
    }

    struct LivePlayer: Equatable, Identifiable, Sendable {
        let id: String
        let seat: Int
        let colorIndex: Int
        let name: String
        let petID: String?
        let points: Int
        let multiplier: Int
        let lives: Int
        let isLeader: Bool
        let isCurrentPlayer: Bool
        let isConnected: Bool
    }

    enum LiveInputMode: Equatable, Sendable {
        case interactive
        case pending
        case syncing
        case finalizing
        case spectating
    }

    enum LiveNetworkStatus: Equatable, Sendable {
        case catchingUp
        case reconnecting
        case finalizing

        var title: String {
            switch self {
            case .catchingUp:
                "Catching up"
            case .reconnecting:
                "Reconnecting"
            case .finalizing:
                "Finalizing"
            }
        }
    }

    struct LiveMatchState: Equatable, Sendable {
        let matchID: String
        let elapsedMilliseconds: Int
        let cells: [Cell]
        let players: [LivePlayer]
        let localSeat: Int
        let streakSteps: Int
        let isRecovering: Bool
        let networkStatus: LiveNetworkStatus?
        let announcement: String?
        let hitFeedbackEvent: GameplayHitFeedbackEvent?
        let inputMode: LiveInputMode
        let gridDimension: Int

        init(
            matchID: String,
            elapsedMilliseconds: Int,
            cells: [Cell],
            players: [LivePlayer],
            localSeat: Int,
            streakSteps: Int,
            isRecovering: Bool,
            networkStatus: LiveNetworkStatus? = nil,
            announcement: String?,
            hitFeedbackEvent: GameplayHitFeedbackEvent? = nil,
            inputMode: LiveInputMode = .interactive,
            gridDimension: Int = 4
        ) {
            self.matchID = matchID
            self.elapsedMilliseconds = elapsedMilliseconds
            self.cells = cells
            self.players = players
            self.localSeat = localSeat
            self.streakSteps = streakSteps
            self.isRecovering = isRecovering
            self.networkStatus = networkStatus
            self.announcement = announcement
            self.hitFeedbackEvent = hitFeedbackEvent
            self.inputMode = inputMode
            self.gridDimension = gridDimension
        }

        var localPlayer: LivePlayer? {
            players.first(where: { $0.seat == localSeat })
        }

        var isSpectating: Bool {
            inputMode == .spectating || localPlayer?.lives == 0
        }

        var orderedCells: [Cell] {
            let byID = Dictionary(uniqueKeysWithValues: cells.map { ($0.id, $0) })
            return (0..<(gridDimension * gridDimension)).map {
                byID[$0] ?? Cell(id: $0, colorIndex: nil)
            }
        }
    }

    enum SettlementState: Equatable, Sendable {
        case collecting(submitted: Int, total: Int)
        case settled(leaderboardEligible: Bool)
        case review(reason: String?)
        case cancelled(reason: String?)

        var isTerminal: Bool {
            switch self {
            case .collecting:
                false
            case .settled, .review, .cancelled:
                true
            }
        }

        var title: String {
            switch self {
            case .collecting:
                "Checking every player"
            case .settled(let eligible):
                eligible ? "Match verified" : "Match complete"
            case .review:
                "Match held for review"
            case .cancelled:
                "Match ended"
            }
        }
    }

    struct Result: Equatable, Identifiable, Sendable {
        let id: String
        let place: Int
        let playerCount: Int
        let name: String
        let petID: String?
        let score: Int
        let survivalMilliseconds: Int
        let hits: Int
        let misses: Int
        let dodges: Int
        let fastestReactionMilliseconds: Int?
        let averageReactionMilliseconds: Int?
        let maxMultiplier: Int
        let isCurrentPlayer: Bool
    }

    struct ResultsState: Equatable, Sendable {
        let settlement: SettlementState
        let results: [Result]
        let isRefreshing: Bool
        let localSubmissionAccepted: Bool
        let message: String?

        var canReturnToMenu: Bool { settlement.isTerminal }
    }

}
