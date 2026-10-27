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
        // Streaks walk every check of a habit, so work them out once per render and hand
        // them down instead of letting each tile and card recompute them.
        let active = habits
        let stats = Dictionary(uniqueKeysWithValues: active.map { ($0.uid, HabitStats(habit: $0)) })
        let levels = HabitStats.dailyLevels(habits: active)
        let doneToday = active.filter { h in h.checks.contains { $0.day == day } }.count

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeroBanner(title: Text(isToday ? "Today's habits" : "Habits"),
                           subtitle: Text(verbatim: day.formatted(.dateTime.weekday(.wide).day().month(.wide))),
                           colors: [Theme.success, Theme.highlight]) {
                    HStack(alignment: .center, spacing: 16) {
                        if !active.isEmpty {
                            ActivityRing(done: doneToday, total: active.count)
                        }
                        PillButton(title: "New Habit") { state.editor = .habit(nil) }
                            .help("New habit (⌥⌘N)")
                    }
                }

                if active.isEmpty && archived.isEmpty {
                    ContentUnavailableView {
                        Label("No habits yet", systemImage: "checkmark.circle")
                    } actions: {
                        PillButton(title: "Add Habit") { state.editor = .habit(nil) }
                    }
                    .frame(maxWidth: .infinity, minHeight: 400)
                } else {
                    if active.isEmpty {
                        Text("All habits are archived.").foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
                            ForEach(active) { h in
                                HabitTile(habit: h, day: day, streak: stats[h.uid]?.current ?? 0)
                                    .contextMenu { habitMenu(h) }
                            }
                        }

                        summary(stats: stats, levels: levels)

                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("All habits")
                                    .font(.system(size: 15, weight: .bold))
                                Spacer()
                                HeatmapLegend(color: Theme.success)
                            }
                            HabitHeatmap(levels: levels, color: Theme.success, cellSize: 15, maxWeeks: 53)
                        }
                        .card(padding: 18)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 12, alignment: .top)],
                                  alignment: .leading, spacing: 12) {
                            ForEach(active) { h in
                                if let s = stats[h.uid] {
                                    HabitCard(habit: h, stats: s, menu: { habitMenu(h) })
                                }
                            }
                        }
                    }
                    if !archived.isEmpty { archivedCard }
                }
            }
            .padding(20)
            .animation(.spring(duration: 0.35), value: doneToday)
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

    // MARK: Summary

    private func summary(stats: [UUID: HabitStats], levels: [Date: Double]) -> some View {
        let top = habits.compactMap { h in stats[h.uid].map { (h, $0) } }.max { $0.1.current < $1.1.current }
        let today = Date().startOfDay
        let perfect = (0..<30).filter { levels[today.adding(days: -$0).startOfDay] ?? 0 >= 1 }.count
        let week = (0..<7).map { levels[today.adding(days: -$0).startOfDay] ?? 0 }
        let weekPercent = Int((week.reduce(0, +) / 7 * 100).rounded())

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 160), spacing: 12), count: 3), spacing: 12) {
            summaryTile(title: "LONGEST CURRENT STREAK",
                        detail: Text(verbatim: top.map { $0.1.current > 0 ? $0.0.name : "" } ?? ""),
                        value: "\(top?.1.current ?? 0)", symbol: "flame.fill", tint: Theme.accent)
            summaryTile(title: "PERFECT DAYS, LAST 30",
                        detail: Text("Days with every habit done"),
                        value: "\(perfect)", symbol: "checkmark.seal.fill", tint: Theme.success)
            summaryTile(title: "LAST 7 DAYS",
                        detail: Text("of all habits done"),
                        value: "\(weekPercent)%", symbol: "chart.bar.fill", tint: Color(hex: "#3F8FD2"))
        }
    }

    private func summaryTile(title: LocalizedStringKey, detail: Text, value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                detail
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            HStack(alignment: .bottom) {
                IconChip(symbol: symbol, color: tint, size: 32)
                Spacer()
                DotNumber(value: value, dot: 3.4)
            }
            .frame(height: 34, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
    }

    // MARK: Archive

    private var archivedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Archived").font(.system(size: 15, weight: .bold))
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

// MARK: - Ring

/// Apple-style progress ring with the count in the middle.
private struct ActivityRing: View {
    let done: Int
    let total: Int

    var body: some View {
        let fraction = total > 0 ? Double(done) / Double(total) : 0
        ZStack {
            Circle().stroke(.white.opacity(0.12), lineWidth: 7)
            Circle()
                .trim(from: 0, to: max(fraction, 0.001))
                .stroke(
                    AngularGradient(colors: [Theme.success, Theme.highlight, Theme.success], center: .center),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.highlight.opacity(fraction >= 1 ? 0.6 : 0), radius: 8)
            Text(verbatim: "\(done)/\(total)")
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
        }
        .frame(width: 54, height: 54)
        .animation(.spring(duration: 0.5), value: fraction)
    }
}

// MARK: - Tiles and cards

/// A habit for the chosen day as a large toggle: it fills with color once checked.
private struct HabitTile: View {
    let habit: Habit
    let day: Date
    let streak: Int
    @Environment(\.modelContext) private var context
    @State private var hovering = false
    @State private var pop = false

    private var isChecked: Bool { habit.checks.contains { $0.day == day } }

    var body: some View {
        let checked = isChecked
        Button(action: toggle) {
            HStack(spacing: 12) {
                Text(verbatim: habit.emoji)
                    .font(.system(size: 22))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(checked ? .white.opacity(0.22) : Theme.cardMuted))
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: habit.name)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(checked ? .white : .primary)
                        .lineLimit(2)
                    Label { Text("^[\(streak) day](inflect: true)") } icon: { Image(systemName: "flame.fill") }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(checked ? .white.opacity(0.8) : .secondary)
                }
                Spacer(minLength: 4)
                ZStack {
                    Circle()
                        .strokeBorder(checked ? .white : Color.secondary.opacity(0.4), lineWidth: 1.8)
                    if checked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 24, height: 24)
                .scaleEffect(pop ? 1.25 : 1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(checked ? AnyShapeStyle(Theme.success.gradient) : AnyShapeStyle(Theme.card))
                    .shadow(color: .black.opacity(hovering ? 0.08 : 0.04), radius: hovering ? 12 : 8, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(checked ? .clear : Theme.hairline.opacity(0.6), lineWidth: 1)
            )
            .scaleEffect(hovering ? 1.01 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.spring(duration: 0.3, bounce: 0.3), value: checked)
        .animation(.easeOut(duration: 0.15), value: hovering)
    }

    private func toggle() {
        if let check = habit.checks.first(where: { $0.day == day }) {
            habit.checks.removeAll { $0.uid == check.uid }
            context.delete(check)
        } else {
            let check = HabitCheck(day: day)
            context.insert(check)
            check.habit = habit
            withAnimation(.spring(duration: 0.2, bounce: 0.6)) { pop = true }
            Task {
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(.spring(duration: 0.3)) { pop = false }
            }
        }
        try? context.save()
    }
}

private struct HabitCard<MenuContent: View>: View {
    let habit: Habit
    let stats: HabitStats
    @ViewBuilder var menu: MenuContent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(verbatim: habit.emoji)
                    .font(.system(size: 17))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.cardMuted))
                Text(verbatim: habit.name)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                Spacer()
                Menu { menu } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Theme.cardMuted))
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            HStack(spacing: 8) {
                StatTile(symbol: "flame.fill", value: stats.current, title: "Current streak")
                StatTile(symbol: "trophy.fill", value: stats.best, title: "Best streak")
                StatTile(symbol: "checkmark", value: stats.lastSixty, title: "Last 60 days")
            }
            HabitHeatmap(levels: stats.checkedDays.reduce(into: [:]) { $0[$1] = 1 }, color: Theme.success, cellSize: 12)
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
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(verbatim: "\(value)")
                    .font(.system(size: 17, weight: .bold))
                    .monospacedDigit()
            }
            Text(title)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.cardMuted))
    }
}

// MARK: - Heatmap

/// GitHub-style grid ending today: one column per week, Monday at the top. It shows as many
/// weeks as fit the width (up to half a year) and draws in a single Canvas; hovering a day
/// names it.
struct HabitHeatmap: View {
    let levels: [Date: Double]
    var color: Color
    var cellSize: CGFloat = 13
    var maxWeeks = 26

    @State private var hovered: Date?
    private let gap: CGFloat = 3
    private let labelWidth: CGFloat = 16

    var body: some View {
        let height = 7 * cellSize + 6 * gap
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { g in
                let weeks = max(4, min(maxWeeks, Int((g.size.width - labelWidth + gap) / (cellSize + gap))))
                let today = Date().startOfDay
                let gridStart = Analytics.startOfWeek(today).adding(days: -(weeks - 1) * 7).startOfDay

                Canvas { ctx, _ in
                    let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
                    for row in [0, 2, 4] {
                        let label = ctx.resolve(Text(verbatim: symbols[(row + 1) % 7])
                            .font(.system(size: 9, weight: .medium)).foregroundStyle(.tertiary))
                        ctx.draw(label, at: CGPoint(x: 0, y: CGFloat(row) * (cellSize + gap) + cellSize / 2), anchor: .leading)
                    }
                    for week in 0..<weeks {
                        for row in 0..<7 {
                            let d = gridStart.adding(days: week * 7 + row).startOfDay
                            guard d <= today else { continue }
                            let rect = CGRect(x: labelWidth + CGFloat(week) * (cellSize + gap),
                                              y: CGFloat(row) * (cellSize + gap), width: cellSize, height: cellSize)
                            let level = levels[d] ?? 0
                            let shading: GraphicsContext.Shading = level > 0
                                ? .color(color.opacity(0.3 + 0.7 * level))
                                : .color(Theme.cardMuted)
                            ctx.fill(Path(roundedRect: rect, cornerRadius: cellSize * 0.28), with: shading)
                            if d == hovered {
                                ctx.stroke(Path(roundedRect: rect.insetBy(dx: -1, dy: -1), cornerRadius: cellSize * 0.32),
                                           with: .color(.primary.opacity(0.6)), lineWidth: 1.2)
                            }
                        }
                    }
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let p):
                        let week = Int((p.x - labelWidth) / (cellSize + gap))
                        let row = Int(p.y / (cellSize + gap))
                        guard p.x >= labelWidth, (0..<weeks).contains(week), (0..<7).contains(row) else {
                            hovered = nil
                            return
                        }
                        let d = gridStart.adding(days: week * 7 + row).startOfDay
                        hovered = d <= today ? d : nil
                    case .ended:
                        hovered = nil
                    }
                }
            }
            .frame(height: height)

            Text(verbatim: caption)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .opacity(hovered == nil ? 0 : 1)
        }
    }

    private var caption: String {
        guard let d = hovered else { return " " }
        let date = d.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        let level = levels[d] ?? 0
        return "\(date) · \(Int((level * 100).rounded()))%"
    }
}

private struct HeatmapLegend: View {
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text("Less").font(.caption2).foregroundStyle(.secondary)
            ForEach([0.0, 0.34, 0.67, 1.0], id: \.self) { level in
                RoundedRectangle(cornerRadius: 3)
                    .fill(level == 0 ? Theme.cardMuted : color.opacity(0.3 + 0.7 * level))
                    .frame(width: 10, height: 10)
            }
            Text("More").font(.caption2).foregroundStyle(.secondary)
        }
    }
}
