import Foundation

enum MultiplayerPresentation {
    enum Availability: Equatable, Sendable {
        case available
        case signInRequired
        case confirmedNameRequired
        case gameCenterRequired

        static func resolve(
            isSignedIn: Bool,
            nicknameConfirmed: Bool,
            gameCenterConnected: Bool
        ) -> Self {
            guard isSignedIn else { return .signInRequired }
            guard nicknameConfirmed else { return .confirmedNameRequired }
            guard gameCenterConnected else { return .gameCenterRequired }
            return .available
        }

        var isAvailable: Bool { self == .available }

        var menuMessage: String {
            switch self {
            case .available:
                "2–4 PLAYERS · NO COINS"
            case .signInRequired:
                "SIGN IN TO PLAY"
            case .confirmedNameRequired:
                "CONFIRM PLAYER NAME"
            case .gameCenterRequired:
                "CONNECT GAME CENTER"
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
        case cloudSyncRequired
        case connectionFailed(String)
        case failed(String)

        var title: String {
            switch self {
            case .matching:
                "Finding the GameKit roster…"
            case .confirmingRoster(let confirmed, let total):
                "Confirming players \(confirmed)/\(total)…"
            case .ready:
                "Roster confirmed"
            case .cloudSyncRequired:
                "Cloud Sync Required"
            case .connectionFailed:
                "Connection Failed"
            case .failed(let message):
                message
            }
        }

        var detail: String? {
            switch self {
            case .cloudSyncRequired:
                "Sign in to iCloud in Settings, then retry."
            case .connectionFailed(let message):
                message
            default:
                nil
            }
        }

        var canRetry: Bool {
            switch self {
            case .cloudSyncRequired, .connectionFailed:
                true
            default:
                false
            }
        }

        var shouldPresentFailure: Bool {
            switch self {
            case .cloudSyncRequired, .connectionFailed, .failed:
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

        var currentPlayer: Participant? {
            participants.first(where: \.isCurrentPlayer)
        }

        var canToggleReady: Bool {
            currentPlayer != nil && !isMutationPending
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

        init(
            id: Int,
            colorIndex: Int?,
            ownerSeat: Int? = nil,
            glyph: String = "●",
            isTarget: Bool = false,
            isDecoy: Bool = false
        ) {
            self.id = id
            self.colorIndex = colorIndex
            self.ownerSeat = ownerSeat
            self.glyph = glyph
            self.isTarget = isTarget
            self.isDecoy = isDecoy
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

    struct LiveMatchState: Equatable, Sendable {
        let matchID: String
        let elapsedMilliseconds: Int
        let cells: [Cell]
        let players: [LivePlayer]
        let localSeat: Int
        let streakSteps: Int
        let isRecovering: Bool
        let announcement: String?

        var localPlayer: LivePlayer? {
            players.first(where: { $0.seat == localSeat })
        }

        var isSpectating: Bool {
            localPlayer?.lives == 0
        }

        var orderedCells: [Cell] {
            let byID = Dictionary(uniqueKeysWithValues: cells.map { ($0.id, $0) })
            return (0..<16).map {
                byID[$0] ?? Cell(id: $0, colorIndex: nil)
            }
        }
    }

    enum SettlementState: Equatable, Sendable {
        case collecting(submitted: Int, total: Int)
        case settled(leaderboardEligible: Bool)
        case review(reason: String?)

        var isTerminal: Bool {
            switch self {
            case .collecting:
                false
            case .settled, .review:
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
            }
        }
    }

    struct SettlementRecovery<Submission: Equatable>: Equatable {
        enum ResponseSource {
            case submission
            case settlement
        }

        private(set) var settlement: SettlementState
        private(set) var pendingSubmission: Submission?
        private(set) var localSubmissionAccepted = false
        private(set) var shouldRetrySubmission = true
        private(set) var message: String?

        init(pendingSubmission: Submission, participantCount: Int) {
            settlement = .collecting(
                submitted: 0,
                total: max(2, participantCount)
            )
            self.pendingSubmission = pendingSubmission
        }

        var isTerminal: Bool { settlement.isTerminal }
        var shouldPoll: Bool { !isTerminal }
        var canReturnToMenu: Bool { isTerminal }

        @discardableResult
        mutating func applyServerResponse(
            settlement incoming: SettlementState,
            source: ResponseSource
        ) -> Bool {
            guard !isTerminal else { return false }
            settlement = incoming
            if source == .submission {
                localSubmissionAccepted = true
                shouldRetrySubmission = false
            }
            if incoming.isTerminal {
                pendingSubmission = nil
                shouldRetrySubmission = false
                if case .settled = incoming {
                    localSubmissionAccepted = true
                }
            }
            message =
                if case .collecting = incoming {
                    "Waiting for matching peer transcripts."
                } else {
                    nil
                }
            return true
        }

        @discardableResult
        mutating func recordSubmissionResponseFailure(_ failure: String) -> Bool {
            guard !isTerminal else { return false }
            shouldRetrySubmission =
                pendingSubmission != nil && !localSubmissionAccepted
            message = failure
            return true
        }

        @discardableResult
        mutating func recordSettlementResponseFailure(_ failure: String) -> Bool {
            guard !isTerminal else { return false }
            message = failure
            return true
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
