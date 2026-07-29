import SwiftUI

struct MultiplayerFlowView: View {
    @EnvironmentObject private var multiplayer: MultiplayerController

    var body: some View {
        Group {
            switch multiplayer.phase {
            case .hub:
                MultiplayerHubView(
                    state: multiplayer.hubState,
                    onRefresh: multiplayer.refreshLobbies,
                    onCreate: multiplayer.createMatch,
                    onJoin: multiplayer.joinMatch,
                    onOpenLeaderboard: multiplayer.openLeaderboard
                )
            case .waiting:
                if let state = multiplayer.waitingState {
                    MultiplayerWaitingRoomView(
                        state: state,
                        onToggleReady: multiplayer.toggleReady,
                        onStart: multiplayer.startMatch,
                        onLeave: multiplayer.leaveMatch,
                        onPetDrag: multiplayer.recordLocalPetDrag
                    )
                } else {
                    ProgressView("Opening waiting room…")
                }
            case .live:
                if let state = multiplayer.liveState {
                    MultiplayerLiveView(
                        state: state,
                        onTapCell: multiplayer.handleTap
                    )
                } else {
                    ProgressView("Starting match…")
                }
            case .results:
                MultiplayerResultsView(
                    state: multiplayer.resultsState,
                    onRefresh: multiplayer.refreshSettlement,
                    onOpenLeaderboard: multiplayer.openLeaderboard,
                    onDone: multiplayer.returnToMenuFromResults
                )
            case .leaderboard:
                MultiplayerLeaderboardView(
                    state: multiplayer.leaderboardState,
                    onRefresh: multiplayer.loadLeaderboard,
                    onDone: multiplayer.closeLeaderboard
                )
            }
        }
        .task {
            if multiplayer.phase == .hub {
                multiplayer.open()
            }
        }
    }
}
