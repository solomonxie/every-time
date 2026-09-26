// Renders the 1024×1024 app icon (opaque, no alpha). Run: swift scripts/make_icon.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let s = CGFloat(size), c = CGPoint(x: s / 2, y: s / 2)

let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
    CGColor(red: 0.16, green: 0.20, blue: 0.62, alpha: 1),
    CGColor(red: 0.20, green: 0.52, blue: 0.96, alpha: 1),
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: s, y: s), options: [])

let r: CGFloat = 330
ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.28))
ctx.setLineWidth(14)
for w in [r * 0.45, r * 0.85] {
    ctx.strokeEllipse(in: CGRect(x: c.x - w, y: c.y - r, width: w * 2, height: r * 2))
}
for y in [-r * 0.5, 0, r * 0.5] {
    let half = sqrt(r * r - y * y)
    ctx.move(to: CGPoint(x: c.x - half, y: c.y + y))
    ctx.addLine(to: CGPoint(x: c.x + half, y: c.y + y))
}
ctx.strokePath()

ctx.setStrokeColor(CGColor(gray: 1, alpha: 1))
ctx.setLineWidth(40)
ctx.strokeEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))

ctx.setLineCap(.round)
ctx.setLineWidth(44)
ctx.move(to: c); ctx.addLine(to: CGPoint(x: c.x, y: c.y + r * 0.68))
ctx.strokePath()
ctx.setStrokeColor(CGColor(red: 1, green: 0.62, blue: 0.2, alpha: 1))
ctx.move(to: c); ctx.addLine(to: CGPoint(x: c.x + r * 0.5, y: c.y - r * 0.2))
ctx.strokePath()
ctx.setFillColor(CGColor(gray: 1, alpha: 1))
ctx.fillEllipse(in: CGRect(x: c.x - 34, y: c.y - 34, width: 68, height: 68))

let url = URL(fileURLWithPath: "EveryTime/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
