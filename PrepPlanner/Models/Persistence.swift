import Foundation
import SwiftData

enum Persistence {
    static let schema = Schema([
        StudyCategory.self, TimeBlock.self, DayTemplate.self, TemplateBlock.self,
        Habit.self, HabitCheck.self,
        IELTSMock.self, SATMock.self, ErrorType.self, ErrorEntry.self,
        AppSettings.self,
    ])

    /// ~/Library/Application Support/PrepPlanner/PrepPlanner.store
    static var storeURL: URL {
        let dir = URL.applicationSupportDirectory.appending(path: "PrepPlanner", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "PrepPlanner.store")
    }

    @MainActor
    static func makeContainer() -> ModelContainer {
        do {
            let config = ModelConfiguration(schema: schema, url: storeURL)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not open the PrepPlanner database: \(error)")
        }
    }
}

@MainActor
enum Seeder {
    static func seedIfNeeded(_ context: ModelContext) {
        if count(StudyCategory.self, in: context) == 0 {
            let categories = seedCategories(context)
            seedTemplates(context, categories: categories)
        }
        if count(AppSettings.self, in: context) == 0 {
            context.insert(AppSettings(ieltsDate: date(2026, 10, 21), satDate: date(2026, 11, 7)))
        }
        if count(ErrorType.self, in: context) == 0 {
            seedErrorTypes(context)
        }
        try? context.save()
    }

    private static func count<T: PersistentModel>(_ type: T.Type, in context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<T>())) ?? 0
    }

    private static func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d)) ?? Date()
    }

    private static func seedCategories(_ context: ModelContext) -> [String: StudyCategory] {
        let defaults: [(String, String, Skill?, Bool)] = [
            ("IELTS Writing", "#F28C38", .writing, true),
            ("IELTS Speaking", "#E0679A", .speaking, true),
            ("IELTS Reading", "#4E9F6E", .reading, true),
            ("IELTS Listening", "#3F8FD2", .listening, true),
            ("SAT Math", "#7B61D9", .satMath, true),
            ("SAT R&W", "#C9A227", .satRW, true),
            ("Mock Test", "#E0533D", nil, true),
            ("Review/Error Analysis", "#9A6B4F", nil, true),
            ("Rest", "#9DB36A", nil, false),
            ("Other", "#8E8E93", nil, true),
        ]
        var result: [String: StudyCategory] = [:]
        for (i, item) in defaults.enumerated() {
            let c = StudyCategory(name: item.0, colorHex: item.1, order: i, skill: item.2, isStudy: item.3)
            context.insert(c)
            result[item.0] = c
        }
        return result
    }

    private static func seedTemplates(_ context: ModelContext, categories: [String: StudyCategory]) {
        let templates: [(String, [(String, String, String, String)])] = [
            ("IELTS full day", [
                ("07:00", "07:45", "IELTS Listening", "Listening: full section practice"),
                ("08:00", "09:00", "IELTS Reading", "Academic Reading passages"),
                ("09:00", "09:15", "Rest", "Break"),
                ("09:15", "10:15", "IELTS Writing", "Task 2 essay"),
                ("10:30", "11:00", "IELTS Speaking", "Part 2 cue cards (recorded)"),
                ("11:00", "12:00", "Review/Error Analysis", "Error log review"),
                ("12:00", "13:00", "Rest", "Lunch"),
                ("14:00", "15:00", "IELTS Writing", "Task 1 report"),
                ("15:15", "16:00", "IELTS Speaking", "Part 3 discussion"),
            ]),
            ("SAT test day", [
                ("08:00", "10:15", "Mock Test", "Full SAT practice test (Bluebook)"),
                ("10:15", "10:45", "Rest", "Break"),
                ("11:00", "12:30", "Review/Error Analysis", "Mock error analysis"),
                ("14:00", "15:00", "SAT Math", "Redo missed Math questions"),
                ("15:15", "16:15", "SAT R&W", "Redo missed R&W questions"),
            ]),
        ]
        for (name, items) in templates {
            let t = DayTemplate(name: name)
            context.insert(t)
            for item in items {
                let tb = TemplateBlock(startMin: TimeFmt.parse(item.0), endMin: TimeFmt.parse(item.1), title: item.3)
                context.insert(tb)
                tb.category = categories[item.2]
                tb.template = t
            }
        }
    }

    private static func seedErrorTypes(_ context: ModelContext) {
        let lr = ["Spelling/plural", "Word limit", "T/F/NG", "Distractor", "Matching headings", "Time pressure"]
        let map: [(Skill, [String])] = [
            (.listening, lr),
            (.reading, lr),
            (.writing, ["No overview", "Unclear position", "Weak development", "Articles", "Tenses", "Comma splice", "Word choice"]),
            (.speaking, []),
            (.satRW, ["Punctuation", "Transitions", "Rhetorical synthesis", "Words in context", "Careless"]),
            (.satMath, ["Algebra", "Advanced math", "Data analysis", "Geometry", "Careless"]),
        ]
        for (skill, names) in map {
            for (i, name) in names.enumerated() {
                context.insert(ErrorType(name: name, skill: skill, order: i))
            }
        }
    }
}
