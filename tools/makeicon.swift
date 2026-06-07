// Generates the ReconKit app icon at all required macOS sizes.
// Run: swift tools/makeicon.swift <output-appiconset-dir>
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func draw(size S: CGFloat) -> CGImage {
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a)
    }

    // Squircle background (slight margin like native macOS icons).
    let margin = S * 0.085
    let rect = CGRect(x: margin, y: margin, width: S - margin*2, height: S - margin*2)
    let radius = rect.width * 0.225
    let squircle = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()

    // Dark vertical gradient backdrop.
    let bg = CGGradient(colorsSpace: cs,
                        colors: [color(20, 26, 36), color(8, 11, 17), color(5, 7, 11)] as CFArray,
                        locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])

    // Soft blue glow, upper area.
    let glow = CGGradient(colorsSpace: cs,
                          colors: [color(0, 83, 253, 0.42), color(0, 83, 253, 0)] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: S*0.5, y: S*0.66), startRadius: 0,
                           endCenter: CGPoint(x: S*0.5, y: S*0.66), endRadius: S*0.55, options: [])

    let c = CGPoint(x: S*0.5, y: S*0.5)
    let blue = color(46, 107, 255)
    let blueBright = color(120, 165, 255)

    // Concentric radar rings.
    let rings: [(CGFloat, CGFloat)] = [(0.30, 0.95), (0.40, 0.55), (0.485, 0.32)]
    for (frac, alpha) in rings {
        ctx.setLineWidth(S * 0.018)
        ctx.setStrokeColor(blue.copy(alpha: alpha)!)
        ctx.addArc(center: c, radius: S*frac, startAngle: 0, endAngle: .pi*2, clockwise: false)
        ctx.strokePath()
    }

    // Bright radar sweep arc on the middle ring.
    ctx.setShadow(offset: .zero, blur: S*0.03, color: blueBright.copy(alpha: 0.8))
    ctx.setLineWidth(S * 0.026)
    ctx.setStrokeColor(blueBright)
    ctx.setLineCap(.round)
    ctx.addArc(center: c, radius: S*0.40, startAngle: -.pi*0.15, endAngle: .pi*0.42, clockwise: false)
    ctx.strokePath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    // Crosshair lines with a center gap.
    ctx.setLineWidth(S * 0.011)
    ctx.setStrokeColor(blue.copy(alpha: 0.40)!)
    let gap = S*0.075, reach = S*0.515
    for (dx, dy) in [(CGFloat(1), CGFloat(0)), (-1, 0), (0, 1), (0, -1)] {
        ctx.move(to: CGPoint(x: c.x + dx*gap, y: c.y + dy*gap))
        ctx.addLine(to: CGPoint(x: c.x + dx*reach, y: c.y + dy*reach))
    }
    ctx.strokePath()

    // Center dot with glow.
    ctx.setShadow(offset: .zero, blur: S*0.04, color: blueBright.copy(alpha: 0.9))
    ctx.setFillColor(blueBright)
    ctx.fillEllipse(in: CGRect(x: c.x - S*0.05, y: c.y - S*0.05, width: S*0.10, height: S*0.10))
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    // Gold accent blip on the outer ring (brand accent).
    let gold = color(255, 210, 54)
    let blip = CGPoint(x: c.x + S*0.40*cos(.pi*0.30), y: c.y + S*0.40*sin(.pi*0.30))
    ctx.setShadow(offset: .zero, blur: S*0.03, color: gold.copy(alpha: 0.9))
    ctx.setFillColor(gold)
    ctx.fillEllipse(in: CGRect(x: blip.x - S*0.028, y: blip.y - S*0.028, width: S*0.056, height: S*0.056))
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    ctx.restoreGState()

    // Subtle top edge highlight on the squircle.
    ctx.addPath(squircle)
    ctx.setLineWidth(S * 0.006)
    ctx.setStrokeColor(color(255, 255, 255, 0.10))
    ctx.strokePath()

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
let sizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]
for s in sizes {
    let img = draw(size: CGFloat(s))
    writePNG(img, to: outDir.appendingPathComponent("icon_\(s).png"))
    print("wrote icon_\(s).png")
}
