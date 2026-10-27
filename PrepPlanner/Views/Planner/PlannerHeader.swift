import SwiftUI
import SwiftData

/// Top of the planner: a dark band with the date as a two-tone heading and a bar chart of
/// the week, and a row of stat cards that overlaps the band's lower edge.
///
/// One query covers the whole week; the day's own numbers are taken from it.
struct PlannerHeader: View {
    let day: Date
    @Query private var weekBlocks: [TimeBlock]
    @Query private var settings: [AppSettings]
    @Environment(AppState.self) private var state
    @State private var showCalendar = false

    private let weekStart: Date
    /// How far the stat cards reach up into the dark band.
    private static let overlap: CGFloat = 46

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

        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 24) {
                    title
                    Spacer(minLength: 0)
                    WeekBars(weekStart: weekStart, selected: day, blocks: weekBlocks) { state.setDay($0) }
                }
                VStack(alignment: .leading, spacing: 18) {
                    title
                    WeekBars(weekStart: weekStart, selected: day, blocks: weekBlocks) { state.setDay($0) }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 22 + Self.overlap)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HeroGlow(colors: glowColors(dayBlocks)))

            StatCards(blocks: dayBlocks, settings: settings.first)
                .padding(.horizontal, 16)
                .padding(.top, -Self.overlap)
        }
    }

    // MARK: Title

    private var title: some View {
        Button {
            showCalendar = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    if isToday {
                        Text("Today")
                            .foregroundStyle(Theme.onHighlight)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Theme.highlight))
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text("Jump to a date")
                    }
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().strokeBorder(.white.opacity(0.18)))
                }
                .font(.system(size: 11, weight: .semibold))

                VStack(alignment: .leading, spacing: -4) {
                    Text(verbatim: day.formatted(.dateTime.weekday(.wide)).capitalized)
                        .foregroundStyle(.white)
                    Text(verbatim: day.formatted(.dateTime.day().month(.wide)))
                        .foregroundStyle(.white.opacity(0.38))
                }
                .font(.system(size: 40, weight: .bold))
                .tracking(-0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Jump to a date")
        .popover(isPresented: $showCalendar, arrowEdge: .bottom) {
            MonthCalendar(selected: day) { state.setDay($0) }
        }
    }

    /// The glow behind the header takes the colors of the day's biggest categories.
    private func glowColors(_ blocks: [TimeBlock]) -> [Color] {
        var minutes: [String: Int] = [:]
        for b in blocks where b.isStudy { minutes[b.category?.colorHex ?? "#8E8E93", default: 0] += b.plannedMinutes }
        let top = minutes.sorted { $0.value > $1.value }.prefix(3).map { Color(hex: $0.key) }
        return top.isEmpty ? [Theme.accent, Color(hex: "#7B61D9")] : top
    }
}

// MARK: - Week bars

/// One bar per day of the week: its height is the plan, the bright part is what got done.
private struct WeekBars: View {
    let weekStart: Date
    let selected: Date
    let blocks: [TimeBlock]
    var onPick: (Date) -> Void

    private static let maxHeight: CGFloat = 86

    var body: some View {
        let byDay = Dictionary(grouping: blocks.filter(\.isStudy), by: \.day)
        let totals = (0..<7).map { offset -> (Date, Int, Int) in
            let d = weekStart.adding(days: offset).startOfDay
            let items = byDay[d] ?? []
            return (d, items.reduce(0) { $0 + $1.plannedMinutes }, items.reduce(0) { $0 + $1.effectiveActual })
        }
        let most = max(totals.map(\.1).max() ?? 0, 60)

        HStack(alignment: .bottom, spacing: 10) {
            ForEach(totals, id: \.0) { day, planned, done in
                Bar(date: day, isSelected: day == selected, planned: planned, done: done,
                    height: planned > 0 ? max(Self.maxHeight * CGFloat(planned) / CGFloat(most), 14) : 4) {
                    onPick(day)
                }
            }
        }
        .frame(height: Self.maxHeight + 34, alignment: .bottom)
    }

    private struct Bar: View {
        let date: Date
        let isSelected: Bool
        let planned: Int
        let done: Int
        let height: CGFloat
        var action: () -> Void

        @State private var hovering = false

        private var isToday: Bool { Calendar.current.isDateInToday(date) }

        var body: some View {
            Button(action: action) {
                VStack(spacing: 7) {
                    ZStack(alignment: .bottom) {
                        Capsule()
                            .fill(isSelected ? Theme.highlight : .white.opacity(hovering ? 0.16 : 0.09))
                        if !isSelected, planned > 0, done > 0 {
                            Capsule()
                                .fill(.white.opacity(0.5))
                                .frame(height: max(height * min(CGFloat(done) / CGFloat(planned), 1), 8))
                        }
                    }
                    .frame(width: 26, height: height)
                    .shadow(color: isSelected ? Theme.highlight.opacity(0.55) : .clear, radius: 12)

                    VStack(spacing: 1) {
                        Text(verbatim: date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                            .font(.system(size: 9.5, weight: .semibold))
                        Text(verbatim: "\(Calendar.current.component(.day, from: date))")
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    }
                    .foregroundStyle(isSelected ? Theme.highlight : .white.opacity(isToday ? 0.85 : 0.42))
                    .frame(width: 34)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .animation(.spring(duration: 0.35), value: height)
            .help(helpText)
        }

        private var helpText: String {
            let d = date.formatted(.dateTime.weekday(.wide).day().month(.wide))
            guard planned > 0 else { return d }
            return "\(d) · \(TimeFmt.hours(done)) / \(TimeFmt.hours(planned))"
        }
    }
}

// MARK: - Stat cards

private struct StatCards: View {
    let blocks: [TimeBlock]
    let settings: AppSettings?

    var body: some View {
        // Re-evaluated every minute so blocks that just ended count as "to review".
        TimelineView(.everyMinute) { context in
            let study = blocks.filter(\.isStudy)
            let planned = study.reduce(0) { $0 + $1.plannedMinutes }
            let done = study.reduce(0) { $0 + $1.effectiveActual }
            let review = blocks.filter { $0.status == .planned && $0.endDate < context.date }.count
            let percent = planned > 0 ? Int((min(Double(done) / Double(planned), 1) * 100).rounded()) : 0

            let cards = [
                AnyView(MetricCard(title: Text("Studied"),
                                   subtitle: review > 0 ? Text("^[\(review) block](inflect: true) to review") : Text("today"),
                                   subtitleTint: review > 0 ? Theme.accent : nil,
                                   value: TimeFmt.hours(done), symbol: "clock.fill", color: Theme.accent)),
                AnyView(MetricCard(title: Text("Planned"),
                                   subtitle: Text("^[\(blocks.count) block](inflect: true)"),
                                   value: TimeFmt.hours(planned), symbol: "square.stack.fill", color: Color(hex: "#3F8FD2"))),
                AnyView(MetricCard(title: Text("Progress"),
                                   subtitle: Text("of the plan"),
                                   value: "\(percent)%", symbol: "chart.bar.fill", color: Color(hex: "#9B6BE0"))),
                AnyView(examCard),
            ]
            // Four across while each card keeps a readable width, otherwise two by two. A grid
            // with adaptive columns would leave empty slots on the right of a wide window.
            ViewThatFits(in: .horizontal) {
                CardRow(spacing: 12) { ForEach(0..<4, id: \.self) { cards[$0].frame(minWidth: 160) } }
                VStack(spacing: 12) {
                    CardRow(spacing: 12) { cards[0]; cards[1] }
                    CardRow(spacing: 12) { cards[2]; cards[3] }
                }
            }
        }
    }

    @ViewBuilder
    private var examCard: some View {
        let exams = [("IELTS", settings?.ieltsDate), ("SAT", settings?.satDate)]
            .compactMap { name, date in date.map { (name, Countdown.days(to: $0)) } }
            .filter { $0.1 >= 0 }
            .sorted { $0.1 < $1.1 }
        if let next = exams.first {
            MetricCard(title: Text(verbatim: next.0),
                     subtitle: Text(next.1 == 0 ? "is today" : "exam in"),
                     value: String(localized: "\(next.1)d"), symbol: "graduationcap.fill", color: Theme.success)
        } else {
            MetricCard(title: Text("Exams"), subtitle: Text("all done"),
                     value: "–", symbol: "checkmark.seal.fill", color: Theme.success)
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
