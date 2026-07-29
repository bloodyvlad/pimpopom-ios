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
                    onJoin: multiplayer.joinMatch
                )
            case .waiting:
                if let state = multiplayer.waitingState {
                    MultiplayerWaitingRoomView(
                        state: state,
                        onToggleReady: multiplayer.toggleReady,
                        onStart: multiplayer.startMatch,
                        onLeave: multiplayer.leaveMatch,
                        onRetryConnection: multiplayer.retryGameKitConnection
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
                    onDone: multiplayer.returnToMenuFromResults
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
