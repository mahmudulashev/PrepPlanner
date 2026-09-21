import Foundation

/// Streaks and recent history for one habit.
struct HabitStats {
    let checkedDays: Set<Date>
    /// Consecutive checked days ending today, or ending yesterday if today isn't checked yet.
    let current: Int
    let best: Int
    let lastSixty: Int

    init(habit: Habit, today: Date = Date()) {
        let days = Set(habit.checks.map(\.day.startOfDay))
        checkedDays = days

        var day = today.startOfDay
        if !days.contains(day) { day = day.adding(days: -1).startOfDay }
        var current = 0
        while days.contains(day) {
            current += 1
            day = day.adding(days: -1).startOfDay
        }
        self.current = current

        var best = 0, run = 0
        var previous: Date?
        for d in days.sorted() {
            run = previous.map { $0.adding(days: 1).startOfDay == d } == true ? run + 1 : 1
            best = max(best, run)
            previous = d
        }
        self.best = best

        let start = today.startOfDay.adding(days: -59)
        lastSixty = days.filter { $0 >= start && $0 <= today }.count
    }

    /// Share of active habits checked on each day (0…1).
    ///
    /// Each habit counts at most once per day. Counting check rows instead would let a
    /// habit with two rows for one day stand in for a habit that was never checked,
    /// which reads as a perfect day in the heatmap and in the perfect-day count.
    static func dailyLevels(habits: [Habit]) -> [Date: Double] {
        guard !habits.isEmpty else { return [:] }
        var checkedHabits: [Date: Set<UUID>] = [:]
        for h in habits {
            for c in h.checks { checkedHabits[c.day.startOfDay, default: []].insert(h.uid) }
        }
        return checkedHabits.mapValues { min(Double($0.count) / Double(habits.count), 1) }
    }
}
