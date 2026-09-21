import XCTest
import SwiftData
@testable import PrepPlanner

/// The aggregations behind the Analytics screen.
///
/// Every number here is a summary: if a block lands in the wrong bucket or a rate is
/// averaged the wrong way, the chart still draws and nothing looks wrong.
@MainActor
final class AnalyticsTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    /// A fixed Monday, so week bucketing can be asserted against a known weekday.
    private let monday = Date(timeIntervalSince1970: 1_789_948_800).startOfDay

    override func setUpWithError() throws {
        let config = ModelConfiguration(schema: Persistence.schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Persistence.schema, configurations: [config])
        context = container.mainContext

        // Guard the fixture itself: the rest of the file depends on this being a Monday.
        let weekday = Analytics.calendar.component(.weekday, from: monday)
        XCTAssertEqual(weekday, 2, "the fixed reference date must be a Monday")
    }

    override func tearDown() {
        container = nil
        context = nil
    }

    // MARK: Fixture helpers

    private func category(_ name: String, isStudy: Bool = true) -> StudyCategory {
        let c = StudyCategory(name: name, colorHex: "#F4852B", order: 0, skill: nil, isStudy: isStudy)
        context.insert(c)
        return c
    }

    @discardableResult
    private func block(
        day: Date,
        minutes: Int,
        category: StudyCategory? = nil,
        status: BlockStatus = .planned,
        actual: Int? = nil
    ) -> TimeBlock {
        let b = TimeBlock(day: day, startMin: 9 * 60, endMin: 9 * 60 + minutes, title: "Block")
        context.insert(b)
        b.category = category
        b.status = status
        b.actualMinutes = actual
        return b
    }

    // MARK: Weeks

    func testWeeksStartOnMonday() {
        XCTAssertEqual(Analytics.startOfWeek(monday), monday, "a Monday is its own week start")
        XCTAssertEqual(Analytics.startOfWeek(monday.adding(days: 3)), monday, "a Thursday belongs to that Monday")
        XCTAssertEqual(Analytics.startOfWeek(monday.adding(days: 6)), monday,
                       "Sunday closes the week rather than opening a new one")
        XCTAssertEqual(Analytics.startOfWeek(monday.adding(days: 7)), monday.adding(days: 7),
                       "the next Monday starts the next week")
        XCTAssertEqual(Analytics.startOfWeek(monday.adding(days: -1)), monday.adding(days: -7),
                       "the Sunday before belongs to the previous week")
    }

    // MARK: Periods

    func testDailyPeriodsEndWithToday() {
        let days = Analytics.periods(.day, count: 5, now: monday)
        XCTAssertEqual(days.count, 5)
        XCTAssertEqual(days.first, monday.adding(days: -4), "oldest first")
        XCTAssertEqual(days.last, monday, "the last period is the one containing now")
        XCTAssertEqual(days, days.sorted(), "periods come back in order")
    }

    func testWeeklyPeriodsStepBackAWeekAtATime() {
        let weeks = Analytics.periods(.week, count: 3, now: monday.adding(days: 2))
        XCTAssertEqual(weeks, [monday.adding(days: -14), monday.adding(days: -7), monday],
                       "a midweek 'now' still lands on its Monday")
    }

    func testSinglePeriod() {
        XCTAssertEqual(Analytics.periods(.day, count: 1, now: monday), [monday])
    }

    // MARK: Hours

    func testHoursSplitPlannedFromActual() {
        let writing = category("Writing")
        block(day: monday, minutes: 60, category: writing, status: .done)
        block(day: monday, minutes: 60, category: writing, status: .planned)

        let rows = Analytics.hours(blocks: try! context.fetch(FetchDescriptor<TimeBlock>()),
                                   granularity: .day, periods: [monday])

        let planned = rows.first { $0.kind == .planned }
        let actual = rows.first { $0.kind == .actual }
        XCTAssertEqual(planned?.hours ?? 0, 2.0, accuracy: 0.0001, "both blocks were planned")
        XCTAssertEqual(actual?.hours ?? 0, 1.0, accuracy: 0.0001, "only the finished one counts as actual")
    }

    func testHoursKeepCategoriesApart() {
        let writing = category("Writing")
        let reading = category("Reading")
        block(day: monday, minutes: 90, category: writing, status: .done)
        block(day: monday, minutes: 30, category: reading, status: .done)

        let rows = Analytics.hours(blocks: try! context.fetch(FetchDescriptor<TimeBlock>()),
                                   granularity: .day, periods: [monday])
            .filter { $0.kind == .actual }

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.first { $0.category == "Writing" }?.hours ?? 0, 1.5, accuracy: 0.0001)
        XCTAssertEqual(rows.first { $0.category == "Reading" }?.hours ?? 0, 0.5, accuracy: 0.0001)
    }

    func testHoursExcludeNonStudyCategories() {
        let rest = category("Rest", isStudy: false)
        block(day: monday, minutes: 60, category: rest, status: .done)

        let rows = Analytics.hours(blocks: try! context.fetch(FetchDescriptor<TimeBlock>()),
                                   granularity: .day, periods: [monday])
        XCTAssertTrue(rows.isEmpty, "a rest block is not study time")
    }

    func testBlocksWithNoCategoryStillCount() {
        block(day: monday, minutes: 60, category: nil, status: .done)
        let rows = Analytics.hours(blocks: try! context.fetch(FetchDescriptor<TimeBlock>()),
                                   granularity: .day, periods: [monday])
        XCTAssertEqual(rows.filter { $0.kind == .actual }.count, 1,
                       "an uncategorised block defaults to study and is counted")
    }

    func testHoursIgnoreBlocksOutsideTheRequestedPeriods() {
        let writing = category("Writing")
        block(day: monday, minutes: 60, category: writing, status: .done)
        block(day: monday.adding(days: -1), minutes: 60, category: writing, status: .done)

        let rows = Analytics.hours(blocks: try! context.fetch(FetchDescriptor<TimeBlock>()),
                                   granularity: .day, periods: [monday])
        XCTAssertEqual(rows.filter { $0.kind == .actual }.first?.hours ?? 0, 1.0, accuracy: 0.0001,
                       "yesterday is not in the window")
    }

    func testWeeklyBucketingSumsTheWholeWeek() {
        let writing = category("Writing")
        for offset in 0...6 {
            block(day: monday.adding(days: offset), minutes: 60, category: writing, status: .done)
        }

        let rows = Analytics.hours(blocks: try! context.fetch(FetchDescriptor<TimeBlock>()),
                                   granularity: .week, periods: [monday])
            .filter { $0.kind == .actual }

        XCTAssertEqual(rows.count, 1, "one row per category per week")
        XCTAssertEqual(rows.first?.hours ?? 0, 7.0, accuracy: 0.0001, "Monday through Sunday land in one bucket")
    }

    func testNoRowIsEmittedForZeroMinutes() {
        let writing = category("Writing")
        block(day: monday, minutes: 60, category: writing, status: .planned)

        let rows = Analytics.hours(blocks: try! context.fetch(FetchDescriptor<TimeBlock>()),
                                   granularity: .day, periods: [monday])
        XCTAssertEqual(rows.filter { $0.kind == .planned }.count, 1)
        XCTAssertTrue(rows.filter { $0.kind == .actual }.isEmpty, "an unstudied day draws no actual bar")
    }

    func testSkippedBlockCountsAsPlannedButNotActual() {
        let writing = category("Writing")
        block(day: monday, minutes: 60, category: writing, status: .skipped)

        let rows = Analytics.hours(blocks: try! context.fetch(FetchDescriptor<TimeBlock>()),
                                   granularity: .day, periods: [monday])
        XCTAssertEqual(rows.first { $0.kind == .planned }?.hours ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertTrue(rows.filter { $0.kind == .actual }.isEmpty)
    }

    // MARK: Completion

    func testCompletionRateWeighting() {
        let done = block(day: monday, minutes: 60, status: .done)
        let partial = block(day: monday, minutes: 60, status: .partial)
        let skipped = block(day: monday, minutes: 60, status: .skipped)

        XCTAssertEqual(Analytics.completionRate([done]) ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertEqual(Analytics.completionRate([partial]) ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(Analytics.completionRate([skipped]) ?? 0, 0.0, accuracy: 0.0001)
        XCTAssertEqual(Analytics.completionRate([done, skipped]) ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(Analytics.completionRate([done, partial, skipped]) ?? 0, 0.5, accuracy: 0.0001)
    }

    func testCompletionRateIgnoresUnmarkedBlocks() {
        let done = block(day: monday, minutes: 60, status: .done)
        let unmarked = block(day: monday, minutes: 60, status: .planned)

        XCTAssertEqual(Analytics.completionRate([done, unmarked]) ?? 0, 1.0, accuracy: 0.0001,
                       "an unmarked block does not drag the rate down")
        XCTAssertNil(Analytics.completionRate([unmarked]), "a day with nothing marked has no rate yet")
        XCTAssertNil(Analytics.completionRate([]), "no blocks means no rate, not zero")
    }

    func testCompletionSeriesCoversTheWindowAndIsOrdered() {
        block(day: monday, minutes: 60, status: .done)
        block(day: monday.adding(days: -1), minutes: 60, status: .skipped)
        block(day: monday.adding(days: -2), minutes: 60, status: .done)   // inside a 3-day window
        block(day: monday.adding(days: -3), minutes: 60, status: .done)   // outside it

        let points = Analytics.completion(blocks: try! context.fetch(FetchDescriptor<TimeBlock>()),
                                          days: 3, now: monday)

        XCTAssertEqual(points.count, 3, "three days in, the fourth left out")
        XCTAssertEqual(points.map(\.day), points.map(\.day).sorted(), "points are ordered oldest first")
        XCTAssertEqual(points.first?.day, monday.adding(days: -2))
        XCTAssertEqual(points.last?.rate ?? 0, 1.0, accuracy: 0.0001)
    }

    func testCompletionSeriesSkipsDaysWithNothingMarked() {
        block(day: monday, minutes: 60, status: .done)
        block(day: monday.adding(days: -1), minutes: 60, status: .planned)

        let points = Analytics.completion(blocks: try! context.fetch(FetchDescriptor<TimeBlock>()),
                                          days: 7, now: monday)
        XCTAssertEqual(points.count, 1, "a day with no marked blocks is absent, not plotted as zero")
        XCTAssertEqual(points.first?.marked, 1)
    }

    // MARK: Error counts

    private func errorEntry(_ note: String, skill: Skill, type: ErrorType?, day: Date) {
        let e = ErrorEntry(date: day, skill: skill, note: note)
        context.insert(e)
        e.errorType = type
    }

    func testErrorCountsRankByFrequencyThenName() {
        let matching = ErrorType(name: "Paragraph matching", skill: .reading, order: 0)
        let timing = ErrorType(name: "Ran out of time", skill: .reading, order: 1)
        let alpha = ErrorType(name: "Aaa tie", skill: .reading, order: 2)
        [matching, timing, alpha].forEach(context.insert)

        for index in 0..<3 { errorEntry("m\(index)", skill: .reading, type: matching, day: monday) }
        errorEntry("t0", skill: .reading, type: timing, day: monday)
        errorEntry("a0", skill: .reading, type: alpha, day: monday)

        let rows = Analytics.errorCounts(try! context.fetch(FetchDescriptor<ErrorEntry>()),
                                         skill: nil, since: nil, limit: 10)

        XCTAssertEqual(rows.map(\.name), ["Paragraph matching", "Aaa tie", "Ran out of time"],
                       "most frequent first, then alphabetical among ties")
        XCTAssertEqual(rows.first?.count, 3)
    }

    func testErrorCountsSkipUntypedEntries() {
        let type = ErrorType(name: "Typed", skill: .reading, order: 0)
        context.insert(type)
        errorEntry("typed", skill: .reading, type: type, day: monday)
        errorEntry("untyped", skill: .reading, type: nil, day: monday)

        let rows = Analytics.errorCounts(try! context.fetch(FetchDescriptor<ErrorEntry>()),
                                         skill: nil, since: nil, limit: 10)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.count, 1, "the untyped entry is not folded into the typed one")
    }

    func testErrorCountsFilterBySkill() {
        let reading = ErrorType(name: "Reading type", skill: .reading, order: 0)
        let writing = ErrorType(name: "Writing type", skill: .writing, order: 0)
        [reading, writing].forEach(context.insert)
        errorEntry("r", skill: .reading, type: reading, day: monday)
        errorEntry("w", skill: .writing, type: writing, day: monday)

        let rows = Analytics.errorCounts(try! context.fetch(FetchDescriptor<ErrorEntry>()),
                                         skill: .reading, since: nil, limit: 10)
        XCTAssertEqual(rows.map(\.name), ["Reading type"])
    }

    func testErrorCountsCutOffAtTheSinceDate() {
        let type = ErrorType(name: "Type", skill: .reading, order: 0)
        context.insert(type)
        errorEntry("on the boundary", skill: .reading, type: type, day: monday.adding(days: -6))
        errorEntry("before it", skill: .reading, type: type, day: monday.adding(days: -7))

        let rows = Analytics.errorCounts(try! context.fetch(FetchDescriptor<ErrorEntry>()),
                                         skill: nil, since: monday.adding(days: -6), limit: 10)
        XCTAssertEqual(rows.first?.count, 1, "the since date is inclusive, the day before is not")
    }

    func testErrorCountsRespectTheLimit() {
        for index in 0..<5 {
            let type = ErrorType(name: "Type \(index)", skill: .reading, order: index)
            context.insert(type)
            errorEntry("e\(index)", skill: .reading, type: type, day: monday)
        }

        XCTAssertEqual(Analytics.errorCounts(try! context.fetch(FetchDescriptor<ErrorEntry>()),
                                             skill: nil, since: nil, limit: 3).count, 3)
        XCTAssertTrue(Analytics.errorCounts(try! context.fetch(FetchDescriptor<ErrorEntry>()),
                                            skill: nil, since: nil, limit: 0).isEmpty)
    }

    func testErrorCountsWithNothingLogged() {
        XCTAssertTrue(Analytics.errorCounts([], skill: nil, since: nil, limit: 6).isEmpty)
    }
}
