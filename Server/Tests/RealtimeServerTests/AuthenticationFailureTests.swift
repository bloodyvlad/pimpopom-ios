import Foundation
import PimPoPomCore
import Testing

@testable import RealtimeServer

struct AuthenticationFailureTests {
    @Test func bridgeFailuresAreNotAllReportedAsPlayerLogout() throws {
        let cases: [(Int, String, AuthenticationFailure)] = [
            (401, "The realtime session is invalid or expired.", .revokedSession),
            (401, "The connection ticket is invalid or expired.", .invalidTicket),
            (401, "The realtime credential is invalid or expired.", .invalidTicket),
            (401, "Multiplayer service authentication failed.", .serviceUnavailable),
            (403, "Confirm your player name before playing multiplayer.", .profileRequired),
            (409, "This multiplayer protocol is not supported.", .invalidCapability),
            (429, "The session has too many realtime connections.", .rateLimited),
            (500, "Internal error.", .serviceUnavailable),
            (503, "Multiplayer v2 is not configured.", .serviceUnavailable),
        ]
        for (status, message, expected) in cases {
            let data = try JSONEncoder().encode(["error": message])
            #expect(throws: expected) { try TicketAuthenticator.decodeResponse(data, statusCode: status) }
        }
        #expect(throws: AuthenticationFailure.serviceUnavailable) {
            try TicketAuthenticator.decodeResponse(Data("invalid json".utf8), statusCode: 200)
        }
        #expect(AuthenticationFailure.classify(URLError(.timedOut)) == .serviceUnavailable)
        #expect(AuthenticationFailure.serviceUnavailable.userMessage.contains("Sign in") == false)
        #expect(AuthenticationFailure.rateLimited.userMessage.contains("Sign in") == false)
    }

    @Test func transientValidationFailsClosedWithoutClaimingSessionRevocation() async throws {
        let (service, ids, roomID) = try await RoomServiceTests().fixture()
        let output = try #require(await service.connections[ids[1]]?.output)
        let validations = await service.validationsDue(now: 15_000)
        let validation = try #require(validations.first { $0.connectionID == ids[1] })
        await service.validated(validation, refreshed: nil, failure: .serviceUnavailable, now: 15_001)
        #expect(await service.connections[ids[1]] == nil)
        #expect(await service.connections[ids[0]] != nil)
        #expect(await service.rooms[roomID]?.value.players[1].connected == false)
        var errors: [String] = []
        for await message in output {
            if case .error(let code, _) = message { errors.append(code) }
        }
        #expect(errors == ["service_unavailable"])
    }

    @Test func expiredRealtimeBindingRequestsNewTicketNotPrimarySignIn() async throws {
        let config = try ServerConfiguration(environment: ["MP2_DEV_AUTH": "1"])
        let authenticator = TicketAuthenticator(configuration: config)
        let player = AuthenticatedPlayer(
            playerID: UUID().uuidString, name: "Local", sessionBinding: "expired-binding", expiresAt: 0)
        await #expect(throws: AuthenticationFailure.invalidTicket) { try await authenticator.validate(player) }
    }
}
