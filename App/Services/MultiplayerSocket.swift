import Foundation
import PimPoPomCore

enum MultiplayerSocketEvent: Sendable {
    case message(MP2ServerMessage)
    case disconnected(String)
}

/// All socket I/O and JSON work is isolated from the UIKit reaction path.
actor MultiplayerSocket {
    private var socket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var reader: Task<Void, Never>?
    private var writer: Task<Void, Never>?
    private var pending: [Data] = []
    private var continuation: AsyncStream<MultiplayerSocketEvent>.Continuation?
    private var generation = 0

    func connect(url: URL, ticket: String) -> AsyncStream<MultiplayerSocketEvent> {
        disconnect()
        generation += 1
        let epoch = generation
        let stream = AsyncStream<MultiplayerSocketEvent>(bufferingPolicy: .bufferingNewest(256)) {
            continuation = $0
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: configuration)
        self.session = session
        let socket = session.webSocketTask(with: url)
        socket.maximumMessageSize = 128 * 1_024
        self.socket = socket
        socket.resume()
        reader = Task {
            do {
                while !Task.isCancelled {
                    let frame = try await socket.receive()
                    guard epoch == generation else { return }
                    let data: Data
                    switch frame {
                    case .data(let value): data = value
                    case .string(let value): data = Data(value.utf8)
                    @unknown default: continue
                    }
                    let message = try JSONDecoder().decode(MP2ServerMessage.self, from: data)
                    if case .dropped = continuation?.yield(.message(message)) {
                        fail("Connection could not keep up. Reconnecting…", epoch: epoch)
                        return
                    }
                }
            } catch {
                fail("Connection interrupted. Reconnecting…", epoch: epoch)
            }
        }
        send(.hello(ticket: ticket, protocolVersion: MP2Protocol.version))
        return stream
    }

    func send(_ message: MP2ClientMessage) {
        guard socket != nil else { return }
        guard pending.count < 128, let data = try? JSONEncoder().encode(message) else {
            fail("Connection send queue is full. Reconnecting…", epoch: generation)
            return
        }
        pending.append(data)
        guard writer == nil else { return }
        let epoch = generation
        writer = Task {
            do {
                while epoch == generation, let socket, !pending.isEmpty {
                    let data = pending.removeFirst()
                    try await socket.send(.string(String(decoding: data, as: UTF8.self)))
                }
                if epoch == generation { writer = nil }
            } catch {
                fail("Connection interrupted. Reconnecting…", epoch: epoch)
            }
        }
    }

    func disconnect() {
        generation += 1
        reader?.cancel()
        writer?.cancel()
        reader = nil
        writer = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        session?.invalidateAndCancel()
        session = nil
        pending.removeAll()
        continuation?.finish()
        continuation = nil
    }

    private func fail(_ message: String, epoch: Int) {
        guard epoch == generation else { return }
        continuation?.yield(.disconnected(message))
        disconnect()
    }
}

struct MultiplayerConnectionTicket: Decodable, Sendable {
    let ticket: String
    let expiresAt: Int
    let realtimeURL: URL
}
