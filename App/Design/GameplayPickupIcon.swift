import SpriteKit
import SwiftUI

enum GameplayPickupSymbol: String, CaseIterable {
    case heart
    case clock
}

/// One artwork source for HUD lives and both SpriteKit pickup modes.
struct GameplayPickupIcon: View {
    let symbol: GameplayPickupSymbol
    let theme: ThemePalette
    var filled = true

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            Group {
                if theme.isPixel {
                    if symbol == .heart {
                        PixelHeartIcon(filled: filled, color: color)
                    } else {
                        PixelClockIcon(color: color)
                    }
                } else if symbol == .heart {
                    Text(filled ? "♥" : "♡")
                        .font(.system(size: side, weight: .black, design: .rounded))
                        .foregroundStyle(color)
                } else {
                    Image(systemName: "clock.arrow.circlepath")
                        .resizable()
                        .scaledToFit()
                        .fontWeight(.bold)
                        .foregroundStyle(color)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityHidden(true)
    }

    private var color: Color {
        Color(hex: symbol == .heart ? GameHUDMetrics.livesColorHex : theme.chromeAccent)
    }
}

struct GameplayLivesView: View {
    let remaining: Int
    let theme: ThemePalette

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                GameplayPickupIcon(symbol: .heart, theme: theme, filled: index < remaining)
                    .frame(width: 14, height: 12)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lives")
        .accessibilityValue("\(max(0, min(3, remaining))) of 3")
    }
}

private struct PixelClockIcon: View {
    let color: Color

    private static let pattern = [
        "0000000000000",
        "0000011110000",
        "0001100001100",
        "0010000000010",
        "0110001000010",
        "1111101000001",
        "0110001000001",
        "0010001110001",
        "0000000000001",
        "0010000000010",
        "0001100001100",
        "0000011110000",
        "0000000000000",
    ]

    var body: some View {
        Canvas { context, size in
            let dimension = CGFloat(Self.pattern.count)
            let pixel = min(size.width, size.height) / dimension
            let origin = CGPoint(x: (size.width - pixel * dimension) / 2, y: (size.height - pixel * dimension) / 2)
            for (row, pattern) in Self.pattern.enumerated() {
                for (column, value) in pattern.enumerated() where value == "1" {
                    context.fill(
                        Path(
                            CGRect(
                                x: origin.x + CGFloat(column) * pixel,
                                y: origin.y + CGFloat(row) * pixel, width: pixel, height: pixel)),
                        with: .color(color))
                }
            }
        }
    }
}

/// Render once at theme preparation, never allocate an image on the touch path.
@MainActor
enum GameplayPickupTextureFactory {
    private static var textures: [String: SKTexture] = [:]

    static func prewarm(theme: ThemePalette) {
        for symbol in GameplayPickupSymbol.allCases { _ = texture(symbol: symbol, theme: theme) }
    }

    static func texture(symbol: GameplayPickupSymbol, theme: ThemePalette) -> SKTexture {
        let key = "\(theme.id)-\(symbol.rawValue)"
        if let texture = textures[key] { return texture }
        let renderer = ImageRenderer(
            content:
                GameplayPickupIcon(symbol: symbol, theme: theme).frame(width: 84, height: 84))
        renderer.scale = 2
        let texture = renderer.uiImage.map(SKTexture.init(image:)) ?? SKTexture()
        texture.filteringMode = theme.isPixel ? .nearest : .linear
        textures[key] = texture
        return texture
    }
}
