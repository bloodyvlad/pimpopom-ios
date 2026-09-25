import SwiftUI

/// Lazy admission is deliberate: constructing GameView can own a coordinator.
/// Never instantiate the destination underneath an overlay tutorial.
struct HowToPlayEntryView<Destination: View>: View {
    @EnvironmentObject private var preferences: AppPreferences
    @State private var admitted = false
    let mode: HowToPlayMode
    private let arguments: [String]
    private let destination: () -> Destination

    init(
        mode: HowToPlayMode, arguments: [String] = ProcessInfo.processInfo.arguments,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.mode = mode
        self.arguments = arguments
        self.destination = destination
    }

    var body: some View {
        ZStack {
            if admitted
                || !HowToPlayLaunchPolicy.shouldPresent(
                    rememberedSkip: preferences.skipsTutorial(for: mode), arguments: arguments)
            {
                destination()
            } else {
                HowToPlayView(mode: mode, doNotShowAgain: preferences.skipsTutorial(for: mode)) { skipNextTime in
                    preferences.setSkipsTutorial(skipNextTime, for: mode)
                    admitted = true
                }
            }
        }
    }
}

/// Settings replay ends in Settings; it never routes into gameplay or a lobby.
struct HowToPlayReplayView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: AppPreferences
    let mode: HowToPlayMode

    var body: some View {
        HowToPlayView(
            mode: mode, doNotShowAgain: preferences.skipsTutorial(for: mode), completionTitle: "Done"
        ) { skipNextTime in
            preferences.setSkipsTutorial(skipNextTime, for: mode)
            dismiss()
        }
    }
}
