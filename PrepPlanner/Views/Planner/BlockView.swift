import SwiftUI

/// One block on the day timeline.
///
/// The fill is opaque (the category color mixed into the surface), so grid lines never show
/// through, and the layout steps down through three densities as the block gets shorter.
struct BlockView: View {
    let block: TimeBlock
    let start: Int
    let end: Int
    let isSelected: Bool
    var needsReview = false
    var isDragging = false
    var onToggleDone: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var hovering = false

    private var hex: String { block.category?.colorHex ?? "#8E8E93" }
    private var color: Color { Color(hex: hex) }
    private var height: CGFloat { CGFloat(end - start) * DayTimeline.pointsPerMinute }
    private var status: BlockStatus { block.status }

    private enum Density { case tiny, compact, regular }

    private var density: Density {
        if height < 30 { return .tiny }
        if height < 50 { return .compact }
        return .regular
    }

    var body: some View {
        HStack(alignment: density == .regular ? .top : .center, spacing: 8) {
            StatusToggle(status: status, color: color, needsReview: needsReview,
                         size: density == .tiny ? 13 : 15, action: onToggleDone)
                .padding(.top, density == .regular ? 1 : 0)
            content
            Spacer(minLength: 0)
        }
        .padding(.leading, 11)
        .padding(.trailing, 8)
        .padding(.vertical, density == .regular ? 7 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: density == .regular ? .topLeading : .leading)
        .background(background)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(color.opacity(status == .skipped ? 0.45 : 1))
                .frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(selectionRing)
        .shadow(color: .black.opacity(isDragging ? 0.18 : 0), radius: isDragging ? 10 : 0, y: isDragging ? 4 : 0)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .help(helpText)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch density {
        case .tiny, .compact:
            // Drop the badge, then the time, before the title has to truncate.
            let size: CGFloat = density == .tiny ? 11 : 12
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    title.font(.system(size: size, weight: .semibold))
                    compactTime
                    if needsReview { reviewBadge }
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    title.font(.system(size: size, weight: .semibold))
                    compactTime
                }
                title
                    .font(.system(size: size, weight: .semibold))
                    .lineLimit(1)
            }
        case .regular:
            VStack(alignment: .leading, spacing: 2) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        title
                            .font(.system(size: 13, weight: .semibold))
                            .fixedSize()
                        Spacer(minLength: 0)
                        if needsReview { reviewBadge }
                    }
                    title
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(height > 90 ? 2 : 1)
                }
                Text(timeLine)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if height > 74, let category = categoryLabel {
                    Text(category)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(textTint)
                        .lineLimit(1)
                        .padding(.top, 1)
                }
                if height > 104, !block.note.isEmpty {
                    Text(block.note)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(max(1, Int((height - 92) / 14)))
                        .padding(.top, 3)
                }
            }
        }
    }

    private var compactTime: some View {
        Text(TimeFmt.range(start, end))
            .font(.system(size: density == .tiny ? 10 : 11).monospacedDigit())
            .foregroundStyle(.secondary)
            .fixedSize()
    }

    private var title: some View {
        Text(block.title.isEmpty ? String(localized: "Untitled") : block.title)
            .strikethrough(status == .done || status == .skipped, color: .secondary)
            .foregroundStyle(status == .planned || status == .partial ? Color.primary : Color.secondary)
    }

    private var timeLine: String {
        var s = "\(TimeFmt.range(start, end)) · \(TimeFmt.duration(end - start))"
        if (status == .done || status == .partial), let a = block.actualMinutes, a != block.plannedMinutes {
            s += " · " + String(localized: "\(TimeFmt.duration(a)) actual")
        }
        return s
    }

    /// The category name, unless the title already says it.
    private var categoryLabel: String? {
        guard let name = block.category?.name, name != block.title else { return nil }
        return name
    }

    private var reviewBadge: some View {
        Text("Review")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(Theme.accent.opacity(0.14)))
            .fixedSize()
    }

    // MARK: Chrome

    /// Category color mixed into the surface: stronger while planned, faded once finished.
    private var background: some View {
        let dark = scheme == .dark
        var strength: Double
        switch status {
        case .planned, .partial: strength = dark ? 0.30 : 0.16
        case .done: strength = dark ? 0.18 : 0.09
        case .skipped: strength = dark ? 0.10 : 0.05
        }
        if hovering || isSelected { strength += dark ? 0.06 : 0.05 }
        let base = dark ? "#1F1F1F" : "#FFFFFF"
        return ZStack {
            Color(nsColor: NSColor(hex: base).mixed(with: NSColor(hex: hex), fraction: strength))
            if status == .skipped { Stripes().foregroundStyle(Color.primary.opacity(dark ? 0.06 : 0.045)) }
        }
    }

    private var textTint: Color {
        Color(nsColor: NSColor(hex: hex).mixed(with: scheme == .dark ? .white : .black, fraction: scheme == .dark ? 0.25 : 0.3))
    }

    private var selectionRing: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(isSelected ? color : Color.primary.opacity(scheme == .dark ? 0.06 : 0.05),
                          lineWidth: isSelected ? 2 : 1)
    }

    private var helpText: String {
        var s = "\(block.title) · \(TimeFmt.range(start, end))"
        if !block.note.isEmpty { s += "\n\(block.note)" }
        return s
    }
}

/// Round status control at the start of a block. Click toggles done; the context menu has the rest.
struct StatusToggle: View {
    let status: BlockStatus
    let color: Color
    var needsReview = false
    var size: CGFloat = 15
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                switch status {
                case .planned:
                    Circle()
                        .strokeBorder(needsReview ? Theme.accent : Color.secondary.opacity(0.7), lineWidth: 1.4)
                    if hovering {
                        Image(systemName: "checkmark")
                            .font(.system(size: size * 0.5, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                case .done:
                    Circle().fill(color)
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.52, weight: .bold))
                        .foregroundStyle(.white)
                case .partial:
                    Circle().strokeBorder(color, lineWidth: 1.4)
                    HalfDisc().fill(color).padding(3)
                case .skipped:
                    Circle().strokeBorder(Color.secondary.opacity(0.6), lineWidth: 1.4)
                    Image(systemName: "minus")
                        .font(.system(size: size * 0.5, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle().inset(by: -4))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(status == .done ? "Mark as planned" : "Mark done")
    }
}

/// Left half of a circle, for the Partial status.
private struct HalfDisc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2,
                 startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
        p.closeSubpath()
        return p
    }
}

/// Diagonal hatching for skipped blocks.
private struct Stripes: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let spacing: CGFloat = 7
        var x = -rect.height
        while x < rect.width {
            p.move(to: CGPoint(x: x, y: rect.maxY))
            p.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += spacing
        }
        return p.strokedPath(StrokeStyle(lineWidth: 1.5))
    }
}

extension NSColor {
    /// Linear sRGB mix: `fraction` 0 is `self`, 1 is `other`.
    func mixed(with other: NSColor, fraction: Double) -> NSColor {
        guard let a = usingColorSpace(.sRGB), let b = other.usingColorSpace(.sRGB) else { return self }
        let f = CGFloat(min(max(fraction, 0), 1))
        return NSColor(
            srgbRed: a.redComponent + (b.redComponent - a.redComponent) * f,
            green: a.greenComponent + (b.greenComponent - a.greenComponent) * f,
            blue: a.blueComponent + (b.blueComponent - a.blueComponent) * f,
            alpha: 1
        )
    }
}
