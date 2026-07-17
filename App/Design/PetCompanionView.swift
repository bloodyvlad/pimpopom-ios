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
            spriteAsset: "pancake-sprite",
            habitatAsset: "pancake-floor",
            usesPlaceholderArt: false
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

struct PetAnimationStep: Equatable, Sendable {
    let frameIndex: Int
    let delayAfter: Duration
}

enum PetAnimationPlan {
    static func wakeAndTurn(to facing: PetFacing) -> [PetAnimationStep] {
        [
            PetAnimationStep(frameIndex: 9, delayAfter: .milliseconds(189)),
            PetAnimationStep(frameIndex: 8, delayAfter: .milliseconds(261)),
        ] + turn(to: facing)
    }

    static func turn(to facing: PetFacing) -> [PetAnimationStep] {
        switch facing {
        case .front:
            [PetAnimationStep(frameIndex: 0, delayAfter: .zero)]
        case .halfLeft:
            [
                PetAnimationStep(frameIndex: 0, delayAfter: .milliseconds(150)),
                PetAnimationStep(frameIndex: 1, delayAfter: .milliseconds(150)),
                PetAnimationStep(frameIndex: 2, delayAfter: .zero),
            ]
        case .left:
            [
                PetAnimationStep(frameIndex: 0, delayAfter: .milliseconds(100)),
                PetAnimationStep(frameIndex: 1, delayAfter: .milliseconds(100)),
                PetAnimationStep(frameIndex: 2, delayAfter: .milliseconds(100)),
                PetAnimationStep(frameIndex: 3, delayAfter: .zero),
            ]
        case .halfRight:
            [
                PetAnimationStep(frameIndex: 0, delayAfter: .milliseconds(150)),
                PetAnimationStep(frameIndex: 5, delayAfter: .milliseconds(150)),
                PetAnimationStep(frameIndex: 6, delayAfter: .zero),
            ]
        case .right:
            [
                PetAnimationStep(frameIndex: 0, delayAfter: .milliseconds(100)),
                PetAnimationStep(frameIndex: 5, delayAfter: .milliseconds(100)),
                PetAnimationStep(frameIndex: 6, delayAfter: .milliseconds(100)),
                PetAnimationStep(frameIndex: 7, delayAfter: .zero),
            ]
        }
    }
}

enum PetFacing: String, Equatable, Sendable {
    case front
    case halfLeft
    case left
    case halfRight
    case right

    static let halfTurnInteractionFraction: CGFloat = 0.15
    // One physical pixel on the 2x SE profile keeps vertical-axis taps centered
    // without turning the exact-center rule into a broad dead zone.
    static let frontAlignmentTolerance: CGFloat = 0.5

    var frameIndex: Int {
        switch self {
        case .front: 0
        case .halfLeft: 2
        case .left: 3
        case .halfRight: 6
        case .right: 7
        }
    }

    static func resolve(
        pointerX: CGFloat,
        petCenterX: CGFloat,
        interactionWidth: CGFloat,
        fallback: PetFacing = .front
    ) -> PetFacing {
        guard pointerX.isFinite, petCenterX.isFinite,
            interactionWidth.isFinite, interactionWidth > 0
        else { return fallback }

        let deltaX = pointerX - petCenterX
        if abs(deltaX) <= frontAlignmentTolerance { return .front }
        let isHalfTurn = abs(deltaX) <= interactionWidth * halfTurnInteractionFraction
        if deltaX < 0 {
            return isHalfTurn ? .halfLeft : .left
        }
        return isHalfTurn ? .halfRight : .right
    }
}

struct PetCompanionView: View {
    let petID: String
    var size: CGFloat = 64
    var placement = PetCompanionPlacement.menu
    var animationTrigger = 0
    var facing = PetFacing.front
    var isSleeping = false

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
            if let spriteAsset = presentation.spriteAsset {
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
        .task(id: "\(petID)-\(placement)-\(animationTrigger)-\(facing.rawValue)-\(isSleeping)") {
            await updateAnimation()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(presentation.kind) companion")
        .accessibilityValue(isSleeping ? "Sleeping" : facing.rawValue)
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

    private func updateAnimation() async {
        if placement == .shop {
            await playPreviewIfRequested()
            return
        }

        if isSleeping {
            guard frameIndex != 9 else { return }
            try? await Task.sleep(for: .milliseconds(261))
            guard !Task.isCancelled else { return }
            frameIndex = 8
            try? await Task.sleep(for: .milliseconds(189))
            guard !Task.isCancelled else { return }
            frameIndex = 9
            return
        }

        let plan =
            frameIndex == 9
            ? PetAnimationPlan.wakeAndTurn(to: facing)
            : PetAnimationPlan.turn(to: facing)
        for step in plan {
            guard !Task.isCancelled else { return }
            frameIndex = step.frameIndex
            if step.delayAfter > .zero {
                try? await Task.sleep(for: step.delayAfter)
            }
        }
    }

    private func playPreviewIfRequested() async {
        frameIndex = 0
        guard animationTrigger > 0 else { return }

        if facing != .front {
            for step in PetAnimationPlan.turn(to: facing) {
                guard !Task.isCancelled else { return }
                frameIndex = step.frameIndex
                if step.delayAfter > .zero {
                    try? await Task.sleep(for: step.delayAfter)
                }
            }
            return
        }

        for frame in PetPreviewAnimation.frames {
            guard !Task.isCancelled else { return }
            frameIndex = frame
            try? await Task.sleep(for: PetPreviewAnimation.frameDuration)
        }
        guard !Task.isCancelled else { return }
        frameIndex = 0
    }

    private var shouldShowHabitat: Bool {
        !(presentation.id == "kesha" && frameIndex >= 8)
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
            let point = spriteSize / 64
            let spriteY =
                switch petID {
                case "foka": -9 * point
                case "misha": 1 * point
                case "tauta": 6 * point
                case "pancake": 26 * point
                default: -4 * point
                }
            return PetArtworkGeometry(
                canvas: CGSize(width: spriteSize, height: spriteSize * 2.25),
                spriteOffset: CGSize(width: 0, height: spriteY),
                habitatSize: CGSize(width: spriteSize, height: spriteSize * 1.5),
                habitatOffset: CGSize(width: 0, height: habitatY)
            )
        case .shop:
            let inset = spriteSize * 0.125
            let point = spriteSize / 64
            let spriteY =
                switch petID {
                case "foka": -11 * point
                case "kesha": -10 * point
                case "misha": -5 * point
                case "pancake": 20 * point
                default: CGFloat.zero
                }
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

    static func gameplayViewVerticalOffset(petID: String) -> CGFloat {
        petID == "pancake" ? 10 : -10
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
