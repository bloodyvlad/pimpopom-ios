import Combine
import Foundation
import PimPoPomCore

struct BackendError: LocalizedError {
    let status: Int
    let message: String
    let code: String?

    var errorDescription: String? { message }
}

@MainActor
final class BackendClient: ObservableObject, StoreKitCreditServing {
    static let productionBaseURL = URL(string: "https://speedytapper.otcsoft.com")!
    static let deployedBuildID = "20260729-1"
    static let rankedRuleset = "reaction-proof-v3"
    static let rankedProofVersion = 2
    static let accountDeletionConfirmation = "DELETE MY ACCOUNT"
    static let accountDeletionAccountMismatchCode = "account-reauthentication-mismatch"
    static var localStoreKitFixtureRequested: Bool {
        #if DEBUG
            ProcessInfo.processInfo.arguments.contains("--local-storekit-credit")
        #else
            false
        #endif
    }
    #if DEBUG
        static let uiTestAccountDeletionCredential = "pimpopom-ui-test-account-reauthentication"
    #endif

    @Published private(set) var sessionState: SessionResponse?
    @Published private(set) var isLoadingSession = false
    @Published private(set) var lastError: String?

    private let baseURL: URL
    private let urlSession: URLSession
    private let isUITestOffline: Bool
    #if DEBUG
        private let localStoreKitCreditService: LocalStoreKitCreditService?
    #endif
    private var uiTestSession: SessionResponse?
    private var uiTestAchievements: AchievementsResponse?
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var csrfToken: String?
    private var sessionStateEpoch = 0
    private var activeStateMutationEpoch: Int?
    private var nextSessionLoadID = 0
    private var activeSessionLoadID: Int?
    private var sessionLoadTask: Task<SessionResponse, Error>?

    init(
        baseURL: URL = BackendClient.productionBaseURL,
        isUITestOffline: Bool = ProcessInfo.processInfo.arguments.contains("--uitesting"),
        useLocalStoreKitFixture: Bool = BackendClient.localStoreKitFixtureRequested,
        urlSession: URLSession? = nil
    ) {
        #if DEBUG
            let localStoreKitFixtureEnabled = useLocalStoreKitFixture
            localStoreKitCreditService =
                localStoreKitFixtureEnabled
                ? LocalStoreKitCreditService()
                : nil
        #else
            let localStoreKitFixtureEnabled = false
        #endif
        let offline = isUITestOffline || localStoreKitFixtureEnabled
        self.baseURL = baseURL
        self.isUITestOffline = offline
        #if DEBUG
            uiTestSession =
                if localStoreKitFixtureEnabled {
                    Self.uiTestStoreKitSession
                } else if offline {
                    Self.selectedUITestSession
                } else {
                    nil
                }
        #else
            uiTestSession = offline ? Self.selectedUITestSession : nil
        #endif
        if offline {
            let arguments = ProcessInfo.processInfo.arguments
            let exposesScreenshotAchievements =
                ScreenshotFixture.resolve(arguments: arguments)?.destination == .achievements
            uiTestAchievements = Self.uiTestAchievementResponse(
                session: uiTestSession,
                exposesClaimableFixture:
                    arguments.contains("--ui-test-achievements-profile")
                    || exposesScreenshotAchievements
            )
        }
        if let urlSession {
            self.urlSession = urlSession
        } else {
            let configuration = offline ? URLSessionConfiguration.ephemeral : .default
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.urlCache = nil
            configuration.httpShouldSetCookies = !offline
            configuration.httpCookieAcceptPolicy = offline ? .never : .always
            configuration.httpCookieStorage = offline ? nil : .shared
            configuration.timeoutIntervalForRequest = 20
            self.urlSession = URLSession(configuration: configuration)
        }
        if let uiTestSession {
            sessionState = uiTestSession
            csrfToken = uiTestSession.csrfToken
        }
    }

    var profile: PlayerProfile? { sessionState?.profile }
    var isAuthenticated: Bool { sessionState?.authenticated == true }
    var canStartRankedRun: Bool {
        isAuthenticated && profile?.nicknameConfirmed == true
    }

    func currentStoreAccount() async -> StoreAccountBinding? {
        guard let sessionState,
            sessionState.authenticated,
            let profile = sessionState.profile,
            UUID(uuidString: profile.id) != nil,
            let token = sessionState.storeKit?.boundToken
        else { return nil }
        return StoreAccountBinding(profileID: profile.id, appAccountToken: token)
    }

    func currentStorefrontState() async -> StorefrontAccountState {
        let binding = await currentStoreAccount()
        let wallet = sessionState?.wallet.flatMap { Self.isValidWallet($0) ? $0 : nil }
        return StorefrontAccountState(
            binding: binding,
            wallet: binding == nil ? nil : wallet,
            adFree: binding == nil ? nil : sessionState?.adFree
        )
    }

    func credit(_ request: StoreCreditRequest) async throws -> StoreCreditResponse {
        guard Self.isValidStoreCreditRequest(request) else {
            throw Self.invalidStoreKitRequestError
        }

        let token = try await beginStateMutation(requiresAuthenticatedProfile: true)
        do {
            guard let account = await currentStoreAccount(),
                account.profileID == token.playerID,
                account.appAccountToken == request.appAccountToken
            else {
                throw Self.storeKitAccountUnavailableError
            }

            let response: StoreCreditResponse
            #if DEBUG
                if let localStoreKitCreditService {
                    response = try await localStoreKitCreditService.credit(request)
                } else {
                    response = try await submitStoreKitCredit(request)
                }
            #else
                response = try await submitStoreKitCredit(request)
            #endif

            guard isCurrent(token),
                token.playerID == sessionState?.profile?.id,
                await currentStoreAccount() == account,
                response.transactionID == request.transactionID,
                Self.isValidWallet(response.wallet)
            else {
                throw Self.invalidStoreKitResponseError
            }
            applyStoreKitCredit(response)
            finishStateMutation(token)
            return response
        } catch {
            finishStateMutation(token)
            if let backendError = error as? BackendError,
                backendError.status == 401 || backendError.status == 403
            {
                _ = try? await loadSession()
            }
            throw error
        }
    }

    @discardableResult
    func loadSession() async throws -> SessionResponse {
        if let uiTestSession { return uiTestSession }
        guard activeStateMutationEpoch == nil else { throw Self.stateMutationBusyError }

        if let sessionLoadTask, let activeSessionLoadID {
            return try await awaitSessionLoad(sessionLoadTask, id: activeSessionLoadID)
        }

        nextSessionLoadID += 1
        let loadID = nextSessionLoadID
        let epoch = sessionStateEpoch
        let task = Task { @MainActor [weak self] () throws -> SessionResponse in
            guard let self else { throw Self.staleSessionError }
            let response: SessionResponse = try await request(path: "/api/session")
            try Task.checkCancellation()
            guard sessionStateEpoch == epoch else { throw Self.staleSessionError }
            applySessionResponse(response)
            return response
        }

        sessionLoadTask = task
        activeSessionLoadID = loadID
        isLoadingSession = true
        return try await awaitSessionLoad(task, id: loadID)
    }

    func loadLeaderboard(mode: GameMode) async throws -> LeaderboardResponse {
        if isUITestOffline {
            let arguments = ProcessInfo.processInfo.arguments
            let exposesScreenshotLeaderboard =
                ScreenshotFixture.resolve(arguments: arguments)?.destination == .leaderboard
            if exposesScreenshotLeaderboard, let profile = uiTestSession?.profile {
                return Self.screenshotLeaderboard(mode: mode, playerName: profile.nickname)
            }
            if arguments.contains("--ui-test-leaderboard-fixture"),
                let profile = uiTestSession?.profile
            {
                return Self.uiTestLeaderboard(mode: mode, playerName: profile.nickname)
            }
            return LeaderboardResponse(
                season: uiTestSession?.season ?? Self.uiTestSignedOutSession.season,
                mode: mode.rawValue,
                entries: [],
                totalEntries: 0,
                playerRank: nil,
                topPercent: nil,
                contextRank: nil,
                contextTopPercent: nil,
                contextEntryId: nil
            )
        }
        return try await request(path: "/api/leaderboard?mode=\(mode.rawValue)")
    }

    func loadProfile(mode: GameMode) async throws -> ProfileResponse {
        if isUITestOffline {
            guard let profile = uiTestSession?.profile else {
                throw Self.authenticationRequiredError
            }
            let leaderboard = Self.uiTestLeaderboard(mode: mode, playerName: profile.nickname)
            return ProfileResponse(
                profile: profile,
                identityBindings: uiTestSession?.identityBindings,
                ranks: [
                    GameMode.arcade.rawValue: RankInfo(rank: 6, totalEntries: 42, topPercent: 15),
                    GameMode.zen.rawValue: RankInfo(rank: nil, totalEntries: 8, topPercent: nil),
                ],
                leaderboard: leaderboard
            )
        }
        let epoch = sessionStateEpoch
        let playerID = sessionState?.profile?.id
        let response: ProfileResponse = try await request(
            path: "/api/profile?mode=\(mode.rawValue)"
        )
        guard epoch == sessionStateEpoch,
            playerID != nil,
            response.profile.id == playerID,
            sessionState?.profile?.id == playerID
        else {
            throw Self.staleSessionError
        }
        replaceProfile(
            response.profile,
            identityBindings: response.identityBindings,
            gameCenter: response.gameCenter,
            ranks: response.ranks
        )
        return response
    }

    func loadThemes() async throws -> ThemeCatalogResponse {
        if isUITestOffline {
            return ThemeCatalogResponse(
                themes: Self.uiTestThemes.themes,
                profile: uiTestSession?.profile,
                coinBalance: uiTestSession?.profile?.coins ?? 0
            )
        }
        return try await request(path: "/api/themes")
    }

    func loadPets() async throws -> PetCatalogResponse {
        if isUITestOffline {
            return PetCatalogResponse(
                pets: Self.uiTestPets.pets,
                profile: uiTestSession?.profile,
                coinBalance: uiTestSession?.profile?.coins ?? 0
            )
        }
        return try await request(path: "/api/pets")
    }

    func loadAchievements() async throws -> AchievementsResponse {
        if isUITestOffline {
            return uiTestAchievements
                ?? Self.uiTestAchievementResponse(
                    session: uiTestSession,
                    exposesClaimableFixture: false
                )
        }

        let epoch = sessionStateEpoch
        let playerID = sessionState?.profile?.id
        let response: AchievementsResponse = try await request(path: "/api/achievements")
        guard Self.isValidAchievementCatalog(response) else {
            throw Self.invalidAchievementResponseError
        }
        if response.authenticated != isAuthenticated {
            let refreshedSession = try await loadSession()
            guard response.authenticated == refreshedSession.authenticated else {
                throw Self.invalidAchievementResponseError
            }
        }
        guard epoch == sessionStateEpoch, playerID == sessionState?.profile?.id else {
            throw Self.staleSessionError
        }
        if response.authenticated,
            let profile = sessionState?.profile,
            profile.id == playerID,
            response.coinBalance >= 0
        {
            replaceProfile(replacingCoins(in: profile, with: response.coinBalance))
        }
        return response
    }

    @discardableResult
    func claimAchievement(_ achievementID: String) async throws -> AchievementsResponse {
        let id = achievementID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { throw Self.invalidAchievementError }
        if isUITestOffline { return try uiTestClaimAchievement(id) }

        let body = try encoder.encode(["id": id])
        let token = try await beginStateMutation(requiresAuthenticatedProfile: true)
        do {
            let response: AchievementsResponse = try await request(
                path: "/api/achievements/claim",
                method: "POST",
                body: body,
                csrf: csrfToken
            )
            guard isCurrent(token),
                token.playerID == sessionState?.profile?.id
            else {
                throw Self.staleSessionError
            }
            guard
                Self.isValidAchievementCatalog(response),
                response.authenticated,
                let claimedAchievement = response.achievement,
                claimedAchievement.id == id,
                claimedAchievement.state == .claimed,
                response.achievements.contains(where: {
                    $0.id == id && $0.state == .claimed
                }),
                let coinsEarned = response.coinsEarned,
                coinsEarned >= 0,
                response.duplicate != nil
            else {
                throw Self.invalidAchievementResponseError
            }
            if let currentProfile = sessionState?.profile {
                replaceProfile(replacingCoins(in: currentProfile, with: response.coinBalance))
            }
            finishStateMutation(token)
            return response
        } catch {
            finishStateMutation(token)
            if let backendError = error as? BackendError,
                backendError.status == 401 || backendError.status == 403
            {
                _ = try? await loadSession()
            }
            throw error
        }
    }

    @discardableResult
    func login(googleIDToken: String) async throws -> SessionResponse {
        try await authenticateWithGoogle(
            googleIDToken: googleIDToken,
            intent: .login
        )
    }

    @discardableResult
    func registerWithGoogle(googleIDToken: String) async throws -> SessionResponse {
        try await authenticateWithGoogle(
            googleIDToken: googleIDToken,
            intent: .register
        )
    }

    @discardableResult
    func reauthenticateWithGoogle(
        googleIDToken: String,
        expectedPlayerID: String
    ) async throws -> SessionResponse {
        let response = try await authenticateWithGoogle(
            googleIDToken: googleIDToken,
            intent: .reauth
        )
        try await requireSameAuthenticatedPlayer(
            response,
            expectedPlayerID: expectedPlayerID
        )
        return response
    }

    @discardableResult
    private func authenticateWithGoogle(
        googleIDToken: String,
        intent: PrimaryAuthenticationIntent
    ) async throws -> SessionResponse {
        guard intent != .link else { throw Self.invalidAuthenticationIntentError }
        if isUITestOffline {
            #if DEBUG
                guard
                    intent == .reauth,
                    isAccountDeletionUITestFixtureEnabled,
                    googleIDToken == Self.uiTestAccountDeletionCredential,
                    let uiTestSession,
                    uiTestSession.authenticated,
                    uiTestSession.profile != nil
                else { throw Self.uiTestOfflineError }
                return uiTestSession
            #else
                throw Self.uiTestOfflineError
            #endif
        }

        let body = try encoder.encode([
            "credential": googleIDToken,
            "intent": intent.rawValue,
        ])
        let token = try await beginStateMutation(
            requiresAuthenticatedProfile: intent == .reauth
        )
        do {
            let response: SessionResponse = try await request(
                path: "/api/auth/google",
                method: "POST",
                body: body,
                csrf: csrfToken
            )
            guard isCurrent(token), response.authenticated, response.profile != nil else {
                throw Self.invalidAuthenticationResponseError
            }
            applySessionResponse(response)
            finishStateMutation(token)
            return response
        } catch {
            finishStateMutation(token)
            throw error
        }
    }

    @discardableResult
    func reauthenticateForAccountDeletion(
        googleIDToken: String,
        expectedPlayerID: String
    ) async throws -> SessionResponse {
        try await reauthenticateWithGoogle(
            googleIDToken: googleIDToken,
            expectedPlayerID: expectedPlayerID
        )
    }

    @discardableResult
    func linkGoogle(
        googleIDToken: String,
        expectedPlayerID: String
    ) async throws -> SessionResponse {
        let body = try encoder.encode(["credential": googleIDToken])
        let token = try await beginStateMutation(requiresAuthenticatedProfile: true)
        do {
            guard token.playerID == expectedPlayerID else {
                throw Self.accountAuthenticationMismatchError
            }
            let response: SessionResponse = try await request(
                path: "/api/profile/identities/google",
                method: "POST",
                body: body,
                csrf: csrfToken
            )
            guard isCurrent(token),
                response.authenticated,
                response.profile?.id == expectedPlayerID,
                response.identityBindings?.google == true
            else {
                throw Self.invalidIdentityLinkResponseError
            }
            applySessionResponse(response)
            finishStateMutation(token)
            return response
        } catch {
            finishStateMutation(token)
            throw error
        }
    }

    func issueAppleSignInChallenge(
        intent: PrimaryAuthenticationIntent
    ) async throws -> AppleSignInChallenge {
        guard !isUITestOffline else { throw Self.uiTestOfflineError }
        if csrfToken == nil { _ = try await loadSession() }
        guard activeStateMutationEpoch == nil else { throw Self.stateMutationBusyError }

        let epoch = sessionStateEpoch
        let playerID = sessionState?.profile?.id
        let response: AppleSignInChallengeResponse = try await request(
            path: "/api/auth/apple/challenge",
            method: "POST",
            body: try encoder.encode(["intent": intent.rawValue]),
            csrf: csrfToken
        )
        let challenge = response.appleSignIn
        let configuredAudience = sessionState?.appleSignIn?.clientId
        guard epoch == sessionStateEpoch,
            playerID == sessionState?.profile?.id,
            challenge.intent == intent,
            configuredAudience == nil || challenge.audience == configuredAudience,
            !challenge.challengeId.isEmpty,
            !challenge.nonce.isEmpty,
            !challenge.state.isEmpty,
            !challenge.audience.isEmpty
        else {
            throw Self.invalidAppleChallengeResponseError
        }
        return challenge
    }

    @discardableResult
    func completeAppleAuthorization(
        challenge: AppleSignInChallenge,
        proof: AppleAuthorizationProof,
        expectedPlayerID: String? = nil
    ) async throws -> SessionResponse {
        struct Body: Encodable {
            let challengeId: String
            let state: String
            let identityToken: String
            let authorizationCode: String
        }

        guard proof.state == challenge.state,
            !proof.identityToken.isEmpty,
            !proof.authorizationCode.isEmpty
        else {
            throw Self.invalidAppleAuthorizationProofError
        }

        let requiresProfile = challenge.intent == .link || challenge.intent == .reauth
        let token = try await beginStateMutation(
            requiresAuthenticatedProfile: requiresProfile
        )
        do {
            if requiresProfile,
                token.playerID != expectedPlayerID
            {
                throw Self.accountAuthenticationMismatchError
            }
            let response: SessionResponse = try await request(
                path: "/api/auth/apple",
                method: "POST",
                body: try encoder.encode(
                    Body(
                        challengeId: challenge.challengeId,
                        state: proof.state,
                        identityToken: proof.identityToken,
                        authorizationCode: proof.authorizationCode
                    )
                ),
                csrf: csrfToken
            )
            guard isCurrent(token), response.authenticated, response.profile != nil else {
                throw Self.invalidAuthenticationResponseError
            }
            if let expectedPlayerID,
                response.profile?.id != expectedPlayerID
            {
                applySessionResponse(response)
                finishStateMutation(token)
                try await requireSameAuthenticatedPlayer(
                    response,
                    expectedPlayerID: expectedPlayerID
                )
                throw Self.accountAuthenticationMismatchError
            }
            if challenge.intent == .link,
                response.identityBindings?.apple != true
            {
                throw Self.invalidIdentityLinkResponseError
            }
            applySessionResponse(response)
            finishStateMutation(token)
            return response
        } catch {
            finishStateMutation(token)
            throw error
        }
    }

    func issueGameCenterLinkChallenge(
        expectedPlayerID: String
    ) async throws -> GameCenterLinkChallenge {
        guard !isUITestOffline else { throw Self.uiTestOfflineError }
        if csrfToken == nil { _ = try await loadSession() }
        guard activeStateMutationEpoch == nil else { throw Self.stateMutationBusyError }
        guard sessionState?.authenticated == true,
            sessionState?.profile?.id == expectedPlayerID
        else {
            throw Self.accountAuthenticationMismatchError
        }

        let epoch = sessionStateEpoch
        let response: GameCenterLinkChallengeResponse = try await request(
            path: "/api/profile/game-center/challenge",
            method: "POST",
            body: Data("{}".utf8),
            csrf: csrfToken
        )
        let challenge = response.gameCenter
        guard epoch == sessionStateEpoch,
            sessionState?.profile?.id == expectedPlayerID,
            !challenge.challengeId.isEmpty
        else {
            throw Self.invalidGameCenterLinkResponseError
        }
        return challenge
    }

    @discardableResult
    func linkGameCenter(
        challenge: GameCenterLinkChallenge,
        verification: GameCenterIdentityVerification,
        expectedPlayerID: String
    ) async throws -> GameCenterLinkResponse {
        struct Body: Encodable {
            let challengeId: String
            let teamPlayerId: String
            let gamePlayerId: String
            let publish: Bool
            let publicKeyUrl: String
            let signature: String
            let salt: String
            let timestamp: UInt64
        }

        guard !verification.signedTeamPlayerID.isEmpty,
            !verification.gamePlayerID.isEmpty,
            verification.publicKeyURL.scheme?.lowercased() == "https",
            !verification.signature.isEmpty,
            !verification.salt.isEmpty,
            verification.timestamp > 0
        else {
            throw Self.invalidGameCenterProofError
        }
        let token = try await beginStateMutation(requiresAuthenticatedProfile: true)
        do {
            guard token.playerID == expectedPlayerID else {
                throw Self.accountAuthenticationMismatchError
            }
            let response: GameCenterLinkResponse = try await request(
                path: "/api/profile/game-center",
                method: "POST",
                body: try encoder.encode(
                    Body(
                        challengeId: challenge.challengeId,
                        teamPlayerId: verification.signedTeamPlayerID,
                        gamePlayerId: verification.gamePlayerID,
                        publish: true,
                        publicKeyUrl: verification.publicKeyURL.absoluteString,
                        signature: verification.signature.base64EncodedString(),
                        salt: verification.salt.base64EncodedString(),
                        timestamp: verification.timestamp
                    )
                ),
                csrf: csrfToken
            )
            guard isCurrent(token),
                response.profile.id == expectedPlayerID,
                response.identityBindings.gameCenter,
                response.gameCenter.identityLinked,
                response.gameCenter.publicationEnabled
            else {
                throw Self.invalidGameCenterLinkResponseError
            }
            replaceProfile(
                response.profile,
                identityBindings: response.identityBindings,
                gameCenter: response.gameCenter
            )
            finishStateMutation(token)
            return response
        } catch {
            finishStateMutation(token)
            throw error
        }
    }

    @discardableResult
    func disableGameCenterPublication(
        expectedPlayerID: String
    ) async throws -> GameCenterPublicationResponse {
        struct Body: Encodable {
            let confirm: Bool
        }

        let token = try await beginStateMutation(requiresAuthenticatedProfile: true)
        do {
            guard token.playerID == expectedPlayerID else {
                throw Self.accountAuthenticationMismatchError
            }
            let response: GameCenterPublicationResponse = try await request(
                path: "/api/profile/game-center/publication",
                method: "DELETE",
                body: try encoder.encode(Body(confirm: true)),
                csrf: csrfToken
            )
            guard isCurrent(token),
                response.gameCenter.identityLinked,
                !response.gameCenter.publicationEnabled
            else {
                throw Self.invalidGameCenterLinkResponseError
            }
            replaceGameCenterStatus(response.gameCenter)
            finishStateMutation(token)
            return response
        } catch {
            finishStateMutation(token)
            throw error
        }
    }

    @discardableResult
    func logout() async throws -> SessionResponse {
        let token = try await beginStateMutation(requiresAuthenticatedProfile: false)
        do {
            let response: SessionResponse = try await request(
                path: "/api/logout",
                method: "POST",
                body: Data("{}".utf8),
                csrf: csrfToken
            )
            guard isCurrent(token) else { throw Self.staleSessionError }
            applySessionResponse(response)
            finishStateMutation(token)
            return response
        } catch {
            finishStateMutation(token)
            throw error
        }
    }

    @discardableResult
    func deleteAccount(
        confirmation: String,
        expectedPlayerID: String
    ) async throws -> AccountDeletionResponse {
        guard confirmation == Self.accountDeletionConfirmation else {
            throw Self.invalidAccountDeletionConfirmationError
        }

        let token = try await beginStateMutation(requiresAuthenticatedProfile: true)
        do {
            guard token.playerID == expectedPlayerID else {
                discardLocalAuthentication()
                throw Self.accountAuthenticationMismatchError
            }
            let response: AccountDeletionResponse
            if isUITestOffline {
                #if DEBUG
                    guard isAccountDeletionUITestFixtureEnabled else {
                        throw Self.uiTestOfflineError
                    }
                    response = AccountDeletionResponse(deleted: true, authenticated: false)
                #else
                    throw Self.uiTestOfflineError
                #endif
            } else {
                response = try await request(
                    path: "/api/profile",
                    method: "DELETE",
                    body: try encoder.encode(["confirmation": confirmation]),
                    csrf: csrfToken
                )
            }

            guard isCurrent(token), token.playerID == sessionState?.profile?.id else {
                throw Self.staleSessionError
            }
            guard response.deleted, !response.authenticated else {
                throw Self.invalidAccountDeletionResponseError
            }

            csrfToken = nil
            lastError = nil
            if isUITestOffline {
                uiTestSession = Self.uiTestSignedOutSession
                sessionState = Self.uiTestSignedOutSession
            } else {
                sessionState = nil
            }
            finishStateMutation(token)
            return response
        } catch {
            finishStateMutation(token)
            throw error
        }
    }

    @discardableResult
    func checkNicknameAvailability(_ nickname: String) async throws
        -> NicknameAvailabilityResponse
    {
        try Self.validatePlayerName(nickname)
        if isUITestOffline {
            return NicknameAvailabilityResponse(nickname: nickname, available: true)
        }
        if csrfToken == nil { _ = try await loadSession() }
        guard sessionState?.authenticated == true,
            let playerID = sessionState?.profile?.id
        else {
            throw Self.authenticationRequiredError
        }

        let epoch = sessionStateEpoch
        let body = try encoder.encode(["nickname": nickname])
        let response: NicknameAvailabilityResponse = try await request(
            path: "/api/profile/nickname/availability",
            method: "POST",
            body: body,
            csrf: csrfToken
        )
        try Task.checkCancellation()
        guard epoch == sessionStateEpoch,
            playerID == sessionState?.profile?.id
        else {
            throw Self.staleSessionError
        }
        guard PlayerNameValidation.localError(for: response.nickname) == nil,
            response.nickname == PlayerNameValidation.serverNormalizedCandidate(nickname)
        else {
            throw Self.invalidNicknameAvailabilityResponseError
        }
        return response
    }

    @discardableResult
    func updateNickname(_ nickname: String) async throws -> ProfileResponse {
        try Self.validatePlayerName(nickname)
        let body = try encoder.encode(["nickname": nickname])
        let token = try await beginStateMutation(requiresAuthenticatedProfile: true)
        do {
            let response: ProfileResponse = try await request(
                path: "/api/profile?mode=normal",
                method: "PATCH",
                body: body,
                csrf: csrfToken
            )
            guard isCurrent(token, responseProfileID: response.profile.id) else {
                throw Self.staleSessionError
            }
            replaceProfile(
                response.profile,
                identityBindings: response.identityBindings,
                gameCenter: response.gameCenter,
                ranks: response.ranks
            )
            finishStateMutation(token)
            return response
        } catch {
            finishStateMutation(token)
            throw error
        }
    }

    @discardableResult
    func selectTheme(_ themeID: String) async throws -> ThemeSelectionResponse {
        let body = try encoder.encode(["themeId": themeID])
        let token = try await beginStateMutation(requiresAuthenticatedProfile: true)
        do {
            let response: ThemeSelectionResponse = try await request(
                path: "/api/themes/select",
                method: "POST",
                body: body,
                csrf: csrfToken
            )
            guard isCurrent(token, responseProfileID: response.profile.id) else {
                throw Self.staleSessionError
            }
            replaceProfile(response.profile)
            finishStateMutation(token)
            return response
        } catch {
            finishStateMutation(token)
            throw error
        }
    }

    @discardableResult
    func selectPet(_ petID: String) async throws -> PetSelectionResponse {
        if isUITestOffline { return try uiTestSelectPet(petID) }
        let body = try encoder.encode(["petId": petID])
        let token = try await beginStateMutation(requiresAuthenticatedProfile: true)
        do {
            let response: PetSelectionResponse = try await request(
                path: "/api/pets/select",
                method: "POST",
                body: body,
                csrf: csrfToken
            )
            guard isCurrent(token, responseProfileID: response.profile.id) else {
                throw Self.staleSessionError
            }
            replaceProfile(response.profile)
            finishStateMutation(token)
            return response
        } catch {
            finishStateMutation(token)
            throw error
        }
    }

    @discardableResult
    func setPetVisibility(_ petID: String, visible: Bool) async throws -> PetVisibilityResponse {
        if isUITestOffline { return try uiTestSetPetVisibility(petID, visible: visible) }

        struct Body: Encodable {
            let petId: String
            let visible: Bool
        }

        let body = try encoder.encode(Body(petId: petID, visible: visible))
        let token = try await beginStateMutation(requiresAuthenticatedProfile: true)
        do {
            let response: PetVisibilityResponse = try await request(
                path: "/api/pets/selection",
                method: "PATCH",
                body: body,
                csrf: csrfToken
            )
            guard isCurrent(token, responseProfileID: response.profile.id) else {
                throw Self.staleSessionError
            }
            replaceProfile(response.profile)
            finishStateMutation(token)
            return response
        } catch {
            finishStateMutation(token)
            throw error
        }
    }

    @discardableResult
    func synchronizeProfileFromCatalog(_ profile: PlayerProfile) -> Bool {
        guard activeStateMutationEpoch == nil,
            sessionState?.authenticated == true,
            sessionState?.profile?.id == profile.id
        else { return false }
        replaceProfile(profile)
        return true
    }

    func startRun() async throws -> RunTicket {
        if isUITestOffline {
            guard canStartRankedRun else { throw Self.authenticationRequiredError }
            return RunTicket(
                runId: "00000000-0000-4000-8000-000000000001",
                mode: GameMode.arcade.rawValue,
                buildId: Self.deployedBuildID,
                ruleset: Self.rankedRuleset,
                proofVersion: Self.rankedProofVersion
            )
        }
        let body = try encoder.encode([
            "mode": GameMode.arcade.rawValue,
            "buildId": Self.deployedBuildID,
        ])
        let ticket: RunTicket = try await mutation(
            path: "/api/runs",
            method: "POST",
            body: body
        )
        guard ticket.mode == GameMode.arcade.rawValue,
            ticket.buildId == Self.deployedBuildID,
            ticket.ruleset == Self.rankedRuleset,
            ticket.proofVersion == Self.rankedProofVersion
        else {
            throw Self.invalidRunTicketResponseError
        }
        return ticket
    }

    func abandonRun(_ runID: String) async {
        guard let body = try? encoder.encode(["runId": runID]) else { return }
        let _: APIMessage? = try? await mutation(
            path: "/api/runs/abandon",
            method: "POST",
            body: body
        )
    }

    func finishRun(ticket: RunTicket, events: [[Int]]) async throws -> RunFinishResponse {
        if isUITestOffline {
            guard !events.isEmpty else { throw Self.invalidRunFinishResponseError }
            return RunFinishResponse(
                rank: 6,
                submittedRank: 6,
                submittedEntryId: ticket.runId,
                improved: true,
                duplicate: false,
                verificationStatus: "verified",
                coinsEarned: 0,
                coinBalance: profile?.coins,
                totalPlayMs: profile?.totalPlayMs
            )
        }
        let payload = RunProofPayload(
            runId: ticket.runId,
            mode: ticket.mode,
            buildId: ticket.buildId,
            ruleset: ticket.ruleset,
            proofVersion: ticket.proofVersion,
            events: events
        )
        let response: RunFinishResponse = try await mutation(
            path: "/api/runs/finish",
            method: "POST",
            body: try encoder.encode(payload)
        )
        guard response.confirmsPersistence(of: ticket.runId) else {
            throw Self.invalidRunFinishResponseError
        }
        return response
    }

    private struct StateMutationToken {
        let epoch: Int
        let playerID: String?
    }

    private struct StoreKitCreditBody: Encodable {
        let signedTransaction: String
        let appAccountToken: String
    }

    private func awaitSessionLoad(
        _ task: Task<SessionResponse, Error>,
        id: Int
    ) async throws -> SessionResponse {
        do {
            let response = try await task.value
            finishSessionLoad(id: id)
            return response
        } catch {
            if activeSessionLoadID == id {
                lastError = error.localizedDescription
            }
            finishSessionLoad(id: id)
            throw error
        }
    }

    private func finishSessionLoad(id: Int) {
        guard activeSessionLoadID == id else { return }
        sessionLoadTask = nil
        activeSessionLoadID = nil
        isLoadingSession = false
    }

    private func beginStateMutation(
        requiresAuthenticatedProfile: Bool
    ) async throws -> StateMutationToken {
        if csrfToken == nil { _ = try await loadSession() }
        guard activeStateMutationEpoch == nil else { throw Self.stateMutationBusyError }
        let playerID = sessionState?.profile?.id
        if requiresAuthenticatedProfile,
            sessionState?.authenticated != true || playerID == nil
        {
            throw Self.authenticationRequiredError
        }

        sessionStateEpoch += 1
        sessionLoadTask?.cancel()
        sessionLoadTask = nil
        activeSessionLoadID = nil
        isLoadingSession = false
        let token = StateMutationToken(epoch: sessionStateEpoch, playerID: playerID)
        activeStateMutationEpoch = token.epoch
        return token
    }

    private func finishStateMutation(_ token: StateMutationToken) {
        if activeStateMutationEpoch == token.epoch {
            activeStateMutationEpoch = nil
        }
    }

    private func isCurrent(_ token: StateMutationToken) -> Bool {
        token.epoch == sessionStateEpoch && activeStateMutationEpoch == token.epoch
    }

    private func isCurrent(
        _ token: StateMutationToken,
        responseProfileID: String
    ) -> Bool {
        isCurrent(token)
            && token.playerID != nil
            && token.playerID == responseProfileID
            && token.playerID == sessionState?.profile?.id
    }

    private func applySessionResponse(_ response: SessionResponse) {
        csrfToken = response.csrfToken
        sessionState = response
        lastError = nil
    }

    private func discardLocalAuthentication() {
        sessionStateEpoch += 1
        sessionLoadTask?.cancel()
        sessionLoadTask = nil
        activeSessionLoadID = nil
        activeStateMutationEpoch = nil
        isLoadingSession = false
        csrfToken = nil
        sessionState = nil
        lastError = nil

        guard let host = baseURL.host,
            let cookieStorage = urlSession.configuration.httpCookieStorage
        else { return }
        for cookie in cookieStorage.cookies ?? []
        where cookie.domain == host || cookie.domain == ".\(host)" {
            cookieStorage.deleteCookie(cookie)
        }
    }

    private func requireSameAuthenticatedPlayer(
        _ response: SessionResponse,
        expectedPlayerID: String
    ) async throws {
        guard response.authenticated, response.profile?.id == expectedPlayerID else {
            do {
                let loggedOut = try await logout()
                if loggedOut.authenticated || loggedOut.profile != nil {
                    discardLocalAuthentication()
                }
            } catch {
                discardLocalAuthentication()
            }
            throw Self.accountAuthenticationMismatchError
        }
    }

    #if DEBUG
        private var isAccountDeletionUITestFixtureEnabled: Bool {
            let arguments = ProcessInfo.processInfo.arguments
            return isUITestOffline
                && arguments.contains("--uitesting")
                && arguments.contains("--ui-test-account-deletion")
        }
    #endif

    private func mutation<Response: Decodable>(
        path: String,
        method: String,
        body: Data
    ) async throws -> Response {
        guard !isUITestOffline else { throw Self.uiTestOfflineError }
        if csrfToken == nil { _ = try await loadSession() }
        return try await request(path: path, method: method, body: body, csrf: csrfToken)
    }

    private func submitStoreKitCredit(
        _ creditRequest: StoreCreditRequest
    ) async throws -> StoreCreditResponse {
        let body = StoreKitCreditBody(
            signedTransaction: creditRequest.signedTransaction,
            appAccountToken: creditRequest.appAccountToken.uuidString.lowercased()
        )
        let response: StoreKitCreditAPIResponse = try await request(
            path: "/api/mobile/v1/storekit/transactions",
            method: "POST",
            body: try encoder.encode(body),
            csrf: csrfToken
        )
        guard response.transactionId == creditRequest.transactionID,
            let wallet = response.wallet,
            Self.isValidWallet(wallet)
        else {
            throw Self.invalidStoreKitResponseError
        }

        let disposition: StoreCreditDisposition
        if response.duplicate {
            disposition = .duplicate
        } else {
            switch response.status {
            case "active":
                disposition = .credited
            case "reinstated":
                disposition = .reconciled
            case "refunded", "revoked":
                disposition = .reversed
            default:
                throw Self.invalidStoreKitResponseError
            }
        }
        guard ["active", "reinstated", "refunded", "revoked"].contains(response.status),
            !["active", "reinstated"].contains(response.status) || response.adFree
        else {
            throw Self.invalidStoreKitResponseError
        }

        return StoreCreditResponse(
            transactionID: response.transactionId,
            disposition: disposition,
            wallet: wallet,
            adFree: response.adFree
        )
    }

    private func request<Response: Decodable>(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        csrf: String? = nil
    ) async throws -> Response {
        guard !isUITestOffline else { throw Self.uiTestOfflineError }
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw BackendError(status: 0, message: "The service URL is invalid.", code: nil)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let csrf {
            request.setValue(csrf, forHTTPHeaderField: "X-SpeedyTapper-CSRF")
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendError(status: 0, message: "The service returned no HTTP response.", code: nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            let payload = try? decoder.decode(APIErrorPayload.self, from: data)
            throw BackendError(
                status: http.statusCode,
                message: payload?.error ?? "PimPoPom services are temporarily unavailable.",
                code: payload?.code
            )
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw BackendError(
                status: http.statusCode,
                message: "The service response could not be read.",
                code: "invalid-response"
            )
        }
    }

    private func replaceProfile(
        _ profile: PlayerProfile,
        identityBindings: IdentityBindings? = nil,
        gameCenter: GameCenterServerStatus? = nil,
        ranks: [String: RankInfo]? = nil
    ) {
        guard let sessionState else { return }
        lastError = nil
        let wallet = sessionState.wallet.flatMap { existing in
            existing.total == profile.coins ? existing : nil
        }
        let updatedSession = SessionResponse(
            authenticated: true,
            csrfToken: sessionState.csrfToken,
            googleClientId: sessionState.googleClientId,
            appleSignIn: sessionState.appleSignIn,
            season: sessionState.season,
            profile: profile,
            identityBindings: identityBindings ?? sessionState.identityBindings,
            gameCenter: gameCenter ?? sessionState.gameCenter,
            wallet: wallet,
            adFree: sessionState.adFree,
            storeKit: sessionState.storeKit,
            ranks: ranks ?? sessionState.ranks
        )
        self.sessionState = updatedSession
        if isUITestOffline { uiTestSession = updatedSession }
    }

    private func replaceGameCenterStatus(_ gameCenter: GameCenterServerStatus) {
        guard let sessionState else { return }
        let updatedSession = SessionResponse(
            authenticated: sessionState.authenticated,
            csrfToken: sessionState.csrfToken,
            googleClientId: sessionState.googleClientId,
            appleSignIn: sessionState.appleSignIn,
            season: sessionState.season,
            profile: sessionState.profile,
            identityBindings: sessionState.identityBindings,
            gameCenter: gameCenter,
            wallet: sessionState.wallet,
            adFree: sessionState.adFree,
            storeKit: sessionState.storeKit,
            ranks: sessionState.ranks
        )
        self.sessionState = updatedSession
        lastError = nil
        if isUITestOffline { uiTestSession = updatedSession }
    }

    private func applyStoreKitCredit(_ response: StoreCreditResponse) {
        guard let sessionState,
            sessionState.authenticated,
            let profile = sessionState.profile
        else { return }
        let updatedSession = SessionResponse(
            authenticated: true,
            csrfToken: sessionState.csrfToken,
            googleClientId: sessionState.googleClientId,
            appleSignIn: sessionState.appleSignIn,
            season: sessionState.season,
            profile: replacingCoins(in: profile, with: response.wallet.total),
            identityBindings: sessionState.identityBindings,
            gameCenter: sessionState.gameCenter,
            wallet: response.wallet,
            adFree: response.adFree,
            storeKit: sessionState.storeKit,
            ranks: sessionState.ranks
        )
        self.sessionState = updatedSession
        lastError = nil
        if isUITestOffline { uiTestSession = updatedSession }
    }

    private func uiTestSelectPet(_ petID: String) throws -> PetSelectionResponse {
        guard let profile = uiTestSession?.profile,
            profile.ownedPetIds.contains(petID)
        else { throw Self.uiTestOfflineError }

        let updated = uiTestProfile(
            from: profile,
            selectedPetID: petID,
            visible: true
        )
        replaceProfile(updated)
        return PetSelectionResponse(
            profile: updated,
            pet: PetSelectionResult(id: petID, purchased: false, pricePaid: 0),
            coinBalance: updated.coins
        )
    }

    private func uiTestSetPetVisibility(
        _ petID: String,
        visible: Bool
    ) throws -> PetVisibilityResponse {
        guard let profile = uiTestSession?.profile,
            profile.selectedPetId == petID,
            profile.ownedPetIds.contains(petID)
        else { throw Self.uiTestOfflineError }

        let updated = uiTestProfile(
            from: profile,
            selectedPetID: petID,
            visible: visible
        )
        replaceProfile(updated)
        return PetVisibilityResponse(
            profile: updated,
            pet: PetVisibilityResult(id: petID, visible: visible),
            coinBalance: updated.coins
        )
    }

    private func uiTestProfile(
        from profile: PlayerProfile,
        selectedPetID: String,
        visible: Bool
    ) -> PlayerProfile {
        PlayerProfile(
            id: profile.id,
            nickname: profile.nickname,
            nicknameConfirmed: profile.nicknameConfirmed,
            coins: profile.coins,
            totalPlayMs: profile.totalPlayMs,
            ownedPetIds: profile.ownedPetIds,
            selectedPetId: selectedPetID,
            petVisible: visible,
            equippedPetId: profile.specialPetId ?? (visible ? selectedPetID : nil),
            specialPetId: profile.specialPetId,
            ownedThemeIds: profile.ownedThemeIds,
            selectedThemeId: profile.selectedThemeId,
            isAdmin: profile.isAdmin,
            createdAt: profile.createdAt,
            updatedAt: profile.updatedAt
        )
    }

    private func replacingCoins(
        in profile: PlayerProfile,
        with coins: Int
    ) -> PlayerProfile {
        PlayerProfile(
            id: profile.id,
            nickname: profile.nickname,
            nicknameConfirmed: profile.nicknameConfirmed,
            coins: coins,
            totalPlayMs: profile.totalPlayMs,
            ownedPetIds: profile.ownedPetIds,
            selectedPetId: profile.selectedPetId,
            petVisible: profile.petVisible,
            equippedPetId: profile.equippedPetId,
            specialPetId: profile.specialPetId,
            ownedThemeIds: profile.ownedThemeIds,
            selectedThemeId: profile.selectedThemeId,
            isAdmin: profile.isAdmin,
            createdAt: profile.createdAt,
            updatedAt: profile.updatedAt
        )
    }

    private static func isValidAchievementCatalog(_ response: AchievementsResponse) -> Bool {
        let items = response.achievements
        return response.coinBalance >= 0
            && response.claimedCount >= 0
            && response.totalCount == items.count
            && response.claimedCount == items.filter { $0.state == .claimed }.count
            && Set(items.map(\.id)).count == items.count
            && items.allSatisfy {
                !$0.id.isEmpty
                    && !$0.title.isEmpty
                    && !$0.description.isEmpty
                    && $0.rewardCoins > 0
            }
    }

    private func uiTestClaimAchievement(_ achievementID: String) throws -> AchievementsResponse {
        guard let current = uiTestAchievements,
            let item = current.achievements.first(where: { $0.id == achievementID })
        else { throw Self.invalidAchievementError }
        guard item.state != .locked else {
            throw BackendError(
                status: 409,
                message: "Complete this achievement before claiming its coins.",
                code: "achievement-locked"
            )
        }
        guard let currentProfile = uiTestSession?.profile else {
            throw Self.authenticationRequiredError
        }

        let duplicate = item.state == .claimed
        let coinsEarned = duplicate ? 0 : item.rewardCoins
        let claimed = AchievementItem(
            id: item.id,
            title: item.title,
            description: item.description,
            rewardCoins: item.rewardCoins,
            state: .claimed,
            unlockedAt: item.unlockedAt ?? "2026-07-17T00:00:00.000Z",
            claimedAt: item.claimedAt ?? "2026-07-17T00:00:01.000Z"
        )
        let items = current.achievements.map { $0.id == achievementID ? claimed : $0 }
        let coinBalance = currentProfile.coins + coinsEarned
        let response = AchievementsResponse(
            authenticated: true,
            achievements: items,
            claimedCount: items.filter { $0.state == .claimed }.count,
            totalCount: items.count,
            coinBalance: coinBalance,
            achievement: claimed,
            coinsEarned: coinsEarned,
            duplicate: duplicate
        )
        uiTestAchievements = response
        replaceProfile(replacingCoins(in: currentProfile, with: coinBalance))
        return response
    }

    private static var selectedUITestSession: SessionResponse {
        #if DEBUG
            if let screenshotFixture = ScreenshotFixture.resolve(
                arguments: ProcessInfo.processInfo.arguments
            ) {
                if screenshotFixture.destination == .profile {
                    return uiTestSignedOutSession
                }
                return uiTestScreenshotSession(fixture: screenshotFixture)
            } else if ProcessInfo.processInfo.arguments.contains("--ui-test-ad-free") {
                return uiTestAdFreeSession
            } else if ProcessInfo.processInfo.arguments.contains("--ui-test-storekit-profile") {
                return uiTestStoreKitSession
            }
        #endif
        if ProcessInfo.processInfo.arguments.contains("--ui-test-achievements-profile") {
            return uiTestAchievementSession
        } else if ProcessInfo.processInfo.arguments.contains("--ui-test-pancake-profile") {
            return uiTestPancakeSession
        } else if ProcessInfo.processInfo.arguments.contains("--ui-test-pet-profile") {
            return uiTestPetSession
        } else {
            return uiTestSignedOutSession
        }
    }

    #if DEBUG
        private static func uiTestScreenshotSession(
            fixture: ScreenshotFixture
        ) -> SessionResponse {
            let petID = fixture.petID
            let profile = PlayerProfile(
                id: "00000000-0000-4000-8000-000000000099",
                nickname: "PimPoPlayer",
                nicknameConfirmed: true,
                coins: 999,
                totalPlayMs: 420_000,
                ownedPetIds: ["foka", "kesha", "tauta", "misha", "pancake"],
                selectedPetId: petID,
                petVisible: petID != nil,
                equippedPetId: petID,
                specialPetId: nil,
                ownedThemeIds: ["classic", "disco", "light", "pixel"],
                selectedThemeId: fixture.themeID,
                isAdmin: false,
                createdAt: "2026-07-24T00:00:00Z",
                updatedAt: "2026-07-24T00:00:00Z"
            )
            return SessionResponse(
                authenticated: true,
                csrfToken: "screenshot-fixture-offline",
                googleClientId: "placeholder.apps.googleusercontent.com",
                appleSignIn: uiTestAppleConfiguration,
                season: Season(id: "screenshot-fixture", name: "Screenshot Fixture"),
                profile: profile,
                identityBindings: uiTestPrimaryBindings,
                wallet: StoreWalletSummary(
                    earned: 999,
                    purchased: 0,
                    earnedDebt: 0,
                    refundDebt: 0,
                    total: 999
                ),
                adFree: true,
                storeKit: nil,
                ranks: [
                    GameMode.arcade.rawValue: RankInfo(
                        rank: 6,
                        totalEntries: 42,
                        topPercent: 15
                    ),
                    GameMode.zen.rawValue: RankInfo(
                        rank: nil,
                        totalEntries: 0,
                        topPercent: nil
                    ),
                ]
            )
        }
    #endif

    private static let uiTestAppleConfiguration = AppleSignInConfiguration(
        enabled: true,
        clientId: "com.otcsoftware.pimpopom"
    )

    private static let uiTestGoogleBindings = IdentityBindings(
        google: true,
        apple: false,
        gameCenter: false
    )

    private static var uiTestPrimaryBindings: IdentityBindings {
        if ProcessInfo.processInfo.arguments.contains("--ui-test-both-linked") {
            return IdentityBindings(google: true, apple: true, gameCenter: false)
        }
        return uiTestGoogleBindings
    }

    private static let uiTestSignedOutSession = SessionResponse(
        authenticated: false,
        csrfToken: "ui-test-offline",
        googleClientId: "placeholder.apps.googleusercontent.com",
        appleSignIn: uiTestAppleConfiguration,
        season: Season(id: "ui-test", name: "Offline UI Test"),
        profile: nil,
        ranks: nil
    )

    #if DEBUG
        private static let uiTestStoreKitSession = SessionResponse(
            authenticated: true,
            csrfToken: "local-storekit-offline",
            googleClientId: "placeholder.apps.googleusercontent.com",
            appleSignIn: uiTestAppleConfiguration,
            season: Season(id: "local-storekit", name: "Local StoreKit"),
            profile: PlayerProfile(
                id: LocalStoreKitCreditService.account.profileID,
                nickname: "StoreKit Tester",
                nicknameConfirmed: true,
                coins: 75,
                totalPlayMs: 120_000,
                ownedPetIds: ["foka"],
                selectedPetId: "foka",
                petVisible: true,
                equippedPetId: "foka",
                specialPetId: nil,
                ownedThemeIds: ["classic", "disco", "light", "pixel"],
                selectedThemeId: "classic",
                isAdmin: false,
                createdAt: "2026-07-19T00:00:00Z",
                updatedAt: "2026-07-19T00:00:00Z"
            ),
            identityBindings: uiTestPrimaryBindings,
            wallet: StoreWalletSummary(
                earned: 75,
                purchased: 0,
                earnedDebt: 0,
                refundDebt: 0,
                total: 75
            ),
            adFree: false,
            storeKit: StoreKitBindingResponse(
                appAccountToken: LocalStoreKitCreditService.account.appAccountToken.uuidString
                    .lowercased(),
                bindingStatus: "bound"
            ),
            ranks: [
                GameMode.arcade.rawValue: RankInfo(rank: 6, totalEntries: 30, topPercent: 20),
                GameMode.zen.rawValue: RankInfo(rank: nil, totalEntries: 0, topPercent: nil),
            ]
        )

        private static var uiTestAdFreeSession: SessionResponse {
            SessionResponse(
                authenticated: uiTestStoreKitSession.authenticated,
                csrfToken: uiTestStoreKitSession.csrfToken,
                googleClientId: uiTestStoreKitSession.googleClientId,
                appleSignIn: uiTestStoreKitSession.appleSignIn,
                season: uiTestStoreKitSession.season,
                profile: uiTestStoreKitSession.profile,
                identityBindings: uiTestStoreKitSession.identityBindings,
                wallet: uiTestStoreKitSession.wallet,
                adFree: true,
                storeKit: uiTestStoreKitSession.storeKit,
                ranks: uiTestStoreKitSession.ranks
            )
        }
    #endif

    private static let uiTestPetSession = SessionResponse(
        authenticated: true,
        csrfToken: "ui-test-offline",
        googleClientId: "placeholder.apps.googleusercontent.com",
        appleSignIn: uiTestAppleConfiguration,
        season: Season(id: "ui-test", name: "Offline UI Test"),
        profile: PlayerProfile(
            id: "ui-test-player",
            nickname: "Owner",
            nicknameConfirmed: true,
            coins: 75,
            totalPlayMs: 120_000,
            ownedPetIds: ["foka", "kesha"],
            selectedPetId: "foka",
            petVisible: true,
            equippedPetId: "muse",
            specialPetId: "muse",
            ownedThemeIds: ["classic", "disco"],
            selectedThemeId: "classic",
            isAdmin: false,
            createdAt: "2026-07-15T00:00:00Z",
            updatedAt: "2026-07-15T00:00:00Z"
        ),
        identityBindings: uiTestPrimaryBindings,
        ranks: [
            GameMode.arcade.rawValue: RankInfo(rank: 6, totalEntries: 30, topPercent: 20),
            GameMode.zen.rawValue: RankInfo(rank: nil, totalEntries: 0, topPercent: nil),
        ]
    )

    private static let uiTestPancakeSession = SessionResponse(
        authenticated: true,
        csrfToken: "ui-test-offline",
        googleClientId: "placeholder.apps.googleusercontent.com",
        appleSignIn: uiTestAppleConfiguration,
        season: Season(id: "ui-test", name: "Offline UI Test"),
        profile: PlayerProfile(
            id: "ui-test-pancake-player",
            nickname: "PancakePilot",
            nicknameConfirmed: true,
            coins: 75,
            totalPlayMs: 120_000,
            ownedPetIds: ["pancake"],
            selectedPetId: "pancake",
            petVisible: true,
            equippedPetId: "pancake",
            specialPetId: nil,
            ownedThemeIds: ["classic", "disco", "light", "pixel"],
            selectedThemeId: "classic",
            isAdmin: false,
            createdAt: "2026-07-15T00:00:00Z",
            updatedAt: "2026-07-15T00:00:00Z"
        ),
        identityBindings: uiTestPrimaryBindings,
        ranks: [
            GameMode.arcade.rawValue: RankInfo(rank: 6, totalEntries: 30, topPercent: 20),
            GameMode.zen.rawValue: RankInfo(rank: nil, totalEntries: 0, topPercent: nil),
        ]
    )

    private static let uiTestAchievementSession = SessionResponse(
        authenticated: true,
        csrfToken: "ui-test-offline",
        googleClientId: "placeholder.apps.googleusercontent.com",
        appleSignIn: uiTestAppleConfiguration,
        season: Season(id: "ui-test", name: "Offline UI Test"),
        profile: PlayerProfile(
            id: "ui-test-achievement-player",
            nickname: "RewardRunner",
            nicknameConfirmed: true,
            coins: 9,
            totalPlayMs: 120_000,
            ownedPetIds: ["foka"],
            selectedPetId: "foka",
            petVisible: true,
            equippedPetId: "foka",
            specialPetId: nil,
            ownedThemeIds: ["classic", "disco", "light", "pixel"],
            selectedThemeId: "classic",
            isAdmin: false,
            createdAt: "2026-07-15T00:00:00Z",
            updatedAt: "2026-07-15T00:00:00Z"
        ),
        identityBindings: uiTestPrimaryBindings,
        ranks: [
            GameMode.arcade.rawValue: RankInfo(rank: 6, totalEntries: 30, topPercent: 20),
            GameMode.zen.rawValue: RankInfo(rank: nil, totalEntries: 0, topPercent: nil),
        ]
    )

    private static func uiTestAchievementResponse(
        session: SessionResponse?,
        exposesClaimableFixture: Bool
    ) -> AchievementsResponse {
        guard exposesClaimableFixture, session?.authenticated == true else {
            return AchievementCatalog.lockedResponse(
                authenticated: session?.authenticated == true,
                coinBalance: session?.profile?.coins ?? 0
            )
        }

        let items = AchievementCatalog.definitions.map { item in
            let state: AchievementState =
                switch item.id {
                case "complete_arcade": .claimable
                case "godlike_speed": .claimed
                default: .locked
                }
            return AchievementItem(
                id: item.id,
                title: item.title,
                description: item.description,
                rewardCoins: item.rewardCoins,
                state: state,
                unlockedAt: state == .locked ? nil : "2026-07-17T00:00:00.000Z",
                claimedAt: state == .claimed ? "2026-07-17T00:00:01.000Z" : nil
            )
        }
        return AchievementsResponse(
            authenticated: true,
            achievements: items,
            claimedCount: 1,
            totalCount: items.count,
            coinBalance: session?.profile?.coins ?? 0
        )
    }

    private static let uiTestThemes = ThemeCatalogResponse(
        themes: [
            CosmeticCatalogItem(id: "classic", name: "Default", priceCoins: 0),
            CosmeticCatalogItem(id: "disco", name: "Disco", priceCoins: 0),
            CosmeticCatalogItem(id: "light", name: "Light", priceCoins: 50),
            CosmeticCatalogItem(id: "pixel", name: "Pixel", priceCoins: 100),
        ],
        profile: nil,
        coinBalance: 0
    )

    private static let uiTestPets = PetCatalogResponse(
        pets: [
            CosmeticCatalogItem(id: "foka", name: "Foka", priceCoins: 10),
            CosmeticCatalogItem(id: "kesha", name: "Kesha", priceCoins: 20),
            CosmeticCatalogItem(id: "tauta", name: "Tauta", priceCoins: 50),
            CosmeticCatalogItem(id: "misha", name: "Misha", priceCoins: 100),
            CosmeticCatalogItem(id: "pancake", name: "Pancake", priceCoins: 500),
        ],
        profile: nil,
        coinBalance: 0
    )

    static func screenshotLeaderboard(mode: GameMode, playerName: String) -> LeaderboardResponse {
        let showsPancake = ProcessInfo.processInfo.arguments.contains("--ui-test-pancake-profile")
        let entries = [
            LeaderboardEntry(
                id: "ui-rank-1",
                rank: 1,
                name: "TapNova",
                petId: showsPancake ? "pancake" : "kesha",
                mode: mode.rawValue,
                score: 18_940,
                survivalMs: 247_000,
                fastestReactionMs: 187,
                averageReactionMs: 306,
                hits: 126,
                dodges: 17,
                speedRatings: SpeedRatingCounts(godlike: 21, perfect: 43, great: 39, good: 23),
                createdAt: "2026-07-15T00:00:00Z",
                isCurrentPlayer: false,
                isContextResult: false,
                verification: mode == .arcade ? "verified" : "legacy"
            ),
            LeaderboardEntry(
                id: "ui-rank-2",
                rank: 2,
                name: "NeonMoth",
                petId: "tauta",
                mode: mode.rawValue,
                score: 17_680,
                survivalMs: 231_000,
                fastestReactionMs: 194,
                averageReactionMs: 317,
                hits: 119,
                dodges: 15,
                speedRatings: SpeedRatingCounts(godlike: 18, perfect: 41, great: 38, good: 22),
                createdAt: "2026-07-15T00:01:00Z",
                isCurrentPlayer: false,
                isContextResult: false,
                verification: mode == .arcade ? "verified" : "legacy"
            ),
            LeaderboardEntry(
                id: "ui-rank-3",
                rank: 3,
                name: "SwiftPaws",
                petId: "misha",
                mode: mode.rawValue,
                score: 16_920,
                survivalMs: 220_000,
                fastestReactionMs: 201,
                averageReactionMs: 324,
                hits: 113,
                dodges: 14,
                speedRatings: SpeedRatingCounts(godlike: 16, perfect: 39, great: 37, good: 21),
                createdAt: "2026-07-15T00:02:00Z",
                isCurrentPlayer: false,
                isContextResult: false,
                verification: mode == .arcade ? "verified" : "legacy"
            ),
            LeaderboardEntry(
                id: "ui-rank-4",
                rank: 4,
                name: "LimeOrbit",
                petId: "foka",
                mode: mode.rawValue,
                score: 15_740,
                survivalMs: 207_000,
                fastestReactionMs: 209,
                averageReactionMs: 337,
                hits: 106,
                dodges: 12,
                speedRatings: SpeedRatingCounts(godlike: 14, perfect: 36, great: 35, good: 21),
                createdAt: "2026-07-15T00:03:00Z",
                isCurrentPlayer: false,
                isContextResult: false,
                verification: mode == .arcade ? "verified" : "legacy"
            ),
            LeaderboardEntry(
                id: "ui-rank-5",
                rank: 5,
                name: "EchoPixel",
                petId: "pancake",
                mode: mode.rawValue,
                score: 14_880,
                survivalMs: 196_000,
                fastestReactionMs: 216,
                averageReactionMs: 345,
                hits: 101,
                dodges: 10,
                speedRatings: SpeedRatingCounts(godlike: 12, perfect: 34, great: 34, good: 21),
                createdAt: "2026-07-15T00:04:00Z",
                isCurrentPlayer: false,
                isContextResult: false,
                verification: mode == .arcade ? "verified" : "legacy"
            ),
            LeaderboardEntry(
                id: "ui-player",
                rank: 6,
                name: playerName,
                petId: showsPancake ? "pancake" : "foka",
                mode: mode.rawValue,
                score: 13_960,
                survivalMs: 184_000,
                fastestReactionMs: 221,
                averageReactionMs: 352,
                hits: 95,
                dodges: 9,
                speedRatings: SpeedRatingCounts(godlike: 10, perfect: 31, great: 33, good: 21),
                createdAt: "2026-07-15T00:05:00Z",
                isCurrentPlayer: true,
                isContextResult: true,
                verification: mode == .arcade ? "verified" : "legacy"
            ),
            LeaderboardEntry(
                id: "ui-rank-7",
                rank: 7,
                name: "TinyBolt",
                petId: "kesha",
                mode: mode.rawValue,
                score: 13_420,
                survivalMs: 176_000,
                fastestReactionMs: 228,
                averageReactionMs: 361,
                hits: 91,
                dodges: 8,
                speedRatings: SpeedRatingCounts(godlike: 9, perfect: 29, great: 32, good: 21),
                createdAt: "2026-07-15T00:06:00Z",
                isCurrentPlayer: false,
                isContextResult: false,
                verification: mode == .arcade ? "verified" : "legacy"
            ),
        ]
        return LeaderboardResponse(
            season: uiTestPetSession.season,
            mode: mode.rawValue,
            entries: entries,
            totalEntries: mode == .arcade ? 42 : 8,
            playerRank: mode == .arcade ? 6 : nil,
            topPercent: mode == .arcade ? 15 : nil,
            contextRank: mode == .arcade ? 6 : nil,
            contextTopPercent: mode == .arcade ? 15 : nil,
            contextEntryId: mode == .arcade ? "ui-player" : nil
        )
    }

    private static func uiTestLeaderboard(
        mode: GameMode,
        playerName: String
    ) -> LeaderboardResponse {
        let showsPancake = ProcessInfo.processInfo.arguments.contains("--ui-test-pancake-profile")
        let entries = [
            LeaderboardEntry(
                id: "ui-top",
                rank: 1,
                name: "TapNova",
                petId: showsPancake ? "pancake" : "kesha",
                mode: mode.rawValue,
                score: 12_480,
                survivalMs: 184_000,
                fastestReactionMs: 187,
                averageReactionMs: 318,
                hits: 94,
                dodges: 12,
                speedRatings: SpeedRatingCounts(godlike: 14, perfect: 32, great: 31, good: 17),
                createdAt: "2026-07-15T00:00:00Z",
                isCurrentPlayer: false,
                isContextResult: false,
                verification: mode == .arcade ? "verified" : "legacy"
            ),
            LeaderboardEntry(
                id: "ui-player",
                rank: 6,
                name: playerName,
                petId: showsPancake ? "pancake" : "foka",
                mode: mode.rawValue,
                score: 8_640,
                survivalMs: 121_000,
                fastestReactionMs: 221,
                averageReactionMs: 356,
                hits: 65,
                dodges: 7,
                speedRatings: SpeedRatingCounts(godlike: 7, perfect: 19, great: 24, good: 15),
                createdAt: "2026-07-15T00:01:00Z",
                isCurrentPlayer: true,
                isContextResult: true,
                verification: mode == .arcade ? "verified" : "legacy"
            ),
            LeaderboardEntry(
                id: "ui-neighbor",
                rank: 7,
                name: "PixelPaws",
                petId: "misha",
                mode: mode.rawValue,
                score: 8_120,
                survivalMs: 117_000,
                fastestReactionMs: 238,
                averageReactionMs: 371,
                hits: 61,
                dodges: 5,
                speedRatings: SpeedRatingCounts(godlike: 5, perfect: 16, great: 23, good: 17),
                createdAt: "2026-07-15T00:02:00Z",
                isCurrentPlayer: false,
                isContextResult: false,
                verification: mode == .arcade ? "verified" : "legacy"
            ),
        ]
        return LeaderboardResponse(
            season: uiTestPetSession.season,
            mode: mode.rawValue,
            entries: entries,
            totalEntries: mode == .arcade ? 42 : 8,
            playerRank: mode == .arcade ? 6 : nil,
            topPercent: mode == .arcade ? 15 : nil,
            contextRank: mode == .arcade ? 6 : nil,
            contextTopPercent: mode == .arcade ? 15 : nil,
            contextEntryId: mode == .arcade ? "ui-player" : nil
        )
    }

    private static let uiTestOfflineError = BackendError(
        status: 0,
        message: "Network mutations are disabled in UI tests.",
        code: "ui-test-offline"
    )

    private static let staleSessionError = BackendError(
        status: 0,
        message: "The account changed while the request was in progress. Please try again.",
        code: "stale-session"
    )

    private static let stateMutationBusyError = BackendError(
        status: 0,
        message: "The account is already being updated. Please try again.",
        code: "session-update-in-progress"
    )

    private static let authenticationRequiredError = BackendError(
        status: 401,
        message: "Sign in to continue.",
        code: "authentication-required"
    )

    private static let invalidAuthenticationIntentError = BackendError(
        status: 400,
        message: "Use the explicit provider-linking flow to add a sign-in method.",
        code: "invalid-authentication-intent"
    )

    private static let invalidAuthenticationResponseError = BackendError(
        status: 0,
        message: "The sign-in response could not be verified. Please try again.",
        code: "invalid-authentication-response"
    )

    private static let invalidIdentityLinkResponseError = BackendError(
        status: 0,
        message: "The service did not confirm the linked sign-in method.",
        code: "invalid-identity-link-response"
    )

    private static let invalidAppleChallengeResponseError = BackendError(
        status: 0,
        message: "The Sign in with Apple request could not be verified. Please try again.",
        code: "invalid-apple-challenge-response"
    )

    private static let invalidAppleAuthorizationProofError = BackendError(
        status: 400,
        message: "Apple returned an incomplete authorization. Please try again.",
        code: "invalid-apple-authorization-proof"
    )

    private static let invalidGameCenterProofError = BackendError(
        status: 400,
        message: "Game Center returned an incomplete identity proof. Please try again.",
        code: "invalid-game-center-proof"
    )

    private static let invalidGameCenterLinkResponseError = BackendError(
        status: 0,
        message: "The service did not confirm the Game Center link. Please try again.",
        code: "invalid-game-center-link-response"
    )

    private static let invalidAchievementError = BackendError(
        status: 400,
        message: "An achievement ID is required.",
        code: "invalid-achievement"
    )

    private static let invalidAccountDeletionConfirmationError = BackendError(
        status: 400,
        message: "Type DELETE MY ACCOUNT exactly to confirm account deletion.",
        code: "invalid-account-deletion-confirmation"
    )

    private static let invalidAccountDeletionResponseError = BackendError(
        status: 0,
        message: "The service did not confirm that the account was deleted. Please try again.",
        code: "invalid-account-deletion-response"
    )

    private static let accountAuthenticationMismatchError = BackendError(
        status: 409,
        message: "A different account was selected. No account was changed.",
        code: accountDeletionAccountMismatchCode
    )

    private static let invalidAchievementResponseError = BackendError(
        status: 0,
        message: "The achievement response could not be verified. Refresh and try again.",
        code: "invalid-response"
    )

    private static let invalidNicknameAvailabilityResponseError = BackendError(
        status: 0,
        message: "Player name validation is temporarily unavailable.",
        code: "invalid-nickname-availability-response"
    )

    private static let invalidRunFinishResponseError = BackendError(
        status: 0,
        message: "The leaderboard did not confirm that this score was saved. Please retry.",
        code: "invalid-run-finish-response"
    )

    private static let invalidRunTicketResponseError = BackendError(
        status: 0,
        message: "This game version is not yet supported for ranked Arcade. Please try again later.",
        code: "invalid-run-ticket-response"
    )

    private static let invalidStoreKitRequestError = BackendError(
        status: 400,
        message: "The App Store transaction is incomplete.",
        code: "invalid-storekit-request"
    )

    private static let storeKitAccountUnavailableError = BackendError(
        status: 409,
        message: "Refresh your PimPoPom profile before continuing with this purchase.",
        code: "storekit-account-unavailable"
    )

    private static let invalidStoreKitResponseError = BackendError(
        status: 0,
        message: "The purchase response could not be verified. Please try again.",
        code: "invalid-storekit-response"
    )

    private static func isValidStoreCreditRequest(_ request: StoreCreditRequest) -> Bool {
        UInt64(request.transactionID).map { $0 > 0 } == true
            && !request.signedTransaction.isEmpty
            && request.signedTransaction.utf8.count <= 262_144
    }

    private static func validatePlayerName(_ nickname: String) throws {
        if let message = PlayerNameValidation.localError(for: nickname) {
            throw BackendError(status: 400, message: message, code: "invalid-player-name")
        }
    }

    private static func isValidWallet(_ wallet: StoreWalletSummary) -> Bool {
        wallet.earned >= 0
            && wallet.purchased >= 0
            && wallet.earnedDebt >= 0
            && wallet.refundDebt >= 0
            && wallet.total >= 0
            && wallet.total == wallet.earned + wallet.purchased
    }
}
