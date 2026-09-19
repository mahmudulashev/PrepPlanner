import Foundation

/// Bounds of the planner timeline, in minutes from midnight.
enum TimelineBounds {
    static let start = 6 * 60
    static let end = 24 * 60
    static let step = 15

    /// Every selectable 15-minute slot, 06:00 through 24:00.
    static var slots: [Int] { Array(stride(from: start, through: end, by: step)) }
}

enum TimeFmt {
    /// 510 -> "08:30"
    static func hm(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    static func range(_ start: Int, _ end: Int) -> String {
        "\(hm(start))–\(hm(end))"
    }

    /// 75 -> "1h 15m"
    static func duration(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return String(localized: "\(m)m", comment: "Duration in minutes") }
        if m == 0 { return String(localized: "\(h)h", comment: "Duration in whole hours") }
        return String(localized: "\(h)h \(m)m", comment: "Duration in hours and minutes")
    }

    /// 270 -> "4.5h", 105 -> "1.75h"
    static func hours(_ minutes: Int) -> String {
        let h = Double(minutes) / 60
        var s = String(format: "%.2f", h)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return String(localized: "\(s)h", comment: "Number of hours, e.g. 4.5h")
    }

    /// "07:45" -> 465
    static func parse(_ s: String) -> Int {
        let parts = s.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return 0 }
        return parts[0] * 60 + parts[1]
    }

    static func minutesSinceMidnight(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
}

enum Countdown {
    static func days(to date: Date, from now: Date = Date()) -> Int {
        Calendar.current.dateComponents([.day], from: now.startOfDay, to: date.startOfDay).day ?? 0
    }
}
