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
final class BackendClient: ObservableObject {
    static let productionBaseURL = URL(string: "https://speedytapper.otcsoft.com")!
    static let deployedBuildID = "20260715-1"

    @Published private(set) var sessionState: SessionResponse?
    @Published private(set) var isLoadingSession = false
    @Published private(set) var lastError: String?

    private let baseURL: URL
    private let urlSession: URLSession
    private let isUITestOffline: Bool
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
        urlSession: URLSession? = nil
    ) {
        self.baseURL = baseURL
        self.isUITestOffline = isUITestOffline
        if let urlSession {
            self.urlSession = urlSession
        } else {
            let configuration = isUITestOffline ? URLSessionConfiguration.ephemeral : .default
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.urlCache = nil
            configuration.httpShouldSetCookies = !isUITestOffline
            configuration.httpCookieAcceptPolicy = isUITestOffline ? .never : .always
            configuration.httpCookieStorage = isUITestOffline ? nil : .shared
            configuration.timeoutIntervalForRequest = 20
            self.urlSession = URLSession(configuration: configuration)
        }
        if isUITestOffline {
            sessionState = Self.uiTestSession
        }
    }

    var profile: PlayerProfile? { sessionState?.profile }
    var isAuthenticated: Bool { sessionState?.authenticated == true }
    var canStartRankedRun: Bool {
        isAuthenticated && profile?.nicknameConfirmed == true
    }

    @discardableResult
    func loadSession() async throws -> SessionResponse {
        if isUITestOffline { return Self.uiTestSession }
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
            return LeaderboardResponse(
                season: Self.uiTestSession.season,
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

    func loadThemes() async throws -> ThemeCatalogResponse {
        if isUITestOffline { return Self.uiTestThemes }
        return try await request(path: "/api/themes")
    }

    func loadPets() async throws -> PetCatalogResponse {
        if isUITestOffline { return Self.uiTestPets }
        return try await request(path: "/api/pets")
    }

    @discardableResult
    func login(googleIDToken: String) async throws -> SessionResponse {
        let body = try encoder.encode(["credential": googleIDToken])
        let token = try await beginStateMutation(requiresAuthenticatedProfile: false)
        do {
            let response: SessionResponse = try await request(
                path: "/api/auth/google",
                method: "POST",
                body: body,
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
    func updateNickname(_ nickname: String) async throws -> ProfileResponse {
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
            replaceProfile(response.profile, ranks: response.ranks)
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
        let body = try encoder.encode([
            "mode": GameMode.arcade.rawValue,
            "buildId": Self.deployedBuildID,
        ])
        return try await mutation(path: "/api/runs", method: "POST", body: body)
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
        let payload = RunProofPayload(
            runId: ticket.runId,
            mode: ticket.mode,
            buildId: ticket.buildId,
            ruleset: ticket.ruleset,
            proofVersion: ticket.proofVersion,
            events: events
        )
        return try await mutation(
            path: "/api/runs/finish",
            method: "POST",
            body: try encoder.encode(payload)
        )
    }

    private struct StateMutationToken {
        let epoch: Int
        let playerID: String?
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

    private func mutation<Response: Decodable>(
        path: String,
        method: String,
        body: Data
    ) async throws -> Response {
        guard !isUITestOffline else { throw Self.uiTestOfflineError }
        if csrfToken == nil { _ = try await loadSession() }
        return try await request(path: path, method: method, body: body, csrf: csrfToken)
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
        ranks: [String: RankInfo]? = nil
    ) {
        guard let sessionState else { return }
        lastError = nil
        self.sessionState = SessionResponse(
            authenticated: true,
            csrfToken: sessionState.csrfToken,
            googleClientId: sessionState.googleClientId,
            season: sessionState.season,
            profile: profile,
            ranks: ranks ?? sessionState.ranks
        )
    }

    private static let uiTestSession = SessionResponse(
        authenticated: false,
        csrfToken: "ui-test-offline",
        googleClientId: "placeholder.apps.googleusercontent.com",
        season: Season(id: "ui-test", name: "Offline UI Test"),
        profile: nil,
        ranks: nil
    )

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
        message: "Sign in with Google to continue.",
        code: "authentication-required"
    )
}
