import SwiftUI
import AppKit

enum Theme {
    static let accent = Color(light: "#E2691C", dark: "#F0873F")
    static let accentSoft = Color(light: "#FCEBDD", dark: "#3D2A1D")
    /// Neon lemon used as a fill (always with dark text on it) for the one thing to look at.
    static let highlight = Color(hex: "#E6F53B")
    static let onHighlight = Color(hex: "#161616")
    static let background = Color(light: "#EEEEEB", dark: "#0E0E0F")
    static let card = Color(light: "#FFFFFF", dark: "#1B1B1D")
    static let cardMuted = Color(light: "#F2F2EF", dark: "#26262A")
    /// The dark band at the top of the planner, the same in both appearances.
    static let hero = Color(hex: "#121214")
    /// High-contrast surface for selected states; inverts in dark mode.
    static let ink = Color(light: "#18181B", dark: "#ECECEC")
    static let onInk = Color(light: "#FFFFFF", dark: "#161616")
    static let gridLine = Color(light: "#ECECE8", dark: "#2A2A2E")
    /// Hairline border around cards and panels.
    static let hairline = Color(light: "#E4E4E0", dark: "#2E2E32")
    static let success = Color(light: "#3E9A5A", dark: "#5BBE77")
    static let danger = Color(light: "#EF3B32", dark: "#FF5A50")

    static let cornerRadius: CGFloat = 18
}

struct CardModifier: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            // Tables run edge to edge, so their corners need clipping to the card.
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(Theme.card)
                    .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(Theme.hairline.opacity(0.6), lineWidth: 1)
            )
    }
}

/// Two-tone heading from the planner header: a strong first line and a faded second one.
struct TwoToneTitle: View {
    let primary: Text
    let secondary: Text
    var size: CGFloat = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            primary.foregroundStyle(.primary)
            secondary.foregroundStyle(.secondary)
        }
        .font(.system(size: size, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

/// Small rounded square holding an icon on a pastel version of `color`.
struct IconChip: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous).fill(color.opacity(0.16)))
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
