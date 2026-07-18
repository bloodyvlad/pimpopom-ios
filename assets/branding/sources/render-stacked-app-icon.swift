#!/usr/bin/env swift
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let canvasPixels = 1024
private let canvasRect = CGRect(x: 0, y: 0, width: canvasPixels, height: canvasPixels)
private let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
private let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let backgroundURL = root.appendingPathComponent(
    "assets/branding/sources/PimPoPom-AppIcon-stacked-background-original.png"
)
private let masterURL = root.appendingPathComponent(
    "assets/branding/sources/PimPoPom-AppIcon-stacked-master.png"
)
private let runtimeURL = root.appendingPathComponent(
    "App/Assets.xcassets/AppIcon.appiconset/PimPoPom-AppIcon.png"
)

private struct WordLine {
    let text: String
    let originX: CGFloat
    let baselineY: CGFloat
    let colors: [CGColor]
    let glow: CGColor
}

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

private func color(_ hex: String, alpha: CGFloat = 1) -> CGColor {
    let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard value.count == 6, let rgb = UInt32(value, radix: 16) else {
        fail("Invalid RGB color: \(hex)")
    }
    return CGColor(
        colorSpace: sRGB,
        components: [
            CGFloat((rgb >> 16) & 0xff) / 255,
            CGFloat((rgb >> 8) & 0xff) / 255,
            CGFloat(rgb & 0xff) / 255,
            alpha,
        ]
    )!
}

private func loadImage(_ url: URL) -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        fail("Could not load image: \(url.path)")
    }
    return image
}

private func bitmapContext(opaque: Bool) -> CGContext {
    let alphaInfo: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
    guard
        let context = CGContext(
            data: nil,
            width: canvasPixels,
            height: canvasPixels,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: sRGB,
            bitmapInfo: alphaInfo.rawValue
        )
    else {
        fail("Could not create bitmap context")
    }
    return context
}

private func roundedBlackFont(size: CGFloat) -> CTFont {
    let fontURL = URL(fileURLWithPath: "/System/Library/Fonts/SFNSRounded.ttf") as CFURL
    let descriptors = CTFontManagerCreateFontDescriptorsFromURL(fontURL) as? [CTFontDescriptor] ?? []
    guard
        let black = descriptors.first(where: {
            CTFontDescriptorCopyAttribute($0, kCTFontStyleNameAttribute) as? String == "Black"
        })
    else {
        fail("Could not resolve the macOS SF Rounded Black face")
    }
    return CTFontCreateWithFontDescriptor(black, size, nil)
}

private func textMask(
    text: String,
    font: CTFont,
    x: CGFloat,
    baseline: CGFloat,
    strokeWidth: CGFloat? = nil
) -> CGImage {
    guard
        let mask = CGContext(
            data: nil,
            width: canvasPixels,
            height: canvasPixels,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
    else {
        fail("Could not create text mask")
    }

    mask.setFillColor(gray: 0, alpha: 1)
    mask.fill(canvasRect)

    var attributes: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: CGColor(gray: 1, alpha: 1),
    ]
    if let strokeWidth {
        attributes[kCTStrokeWidthAttributeName] = strokeWidth
        attributes[kCTStrokeColorAttributeName] = CGColor(gray: 1, alpha: 1)
    }

    let attributed = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)!
    let line = CTLineCreateWithAttributedString(attributed)
    mask.textMatrix = CGAffineTransform(a: 1, b: 0, c: 0.11, d: 1, tx: 0, ty: 0)
    mask.textPosition = CGPoint(x: x, y: baseline)
    CTLineDraw(line, mask)

    guard let image = mask.makeImage() else {
        fail("Could not create text mask image")
    }
    return image
}

private func gradientLayer(mask: CGImage, colors: [CGColor], startX: CGFloat, endX: CGFloat) -> CGImage {
    let layer = bitmapContext(opaque: false)
    layer.clear(canvasRect)
    layer.clip(to: canvasRect, mask: mask)
    let locations = colors.indices.map { CGFloat($0) / CGFloat(max(1, colors.count - 1)) }
    guard
        let gradient = CGGradient(
            colorsSpace: sRGB,
            colors: colors as CFArray,
            locations: locations
        )
    else {
        fail("Could not create word gradient")
    }
    layer.drawLinearGradient(
        gradient,
        start: CGPoint(x: startX, y: 0),
        end: CGPoint(x: endX, y: 0),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
    guard let image = layer.makeImage() else {
        fail("Could not create gradient word image")
    }
    return image
}

private func solidLayer(mask: CGImage, fill: CGColor) -> CGImage {
    let layer = bitmapContext(opaque: false)
    layer.clear(canvasRect)
    layer.clip(to: canvasRect, mask: mask)
    layer.setFillColor(fill)
    layer.fill(canvasRect)
    guard let image = layer.makeImage() else {
        fail("Could not create solid word image")
    }
    return image
}

private func wordWidth(_ text: String, font: CTFont) -> CGFloat {
    let attributed = CFAttributedStringCreate(
        nil,
        text as CFString,
        [kCTFontAttributeName: font] as CFDictionary
    )!
    return CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attributed), nil, nil, nil))
}

private func writePNG(_ image: CGImage, to url: URL) {
    guard
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        fail("Could not create PNG destination: \(url.path)")
    }
    CGImageDestinationAddImage(
        destination,
        image,
        [kCGImagePropertyPNGDictionary: [:]] as CFDictionary
    )
    guard CGImageDestinationFinalize(destination) else {
        fail("Could not write PNG: \(url.path)")
    }
}

let background = loadImage(backgroundURL)
let output = bitmapContext(opaque: true)
output.interpolationQuality = .high
output.draw(background, in: canvasRect)

private let font = roundedBlackFont(size: 250)
private let words = [
    WordLine(
        text: "Pim",
        originX: 120,
        baselineY: 715,
        colors: [color("#16b887"), color("#39c85f"), color("#86bd3c")],
        glow: color("#43f4c5", alpha: 0.82)
    ),
    WordLine(
        text: "Po",
        originX: 215,
        baselineY: 445,
        colors: [color("#ffe659"), color("#ff9a56"), color("#ff6fc8")],
        glow: color("#ffb75d", alpha: 0.82)
    ),
    WordLine(
        text: "Pom",
        originX: 310,
        baselineY: 175,
        colors: [color("#ff6fc8"), color("#a58aff"), color("#69d7ff")],
        glow: color("#a58aff", alpha: 0.86)
    ),
]

for word in words {
    let width = wordWidth(word.text, font: font)
    let fillMask = textMask(
        text: word.text,
        font: font,
        x: word.originX,
        baseline: word.baselineY
    )
    let outlineMask = textMask(
        text: word.text,
        font: font,
        x: word.originX,
        baseline: word.baselineY,
        strokeWidth: -5
    )
    let gradient = gradientLayer(
        mask: fillMask,
        colors: word.colors,
        startX: word.originX,
        endX: word.originX + width
    )
    let outline = solidLayer(mask: outlineMask, fill: color("#07143b", alpha: 0.88))

    output.saveGState()
    output.setShadow(offset: .zero, blur: 30, color: word.glow)
    output.draw(gradient, in: canvasRect)
    output.restoreGState()
    output.draw(outline, in: canvasRect)
    output.draw(gradient, in: canvasRect)
}

let pomWidth = wordWidth("Pom", font: font)
let ringCenter = CGPoint(x: 310 + pomWidth + 58, y: 306)
output.saveGState()
output.setStrokeColor(color("#63fff2"))
output.setLineWidth(10)
output.setShadow(offset: .zero, blur: 22, color: color("#63fff2", alpha: 0.88))
output.strokeEllipse(in: CGRect(x: ringCenter.x - 22, y: ringCenter.y - 22, width: 44, height: 44))
output.restoreGState()

guard let finalImage = output.makeImage() else {
    fail("Could not create final app icon")
}
writePNG(finalImage, to: masterURL)
writePNG(finalImage, to: runtimeURL)
print("Wrote \(masterURL.path)")
print("Wrote \(runtimeURL.path)")
