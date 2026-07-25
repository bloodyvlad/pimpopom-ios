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
        XCTAssertEqual(verification.gamePlayerID, "game-player-1")
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

    func testTransientScopedIDsAreVisibleAndRefusedBeforeSignatureFetch() async {
        let harness = GameCenterClientHarness()
        harness.authenticated = true
        harness.scopedIDsArePersistent = false
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

    func testReconnectAdoptsAnAlreadyAuthenticatedPlayerWithoutWaitingForCallback() {
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
        harness.authenticated = true
        harness.authenticationCallback?(nil, nil)
        service.disableParticipation()

        service.connect()

        XCTAssertEqual(harness.installCount, 2)
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
        XCTAssertTrue(service.participationEnabled)
    }

    func testTurningOffWhileAuthenticationIsPendingCancelsImmediately() {
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
        XCTAssertEqual(service.state, .authenticating)

        service.disableParticipation()
        harness.authenticated = true
        staleCallback?(nil, nil)

        XCTAssertEqual(service.state, .disabled)
        XCTAssertFalse(service.participationEnabled)
        XCTAssertNil(harness.authenticationCallback)
    }

    func testProfileStateResolverExposesEveryServerPublicationState() {
        let player = GameCenterPlayerIdentity(
            displayName: "Arcade Tester",
            gamePlayerID: "game-player-1",
            teamPlayerID: "team-player-1"
        )
        let authenticated = GameCenterConnectionState.authenticated(player)
        let base = GameCenterServerStatus(
            serverPublicationAvailable: true,
            preReleased: true,
            identityLinked: true,
            publicationEnabled: true,
            mirrorReady: true,
            pendingJobs: 0,
            heldJobs: 0,
            needsReset: false
        )

        XCTAssertEqual(
            GameCenterProfileStateResolver.resolve(
                connection: .disabled,
                primaryProfileAuthenticated: true,
                identityBinding: true,
                serverStatus: base,
                issue: nil
            ),
            .gameCenterSignedOut
        )
        XCTAssertEqual(
            resolved(authenticated, primary: false, binding: false, status: nil),
            .primaryProfileRequired
        )
        XCTAssertEqual(
            resolved(
                authenticated,
                primary: true,
                binding: false,
                status: nil,
                issue: .primaryReauthenticationRequired
            ),
            .primaryReauthenticationRequired
        )
        XCTAssertEqual(
            resolved(
                .authenticated(
                    GameCenterPlayerIdentity(
                        displayName: "Arcade Tester",
                        gamePlayerID: "game-player-1",
                        teamPlayerID: "team-player-1",
                        scopedIDsArePersistent: false
                    )
                ),
                primary: true,
                binding: false,
                status: nil
            ),
            .scopedIDsTransient
        )
        XCTAssertEqual(
            resolved(
                authenticated,
                primary: true,
                binding: false,
                status: status(base, identityLinked: false)
            ),
            .unlinked
        )
        XCTAssertEqual(
            resolved(
                authenticated,
                primary: true,
                binding: true,
                status: status(base, publicationEnabled: false, mirrorReady: false)
            ),
            .linkedIdentityOnly
        )
        XCTAssertEqual(
            resolved(
                authenticated,
                primary: true,
                binding: true,
                status: status(base, pendingJobs: 3)
            ),
            .publicationQueued(3)
        )
        XCTAssertEqual(
            resolved(authenticated, primary: true, binding: true, status: base),
            .mirrorReady
        )
        XCTAssertEqual(
            resolved(
                authenticated,
                primary: true,
                binding: true,
                status: status(base, pendingJobs: 2, heldJobs: 1)
            ),
            .publicationHeld(1)
        )
        XCTAssertEqual(
            resolved(
                authenticated,
                primary: true,
                binding: true,
                status: base,
                issue: .conflict("Already linked")
            ),
            .conflict("Already linked")
        )
        XCTAssertEqual(
            resolved(
                authenticated,
                primary: true,
                binding: true,
                status: status(base, needsReset: true)
            ),
            .resetNeedsSupport
        )
        XCTAssertEqual(
            resolved(
                authenticated,
                primary: true,
                binding: true,
                status: status(
                    base,
                    serverPublicationAvailable: false,
                    publicationEnabled: true,
                    mirrorReady: false
                )
            ),
            .linkedIdentityOnly
        )
    }

    private func resolved(
        _ connection: GameCenterConnectionState,
        primary: Bool,
        binding: Bool,
        status: GameCenterServerStatus?,
        issue: GameCenterLinkIssue? = nil
    ) -> GameCenterProfileState {
        GameCenterProfileStateResolver.resolve(
            connection: connection,
            primaryProfileAuthenticated: primary,
            identityBinding: binding,
            serverStatus: status,
            issue: issue
        )
    }

    private func status(
        _ base: GameCenterServerStatus,
        serverPublicationAvailable: Bool? = nil,
        identityLinked: Bool? = nil,
        publicationEnabled: Bool? = nil,
        mirrorReady: Bool? = nil,
        pendingJobs: Int? = nil,
        heldJobs: Int? = nil,
        needsReset: Bool? = nil
    ) -> GameCenterServerStatus {
        GameCenterServerStatus(
            serverPublicationAvailable:
                serverPublicationAvailable ?? base.serverPublicationAvailable,
            preReleased: base.preReleased,
            identityLinked: identityLinked ?? base.identityLinked,
            publicationEnabled: publicationEnabled ?? base.publicationEnabled,
            mirrorReady: mirrorReady ?? base.mirrorReady,
            pendingJobs: pendingJobs ?? base.pendingJobs,
            heldJobs: heldJobs ?? base.heldJobs,
            needsReset: needsReset ?? base.needsReset
        )
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
            }
        )
    }
}
