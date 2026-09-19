import Foundation

/// The six skills tracked across IELTS and SAT.
enum Skill: String, Codable, CaseIterable, Identifiable {
    case listening, reading, writing, speaking, satRW, satMath

    var id: String { rawValue }

    var title: String {
        switch self {
        case .listening: String(localized: "Listening")
        case .reading: String(localized: "Reading")
        case .writing: String(localized: "Writing")
        case .speaking: String(localized: "Speaking")
        case .satRW: String(localized: "SAT R&W")
        case .satMath: String(localized: "SAT Math")
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

    var title: String {
        switch self {
        case .planned: String(localized: "Planned")
        case .done: String(localized: "Done")
        case .partial: String(localized: "Partial")
        case .skipped: String(localized: "Skipped")
        }
    }

    /// Context-menu wording for switching to this status.
    var actionTitle: String {
        switch self {
        case .planned: String(localized: "Reset to Planned")
        case .done: String(localized: "Mark Done")
        case .partial: String(localized: "Mark Partial")
        case .skipped: String(localized: "Mark Skipped")
        }
    }

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
        case .merge: String(localized: "Merge (add alongside)")
        case .replace: String(localized: "Replace existing blocks")
        case .skip: String(localized: "Skip those days")
        }
    }
}
