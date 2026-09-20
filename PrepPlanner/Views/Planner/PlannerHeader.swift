import SwiftUI
import SwiftData

/// Day heading: greeting, date picker and the three summary cards.
///
/// The header folds from one row into two and then three as it loses width, so it keeps
/// working when the window is narrow, the inspector is open, or a translation is longer
/// than the English original.
struct PlannerHeader: View {
    let day: Date
    @Query private var blocks: [TimeBlock]
    @Query private var settings: [AppSettings]
    @Environment(AppState.self) private var state
    @State private var showCalendar = false
    @State private var hoveringDate = false

    init(day: Date) {
        self.day = day
        let d = day
        _blocks = Query(filter: #Predicate<TimeBlock> { $0.day == d })
    }

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    private var greeting: String {
        let weekday = day.formatted(.dateTime.weekday(.wide))
        let cal = Calendar.current
        if isToday { return String(localized: "Happy \(weekday) 👋") }
        if cal.isDateInTomorrow(day) { return String(localized: "Tomorrow, \(weekday)") }
        if cal.isDateInYesterday(day) { return String(localized: "Yesterday, \(weekday)") }
        return weekday.prefix(1).uppercased() + weekday.dropFirst()
    }

    var body: some View {
        let study = blocks.filter(\.isStudy)
        let planned = study.reduce(0) { $0 + $1.plannedMinutes }
        let done = study.reduce(0) { $0 + $1.effectiveActual }
        let review = blocks.filter(\.needsReview).count

        ViewThatFits(in: .horizontal) {
            // Wide: greeting on the left, every card on the right.
            row {
                title(size: 30)
                    .frame(maxHeight: .infinity, alignment: .leading)
                Spacer(minLength: 16)
                progress(planned: planned, done: done, review: review, width: .capped(ideal: 236, max: 300))
                countdowns(width: .capped(ideal: 166, max: 196))
            }

            // Medium: greeting above a single row of equal cards.
            VStack(alignment: .leading, spacing: 14) {
                title(size: 28)
                row {
                    progress(planned: planned, done: done, review: review, width: .fill)
                    countdowns(width: .fill)
                }
            }

            // Narrow: the two countdowns share the last row, and every card drops to the
            // compact density so the header leaves the timeline some room.
            VStack(alignment: .leading, spacing: 10) {
                title(size: 22)
                row { progress(planned: planned, done: done, review: review, width: .fill, density: .compact) }
                row { countdowns(width: .fill, density: .compact) }
            }
        }
    }

    // MARK: Pieces

    /// A row of cards that all take the height of the tallest one.
    private func row<C: View>(@ViewBuilder content: () -> C) -> some View {
        HStack(alignment: .top, spacing: 12) { content() }
            .fixedSize(horizontal: false, vertical: true)
    }

    private func title(size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greeting)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            datePicker
        }
    }

    private var datePicker: some View {
        Button {
            showCalendar = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                Text(verbatim: day.formatted(.dateTime.day().month(.wide).year()))
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(showCalendar || hoveringDate ? Theme.cardMuted : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.gridLine, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hoveringDate = $0 }
        .animation(.easeOut(duration: 0.12), value: hoveringDate)
        .help("Jump to a date")
        .popover(isPresented: $showCalendar, arrowEdge: .bottom) {
            MonthCalendar(selected: day) { state.setDay($0) }
        }
    }

    private func progress(
        planned: Int, done: Int, review: Int,
        width: HeroCardWidth, density: HeroDensity = .regular
    ) -> some View {
        DayProgressCard(planned: planned, done: done, review: review, isToday: isToday, density: density)
            .heroCardWidth(width)
    }

    @ViewBuilder
    private func countdowns(width: HeroCardWidth, density: HeroDensity = .regular) -> some View {
        if let s = settings.first {
            CountdownCard(exam: "IELTS", date: s.ieltsDate, fill: Theme.accent, foreground: .white, density: density)
                .heroCardWidth(width)
            CountdownCard(exam: "SAT", date: s.satDate, fill: Theme.ink, foreground: Theme.onInk, density: density)
                .heroCardWidth(width)
        }
    }
}

// MARK: - Card chrome

/// How much width a hero card asks for: its share of the row, or a preferred size it may
/// grow a little beyond.
enum HeroCardWidth {
    case fill
    case capped(ideal: CGFloat, max: CGFloat)
}

private extension View {
    @ViewBuilder
    func heroCardWidth(_ width: HeroCardWidth) -> some View {
        switch width {
        case .fill:
            frame(maxWidth: .infinity)
        case let .capped(ideal, max):
            frame(idealWidth: ideal, maxWidth: max)
        }
    }
}

/// How tightly a hero card is packed. The narrow layout stacks all three cards, so it uses
/// the compact set to keep the header from crowding out the timeline.
enum HeroDensity {
    case regular, compact

    var padding: CGFloat { self == .regular ? 14 : 11 }
    var cornerRadius: CGFloat { self == .regular ? Theme.cornerRadius : 14 }
    var spacing: CGFloat { self == .regular ? 6 : 3 }
    var metric: Font { .system(size: self == .regular ? 28 : 22, weight: .bold, design: .rounded) }
    var label: Font { self == .regular ? .callout : .footnote }
    var caption: Font { self == .regular ? .caption : .caption2 }
}

/// One card in the header row. Every card in a row shares the same radius, padding, shadow
/// and density, and stretches to the height of that row, so they read as one set.
private struct HeroCard<Content: View>: View {
    var fill: Color = Theme.card
    var density: HeroDensity = .regular
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: density.spacing) { content }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(density.padding)
            .background(
                RoundedRectangle(cornerRadius: density.cornerRadius, style: .continuous).fill(fill)
            )
            .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
    }
}

// MARK: - Cards

private struct DayProgressCard: View {
    let planned: Int
    let done: Int
    let review: Int
    let isToday: Bool
    var density: HeroDensity = .regular

    var body: some View {
        let fraction = planned > 0 ? min(Double(done) / Double(planned), 1) : 0
        HeroCard(density: density) {
            Text(isToday ? "TODAY · STUDY HOURS" : "THIS DAY · STUDY HOURS")
                .font(density.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Side by side while both halves fit; stacked once a translation is too long.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    hours
                    plannedLabel
                }
                VStack(alignment: .leading, spacing: 1) {
                    hours
                    plannedLabel
                }
            }

            Spacer(minLength: density == .regular ? 4 : 2)

            Capsule()
                .fill(Theme.cardMuted)
                .frame(height: density == .regular ? 8 : 6)
                .overlay(alignment: .leading) {
                    GeometryReader { g in
                        Capsule()
                            .fill(Theme.success)
                            .frame(width: g.size.width * fraction)
                    }
                }
                .animation(.easeOut(duration: 0.25), value: fraction)

            // The percentage only repeats what the bar already says; compact keeps the
            // line for the review prompt, which is the one thing worth acting on.
            if review > 0 || density == .regular {
                footnote(fraction: fraction)
            }
        }
    }

    private var hours: some View {
        Text(TimeFmt.hours(done))
            .font(density.metric)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private var plannedLabel: some View {
        Text("of \(TimeFmt.hours(planned)) planned")
            .font(density.label)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private func footnote(fraction: Double) -> some View {
        Group {
            if review > 0 {
                Text("^[\(review) block](inflect: true) to review")
            } else {
                Text("\(Int(fraction * 100))% completed")
            }
        }
        .font(density.caption.weight(review > 0 ? .semibold : .regular))
        .foregroundStyle(review > 0 ? Theme.accent : .secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

private struct CountdownCard: View {
    let exam: String
    let date: Date
    let fill: Color
    let foreground: Color
    var density: HeroDensity = .regular

    var body: some View {
        let days = Countdown.days(to: date)
        HeroCard(fill: fill, density: density) {
            // The layout is fixed per density rather than per card: "days to IELTS" and
            // "days to SAT" are different lengths in every language, and the two cards
            // have to break the same way to read as a pair.
            if density == .regular {
                VStack(alignment: .leading, spacing: 0) {
                    count(days)
                    label(days)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    count(days)
                    label(days)
                }
            }

            Spacer(minLength: density == .regular ? 4 : 1)

            Text(subtitle(days))
                .font(density.caption)
                .opacity(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(foreground)
    }

    private func count(_ days: Int) -> some View {
        Text("\(max(days, 0))")
            .font(density.metric)
            .monospacedDigit()
            .lineLimit(1)
    }

    private func label(_ days: Int) -> some View {
        Text(days == 1 ? "day to \(exam)" : "days to \(exam)")
            .font(density.label.weight(.semibold))
            .lineLimit(density == .regular ? 2 : 1)
            .minimumScaleFactor(0.75)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func subtitle(_ days: Int) -> String {
        if days < 0 { return String(localized: "Exam done") }
        if days == 0 { return String(localized: "Exam day — good luck!") }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
    }
}
