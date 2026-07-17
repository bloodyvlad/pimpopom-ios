#!/usr/bin/env swift
import AppKit
import Foundation

private struct PixelBounds {
    let minX: Int
    let minY: Int
    let maxX: Int
    let maxY: Int

    var width: Int { maxX - minX }
    var height: Int { maxY - minY }
}

private let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
private let sourceRoot = root.appendingPathComponent("assets/pets/sources")
private let runtimeRoot = root.appendingPathComponent("App/Resources/Pets")

private func bitmap(at url: URL) throws -> NSBitmapImageRep {
    let data = try Data(contentsOf: url)
    guard let bitmap = NSBitmapImageRep(data: data) else {
        throw CocoaError(.fileReadCorruptFile)
    }
    return bitmap
}

private func emptyBitmap(width: Int, height: Int) throws -> NSBitmapImageRep {
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        )
    else {
        throw CocoaError(.coderInvalidValue)
    }
    bitmap.bitmapData?.initialize(repeating: 0, count: width * height * 4)
    return bitmap
}

private func bounds(
    in bitmap: NSBitmapImageRep,
    xRange: Range<Int>,
    yRange: Range<Int>,
    alphaThreshold: CGFloat = 0.10
) throws -> PixelBounds {
    var minX = xRange.upperBound
    var minY = yRange.upperBound
    var maxX = xRange.lowerBound
    var maxY = yRange.lowerBound

    for y in yRange {
        for x in xRange {
            guard let color = bitmap.colorAt(x: x, y: y),
                color.alphaComponent > alphaThreshold
            else { continue }
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x + 1)
            maxY = max(maxY, y + 1)
        }
    }

    guard minX < maxX, minY < maxY else {
        throw CocoaError(.coderReadCorrupt)
    }
    return PixelBounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
}

private func drawNearest(
    source: NSBitmapImageRep,
    sourceBounds: PixelBounds,
    destination: NSBitmapImageRep,
    destinationX: Int,
    destinationY: Int,
    width: Int,
    height: Int
) {
    for y in 0..<height {
        let sourceY =
            sourceBounds.minY
            + min(sourceBounds.height - 1, y * sourceBounds.height / height)
        for x in 0..<width {
            let sourceX =
                sourceBounds.minX
                + min(sourceBounds.width - 1, x * sourceBounds.width / width)
            guard let rawColor = source.colorAt(x: sourceX, y: sourceY),
                let color = rawColor.usingColorSpace(.deviceRGB),
                color.alphaComponent >= 0.38
            else { continue }

            destination.setColor(
                NSColor(
                    deviceRed: color.redComponent,
                    green: color.greenComponent,
                    blue: color.blueComponent,
                    alpha: 1
                ),
                atX: destinationX + x,
                y: destinationY + y
            )
        }
    }
}

private func write(_ bitmap: NSBitmapImageRep, to urls: [URL]) throws {
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    for url in urls {
        try data.write(to: url, options: .atomic)
        print("Wrote \(url.path.replacingOccurrences(of: root.path + "/", with: ""))")
    }
}

private func buildSpriteSheet() throws {
    let source = try bitmap(
        at: sourceRoot.appendingPathComponent("alpha/pancake-directional-alpha.png")
    )
    let frameBounds = try (0..<10).map { index -> PixelBounds in
        let column = index % 5
        let visualRow = index < 5 ? 0 : 1
        let x0 = source.pixelsWide * column / 5
        let x1 = source.pixelsWide * (column + 1) / 5
        let y0 = source.pixelsHigh * visualRow / 2
        let y1 = source.pixelsHigh * (visualRow + 1) / 2
        return try bounds(in: source, xRange: x0..<x1, yRange: y0..<y1)
    }

    let widest = frameBounds.map(\.width).max() ?? 1
    let tallest = frameBounds.map(\.height).max() ?? 1
    let scale = min(60.0 / Double(widest), 58.0 / Double(tallest))
    let sheet = try emptyBitmap(width: 640, height: 64)

    for (index, frame) in frameBounds.enumerated() {
        let width = max(1, Int((Double(frame.width) * scale).rounded()))
        let height = max(1, Int((Double(frame.height) * scale).rounded()))
        drawNearest(
            source: source,
            sourceBounds: frame,
            destination: sheet,
            destinationX: index * 64 + (64 - width) / 2,
            destinationY: 2,
            width: width,
            height: height
        )
    }

    try write(
        sheet,
        to: [
            sourceRoot.appendingPathComponent("pancake-sprite.png"),
            runtimeRoot.appendingPathComponent("pancake-sprite.png"),
        ]
    )
}

private func buildFloor() throws {
    let source = try bitmap(
        at: sourceRoot.appendingPathComponent("alpha/pancake-floor-alpha.png")
    )
    let sourceBounds = try bounds(
        in: source,
        xRange: 0..<source.pixelsWide,
        yRange: 0..<source.pixelsHigh
    )
    let scale = min(30.0 / Double(sourceBounds.width), 32.0 / Double(sourceBounds.height))
    let width = max(1, Int((Double(sourceBounds.width) * scale).rounded()))
    let height = max(1, Int((Double(sourceBounds.height) * scale).rounded()))
    let sheet = try emptyBitmap(width: 64, height: 48)

    // The left 32×48 cell is the complete back layer. The right cell remains
    // transparent so the pet is never obscured by a synthetic front rim.
    drawNearest(
        source: source,
        sourceBounds: sourceBounds,
        destination: sheet,
        destinationX: (32 - width) / 2,
        destinationY: 7,
        width: width,
        height: height
    )

    try write(
        sheet,
        to: [
            sourceRoot.appendingPathComponent("pancake-floor.png"),
            runtimeRoot.appendingPathComponent("pancake-floor.png"),
        ]
    )
}

do {
    try buildSpriteSheet()
    try buildFloor()
} catch {
    fputs("Pancake asset build failed: \(error)\n", stderr)
    exit(1)
}
