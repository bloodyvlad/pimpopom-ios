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
        XCTAssertEqual(state.startMatchControlState, .ready)
        XCTAssertEqual(state.startMatchControlState.title, "Start match")
        XCTAssertTrue(state.canStart)

        state.participants[1] = participant(seat: 1, ready: false, current: false)
        XCTAssertEqual(state.startMatchControlState, .waitingForPlayers)
        XCTAssertEqual(state.startMatchControlState.title, "Waiting for players")
        XCTAssertFalse(state.canStart)

        state.participants[1] = participant(seat: 1, ready: true, current: false)
        state.connection = .confirmingRoster(confirmed: 1, total: 2)
        XCTAssertEqual(state.startMatchControlState, .loadingRoster)
        XCTAssertEqual(state.startMatchControlState.title, "Loading roster…")
        XCTAssertFalse(state.canStart)

        state.connection = .ready
        state.isMutationPending = true
        XCTAssertEqual(state.startMatchControlState, .ready)
        XCTAssertFalse(state.canStart)

        state.isMutationPending = false
        state.participants.removeLast()
        XCTAssertEqual(state.startMatchControlState, .waitingForPlayers)
        XCTAssertFalse(state.canStart)

        state.participants.append(
            participant(
                seat: 1,
                ready: true,
                current: false,
                connected: false
            )
        )
        XCTAssertEqual(state.startMatchControlState, .loadingRoster)
        XCTAssertFalse(state.canStart)

        state.participants[1] = participant(seat: 1, ready: true, current: false)
        let nonCreatorState = MultiplayerPresentation.WaitingRoomState(
            matchID: "match",
            capacity: 2,
            isCreator: false,
            participants: state.participants,
            connection: .ready,
            isMutationPending: false
        )
        XCTAssertEqual(nonCreatorState.startMatchControlState, .ready)
        XCTAssertFalse(nonCreatorState.canStart)
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
        XCTAssertTrue(
            MultiplayerPresentation.WaitingConnectionState.cloudSyncRequired
                .shouldPresentFailure
        )

        let failed =
            MultiplayerPresentation.WaitingConnectionState.connectionFailed(
                "GameKit could not create the match."
            )
        XCTAssertEqual(failed.title, "Connection Failed")
        XCTAssertEqual(failed.detail, "GameKit could not create the match.")
        XCTAssertTrue(failed.canRetry)
        XCTAssertTrue(failed.shouldPresentFailure)
        XCTAssertTrue(
            MultiplayerPresentation.WaitingConnectionState.failed("Start failed.")
                .shouldPresentFailure
        )
        XCTAssertFalse(
            MultiplayerPresentation.WaitingConnectionState.matching.shouldPresentFailure
        )
        XCTAssertFalse(
            MultiplayerPresentation.WaitingConnectionState.ready.shouldPresentFailure
        )
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
    }

    func testLiveLayoutStacksPlayersAndMovesSEBoardCloserToHUD() {
        let compact = MultiplayerLiveLayoutMetrics.resolve(
            availableSize: CGSize(width: 375, height: 667),
            playerCount: 4
        )
        let tall = MultiplayerLiveLayoutMetrics.resolve(
            availableSize: CGSize(width: 430, height: 932),
            playerCount: 4
        )

        XCTAssertEqual(compact.hudToBoardSpacing, 4)
        XCTAssertEqual(tall.hudToBoardSpacing, 10)
        XCTAssertEqual(
            compact.playerStackHeight,
            MultiplayerLiveLayoutMetrics.badgeHeight * 4
                + MultiplayerLiveLayoutMetrics.badgeSpacing * 3
        )
        XCTAssertGreaterThanOrEqual(
            compact.boardSide,
            MultiplayerLiveLayoutMetrics.minimumBoardSide
        )
        XCTAssertEqual(
            tall.boardSide,
            430 - MultiplayerLiveLayoutMetrics.horizontalInset * 2
        )
    }

    func testTerminalRemoteInputNeverAdvancesCoordinatorBackwards() {
        XCTAssertEqual(
            MultiplayerCoordinatorFramePolicy.handledAt(
                inputAt: 9_000,
                receivedAt: 9_250,
                engineClock: 8_950,
                watermark: 9_100
            ),
            9_100
        )
        XCTAssertTrue(
            MultiplayerCoordinatorFramePolicy.shouldAdvance(.running)
        )
        XCTAssertFalse(
            MultiplayerCoordinatorFramePolicy.shouldAdvance(.finished)
        )
    }

    func testSettlementCopyDoesNotClaimServerAuthority() {
        XCTAssertEqual(
            MultiplayerPresentation.SettlementState.settled(
                leaderboardEligible: true
            ).title,
            "Match verified"
        )
    }

    func testLostSubmissionResponseRecoversFromTerminalSettlement() {
        var firstPeer = MultiplayerPresentation.SettlementRecovery(
            pendingSubmission: "exact-transcript",
            participantCount: 2
        )
        var secondPeer = MultiplayerPresentation.SettlementRecovery(
            pendingSubmission: "exact-transcript",
            participantCount: 2
        )

        XCTAssertTrue(
            firstPeer.recordSubmissionResponseFailure("The response was lost.")
        )
        XCTAssertEqual(firstPeer.pendingSubmission, "exact-transcript")
        XCTAssertTrue(firstPeer.shouldRetrySubmission)
        XCTAssertFalse(firstPeer.localSubmissionAccepted)
        XCTAssertTrue(firstPeer.shouldPoll)

        XCTAssertTrue(
            secondPeer.applyServerResponse(
                settlement: .settled(leaderboardEligible: true),
                source: .submission
            )
        )
        XCTAssertTrue(secondPeer.isTerminal)
        XCTAssertNil(secondPeer.pendingSubmission)

        XCTAssertTrue(
            firstPeer.applyServerResponse(
                settlement: .settled(leaderboardEligible: true),
                source: .settlement
            )
        )
        let terminalSnapshot = firstPeer
        XCTAssertTrue(firstPeer.canReturnToMenu)
        XCTAssertFalse(firstPeer.shouldPoll)
        XCTAssertNil(firstPeer.pendingSubmission)
        XCTAssertFalse(
            firstPeer.applyServerResponse(
                settlement: .collecting(submitted: 1, total: 2),
                source: .submission
            )
        )
        XCTAssertFalse(firstPeer.recordSubmissionResponseFailure("stale"))
        XCTAssertFalse(firstPeer.recordSettlementResponseFailure("stale"))
        XCTAssertEqual(firstPeer, terminalSnapshot)
    }

    func testFailedSubmissionBeforeCommitRetainsExactPayloadUntilRetrySettles() {
        var firstPeer = MultiplayerPresentation.SettlementRecovery(
            pendingSubmission: "exact-transcript",
            participantCount: 2
        )
        var secondPeer = MultiplayerPresentation.SettlementRecovery(
            pendingSubmission: "exact-transcript",
            participantCount: 2
        )

        XCTAssertTrue(firstPeer.recordSubmissionResponseFailure("offline"))
        XCTAssertTrue(
            secondPeer.applyServerResponse(
                settlement: .collecting(submitted: 1, total: 2),
                source: .submission
            )
        )
        XCTAssertEqual(secondPeer.pendingSubmission, "exact-transcript")
        XCTAssertTrue(secondPeer.localSubmissionAccepted)
        XCTAssertFalse(secondPeer.shouldRetrySubmission)

        XCTAssertTrue(
            firstPeer.applyServerResponse(
                settlement: .collecting(submitted: 1, total: 2),
                source: .settlement
            )
        )
        XCTAssertEqual(firstPeer.pendingSubmission, "exact-transcript")
        XCTAssertFalse(firstPeer.localSubmissionAccepted)
        XCTAssertTrue(firstPeer.shouldRetrySubmission)

        XCTAssertTrue(
            firstPeer.applyServerResponse(
                settlement: .settled(leaderboardEligible: true),
                source: .submission
            )
        )
        XCTAssertTrue(
            secondPeer.applyServerResponse(
                settlement: .settled(leaderboardEligible: true),
                source: .settlement
            )
        )
        XCTAssertTrue(firstPeer.canReturnToMenu)
        XCTAssertTrue(secondPeer.canReturnToMenu)
        XCTAssertNil(firstPeer.pendingSubmission)
        XCTAssertNil(secondPeer.pendingSubmission)
    }

    func testCollectingSettlementDoesNotInventSubmissionAcceptance() {
        var recovery = MultiplayerPresentation.SettlementRecovery(
            pendingSubmission: "exact-transcript",
            participantCount: 2
        )

        XCTAssertTrue(
            recovery.applyServerResponse(
                settlement: .collecting(submitted: 0, total: 2),
                source: .settlement
            )
        )
        XCTAssertEqual(recovery.pendingSubmission, "exact-transcript")
        XCTAssertFalse(recovery.localSubmissionAccepted)
        XCTAssertTrue(recovery.shouldRetrySubmission)

        XCTAssertTrue(
            recovery.applyServerResponse(
                settlement: .collecting(submitted: 1, total: 2),
                source: .submission
            )
        )
        XCTAssertEqual(recovery.pendingSubmission, "exact-transcript")
        XCTAssertTrue(recovery.localSubmissionAccepted)
        XCTAssertFalse(recovery.shouldRetrySubmission)
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
        creator: Bool = false,
        connected: Bool = true
    ) -> MultiplayerPresentation.Participant {
        MultiplayerPresentation.Participant(
            id: "player-\(seat)",
            seat: seat,
            colorIndex: seat,
            name: "Player \(seat)",
            petID: nil,
            ready: ready,
            isCurrentPlayer: current,
            isCreator: creator,
            isConnected: connected
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
