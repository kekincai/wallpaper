// Renders the app icon: a dusk landscape (sun + layered hills) inside the macOS icon squircle.
//
//   swift scripts/make_icon.swift            # writes Assets/AppIcon.icns and Assets/AppIcon-1024.png
//
// Geometry follows the macOS icon grid: 1024 canvas, 824 body inset by 100, soft drop shadow.
import AppKit
import CoreGraphics
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

/// The macOS icon body: a continuous-corner ("squircle") rounded rect, radius 185.4 on an 824 body.
func iconShape(in rect: CGRect) -> CGPath {
    RoundedRectangle(cornerRadius: rect.width * 0.225, style: .continuous).path(in: rect).cgPath
}

/// A hill silhouette from the left edge to the right edge, closed along the bottom.
func hill(_ points: [CGPoint], controls: [(CGPoint, CGPoint)]) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 0, y: 1024))
    path.addLine(to: points[0])
    for (i, point) in points.dropFirst().enumerated() {
        path.addCurve(to: point, control1: controls[i].0, control2: controls[i].1)
    }
    path.addLine(to: CGPoint(x: 1024, y: 1024))
    path.closeSubpath()
    return path
}

func drawIcon(in ctx: CGContext) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = iconShape(in: body)

    // Drop shadow (y grows downward in this flipped context).
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 10), blur: 20, color: rgb(0x000000, 0.25))
    ctx.addPath(shape)
    ctx.setFillColor(rgb(0x2A3360))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()

    // Sky.
    let sky = CGGradient(colorsSpace: space,
                         colors: [rgb(0xFFE4C4), rgb(0xFBC3A6), rgb(0xEE9FB0), rgb(0xB98BC0)] as CFArray,
                         locations: [0, 0.38, 0.62, 0.85])!
    ctx.drawLinearGradient(sky, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])

    // Sun with a soft glow.
    let sunCenter = CGPoint(x: 618, y: 430)
    let glow = CGGradient(colorsSpace: space,
                          colors: [rgb(0xFFF6E0, 0.75), rgb(0xFFF6E0, 0)] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: sunCenter, startRadius: 80,
                           endCenter: sunCenter, endRadius: 260, options: [])
    ctx.setFillColor(rgb(0xFFF7E6))
    ctx.fillEllipse(in: CGRect(x: sunCenter.x - 96, y: sunCenter.y - 96, width: 192, height: 192))

    // Far hills.
    ctx.addPath(hill([CGPoint(x: 100, y: 610), CGPoint(x: 470, y: 560), CGPoint(x: 924, y: 600)],
                     controls: [(CGPoint(x: 230, y: 540), CGPoint(x: 360, y: 520)),
                                (CGPoint(x: 600, y: 600), CGPoint(x: 780, y: 520))]))
    ctx.setFillColor(rgb(0x9C9FD0))
    ctx.fillPath()

    // Middle hills.
    ctx.addPath(hill([CGPoint(x: 100, y: 690), CGPoint(x: 560, y: 660), CGPoint(x: 924, y: 640)],
                     controls: [(CGPoint(x: 250, y: 620), CGPoint(x: 430, y: 610)),
                                (CGPoint(x: 700, y: 712), CGPoint(x: 820, y: 620))]))
    ctx.setFillColor(rgb(0x6670AE))
    ctx.fillPath()

    // Front hills, darker toward the bottom.
    ctx.saveGState()
    ctx.addPath(hill([CGPoint(x: 100, y: 770), CGPoint(x: 924, y: 730)],
                     controls: [(CGPoint(x: 380, y: 690), CGPoint(x: 640, y: 800))]))
    ctx.clip()
    let front = CGGradient(colorsSpace: space,
                           colors: [rgb(0x3A4380), rgb(0x1E2450)] as CFArray,
                           locations: [0, 1])!
    ctx.drawLinearGradient(front, start: CGPoint(x: 512, y: 700), end: CGPoint(x: 512, y: 924), options: [])
    ctx.restoreGState()

    // Gentle top light and bottom shade for depth.
    let sheen = CGGradient(colorsSpace: space,
                           colors: [rgb(0xFFFFFF, 0.22), rgb(0xFFFFFF, 0), rgb(0x000000, 0), rgb(0x000000, 0.12)] as CFArray,
                           locations: [0, 0.35, 0.8, 1])!
    ctx.drawLinearGradient(sheen, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
    ctx.restoreGState()

    // Hairline rim so the edge holds up on light and dark backgrounds.
    ctx.addPath(shape)
    ctx.setStrokeColor(rgb(0x000000, 0.10))
    ctx.setLineWidth(2)
    ctx.strokePath()
}

func render(pixels: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    let scale = CGFloat(pixels) / 1024
    // Flip so drawing code uses top-left origin.
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: scale, y: -scale)
    drawIcon(in: ctx)
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Assets")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    writePNG(render(pixels: points), to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    writePNG(render(pixels: points * 2), to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
writePNG(render(pixels: 1024), to: assets.appendingPathComponent("AppIcon-1024.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", assets.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print(iconutil.terminationStatus == 0 ? "Wrote Assets/AppIcon.icns and Assets/AppIcon-1024.png" : "iconutil failed")
