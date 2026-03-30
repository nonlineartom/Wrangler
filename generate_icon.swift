import AppKit
import CoreGraphics

// Draw cowboy hat icon at exact pixel size using CGContext (no Retina scaling)
func drawIcon(pixelSize: Int) -> Data? {
    let size = CGFloat(pixelSize)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // Flip coordinate system so origin is top-left (easier to reason about)
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)

    let w = size
    let h = size
    let cx = w / 2

    // Background: warm dark tone with rounded rect
    let bgColor = CGColor(red: 0.13, green: 0.11, blue: 0.09, alpha: 1)
    ctx.setFillColor(bgColor)
    let radius = w * 0.22
    let bgPath = CGMutablePath()
    bgPath.addRoundedRect(in: CGRect(x: 0, y: 0, width: w, height: h), cornerWidth: radius, cornerHeight: radius)
    ctx.addPath(bgPath)
    ctx.fillPath()

    // Hat stroke colour: warm amber
    let hatColor = CGColor(red: 0.95, green: 0.80, blue: 0.45, alpha: 1.0)
    let strokeWidth = max(1.0, size * 0.028)

    ctx.setStrokeColor(hatColor)
    ctx.setLineWidth(strokeWidth)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // --- Brim ---
    let brimY = h * 0.30
    let brimHalfW = w * 0.44
    let brimH = h * 0.10

    let brimPath = CGMutablePath()
    let leftX = cx - brimHalfW
    let rightX = cx + brimHalfW

    brimPath.move(to: CGPoint(x: leftX, y: brimY))
    brimPath.addCurve(
        to: CGPoint(x: rightX, y: brimY),
        control1: CGPoint(x: cx - brimHalfW * 0.3, y: brimY - brimH * 0.35),
        control2: CGPoint(x: cx + brimHalfW * 0.3, y: brimY - brimH * 0.35)
    )
    brimPath.addCurve(
        to: CGPoint(x: rightX - w * 0.04, y: brimY + brimH * 0.85),
        control1: CGPoint(x: rightX + w * 0.015, y: brimY + brimH * 0.3),
        control2: CGPoint(x: rightX + w * 0.005, y: brimY + brimH * 0.65)
    )
    brimPath.addCurve(
        to: CGPoint(x: leftX + w * 0.04, y: brimY + brimH * 0.85),
        control1: CGPoint(x: cx + brimHalfW * 0.25, y: brimY + brimH * 1.1),
        control2: CGPoint(x: cx - brimHalfW * 0.25, y: brimY + brimH * 1.1)
    )
    brimPath.addCurve(
        to: CGPoint(x: leftX, y: brimY),
        control1: CGPoint(x: leftX - w * 0.005, y: brimY + brimH * 0.65),
        control2: CGPoint(x: leftX - w * 0.015, y: brimY + brimH * 0.3)
    )
    brimPath.closeSubpath()
    ctx.addPath(brimPath)
    ctx.strokePath()

    // --- Crown ---
    let crownBaseY = brimY + brimH * 0.88
    let crownBaseHalfW = w * 0.265
    let crownTopY = h * 0.76
    let crownTopHalfW = w * 0.175
    let crownTopDip = h * 0.055

    let crownPath = CGMutablePath()
    crownPath.move(to: CGPoint(x: cx - crownBaseHalfW, y: crownBaseY))
    crownPath.addCurve(
        to: CGPoint(x: cx - crownTopHalfW, y: crownTopY),
        control1: CGPoint(x: cx - crownBaseHalfW - w * 0.015, y: crownBaseY + (crownTopY - crownBaseY) * 0.4),
        control2: CGPoint(x: cx - crownTopHalfW - w * 0.01, y: crownTopY - (crownTopY - crownBaseY) * 0.3)
    )
    crownPath.addCurve(
        to: CGPoint(x: cx, y: crownTopY - crownTopDip),
        control1: CGPoint(x: cx - crownTopHalfW * 0.6, y: crownTopY + h * 0.01),
        control2: CGPoint(x: cx - crownTopHalfW * 0.2, y: crownTopY - crownTopDip - h * 0.005)
    )
    crownPath.addCurve(
        to: CGPoint(x: cx + crownTopHalfW, y: crownTopY),
        control1: CGPoint(x: cx + crownTopHalfW * 0.2, y: crownTopY - crownTopDip - h * 0.005),
        control2: CGPoint(x: cx + crownTopHalfW * 0.6, y: crownTopY + h * 0.01)
    )
    crownPath.addCurve(
        to: CGPoint(x: cx + crownBaseHalfW, y: crownBaseY),
        control1: CGPoint(x: cx + crownTopHalfW + w * 0.01, y: crownTopY - (crownTopY - crownBaseY) * 0.3),
        control2: CGPoint(x: cx + crownBaseHalfW + w * 0.015, y: crownBaseY + (crownTopY - crownBaseY) * 0.4)
    )
    crownPath.addCurve(
        to: CGPoint(x: cx - crownBaseHalfW, y: crownBaseY),
        control1: CGPoint(x: cx + crownBaseHalfW * 0.3, y: crownBaseY - h * 0.005),
        control2: CGPoint(x: cx - crownBaseHalfW * 0.3, y: crownBaseY - h * 0.005)
    )
    crownPath.closeSubpath()
    ctx.addPath(crownPath)
    ctx.strokePath()

    // --- Hat band ---
    let bandY = crownBaseY + h * 0.038
    let bandPath = CGMutablePath()
    bandPath.move(to: CGPoint(x: cx - crownBaseHalfW + w * 0.01, y: bandY))
    bandPath.addCurve(
        to: CGPoint(x: cx + crownBaseHalfW - w * 0.01, y: bandY),
        control1: CGPoint(x: cx - crownBaseHalfW * 0.3, y: bandY - h * 0.003),
        control2: CGPoint(x: cx + crownBaseHalfW * 0.3, y: bandY - h * 0.003)
    )
    ctx.setLineWidth(strokeWidth * 0.75)
    ctx.addPath(bandPath)
    ctx.strokePath()

    guard let cgImage = ctx.makeImage() else { return nil }
    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: pixelSize, height: pixelSize))
    guard let tiff = nsImage.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return nil }
    return png
}

// Exact pixel sizes needed for each slot
let sizes: [(points: Int, scale: Int, pixels: Int)] = [
    (16,  1, 16),
    (16,  2, 32),
    (32,  1, 32),
    (32,  2, 64),
    (128, 1, 128),
    (128, 2, 256),
    (256, 1, 256),
    (256, 2, 512),
    (512, 1, 512),
    (512, 2, 1024)
]

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

for entry in sizes {
    guard let png = drawIcon(pixelSize: entry.pixels) else {
        print("Failed \(entry.pixels)x\(entry.pixels)")
        continue
    }

    let suffix = entry.scale == 2 ? "@2x" : ""
    let filename = "icon_\(entry.points)x\(entry.points)\(suffix).png"
    let url = URL(fileURLWithPath: "\(outputDir)/\(filename)")

    do {
        try png.write(to: url)
        print("Generated \(filename) (\(entry.pixels)×\(entry.pixels)px)")
    } catch {
        print("Error \(filename): \(error.localizedDescription)")
    }
}
