// Makes a WoW Forever settings preview from an in-game screenshot: crops a
// square, scales it to 520×520, and rounds the corners like the Classic and
// Retail previews. Uses only macOS's built-in image libraries.
//
//   swift tools/settings-image.swift <screenshot> <name> <x> <y> <size>
//
// <name> is the option's image name (e.g. unitdebuff); the result is written
// to Art/Settings/Forever/<name>.png. <x> <y> is the crop's top-left corner and
// <size> its side, in screenshot pixels. List the name in
// FOREVER_SETTINGS_IMAGES in config.lua so Forever uses it.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputSize = 520
let cornerRadius: CGFloat = 24

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count == 6,
      let cropX = Int(arguments[3]), let cropY = Int(arguments[4]), let cropSize = Int(arguments[5]),
      cropSize > 0 else {
    fail("usage: swift tools/settings-image.swift <screenshot> <name> <x> <y> <size>")
}

let inputURL = URL(fileURLWithPath: arguments[1])
let name = arguments[2].hasSuffix(".png") ? String(arguments[2].dropLast(4)) : arguments[2]
let repoURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let outputDirectory = repoURL.appendingPathComponent("Art/Settings/Forever")
let outputURL = outputDirectory.appendingPathComponent(name + ".png")

guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
      let screenshot = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fail("could not read \(inputURL.path)")
}

let bounds = CGRect(x: 0, y: 0, width: screenshot.width, height: screenshot.height)
let cropRect = CGRect(x: cropX, y: cropY, width: cropSize, height: cropSize)
guard bounds.contains(cropRect) else {
    fail("crop \(cropRect) is outside the \(screenshot.width)×\(screenshot.height) screenshot")
}
guard let cropped = screenshot.cropping(to: cropRect) else {
    fail("could not crop the screenshot")
}
if cropSize < outputSize {
    print("note: a \(cropSize)px crop is scaled up to \(outputSize)px and may look soft")
}

guard let context = CGContext(
    data: nil, width: outputSize, height: outputSize, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fail("could not create the output image")
}

let outputRect = CGRect(x: 0, y: 0, width: outputSize, height: outputSize)
context.interpolationQuality = .high
context.setShouldAntialias(true)
context.addPath(CGPath(roundedRect: outputRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
context.clip()
context.draw(cropped, in: outputRect)

guard let image = context.makeImage() else {
    fail("could not render the output image")
}

try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fail("could not write \(outputURL.path)")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fail("could not write \(outputURL.path)")
}

print("wrote Art/Settings/Forever/\(name).png")
