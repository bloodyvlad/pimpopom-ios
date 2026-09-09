import Foundation
import PimPoPomCore

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public struct AuthenticatedPlayer: Codable, Equatable, Sendable {
    public let playerID: String
    public let name: String
    public let petID: String?
    public let sessionBinding: String
    public let expiresAt: Int
    public let protocolVersion: Int
    public let ruleset: String

    public init(
        playerID: String, name: String, petID: String? = nil, sessionBinding: String,
        expiresAt: Int, protocolVersion: Int = 2, ruleset: String = "multiplayer-shared-arcade-v2"
    ) {
        self.playerID = playerID
        self.name = name
        self.petID = petID
        self.sessionBinding = sessionBinding
        self.expiresAt = expiresAt
        self.protocolVersion = protocolVersion
        self.ruleset = ruleset
    }
}

public protocol TicketAuthenticating: Sendable {
    func redeem(_ ticket: String) async throws -> AuthenticatedPlayer
    func validate(_ player: AuthenticatedPlayer) async throws -> AuthenticatedPlayer
}

public enum AuthenticationFailure: Error { case invalidTicket, invalidCapability, revokedSession }

public struct TicketAuthenticator: TicketAuthenticating {
    let configuration: ServerConfiguration
    public init(configuration: ServerConfiguration) { self.configuration = configuration }

    public func redeem(_ ticket: String) async throws -> AuthenticatedPlayer {
        guard !ticket.isEmpty, ticket.utf8.count <= 2048 else { throw AuthenticationFailure.invalidTicket }
        if configuration.developmentAuthentication {
            // Synthetic local fixtures only. No real or anonymous production identity fallback.
            guard ticket.hasPrefix("dev:"), let uuid = UUID(uuidString: String(ticket.dropFirst(4))) else {
                throw AuthenticationFailure.invalidTicket
            }
            return AuthenticatedPlayer(
                playerID: uuid.uuidString.lowercased(), name: "Local" + uuid.uuidString.prefix(4),
                sessionBinding: UUID().uuidString, expiresAt: Int(Date().timeIntervalSince1970) + 3600)
        }
        guard let url = configuration.redemptionURL else { throw AuthenticationFailure.invalidTicket }
        return try await request(url, fields: ["ticket": ticket])
    }

    public func validate(_ player: AuthenticatedPlayer) async throws -> AuthenticatedPlayer {
        guard player.expiresAt > Int(Date().timeIntervalSince1970) else { throw AuthenticationFailure.revokedSession }
        if configuration.developmentAuthentication { return player }
        guard let url = configuration.validationURL else { throw AuthenticationFailure.revokedSession }
        let result = try await request(
            url, fields: ["playerID": player.playerID, "sessionBinding": player.sessionBinding])
        guard result.playerID == player.playerID, result.sessionBinding == player.sessionBinding else {
            throw AuthenticationFailure.revokedSession
        }
        return result
    }

    private func request(_ url: URL, fields: [String: String]) async throws -> AuthenticatedPlayer {
        var body: [String: Any] = fields
        body["protocolVersion"] = MP2Protocol.version
        body["ruleset"] = MP2Protocol.ruleset
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "POST"
        request.setValue("Bearer " + (configuration.serviceKey ?? ""), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200, data.count <= 16_384 else {
            throw AuthenticationFailure.invalidTicket
        }
        let player = try JSONDecoder().decode(AuthenticatedPlayer.self, from: data)
        guard UUID(uuidString: player.playerID) != nil, !player.name.isEmpty, player.name.count <= 20,
            !player.sessionBinding.isEmpty, player.expiresAt > Int(Date().timeIntervalSince1970),
            player.protocolVersion == MP2Protocol.version, player.ruleset == MP2Protocol.ruleset
        else {
            throw AuthenticationFailure.invalidCapability
        }
        return player
    }
}
