import Foundation

public struct ServerConfiguration: Sendable {
    public var hostname: String
    public var port: Int
    public var developmentAuthentication: Bool
    public var redemptionURL: URL?
    public var validationURL: URL?
    public var resultsURL: URL?
    public var serviceKey: String?
    public var outboxDirectory: URL
    public var maximumConnections = 256
    public var maximumRooms = 64
    public var reconnectGraceMs = 15_000
    public var idleConnectionMs = 30_000
    public var authenticationTimeoutMs = 5_000
    public var validationIntervalMs = 15_000

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) throws {
        hostname = environment["MP2_BIND"] ?? "127.0.0.1"
        port = Int(environment["MP2_PORT"] ?? "8080") ?? 8080
        developmentAuthentication = environment["MP2_DEV_AUTH"] == "1"
        redemptionURL = environment["MP2_TICKET_INTROSPECTION_URL"].flatMap(URL.init(string:))
        validationURL = environment["MP2_SESSION_VALIDATION_URL"].flatMap(URL.init(string:))
        resultsURL = environment["MP2_RESULTS_URL"].flatMap(URL.init(string:))
        serviceKey = environment["MP2_SERVICE_KEY"]
        outboxDirectory = URL(fileURLWithPath: environment["MP2_OUTBOX_DIRECTORY"] ?? "data/outbox", isDirectory: true)
        guard (1...65535).contains(port) else { throw ConfigurationError.invalidPort }
        if developmentAuthentication {
            guard ["127.0.0.1", "::1", "localhost"].contains(hostname) else {
                throw ConfigurationError.developmentAuthenticationRequiresLoopback
            }
        } else {
            guard let redemptionURL, let validationURL, let serviceKey, serviceKey.count >= 32,
                redemptionURL.scheme == "https", validationURL.scheme == "https",
                resultsURL == nil || resultsURL?.scheme == "https"
            else { throw ConfigurationError.productionAuthenticationRequired }
        }
    }

    public enum ConfigurationError: Error {
        case invalidPort
        case developmentAuthenticationRequiresLoopback
        case productionAuthenticationRequired
    }
}

public enum ServerClock {
    public static func milliseconds() -> Int { Int(DispatchTime.now().uptimeNanoseconds / 1_000_000) }
}
