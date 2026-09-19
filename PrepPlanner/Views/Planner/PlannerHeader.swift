import SwiftUI
import SwiftData

struct PlannerHeader: View {
    let day: Date
    @Query private var blocks: [TimeBlock]
    @Query private var settings: [AppSettings]
    @Environment(AppState.self) private var state

    init(day: Date) {
        self.day = day
        let d = day
        _blocks = Query(filter: #Predicate<TimeBlock> { $0.day == d })
    }

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    private var greeting: String {
        let weekday = day.formatted(.dateTime.weekday(.wide))
        let cal = Calendar.current
        if isToday { return "Happy \(weekday) 👋" }
        if cal.isDateInTomorrow(day) { return "Tomorrow, \(weekday)" }
        if cal.isDateInYesterday(day) { return "Yesterday, \(weekday)" }
        return weekday
    }

    var body: some View {
        let study = blocks.filter(\.isStudy)
        let planned = study.reduce(0) { $0 + $1.plannedMinutes }
        let done = study.reduce(0) { $0 + $1.effectiveActual }
        let review = blocks.filter(\.needsReview).count

        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                title
                Spacer(minLength: 12)
                cards(planned: planned, done: done, review: review)
            }
            VStack(alignment: .leading, spacing: 12) {
                title
                HStack(spacing: 12) { cards(planned: planned, done: done, review: review) }
            }
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .lineLimit(1)
            DatePicker("Date", selection: Binding(get: { day }, set: { state.setDay($0) }),
                       displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .help("Jump to a date")
        }
        .fixedSize()
    }

    @ViewBuilder
    private func cards(planned: Int, done: Int, review: Int) -> some View {
        DayProgressCard(planned: planned, done: done, review: review, isToday: isToday)
        if let s = settings.first {
            CountdownCard(exam: "IELTS", date: s.ieltsDate, fill: Theme.accent, foreground: .white)
            CountdownCard(exam: "SAT", date: s.satDate, fill: Theme.ink, foreground: Theme.onInk)
        }
    }
}

private struct DayProgressCard: View {
    let planned: Int
    let done: Int
    let review: Int
    let isToday: Bool

    var body: some View {
        let fraction = planned > 0 ? min(Double(done) / Double(planned), 1) : 0
        VStack(alignment: .leading, spacing: 6) {
            Text(isToday ? "TODAY · STUDY HOURS" : "THIS DAY · STUDY HOURS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(TimeFmt.hours(done))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("of \(TimeFmt.hours(planned)) planned")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.cardMuted)
                    Capsule().fill(Theme.success).frame(width: g.size.width * fraction)
                }
            }
            .frame(height: 8)
            Text(review > 0 ? "\(review) block\(review == 1 ? "" : "s") to review" : "\(Int(fraction * 100))% completed")
                .font(.caption.weight(review > 0 ? .semibold : .regular))
                .foregroundStyle(review > 0 ? Theme.accent : .secondary)
        }
        .frame(width: 200, alignment: .leading)
        .card(padding: 14)
    }
}

private struct CountdownCard: View {
    let exam: String
    let date: Date
    let fill: Color
    let foreground: Color

    var body: some View {
        let days = Countdown.days(to: date)
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(max(days, 0))")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(days == 1 ? "day to \(exam)" : "days to \(exam)")
                    .font(.callout.weight(.semibold))
            }
            Text(subtitle(days))
                .font(.caption)
                .opacity(0.8)
        }
        .foregroundStyle(foreground)
        .padding(14)
        .frame(width: 156, height: 96, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).fill(fill))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }

    private func subtitle(_ days: Int) -> String {
        if days < 0 { return "Exam done" }
        if days == 0 { return "Exam day — good luck!" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
    }
}
