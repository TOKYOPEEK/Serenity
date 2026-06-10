// Generates Serenity/Assets.xcassets/AppIcon.appiconset/AppIcon.png (1024×1024, no alpha).
// Mirrors the in-app SerenityLogo: navy background, cosmic gradient circle, white leaf + sparkle.
// Run: swift scripts/generate_icon.swift
import AppKit

let canvas: CGFloat = 1024

func color(_ hex: UInt32) -> NSColor {
    NSColor(calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
}

func whiteSymbol(_ name: String, pointSize: CGFloat, weight: NSFont.Weight) -> NSImage? {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else { return nil }
    return NSImage(size: symbol.size, flipped: false) { rect in
        NSColor.white.set()
        rect.fill()
        symbol.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
        return true
    }
}

// Opaque context (App Store icons must not have an alpha channel)
guard let ctx = CGContext(
    data: nil, width: Int(canvas), height: Int(canvas),
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fatalError("no context") }

NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

// Background
ctx.setFillColor(color(0x080D18).cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))

// Soft radial glow behind the circle
let glowColors = [color(0x8B7CF8).withAlphaComponent(0.28).cgColor, NSColor.clear.cgColor] as CFArray
if let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0, 1]) {
    ctx.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: canvas / 2, y: canvas / 2), startRadius: 0,
        endCenter: CGPoint(x: canvas / 2, y: canvas / 2), endRadius: canvas * 0.52,
        options: []
    )
}

// Cosmic gradient circle
let circleSize = canvas * 0.62
let circleRect = CGRect(
    x: (canvas - circleSize) / 2, y: (canvas - circleSize) / 2,
    width: circleSize, height: circleSize
)
ctx.saveGState()
ctx.addEllipse(in: circleRect)
ctx.clip()
let circleColors = [color(0x8B7CF8).cgColor, color(0xA5B4FC).cgColor] as CFArray
if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: circleColors, locations: [0, 1]) {
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: circleRect.minX, y: circleRect.maxY),
        end: CGPoint(x: circleRect.maxX, y: circleRect.minY),
        options: []
    )
}
ctx.restoreGState()

// Leaf (slightly down-left of center, like SerenityLogo)
if let leaf = whiteSymbol("leaf.fill", pointSize: circleSize * 0.38, weight: .medium) {
    let s = leaf.size
    let origin = CGPoint(
        x: canvas / 2 - s.width / 2 - circleSize * 0.04,
        y: canvas / 2 - s.height / 2 - circleSize * 0.04
    )
    leaf.draw(in: CGRect(origin: origin, size: s), from: .zero, operation: .sourceOver, fraction: 0.92)
}

// Sparkle accent (top-right)
if let sparkle = whiteSymbol("sparkle", pointSize: circleSize * 0.20, weight: .bold) {
    let s = sparkle.size
    let origin = CGPoint(
        x: canvas / 2 - s.width / 2 + circleSize * 0.20,
        y: canvas / 2 - s.height / 2 + circleSize * 0.20
    )
    sparkle.draw(in: CGRect(origin: origin, size: s), from: .zero, operation: .sourceOver, fraction: 1)
}

NSGraphicsContext.current = nil

guard let cgImage = ctx.makeImage() else { fatalError("no image") }
let rep = NSBitmapImageRep(cgImage: cgImage)
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("no png") }

let out = URL(fileURLWithPath: "Serenity/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
try! png.write(to: out)
print("Wrote \(out.path) (\(png.count) bytes)")
