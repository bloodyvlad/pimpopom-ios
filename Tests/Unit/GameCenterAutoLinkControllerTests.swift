import XCTest

@testable import PimPoPom

@MainActor
final class GameCenterAutoLinkControllerTests: XCTestCase {
    func testReconcileLinksEachCurrentProfileAndGameCenterIdentityOnlyOnce() async {
        var context: GameCenterAutoLinkContext? = makeContext(profileID: "profile-1")
        var linkedContexts: [GameCenterAutoLinkContext] = []
        let controller = GameCenterAutoLinkController(
            currentContext: { context },
            link: {
                linkedContexts.append($0)
            }
        )

        controller.reconcile()
        await wait(for: .linked, in: controller)
        controller.reconcile()
        await Task.yield()

        XCTAssertEqual(linkedContexts, [context!])

        context = makeContext(
            profileID: "profile-1",
            gamePlayerID: "game-player-2",
            teamPlayerID: "team-player-2"
        )
        controller.reconcile()
        await wait(for: .linked, in: controller)

        XCTAssertEqual(linkedContexts.count, 2)
        XCTAssertEqual(linkedContexts.last, context)
    }

    func testDeferredFailureRetriesWithoutSurfacingTheError() async {
        let context = makeContext(profileID: "profile-1")
        var attempt = 0
        let controller = GameCenterAutoLinkController(
            currentContext: { context },
            link: { _ in
                attempt += 1
                if attempt == 1 {
                    throw BackendError(
                        status: 409,
                        message: "Existing binding belongs to another profile.",
                        code: "game-center-conflict"
                    )
                }
            }
        )

        controller.reconcile()
        await wait(for: .deferred, in: controller)
        controller.reconcile()
        await wait(for: .linked, in: controller)

        XCTAssertEqual(attempt, 2)
    }

    func testContextChangeCancelsTheStaleLinkAndStartsTheCurrentOne() async {
        var context: GameCenterAutoLinkContext? = makeContext(profileID: "profile-1")
        var startedProfiles: [String] = []
        let controller = GameCenterAutoLinkController(
            currentContext: { context },
            link: { submittedContext in
                startedProfiles.append(submittedContext.profileID)
                if submittedContext.profileID == "profile-1" {
                    while !Task.isCancelled {
                        await Task.yield()
                    }
                    throw CancellationError()
                }
            }
        )

        controller.reconcile()
        await waitUntil { startedProfiles == ["profile-1"] }

        context = makeContext(profileID: "profile-2")
        controller.reconcile()
        await wait(for: .linked, in: controller)

        XCTAssertEqual(startedProfiles, ["profile-1", "profile-2"])
    }

    func testMissingContextResetsCompletedWork() async {
        var context: GameCenterAutoLinkContext? = makeContext(profileID: "profile-1")
        var linkCount = 0
        let controller = GameCenterAutoLinkController(
            currentContext: { context },
            link: { _ in linkCount += 1 }
        )

        controller.reconcile()
        await wait(for: .linked, in: controller)
        context = nil
        controller.reconcile()
        XCTAssertEqual(controller.state, .idle)

        context = makeContext(profileID: "profile-1")
        controller.reconcile()
        await wait(for: .linked, in: controller)

        XCTAssertEqual(linkCount, 2)
    }

    func testServerPublicationRegressionRepairsTheSameCurrentIdentity() async {
        let context = makeContext(profileID: "profile-1")
        var serverLinkIsReady = false
        var linkCount = 0
        let controller = GameCenterAutoLinkController(
            currentContext: { context },
            serverLinkIsReady: { serverLinkIsReady },
            link: { _ in
                linkCount += 1
                serverLinkIsReady = true
            }
        )

        controller.reconcile()
        await wait(for: .linked, in: controller)
        serverLinkIsReady = false
        controller.reconcile()
        await waitUntil { linkCount == 2 && controller.state == .linked }

        XCTAssertEqual(linkCount, 2)
    }

    private func makeContext(
        profileID: String,
        gamePlayerID: String = "game-player-1",
        teamPlayerID: String = "team-player-1"
    ) -> GameCenterAutoLinkContext {
        GameCenterAutoLinkContext(
            profileID: profileID,
            gamePlayerID: gamePlayerID,
            teamPlayerID: teamPlayerID
        )
    }

    private func wait(
        for expectedState: GameCenterAutoLinkState,
        in controller: GameCenterAutoLinkController,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        await waitUntil(file: file, line: line) {
            controller.state == expectedState
        }
    }

    private func waitUntil(
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @MainActor () -> Bool
    ) async {
        for _ in 0..<1_000 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("Timed out waiting for asynchronous Game Center state.", file: file, line: line)
    }
}
