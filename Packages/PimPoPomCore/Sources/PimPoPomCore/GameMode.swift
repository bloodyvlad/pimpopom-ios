public enum GameMode: String, CaseIterable, Sendable {
    case arcade
    case zen

    public var displayName: String {
        switch self {
        case .arcade: "Arcade"
        case .zen: "Zen"
        }
    }
}
