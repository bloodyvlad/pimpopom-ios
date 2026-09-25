import SwiftUI

/// Code-native pixel artwork; non-pixel themes retain their original SF Symbols.
struct ThemedMenuFeatureIcon: View {
    let systemImage: String
    let theme: ThemePalette

    static func pixelPattern(for systemImage: String) -> [String]? {
        switch systemImage {
        case "pawprint.fill":
            [
                "0001100011000", "0011100011100", "0011100011100",
                "0000000000000", "1100000000011", "1110011100111",
                "1100111110011", "0001111111000", "0011111111100",
                "0011111111100", "0011100011100", "0001100011000", "0000000000000",
            ]
        case "paintpalette.fill":
            [
                "0001111110000", "0011111111100", "0110011001110",
                "1110011001110", "1111111111111", "1001111110011",
                "1001111110011", "1111111111111", "1110011111000",
                "1110011110000", "0111111110000", "0011111111000", "0001111110000",
            ]
        case "trophy.fill":
            [
                "0011111111100", "0011111111100", "1111111111111",
                "1011111111101", "1011111111101", "0111111111110",
                "0001111111000", "0000111110000", "0000011100000",
                "0000011100000", "0000111110000", "0001111111000", "0001111111000",
            ]
        case "person":
            [
                "0000011100000", "0000100010000", "0000100010000",
                "0000100010000", "0000011100000", "0000000000000",
                "0000111110000", "0001000001000", "0010000000100",
                "0100000000010", "0100000000010", "0100000000010", "0111111111110",
            ]
        case "person.fill":
            [
                "0000011100000", "0000111110000", "0000111110000",
                "0000111110000", "0000011100000", "0000000000000",
                "0000111110000", "0001111111000", "0011111111100",
                "0111111111110", "0111111111110", "0111111111110", "0111111111110",
            ]
        default: nil
        }
    }

    var body: some View {
        Group {
            if theme.isPixel, let pattern = Self.pixelPattern(for: systemImage) {
                Canvas { context, size in
                    let pixel = min(size.width, size.height) / 13
                    let origin = CGPoint(x: (size.width - pixel * 13) / 2, y: (size.height - pixel * 13) / 2)
                    var path = Path()
                    for (row, line) in pattern.enumerated() {
                        for (column, value) in line.enumerated() where value == "1" {
                            path.addRect(
                                CGRect(
                                    x: origin.x + CGFloat(column) * pixel,
                                    y: origin.y + CGFloat(row) * pixel, width: pixel, height: pixel))
                        }
                    }
                    context.fill(path, with: .foreground, style: FillStyle(antialiased: false))
                }
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .black))
            }
        }
        .accessibilityHidden(true)
    }
}
