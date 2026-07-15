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
        "muse": PetPresentation(
            id: "muse",
            kind: "Home companion",
            spriteAsset: "muse-sprite",
            habitatAsset: "muse-floor",
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

enum PetCompanionPlacement: Equatable, Sendable {
    case menu
    case shop
    case gameplay
    case leaderboard
}

enum PetPreviewAnimation {
    static let frames = [0, 2, 3, 0, 6, 7, 8, 9, 0]
    static let frameDuration = Duration.milliseconds(160)
}

struct PetCompanionView: View {
    let petID: String
    var size: CGFloat = 64
    var placement = PetCompanionPlacement.menu
    var animationTrigger = 0

    @State private var frameIndex = 0

    private var presentation: PetPresentation { .resolve(petID) }
    private var geometry: PetArtworkGeometry {
        PetArtworkGeometry.resolve(
            placement: placement,
            petID: presentation.id,
            spriteSize: size
        )
    }

    var body: some View {
        Group {
            if presentation.id == "pancake" {
                PancakePlaceholder(size: size)
                    .offset(
                        x: (geometry.canvas.width - size) / 2,
                        y: max(0, geometry.spriteOffset.height)
                    )
            } else if let spriteAsset = presentation.spriteAsset {
                artwork(spriteAsset: spriteAsset)
            } else {
                Color.clear
            }
        }
        .frame(
            width: geometry.canvas.width,
            height: geometry.canvas.height,
            alignment: .topLeading
        )
        .clipped(antialiased: false)
        .task(id: "\(petID)-\(animationTrigger)") {
            await playPreviewIfRequested()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(presentation.kind) companion")
    }

    @ViewBuilder
    private func artwork(spriteAsset: String) -> some View {
        ZStack(alignment: .topLeading) {
            if placement != .gameplay,
                shouldShowHabitat,
                let habitatAsset = presentation.habitatAsset,
                let back = PetArtwork.habitatLayer(named: habitatAsset, index: 0)
            {
                Image(uiImage: back)
                    .resizable()
                    .interpolation(.none)
                    .frame(
                        width: geometry.habitatSize.width,
                        height: geometry.habitatSize.height
                    )
                    .offset(
                        x: geometry.habitatOffset.width,
                        y: geometry.habitatOffset.height
                    )
            }

            if let sprite = PetArtwork.spriteFrame(named: spriteAsset, index: frameIndex) {
                Image(uiImage: sprite)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: size, height: size)
                    .offset(
                        x: geometry.spriteOffset.width,
                        y: geometry.spriteOffset.height
                    )
                    .shadow(color: .black.opacity(0.54), radius: 2, y: 3)
                    .zIndex(presentation.id == "misha" ? 4 : 2)
            }

            if placement != .gameplay,
                shouldShowHabitat,
                let habitatAsset = presentation.habitatAsset,
                let front = PetArtwork.habitatLayer(named: habitatAsset, index: 1)
            {
                Image(uiImage: front)
                    .resizable()
                    .interpolation(.none)
                    .frame(
                        width: geometry.habitatSize.width,
                        height: geometry.habitatSize.height
                    )
                    .offset(
                        x: geometry.habitatOffset.width,
                        y: geometry.habitatOffset.height
                    )
                    .zIndex(3)
            }
        }
        .frame(
            width: geometry.canvas.width,
            height: geometry.canvas.height,
            alignment: .topLeading
        )
    }

    private func playPreviewIfRequested() async {
        frameIndex = 0
        guard placement == .shop, animationTrigger > 0 else { return }

        for frame in PetPreviewAnimation.frames {
            guard !Task.isCancelled else { return }
            frameIndex = frame
            try? await Task.sleep(for: PetPreviewAnimation.frameDuration)
        }
        guard !Task.isCancelled else { return }
        frameIndex = 0
    }

    private var shouldShowHabitat: Bool {
        !(placement == .shop && presentation.id == "kesha" && frameIndex >= 8)
    }
}

struct PetArtworkGeometry {
    let canvas: CGSize
    let spriteOffset: CGSize
    let habitatSize: CGSize
    let habitatOffset: CGSize

    static func resolve(
        placement: PetCompanionPlacement,
        petID: String,
        spriteSize: CGFloat
    ) -> PetArtworkGeometry {
        switch placement {
        case .menu:
            let habitatY = petID == "mitsuri" ? -spriteSize * 0.3125 : spriteSize * 0.75
            let spriteY = ["foka", "kesha"].contains(petID) ? -spriteSize * 0.09375 : -spriteSize * 0.0625
            return PetArtworkGeometry(
                canvas: CGSize(width: spriteSize, height: spriteSize * 2.25),
                spriteOffset: CGSize(width: 0, height: spriteY),
                habitatSize: CGSize(width: spriteSize, height: spriteSize * 1.5),
                habitatOffset: CGSize(width: 0, height: habitatY)
            )
        case .shop:
            let inset = spriteSize * 0.125
            let spriteY =
                ["foka", "kesha"].contains(petID)
                ? -spriteSize * 0.078_125
                : 0
            return PetArtworkGeometry(
                canvas: CGSize(width: spriteSize * 1.25, height: spriteSize * 1.25),
                spriteOffset: CGSize(width: inset, height: spriteY),
                habitatSize: CGSize(width: spriteSize, height: spriteSize),
                habitatOffset: CGSize(width: inset, height: spriteSize * 0.75)
            )
        case .gameplay:
            return PetArtworkGeometry(
                canvas: CGSize(width: spriteSize, height: spriteSize),
                spriteOffset: .zero,
                habitatSize: .zero,
                habitatOffset: .zero
            )
        case .leaderboard:
            let scale = spriteSize / 36
            let habitatY = petID == "mitsuri" ? -8 * scale : 27 * scale
            return PetArtworkGeometry(
                canvas: CGSize(width: 44 * scale, height: 44 * scale),
                spriteOffset: CGSize(width: 4 * scale, height: scale),
                habitatSize: CGSize(width: spriteSize, height: 54 * scale),
                habitatOffset: CGSize(width: 4 * scale, height: habitatY)
            )
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
