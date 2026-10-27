import SwiftUI
import SwiftData

/// Day heading: the date (which opens the month calendar), the day's progress and a strip
/// of the surrounding week.
///
/// One query covers the whole week; the day's own numbers are taken from it.
struct PlannerHeader: View {
    let day: Date
    @Query private var weekBlocks: [TimeBlock]
    @Environment(AppState.self) private var state
    @State private var showCalendar = false

    private let weekStart: Date

    init(day: Date) {
        self.day = day
        let start = Analytics.startOfWeek(day).startOfDay
        let end = start.adding(days: 7).startOfDay
        weekStart = start
        _weekBlocks = Query(filter: #Predicate<TimeBlock> { $0.day >= start && $0.day < end })
    }

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    var body: some View {
        let dayBlocks = weekBlocks.filter { $0.day == day }

        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 24) {
                    title
                    Spacer(minLength: 12)
                    DayProgress(blocks: dayBlocks)
                        .frame(width: 280)
                }
                VStack(alignment: .leading, spacing: 12) {
                    title
                    DayProgress(blocks: dayBlocks)
                        .frame(maxWidth: 320)
                }
            }
            WeekStrip(weekStart: weekStart, selected: day, blocks: weekBlocks) { state.setDay($0) }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: Pieces

    private var title: some View {
        Button {
            showCalendar = true
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: day.formatted(.dateTime.weekday(.wide)).capitalized)
                        .font(.system(size: 22, weight: .semibold))
                        .lineLimit(1)
                    if isToday {
                        Text("Today")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.accent.opacity(0.13)))
                    }
                }
                HStack(spacing: 4) {
                    Text(verbatim: day.formatted(.dateTime.day().month(.wide).year()))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help("Jump to a date")
        .popover(isPresented: $showCalendar, arrowEdge: .bottom) {
            MonthCalendar(selected: day) { state.setDay($0) }
        }
    }
}

// MARK: - Progress

/// Study hours done against planned, with a thin bar and the number of blocks still to mark.
private struct DayProgress: View {
    let blocks: [TimeBlock]

    var body: some View {
        // Re-evaluated every minute so blocks that just ended count as "to review".
        TimelineView(.everyMinute) { context in
            let study = blocks.filter(\.isStudy)
            let planned = study.reduce(0) { $0 + $1.plannedMinutes }
            let done = study.reduce(0) { $0 + $1.effectiveActual }
            let review = blocks.filter { $0.status == .planned && $0.endDate < context.date }.count
            let fraction = planned > 0 ? min(Double(done) / Double(planned), 1) : 0

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(TimeFmt.hours(done))
                        .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    Text("of \(TimeFmt.hours(planned)) planned")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if planned > 0 {
                        Text(verbatim: "\(Int((fraction * 100).rounded()))%")
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                ProgressTrack(fraction: fraction, color: Theme.success)
                Group {
                    if review > 0 {
                        Text("^[\(review) block](inflect: true) to review")
                            .foregroundStyle(Theme.accent)
                    } else if planned == 0 {
                        Text("Nothing planned yet")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Study hours")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
            }
        }
    }
}

/// Thin rounded progress bar.
struct ProgressTrack: View {
    let fraction: Double
    var color: Color = Theme.accent
    var track: Color = Theme.cardMuted
    var height: CGFloat = 5

    var body: some View {
        Capsule()
            .fill(track)
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { g in
                    Capsule()
                        .fill(color)
                        .frame(width: max(g.size.width * min(max(fraction, 0), 1), fraction > 0 ? height : 0))
                }
            }
            .animation(.easeOut(duration: 0.25), value: fraction)
    }
}

// MARK: - Week strip

/// The seven days of the selected week. Each day shows how much of its plan is done.
private struct WeekStrip: View {
    let weekStart: Date
    let selected: Date
    let blocks: [TimeBlock]
    var onPick: (Date) -> Void

    var body: some View {
        let byDay = Dictionary(grouping: blocks.filter(\.isStudy), by: \.day)
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { offset in
                let d = weekStart.adding(days: offset).startOfDay
                let items = byDay[d] ?? []
                let planned = items.reduce(0) { $0 + $1.plannedMinutes }
                let done = items.reduce(0) { $0 + $1.effectiveActual }
                DayCell(date: d, isSelected: d == selected, planned: planned, done: done) { onPick(d) }
            }
        }
    }
}

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let planned: Int
    let done: Int
    var action: () -> Void

    @State private var hovering = false

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    Text(verbatim: date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? Theme.onInk.opacity(0.75) : .secondary)
                    Text(verbatim: "\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(isSelected ? Theme.onInk : (isToday ? Theme.accent : .primary))
                }
                ProgressTrack(
                    fraction: planned > 0 ? Double(done) / Double(planned) : 0,
                    color: isSelected ? Theme.onInk : Theme.success,
                    track: isSelected ? Theme.onInk.opacity(0.25) : Theme.cardMuted,
                    height: 3
                )
                .opacity(planned > 0 ? 1 : 0)
                .padding(.horizontal, 10)
            }
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Theme.ink : (hovering ? Theme.cardMuted : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isToday && !isSelected ? Theme.accent.opacity(0.5) : .clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(helpText)
    }

    private var helpText: String {
        let d = date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        guard planned > 0 else { return d }
        return "\(d) · \(TimeFmt.hours(done)) / \(TimeFmt.hours(planned))"
    }
}
