import SwiftUI
import SwiftData
import Observation

enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case planner, habits, results, errors, analytics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .planner: String(localized: "Planner")
        case .habits: String(localized: "Habits")
        case .results: String(localized: "Results")
        case .errors: String(localized: "Error Log")
        case .analytics: String(localized: "Analytics")
        }
    }

    var symbol: String {
        switch self {
        case .planner: "calendar.day.timeline.left"
        case .habits: "checkmark.circle"
        case .results: "graduationcap"
        case .errors: "exclamationmark.bubble"
        case .analytics: "chart.xyaxis.line"
        }
    }

    var shortcut: KeyEquivalent {
        switch self {
        case .planner: "1"
        case .habits: "2"
        case .results: "3"
        case .errors: "4"
        case .analytics: "5"
        }
    }
}

enum ResultsTab: String, CaseIterable, Identifiable {
    case ielts = "IELTS"
    case sat = "SAT"

    var id: String { rawValue }
}

/// Values to pre-fill when logging an error from a mock test.
struct ErrorPrefill {
    var date: Date?
    var skill: Skill?
    var ieltsMockID: UUID?
    var satMockID: UUID?
}

/// Add/edit sheets that can be opened from anywhere in the app.
enum EditorSheet: Identifiable {
    case ielts(IELTSMock?)
    case sat(SATMock?)
    case error(ErrorEntry?, ErrorPrefill?)
    case habit(Habit?)

    var id: String {
        switch self {
        case .ielts(let m): "ielts-\(m?.uid.uuidString ?? "new")"
        case .sat(let m): "sat-\(m?.uid.uuidString ?? "new")"
        case .error(let e, _): "error-\(e?.uid.uuidString ?? "new")"
        case .habit(let h): "habit-\(h?.uid.uuidString ?? "new")"
        }
    }
}

/// Shared UI state plus planner actions, so menu commands and views use the same code paths.
@MainActor
@Observable
final class AppState {
    var section: SidebarSection? = .planner
    var day: Date = Date().startOfDay
    var selectedBlockID: UUID?
    var showInspector = true
    var showSaveTemplate = false
    var showApplyTemplate = false
    var lastCategoryID: UUID?
    /// A newly created block whose title field should receive focus.
    var pendingTitleFocusID: UUID?
    var toast: String?
    var resultsTab: ResultsTab = .ielts
    var editor: EditorSheet?

    @ObservationIgnored let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: Navigation

    func goToday() {
        section = .planner
        setDay(Date())
    }

    func shiftDay(_ delta: Int) {
        section = .planner
        setDay(day.adding(days: delta))
    }

    func setDay(_ date: Date) {
        let d = date.startOfDay
        guard d != day else { return }
        day = d
        selectedBlockID = nil
    }

    // MARK: Fetching

    func blocks(on date: Date) -> [TimeBlock] {
        let d = date.startOfDay
        let descriptor = FetchDescriptor<TimeBlock>(
            predicate: #Predicate { $0.day == d },
            sortBy: [SortDescriptor(\.startMin)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func blockCount(on date: Date) -> Int {
        let d = date.startOfDay
        let descriptor = FetchDescriptor<TimeBlock>(predicate: #Predicate { $0.day == d })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    var selectedBlock: TimeBlock? {
        guard let id = selectedBlockID else { return nil }
        var descriptor = FetchDescriptor<TimeBlock>(predicate: #Predicate { $0.uid == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func categories() -> [StudyCategory] {
        (try? context.fetch(FetchDescriptor<StudyCategory>(sortBy: [SortDescriptor(\.order)]))) ?? []
    }

    private func defaultCategory() -> StudyCategory? {
        let all = categories()
        if let id = lastCategoryID, let c = all.first(where: { $0.uid == id }) { return c }
        return all.first
    }

    // MARK: Block actions

    @discardableResult
    func createBlock(start: Int, end: Int, category: StudyCategory? = nil) -> TimeBlock {
        let cat = category ?? defaultCategory()
        let block = TimeBlock(day: day, startMin: start, endMin: end, title: cat?.name ?? String(localized: "Study"))
        context.insert(block)
        block.category = cat
        section = .planner
        selectedBlockID = block.uid
        showInspector = true
        pendingTitleFocusID = block.uid
        return block
    }

    /// ⌘N: a one-hour block at the first free slot (from now if viewing today, else 08:00).
    func newBlockAtNextFreeSlot() {
        section = .planner
        let existing = blocks(on: day)
        var start = 8 * 60
        if Calendar.current.isDateInToday(day) {
            let now = TimeFmt.minutesSinceMidnight(Date())
            start = max(TimelineBounds.start, Int((Double(now) / 15).rounded(.up)) * 15)
        }
        let lastStart = TimelineBounds.end - 60
        start = min(start, lastStart)
        func isFree(_ s: Int) -> Bool {
            !existing.contains { $0.startMin < s + 60 && $0.endMin > s }
        }
        var slot = start
        while slot <= lastStart && !isFree(slot) { slot += 15 }
        if slot > lastStart { slot = start }
        createBlock(start: slot, end: slot + 60)
    }

    func delete(_ block: TimeBlock) {
        if selectedBlockID == block.uid { selectedBlockID = nil }
        context.delete(block)
    }

    func deleteSelected() {
        if let b = selectedBlock { delete(b) }
    }

    func setStatus(_ status: BlockStatus) {
        selectedBlock?.setStatus(status)
    }

    func toggleDone(_ block: TimeBlock) {
        block.setStatus(block.status == .done ? .planned : .done)
    }

    func duplicate(_ block: TimeBlock) {
        let length = block.plannedMinutes
        var start = block.endMin
        if start + length > TimelineBounds.end { start = max(TimelineBounds.start, TimelineBounds.end - length) }
        let copy = TimeBlock(day: block.day, startMin: start, endMin: min(start + length, TimelineBounds.end),
                             title: block.title, note: block.note)
        context.insert(copy)
        copy.category = block.category
        selectedBlockID = copy.uid
    }

    func duplicateSelected() {
        if let b = selectedBlock { duplicate(b) }
    }

    /// Moves the selected block by ±15 minutes (arrow keys).
    func nudgeSelected(by delta: Int) {
        guard let b = selectedBlock else { return }
        let d = min(max(delta, TimelineBounds.start - b.startMin), TimelineBounds.end - b.endMin)
        b.startMin += d
        b.endMin += d
    }

    // MARK: Templates

    func saveTemplate(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let source = blocks(on: day)
        let existing = (try? context.fetch(FetchDescriptor<DayTemplate>(predicate: #Predicate { $0.name == name }))) ?? []
        existing.forEach(context.delete)

        let template = DayTemplate(name: name)
        context.insert(template)
        for b in source {
            let tb = TemplateBlock(startMin: b.startMin, endMin: b.endMin, title: b.title, note: b.note)
            context.insert(tb)
            tb.category = b.category
            tb.template = template
        }
        try? context.save()
        showToast(String.inflected("Saved template “\(name)” (^[\(source.count) block](inflect: true))"))
    }

    /// Returns the number of days the template was applied to.
    @discardableResult
    func apply(_ template: DayTemplate, to days: [Date], mode: TemplateConflictMode) -> Int {
        var applied = 0
        for date in days {
            let d = date.startOfDay
            let existing = blocks(on: d)
            if !existing.isEmpty {
                switch mode {
                case .skip: continue
                case .replace: existing.forEach(context.delete)
                case .merge: break
                }
            }
            for tb in template.sortedBlocks {
                // Re-applying the same template with Merge shouldn't create duplicates.
                if mode == .merge, existing.contains(where: {
                    $0.startMin == tb.startMin && $0.endMin == tb.endMin && $0.title == tb.title
                }) { continue }
                let b = TimeBlock(day: d, startMin: tb.startMin, endMin: tb.endMin, title: tb.title, note: tb.note)
                context.insert(b)
                b.category = tb.category
            }
            applied += 1
        }
        try? context.save()
        selectedBlockID = nil
        return applied
    }

    // MARK: Toast

    func showToast(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if toast == message { toast = nil }
        }
    }
}
