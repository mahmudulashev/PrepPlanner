import SwiftUI

struct BlockView: View {
    let block: TimeBlock
    let start: Int
    let end: Int
    let isSelected: Bool
    var onToggleDone: () -> Void

    @Environment(\.colorScheme) private var scheme

    private var color: Color { Color(hex: block.category?.colorHex ?? "#8E8E93") }
    private var height: CGFloat { CGFloat(end - start) * DayTimeline.pointsPerMinute }
    private var compact: Bool { height < 36 }

    var body: some View {
        HStack(alignment: compact ? .center : .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4)
                .padding(.vertical, 4)
                .padding(.leading, 4)
            content
                .padding(.horizontal, 8)
                .padding(.vertical, compact ? 0 : 6)
            Spacer(minLength: 0)
            statusButton
                .padding(.trailing, 6)
                .padding(.top, compact ? 0 : 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(scheme == .dark ? 0.28 : 0.17))
        )
        .overlay(border)
        .opacity(block.status == .skipped ? 0.55 : 1)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .help(helpText)
    }

    @ViewBuilder
    private var content: some View {
        if compact {
            HStack(spacing: 6) {
                titleText.font(.caption.weight(.semibold))
                Text(TimeFmt.range(start, end))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } else {
            VStack(alignment: .leading, spacing: 3) {
                titleText.font(.callout.weight(.semibold))
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text("\(TimeFmt.range(start, end)) · \(TimeFmt.duration(end - start))")
                        .monospacedDigit()
                    if let actual = actualLabel { Text("· \(actual)") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                if height > 62 {
                    HStack(spacing: 6) {
                        Text(block.category?.name ?? String(localized: "No category"))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(color.opacity(0.22)))
                        if block.needsReview {
                            Text("Needs review")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
                if height > 96, !block.note.isEmpty {
                    Text(block.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(max(1, Int((height - 80) / 15)))
                }
            }
        }
    }

    private var titleText: Text {
        Text(block.title.isEmpty ? String(localized: "Untitled") : block.title)
            .strikethrough(block.status == .done)
    }

    private var actualLabel: String? {
        guard block.status == .done || block.status == .partial,
              let a = block.actualMinutes, a != block.plannedMinutes else { return nil }
        return String(localized: "\(TimeFmt.duration(a)) actual")
    }

    private var statusButton: some View {
        Button(action: onToggleDone) {
            Image(systemName: block.status.symbol)
                .font(compact ? .callout : .title3)
                .foregroundStyle(statusColor)
        }
        .buttonStyle(.plain)
        .help(block.status == .done ? "Mark as planned" : "Mark done")
    }

    private var statusColor: Color {
        switch block.status {
        case .planned: .secondary
        case .done: Theme.success
        case .partial: Theme.accent
        case .skipped: .gray
        }
    }

    private var border: some View {
        let review = block.needsReview && !isSelected
        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(
                isSelected ? color : (review ? Theme.accent.opacity(0.85) : .clear),
                style: StrokeStyle(lineWidth: isSelected ? 2 : 1.2, dash: review ? [4, 3] : [])
            )
    }

    private var helpText: String {
        var s = "\(block.title) · \(TimeFmt.range(start, end))"
        if !block.note.isEmpty { s += "\n\(block.note)" }
        return s
    }
}
