#!/usr/bin/env swift

import AppKit
import Foundation

enum IconError: Error, CustomStringConvertible {
    case invalidArguments
    case invalidSource(String)
    case cannotCreateBitmap(Int)
    case cannotCreateContext(Int)
    case cannotEncodePNG(String)

    var description: String {
        switch self {
        case .invalidArguments:
            return "Usage: generate-app-icon.swift <source.svg> <output.iconset>"
        case .invalidSource(let path):
            return "Could not load SVG source: \(path)"
        case .cannotCreateBitmap(let size):
            return "Could not create \(size)x\(size) bitmap"
        case .cannotCreateContext(let size):
            return "Could not create graphics context for \(size)x\(size) icon"
        case .cannotEncodePNG(let path):
            return "Could not encode PNG: \(path)"
        }
    }
}

func render(
    source: NSImage,
    pixelSize: Int,
    outputURL: URL
) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw IconError.cannotCreateBitmap(pixelSize)
    }

    bitmap.size = NSSize(
        width: pixelSize,
        height: pixelSize
    )

    guard let context = NSGraphicsContext(
        bitmapImageRep: bitmap
    ) else {
        throw IconError.cannotCreateContext(pixelSize)
    }

    NSGraphicsContext.saveGraphicsState()
    defer {
        NSGraphicsContext.restoreGraphicsState()
    }

    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    NSColor.clear.setFill()
    NSRect(
        x: 0,
        y: 0,
        width: pixelSize,
        height: pixelSize
    ).fill()

    source.draw(
        in: NSRect(
            x: 0,
            y: 0,
            width: pixelSize,
            height: pixelSize
        ),
        from: NSRect(
            origin: .zero,
            size: source.size
        ),
        operation: .sourceOver,
        fraction: 1.0,
        respectFlipped: true,
        hints: [
            .interpolation:
                NSImageInterpolation.high
        ]
    )

    context.flushGraphics()

    guard let png = bitmap.representation(
        using: .png,
        properties: [:]
    ) else {
        throw IconError.cannotEncodePNG(
            outputURL.path
        )
    }

    try png.write(
        to: outputURL,
        options: .atomic
    )
}

do {
    guard CommandLine.arguments.count == 3 else {
        throw IconError.invalidArguments
    }

    let sourceURL = URL(
        fileURLWithPath:
            CommandLine.arguments[1]
    )
    let outputDirectory = URL(
        fileURLWithPath:
            CommandLine.arguments[2],
        isDirectory: true
    )

    guard let source = NSImage(
        contentsOf: sourceURL
    ) else {
        throw IconError.invalidSource(
            sourceURL.path
        )
    }

    try FileManager.default
        .createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

    let outputs: [(String, Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    for (name, size) in outputs {
        try render(
            source: source,
            pixelSize: size,
            outputURL:
                outputDirectory
                .appendingPathComponent(name)
        )
    }

    print(
        "Rendered iconset from \(sourceURL.lastPathComponent)"
    )
} catch {
    FileHandle.standardError.write(
        Data("error: \(error)\n".utf8)
    )
    exit(1)
}
