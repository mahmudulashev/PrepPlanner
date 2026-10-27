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

/// Segmented control drawn as a dark track with a light thumb.
struct PillToggle<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, String)]

    @Namespace private var thumb

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { value, label in
                Button {
                    withAnimation(.spring(duration: 0.3)) { selection = value }
                } label: {
                    Text(verbatim: label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selection == value ? Theme.onHighlight : .white.opacity(0.65))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background {
                            if selection == value {
                                Capsule().fill(.white).matchedGeometryEffect(id: "thumb", in: thumb)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(.white.opacity(0.1)))
        .fixedSize()
    }
}
