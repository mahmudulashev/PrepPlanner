import Foundation

enum Granularity: String, CaseIterable, Identifiable {
    case day, week

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: String(localized: "Daily")
        case .week: String(localized: "Weekly")
        }
    }
}

enum HoursKind: String {
    case planned, actual

    var title: String {
        switch self {
        case .planned: String(localized: "Planned")
        case .actual: String(localized: "Actual")
        }
    }
}

struct HoursRow: Identifiable {
    let id = UUID()
    let period: Date
    let category: String
    let kind: HoursKind
    let hours: Double
}

struct CompletionPoint: Identifiable {
    let id = UUID()
    let day: Date
    let rate: Double
    let marked: Int
}

struct ScorePoint: Identifiable {
    let id = UUID()
    let date: Date
    let series: String
    let value: Double
}

struct ErrorCountRow: Identifiable {
    let id = UUID()
    let name: String
    let skill: Skill
    let count: Int
}

/// Pure aggregation helpers behind the Analytics screen and insights.
enum Analytics {
    /// Weeks start on Monday.
    static var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2
        c.minimumDaysInFirstWeek = 4
        return c
    }

    static func startOfWeek(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date.startOfDay
    }

    /// Period start dates, oldest first, ending with the period that contains `now`.
    static func periods(_ granularity: Granularity, count: Int, now: Date) -> [Date] {
        switch granularity {
        case .day:
            return (0..<count).map { now.startOfDay.adding(days: -(count - 1 - $0)) }
        case .week:
            let current = startOfWeek(now)
            return (0..<count).map { current.adding(days: -7 * (count - 1 - $0)) }
        }
    }

    /// Planned and actual study hours per category and period. Only "study" categories are counted.
    static func hours(blocks: [TimeBlock], granularity: Granularity, periods: [Date]) -> [HoursRow] {
        let wanted = Set(periods)
        var planned: [Date: [String: Int]] = [:]
        var actual: [Date: [String: Int]] = [:]
        for b in blocks where b.isStudy {
            let key = granularity == .day ? b.day : startOfWeek(b.day)
            guard wanted.contains(key) else { continue }
            let name = b.category?.name ?? String(localized: "No category")
            planned[key, default: [:]][name, default: 0] += b.plannedMinutes
            actual[key, default: [:]][name, default: 0] += b.effectiveActual
        }
        var rows: [HoursRow] = []
        for p in periods {
            for (name, minutes) in planned[p] ?? [:] where minutes > 0 {
                rows.append(HoursRow(period: p, category: name, kind: .planned, hours: Double(minutes) / 60))
            }
            for (name, minutes) in actual[p] ?? [:] where minutes > 0 {
                rows.append(HoursRow(period: p, category: name, kind: .actual, hours: Double(minutes) / 60))
            }
        }
        return rows
    }

    /// Done = 100%, Partial = 50%, Skipped = 0%. Unmarked blocks are ignored.
    static func completionRate(_ blocks: [TimeBlock]) -> Double? {
        let weights = blocks.compactMap(\.status.completionWeight)
        guard !weights.isEmpty else { return nil }
        return weights.reduce(0, +) / Double(weights.count)
    }

    static func completion(blocks: [TimeBlock], days: Int, now: Date) -> [CompletionPoint] {
        let start = now.startOfDay.adding(days: -(days - 1))
        let grouped = Dictionary(grouping: blocks.filter { $0.isStudy && $0.day >= start && $0.day <= now }) { $0.day }
        return grouped.compactMap { day, items in
            guard let rate = completionRate(items) else { return nil }
            return CompletionPoint(day: day, rate: rate, marked: items.filter { $0.status != .planned }.count)
        }
        .sorted { $0.day < $1.day }
    }

    static func ieltsPoints(_ mocks: [IELTSMock]) -> [ScorePoint] {
        mocks.flatMap { m in
            Skill.ielts.map { s in ScorePoint(date: m.date, series: s.title, value: m.band(for: s) ?? 0) }
        }
    }

    static func satSectionPoints(_ mocks: [SATMock]) -> [ScorePoint] {
        mocks.flatMap { m in
            [ScorePoint(date: m.date, series: Skill.satRW.title, value: Double(m.readingWriting)),
             ScorePoint(date: m.date, series: Skill.satMath.title, value: Double(m.math))]
        }
    }

    /// Most frequent error types, highest first. Untyped entries are skipped.
    static func errorCounts(_ errors: [ErrorEntry], skill: Skill?, since: Date?, limit: Int) -> [ErrorCountRow] {
        let filtered = errors.filter { e in
            if let skill, e.skill != skill { return false }
            if let since, e.date < since { return false }
            return e.errorType != nil
        }
        let grouped = Dictionary(grouping: filtered) { $0.errorType!.uid }
        return grouped.compactMap { _, items -> ErrorCountRow? in
            guard let t = items.first?.errorType else { return nil }
            return ErrorCountRow(name: t.name, skill: t.skill, count: items.count)
        }
        .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
        .prefix(limit)
        .map { $0 }
    }
}
