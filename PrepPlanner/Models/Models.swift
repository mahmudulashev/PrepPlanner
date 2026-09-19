import Foundation
import SwiftData

// MARK: - Planner

@Model
final class StudyCategory {
    var uid: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#8E8E93"
    var order: Int = 0
    var skillRaw: String? = nil
    /// Rest-type categories are excluded from study-hour totals.
    var isStudy: Bool = true

    @Relationship(deleteRule: .nullify, inverse: \TimeBlock.category)
    var blocks: [TimeBlock] = []

    @Relationship(deleteRule: .nullify, inverse: \TemplateBlock.category)
    var templateBlocks: [TemplateBlock] = []

    init(name: String, colorHex: String, order: Int, skill: Skill? = nil, isStudy: Bool = true) {
        self.name = name
        self.colorHex = colorHex
        self.order = order
        self.skillRaw = skill?.rawValue
        self.isStudy = isStudy
    }

    var skill: Skill? {
        get { skillRaw.flatMap(Skill.init(rawValue:)) }
        set { skillRaw = newValue?.rawValue }
    }
}

@Model
final class TimeBlock {
    var uid: UUID = UUID()
    /// Start of the calendar day this block belongs to.
    var day: Date = Date.distantPast
    /// Minutes from midnight, multiples of 15, within 06:00–24:00.
    var startMin: Int = 480
    var endMin: Int = 540
    var title: String = ""
    var note: String = ""
    var statusRaw: String = BlockStatus.planned.rawValue
    var actualMinutes: Int? = nil
    var createdAt: Date = Date()
    var category: StudyCategory?

    init(day: Date, startMin: Int, endMin: Int, title: String, note: String = "") {
        self.day = day
        self.startMin = startMin
        self.endMin = endMin
        self.title = title
        self.note = note
    }

    var status: BlockStatus {
        get { BlockStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }

    var plannedMinutes: Int { endMin - startMin }

    /// Minutes actually studied. Planned blocks count as 0 until reviewed.
    var effectiveActual: Int {
        switch status {
        case .planned: 0
        case .skipped: actualMinutes ?? 0
        case .done, .partial: actualMinutes ?? plannedMinutes
        }
    }

    var startDate: Date { Calendar.current.date(byAdding: .minute, value: startMin, to: day) ?? day }
    var endDate: Date { Calendar.current.date(byAdding: .minute, value: endMin, to: day) ?? day }

    /// Finished in the past but not yet marked.
    var needsReview: Bool { status == .planned && endDate < Date() }

    var isStudy: Bool { category?.isStudy ?? true }

    /// Sets the status and pre-fills actual minutes with a sensible default.
    func setStatus(_ newStatus: BlockStatus) {
        status = newStatus
        switch newStatus {
        case .planned: actualMinutes = nil
        case .done: actualMinutes = plannedMinutes
        case .partial: actualMinutes = Int((Double(plannedMinutes) / 2 / 5).rounded()) * 5
        case .skipped: actualMinutes = 0
        }
    }
}

@Model
final class DayTemplate {
    var uid: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \TemplateBlock.template)
    var blocks: [TemplateBlock] = []

    init(name: String) {
        self.name = name
    }

    var sortedBlocks: [TemplateBlock] { blocks.sorted { $0.startMin < $1.startMin } }
    var totalMinutes: Int { blocks.reduce(0) { $0 + ($1.endMin - $1.startMin) } }
}

@Model
final class TemplateBlock {
    var uid: UUID = UUID()
    var startMin: Int = 480
    var endMin: Int = 540
    var title: String = ""
    var note: String = ""
    var category: StudyCategory?
    var template: DayTemplate?

    init(startMin: Int, endMin: Int, title: String, note: String = "") {
        self.startMin = startMin
        self.endMin = endMin
        self.title = title
        self.note = note
    }
}

// MARK: - Habits (UI in Phase 4)

@Model
final class Habit {
    var uid: UUID = UUID()
    var name: String = ""
    var emoji: String = "✅"
    var order: Int = 0
    var createdAt: Date = Date()
    var isArchived: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \HabitCheck.habit)
    var checks: [HabitCheck] = []

    init(name: String, emoji: String, order: Int) {
        self.name = name
        self.emoji = emoji
        self.order = order
    }
}

@Model
final class HabitCheck {
    var uid: UUID = UUID()
    var day: Date = Date.distantPast
    var habit: Habit?

    init(day: Date) {
        self.day = day
    }
}

// MARK: - Results & Error Log (UI in Phase 2)

@Model
final class IELTSMock {
    var uid: UUID = UUID()
    var date: Date = Date()
    var listeningRaw: Int = 0
    var readingRaw: Int = 0
    var writingBand: Double = 0
    var speakingBand: Double = 0
    var writingTR: Double? = nil
    var writingCC: Double? = nil
    var writingLR: Double? = nil
    var writingGRA: Double? = nil
    var speakingFC: Double? = nil
    var speakingLR: Double? = nil
    var speakingGRA: Double? = nil
    var speakingP: Double? = nil
    var note: String = ""

    @Relationship(deleteRule: .nullify, inverse: \ErrorEntry.ieltsMock)
    var errors: [ErrorEntry] = []

    init(date: Date) {
        self.date = date
    }
}

@Model
final class SATMock {
    var uid: UUID = UUID()
    var date: Date = Date()
    var readingWriting: Int = 200
    var math: Int = 200
    var note: String = ""

    @Relationship(deleteRule: .nullify, inverse: \ErrorEntry.satMock)
    var errors: [ErrorEntry] = []

    init(date: Date) {
        self.date = date
    }

    var total: Int { readingWriting + math }
}

@Model
final class ErrorType {
    var uid: UUID = UUID()
    var name: String = ""
    var skillRaw: String = Skill.reading.rawValue
    var order: Int = 0

    @Relationship(deleteRule: .nullify, inverse: \ErrorEntry.errorType)
    var entries: [ErrorEntry] = []

    init(name: String, skill: Skill, order: Int) {
        self.name = name
        self.skillRaw = skill.rawValue
        self.order = order
    }

    var skill: Skill { Skill(rawValue: skillRaw) ?? .reading }
}

@Model
final class ErrorEntry {
    var uid: UUID = UUID()
    var date: Date = Date()
    var skillRaw: String = Skill.reading.rawValue
    var note: String = ""
    var errorType: ErrorType?
    var ieltsMock: IELTSMock?
    var satMock: SATMock?

    init(date: Date, skill: Skill, note: String = "") {
        self.date = date
        self.skillRaw = skill.rawValue
        self.note = note
    }

    var skill: Skill { Skill(rawValue: skillRaw) ?? .reading }
}

// MARK: - Settings

@Model
final class AppSettings {
    var uid: UUID = UUID()
    var ieltsDate: Date = Date()
    var satDate: Date = Date()
    var targetListening: Double = 9
    var targetReading: Double = 9
    var targetWriting: Double = 6.5
    var targetSpeaking: Double = 6.5
    var targetSAT: Int = 1450
    var notificationsEnabled: Bool = true
    var notificationLeadMinutes: Int = 5

    init(ieltsDate: Date, satDate: Date) {
        self.ieltsDate = ieltsDate
        self.satDate = satDate
    }
}
