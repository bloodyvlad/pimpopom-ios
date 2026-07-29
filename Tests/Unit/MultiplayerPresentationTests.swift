import XCTest

@testable import PimPoPom

final class MultiplayerPresentationTests: XCTestCase {
    func testAvailabilityRequiresPrerequisitesInOrder() {
        XCTAssertEqual(
            MultiplayerPresentation.Availability.resolve(
                isSignedIn: false,
                nicknameConfirmed: false,
                gameCenterConnected: false
            ),
            .signInRequired
        )
        XCTAssertEqual(
            MultiplayerPresentation.Availability.resolve(
                isSignedIn: true,
                nicknameConfirmed: false,
                gameCenterConnected: false
            ),
            .confirmedNameRequired
        )
        XCTAssertEqual(
            MultiplayerPresentation.Availability.resolve(
                isSignedIn: true,
                nicknameConfirmed: true,
                gameCenterConnected: false
            ),
            .gameCenterRequired
        )
        XCTAssertEqual(
            MultiplayerPresentation.Availability.resolve(
                isSignedIn: true,
                nicknameConfirmed: true,
                gameCenterConnected: true
            ),
            .available
        )
    }

    func testLobbyOpenSeatsNeverBecomeNegative() {
        let fullLobby = MultiplayerPresentation.Lobby(
            id: "match",
            capacity: 2,
            playerCount: 4,
            hostName: "Pim",
            hostPetID: nil
        )
        XCTAssertEqual(fullLobby.openSeatCount, 0)
    }

    func testWaitingRoomStartRequiresCreatorRosterAndEveryReadyPlayer() {
        let players = [
            participant(seat: 0, ready: true, current: true, creator: true),
            participant(seat: 1, ready: true, current: false),
        ]
        var state = MultiplayerPresentation.WaitingRoomState(
            matchID: "match",
            capacity: 2,
            isCreator: true,
            participants: players,
            connection: .ready,
            isMutationPending: false
        )
        XCTAssertTrue(state.canStart)

        state.participants[1] = participant(seat: 1, ready: false, current: false)
        XCTAssertFalse(state.canStart)

        state.participants[1] = participant(seat: 1, ready: true, current: false)
        state.connection = .confirmingRoster(confirmed: 1, total: 2)
        XCTAssertFalse(state.canStart)

        state.connection = .ready
        state.isMutationPending = true
        XCTAssertFalse(state.canStart)
    }

    func testWaitingRoomCanToggleReadyBeforeGameKitRosterCompletes() {
        var state = MultiplayerPresentation.WaitingRoomState(
            matchID: "match",
            capacity: 2,
            isCreator: false,
            participants: [
                participant(seat: 0, ready: false, current: true),
                participant(seat: 1, ready: false, current: false),
            ],
            connection: .matching,
            isMutationPending: false
        )

        XCTAssertTrue(state.canToggleReady)
        XCTAssertFalse(state.canStart)

        state.connection = .confirmingRoster(confirmed: 1, total: 2)
        XCTAssertTrue(state.canToggleReady)
        XCTAssertFalse(state.canStart)

        state.isMutationPending = true
        XCTAssertFalse(state.canToggleReady)
    }

    func testGameKitConnectionFailuresHaveStableRetryablePresentation() {
        XCTAssertEqual(
            MultiplayerPresentation.WaitingConnectionState.cloudSyncRequired.title,
            "Cloud Sync Required"
        )
        XCTAssertEqual(
            MultiplayerPresentation.WaitingConnectionState.cloudSyncRequired.detail,
            "Sign in to iCloud in Settings, then retry."
        )
        XCTAssertTrue(
            MultiplayerPresentation.WaitingConnectionState.cloudSyncRequired.canRetry
        )

        let failed =
            MultiplayerPresentation.WaitingConnectionState.connectionFailed(
                "GameKit could not create the match."
            )
        XCTAssertEqual(failed.title, "Connection Failed")
        XCTAssertEqual(failed.detail, "GameKit could not create the match.")
        XCTAssertTrue(failed.canRetry)
    }

    func testLiveStateAlwaysPresentsSixteenOrderedCells() {
        let live = MultiplayerPresentation.LiveMatchState(
            matchID: "match",
            elapsedMilliseconds: 5_000,
            cells: [
                .init(id: 9, colorIndex: 1, isTarget: true),
                .init(id: 2, colorIndex: 5, isDecoy: true),
            ],
            players: [
                livePlayer(seat: 0),
                livePlayer(seat: 1),
                livePlayer(seat: 2),
            ],
            localSeat: 0,
            streakSteps: 2,
            isRecovering: false,
            announcement: nil
        )
        XCTAssertEqual(live.orderedCells.map(\.id), Array(0..<16))
        XCTAssertEqual(live.orderedCells[2].colorIndex, 5)
        XCTAssertEqual(live.orderedCells[9].colorIndex, 1)
        XCTAssertEqual(live.stripFraction, 1.0 / 3.0, accuracy: 0.000_001)
    }

    func testPlayerStripFractionsCoverSupportedRosterSizes() {
        for count in 2...4 {
            let live = MultiplayerPresentation.LiveMatchState(
                matchID: "match",
                elapsedMilliseconds: 0,
                cells: [],
                players: (0..<count).map { livePlayer(seat: $0) },
                localSeat: 0,
                streakSteps: 0,
                isRecovering: false,
                announcement: nil
            )
            XCTAssertEqual(
                live.stripFraction,
                1 / Double(count),
                accuracy: 0.000_001
            )
        }
    }

    func testSettlementCopyDoesNotClaimServerAuthority() {
        XCTAssertEqual(
            MultiplayerPresentation.SettlementState.settled(
                leaderboardEligible: true
            ).title,
            "Match verified"
        )
    }

    func testEliminatedLocalPlayerRemainsInLiveSpectatorState() {
        let live = MultiplayerPresentation.LiveMatchState(
            matchID: "match",
            elapsedMilliseconds: 72_000,
            cells: [],
            players: [
                livePlayer(seat: 0, lives: 0),
                livePlayer(seat: 1, lives: 2),
            ],
            localSeat: 0,
            streakSteps: 0,
            isRecovering: false,
            announcement: nil
        )

        XCTAssertTrue(live.isSpectating)
        XCTAssertEqual(live.players.count, 2)
        XCTAssertEqual(live.players[1].lives, 2)
    }

    private func participant(
        seat: Int,
        ready: Bool,
        current: Bool,
        creator: Bool = false
    ) -> MultiplayerPresentation.Participant {
        MultiplayerPresentation.Participant(
            id: "player-\(seat)",
            seat: seat,
            colorIndex: seat,
            name: "Player \(seat)",
            petID: nil,
            ready: ready,
            isCurrentPlayer: current,
            isCreator: creator
        )
    }

    private func livePlayer(
        seat: Int,
        lives: Int = 3
    ) -> MultiplayerPresentation.LivePlayer {
        MultiplayerPresentation.LivePlayer(
            id: "player-\(seat)",
            seat: seat,
            colorIndex: seat,
            name: "Player \(seat)",
            petID: nil,
            points: seat * 1_000,
            multiplier: 1,
            lives: lives,
            isLeader: seat == 0,
            isCurrentPlayer: seat == 0,
            isConnected: true
        )
    }
}
