import Foundation
import PimPoPomCore
import Vapor

public enum RealtimeApplication {
    public static func run() async throws {
        let configuration = try ServerConfiguration()
        let outbox = ResultOutbox(directory: configuration.outboxDirectory)
        try await outbox.prepare()
        let app = try await Application.make(.detect())
        app.http.server.configuration.hostname = configuration.hostname
        app.http.server.configuration.port = configuration.port
        let resultQueue = AsyncStream<CompletedMatch>.makeStream(bufferingPolicy: .bufferingOldest(128))
        let service = RoomService(configuration: configuration, resultOutput: resultQueue.continuation)
        let authenticator = TicketAuthenticator(configuration: configuration)
        configure(app: app, service: service, authenticator: authenticator)
        let logger = app.logger

        let ticker = Task {
            while !Task.isCancelled {
                await service.tick(now: ServerClock.milliseconds())
                try await Task.sleep(for: .nanoseconds(16_666_667))
            }
        }
        let validator = Task {
            while !Task.isCancelled {
                let due = await service.validationsDue(now: ServerClock.milliseconds())
                await withTaskGroup(of: Void.self) { group in
                    for validation in due {
                        group.addTask {
                            do {
                                let refreshed = try await authenticator.validate(validation.player)
                                await service.validated(
                                    validation, refreshed: refreshed, now: ServerClock.milliseconds())
                            } catch {
                                await service.validated(
                                    validation, refreshed: nil, failure: .classify(error),
                                    now: ServerClock.milliseconds())
                            }
                        }
                    }
                }
                try await Task.sleep(for: .seconds(1))
            }
        }
        let journaler = Task {
            for await result in resultQueue.stream {
                while !Task.isCancelled {
                    do {
                        try await outbox.store(result)
                        await service.resultStored(matchID: result.matchID)
                        break
                    } catch {
                        logger.error("mp2_result_journal_retry", metadata: ["matchID": .string(result.matchID)])
                        try await Task.sleep(for: .seconds(1))
                    }
                }
            }
        }
        let delivery = Task {
            while !Task.isCancelled {
                do { try await outbox.deliverPending(configuration: configuration) } catch {
                    logger.warning("mp2_result_delivery_retry")
                }
                try await Task.sleep(for: .seconds(5))
            }
        }
        do {
            try await app.execute()
        } catch {
            ticker.cancel()
            validator.cancel()
            journaler.cancel()
            delivery.cancel()
            resultQueue.continuation.finish()
            try await app.asyncShutdown()
            throw error
        }
        ticker.cancel()
        validator.cancel()
        journaler.cancel()
        delivery.cancel()
        resultQueue.continuation.finish()
        try await app.asyncShutdown()
    }

    public static func configure(app: Application, service: RoomService, authenticator: any TicketAuthenticating) {
        app.get("health") { _ async -> Health in
            let counts = await service.counts()
            return Health(
                status: "ok", protocolVersion: MP2Protocol.version, ruleset: MP2Protocol.ruleset,
                rankingEnabled: false, connections: counts.connections, rooms: counts.rooms)
        }
        app.webSocket("multiplayer", "v2", maxFrameSize: 16_384) { _, socket in
            // Callbacks only enqueue bounded messages. One task owns decoding and
            // admission, and one writer preserves each connection's output order.
            let input = AsyncStream<String>.makeStream(bufferingPolicy: .bufferingOldest(64))
            let output = OutboundMessages()
            let connectionID = UUID().uuidString.lowercased()
            socket.pingInterval = .seconds(5)
            socket.onText { socket, text in
                guard text.utf8.count <= 16_384 else {
                    socket.close(promise: nil)
                    input.continuation.finish()
                    return
                }
                if case .dropped = input.continuation.yield(text) {
                    socket.close(promise: nil)
                    input.continuation.finish()
                }
            }
            socket.onBinary { socket, _ in
                socket.close(promise: nil)
                input.continuation.finish()
            }
            socket.onClose.whenComplete { _ in
                input.continuation.finish()
                output.finish()
            }
            Task {
                guard await service.connect(id: connectionID, output: output, now: ServerClock.milliseconds()) else {
                    try? await socket.close()
                    return
                }
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        let encoder = JSONEncoder()
                        do {
                            for await message in output {
                                let bytes = try encoder.encode(message)
                                try await socket.send(String(decoding: bytes, as: UTF8.self))
                            }
                        } catch {
                            // Close and isolate a failed writer.
                        }
                        try? await socket.close()
                        input.continuation.finish()
                    }
                    group.addTask {
                        let decoder = JSONDecoder()
                        var authenticated = false
                        var identity: AuthenticatedPlayer?
                        for await text in input.stream {
                            do {
                                let message = try decoder.decode(MP2ClientMessage.self, from: Data(text.utf8))
                                if !authenticated {
                                    guard case .hello(let ticket, let version, let gameplayRevision) = message else {
                                        await service.authenticationFailed(
                                            id: connectionID, failure: .authenticationRequired,
                                            now: ServerClock.milliseconds())
                                        break
                                    }
                                    guard version == MP2Protocol.version,
                                        MP2Protocol.supportedGameplayRevisions.contains(
                                            gameplayRevision ?? MP2Protocol.legacyGameplayRevision)
                                    else {
                                        await service.authenticationFailed(
                                            id: connectionID, failure: .invalidCapability,
                                            now: ServerClock.milliseconds())
                                        break
                                    }
                                    let player = try await authenticator.redeem(ticket)
                                    await service.authenticated(
                                        id: connectionID, player: player, now: ServerClock.milliseconds(),
                                        gameplayRevision: gameplayRevision ?? MP2Protocol.legacyGameplayRevision)
                                    identity = player
                                    authenticated = true
                                } else {
                                    if case .resume = message, let player = identity {
                                        do {
                                            let refreshed = try await authenticator.validate(player)
                                            await service.validated(
                                                RoomService.Validation(connectionID: connectionID, player: player),
                                                refreshed: refreshed, now: ServerClock.milliseconds())
                                            identity = refreshed
                                        } catch {
                                            await service.authenticationFailed(
                                                id: connectionID, failure: .classify(error),
                                                now: ServerClock.milliseconds())
                                            break
                                        }
                                    }
                                    await service.receive(message, from: connectionID, now: ServerClock.milliseconds())
                                }
                            } catch {
                                if authenticated || error is DecodingError {
                                    await service.malformed(id: connectionID, now: ServerClock.milliseconds())
                                } else {
                                    await service.authenticationFailed(
                                        id: connectionID, failure: .classify(error), now: ServerClock.milliseconds())
                                }
                                break
                            }
                        }
                        await service.disconnect(id: connectionID, now: ServerClock.milliseconds())
                        output.finish()
                    }
                    await group.waitForAll()
                }
            }
        }
    }

    struct Health: Content {
        let status: String
        let protocolVersion: Int
        let ruleset: String
        let rankingEnabled: Bool
        let connections: Int
        let rooms: Int
    }
}
