import PimPoPomCore
import SwiftUI
import XCTest

@testable import PimPoPom

@MainActor
final class MultiplayerFlowLifecycleTests: XCTestCase {
    func testPhaseChangesKeepMembershipUntilTheFlowActuallyDisappears() async throws {
        let backend = BackendClient(isUITestOffline: true)
        let multiplayer = MultiplayerController(
            backend: backend, gameCenter: GameCenterService(), audio: AudioController())
        let suite = "MultiplayerFlowLifecycleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = AppPreferences(defaults: defaults)
        let cosmetics = CosmeticsController(backend: backend, preferences: preferences)
        let now = Int(ProcessInfo.processInfo.systemUptime * 1_000)
        var room = MP2Room(
            id: "lifecycle-room", revision: 1, rosterRevision: 1, hostPlayerID: "p0", capacity: 2,
            phase: .waiting,
            players: [
                .init(id: "p0", seat: 0, colorIndex: 0, name: "Pim", ready: true),
                .init(id: "p1", seat: 1, colorIndex: 1, name: "Pom", ready: true),
            ], gameplayRevision: MP2Protocol.gameplayRevision)

        // Start in a real waiting room so the view's hub-only task never opens a
        // network connection. Unlike screenshot fixtures, close() remains active.
        multiplayer.receive(
            .welcome(playerID: "p0", connectionID: "lifecycle", serverTimeMs: now, gameplayRevision: 2))
        multiplayer.joinMatch(room.id)
        multiplayer.receive(.room(room))

        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(
            rootView: NavigationStack {
                MultiplayerFlowView()
            }
            .environmentObject(multiplayer)
            .environmentObject(cosmetics)
            .environmentObject(preferences))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
            multiplayer.close()
        }
        try await render(host)
        XCTAssertEqual(multiplayer.phase, .waiting)
        XCTAssertEqual(multiplayer.waitingState?.matchID, room.id)

        room.revision += 1
        room.phase = .playing
        room.matchID = "lifecycle-match"
        room.startsAtServerMs = now
        multiplayer.receive(.room(room))
        let snapshot = MP2Snapshot(
            matchID: "lifecycle-match", revision: 2, elapsedMs: 0, phase: .playing,
            gridDimension: 1, players: room.players, targets: [], decoys: [], gameplayRevision: 2)
        multiplayer.receive(.snapshot(snapshot))
        try await render(host)
        XCTAssertEqual(multiplayer.phase, .live, "Replacing the waiting child must not leave the room")
        XCTAssertNotNil(multiplayer.liveState)
        guard multiplayer.phase == .live else { return }

        multiplayer.receive(
            .snapshot(
                .init(
                    matchID: snapshot.matchID, revision: snapshot.revision + 1, elapsedMs: 1_000, phase: .finished,
                    gridDimension: 1, players: room.players, targets: [], decoys: [], gameplayRevision: 2)))
        try await render(host)
        XCTAssertEqual(multiplayer.phase, .results, "Replacing the live child must not leave the room")
        XCTAssertEqual(multiplayer.resultsState.results.count, 2)

        // Replacing the hosting root is a genuine exit, so ownership must close.
        window.rootViewController = UIViewController()
        try await render(host)
        XCTAssertEqual(multiplayer.phase, .hub)
        XCTAssertNil(multiplayer.waitingState)
        XCTAssertNil(multiplayer.liveState)
    }

    private func render<Content: View>(_ host: UIHostingController<Content>) async throws {
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(300))
        host.view.layoutIfNeeded()
    }
}
