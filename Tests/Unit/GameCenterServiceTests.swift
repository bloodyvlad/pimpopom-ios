import UIKit
import XCTest

@testable import PimPoPom

@MainActor
final class GameCenterServiceTests: XCTestCase {
    func testAuthenticationStartsOnceAndPublishesTheAuthenticatedPlayer() {
        let harness = GameCenterClientHarness()
        let service = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            presentAuthenticationViewController: { _ in true }
        )

        service.authenticateAtLaunch()
        service.authenticateAtLaunch()
        XCTAssertEqual(harness.installCount, 1)
        XCTAssertEqual(service.state, .authenticating)

        harness.authenticated = true
        harness.authenticationCallback?(nil, nil)

        XCTAssertEqual(
            service.state,
            .authenticated(
                GameCenterPlayerIdentity(
                    displayName: "Arcade Tester",
                    gamePlayerID: "game-player-1",
                    teamPlayerID: "team-player-1"
                )
            )
        )
    }

    func testAuthenticationPresentsAppleControllerWithoutBlockingOtherStartupWork() {
        let harness = GameCenterClientHarness()
        let controller = UIViewController()
        var presentedController: UIViewController?
        let service = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            presentAuthenticationViewController: {
                presentedController = $0
                return true
            }
        )

        service.authenticateAtLaunch()
        harness.authenticationCallback?(controller, nil)

        XCTAssertTrue(presentedController === controller)
        XCTAssertEqual(service.state, .authenticating)
    }

    func testStatsDashboardRequiresAnAuthenticatedGameCenterPlayer() {
        let harness = GameCenterClientHarness()
        let service = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            presentAuthenticationViewController: { _ in true }
        )

        XCTAssertFalse(service.showStats())
        XCTAssertEqual(harness.dashboardTriggerCount, 0)
        XCTAssertFalse(service.isOpeningStats)
    }

    func testStatsDashboardOpensOnceUntilAppleReportsPresentation() {
        let harness = GameCenterClientHarness()
        harness.authenticated = true
        let service = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            presentAuthenticationViewController: { _ in true }
        )
        service.authenticateAtLaunch()

        XCTAssertTrue(service.showStats())
        XCTAssertFalse(service.showStats())
        XCTAssertEqual(harness.dashboardTriggerCount, 1)
        XCTAssertTrue(service.isOpeningStats)

        harness.dashboardCompletion?()

        XCTAssertFalse(service.isOpeningStats)
        XCTAssertTrue(service.showStats())
        XCTAssertEqual(harness.dashboardTriggerCount, 2)
    }

    func testUnavailableGameCenterCanRetryWithoutAffectingPimPoPomState() {
        let harness = GameCenterClientHarness()
        let service = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            presentAuthenticationViewController: { _ in true }
        )

        service.authenticateAtLaunch()
        harness.authenticationCallback?(nil, "The player cancelled sign-in.")
        XCTAssertEqual(service.state, .unavailable("The player cancelled sign-in."))

        service.authenticateAtLaunch()
        XCTAssertEqual(harness.installCount, 2)
        XCTAssertEqual(service.state, .authenticating)
    }

    func testUITestsNeverInvokeTheSystemAuthenticationUI() {
        let harness = GameCenterClientHarness()
        let service = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: ["XCTestConfigurationFilePath": "fixture.xctestconfiguration"],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            presentAuthenticationViewController: { _ in
                XCTFail("UI tests must not present Game Center")
                return false
            }
        )

        service.authenticateAtLaunch()

        XCTAssertEqual(harness.installCount, 0)
        XCTAssertEqual(
            service.state,
            .unavailable("Unavailable in deterministic automated tests")
        )
    }

    func testIdentityVerificationRequiresAuthentication() async {
        let harness = GameCenterClientHarness()
        let service = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            presentAuthenticationViewController: { _ in true }
        )

        do {
            _ = try await service.fetchIdentityVerification()
            XCTFail("Expected an unauthenticated error")
        } catch {
            XCTAssertEqual(error as? GameCenterServiceError, .notAuthenticated)
        }
    }

    func testIdentityVerificationReturnsTheRuntimeSignedPlayerFields() async throws {
        let harness = GameCenterClientHarness()
        harness.authenticated = true
        harness.verification = (
            URL(string: "https://static.gc.apple.com/public-key")!,
            Data([1, 2, 3]),
            Data([4, 5, 6]),
            1_721_234_567
        )
        let service = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            presentAuthenticationViewController: { _ in true }
        )
        service.authenticateAtLaunch()
        harness.authenticationCallback?(nil, nil)

        let verification = try await service.fetchIdentityVerification()

        XCTAssertEqual(verification.signedTeamPlayerID, "team-player-1")
        XCTAssertEqual(verification.gamePlayerID, "game-player-1")
        XCTAssertEqual(verification.bundleIdentifier, "com.otcsoftware.pimpopom")
        XCTAssertEqual(verification.signature, Data([1, 2, 3]))
        XCTAssertEqual(verification.salt, Data([4, 5, 6]))
        XCTAssertEqual(verification.timestamp, 1_721_234_567)
    }

    func testRuntimeServerVerificationIsMemoryOnlyAndBoundToTheCurrentPlayer() throws {
        let harness = GameCenterClientHarness()
        harness.authenticated = true
        let service = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            presentAuthenticationViewController: { _ in true }
        )
        service.authenticateAtLaunch()
        let verification = GameCenterIdentityVerification(
            signedTeamPlayerID: harness.teamPlayerID,
            gamePlayerID: harness.gamePlayerID,
            bundleIdentifier: "com.otcsoftware.pimpopom",
            publicKeyURL: URL(string: "https://static.gc.apple.com/public-key")!,
            signature: Data([1]),
            salt: Data([2]),
            timestamp: 1
        )

        try service.markRuntimeVerification(
            profileID: "profile-1",
            verification: verification
        )

        XCTAssertTrue(service.isCurrentRuntimePlayerVerified(for: "profile-1"))
        XCTAssertFalse(service.isCurrentRuntimePlayerVerified(for: "profile-2"))
        XCTAssertEqual(service.runtimeVerifiedProfileID, "profile-1")

        harness.scopedIDsArePersistent = false
        harness.authenticationCallback?(nil, nil)
        XCTAssertFalse(service.isCurrentRuntimePlayerVerified(for: "profile-1"))
        XCTAssertNil(service.runtimeVerifiedProfileID)

        harness.scopedIDsArePersistent = true
        harness.authenticationCallback?(nil, nil)
        XCTAssertFalse(service.isCurrentRuntimePlayerVerified(for: "profile-1"))

        harness.gamePlayerID = "game-player-2"
        harness.teamPlayerID = "team-player-2"
        harness.authenticationCallback?(nil, nil)

        XCTAssertFalse(service.isCurrentRuntimePlayerVerified(for: "profile-1"))
        XCTAssertNil(service.runtimeVerifiedProfileID)
    }

    func testRuntimeVerificationRejectsTransientIDsAndAnotherBundle() {
        let harness = GameCenterClientHarness()
        harness.authenticated = true
        let service = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            presentAuthenticationViewController: { _ in true }
        )
        service.authenticateAtLaunch()
        var verification = GameCenterIdentityVerification(
            signedTeamPlayerID: harness.teamPlayerID,
            gamePlayerID: harness.gamePlayerID,
            bundleIdentifier: "com.example.another-game",
            publicKeyURL: URL(string: "https://static.gc.apple.com/public-key")!,
            signature: Data([1]),
            salt: Data([2]),
            timestamp: 1
        )

        XCTAssertThrowsError(
            try service.markRuntimeVerification(
                profileID: "profile-1",
                verification: verification
            )
        ) { error in
            XCTAssertEqual(error as? GameCenterServiceError, .identityChanged)
        }

        verification = GameCenterIdentityVerification(
            signedTeamPlayerID: harness.teamPlayerID,
            gamePlayerID: harness.gamePlayerID,
            bundleIdentifier: "com.otcsoftware.pimpopom",
            publicKeyURL: URL(string: "https://static.gc.apple.com/public-key")!,
            signature: Data([1]),
            salt: Data([2]),
            timestamp: 1
        )
        harness.scopedIDsArePersistent = false
        XCTAssertThrowsError(
            try service.markRuntimeVerification(
                profileID: "profile-1",
                verification: verification
            )
        ) { error in
            XCTAssertEqual(error as? GameCenterServiceError, .identityChanged)
        }
        XCTAssertFalse(service.isCurrentRuntimePlayerVerified(for: "profile-1"))
    }

    func testIdentityVerificationRejectsAPlayerChangeBeforeCompletion() async {
        let harness = GameCenterClientHarness()
        harness.authenticated = true
        harness.verification = (
            URL(string: "https://static.gc.apple.com/public-key")!,
            Data([1]),
            Data([2]),
            1
        )
        harness.beforeVerificationCallback = {
            harness.teamPlayerID = "different-team-player"
        }
        let service = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            presentAuthenticationViewController: { _ in true }
        )
        service.authenticateAtLaunch()
        harness.authenticationCallback?(nil, nil)

        do {
            _ = try await service.fetchIdentityVerification()
            XCTFail("Expected an identity-change error")
        } catch {
            XCTAssertEqual(error as? GameCenterServiceError, .identityChanged)
        }
    }

    func testIdentityVerificationRejectsAGamePlayerChangeBeforeCompletion() async {
        let harness = GameCenterClientHarness()
        harness.authenticated = true
        harness.verification = (
            URL(string: "https://static.gc.apple.com/public-key")!,
            Data([1]),
            Data([2]),
            1
        )
        harness.beforeVerificationCallback = {
            harness.gamePlayerID = "different-game-player"
        }
        let service = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            presentAuthenticationViewController: { _ in true }
        )
        service.authenticateAtLaunch()
        harness.authenticationCallback?(nil, nil)

        do {
            _ = try await service.fetchIdentityVerification()
            XCTFail("Expected an identity-change error")
        } catch {
            XCTAssertEqual(error as? GameCenterServiceError, .identityChanged)
        }
    }

    func testTransientScopedIDsAreVisibleAndRefusedBeforeSignatureFetch() async {
        let harness = GameCenterClientHarness()
        harness.authenticated = true
        harness.scopedIDsArePersistent = false
        let service = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            presentAuthenticationViewController: { _ in true }
        )
        service.authenticateAtLaunch()
        harness.authenticationCallback?(nil, nil)

        guard case .authenticated(let player) = service.state else {
            return XCTFail("Expected an authenticated Game Center player.")
        }
        XCTAssertFalse(player.scopedIDsArePersistent)
        do {
            _ = try await service.fetchIdentityVerification()
            XCTFail("Transient scoped IDs must never produce a proof.")
        } catch {
            XCTAssertEqual(error as? GameCenterServiceError, .scopedIDsTransient)
        }
        XCTAssertEqual(harness.verificationFetchCount, 0)
    }

    func testIdentityVerificationRejectsEmptySignatureMaterial() async {
        let harness = GameCenterClientHarness()
        harness.authenticated = true
        harness.verification = (
            URL(string: "https://static.gc.apple.com/public-key")!,
            Data(),
            Data([2]),
            1
        )
        let service = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            presentAuthenticationViewController: { _ in true }
        )
        service.authenticateAtLaunch()
        harness.authenticationCallback?(nil, nil)

        do {
            _ = try await service.fetchIdentityVerification()
            XCTFail("Expected an incomplete-verification error")
        } catch {
            XCTAssertEqual(error as? GameCenterServiceError, .incompleteVerification)
        }
    }

    func testLaunchAdoptsAnAlreadyAuthenticatedPlayerWithoutWaitingForCallback() {
        let harness = GameCenterClientHarness()
        harness.authenticated = true
        let service = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            presentAuthenticationViewController: { _ in true }
        )

        service.authenticateAtLaunch()

        XCTAssertEqual(harness.installCount, 1)
        XCTAssertEqual(
            service.state,
            .authenticated(
                GameCenterPlayerIdentity(
                    displayName: "Arcade Tester",
                    gamePlayerID: "game-player-1",
                    teamPlayerID: "team-player-1"
                )
            )
        )
    }

    func testForegroundRefreshPublishesPersistentScopedIDsWithoutAnotherCallback() {
        let harness = GameCenterClientHarness()
        harness.authenticated = true
        harness.scopedIDsArePersistent = false
        let service = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            presentAuthenticationViewController: { _ in true }
        )

        service.authenticateAtLaunch()
        guard case .authenticated(let transientPlayer) = service.state else {
            return XCTFail("Expected the signed-in Game Center player.")
        }
        XCTAssertFalse(transientPlayer.scopedIDsArePersistent)

        harness.scopedIDsArePersistent = true
        service.authenticateAtLaunch()

        guard case .authenticated(let persistentPlayer) = service.state else {
            return XCTFail("Expected refreshed persistent Game Center IDs.")
        }
        XCTAssertTrue(persistentPlayer.scopedIDsArePersistent)
        XCTAssertEqual(harness.installCount, 1)
    }
}

@MainActor
private final class GameCenterClientHarness {
    var installCount = 0
    var removeCount = 0
    var authenticated = false
    var teamPlayerID = "team-player-1"
    var gamePlayerID = "game-player-1"
    var scopedIDsArePersistent = true
    var verificationFetchCount = 0
    var dashboardTriggerCount = 0
    var authenticationCallback: GameCenterClient.AuthenticationCallback?
    var dashboardCompletion: GameCenterClient.DashboardCompletion?
    var verification: (URL, Data, Data, UInt64)?
    var beforeVerificationCallback: (() -> Void)?
    var client: GameCenterClient {
        GameCenterClient(
            installAuthenticationHandler: { [weak self] callback in
                self?.installCount += 1
                self?.authenticationCallback = callback
            },
            removeAuthenticationHandler: { [weak self] in
                self?.removeCount += 1
                self?.authenticationCallback = nil
            },
            isAuthenticated: { [weak self] in self?.authenticated == true },
            displayName: { "Arcade Tester" },
            gamePlayerID: { [weak self] in self?.gamePlayerID ?? "" },
            teamPlayerID: { [weak self] in self?.teamPlayerID ?? "" },
            scopedIDsArePersistent: {
                [weak self] in self?.scopedIDsArePersistent == true
            },
            fetchIdentityVerification: { [weak self] callback in
                self?.verificationFetchCount += 1
                guard let verification = self?.verification else {
                    callback(nil, nil, nil, 0, "Verification fixture unavailable")
                    return
                }
                self?.beforeVerificationCallback?()
                callback(
                    verification.0,
                    verification.1,
                    verification.2,
                    verification.3,
                    nil
                )
            },
            showDashboard: { [weak self] completion in
                guard let self, authenticated else { return false }
                dashboardTriggerCount += 1
                dashboardCompletion = completion
                return true
            }
        )
    }
}
