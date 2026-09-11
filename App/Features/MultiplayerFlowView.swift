import SwiftUI

struct MultiplayerFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var multiplayer: MultiplayerController

    var body: some View {
        // The flow owns membership; replacing a phase child is not a screen exit.
        ZStack {
            switch multiplayer.phase {
            case .hub:
                MultiplayerHubView(
                    state: multiplayer.hubState,
                    onRefresh: multiplayer.refreshLobbies,
                    onCreate: multiplayer.createMatch,
                    onJoin: multiplayer.joinMatch,
                    onSearch: multiplayer.searchLobbies
                )
            case .waiting:
                if let state = multiplayer.waitingState {
                    MultiplayerWaitingRoomView(
                        state: state,
                        onToggleReady: multiplayer.toggleReady,
                        onStart: multiplayer.startMatch,
                        onLeave: multiplayer.leaveMatch,
                        onRetryConnection: multiplayer.retryConnection,
                        onTogglePrivacy: multiplayer.togglePrivacy
                    )
                } else {
                    ProgressView("Opening waiting room…")
                }
            case .live:
                if let state = multiplayer.liveState {
                    MultiplayerLiveView(
                        state: state,
                        scene: multiplayer.scene,
                        onTapCell: multiplayer.handleTap,
                        onMenu: {
                            multiplayer.leaveMatch()
                            dismiss()
                        }
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
        .onDisappear { multiplayer.close() }
    }
}
