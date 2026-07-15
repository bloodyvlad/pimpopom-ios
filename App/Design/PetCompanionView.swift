import SwiftUI
import UIKit

struct PetPresentation: Identifiable, Equatable, Sendable {
    let id: String
    let kind: String
    let spriteAsset: String?
    let habitatAsset: String?
    let usesPlaceholderArt: Bool

    static func resolve(_ id: String) -> PetPresentation {
        presentations[id]
            ?? PetPresentation(
                id: id,
                kind: "Companion",
                spriteAsset: nil,
                habitatAsset: nil,
                usesPlaceholderArt: true
            )
    }

    private static let presentations: [String: PetPresentation] = [
        "foka": PetPresentation(
            id: "foka",
            kind: "Baby seal",
            spriteAsset: "foka-sprite",
            habitatAsset: "foka-ice-floe",
            usesPlaceholderArt: false
        ),
        "kesha": PetPresentation(
            id: "kesha",
            kind: "Green-yellow parrot",
            spriteAsset: "kesha-sprite",
            habitatAsset: "kesha-perch",
            usesPlaceholderArt: false
        ),
        "tauta": PetPresentation(
            id: "tauta",
            kind: "Border collie",
            spriteAsset: "tauta-sprite",
            habitatAsset: "tauta-bed",
            usesPlaceholderArt: false
        ),
        "misha": PetPresentation(
            id: "misha",
            kind: "Grey cat",
            spriteAsset: "misha-sprite",
            habitatAsset: "misha-climber",
            usesPlaceholderArt: false
        ),
        "mitsuri": PetPresentation(
            id: "mitsuri",
            kind: "Red rabbit",
            spriteAsset: "mitsuri-sprite",
            habitatAsset: "mitsuri-cushion",
            usesPlaceholderArt: false
        ),
        "pancake": PetPresentation(
            id: "pancake",
            kind: "Pancake companion",
            spriteAsset: nil,
            habitatAsset: nil,
            usesPlaceholderArt: true
        ),
    ]
}

struct PetCompanionView: View {
    let petID: String
    var size: CGFloat = 64
    var includesHabitat = true
    var animated = true

    private var presentation: PetPresentation { .resolve(petID) }

    var body: some View {
        Group {
            if presentation.id == "pancake" {
                PancakePlaceholder(size: size)
            } else if let spriteAsset = presentation.spriteAsset {
                TimelineView(.periodic(from: .now, by: animated ? 0.16 : 60)) { context in
                    artwork(spriteAsset: spriteAsset, date: context.date)
                }
            } else {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: size * 0.48, weight: .black))
                    .foregroundStyle(.cyan)
                    .frame(width: size, height: size)
                    .background(.white.opacity(0.08), in: Circle())
            }
        }
        .frame(width: size * 1.25, height: includesHabitat ? size * 1.12 : size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(presentation.kind) companion")
    }

    @ViewBuilder
    private func artwork(spriteAsset: String, date: Date) -> some View {
        let frameSequence = animated ? [0, 2, 3, 0, 6, 7, 8, 9, 0] : [0]
        let frameIndex = frameSequence[
            Int(date.timeIntervalSinceReferenceDate / 0.16) % frameSequence.count
        ]

        ZStack {
            if includesHabitat,
                let habitatAsset = presentation.habitatAsset,
                let back = PetArtwork.habitatLayer(named: habitatAsset, index: 0)
            {
                Image(uiImage: back)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: size, height: size * 1.5)
                    .offset(y: size * 0.18)
            }

            if let sprite = PetArtwork.spriteFrame(named: spriteAsset, index: frameIndex) {
                Image(uiImage: sprite)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: size, height: size)
                    .zIndex(presentation.id == "misha" ? 3 : 1)
            }

            if includesHabitat,
                let habitatAsset = presentation.habitatAsset,
                let front = PetArtwork.habitatLayer(named: habitatAsset, index: 1)
            {
                Image(uiImage: front)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: size, height: size * 1.5)
                    .offset(y: size * 0.18)
                    .zIndex(2)
            }
        }
    }
}

private struct PancakePlaceholder: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.yellow.opacity(0.20))
                .frame(width: size * 0.95, height: size * 0.20)
                .offset(y: size * 0.39)
            VStack(spacing: -size * 0.08) {
                ForEach(0..<3, id: \.self) { layer in
                    Capsule()
                        .fill(layer == 0 ? Color(hex: "#ffd773") : Color(hex: "#d58a3a"))
                        .overlay(Capsule().stroke(Color(hex: "#7f451d"), lineWidth: 1.5))
                        .frame(width: size * (0.66 + CGFloat(layer) * 0.07), height: size * 0.23)
                }
            }
            HStack(spacing: size * 0.16) {
                Circle().fill(.black).frame(width: size * 0.07, height: size * 0.07)
                Circle().fill(.black).frame(width: size * 0.07, height: size * 0.07)
            }
            .offset(y: -size * 0.02)
        }
        .frame(width: size, height: size)
    }
}

@MainActor
private enum PetArtwork {
    private static var cache: [String: UIImage] = [:]

    static func spriteFrame(named name: String, index: Int) -> UIImage? {
        cropped(named: name, index: index, columns: 10)
    }

    static func habitatLayer(named name: String, index: Int) -> UIImage? {
        cropped(named: name, index: index, columns: 2)
    }

    private static func cropped(named name: String, index: Int, columns: Int) -> UIImage? {
        let key = "\(name)-\(columns)-\(index)"
        if let cached = cache[key] { return cached }
        guard let source = UIImage(named: name),
            let image = source.cgImage,
            index >= 0,
            index < columns
        else { return nil }

        let cellWidth = image.width / columns
        let rect = CGRect(x: index * cellWidth, y: 0, width: cellWidth, height: image.height)
        guard let frame = image.cropping(to: rect) else { return nil }
        let result = UIImage(cgImage: frame, scale: 1, orientation: .up)
        cache[key] = result
        return result
    }
}
