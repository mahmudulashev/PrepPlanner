import AppKit
import CoreGraphics
import Foundation

// Draws the background shown inside the PrepPlanner disk image window.
// Usage: swiftc -O -o /tmp/dmgbg scripts/make_dmg_background.swift && /tmp/dmgbg out.png

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg-background.png"
let width: CGFloat = 640
let height: CGFloat = 400

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

let ctx = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// Warm background with a soft orange glow behind the app icon.
ctx.setFillColor(color("#F6F2EC"))
ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                      colors: [color("#F4852B", 0.20), color("#F4852B", 0)] as CFArray,
                      locations: [0, 1])!
ctx.drawRadialGradient(glow,
                       startCenter: CGPoint(x: 168, y: 214), startRadius: 0,
                       endCenter: CGPoint(x: 168, y: 214), endRadius: 200,
                       options: [])

// Arrow from the app to the Applications folder.
ctx.setStrokeColor(color("#C9BCAC"))
ctx.setLineWidth(3)
ctx.setLineCap(.round)
ctx.setLineDash(phase: 0, lengths: [1, 11])
ctx.beginPath()
ctx.move(to: CGPoint(x: 268, y: 214))
ctx.addLine(to: CGPoint(x: 372, y: 214))
ctx.strokePath()
ctx.setLineDash(phase: 0, lengths: [])
ctx.setFillColor(color("#C9BCAC"))
ctx.beginPath()
ctx.move(to: CGPoint(x: 396, y: 214))
ctx.addLine(to: CGPoint(x: 374, y: 226))
ctx.addLine(to: CGPoint(x: 374, y: 202))
ctx.closePath()
ctx.fillPath()

// Text, drawn with AppKit into the same context.
let graphics = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics

func draw(_ text: String, _ font: NSFont, _ hex: String, centerX: CGFloat, y: CGFloat) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(cgColor: color(hex))!,
    ]
    let string = NSAttributedString(string: text, attributes: attributes)
    let size = string.size()
    string.draw(at: NSPoint(x: centerX - size.width / 2, y: y))
}

draw("PrepPlanner", NSFont.systemFont(ofSize: 26, weight: .bold), "#221D1A", centerX: width / 2, y: 330)
draw("Drag the app onto the Applications folder to install",
     NSFont.systemFont(ofSize: 13, weight: .regular), "#8A7E70", centerX: width / 2, y: 300)
draw("IELTS and SAT study planner for macOS",
     NSFont.systemFont(ofSize: 12, weight: .regular), "#A99C8C", centerX: width / 2, y: 52)

NSGraphicsContext.restoreGraphicsState()

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
rep.size = NSSize(width: width, height: height)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
