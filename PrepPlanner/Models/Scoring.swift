import Foundation

/// IELTS band conversion and rounding rules.
enum Band {
    /// 0.0, 0.5, … 9.0
    static let halfSteps: [Double] = Array(stride(from: 0.0, through: 9.0, by: 0.5))

    /// (minimum raw score, band), highest first.
    private static let listeningTable: [(Int, Double)] = [
        (39, 9), (37, 8.5), (35, 8), (32, 7.5), (30, 7), (26, 6.5), (23, 6), (18, 5.5), (16, 5),
        (13, 4.5), (10, 4), (7, 3.5), (5, 3), (3, 2.5), (1, 1),
    ]

    /// Academic Reading.
    private static let readingTable: [(Int, Double)] = [
        (39, 9), (37, 8.5), (35, 8), (33, 7.5), (30, 7), (27, 6.5), (23, 6), (19, 5.5), (15, 5),
        (13, 4.5), (10, 4), (8, 3.5), (6, 3), (4, 2.5), (1, 1),
    ]

    static func listening(_ raw: Int) -> Double { lookup(raw, in: listeningTable) }
    static func reading(_ raw: Int) -> Double { lookup(raw, in: readingTable) }

    private static func lookup(_ raw: Int, in table: [(Int, Double)]) -> Double {
        table.first { raw >= $0.0 }?.1 ?? 0
    }

    /// Average rounded to the nearest half band: .25 rounds up to .5 and .75 rounds up to the next whole band.
    static func overall(_ bands: [Double]) -> Double {
        guard !bands.isEmpty else { return 0 }
        let average = bands.reduce(0, +) / Double(bands.count)
        let whole = average.rounded(.down)
        let fraction = average - whole
        if fraction < 0.25 { return whole }
        if fraction < 0.75 { return whole + 0.5 }
        return whole + 1
    }

    /// Average of four marking criteria and the band it suggests (rounded down to the nearest half band).
    static func criteria(_ values: [Double?]) -> (average: Double, band: Double)? {
        let set = values.compactMap { $0 }
        guard set.count == values.count, !set.isEmpty else { return nil }
        let average = set.reduce(0, +) / Double(set.count)
        return (average, (average * 2).rounded(.down) / 2)
    }

    static func format(_ band: Double) -> String {
        String(format: "%.1f", band)
    }

    static func formatDelta(_ delta: Double) -> String {
        if delta > 0 { return "+" + format(delta) }
        if delta < 0 { return "−" + format(-delta) }
        return "±0"
    }
}

enum SATScore {
    static let sectionRange = 200...800

    /// Section scores move in steps of 10.
    static func clampSection(_ value: Int) -> Int {
        let snapped = Int((Double(value) / 10).rounded()) * 10
        return min(max(snapped, sectionRange.lowerBound), sectionRange.upperBound)
    }

    static func formatDelta(_ delta: Int) -> String {
        if delta > 0 { return "+\(delta)" }
        if delta < 0 { return "−\(-delta)" }
        return "±0"
    }
}
