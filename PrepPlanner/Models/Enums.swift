import Foundation

/// The six skills tracked across IELTS and SAT.
enum Skill: String, Codable, CaseIterable, Identifiable {
    case listening, reading, writing, speaking, satRW, satMath

    var id: String { rawValue }

    var title: String {
        switch self {
        case .listening: "Listening"
        case .reading: "Reading"
        case .writing: "Writing"
        case .speaking: "Speaking"
        case .satRW: "SAT R&W"
        case .satMath: "SAT Math"
        }
    }

    var isIELTS: Bool {
        switch self {
        case .satRW, .satMath: false
        default: true
        }
    }
}

enum BlockStatus: String, Codable, CaseIterable, Identifiable {
    case planned, done, partial, skipped

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .planned: "square"
        case .done: "checkmark.square.fill"
        case .partial: "circle.lefthalf.filled"
        case .skipped: "xmark.square.fill"
        }
    }

    /// Done = 100%, Partial = 50%, Skipped = 0%. Planned blocks are not scored yet.
    var completionWeight: Double? {
        switch self {
        case .planned: nil
        case .done: 1
        case .partial: 0.5
        case .skipped: 0
        }
    }
}

/// What to do with days that already contain blocks when applying a template.
enum TemplateConflictMode: String, CaseIterable, Identifiable {
    case merge, replace, skip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .merge: "Merge (add alongside)"
        case .replace: "Replace existing blocks"
        case .skip: "Skip those days"
        }
    }
}
