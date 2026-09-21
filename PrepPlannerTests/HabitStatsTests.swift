import XCTest
import SwiftData
@testable import PrepPlanner

/// Habit streaks and the heatmap levels.
///
/// Streak arithmetic is where off-by-one errors hide: a streak that counts one day too
/// many looks exactly as plausible as a correct one.
@MainActor
final class HabitStatsTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    /// A fixed day so the tests do not drift with the clock.
    private let today = Date(timeIntervalSince1970: 1_780_000_000).startOfDay

    override func setUpWithError() throws {
        let config = ModelConfiguration(schema: Persistence.schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Persistence.schema, configurations: [config])
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
    }

    /// A habit checked on each of `daysBack` (0 is the fixed today).
    @discardableResult
    private func makeHabit(_ name: String = "Habit", checked daysBack: [Int]) -> Habit {
        let habit = Habit(name: name, emoji: "✅", order: 0)
        context.insert(habit)
        for back in daysBack {
            let check = HabitCheck(day: today.adding(days: -back))
            context.insert(check)
            check.habit = habit
        }
        return habit
    }

    private func stats(_ habit: Habit) -> HabitStats {
        HabitStats(habit: habit, today: today)
    }

    // MARK: Current streak

    func testCurrentStreakCountsBackFromToday() {
        XCTAssertEqual(stats(makeHabit(checked: [0, 1, 2])).current, 3)
    }

    func testCurrentStreakSurvivesTodayNotBeingCheckedYet() {
        // The day is not over, so a run ending yesterday is still the current streak.
        XCTAssertEqual(stats(makeHabit(checked: [1, 2, 3])).current, 3)
    }

    func testCurrentStreakIsZeroOnceTwoDaysAreMissed() {
        XCTAssertEqual(stats(makeHabit(checked: [2, 3, 4])).current, 0)
    }

    func testCurrentStreakStopsAtTheFirstGap() {
        // Checked today and yesterday, then a missed day, then more history.
        XCTAssertEqual(stats(makeHabit(checked: [0, 1, 3, 4, 5])).current, 2)
    }

    func testCurrentStreakOfOne() {
        XCTAssertEqual(stats(makeHabit(checked: [0])).current, 1)
        XCTAssertEqual(stats(makeHabit(checked: [1])).current, 1, "yesterday alone still counts")
    }

    func testHabitWithNoChecks() {
        let s = stats(makeHabit(checked: []))
        XCTAssertEqual(s.current, 0)
        XCTAssertEqual(s.best, 0)
        XCTAssertEqual(s.lastSixty, 0)
    }

    // MARK: Best streak

    func testBestStreakFindsTheLongestRun() {
        // Runs of 2, then 4, then 1.
        XCTAssertEqual(stats(makeHabit(checked: [0, 1, 5, 6, 7, 8, 12])).best, 4)
    }

    func testBestStreakIsOneWhenNoDaysAdjoin() {
        XCTAssertEqual(stats(makeHabit(checked: [0, 5, 10])).best, 1)
    }

    func testBestStreakIncludesARunStillInProgress() {
        let s = stats(makeHabit(checked: [0, 1, 2, 3, 7, 8]))
        XCTAssertEqual(s.current, 4)
        XCTAssertEqual(s.best, 4, "the run ending today is also the best one")
    }

    func testBestStreakDoesNotDependOnInsertionOrder() {
        let shuffled = stats(makeHabit(checked: [7, 2, 8, 1, 0, 12, 6, 5]))
        XCTAssertEqual(shuffled.best, 4, "days are sorted before the run is measured")
        XCTAssertEqual(shuffled.current, 3)
    }

    func testDuplicateChecksOnOneDayDoNotInflateAStreak() {
        let habit = makeHabit(checked: [0, 0, 1])
        let s = stats(habit)
        XCTAssertEqual(s.current, 2, "the same day checked twice is still one day")
        XCTAssertEqual(s.best, 2)
    }

    // MARK: Sixty-day window

    func testLastSixtyCountsAnInclusiveWindow() {
        // Day 59 back is the oldest day inside a 60-day window; day 60 is outside it.
        let s = stats(makeHabit(checked: [0, 59, 60]))
        XCTAssertEqual(s.lastSixty, 2, "today and day 59 are inside, day 60 is not")
    }

    func testLastSixtyIgnoresDaysInTheFuture() {
        let s = stats(makeHabit(checked: [-1, 0]))
        XCTAssertEqual(s.lastSixty, 1, "a day after today does not count toward the window")
    }

    func testLastSixtyCountsEveryDayInAFullWindow() {
        let s = stats(makeHabit(checked: Array(0...59)))
        XCTAssertEqual(s.lastSixty, 60)
        XCTAssertEqual(s.current, 60)
    }

    // MARK: Heatmap levels

    func testDailyLevelsIsTheShareOfHabitsChecked() {
        let a = makeHabit("A", checked: [0, 1])
        let b = makeHabit("B", checked: [0])
        let levels = HabitStats.dailyLevels(habits: [a, b])

        XCTAssertEqual(levels[today] ?? 0, 1.0, accuracy: 0.0001, "both habits done today")
        XCTAssertEqual(levels[today.adding(days: -1)] ?? 0, 0.5, accuracy: 0.0001, "one of two")
        XCTAssertNil(levels[today.adding(days: -2)], "a day with no checks has no entry")
    }

    func testDailyLevelsWithNoHabits() {
        XCTAssertTrue(HabitStats.dailyLevels(habits: []).isEmpty)
    }

    func testDailyLevelsNeverExceedsOne() {
        let a = makeHabit("A", checked: [0])
        let levels = HabitStats.dailyLevels(habits: [a])
        XCTAssertEqual(levels[today] ?? 0, 1.0, accuracy: 0.0001)
    }

    /// A day is "fully done" only when every habit was checked. One habit checked twice
    /// must not stand in for a habit that was never checked at all.
    func testDuplicateChecksDoNotFakeAPerfectDay() {
        let a = makeHabit("A", checked: [0, 0])
        let b = makeHabit("B", checked: [])
        let levels = HabitStats.dailyLevels(habits: [a, b])
        XCTAssertEqual(levels[today] ?? 0, 0.5, accuracy: 0.0001,
                       "one of two habits was done, however many rows say so")
    }
}
