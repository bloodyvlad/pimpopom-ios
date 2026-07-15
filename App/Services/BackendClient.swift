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

    init(
        baseURL: URL = BackendClient.productionBaseURL,
        isUITestOffline: Bool = ProcessInfo.processInfo.arguments.contains("--uitesting")
    ) {
        self.baseURL = baseURL
        self.isUITestOffline = isUITestOffline
        let configuration = isUITestOffline ? URLSessionConfiguration.ephemeral : .default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = !isUITestOffline
        configuration.httpCookieAcceptPolicy = isUITestOffline ? .never : .always
        configuration.httpCookieStorage = isUITestOffline ? nil : .shared
        configuration.timeoutIntervalForRequest = 20
        urlSession = URLSession(configuration: configuration)
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
        isLoadingSession = true
        defer { isLoadingSession = false }
        do {
            let response: SessionResponse = try await request(path: "/api/session")
            csrfToken = response.csrfToken
            sessionState = response
            lastError = nil
            return response
        } catch {
            lastError = error.localizedDescription
            throw error
        }
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

    @discardableResult
    func login(googleIDToken: String) async throws -> SessionResponse {
        let body = try encoder.encode(["credential": googleIDToken])
        let response: SessionResponse = try await mutation(
            path: "/api/auth/google",
            method: "POST",
            body: body
        )
        csrfToken = response.csrfToken
        sessionState = response
        return response
    }

    @discardableResult
    func logout() async throws -> SessionResponse {
        let response: SessionResponse = try await mutation(
            path: "/api/logout",
            method: "POST",
            body: Data("{}".utf8)
        )
        csrfToken = response.csrfToken
        sessionState = response
        return response
    }

    @discardableResult
    func updateNickname(_ nickname: String) async throws -> ProfileResponse {
        let body = try encoder.encode(["nickname": nickname])
        let response: ProfileResponse = try await mutation(
            path: "/api/profile?mode=normal",
            method: "PATCH",
            body: body
        )
        _ = try await loadSession()
        return response
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

    private static let uiTestSession = SessionResponse(
        authenticated: false,
        csrfToken: "ui-test-offline",
        googleClientId: "placeholder.apps.googleusercontent.com",
        season: Season(id: "ui-test", name: "Offline UI Test"),
        profile: nil,
        ranks: nil
    )

    private static let uiTestOfflineError = BackendError(
        status: 0,
        message: "Network mutations are disabled in UI tests.",
        code: "ui-test-offline"
    )
}
