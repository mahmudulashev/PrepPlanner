import SwiftUI

/// Near-black surface with soft blurred light in the given colors. Used behind the planner
/// header and every screen's banner.
struct HeroGlow: View {
    var colors: [Color] = [Theme.accent, Color(hex: "#7B61D9")]

    var body: some View {
        GeometryReader { g in
            ZStack {
                Theme.hero
                ForEach(Array(colors.enumerated()), id: \.offset) { i, color in
                    Ellipse()
                        .fill(color)
                        .frame(width: g.size.width * 0.42, height: g.size.height * 0.9)
                        .offset(x: g.size.width * (0.08 + 0.2 * CGFloat(i)), y: -g.size.height * (0.25 - 0.18 * CGFloat(i)))
                        .opacity(0.55 - 0.1 * Double(i))
                        .blur(radius: 70)
                }
                // Fades the light out towards the bottom so text stays readable.
                LinearGradient(colors: [.clear, Theme.hero.opacity(0.85)], startPoint: .top, endPoint: .bottom)
            }
            // One flattened layer: the blur is drawn once instead of on every redraw above it.
            .drawingGroup()
            .animation(.easeInOut(duration: 0.6), value: colors)
        }
        .clipped()
    }
}

/// Rounded dark banner at the top of a screen: a two-tone heading on the left and the
/// screen's main actions or numbers on the right.
struct HeroBanner<Trailing: View>: View {
    let title: Text
    let subtitle: Text
    var colors: [Color] = [Theme.accent, Color(hex: "#7B61D9")]
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 20) {
                heading
                Spacer(minLength: 0)
                trailing
            }
            VStack(alignment: .leading, spacing: 16) {
                heading
                trailing
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HeroGlow(colors: colors))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.07), lineWidth: 1)
        )
        .environment(\.colorScheme, .dark)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: -3) {
            title.foregroundStyle(.white)
            subtitle.foregroundStyle(.white.opacity(0.38))
        }
        .font(.system(size: 32, weight: .bold))
        .tracking(-0.6)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

/// Neon pill for a screen's main action.
struct PillButton: View {
    let title: LocalizedStringKey
    var symbol = "plus"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.onHighlight)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(Capsule().fill(Theme.highlight))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}

/// Segmented control as a pill: a light thumb sliding on a dark track inside banners, or
/// a white thumb on a grey track on light cards.
struct PillToggle<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, String)]
    var onDark = true

    @Namespace private var thumb

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { value, label in
                Button {
                    withAnimation(.spring(duration: 0.3)) { selection = value }
                } label: {
                    Text(verbatim: label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(textColor(selected: selection == value))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background {
                            if selection == value {
                                Capsule()
                                    .fill(onDark ? Color.white : Theme.card)
                                    .shadow(color: .black.opacity(onDark ? 0 : 0.08), radius: 3, y: 1)
                                    .matchedGeometryEffect(id: "thumb", in: thumb)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(onDark ? Color.white.opacity(0.1) : Theme.cardMuted))
        .fixedSize()
    }

    private func textColor(selected: Bool) -> Color {
        if onDark { return selected ? Theme.onHighlight : .white.opacity(0.65) }
        return selected ? .primary : .secondary
    }
}

/// The app's one stat card: a two-tone caption, then an icon chip and a dot-matrix number
/// on the bottom row, and an optional footer such as a progress bar. Every screen's
/// headline numbers use it so they line up and read the same.
struct MetricCard<Footer: View>: View {
    let title: Text
    let subtitle: Text
    var subtitleTint: Color?
    let value: String
    let symbol: String
    let color: Color
    var footer: Footer

    init(title: Text, subtitle: Text, subtitleTint: Color? = nil, value: String, symbol: String, color: Color,
         @ViewBuilder footer: () -> Footer) {
        self.title = title
        self.subtitle = subtitle
        self.subtitleTint = subtitleTint
        self.value = value
        self.symbol = symbol
        self.color = color
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                title.foregroundStyle(.primary)
                subtitle.foregroundStyle(subtitleTint ?? .secondary)
            }
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            HStack(alignment: .bottom) {
                IconChip(symbol: symbol, color: color, size: 34)
                Spacer(minLength: 8)
                DotNumber(value: value, dot: 3.4)
                    .foregroundStyle(.primary)
            }
            .frame(height: 36, alignment: .bottom)

            footer
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.card)
                .shadow(color: .black.opacity(0.07), radius: 14, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.hairline.opacity(0.7), lineWidth: 1)
        )
    }
}

extension MetricCard where Footer == EmptyView {
    init(title: Text, subtitle: Text, subtitleTint: Color? = nil, value: String, symbol: String, color: Color) {
        self.init(title: title, subtitle: subtitle, subtitleTint: subtitleTint, value: value, symbol: symbol,
                  color: color) { EmptyView() }
    }
}

/// Button styles for sheet footers and other text buttons: the main action is a neon pill,
/// anything else a grey one. Disabled buttons fade.
struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive }
    var kind: Kind = .secondary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: kind == .primary ? .bold : .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(Capsule().fill(background))
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: Theme.onHighlight
        case .secondary: .primary
        case .destructive: Theme.danger
        }
    }

    private var background: Color {
        switch kind {
        case .primary: Theme.highlight
        case .secondary: Theme.cardMuted
        case .destructive: Theme.danger.opacity(0.12)
        }
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var pillPrimary: PillButtonStyle { PillButtonStyle(kind: .primary) }
    static var pill: PillButtonStyle { PillButtonStyle(kind: .secondary) }
}
