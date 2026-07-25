import Foundation

struct ScreenshotFixture: Equatable, Sendable {
    enum Destination: String, Equatable, Sendable {
        case menu
        case themeShop = "themes"
        case petShop = "pets"
        case leaderboard
        case profile
        case achievements
        case arcade
        case zen
    }

    static let argument = "--screenshot-mode"
    static let autoplayArgument = "--screenshot-autoplay"
    static let recordAudioArgument = "--screenshot-record-audio"
    static let supportedPetIDs: Set<String> = [
        "foka",
        "kesha",
        "tauta",
        "misha",
        "pancake",
    ]
    static let supportedThemeIDs: Set<String> = [
        "classic",
        "disco",
        "light",
        "pixel",
    ]

    let destination: Destination
    let themeID: String
    let petID: String?
    let autoplayEnabled: Bool
    let autoplaySeed: UInt64

    static func resolve(arguments: [String]) -> Self? {
        #if DEBUG
            guard arguments.contains(argument), arguments.contains("--uitesting") else {
                return nil
            }

            let destination =
                value(for: "--screenshot-screen", in: arguments)
                .flatMap(Destination.init(rawValue:))
                ?? .menu
            let requestedTheme = value(for: "--screenshot-theme", in: arguments) ?? "pixel"
            let themeID = supportedThemeIDs.contains(requestedTheme) ? requestedTheme : "pixel"
            let requestedPet = value(for: "--screenshot-pet", in: arguments)
            let petID = requestedPet.flatMap { supportedPetIDs.contains($0) ? $0 : nil }
            let seed =
                value(for: "--screenshot-seed", in: arguments)
                .flatMap(UInt64.init)
                ?? 0x50_69_6D_50_6F_50_6F_6D

            return Self(
                destination: destination,
                themeID: themeID,
                petID: petID,
                autoplayEnabled: arguments.contains(autoplayArgument),
                autoplaySeed: seed
            )
        #else
            return nil
        #endif
    }

    static func reactionRangeMilliseconds(forGridDimension dimension: Int) -> ClosedRange<Int> {
        switch dimension {
        case 1: 190...280
        case 2: 270...350
        default: 310...500
        }
    }

    private static func value(for option: String, in arguments: [String]) -> String? {
        if let inline = arguments.first(where: { $0.hasPrefix("\(option)=") }) {
            return String(inline.dropFirst(option.count + 1))
        }
        guard let index = arguments.firstIndex(of: option),
            arguments.indices.contains(index + 1)
        else {
            return nil
        }
        return arguments[index + 1]
    }
}

struct ScreenshotAutoplayRandom: Equatable, Sendable {
    static let minimumTapFraction = 0.12
    static let maximumTapFraction = 0.88

    private(set) var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func nextReactionMilliseconds(forGridDimension dimension: Int) -> Int {
        let value = nextValue()
        let range = ScreenshotFixture.reactionRangeMilliseconds(forGridDimension: dimension)
        let width = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int((value >> 18) % width)
    }

    mutating func nextTapLocation() -> ScreenshotAutoplayTapLocation {
        ScreenshotAutoplayTapLocation(
            horizontalFraction: nextTapFraction(),
            verticalFraction: nextTapFraction()
        )
    }

    private mutating func nextTapFraction() -> Double {
        let sample = Double((nextValue() >> 11) % 10_001) / 10_000
        return Self.minimumTapFraction
            + sample * (Self.maximumTapFraction - Self.minimumTapFraction)
    }

    private mutating func nextValue() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

struct ScreenshotAutoplayTapLocation: Equatable, Sendable {
    let horizontalFraction: Double
    let verticalFraction: Double
}
