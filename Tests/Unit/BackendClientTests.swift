import Foundation
import PimPoPomCore
import UIKit
import XCTest

@testable import PimPoPom

@MainActor
final class BackendClientTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testConcurrentSessionLoadsAreCoalesced() async throws {
        let recorder = RequestRecorder()
        let signedOutData = try JSONEncoder().encode(Self.signedOutSession)
        StubURLProtocol.handler = { request in
            recorder.append(request)
            return StubResponse(
                data: signedOutData,
                delay: 0.10
            )
        }
        let backend = makeBackend()

        let first = Task { @MainActor in try await backend.loadSession() }
        let second = Task { @MainActor in try await backend.loadSession() }
        _ = try await (first.value, second.value)

        XCTAssertEqual(recorder.requests(forPath: "/api/session").count, 1)
        XCTAssertFalse(backend.isAuthenticated)
    }

    func testSessionModelsDecodeLegacyAndAdditiveStoreKitState() throws {
        let legacy = try JSONDecoder().decode(
            SessionResponse.self,
            from: JSONEncoder().encode(Self.signedInSession)
        )
        XCTAssertNil(legacy.wallet)
        XCTAssertNil(legacy.adFree)
        XCTAssertNil(legacy.storeKit)

        let current = try JSONDecoder().decode(
            SessionResponse.self,
            from: JSONEncoder().encode(Self.storeKitSession)
        )
        XCTAssertEqual(current.wallet, Self.initialStoreWallet)
        XCTAssertEqual(current.adFree, false)
        XCTAssertEqual(current.storeKit?.boundToken, Self.storeAccountToken)
    }

    func testStoreKitCreditUsesExactNativeContractAndUpdatesAuthoritativeSession() async throws {
        let recorder = RequestRecorder()
        let sessionData = try JSONEncoder().encode(Self.storeKitSession)
        let response = StoreKitCreditAPIResponse(
            transactionId: "9001",
            status: "active",
            duplicate: false,
            wallet: StoreWalletSummary(
                earned: 75,
                purchased: 100,
                earnedDebt: 0,
                refundDebt: 0,
                total: 175
            ),
            adFree: true
        )
        let responseData = try JSONEncoder().encode(response)
        StubURLProtocol.handler = { request in
            recorder.append(request)
            switch (request.url?.path, request.httpMethod) {
            case ("/api/session", _): return StubResponse(data: sessionData)
            case ("/api/mobile/v1/storekit/transactions", "POST"):
                return StubResponse(data: responseData)
            default: return StubResponse(data: Data("{}".utf8), statusCode: 404)
            }
        }
        let backend = makeBackend()
        _ = try await backend.loadSession()

        let maybeBinding = await backend.currentStoreAccount()
        let binding = try XCTUnwrap(maybeBinding)
        XCTAssertEqual(binding.profileID, Self.storeKitSession.profile?.id)
        let credited = try await backend.credit(
            StoreCreditRequest(
                transactionID: "9001",
                productID: .coins100,
                signedTransaction: "header.payload.signature",
                appAccountToken: binding.appAccountToken
            )
        )

        XCTAssertEqual(credited.disposition, .credited)
        XCTAssertEqual(backend.profile?.coins, 175)
        XCTAssertEqual(backend.sessionState?.wallet, response.wallet)
        XCTAssertEqual(backend.sessionState?.adFree, true)
        XCTAssertEqual(backend.sessionState?.storeKit, Self.storeKitSession.storeKit)
        let storefront = await backend.currentStorefrontState()
        XCTAssertEqual(storefront.binding, binding)
        XCTAssertEqual(storefront.wallet, response.wallet)
        XCTAssertEqual(storefront.adFree, true)

        let request = try XCTUnwrap(
            recorder.requests(forPath: "/api/mobile/v1/storekit/transactions").first
        )
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.header(named: "X-SpeedyTapper-CSRF"), "csrf-storekit")
        let body = try XCTUnwrap(request.body)
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: String]
        )
        XCTAssertEqual(
            payload,
            [
                "signedTransaction": "header.payload.signature",
                "appAccountToken": Self.storeAccountToken.uuidString.lowercased(),
            ]
        )
    }

    func testStoreKitCreditRejectsUnknownStatusAndInvalidWalletWithoutMutatingCoins() async throws {
        for (status, wallet) in [
            (
                "unexpected",
                StoreWalletSummary(
                    earned: 75,
                    purchased: 50,
                    earnedDebt: 0,
                    refundDebt: 0,
                    total: 125
                )
            ),
            (
                "active",
                StoreWalletSummary(
                    earned: 75,
                    purchased: 50,
                    earnedDebt: 0,
                    refundDebt: 0,
                    total: 124
                )
            ),
        ] {
            let sessionData = try JSONEncoder().encode(Self.storeKitSession)
            let responseData = try JSONEncoder().encode(
                StoreKitCreditAPIResponse(
                    transactionId: "9002",
                    status: status,
                    duplicate: false,
                    wallet: wallet,
                    adFree: true
                )
            )
            StubURLProtocol.handler = { request in
                switch request.url?.path {
                case "/api/session": StubResponse(data: sessionData)
                case "/api/mobile/v1/storekit/transactions": StubResponse(data: responseData)
                default: StubResponse(data: Data("{}".utf8), statusCode: 404)
                }
            }
            let backend = makeBackend()
            _ = try await backend.loadSession()

            do {
                _ = try await backend.credit(
                    StoreCreditRequest(
                        transactionID: "9002",
                        productID: .coins50,
                        signedTransaction: "header.payload.signature",
                        appAccountToken: Self.storeAccountToken
                    )
                )
                XCTFail("The malformed StoreKit response must be rejected.")
            } catch let error as BackendError {
                XCTAssertEqual(error.code, "invalid-storekit-response")
            }
            XCTAssertEqual(backend.profile?.coins, 75)
            XCTAssertEqual(backend.sessionState?.wallet, Self.initialStoreWallet)
            XCTAssertEqual(backend.sessionState?.adFree, false)
        }
    }

    func testStoreKitBindingMustBeBoundAndUseValidUUIDsBeforeSendingCredit() async throws {
        let recorder = RequestRecorder()
        let invalidSession = SessionResponse(
            authenticated: Self.storeKitSession.authenticated,
            csrfToken: Self.storeKitSession.csrfToken,
            googleClientId: Self.storeKitSession.googleClientId,
            season: Self.storeKitSession.season,
            profile: Self.storeKitSession.profile,
            wallet: Self.storeKitSession.wallet,
            adFree: Self.storeKitSession.adFree,
            storeKit: StoreKitBindingResponse(
                appAccountToken: Self.storeAccountToken.uuidString.lowercased(),
                bindingStatus: "pending"
            ),
            ranks: Self.storeKitSession.ranks
        )
        let invalidJSON = try JSONEncoder().encode(invalidSession)
        StubURLProtocol.handler = { request in
            recorder.append(request)
            return StubResponse(data: invalidJSON)
        }
        let backend = makeBackend()
        _ = try await backend.loadSession()

        let invalidBinding = await backend.currentStoreAccount()
        XCTAssertNil(invalidBinding)
        do {
            _ = try await backend.credit(
                StoreCreditRequest(
                    transactionID: "9003",
                    productID: .coins50,
                    signedTransaction: "header.payload.signature",
                    appAccountToken: Self.storeAccountToken
                )
            )
            XCTFail("An unbound StoreKit account must not submit a transaction.")
        } catch let error as BackendError {
            XCTAssertEqual(error.code, "storekit-account-unavailable")
        }
        XCTAssertTrue(
            recorder.requests(forPath: "/api/mobile/v1/storekit/transactions").isEmpty
        )
    }

    #if DEBUG
        func testLocalStoreKitFixtureIsSignedInOfflineAndCreditsIdempotently() async throws {
            let recorder = RequestRecorder()
            StubURLProtocol.handler = { request in
                recorder.append(request)
                return StubResponse(data: Data("{}".utf8), statusCode: 500)
            }
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [StubURLProtocol.self]
            let backend = BackendClient(
                baseURL: URL(string: "https://must-not-be-used.invalid")!,
                isUITestOffline: false,
                useLocalStoreKitFixture: true,
                urlSession: URLSession(configuration: configuration)
            )
            let session = try await backend.loadSession()
            let maybeAccount = await backend.currentStoreAccount()
            let account = try XCTUnwrap(maybeAccount)
            let request = StoreCreditRequest(
                transactionID: "9100",
                productID: .coins50,
                signedTransaction: "local.signed.transaction",
                appAccountToken: account.appAccountToken
            )

            let first = try await backend.credit(request)
            let duplicate = try await backend.credit(request)

            XCTAssertTrue(session.authenticated)
            XCTAssertEqual(first.disposition, .credited)
            XCTAssertEqual(first.wallet.total, 125)
            XCTAssertEqual(duplicate.disposition, .duplicate)
            XCTAssertEqual(duplicate.wallet.total, 125)
            XCTAssertEqual(backend.profile?.coins, 125)
            XCTAssertEqual(backend.sessionState?.adFree, true)
            XCTAssertTrue(recorder.requests(forPath: "/api/session").isEmpty)
            XCTAssertTrue(
                recorder.requests(forPath: "/api/mobile/v1/storekit/transactions").isEmpty
            )
        }
    #endif

    func testLoginUsesCSRFAndLateSessionCannotReplaceNewAccount() async throws {
        let recorder = RequestRecorder()
        let sessionRequestCounter = LockedCounter()
        let signedOutData = try JSONEncoder().encode(Self.signedOutSession)
        let signedInData = try JSONEncoder().encode(Self.signedInSession)
        StubURLProtocol.handler = { request in
            recorder.append(request)
            switch request.url?.path {
            case "/api/session":
                let requestNumber = sessionRequestCounter.increment()
                return StubResponse(
                    data: signedOutData,
                    delay: requestNumber == 1 ? 0 : 0.20
                )
            case "/api/auth/google":
                return StubResponse(data: signedInData)
            default:
                return StubResponse(data: Data("{}".utf8), statusCode: 404)
            }
        }
        let backend = makeBackend()
        _ = try await backend.loadSession()

        let staleLoad = Task { @MainActor in try await backend.loadSession() }
        try await Task.sleep(for: .milliseconds(30))
        let loggedIn = try await backend.login(googleIDToken: "native-id-token")

        do {
            _ = try await staleLoad.value
            XCTFail("The superseded session load should not be applied.")
        } catch {
            // Cancellation or the explicit stale-session error are both safe outcomes.
        }

        XCTAssertEqual(loggedIn.profile?.id, "player-new")
        XCTAssertEqual(backend.profile?.id, "player-new")
        let loginRequest = try XCTUnwrap(recorder.requests(forPath: "/api/auth/google").first)
        XCTAssertEqual(loginRequest.method, "POST")
        XCTAssertEqual(loginRequest.header(named: "X-SpeedyTapper-CSRF"), "csrf-1")
        let body = try XCTUnwrap(loginRequest.body)
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: String]
        )
        XCTAssertEqual(payload["credential"], "native-id-token")
    }

    func testLightThemeUsesDarkPromptInkAndWhiteBoardInk() {
        XCTAssertEqual(ThemePalette.light.cellInkUIColor(at: 0), UIColor.white)
        XCTAssertNotEqual(ThemePalette.classic.cellInkUIColor(at: 0), UIColor.white)
    }

    func testAccountAndEconomyMutationsAreSerialized() async throws {
        let recorder = RequestRecorder()
        let signedInData = try JSONEncoder().encode(Self.signedInSession)
        let themeSelectionData = try JSONEncoder().encode(Self.themeSelection)
        let signedOutData = try JSONEncoder().encode(Self.signedOutSession)
        StubURLProtocol.handler = { request in
            recorder.append(request)
            switch request.url?.path {
            case "/api/session":
                return StubResponse(data: signedInData)
            case "/api/themes/select":
                return StubResponse(
                    data: themeSelectionData,
                    delay: 0.15
                )
            case "/api/logout":
                return StubResponse(data: signedOutData)
            default:
                return StubResponse(data: Data("{}".utf8), statusCode: 404)
            }
        }
        let backend = makeBackend()
        _ = try await backend.loadSession()

        let selection = Task { @MainActor in try await backend.selectTheme("light") }
        try await Task.sleep(for: .milliseconds(25))
        do {
            _ = try await backend.logout()
            XCTFail("A second account/economy mutation must not supersede the first.")
        } catch let error as BackendError {
            XCTAssertEqual(error.code, "session-update-in-progress")
        }

        _ = try await selection.value
        XCTAssertEqual(backend.profile?.selectedThemeId, "light")
        XCTAssertEqual(recorder.requests(forPath: "/api/logout").count, 0)
    }

    func testAccountDeletionUsesExactCSRFContractAndClearsSessionOnlyAfterConfirmation() async throws {
        let recorder = RequestRecorder()
        let sessionRequestCounter = LockedCounter()
        let signedInData = try JSONEncoder().encode(Self.signedInSession)
        let signedOutData = try JSONEncoder().encode(Self.signedOutSession)
        let reauthenticatedSession = SessionResponse(
            authenticated: true,
            csrfToken: "csrf-reauthenticated",
            googleClientId: Self.signedInSession.googleClientId,
            season: Self.signedInSession.season,
            profile: Self.signedInSession.profile,
            ranks: Self.signedInSession.ranks
        )
        let reauthenticatedData = try JSONEncoder().encode(reauthenticatedSession)
        let deletionData = Data(
            #"{"deleted":true,"authenticated":false,"retainedStoreKitTransactions":2,"retainedPurchasedCoinLots":1}"#
                .utf8
        )
        StubURLProtocol.handler = { request in
            recorder.append(request)
            switch (request.url?.path, request.httpMethod) {
            case ("/api/session", _):
                return StubResponse(
                    data: sessionRequestCounter.increment() == 1 ? signedInData : signedOutData
                )
            case ("/api/auth/google", "POST"):
                return StubResponse(data: reauthenticatedData)
            case ("/api/profile", "DELETE"):
                return StubResponse(data: deletionData)
            default:
                return StubResponse(data: Data("{}".utf8), statusCode: 404)
            }
        }
        let backend = makeBackend()
        _ = try await backend.loadSession()

        do {
            _ = try await backend.deleteAccount(
                confirmation: "delete my account",
                expectedPlayerID: "player-new"
            )
            XCTFail("An inexact confirmation phrase must be rejected.")
        } catch let error as BackendError {
            XCTAssertEqual(error.code, "invalid-account-deletion-confirmation")
        }
        XCTAssertTrue(recorder.requests(forPath: "/api/profile").isEmpty)
        XCTAssertEqual(backend.profile?.id, "player-new")

        _ = try await backend.reauthenticateForAccountDeletion(
            googleIDToken: "fresh-google-id-token",
            expectedPlayerID: "player-new"
        )
        let response = try await backend.deleteAccount(
            confirmation: BackendClient.accountDeletionConfirmation,
            expectedPlayerID: "player-new"
        )

        XCTAssertEqual(response, AccountDeletionResponse(deleted: true, authenticated: false))
        XCTAssertNil(backend.sessionState)
        XCTAssertNil(backend.profile)
        XCTAssertFalse(backend.isAuthenticated)
        let request = try XCTUnwrap(recorder.requests(forPath: "/api/profile").first)
        XCTAssertEqual(request.method, "DELETE")
        XCTAssertEqual(
            request.header(named: "X-SpeedyTapper-CSRF"),
            "csrf-reauthenticated"
        )
        let body = try XCTUnwrap(request.body)
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: String]
        )
        XCTAssertEqual(payload, ["confirmation": BackendClient.accountDeletionConfirmation])
        let loginRequest = try XCTUnwrap(recorder.requests(forPath: "/api/auth/google").first)
        XCTAssertEqual(loginRequest.header(named: "X-SpeedyTapper-CSRF"), "csrf-2")

        let freshSession = try await backend.loadSession()
        XCTAssertFalse(freshSession.authenticated)
        XCTAssertEqual(freshSession.csrfToken, "csrf-1")
        XCTAssertEqual(sessionRequestCounter.currentValue, 2)
    }

    func testUnconfirmedAccountDeletionResponsePreservesTheSignedInSession() async throws {
        let signedInData = try JSONEncoder().encode(Self.signedInSession)
        let invalidDeletionData = Data(#"{"deleted":false,"authenticated":false}"#.utf8)
        StubURLProtocol.handler = { request in
            switch (request.url?.path, request.httpMethod) {
            case ("/api/session", _): StubResponse(data: signedInData)
            case ("/api/profile", "DELETE"): StubResponse(data: invalidDeletionData)
            default: StubResponse(data: Data("{}".utf8), statusCode: 404)
            }
        }
        let backend = makeBackend()
        _ = try await backend.loadSession()

        do {
            _ = try await backend.deleteAccount(
                confirmation: BackendClient.accountDeletionConfirmation,
                expectedPlayerID: "player-new"
            )
            XCTFail("The client must reject a response that does not confirm deletion.")
        } catch let error as BackendError {
            XCTAssertEqual(error.code, "invalid-account-deletion-response")
        }

        XCTAssertTrue(backend.isAuthenticated)
        XCTAssertEqual(backend.profile?.id, "player-new")
    }

    func testAccountDeletionReauthenticationRejectsDifferentPlayerAndClearsFailedLogout()
        async throws
    {
        let recorder = RequestRecorder()
        let signedInData = try JSONEncoder().encode(Self.signedInSession)
        let otherProfile = PlayerProfile(
            id: "player-other",
            nickname: "Other",
            nicknameConfirmed: true,
            coins: 0,
            totalPlayMs: 0,
            ownedPetIds: [],
            selectedPetId: nil,
            petVisible: false,
            equippedPetId: nil,
            specialPetId: nil,
            ownedThemeIds: ["classic", "disco"],
            selectedThemeId: "classic",
            isAdmin: false,
            createdAt: "2026-07-19T00:00:00Z",
            updatedAt: "2026-07-19T00:00:00Z"
        )
        let otherSession = SessionResponse(
            authenticated: true,
            csrfToken: "csrf-other",
            googleClientId: Self.signedInSession.googleClientId,
            season: Self.signedInSession.season,
            profile: otherProfile,
            ranks: nil
        )
        let otherData = try JSONEncoder().encode(otherSession)
        StubURLProtocol.handler = { request in
            recorder.append(request)
            switch (request.url?.path, request.httpMethod) {
            case ("/api/session", _):
                return StubResponse(data: signedInData)
            case ("/api/auth/google", "POST"):
                return StubResponse(data: otherData)
            case ("/api/logout", "POST"):
                return StubResponse(
                    data: Data(#"{"error":"Logout unavailable"}"#.utf8),
                    statusCode: 503
                )
            case ("/api/profile", "DELETE"):
                return StubResponse(
                    data: Data(#"{"deleted":true,"authenticated":false}"#.utf8)
                )
            default:
                return StubResponse(data: Data("{}".utf8), statusCode: 404)
            }
        }
        let backend = makeBackend()
        _ = try await backend.loadSession()

        do {
            _ = try await backend.reauthenticateForAccountDeletion(
                googleIDToken: "different-google-id-token",
                expectedPlayerID: "player-new"
            )
            XCTFail("A different Google player must never authorize account deletion.")
        } catch let error as BackendError {
            XCTAssertEqual(error.code, BackendClient.accountDeletionAccountMismatchCode)
        }

        XCTAssertEqual(recorder.requests(forPath: "/api/auth/google").count, 1)
        XCTAssertEqual(recorder.requests(forPath: "/api/logout").count, 1)
        XCTAssertTrue(recorder.requests(forPath: "/api/profile").isEmpty)
        XCTAssertNil(backend.sessionState)
        XCTAssertNil(backend.profile)
        XCTAssertFalse(backend.isAuthenticated)
    }

    func testAchievementLoadAndClaimUseAuthoritativeCSRFContractAndUpdateCoins() async throws {
        let recorder = RequestRecorder()
        let sessionData = try JSONEncoder().encode(Self.signedInSession)
        let claimable = AchievementItem(
            id: "complete_arcade",
            title: "Complete Arcade mode",
            description: "Play until all three Arcade lives are gone.",
            rewardCoins: 1,
            state: .claimable,
            unlockedAt: "2026-07-17T00:00:00.000Z",
            claimedAt: nil
        )
        let loaded = AchievementsResponse(
            authenticated: true,
            achievements: [claimable],
            claimedCount: 0,
            totalCount: 1,
            coinBalance: 75
        )
        let claimed = AchievementItem(
            id: claimable.id,
            title: claimable.title,
            description: claimable.description,
            rewardCoins: claimable.rewardCoins,
            state: .claimed,
            unlockedAt: claimable.unlockedAt,
            claimedAt: "2026-07-17T00:00:01.000Z"
        )
        let claimResponse = AchievementsResponse(
            authenticated: true,
            achievements: [claimed],
            claimedCount: 1,
            totalCount: 1,
            coinBalance: 76,
            achievement: claimed,
            coinsEarned: 1,
            duplicate: false
        )
        let loadedData = try JSONEncoder().encode(loaded)
        let claimData = try JSONEncoder().encode(claimResponse)
        StubURLProtocol.handler = { request in
            recorder.append(request)
            switch (request.url?.path, request.httpMethod) {
            case ("/api/session", _): return StubResponse(data: sessionData)
            case ("/api/achievements", "GET"): return StubResponse(data: loadedData)
            case ("/api/achievements/claim", "POST"):
                return StubResponse(data: claimData, statusCode: 201)
            default: return StubResponse(data: Data("{}".utf8), statusCode: 404)
            }
        }

        let backend = makeBackend()
        _ = try await backend.loadSession()
        let loadedResponse = try await backend.loadAchievements()
        XCTAssertEqual(loadedResponse, loaded)
        let response = try await backend.claimAchievement("complete_arcade")

        XCTAssertEqual(response, claimResponse)
        XCTAssertEqual(backend.profile?.coins, 76)
        let getRequest = try XCTUnwrap(
            recorder.requests(forPath: "/api/achievements").first
        )
        XCTAssertEqual(getRequest.method, "GET")
        let claimRequest = try XCTUnwrap(
            recorder.requests(forPath: "/api/achievements/claim").first
        )
        XCTAssertEqual(claimRequest.method, "POST")
        XCTAssertEqual(claimRequest.header(named: "X-SpeedyTapper-CSRF"), "csrf-2")
        let body = try XCTUnwrap(claimRequest.body)
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: String]
        )
        XCTAssertEqual(payload, ["id": "complete_arcade"])
    }

    func testBlankAchievementIDIsRejectedBeforeANetworkMutation() async throws {
        let recorder = RequestRecorder()
        StubURLProtocol.handler = { request in
            recorder.append(request)
            return StubResponse(data: Data("{}".utf8), statusCode: 500)
        }
        let backend = makeBackend()

        do {
            _ = try await backend.claimAchievement("   ")
            XCTFail("A blank stable achievement ID must be rejected.")
        } catch let error as BackendError {
            XCTAssertEqual(error.code, "invalid-achievement")
        }
        XCTAssertTrue(recorder.requests(forPath: "/api/achievements/claim").isEmpty)
    }

    func testAchievementPayloadDecodesTheCurrentPHPShape() throws {
        let json = Data(
            #"""
            {
              "authenticated": true,
              "achievements": [{
                "id": "godlike_speed",
                "title": "Show Godlike speed",
                "description": "Make a correct tap in under 250 ms.",
                "rewardCoins": 1,
                "state": "claimable",
                "unlockedAt": "2026-07-17T00:00:00.000Z",
                "claimedAt": null
              }],
              "claimedCount": 0,
              "totalCount": 5,
              "coinBalance": 9
            }
            """#.utf8
        )

        let response = try JSONDecoder().decode(AchievementsResponse.self, from: json)

        XCTAssertTrue(response.authenticated)
        XCTAssertEqual(response.achievements.first?.state, .claimable)
        XCTAssertEqual(response.claimableCount, 1)
        XCTAssertNil(response.achievement)
        XCTAssertNil(response.coinsEarned)
        XCTAssertNil(response.duplicate)
    }

    func testRefreshDuringAchievementClaimCannotLeaveClaimsDisabled() async throws {
        let sessionData = try JSONEncoder().encode(Self.signedInSession)
        let claimable = AchievementItem(
            id: "complete_arcade",
            title: "Complete Arcade mode",
            description: "Play until all three Arcade lives are gone.",
            rewardCoins: 1,
            state: .claimable,
            unlockedAt: "2026-07-17T00:00:00.000Z",
            claimedAt: nil
        )
        let loaded = AchievementsResponse(
            authenticated: true,
            achievements: [claimable],
            claimedCount: 0,
            totalCount: 1,
            coinBalance: 75
        )
        let claimed = AchievementItem(
            id: claimable.id,
            title: claimable.title,
            description: claimable.description,
            rewardCoins: claimable.rewardCoins,
            state: .claimed,
            unlockedAt: claimable.unlockedAt,
            claimedAt: "2026-07-17T00:00:01.000Z"
        )
        let claimResponse = AchievementsResponse(
            authenticated: true,
            achievements: [claimed],
            claimedCount: 1,
            totalCount: 1,
            coinBalance: 76,
            achievement: claimed,
            coinsEarned: 1,
            duplicate: false
        )
        let loadedData = try JSONEncoder().encode(loaded)
        let claimData = try JSONEncoder().encode(claimResponse)
        StubURLProtocol.handler = { request in
            switch (request.url?.path, request.httpMethod) {
            case ("/api/session", _): StubResponse(data: sessionData)
            case ("/api/achievements", "GET"): StubResponse(data: loadedData)
            case ("/api/achievements/claim", "POST"):
                StubResponse(data: claimData, statusCode: 201, delay: 0.15)
            default: StubResponse(data: Data("{}".utf8), statusCode: 404)
            }
        }

        let backend = makeBackend()
        _ = try await backend.loadSession()
        let controller = AchievementsController(backend: backend)
        await controller.refresh()
        let claimTask = Task { @MainActor in await controller.claim(claimable) }
        try await Task.sleep(for: .milliseconds(25))

        await controller.refresh(showLoading: false)
        await claimTask.value

        XCTAssertNil(controller.pendingClaimID)
        XCTAssertEqual(controller.payload.achievements.first?.state, .claimed)
        XCTAssertEqual(controller.claimedCount, 1)
        XCTAssertEqual(backend.profile?.coins, 76)
    }

    func testMalformedSuccessfulClaimResponseIsRejectedWithoutChangingCoins() async throws {
        let sessionData = try JSONEncoder().encode(Self.signedInSession)
        let claimed = AchievementItem(
            id: "complete_arcade",
            title: "Complete Arcade mode",
            description: "Play until all three Arcade lives are gone.",
            rewardCoins: 1,
            state: .claimed,
            unlockedAt: "2026-07-17T00:00:00.000Z",
            claimedAt: "2026-07-17T00:00:01.000Z"
        )
        let malformed = AchievementsResponse(
            authenticated: true,
            achievements: [claimed],
            claimedCount: 1,
            totalCount: 1,
            coinBalance: 76,
            achievement: claimed
        )
        let malformedData = try JSONEncoder().encode(malformed)
        StubURLProtocol.handler = { request in
            switch request.url?.path {
            case "/api/session": StubResponse(data: sessionData)
            case "/api/achievements/claim": StubResponse(data: malformedData, statusCode: 201)
            default: StubResponse(data: Data("{}".utf8), statusCode: 404)
            }
        }

        let backend = makeBackend()
        _ = try await backend.loadSession()
        do {
            _ = try await backend.claimAchievement("complete_arcade")
            XCTFail("A malformed successful response must not update local economy state.")
        } catch let error as BackendError {
            XCTAssertEqual(error.code, "invalid-response")
        }
        XCTAssertEqual(backend.profile?.coins, 75)
    }

    func testAchievementAuthenticationMismatchRefreshesTheSession() async throws {
        let sessionRequestCounter = LockedCounter()
        let signedInData = try JSONEncoder().encode(Self.signedInSession)
        let signedOutData = try JSONEncoder().encode(Self.signedOutSession)
        let achievementsData = try JSONEncoder().encode(
            AchievementCatalog.lockedResponse(authenticated: false)
        )
        StubURLProtocol.handler = { request in
            switch request.url?.path {
            case "/api/session":
                StubResponse(
                    data: sessionRequestCounter.increment() == 1 ? signedInData : signedOutData
                )
            case "/api/achievements": StubResponse(data: achievementsData)
            default: StubResponse(data: Data("{}".utf8), statusCode: 404)
            }
        }

        let backend = makeBackend()
        _ = try await backend.loadSession()
        XCTAssertTrue(backend.isAuthenticated)

        do {
            _ = try await backend.loadAchievements()
            XCTFail("The response belongs to the expired account identity.")
        } catch let error as BackendError {
            XCTAssertEqual(error.code, "stale-session")
        }
        XCTAssertFalse(backend.isAuthenticated)
        XCTAssertNil(backend.profile)
    }

    func testExpiredSessionDuringAchievementClaimSignsTheLocalPlayerOut() async throws {
        let sessionRequestCounter = LockedCounter()
        let signedInData = try JSONEncoder().encode(Self.signedInSession)
        let signedOutData = try JSONEncoder().encode(Self.signedOutSession)
        StubURLProtocol.handler = { request in
            switch request.url?.path {
            case "/api/session":
                StubResponse(
                    data: sessionRequestCounter.increment() == 1 ? signedInData : signedOutData
                )
            case "/api/achievements/claim":
                StubResponse(
                    data: Data(#"{"error":"Sign in with Google to continue."}"#.utf8),
                    statusCode: 401
                )
            default: StubResponse(data: Data("{}".utf8), statusCode: 404)
            }
        }

        let backend = makeBackend()
        _ = try await backend.loadSession()
        do {
            _ = try await backend.claimAchievement("complete_arcade")
            XCTFail("An expired authenticated session must reject the claim.")
        } catch let error as BackendError {
            XCTAssertEqual(error.status, 401)
        }
        XCTAssertFalse(backend.isAuthenticated)
        XCTAssertNil(backend.profile)
        XCTAssertEqual(sessionRequestCounter.currentValue, 2)
    }

    func testExpiredCSRFDuringAchievementClaimRefreshesTheSecurityToken() async throws {
        let sessionRequestCounter = LockedCounter()
        let signedInData = try JSONEncoder().encode(Self.signedInSession)
        let refreshedSession = SessionResponse(
            authenticated: true,
            csrfToken: "csrf-3",
            googleClientId: Self.signedInSession.googleClientId,
            season: Self.signedInSession.season,
            profile: Self.signedInSession.profile,
            ranks: Self.signedInSession.ranks
        )
        let refreshedData = try JSONEncoder().encode(refreshedSession)
        StubURLProtocol.handler = { request in
            switch request.url?.path {
            case "/api/session":
                StubResponse(
                    data: sessionRequestCounter.increment() == 1
                        ? signedInData
                        : refreshedData
                )
            case "/api/achievements/claim":
                StubResponse(
                    data: Data(#"{"error":"Your security token expired. Please try again."}"#.utf8),
                    statusCode: 403
                )
            default: StubResponse(data: Data("{}".utf8), statusCode: 404)
            }
        }

        let backend = makeBackend()
        _ = try await backend.loadSession()
        do {
            _ = try await backend.claimAchievement("complete_arcade")
            XCTFail("An expired CSRF token must reject the first claim attempt.")
        } catch let error as BackendError {
            XCTAssertEqual(error.status, 403)
        }
        XCTAssertTrue(backend.isAuthenticated)
        XCTAssertEqual(backend.sessionState?.csrfToken, "csrf-3")
        XCTAssertEqual(sessionRequestCounter.currentValue, 2)
    }

    func testRankedRunStartAndFinishPreserveTicketProofContract() async throws {
        XCTAssertEqual(BackendClient.deployedBuildID, "20260719-1")
        let recorder = RequestRecorder()
        let sessionData = try JSONEncoder().encode(Self.signedInSession)
        let ticket = RunTicket(
            runId: "run-native-1",
            mode: GameMode.arcade.rawValue,
            buildId: BackendClient.deployedBuildID,
            ruleset: "reaction-proof-v2",
            proofVersion: 1
        )
        let finish = RunFinishResponse(
            rank: 8,
            submittedRank: 8,
            submittedEntryId: ticket.runId,
            improved: true,
            duplicate: false,
            verificationStatus: "verified",
            coinsEarned: 1,
            coinBalance: 76,
            totalPlayMs: 180_000
        )
        let ticketData = try JSONEncoder().encode(ticket)
        let finishData = try JSONEncoder().encode(finish)
        StubURLProtocol.handler = { request in
            recorder.append(request)
            switch request.url?.path {
            case "/api/session": return StubResponse(data: sessionData)
            case "/api/runs": return StubResponse(data: ticketData, statusCode: 201)
            case "/api/runs/finish": return StubResponse(data: finishData)
            default: return StubResponse(data: Data("{}".utf8), statusCode: 404)
            }
        }

        let backend = makeBackend()
        _ = try await backend.loadSession()
        let issued = try await backend.startRun()
        let engine = GameEngine(random: { 0 })
        _ = engine.start(now: 0, mode: .arcade)
        _ = engine.tap(cellIndex: 0, now: 100, resolvedAt: 100)
        _ = engine.tap(cellIndex: 0, now: 200, resolvedAt: 200)
        _ = engine.tap(cellIndex: 0, now: 300, resolvedAt: 300)
        let proof = engine.proofEvents()
        let accepted = try await backend.finishRun(ticket: issued, events: proof)

        XCTAssertEqual(issued, ticket)
        XCTAssertEqual(accepted, finish)

        let startRequest = try XCTUnwrap(recorder.requests(forPath: "/api/runs").first)
        XCTAssertEqual(startRequest.header(named: "X-SpeedyTapper-CSRF"), "csrf-2")
        let startPayload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(startRequest.body))
                as? [String: String]
        )
        XCTAssertEqual(startPayload["mode"], GameMode.arcade.rawValue)
        XCTAssertEqual(startPayload["buildId"], BackendClient.deployedBuildID)

        let finishRequest = try XCTUnwrap(
            recorder.requests(forPath: "/api/runs/finish").first
        )
        XCTAssertEqual(finishRequest.header(named: "X-SpeedyTapper-CSRF"), "csrf-2")
        let finishPayload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(finishRequest.body))
                as? [String: Any]
        )
        XCTAssertEqual(finishPayload["runId"] as? String, ticket.runId)
        XCTAssertEqual(finishPayload["mode"] as? String, ticket.mode)
        XCTAssertEqual(finishPayload["buildId"] as? String, ticket.buildId)
        XCTAssertEqual(finishPayload["ruleset"] as? String, ticket.ruleset)
        XCTAssertEqual(finishPayload["proofVersion"] as? Int, ticket.proofVersion)
        XCTAssertEqual(finishPayload["events"] as? [[Int]], proof)
    }

    func testSessionAndRunFinishIgnoreAchievementSnapshotFields() throws {
        var sessionPayload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(Self.signedInSession))
                as? [String: Any]
        )
        sessionPayload["achievementSnapshot"] = [
            "claimableCount": 2,
            "achievements": [["id": "complete_arcade", "state": "claimable"]],
        ]
        let decodedSession = try JSONDecoder().decode(
            SessionResponse.self,
            from: JSONSerialization.data(withJSONObject: sessionPayload)
        )
        XCTAssertEqual(decodedSession, Self.signedInSession)

        let finish = RunFinishResponse(
            rank: 8,
            submittedRank: 8,
            submittedEntryId: "run-native-1",
            improved: true,
            duplicate: false,
            verificationStatus: "verified",
            coinsEarned: 1,
            coinBalance: 76,
            totalPlayMs: 180_000
        )
        var finishPayload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(finish))
                as? [String: Any]
        )
        finishPayload["achievementSnapshot"] = [
            "claimableCount": 1,
            "achievements": [],
        ]
        let decodedFinish = try JSONDecoder().decode(
            RunFinishResponse.self,
            from: JSONSerialization.data(withJSONObject: finishPayload)
        )
        XCTAssertEqual(decodedFinish, finish)
    }

    func testRunFinishResponseRequiresTheExactVerifiedPHPEntry() {
        let accepted = RunFinishResponse(
            rank: 3,
            submittedRank: 3,
            submittedEntryId: "run-1",
            improved: true,
            duplicate: false,
            verificationStatus: "verified",
            coinsEarned: 0,
            coinBalance: 5,
            totalPlayMs: 1_000
        )
        XCTAssertTrue(accepted.confirmsPersistence(of: "run-1"))

        let mismatched = RunFinishResponse(
            rank: 3,
            submittedRank: 3,
            submittedEntryId: "different-run",
            improved: true,
            duplicate: false,
            verificationStatus: "verified",
            coinsEarned: 0,
            coinBalance: 5,
            totalPlayMs: 1_000
        )
        XCTAssertFalse(mismatched.confirmsPersistence(of: "run-1"))

        let review = RunFinishResponse(
            rank: nil,
            submittedRank: nil,
            submittedEntryId: nil,
            improved: false,
            duplicate: false,
            verificationStatus: "review",
            coinsEarned: 0,
            coinBalance: 5,
            totalPlayMs: 1_000
        )
        XCTAssertTrue(review.confirmsPersistence(of: "run-1"))
    }

    func testFinishRunRejectsAMismatchedVerifiedPHPEntry() async throws {
        let sessionData = try JSONEncoder().encode(Self.signedInSession)
        let ticket = RunTicket(
            runId: "run-native-mismatch",
            mode: GameMode.arcade.rawValue,
            buildId: BackendClient.deployedBuildID,
            ruleset: "reaction-proof-v2",
            proofVersion: 1
        )
        let mismatched = RunFinishResponse(
            rank: 4,
            submittedRank: 4,
            submittedEntryId: "another-run",
            improved: true,
            duplicate: false,
            verificationStatus: "verified",
            coinsEarned: 0,
            coinBalance: 75,
            totalPlayMs: 120_000
        )
        let mismatchData = try JSONEncoder().encode(mismatched)
        StubURLProtocol.handler = { request in
            switch request.url?.path {
            case "/api/session": StubResponse(data: sessionData)
            case "/api/runs/finish": StubResponse(data: mismatchData)
            default: StubResponse(data: Data("{}".utf8), statusCode: 404)
            }
        }

        let backend = makeBackend()
        _ = try await backend.loadSession()
        do {
            _ = try await backend.finishRun(ticket: ticket, events: [[5, 1, 1]])
            XCTFail("A verified response for another run must not clear the ticket.")
        } catch let error as BackendError {
            XCTAssertEqual(error.code, "invalid-run-finish-response")
        }
    }

    func testPetSelectHideAndShowUpdateVisiblePresentation() async throws {
        let recorder = RequestRecorder()
        let visibilityCounter = LockedCounter()
        let initialData = try JSONEncoder().encode(Self.signedInSession)
        let selectedProfile = petProfile(selectedID: "kesha", visible: true)
        let hiddenProfile = petProfile(selectedID: "kesha", visible: false)
        let selectedData = try JSONEncoder().encode(
            PetSelectionResponse(
                profile: selectedProfile,
                pet: PetSelectionResult(id: "kesha", purchased: true, pricePaid: 20),
                coinBalance: selectedProfile.coins
            )
        )
        let hiddenData = try JSONEncoder().encode(
            PetVisibilityResponse(
                profile: hiddenProfile,
                pet: PetVisibilityResult(id: "kesha", visible: false),
                coinBalance: hiddenProfile.coins
            )
        )
        let shownData = try JSONEncoder().encode(
            PetVisibilityResponse(
                profile: selectedProfile,
                pet: PetVisibilityResult(id: "kesha", visible: true),
                coinBalance: selectedProfile.coins
            )
        )
        StubURLProtocol.handler = { request in
            recorder.append(request)
            switch request.url?.path {
            case "/api/session":
                return StubResponse(data: initialData)
            case "/api/pets/select":
                return StubResponse(data: selectedData, statusCode: 201)
            case "/api/pets/selection":
                return StubResponse(
                    data: visibilityCounter.increment() == 1 ? hiddenData : shownData
                )
            default:
                return StubResponse(data: Data("{}".utf8), statusCode: 404)
            }
        }

        let suiteName = "PimPoPomTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let backend = makeBackend()
        _ = try await backend.loadSession()
        let cosmetics = CosmeticsController(
            backend: backend,
            preferences: AppPreferences(defaults: defaults)
        )
        let kesha = try XCTUnwrap(CosmeticCatalog.pets.first { $0.id == "kesha" })

        await cosmetics.performPetAction(kesha)
        XCTAssertEqual(cosmetics.selectedPetID, "kesha")
        XCTAssertTrue(cosmetics.petVisible)
        XCTAssertEqual(cosmetics.displayedPetID, "kesha")

        await cosmetics.performPetAction(kesha)
        XCTAssertFalse(cosmetics.petVisible)
        XCTAssertNil(cosmetics.displayedPetID)

        await cosmetics.performPetAction(kesha)
        XCTAssertTrue(cosmetics.petVisible)
        XCTAssertEqual(cosmetics.displayedPetID, "kesha")

        let selectRequest = try XCTUnwrap(recorder.requests(forPath: "/api/pets/select").first)
        XCTAssertEqual(selectRequest.header(named: "X-SpeedyTapper-CSRF"), "csrf-2")
        let selectBody = try XCTUnwrap(selectRequest.body)
        let selectPayload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: selectBody) as? [String: String]
        )
        XCTAssertEqual(selectPayload["petId"], "kesha")
        XCTAssertEqual(recorder.requests(forPath: "/api/pets/selection").count, 2)
    }

    private func makeBackend() -> BackendClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpCookieStorage = nil
        return BackendClient(
            baseURL: URL(string: "https://unit.test")!,
            isUITestOffline: false,
            urlSession: URLSession(configuration: configuration)
        )
    }

    private func petProfile(selectedID: String, visible: Bool) -> PlayerProfile {
        PlayerProfile(
            id: "player-new",
            nickname: "Player",
            nicknameConfirmed: true,
            coins: 55,
            totalPlayMs: 120_000,
            ownedPetIds: ["foka", "kesha"],
            selectedPetId: selectedID,
            petVisible: visible,
            equippedPetId: visible ? selectedID : nil,
            specialPetId: nil,
            ownedThemeIds: ["classic", "disco", "light"],
            selectedThemeId: "light",
            isAdmin: false,
            createdAt: "2026-07-15T00:00:00Z",
            updatedAt: "2026-07-15T00:00:00Z"
        )
    }

    private static let signedOutSession = SessionResponse(
        authenticated: false,
        csrfToken: "csrf-1",
        googleClientId: "server-client.apps.googleusercontent.com",
        season: Season(id: "season-1", name: "Season 1"),
        profile: nil,
        ranks: nil
    )

    private static let signedInSession = SessionResponse(
        authenticated: true,
        csrfToken: "csrf-2",
        googleClientId: "server-client.apps.googleusercontent.com",
        season: Season(id: "season-1", name: "Season 1"),
        profile: PlayerProfile(
            id: "player-new",
            nickname: "Player",
            nicknameConfirmed: true,
            coins: 75,
            totalPlayMs: 120_000,
            ownedPetIds: ["foka"],
            selectedPetId: "foka",
            petVisible: true,
            equippedPetId: "foka",
            specialPetId: nil,
            ownedThemeIds: ["classic", "disco", "light"],
            selectedThemeId: "light",
            isAdmin: false,
            createdAt: "2026-07-15T00:00:00Z",
            updatedAt: "2026-07-15T00:00:00Z"
        ),
        ranks: nil
    )

    private static let storeAccountToken = UUID(
        uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE"
    )!

    private static let initialStoreWallet = StoreWalletSummary(
        earned: 75,
        purchased: 0,
        earnedDebt: 0,
        refundDebt: 0,
        total: 75
    )

    private static let storeKitSession = SessionResponse(
        authenticated: true,
        csrfToken: "csrf-storekit",
        googleClientId: "server-client.apps.googleusercontent.com",
        season: Season(id: "season-1", name: "Season 1"),
        profile: PlayerProfile(
            id: "BBBBBBBB-CCCC-4DDD-8EEE-FFFFFFFFFFFF",
            nickname: "Buyer",
            nicknameConfirmed: true,
            coins: 75,
            totalPlayMs: 120_000,
            ownedPetIds: ["foka"],
            selectedPetId: "foka",
            petVisible: true,
            equippedPetId: "foka",
            specialPetId: nil,
            ownedThemeIds: ["classic", "disco", "light"],
            selectedThemeId: "light",
            isAdmin: false,
            createdAt: "2026-07-19T00:00:00Z",
            updatedAt: "2026-07-19T00:00:00Z"
        ),
        wallet: initialStoreWallet,
        adFree: false,
        storeKit: StoreKitBindingResponse(
            appAccountToken: storeAccountToken.uuidString.lowercased(),
            bindingStatus: "bound"
        ),
        ranks: nil
    )

    private static let themeSelection = ThemeSelectionResponse(
        profile: signedInSession.profile!,
        theme: ThemeSelectionResult(id: "light", purchased: false, pricePaid: 0),
        coinBalance: 75
    )
}

private struct StubResponse: @unchecked Sendable {
    let data: Data
    let statusCode: Int
    let delay: TimeInterval

    init(data: Data, statusCode: Int = 200, delay: TimeInterval = 0) {
        self.data = data
        self.statusCode = statusCode
        self.delay = delay
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> StubResponse)?

    private let stateLock = NSLock()
    private var stopped = false

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let result = handler(request)
        if result.delay > 0 { Thread.sleep(forTimeInterval: result.delay) }
        guard !isStopped, let url = request.url else { return }
        let response = HTTPURLResponse(
            url: url,
            statusCode: result.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: result.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        stateLock.withLock { stopped = true }
    }

    private var isStopped: Bool {
        stateLock.withLock { stopped }
    }
}

private final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [RecordedRequest] = []

    func append(_ request: URLRequest) {
        let captured = RecordedRequest(request)
        lock.withLock { recorded.append(captured) }
    }

    func requests(forPath path: String) -> [RecordedRequest] {
        lock.withLock { recorded.filter { $0.path == path } }
    }
}

private struct RecordedRequest: @unchecked Sendable {
    let path: String
    let method: String?
    let headers: [String: String]
    let body: Data?

    init(_ request: URLRequest) {
        path = request.url?.path ?? ""
        method = request.httpMethod
        headers = request.allHTTPHeaderFields ?? [:]
        body = request.httpBody ?? Self.read(stream: request.httpBodyStream)
    }

    func header(named name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    private static func read(stream: InputStream?) -> Data? {
        guard let stream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data.isEmpty ? nil : data
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var currentValue: Int {
        lock.withLock { value }
    }

    func increment() -> Int {
        lock.withLock {
            value += 1
            return value
        }
    }
}
