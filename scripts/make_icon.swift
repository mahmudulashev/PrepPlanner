import AppKit
import CoreGraphics
import Foundation

// Draws the PrepPlanner app icon: a near-black squircle with soft colored light, and the
// planner's week bar chart with today's bar lit in neon above a row of LED dots.

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

/// Soft round light: a radial gradient from `hex` at `alpha` to transparent.
func glow(_ ctx: CGContext, at center: CGPoint, radius: CGFloat, hex: String, alpha: CGFloat) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                       colors: [color(hex, alpha), color(hex, alpha * 0.45), color(hex, 0)] as CFArray,
                       locations: [0, 0.45, 1])!
    ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
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

    // Shadow under the plate.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: color("#000000", 0.45))
    ctx.addPath(platePath)
    ctx.setFillColor(color("#121214"))
    ctx.fillPath()
    ctx.restoreGState()

    // Dark plate with the same glow as the app's header.
    ctx.saveGState()
    ctx.addPath(platePath)
    ctx.clip()
    let base = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                          colors: [color("#24232B"), color("#121214"), color("#0B0B0D")] as CFArray,
                          locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(base, start: CGPoint(x: plate.minX, y: plate.maxY),
                           end: CGPoint(x: plate.maxX, y: plate.minY), options: [])
    glow(ctx, at: CGPoint(x: plate.minX + 150, y: plate.maxY - 120), radius: 520, hex: "#F0873F", alpha: 0.55)
    glow(ctx, at: CGPoint(x: plate.maxX - 110, y: plate.maxY - 220), radius: 480, hex: "#7B61D9", alpha: 0.55)
    glow(ctx, at: CGPoint(x: plate.midX + 40, y: plate.minY + 60), radius: 420, hex: "#E0679A", alpha: 0.22)

    // Fine inner rim so the plate reads on dark backgrounds too.
    ctx.addPath(squircle(in: plate.insetBy(dx: 3, dy: 3)))
    ctx.setStrokeColor(color("#FFFFFF", 0.10))
    ctx.setLineWidth(6)
    ctx.strokePath()
    ctx.restoreGState()

    // The week: five bars on a baseline; their pale tops are the plan, the bright part what got done.
    let barWidth: CGFloat = 92
    let gap: CGFloat = 40
    let baseline: CGFloat = 340
    let bars: [(plan: CGFloat, done: CGFloat)] = [(250, 190), (330, 300), (430, 430), (290, 120), (200, 0)]
    let lit = 2
    let totalWidth = CGFloat(bars.count) * barWidth + CGFloat(bars.count - 1) * gap
    var x = plate.midX - totalWidth / 2

    for (i, bar) in bars.enumerated() {
        let track = CGRect(x: x, y: baseline, width: barWidth, height: bar.plan)
        if i == lit {
            // Today's bar: neon with a halo, like the selected day in the planner header.
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 70, color: color("#E6F53B", 0.75))
            ctx.addPath(roundedRect(track, barWidth / 2))
            ctx.setFillColor(color("#E6F53B"))
            ctx.fillPath()
            ctx.restoreGState()
        } else {
            ctx.addPath(roundedRect(track, barWidth / 2))
            ctx.setFillColor(color("#FFFFFF", 0.13))
            ctx.fillPath()
            if bar.done > 0 {
                ctx.addPath(roundedRect(CGRect(x: x, y: baseline, width: barWidth, height: max(bar.done, barWidth)), barWidth / 2))
                ctx.setFillColor(color("#FFFFFF", 0.62))
                ctx.fillPath()
            }
        }
        x += barWidth + gap
    }

    // A row of LED dots under the bars, the dot-matrix digits' signature.
    let dot: CGFloat = 22
    let dotGap: CGFloat = 16
    let dots = 15
    let dotsWidth = CGFloat(dots) * dot + CGFloat(dots - 1) * dotGap
    var dx = plate.midX - dotsWidth / 2
    for i in 0..<dots {
        let on = i < 10
        ctx.setFillColor(on ? color("#E6F53B", i == 9 ? 1 : 0.85) : color("#FFFFFF", 0.16))
        ctx.fillEllipse(in: CGRect(x: dx, y: 238, width: dot, height: dot))
        dx += dot + dotGap
    }

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
