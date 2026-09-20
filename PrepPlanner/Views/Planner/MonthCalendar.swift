import SwiftUI
import SwiftData

/// Month grid used by the planner's date button: large day cells, today and selection
/// highlights, and a dot for every category planned on that day.
struct MonthCalendar: View {
    let selected: Date
    var onPick: (Date) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var visibleMonth: Date = Date().startOfDay
    /// Category colors per day, for the dots under each date.
    @State private var marks: [Date: [String]] = [:]

    private var calendar: Calendar { Analytics.calendar }

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: visibleMonth)) ?? visibleMonth
    }

    /// Six weeks starting on the Monday on or before the first of the month.
    private var days: [Date] {
        let gridStart = Analytics.startOfWeek(monthStart)
        return (0..<42).map { gridStart.adding(days: $0).startOfDay }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        return (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            HStack(spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(verbatim: symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 4), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { day in
                    dayCell(day)
                }
            }
            Divider()
            HStack {
                Label("Days with blocks show a dot", systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(DotLegendStyle())
                Spacer()
            }
        }
        .padding(16)
        .frame(width: 356)
        .onAppear {
            visibleMonth = selected
            reload()
        }
        .onChange(of: visibleMonth) { reload() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(verbatim: monthStart.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
            Spacer()
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.borderless)
                .help("Previous month")
            Button("Today") {
                visibleMonth = Date().startOfDay
                pick(Date().startOfDay)
            }
            .buttonStyle(.borderless)
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.borderless)
                .help("Next month")
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = day == selected.startOfDay
        let isToday = calendar.isDateInToday(day)
        let inMonth = calendar.isDate(day, equalTo: monthStart, toGranularity: .month)
        let colors = marks[day] ?? []

        return Button {
            pick(day)
        } label: {
            VStack(spacing: 3) {
                Text(verbatim: "\(calendar.component(.day, from: day))")
                    .font(.system(size: 15, weight: isSelected || isToday ? .semibold : .regular, design: .rounded))
                    .monospacedDigit()
                HStack(spacing: 3) {
                    ForEach(Array(colors.prefix(4).enumerated()), id: \.offset) { _, hex in
                        Circle()
                            .fill(isSelected ? Color.white.opacity(0.9) : Color(hex: hex))
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(width: 44, height: 46)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isSelected ? Theme.accent : (isToday ? Theme.accentSoft : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(isToday && !isSelected ? Theme.accent.opacity(0.6) : .clear)
            )
            .foregroundStyle(isSelected ? .white : (inMonth ? .primary : .secondary))
            .opacity(inMonth ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
    }

    private func pick(_ day: Date) {
        onPick(day)
        dismiss()
    }

    private func shiftMonth(_ delta: Int) {
        visibleMonth = calendar.date(byAdding: .month, value: delta, to: monthStart) ?? monthStart
    }

    /// Loads which categories are planned on each visible day.
    private func reload() {
        guard let first = days.first, let last = days.last else { return }
        let descriptor = FetchDescriptor<TimeBlock>(
            predicate: #Predicate { $0.day >= first && $0.day <= last },
            sortBy: [SortDescriptor(\.day), SortDescriptor(\.startMin)]
        )
        let blocks = (try? context.fetch(descriptor)) ?? []
        var result: [Date: [String]] = [:]
        for block in blocks {
            let hex = block.category?.colorHex ?? "#8E8E93"
            var colors = result[block.day] ?? []
            if !colors.contains(hex) { colors.append(hex) }
            result[block.day] = colors
        }
        marks = result
    }
}

/// Shows the legend dot in the app's accent color.
private struct DotLegendStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
                .font(.system(size: 5))
                .foregroundStyle(Theme.accent)
            configuration.title
        }
    }
}
