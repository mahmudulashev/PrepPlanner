import SwiftUI

/// One block on the day timeline.
///
/// Study blocks are pastel cards in their category color: title on top in a deep shade of
/// that color, time at the bottom right under a dashed rule. Rest blocks are a quiet hatched
/// strip with the label in the middle. The layout steps down as the block gets shorter.
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
    private var dark: Bool { scheme == .dark }
    private var isRest: Bool { !block.isStudy }

    private enum Density { case tiny, compact, regular, tall }

    private var density: Density {
        if height < 30 { return .tiny }
        if height < 52 { return .compact }
        if height < 92 { return .regular }
        return .tall
    }

    private static let radius: CGFloat = 12

    var body: some View {
        Group {
            if isRest { restBody } else { studyBody }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
                .strokeBorder(isSelected ? deep : .clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(isDragging ? 0.2 : (isSelected ? 0.08 : 0)), radius: isDragging ? 14 : 8, y: isDragging ? 6 : 2)
        .scaleEffect(isDragging ? 1.01 : 1)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .animation(.spring(duration: 0.25), value: isDragging)
        .help(helpText)
    }

    // MARK: Study blocks

    @ViewBuilder
    private var studyBody: some View {
        switch density {
        case .tiny, .compact:
            HStack(spacing: 8) {
                // Drop the badge, then the time, before the title has to truncate.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        title(size: density == .tiny ? 11 : 12.5)
                        timeText(size: density == .tiny ? 10 : 11)
                        if needsReview { reviewBadge }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        title(size: density == .tiny ? 11 : 12.5)
                        timeText(size: density == .tiny ? 10 : 11)
                    }
                    title(size: density == .tiny ? 11 : 12.5).lineLimit(1)
                }
                Spacer(minLength: 0)
                statusToggle(size: density == .tiny ? 13 : 16)
            }
            .padding(.horizontal, 12)

        case .regular, .tall:
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        title(size: 14)
                            .lineLimit(density == .tall ? 2 : 1)
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(deep.opacity(0.65))
                                .lineLimit(density == .tall ? 2 : 1)
                        }
                    }
                    Spacer(minLength: 0)
                    statusToggle(size: 18)
                }
                Spacer(minLength: 4)
                if density == .tall {
                    DashedRule()
                        .stroke(deep.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .frame(height: 1)
                        .padding(.bottom, 7)
                }
                HStack(spacing: 6) {
                    if needsReview { reviewBadge }
                    if let actual = actualLabel {
                        Text(actual)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(deep.opacity(0.6))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    timeText(size: 12)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
    }

    private func title(size: CGFloat) -> some View {
        Text(block.title.isEmpty ? String(localized: "Untitled") : block.title)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(status == .planned || status == .partial ? deep : deep.opacity(0.5))
            .strikethrough(status == .done || status == .skipped, color: deep.opacity(0.5))
    }

    private func timeText(size: CGFloat) -> some View {
        Text(TimeFmt.range(start, end))
            .font(.system(size: size, weight: .medium).monospacedDigit())
            .foregroundStyle(deep.opacity(0.55))
            .lineLimit(1)
            .fixedSize()
    }

    /// The category, or the note when the title already names the category.
    private var subtitle: String? {
        if let name = block.category?.name, name != block.title { return name }
        return block.note.isEmpty ? nil : block.note
    }

    private var actualLabel: String? {
        guard status == .done || status == .partial,
              let a = block.actualMinutes, a != block.plannedMinutes else { return nil }
        return String(localized: "\(TimeFmt.duration(a)) actual")
    }

    private var reviewBadge: some View {
        Text("Review")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Theme.accent))
            .fixedSize()
    }

    private func statusToggle(size: CGFloat) -> some View {
        StatusToggle(status: status, color: deep, needsReview: needsReview, size: size, action: onToggleDone)
    }

    // MARK: Rest blocks

    private var restBody: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 10))
            Text(block.title.isEmpty ? String(localized: "Untitled") : block.title)
                .font(.system(size: 11.5, weight: .semibold))
                .lineLimit(1)
            Text(TimeFmt.range(start, end))
                .font(.system(size: 11).monospacedDigit())
                .opacity(0.7)
                .fixedSize()
            Spacer(minLength: 0)
        }
        .foregroundStyle(.secondary)
        .overlay(alignment: .trailing) {
            statusToggle(size: height < 30 ? 13 : 15).padding(.trailing, 12)
        }
        .padding(.horizontal, 12)
    }

    // MARK: Colors

    /// Category color mixed into the surface: a pastel while planned, paler once finished.
    private var background: some View {
        let base = NSColor(hex: dark ? "#1B1B1D" : "#FFFFFF")
        var strength: Double
        switch (isRest, status) {
        case (true, _): strength = dark ? 0.10 : 0.07
        case (_, .planned), (_, .partial): strength = dark ? 0.34 : 0.22
        case (_, .done): strength = dark ? 0.18 : 0.11
        case (_, .skipped): strength = dark ? 0.10 : 0.06
        }
        if hovering || isSelected { strength += dark ? 0.06 : 0.05 }
        let fill = Color(nsColor: base.mixed(with: NSColor(hex: isRest ? "#8E8E93" : hex), fraction: strength))
        return ZStack {
            fill
            if isRest || status == .skipped {
                Stripes().foregroundStyle(Color.primary.opacity(dark ? 0.07 : 0.06))
            }
        }
    }

    /// The category color pushed towards black (or white in dark mode) for text on the pastel.
    private var deep: Color {
        if isRest { return .secondary }
        let source = NSColor(hex: hex)
        return Color(nsColor: dark ? source.mixed(with: .white, fraction: 0.35) : source.mixed(with: .black, fraction: 0.42))
    }

    private var helpText: String {
        var s = "\(block.title) · \(TimeFmt.range(start, end))"
        if !block.note.isEmpty { s += "\n\(block.note)" }
        return s
    }
}

/// Round status control. Click toggles done; the context menu has the rest.
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
                        .strokeBorder(needsReview ? Theme.accent : color.opacity(0.45), lineWidth: 1.6)
                    if hovering {
                        Image(systemName: "checkmark")
                            .font(.system(size: size * 0.48, weight: .bold))
                            .foregroundStyle(color.opacity(0.7))
                    }
                case .done:
                    Circle().fill(color)
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.5, weight: .heavy))
                        .foregroundStyle(.white)
                case .partial:
                    Circle().strokeBorder(color, lineWidth: 1.6)
                    HalfDisc().fill(color).padding(size * 0.2)
                case .skipped:
                    Circle().strokeBorder(color.opacity(0.4), lineWidth: 1.6)
                    Image(systemName: "minus")
                        .font(.system(size: size * 0.48, weight: .bold))
                        .foregroundStyle(color.opacity(0.6))
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle().inset(by: -5))
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

/// Horizontal line, for dashing.
private struct DashedRule: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

/// Diagonal hatching for breaks and skipped blocks.
struct Stripes: Shape {
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
