import Foundation
import SwiftData

/// English and Uzbek names for the built-in categories, templates, template blocks and error types.
enum DefaultNames {
    static let pairs: [(en: String, uz: String)] = [
        // Categories
        ("IELTS Writing", "IELTS Yozish"),
        ("IELTS Speaking", "IELTS Gapirish"),
        ("IELTS Reading", "IELTS Oʻqish"),
        ("IELTS Listening", "IELTS Tinglash"),
        ("SAT Math", "SAT Matematika"),
        ("SAT R&W", "SAT R&W"),
        ("Mock Test", "Sinov imtihoni"),
        ("Review/Error Analysis", "Takrorlash/Xatolar tahlili"),
        ("Rest", "Dam olish"),
        ("Other", "Boshqa"),
        // Templates
        ("IELTS full day", "IELTS toʻliq kun"),
        ("SAT test day", "SAT sinov kuni"),
        // Template block titles
        ("Listening: full section practice", "Tinglash: toʻliq boʻlim mashqi"),
        ("Academic Reading passages", "Academic Reading matnlari"),
        ("Break", "Tanaffus"),
        ("Task 2 essay", "Task 2 insho"),
        ("Part 2 cue cards (recorded)", "Part 2 kartochkalari (yozib olingan)"),
        ("Error log review", "Xatolar jurnalini koʻrib chiqish"),
        ("Lunch", "Tushlik"),
        ("Task 1 report", "Task 1 hisobot"),
        ("Part 3 discussion", "Part 3 muhokama"),
        ("Full SAT practice test (Bluebook)", "Toʻliq SAT sinov testi (Bluebook)"),
        ("Mock error analysis", "Sinov xatolarini tahlil qilish"),
        ("Redo missed Math questions", "Xato qilingan Math savollarini qayta ishlash"),
        ("Redo missed R&W questions", "Xato qilingan R&W savollarini qayta ishlash"),
        // Error types
        ("Spelling/plural", "Imlo/koʻplik"),
        ("Word limit", "Soʻz chegarasi"),
        ("T/F/NG", "T/F/NG"),
        ("Distractor", "Chalgʻituvchi javob"),
        ("Matching headings", "Sarlavhalarni moslash"),
        ("Time pressure", "Vaqt yetishmasligi"),
        ("No overview", "Overview yoʻq"),
        ("Unclear position", "Pozitsiya noaniq"),
        ("Weak development", "Fikr yetarli rivojlanmagan"),
        ("Articles", "Artikllar"),
        ("Tenses", "Zamonlar"),
        ("Comma splice", "Comma splice (vergul xatosi)"),
        ("Word choice", "Soʻz tanlash"),
        ("Punctuation", "Tinish belgilari"),
        ("Transitions", "Bogʻlovchi soʻzlar"),
        ("Rhetorical synthesis", "Rhetorical synthesis"),
        ("Words in context", "Kontekstdagi soʻzlar"),
        ("Careless", "Eʼtiborsizlik"),
        ("Algebra", "Algebra"),
        ("Advanced math", "Murakkab matematika"),
        ("Data analysis", "Maʼlumotlar tahlili"),
        ("Geometry", "Geometriya"),
    ]

    /// Name to use when seeding a new database.
    static func seedName(_ english: String) -> String {
        guard AppLanguage.isUzbekActive else { return english }
        return pairs.first { $0.en == english }?.uz ?? english
    }

    /// Renames built-in items that still have their default name in the other language.
    /// Returns how many items were renamed.
    @MainActor
    @discardableResult
    static func translate(toUzbek: Bool, in context: ModelContext) -> Int {
        var map: [String: String] = [:]
        for p in pairs where p.en != p.uz {
            if toUzbek { map[p.en] = p.uz } else { map[p.uz] = p.en }
        }
        var count = 0
        func rename(_ value: inout String) {
            if let new = map[value] {
                value = new
                count += 1
            }
        }
        for c in (try? context.fetch(FetchDescriptor<StudyCategory>())) ?? [] { rename(&c.name) }
        for t in (try? context.fetch(FetchDescriptor<DayTemplate>())) ?? [] { rename(&t.name) }
        for b in (try? context.fetch(FetchDescriptor<TemplateBlock>())) ?? [] { rename(&b.title) }
        for b in (try? context.fetch(FetchDescriptor<TimeBlock>())) ?? [] { rename(&b.title) }
        for e in (try? context.fetch(FetchDescriptor<ErrorType>())) ?? [] { rename(&e.name) }
        try? context.save()
        return count
    }
}
