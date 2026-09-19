import SwiftUI
import SwiftData

struct HabitsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var context
    @Query(sort: \Habit.order) private var allHabits: [Habit]
    @State private var day = Date().startOfDay
    @State private var pendingDelete: Habit?

    private var habits: [Habit] { allHabits.filter { !$0.isArchived } }
    private var archived: [Habit] { allHabits.filter(\.isArchived) }
    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if habits.isEmpty && archived.isEmpty {
                    ContentUnavailableView {
                        Label("No habits yet", systemImage: "checkmark.circle")
                    } actions: {
                        Button("Add Habit") { state.editor = .habit(nil) }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, minHeight: 400)
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        checklist
                        summary
                            .frame(width: 300)
                    }
                    if !habits.isEmpty {
                        overallHeatmap
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 16, alignment: .top)],
                                  alignment: .leading, spacing: 16) {
                            ForEach(habits) { h in
                                HabitCard(habit: h, menu: { habitMenu(h) })
                            }
                        }
                    }
                    if !archived.isEmpty { archivedCard }
                }
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("Habits")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { day = day.adding(days: -1).startOfDay } label: { Label("Previous Day", systemImage: "chevron.left") }
                Button("Today") { day = Date().startOfDay }
                Button { day = day.adding(days: 1).startOfDay } label: { Label("Next Day", systemImage: "chevron.right") }
                    .disabled(isToday)
            }
            ToolbarItem {
                Button { state.editor = .habit(nil) } label: { Label("New Habit", systemImage: "plus") }
                    .help("New habit (⌥⌘N)")
            }
        }
        .confirmationDialog(
            "Delete “\(pendingDelete?.name ?? "")”?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { h in
            Button("Delete", role: .destructive) {
                context.delete(h)
                try? context.save()
            }
        } message: { _ in
            Text("Its whole history is deleted too. Archive it instead to keep the history.")
        }
    }

    // MARK: Checklist

    private var checklist: some View {
        let done = habits.filter { h in h.checks.contains { $0.day == day } }.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isToday ? "Today's habits" : "Habits")
                        .font(.title2.bold())
                    Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(verbatim: "\(done)/\(habits.count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(done == habits.count && done > 0 ? Theme.success : .primary)
            }
            if habits.isEmpty {
                Text("All habits are archived.").foregroundStyle(.secondary)
            }
            ForEach(habits) { h in
                HabitCheckRow(habit: h, day: day)
                    .contextMenu { habitMenu(h) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 18)
    }

    private var summary: some View {
        let stats = habits.map { ($0, HabitStats(habit: $0)) }
        let top = stats.max { $0.1.current < $1.1.current }
        let levels = HabitStats.dailyLevels(habits: habits)
        let today = Date().startOfDay
        let perfect = (0..<30).filter { levels[today.adding(days: -$0).startOfDay] ?? 0 >= 1 }.count

        return VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("LONGEST CURRENT STREAK")
                    .font(.caption.weight(.semibold))
                    .opacity(0.85)
                Text(verbatim: "🔥 \(top?.1.current ?? 0)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(verbatim: top.map { $0.1.current > 0 ? $0.0.name : "" } ?? "")
                    .font(.caption)
                    .opacity(0.85)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).fill(Theme.accent))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("PERFECT DAYS, LAST 30")
                    .font(.caption.weight(.semibold))
                    .opacity(0.75)
                Text(verbatim: "\(perfect)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Days with every habit done")
                    .font(.caption)
                    .opacity(0.75)
            }
            .foregroundStyle(Theme.onInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).fill(Theme.ink))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        }
    }

    private var overallHeatmap: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("All habits, last 60 days").font(.headline)
                Spacer()
                HeatmapLegend(color: Theme.accent)
            }
            HabitHeatmap(levels: HabitStats.dailyLevels(habits: habits), color: Theme.accent, cellSize: 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 18)
    }

    private var archivedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Archived").font(.headline)
            ForEach(archived) { h in
                HStack {
                    Text(verbatim: "\(h.emoji)  \(h.name)")
                    Spacer()
                    Button("Restore") { h.isArchived = false }
                    Button("Delete", role: .destructive) { pendingDelete = h }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 18)
    }

    @ViewBuilder
    private func habitMenu(_ h: Habit) -> some View {
        Button("Edit…") { state.editor = .habit(h) }
        Button("Move Up") { move(h, by: -1) }
            .disabled(habits.first?.uid == h.uid)
        Button("Move Down") { move(h, by: 1) }
            .disabled(habits.last?.uid == h.uid)
        Divider()
        Button("Archive") { h.isArchived = true }
        Button("Delete", role: .destructive) { pendingDelete = h }
    }

    private func move(_ h: Habit, by offset: Int) {
        var ordered = habits
        guard let i = ordered.firstIndex(where: { $0.uid == h.uid }) else { return }
        let j = i + offset
        guard ordered.indices.contains(j) else { return }
        ordered.swapAt(i, j)
        for (index, habit) in ordered.enumerated() { habit.order = index }
    }
}

// MARK: - Rows and cards

private struct HabitCheckRow: View {
    let habit: Habit
    let day: Date
    @Environment(\.modelContext) private var context

    private var isChecked: Bool { habit.checks.contains { $0.day == day } }

    var body: some View {
        let stats = HabitStats(habit: habit)
        Button(action: toggle) {
            HStack(spacing: 12) {
                Text(verbatim: habit.emoji)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.cardMuted))
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: habit.name)
                        .font(.body.weight(.medium))
                        .strikethrough(isChecked)
                        .foregroundStyle(isChecked ? .secondary : .primary)
                    HStack(spacing: 10) {
                        Text("🔥 ^[\(stats.current) day](inflect: true)")
                        Text("🏆 \(stats.best)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(isChecked ? Theme.success : .secondary)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle() {
        if let check = habit.checks.first(where: { $0.day == day }) {
            habit.checks.removeAll { $0.uid == check.uid }
            context.delete(check)
        } else {
            let check = HabitCheck(day: day)
            context.insert(check)
            check.habit = habit
        }
        try? context.save()
    }
}

private struct HabitCard<MenuContent: View>: View {
    let habit: Habit
    @ViewBuilder var menu: MenuContent

    var body: some View {
        let stats = HabitStats(habit: habit)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(verbatim: habit.emoji).font(.title2)
                Text(verbatim: habit.name).font(.headline).lineLimit(1)
                Spacer()
                Menu { menu } label: { Image(systemName: "ellipsis.circle") }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
            }
            HStack(spacing: 10) {
                StatTile(symbol: "🔥", value: stats.current, title: "Current streak")
                StatTile(symbol: "🏆", value: stats.best, title: "Best streak")
                StatTile(symbol: "✓", value: stats.lastSixty, title: "Last 60 days")
            }
            HabitHeatmap(levels: stats.checkedDays.reduce(into: [:]) { $0[$1] = 1 }, color: Theme.success, cellSize: 13)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
    }
}

private struct StatTile: View {
    let symbol: String
    let value: Int
    let title: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: "\(symbol) \(value)")
                .font(.title3.weight(.bold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.cardMuted))
    }
}

// MARK: - Heatmap

/// GitHub-style grid of the last 60 days: one column per week, Monday at the top.
struct HabitHeatmap: View {
    let levels: [Date: Double]
    var color: Color
    var cellSize: CGFloat = 13
    private let dayCount = 60

    var body: some View {
        let today = Date().startOfDay
        let start = today.adding(days: -(dayCount - 1)).startOfDay
        let gridStart = Analytics.startOfWeek(start)
        let span = (Calendar.current.dateComponents([.day], from: gridStart, to: today).day ?? 0) + 1
        let weeks = Int((Double(span) / 7).rounded(.up))
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols

        HStack(alignment: .top, spacing: 3) {
            VStack(alignment: .trailing, spacing: 3) {
                ForEach(0..<7, id: \.self) { row in
                    // Label Monday, Wednesday and Friday like GitHub does.
                    Text(verbatim: row % 2 == 0 && row < 6 ? symbols[(row + 1) % 7] : "")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 12, height: cellSize)
                }
            }
            ForEach(0..<weeks, id: \.self) { week in
                VStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { row in
                        let d = gridStart.adding(days: week * 7 + row).startOfDay
                        cell(d, inRange: d >= start && d <= today)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(_ day: Date, inRange: Bool) -> some View {
        let level = levels[day] ?? 0
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(inRange ? (level > 0 ? color.opacity(0.3 + 0.7 * level) : Theme.cardMuted) : Color.clear)
            .frame(width: cellSize, height: cellSize)
            .help(inRange ? day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) : "")
    }
}

private struct HeatmapLegend: View {
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text("Less").font(.caption2).foregroundStyle(.secondary)
            ForEach([0.0, 0.34, 0.67, 1.0], id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(level == 0 ? Theme.cardMuted : color.opacity(0.3 + 0.7 * level))
                    .frame(width: 10, height: 10)
            }
            Text("More").font(.caption2).foregroundStyle(.secondary)
        }
    }
}
