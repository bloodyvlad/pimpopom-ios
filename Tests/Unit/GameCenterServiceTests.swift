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
            defaults: harness.defaults,
            presentAuthenticationViewController: { _ in true }
        )

        service.connect()
        service.connect()
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
            defaults: harness.defaults,
            presentAuthenticationViewController: {
                presentedController = $0
                return true
            }
        )

        service.connect()
        harness.authenticationCallback?(controller, nil)

        XCTAssertTrue(presentedController === controller)
        XCTAssertEqual(service.state, .authenticating)
    }

    func testUnavailableGameCenterCanRetryWithoutAffectingPimPoPomState() {
        let harness = GameCenterClientHarness()
        let service = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            defaults: harness.defaults,
            presentAuthenticationViewController: { _ in true }
        )

        service.connect()
        harness.authenticationCallback?(nil, "The player cancelled sign-in.")
        XCTAssertEqual(service.state, .unavailable("The player cancelled sign-in."))

        service.retryAuthentication()
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
            defaults: harness.defaults,
            presentAuthenticationViewController: { _ in
                XCTFail("UI tests must not present Game Center")
                return false
            }
        )

        service.connect()

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
            defaults: harness.defaults,
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
            defaults: harness.defaults,
            presentAuthenticationViewController: { _ in true }
        )
        service.connect()
        harness.authenticationCallback?(nil, nil)

        let verification = try await service.fetchIdentityVerification()

        XCTAssertEqual(verification.signedTeamPlayerID, "team-player-1")
        XCTAssertEqual(verification.bundleIdentifier, "com.otcsoftware.pimpopom")
        XCTAssertEqual(verification.signature, Data([1, 2, 3]))
        XCTAssertEqual(verification.salt, Data([4, 5, 6]))
        XCTAssertEqual(verification.timestamp, 1_721_234_567)
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
            defaults: harness.defaults,
            presentAuthenticationViewController: { _ in true }
        )
        service.connect()
        harness.authenticationCallback?(nil, nil)

        do {
            _ = try await service.fetchIdentityVerification()
            XCTFail("Expected an identity-change error")
        } catch {
            XCTAssertEqual(error as? GameCenterServiceError, .identityChanged)
        }
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
            defaults: harness.defaults,
            presentAuthenticationViewController: { _ in true }
        )
        service.connect()
        harness.authenticationCallback?(nil, nil)

        do {
            _ = try await service.fetchIdentityVerification()
            XCTFail("Expected an incomplete-verification error")
        } catch {
            XCTAssertEqual(error as? GameCenterServiceError, .incompleteVerification)
        }
    }

    func testLaunchDoesNotInstallAuthenticationUntilPlayerOptsIn() {
        let harness = GameCenterClientHarness()
        let service = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            defaults: harness.defaults,
            presentAuthenticationViewController: { _ in true }
        )

        service.resumeAuthenticationIfOptedIn()

        XCTAssertEqual(service.state, .disabled)
        XCTAssertFalse(service.participationEnabled)
        XCTAssertEqual(harness.installCount, 0)
    }

    func testSuccessfulConnectionPersistsOptInAndResumesOnNextLaunch() {
        let harness = GameCenterClientHarness()
        var service: GameCenterService? = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            defaults: harness.defaults,
            presentAuthenticationViewController: { _ in true }
        )

        service?.connect()
        harness.authenticated = true
        harness.authenticationCallback?(nil, nil)
        XCTAssertTrue(service?.participationEnabled == true)
        service = nil

        let relaunched = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            defaults: harness.defaults,
            presentAuthenticationViewController: { _ in true }
        )
        relaunched.resumeAuthenticationIfOptedIn()

        XCTAssertTrue(relaunched.participationEnabled)
        XCTAssertEqual(harness.installCount, 2)
    }

    func testCancelledConnectionDoesNotCreateAStartupOptIn() {
        let harness = GameCenterClientHarness()
        let service = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            defaults: harness.defaults,
            presentAuthenticationViewController: { _ in true }
        )
        service.connect()
        harness.authenticationCallback?(nil, "The player cancelled sign-in.")

        let relaunched = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            defaults: harness.defaults,
            presentAuthenticationViewController: { _ in true }
        )
        relaunched.resumeAuthenticationIfOptedIn()

        XCTAssertFalse(relaunched.participationEnabled)
        XCTAssertEqual(relaunched.state, .disabled)
        XCTAssertEqual(harness.installCount, 1)
    }

    func testTurningOffRemovesTheHandlerAndIgnoresStaleCallbacks() {
        let harness = GameCenterClientHarness()
        let service = GameCenterService(
            client: harness.client,
            arguments: [],
            environment: [:],
            bundleIdentifier: "com.otcsoftware.pimpopom",
            defaults: harness.defaults,
            presentAuthenticationViewController: { _ in true }
        )
        service.connect()
        let staleCallback = harness.authenticationCallback
        harness.authenticated = true
        harness.authenticationCallback?(nil, nil)

        service.disableParticipation()
        staleCallback?(nil, nil)

        XCTAssertEqual(service.state, .disabled)
        XCTAssertFalse(service.participationEnabled)
        XCTAssertEqual(harness.removeCount, 1)
        XCTAssertNil(harness.authenticationCallback)
    }
}

@MainActor
private final class GameCenterClientHarness {
    var installCount = 0
    var removeCount = 0
    var authenticated = false
    var teamPlayerID = "team-player-1"
    var authenticationCallback: GameCenterClient.AuthenticationCallback?
    var verification: (URL, Data, Data, UInt64)?
    var beforeVerificationCallback: (() -> Void)?
    let defaults = UserDefaults(
        suiteName: "GameCenterServiceTests.\(UUID().uuidString)"
    )!

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
            gamePlayerID: { "game-player-1" },
            teamPlayerID: { [weak self] in self?.teamPlayerID ?? "" },
            fetchIdentityVerification: { [weak self] callback in
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
            }
        )
    }
}
