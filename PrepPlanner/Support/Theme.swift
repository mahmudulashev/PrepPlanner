import SwiftUI
import AppKit

enum Theme {
    static let accent = Color(hex: "#F4852B")
    static let accentSoft = Color(light: "#FDE6D2", dark: "#4A3020")
    static let background = Color(light: "#F6F2EC", dark: "#1A1816")
    static let card = Color(light: "#FFFFFF", dark: "#252220")
    static let cardMuted = Color(light: "#F1EBE3", dark: "#312D29")
    /// Dark "pill" surface (like the reference's Link Account button); inverts in dark mode.
    static let ink = Color(light: "#221D1A", dark: "#EDE6DE")
    static let onInk = Color(light: "#FFFFFF", dark: "#1A1816")
    static let gridLine = Color(light: "#ECE5DC", dark: "#34302C")
    static let success = Color(hex: "#5BAA6E")
    static let danger = Color(hex: "#E5584F")

    static let cornerRadius: CGFloat = 18
}

struct CardModifier: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(Theme.card)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

// MARK: - Hex colors

extension NSColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        if s.count == 6 {
            self.init(
                srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        } else {
            self.init(srgbRed: 0.56, green: 0.56, blue: 0.58, alpha: 1)
        }
    }

    var hexString: String {
        guard let c = usingColorSpace(.sRGB) else { return "#8E8E93" }
        return String(
            format: "#%02X%02X%02X",
            Int((c.redComponent * 255).rounded()),
            Int((c.greenComponent * 255).rounded()),
            Int((c.blueComponent * 255).rounded())
        )
    }
}

extension Color {
    init(hex: String) {
        self.init(nsColor: NSColor(hex: hex))
    }

    /// A color that switches between light and dark appearance.
    init(light: String, dark: String) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(hex: dark)
                : NSColor(hex: light)
        })
    }

    var hexString: String { NSColor(self).hexString }
}
