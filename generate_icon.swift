import AppKit
import CoreGraphics

// Draw cowboy hat icon at a given size and return NSImage
func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let w = size
    let h = size
    let cx = w / 2

    // Background: warm dark tone
    let bg = CGColor(red: 0.13, green: 0.11, blue: 0.09, alpha: 1)
    ctx.setFillColor(bg)
    let bgRect = CGRect(x: 0, y: 0, width: w, height: h)
    // Rounded rect background
    let radius = w * 0.22
    let bgPath = CGMutablePath()
    bgPath.addRoundedRect(in: bgRect, cornerWidth: radius, cornerHeight: radius)
    ctx.addPath(bgPath)
    ctx.fillPath()

    // Hat colours - amber / tan outline
    let hatColor = CGColor(red: 0.95, green: 0.80, blue: 0.45, alpha: 1.0)
    let strokeWidth = max(1.5, size * 0.028)

    ctx.setStrokeColor(hatColor)
    ctx.setFillColor(CGColor.clear)
    ctx.setLineWidth(strokeWidth)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // --- Brim ---
    // A wide ellipse with slightly upturned sides
    let brimY = h * 0.30
    let brimHalfW = w * 0.44
    let brimH = h * 0.10

    // Brim as a flat ellipse arc — bottom edge straight, top curves up
    let brimPath = CGMutablePath()
    // Draw brim as a closed shape: left end, bottom arc, right end, top arc
    let leftX = cx - brimHalfW
    let rightX = cx + brimHalfW

    // Bottom brim edge — gentle downward curve
    brimPath.move(to: CGPoint(x: leftX, y: brimY))
    brimPath.addCurve(
        to: CGPoint(x: rightX, y: brimY),
        control1: CGPoint(x: cx - brimHalfW * 0.3, y: brimY - brimH * 0.35),
        control2: CGPoint(x: cx + brimHalfW * 0.3, y: brimY - brimH * 0.35)
    )

    // Right brim tip curls upward
    brimPath.addCurve(
        to: CGPoint(x: rightX - w * 0.04, y: brimY + brimH * 0.85),
        control1: CGPoint(x: rightX + w * 0.015, y: brimY + brimH * 0.3),
        control2: CGPoint(x: rightX + w * 0.005, y: brimY + brimH * 0.65)
    )

    // Top brim edge — curves back across
    brimPath.addCurve(
        to: CGPoint(x: leftX + w * 0.04, y: brimY + brimH * 0.85),
        control1: CGPoint(x: cx + brimHalfW * 0.25, y: brimY + brimH * 1.1),
        control2: CGPoint(x: cx - brimHalfW * 0.25, y: brimY + brimH * 1.1)
    )

    // Left brim tip curls upward
    brimPath.addCurve(
        to: CGPoint(x: leftX, y: brimY),
        control1: CGPoint(x: leftX - w * 0.005, y: brimY + brimH * 0.65),
        control2: CGPoint(x: leftX - w * 0.015, y: brimY + brimH * 0.3)
    )
    brimPath.closeSubpath()

    ctx.addPath(brimPath)
    ctx.strokePath()

    // --- Crown ---
    // The main body of the hat sitting above the brim
    let crownBaseY = brimY + brimH * 0.88
    let crownBaseHalfW = w * 0.265
    let crownTopY = h * 0.76
    let crownTopHalfW = w * 0.175
    let crownTopDip = h * 0.055  // centre dip (cattleman crease)

    let crownPath = CGMutablePath()

    // Bottom-left of crown
    crownPath.move(to: CGPoint(x: cx - crownBaseHalfW, y: crownBaseY))

    // Left side curves up to top-left
    crownPath.addCurve(
        to: CGPoint(x: cx - crownTopHalfW, y: crownTopY),
        control1: CGPoint(x: cx - crownBaseHalfW - w * 0.015, y: crownBaseY + (crownTopY - crownBaseY) * 0.4),
        control2: CGPoint(x: cx - crownTopHalfW - w * 0.01, y: crownTopY - (crownTopY - crownBaseY) * 0.3)
    )

    // Top edge: left peak → centre dip → right peak (cattleman crease)
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

    // Right side curves down to bottom-right
    crownPath.addCurve(
        to: CGPoint(x: cx + crownBaseHalfW, y: crownBaseY),
        control1: CGPoint(x: cx + crownTopHalfW + w * 0.01, y: crownTopY - (crownTopY - crownBaseY) * 0.3),
        control2: CGPoint(x: cx + crownBaseHalfW + w * 0.015, y: crownBaseY + (crownTopY - crownBaseY) * 0.4)
    )

    // Bottom of crown — slight curve matching top of brim
    crownPath.addCurve(
        to: CGPoint(x: cx - crownBaseHalfW, y: crownBaseY),
        control1: CGPoint(x: cx + crownBaseHalfW * 0.3, y: crownBaseY - h * 0.005),
        control2: CGPoint(x: cx - crownBaseHalfW * 0.3, y: crownBaseY - h * 0.005)
    )

    crownPath.closeSubpath()

    ctx.addPath(crownPath)
    ctx.strokePath()

    // --- Hat band: a thin line just above the brim ---
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

    image.unlockFocus()
    return image
}

// Required icon sizes for macOS
let sizes: [(Int, Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2)
]

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

for (points, scale) in sizes {
    let pixels = points * scale
    let image = drawIcon(size: CGFloat(pixels))

    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to generate \(pixels)x\(pixels)")
        continue
    }

    let scaleSuffix = scale == 2 ? "@2x" : ""
    let filename = "icon_\(points)x\(points)\(scaleSuffix).png"
    let path = "\(outputDir)/\(filename)"

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Generated \(filename) (\(pixels)x\(pixels)px)")
    } catch {
        print("Error writing \(filename): \(error)")
    }
}
