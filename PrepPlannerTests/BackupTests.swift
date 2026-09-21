import XCTest
import SwiftData
@testable import PrepPlanner

/// Backup export and restore.
///
/// Restore deletes everything before it writes, so a fault here does not degrade the
/// data — it replaces it. These tests populate a store with one of everything, send it
/// through JSON and back, and check that what comes out is what went in.
@MainActor
final class BackupTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try makeContainer()
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
    }

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: Persistence.schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: Persistence.schema, configurations: [config])
    }

    /// The same JSON a backup would be written as, with the timestamp neutralised so two
    /// exports of the same data compare equal.
    private func canonical(_ backup: Backup) throws -> String {
        var copy = backup
        copy.exportedAt = Date(timeIntervalSince1970: 0)
        return String(decoding: try copy.encoded(), as: UTF8.self)
    }

    private func count<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    // MARK: Fixture

    /// One of everything, with every relationship used at least once.
    private func populate(_ context: ModelContext) {
        let day = Date(timeIntervalSince1970: 1_780_000_000).startOfDay

        let settings = AppSettings(ieltsDate: day.adding(days: 30), satDate: day.adding(days: 47))
        settings.targetListening = 8.0
        settings.targetReading = 7.5
        settings.targetWriting = 7.0
        settings.targetSpeaking = 6.5
        settings.targetSAT = 1480
        settings.notificationsEnabled = true
        settings.notificationLeadMinutes = 15
        context.insert(settings)

        let writing = StudyCategory(name: "IELTS Writing", colorHex: "#F4852B", order: 0, skill: .writing, isStudy: true)
        let rest = StudyCategory(name: "Rest", colorHex: "#5BAA6E", order: 1, skill: nil, isStudy: false)
        context.insert(writing)
        context.insert(rest)

        let block = TimeBlock(day: day, startMin: 9 * 60, endMin: 10 * 60 + 30,
                              title: "Task 2, \"comma, quote\"", note: "A note\nwith a line break")
        block.statusRaw = BlockStatus.partial.rawValue
        block.actualMinutes = 45
        context.insert(block)
        block.category = writing

        let untyped = TimeBlock(day: day.adding(days: 1), startMin: 12 * 60, endMin: 13 * 60, title: "Lunch")
        context.insert(untyped)

        let template = DayTemplate(name: "Full day")
        context.insert(template)
        for (index, start) in [9 * 60, 14 * 60].enumerated() {
            let tb = TemplateBlock(startMin: start, endMin: start + 60, title: "Slot \(index)", note: "")
            context.insert(tb)
            tb.category = index == 0 ? writing : nil
            tb.template = template
        }

        let habit = Habit(name: "Wrote Task 2", emoji: "✍️", order: 0)
        context.insert(habit)
        for back in [0, 1, 3] {
            let check = HabitCheck(day: day.adding(days: -back))
            context.insert(check)
            check.habit = habit
        }
        let archived = Habit(name: "Old habit", emoji: "📒", order: 1)
        archived.isArchived = true
        context.insert(archived)

        let ielts = IELTSMock(date: day.adding(days: -3))
        ielts.listeningRaw = 36
        ielts.readingRaw = 34
        ielts.writingBand = 7.0
        ielts.speakingBand = 6.5
        ielts.writingTR = 6.5
        ielts.writingCC = 6.0
        ielts.speakingFC = 6.5
        ielts.note = "Tired"
        context.insert(ielts)

        let sat = SATMock(date: day.adding(days: -4))
        sat.readingWriting = 670
        sat.math = 710
        context.insert(sat)

        let type = ErrorType(name: "Paragraph matching", skill: .reading, order: 0)
        context.insert(type)

        let linkedToIELTS = ErrorEntry(date: day, skill: .reading, note: "Missed the paraphrase")
        context.insert(linkedToIELTS)
        linkedToIELTS.errorType = type
        linkedToIELTS.ieltsMock = ielts

        let linkedToSAT = ErrorEntry(date: day, skill: .satMath, note: "Sign slip")
        context.insert(linkedToSAT)
        linkedToSAT.satMock = sat

        let bare = ErrorEntry(date: day.adding(days: -1), skill: .writing, note: "")
        context.insert(bare)

        try? context.save()
    }

    // MARK: Round trip

    func testExportRestoreExportIsUnchanged() throws {
        populate(context)
        let first = try Backup(context: context)
        let json = try first.encoded()

        let restored = try makeContainer()
        try Backup.decode(json).restore(into: restored.mainContext)
        let second = try Backup(context: restored.mainContext)

        XCTAssertEqual(try canonical(first), try canonical(second),
                       "a full round trip should not change a single field")
    }

    func testRoundTripKeepsEveryRecord() throws {
        populate(context)
        let json = try Backup(context: context).encoded()

        let restored = try makeContainer()
        let target = restored.mainContext
        try Backup.decode(json).restore(into: target)

        XCTAssertEqual(try count(AppSettings.self, in: target), 1)
        XCTAssertEqual(try count(StudyCategory.self, in: target), 2)
        XCTAssertEqual(try count(TimeBlock.self, in: target), 2)
        XCTAssertEqual(try count(DayTemplate.self, in: target), 1)
        XCTAssertEqual(try count(TemplateBlock.self, in: target), 2)
        XCTAssertEqual(try count(Habit.self, in: target), 2)
        XCTAssertEqual(try count(HabitCheck.self, in: target), 3)
        XCTAssertEqual(try count(IELTSMock.self, in: target), 1)
        XCTAssertEqual(try count(SATMock.self, in: target), 1)
        XCTAssertEqual(try count(ErrorType.self, in: target), 1)
        XCTAssertEqual(try count(ErrorEntry.self, in: target), 3)
    }

    func testRoundTripRelinksRelationships() throws {
        populate(context)
        let json = try Backup(context: context).encoded()

        let restored = try makeContainer()
        let target = restored.mainContext
        try Backup.decode(json).restore(into: target)

        let blocks = try target.fetch(FetchDescriptor<TimeBlock>())
        let studyBlock = try XCTUnwrap(blocks.first { $0.title.hasPrefix("Task 2") })
        XCTAssertEqual(studyBlock.category?.name, "IELTS Writing", "a block keeps its category")
        XCTAssertNil(blocks.first { $0.title == "Lunch" }?.category, "a block with no category keeps none")

        let template = try XCTUnwrap(try target.fetch(FetchDescriptor<DayTemplate>()).first)
        XCTAssertEqual(template.sortedBlocks.count, 2)
        XCTAssertEqual(template.sortedBlocks.first?.category?.name, "IELTS Writing")
        XCTAssertNil(template.sortedBlocks.last?.category)

        let habit = try XCTUnwrap(try target.fetch(FetchDescriptor<Habit>()).first { !$0.isArchived })
        XCTAssertEqual(habit.checks.count, 3, "checks come back attached to their habit")

        let errors = try target.fetch(FetchDescriptor<ErrorEntry>())
        XCTAssertEqual(errors.first { $0.note == "Missed the paraphrase" }?.errorType?.name, "Paragraph matching")
        XCTAssertNotNil(errors.first { $0.note == "Missed the paraphrase" }?.ieltsMock, "the IELTS link survives")
        XCTAssertNotNil(errors.first { $0.note == "Sign slip" }?.satMock, "the SAT link survives")
        XCTAssertNil(errors.first { $0.note == "" }?.errorType, "an unlinked entry stays unlinked")
    }

    func testRoundTripKeepsFieldDetail() throws {
        populate(context)
        let json = try Backup(context: context).encoded()

        let restored = try makeContainer()
        let target = restored.mainContext
        try Backup.decode(json).restore(into: target)

        let settings = try XCTUnwrap(try target.fetch(FetchDescriptor<AppSettings>()).first)
        XCTAssertEqual(settings.targetListening, 8.0)
        XCTAssertEqual(settings.targetSAT, 1480)
        XCTAssertEqual(settings.notificationLeadMinutes, 15)
        XCTAssertTrue(settings.notificationsEnabled)

        let block = try XCTUnwrap(try target.fetch(FetchDescriptor<TimeBlock>()).first { $0.actualMinutes != nil })
        XCTAssertEqual(block.status, .partial, "a status other than the default survives")
        XCTAssertEqual(block.actualMinutes, 45)
        XCTAssertEqual(block.title, "Task 2, \"comma, quote\"", "quotes and commas survive JSON")
        XCTAssertEqual(block.note, "A note\nwith a line break", "so do line breaks")

        let ielts = try XCTUnwrap(try target.fetch(FetchDescriptor<IELTSMock>()).first)
        XCTAssertEqual(ielts.listeningRaw, 36)
        XCTAssertEqual(ielts.writingTR, 6.5, "a filled criterion survives")
        XCTAssertNil(ielts.writingLR, "an empty criterion stays empty rather than becoming zero")
        XCTAssertEqual(ielts.overallBand, Band.overall([8.0, 7.5, 7.0, 6.5]), "the derived band is unchanged")

        let archived = try XCTUnwrap(try target.fetch(FetchDescriptor<Habit>()).first { $0.isArchived })
        XCTAssertEqual(archived.name, "Old habit", "an archived habit is not dropped")
    }

    // MARK: Restore semantics

    func testRestoreReplacesWhateverWasThere() throws {
        populate(context)
        let json = try Backup(context: context).encoded()

        // A second store with different contents, including more records than the backup.
        let other = try makeContainer()
        let target = other.mainContext
        for index in 0..<5 {
            let block = TimeBlock(day: Date().startOfDay, startMin: index * 60, endMin: index * 60 + 30, title: "Old \(index)")
            target.insert(block)
        }
        let staleHabit = Habit(name: "Should be gone", emoji: "👻", order: 0)
        target.insert(staleHabit)
        try target.save()

        try Backup.decode(json).restore(into: target)

        XCTAssertEqual(try count(TimeBlock.self, in: target), 2, "old blocks are gone, not merged")
        XCTAssertNil(try target.fetch(FetchDescriptor<Habit>()).first { $0.name == "Should be gone" })
        XCTAssertEqual(try count(Habit.self, in: target), 2)
    }

    func testRestoringTwiceDoesNotDuplicate() throws {
        populate(context)
        let json = try Backup(context: context).encoded()

        let restored = try makeContainer()
        let target = restored.mainContext
        try Backup.decode(json).restore(into: target)
        try Backup.decode(json).restore(into: target)

        XCTAssertEqual(try count(TimeBlock.self, in: target), 2, "restore wipes first, so it is repeatable")
        XCTAssertEqual(try count(HabitCheck.self, in: target), 3)
        XCTAssertEqual(try count(ErrorEntry.self, in: target), 3)
    }

    func testRestoringAnEmptyBackupClearsTheStore() throws {
        populate(context)
        let empty = Backup(version: Backup.currentVersion, exportedAt: Date(), settings: nil,
                           categories: [], blocks: [], templates: [], habits: [],
                           ieltsMocks: [], satMocks: [], errorTypes: [], errors: [])
        try empty.restore(into: context)

        XCTAssertEqual(try count(TimeBlock.self, in: context), 0)
        XCTAssertEqual(try count(StudyCategory.self, in: context), 0)
        XCTAssertEqual(try count(AppSettings.self, in: context), 0)
    }

    /// A hand-edited or older file can repeat a day. Restoring it must not create two
    /// rows for one habit-day, which would misreport the heatmap.
    func testRestoreIgnoresRepeatedCheckedDays() throws {
        let day = Date(timeIntervalSince1970: 1_780_000_000).startOfDay
        let habit = Backup.HabitDTO(uid: UUID(), name: "Habit", emoji: "✅", order: 0,
                                    createdAt: day, isArchived: false,
                                    checkedDays: [day, day, day.adding(days: -1)])
        let backup = Backup(version: Backup.currentVersion, exportedAt: Date(), settings: nil,
                            categories: [], blocks: [], templates: [], habits: [habit],
                            ieltsMocks: [], satMocks: [], errorTypes: [], errors: [])
        try backup.restore(into: context)

        XCTAssertEqual(try count(HabitCheck.self, in: context), 2, "the repeated day is stored once")
    }

    // MARK: Encoding

    func testEncodingIsStable() throws {
        populate(context)
        let backup = try Backup(context: context)
        XCTAssertEqual(try backup.encoded(), try backup.encoded(),
                       "sorted keys make the file diffable between exports")
    }

    func testDecodeRejectsNonsense() {
        XCTAssertThrowsError(try Backup.decode(Data("not json".utf8)))
        XCTAssertThrowsError(try Backup.decode(Data("{}".utf8)), "a file missing every field is not a backup")
    }

    func testVersionIsCarried() throws {
        populate(context)
        let decoded = try Backup.decode(try Backup(context: context).encoded())
        XCTAssertEqual(decoded.version, Backup.currentVersion)
    }
}
