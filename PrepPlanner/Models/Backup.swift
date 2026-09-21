import Foundation
import SwiftData

/// Full JSON backup of everything PrepPlanner stores. Relationships are saved as uid references.
struct Backup: Codable {
    static let currentVersion = 1

    var version: Int
    var exportedAt: Date
    var settings: SettingsDTO?
    var categories: [CategoryDTO]
    var blocks: [BlockDTO]
    var templates: [TemplateDTO]
    var habits: [HabitDTO]
    var ieltsMocks: [IELTSDTO]
    var satMocks: [SATDTO]
    var errorTypes: [ErrorTypeDTO]
    var errors: [ErrorDTO]

    struct SettingsDTO: Codable {
        var ieltsDate: Date
        var satDate: Date
        var targetListening: Double
        var targetReading: Double
        var targetWriting: Double
        var targetSpeaking: Double
        var targetSAT: Int
        var notificationsEnabled: Bool
        var notificationLeadMinutes: Int
    }

    struct CategoryDTO: Codable {
        var uid: UUID
        var name: String
        var colorHex: String
        var order: Int
        var skill: String?
        var isStudy: Bool
    }

    struct BlockDTO: Codable {
        var uid: UUID
        var day: Date
        var startMin: Int
        var endMin: Int
        var title: String
        var note: String
        var status: String
        var actualMinutes: Int?
        var createdAt: Date
        var categoryID: UUID?
    }

    struct TemplateDTO: Codable {
        var uid: UUID
        var name: String
        var createdAt: Date
        var blocks: [TemplateBlockDTO]
    }

    struct TemplateBlockDTO: Codable {
        var uid: UUID
        var startMin: Int
        var endMin: Int
        var title: String
        var note: String
        var categoryID: UUID?
    }

    struct HabitDTO: Codable {
        var uid: UUID
        var name: String
        var emoji: String
        var order: Int
        var createdAt: Date
        var isArchived: Bool
        var checkedDays: [Date]
    }

    struct IELTSDTO: Codable {
        var uid: UUID
        var date: Date
        var listeningRaw: Int
        var readingRaw: Int
        var writingBand: Double
        var speakingBand: Double
        var writingTR: Double?
        var writingCC: Double?
        var writingLR: Double?
        var writingGRA: Double?
        var speakingFC: Double?
        var speakingLR: Double?
        var speakingGRA: Double?
        var speakingP: Double?
        var note: String
    }

    struct SATDTO: Codable {
        var uid: UUID
        var date: Date
        var readingWriting: Int
        var math: Int
        var note: String
    }

    struct ErrorTypeDTO: Codable {
        var uid: UUID
        var name: String
        var skill: String
        var order: Int
    }

    struct ErrorDTO: Codable {
        var uid: UUID
        var date: Date
        var skill: String
        var note: String
        var errorTypeID: UUID?
        var ieltsMockID: UUID?
        var satMockID: UUID?
    }
}

// MARK: - Snapshot and restore

extension Backup {
    @MainActor
    init(context: ModelContext) throws {
        func all<T: PersistentModel>(_ type: T.Type) throws -> [T] { try context.fetch(FetchDescriptor<T>()) }

        version = Self.currentVersion
        exportedAt = Date()
        settings = try all(AppSettings.self).first.map {
            SettingsDTO(ieltsDate: $0.ieltsDate, satDate: $0.satDate,
                        targetListening: $0.targetListening, targetReading: $0.targetReading,
                        targetWriting: $0.targetWriting, targetSpeaking: $0.targetSpeaking,
                        targetSAT: $0.targetSAT, notificationsEnabled: $0.notificationsEnabled,
                        notificationLeadMinutes: $0.notificationLeadMinutes)
        }
        categories = try all(StudyCategory.self).sorted { ($0.order, $0.uid.uuidString) < ($1.order, $1.uid.uuidString) }.map {
            CategoryDTO(uid: $0.uid, name: $0.name, colorHex: $0.colorHex, order: $0.order,
                        skill: $0.skillRaw, isStudy: $0.isStudy)
        }
        blocks = try all(TimeBlock.self).sorted { ($0.day, $0.startMin, $0.uid.uuidString) < ($1.day, $1.startMin, $1.uid.uuidString) }.map {
            BlockDTO(uid: $0.uid, day: $0.day, startMin: $0.startMin, endMin: $0.endMin, title: $0.title,
                     note: $0.note, status: $0.statusRaw, actualMinutes: $0.actualMinutes,
                     createdAt: $0.createdAt, categoryID: $0.category?.uid)
        }
        templates = try all(DayTemplate.self).sorted { ($0.name, $0.uid.uuidString) < ($1.name, $1.uid.uuidString) }.map { t in
            TemplateDTO(uid: t.uid, name: t.name, createdAt: t.createdAt, blocks: t.sortedBlocks.map {
                TemplateBlockDTO(uid: $0.uid, startMin: $0.startMin, endMin: $0.endMin, title: $0.title,
                                 note: $0.note, categoryID: $0.category?.uid)
            })
        }
        habits = try all(Habit.self).sorted { ($0.order, $0.uid.uuidString) < ($1.order, $1.uid.uuidString) }.map {
            HabitDTO(uid: $0.uid, name: $0.name, emoji: $0.emoji, order: $0.order, createdAt: $0.createdAt,
                     isArchived: $0.isArchived, checkedDays: Array(Set($0.checks.map(\.day))).sorted())
        }
        ieltsMocks = try all(IELTSMock.self).sorted { ($0.date, $0.uid.uuidString) < ($1.date, $1.uid.uuidString) }.map {
            IELTSDTO(uid: $0.uid, date: $0.date, listeningRaw: $0.listeningRaw, readingRaw: $0.readingRaw,
                     writingBand: $0.writingBand, speakingBand: $0.speakingBand,
                     writingTR: $0.writingTR, writingCC: $0.writingCC, writingLR: $0.writingLR, writingGRA: $0.writingGRA,
                     speakingFC: $0.speakingFC, speakingLR: $0.speakingLR, speakingGRA: $0.speakingGRA, speakingP: $0.speakingP,
                     note: $0.note)
        }
        satMocks = try all(SATMock.self).sorted { ($0.date, $0.uid.uuidString) < ($1.date, $1.uid.uuidString) }.map {
            SATDTO(uid: $0.uid, date: $0.date, readingWriting: $0.readingWriting, math: $0.math, note: $0.note)
        }
        errorTypes = try all(ErrorType.self).sorted { ($0.skillRaw, $0.order, $0.uid.uuidString) < ($1.skillRaw, $1.order, $1.uid.uuidString) }.map {
            ErrorTypeDTO(uid: $0.uid, name: $0.name, skill: $0.skillRaw, order: $0.order)
        }
        errors = try all(ErrorEntry.self).sorted { ($0.date, $0.uid.uuidString) < ($1.date, $1.uid.uuidString) }.map {
            ErrorDTO(uid: $0.uid, date: $0.date, skill: $0.skillRaw, note: $0.note, errorTypeID: $0.errorType?.uid,
                     ieltsMockID: $0.ieltsMock?.uid, satMockID: $0.satMock?.uid)
        }
    }

    /// Deletes all existing data and replaces it with this backup.
    @MainActor
    func restore(into context: ModelContext) throws {
        func wipe<T: PersistentModel>(_ type: T.Type) throws {
            for item in try context.fetch(FetchDescriptor<T>()) { context.delete(item) }
        }
        try wipe(ErrorEntry.self)
        try wipe(ErrorType.self)
        try wipe(IELTSMock.self)
        try wipe(SATMock.self)
        try wipe(HabitCheck.self)
        try wipe(Habit.self)
        try wipe(TemplateBlock.self)
        try wipe(DayTemplate.self)
        try wipe(TimeBlock.self)
        try wipe(StudyCategory.self)
        try wipe(AppSettings.self)
        try context.save()

        if let s = settings {
            let model = AppSettings(ieltsDate: s.ieltsDate, satDate: s.satDate)
            context.insert(model)
            model.targetListening = s.targetListening
            model.targetReading = s.targetReading
            model.targetWriting = s.targetWriting
            model.targetSpeaking = s.targetSpeaking
            model.targetSAT = s.targetSAT
            model.notificationsEnabled = s.notificationsEnabled
            model.notificationLeadMinutes = s.notificationLeadMinutes
        }

        var categoryByID: [UUID: StudyCategory] = [:]
        for c in categories {
            let model = StudyCategory(name: c.name, colorHex: c.colorHex, order: c.order,
                                      skill: c.skill.flatMap(Skill.init(rawValue:)), isStudy: c.isStudy)
            model.uid = c.uid
            context.insert(model)
            categoryByID[c.uid] = model
        }

        for b in blocks {
            let model = TimeBlock(day: b.day, startMin: b.startMin, endMin: b.endMin, title: b.title, note: b.note)
            model.uid = b.uid
            model.statusRaw = b.status
            model.actualMinutes = b.actualMinutes
            model.createdAt = b.createdAt
            context.insert(model)
            model.category = b.categoryID.flatMap { categoryByID[$0] }
        }

        for t in templates {
            let template = DayTemplate(name: t.name)
            template.uid = t.uid
            template.createdAt = t.createdAt
            context.insert(template)
            for tb in t.blocks {
                let model = TemplateBlock(startMin: tb.startMin, endMin: tb.endMin, title: tb.title, note: tb.note)
                model.uid = tb.uid
                context.insert(model)
                model.category = tb.categoryID.flatMap { categoryByID[$0] }
                model.template = template
            }
        }

        for h in habits {
            let habit = Habit(name: h.name, emoji: h.emoji, order: h.order)
            habit.uid = h.uid
            habit.createdAt = h.createdAt
            habit.isArchived = h.isArchived
            context.insert(habit)
            // A hand-edited or older file can repeat a day; one row per habit-day.
            for day in Array(Set(h.checkedDays)).sorted() {
                let check = HabitCheck(day: day)
                context.insert(check)
                check.habit = habit
            }
        }

        var ieltsByID: [UUID: IELTSMock] = [:]
        for m in ieltsMocks {
            let model = IELTSMock(date: m.date)
            model.uid = m.uid
            context.insert(model)
            model.listeningRaw = m.listeningRaw
            model.readingRaw = m.readingRaw
            model.writingBand = m.writingBand
            model.speakingBand = m.speakingBand
            (model.writingTR, model.writingCC, model.writingLR, model.writingGRA) = (m.writingTR, m.writingCC, m.writingLR, m.writingGRA)
            (model.speakingFC, model.speakingLR, model.speakingGRA, model.speakingP) = (m.speakingFC, m.speakingLR, m.speakingGRA, m.speakingP)
            model.note = m.note
            ieltsByID[m.uid] = model
        }

        var satByID: [UUID: SATMock] = [:]
        for m in satMocks {
            let model = SATMock(date: m.date)
            model.uid = m.uid
            context.insert(model)
            model.readingWriting = m.readingWriting
            model.math = m.math
            model.note = m.note
            satByID[m.uid] = model
        }

        var typeByID: [UUID: ErrorType] = [:]
        for t in errorTypes {
            let model = ErrorType(name: t.name, skill: Skill(rawValue: t.skill) ?? .reading, order: t.order)
            model.uid = t.uid
            context.insert(model)
            typeByID[t.uid] = model
        }

        for e in errors {
            let model = ErrorEntry(date: e.date, skill: Skill(rawValue: e.skill) ?? .reading, note: e.note)
            model.uid = e.uid
            context.insert(model)
            model.errorType = e.errorTypeID.flatMap { typeByID[$0] }
            model.ieltsMock = e.ieltsMockID.flatMap { ieltsByID[$0] }
            model.satMock = e.satMockID.flatMap { satByID[$0] }
        }

        try context.save()
    }

    // MARK: Coding

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> Backup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Backup.self, from: data)
    }
}

// MARK: - CSV

enum CSVExport {
    static func ielts(_ mocks: [IELTSMock]) -> String {
        let header = ["Date", "Listening raw", "Listening band", "Reading raw", "Reading band", "Writing band",
                      "Speaking band", "Overall band", "Writing TR", "Writing CC", "Writing LR", "Writing GRA",
                      "Speaking FC", "Speaking LR", "Speaking GRA", "Speaking P", "Errors", "Note"]
        let rows = mocks.sorted { $0.date < $1.date }.map { m -> [String] in
            [day(m.date), "\(m.listeningRaw)", Band.format(m.listeningBand), "\(m.readingRaw)", Band.format(m.readingBand),
             Band.format(m.writingBand), Band.format(m.speakingBand), Band.format(m.overallBand)]
                + (m.writingCriteria + m.speakingCriteria).map { $0.map(Band.format) ?? "" }
                + ["\(m.errors.count)", m.note]
        }
        return document(header, rows)
    }

    static func sat(_ mocks: [SATMock]) -> String {
        let header = ["Date", "Reading and Writing", "Math", "Total", "Errors", "Note"]
        let rows = mocks.sorted { $0.date < $1.date }.map {
            [day($0.date), "\($0.readingWriting)", "\($0.math)", "\($0.total)", "\($0.errors.count)", $0.note]
        }
        return document(header, rows)
    }

    static func errors(_ entries: [ErrorEntry]) -> String {
        let header = ["Date", "Skill", "Error type", "Note", "Mock"]
        let rows = entries.sorted { $0.date < $1.date }.map {
            [day($0.date), $0.skill.title, $0.errorType?.name ?? "", $0.note, $0.mockLabel ?? ""]
        }
        return document(header, rows)
    }

    /// UTF-8 with a byte order mark so Excel shows Uzbek letters correctly.
    private static func document(_ header: [String], _ rows: [[String]]) -> String {
        "\u{FEFF}" + ([header] + rows).map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func day(_ date: Date) -> String { dayFormatter.string(from: date) }
}
