import AppKit
import CoreGraphics
import Foundation

// Draws the PrepPlanner app icon: a warm squircle with a day-plan card,
// three colored time blocks and a green "done" badge.

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func color(_ hex: String, _ alpha: CGFloat = 1) -> CGColor {
    var s = hex
    if s.hasPrefix("#") { s.removeFirst() }
    var v: UInt64 = 0
    Scanner(string: s).scanHexInt64(&v)
    return CGColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                   green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255,
                   alpha: alpha)
}

/// Apple-style squircle (superellipse) path.
func squircle(in rect: CGRect, exponent: CGFloat = 5.0) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    let cx = rect.midX, cy = rect.midY
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * (ct < 0 ? -1 : 1) * pow(abs(ct), 2 / exponent)
        let y = cy + b * (st < 0 ? -1 : 1) * pow(abs(st), 2 / exponent)
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func draw(size: CGFloat) -> CGImage {
    let s = size / 1024  // design is laid out on a 1024 grid
    let width = Int(size), height = Int(size)
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: s, y: s)
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    // macOS icons leave a margin around the artwork.
    let plate = CGRect(x: 100, y: 108, width: 824, height: 824)
    let platePath = squircle(in: plate)

    // Soft shadow under the plate.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 42, color: color("#7A3C10", 0.32))
    ctx.addPath(platePath)
    ctx.setFillColor(color("#F4852B"))
    ctx.fillPath()
    ctx.restoreGState()

    // Warm gradient background.
    ctx.saveGState()
    ctx.addPath(platePath)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: [color("#FFC062"), color("#F58A2E"), color("#E8622F")] as CFArray,
                              locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: plate.minX, y: plate.maxY),
                           end: CGPoint(x: plate.maxX, y: plate.minY),
                           options: [])
    // Gentle highlight in the top-left corner.
    let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                          colors: [color("#FFFFFF", 0.32), color("#FFFFFF", 0)] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(glow,
                           startCenter: CGPoint(x: plate.minX + 210, y: plate.maxY - 150), startRadius: 0,
                           endCenter: CGPoint(x: plate.minX + 210, y: plate.maxY - 150), endRadius: 560,
                           options: [])
    ctx.restoreGState()

    // The day-plan card.
    let card = CGRect(x: 208, y: 276, width: 608, height: 472)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: color("#6E3208", 0.28))
    ctx.addPath(roundedRect(card, 78))
    ctx.setFillColor(color("#FFFDF9"))
    ctx.fillPath()
    ctx.restoreGState()

    // Three time blocks, like blocks on the planner timeline.
    let bars: [(CGFloat, String)] = [(350, "#3F8FD2"), (446, "#4E9F6E"), (250, "#F28C38")]
    let barHeight: CGFloat = 78
    let gap: CGFloat = 44
    let totalHeight = CGFloat(bars.count) * barHeight + CGFloat(bars.count - 1) * gap
    var y = card.midY + totalHeight / 2 - barHeight
    let barX = card.minX + 74
    for (barWidth, hex) in bars {
        ctx.addPath(roundedRect(CGRect(x: barX, y: y, width: barWidth, height: barHeight), barHeight / 2))
        ctx.setFillColor(color(hex))
        ctx.fillPath()
        y -= barHeight + gap
    }

    // "Done" badge overlapping the card's bottom-right corner.
    let badgeCenter = CGPoint(x: card.maxX - 14, y: card.minY + 18)
    let badgeRadius: CGFloat = 124
    ctx.setFillColor(color("#FFFDF9"))
    ctx.fillEllipse(in: CGRect(x: badgeCenter.x - badgeRadius, y: badgeCenter.y - badgeRadius,
                               width: badgeRadius * 2, height: badgeRadius * 2))
    let inner = badgeRadius - 18
    ctx.setFillColor(color("#4E9F6E"))
    ctx.fillEllipse(in: CGRect(x: badgeCenter.x - inner, y: badgeCenter.y - inner,
                               width: inner * 2, height: inner * 2))
    ctx.setStrokeColor(color("#FFFFFF"))
    ctx.setLineWidth(30)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: badgeCenter.x - 48, y: badgeCenter.y + 4))
    ctx.addLine(to: CGPoint(x: badgeCenter.x - 14, y: badgeCenter.y - 32))
    ctx.addLine(to: CGPoint(x: badgeCenter.x + 52, y: badgeCenter.y + 42))
    ctx.strokePath()

    return ctx.makeImage()!
}

func write(_ image: CGImage, to path: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: image.width, height: image.height)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: URL(fileURLWithPath: path))
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    write(draw(size: CGFloat(size)), to: "\(outputDir)/icon_\(size).png")
}
print("wrote icons to \(outputDir)")
