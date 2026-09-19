import SwiftUI
import SwiftData

enum ErrorDateRange: String, CaseIterable, Identifiable {
    case week = "7 days"
    case month = "30 days"
    case all = "All"

    var id: String { rawValue }

    var startDate: Date? {
        switch self {
        case .week: Date().startOfDay.adding(days: -6)
        case .month: Date().startOfDay.adding(days: -29)
        case .all: nil
        }
    }
}

struct ErrorLogView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var context
    @Query(sort: \ErrorEntry.date, order: .reverse) private var entries: [ErrorEntry]
    @Query(sort: \ErrorType.order) private var types: [ErrorType]

    @State private var skillFilter: Skill?
    @State private var typeFilter: UUID?
    @State private var range: ErrorDateRange = .all
    @State private var search = ""
    @State private var selection = Set<PersistentIdentifier>()
    @State private var pendingDelete: [ErrorEntry] = []

    private var filtered: [ErrorEntry] {
        let start = range.startDate
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        return entries.filter { e in
            if let s = skillFilter, e.skill != s { return false }
            if let t = typeFilter, e.errorType?.uid != t { return false }
            if let start, e.date < start { return false }
            if !query.isEmpty {
                let haystack = "\(e.note) \(e.errorType?.name ?? "") \(e.skill.title)".lowercased()
                if !haystack.contains(query) { return false }
            }
            return true
        }
    }

    var body: some View {
        let rows = filtered
        VStack(spacing: 16) {
            filterBar(count: rows.count)
            if entries.isEmpty {
                ContentUnavailableView {
                    Label("No errors logged yet", systemImage: "exclamationmark.bubble")
                } description: {
                    Text("Log each mistake with its skill and type. Patterns show up here and in Analytics.")
                } actions: {
                    Button("Log an Error") { state.editor = .error(nil, nil) }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxHeight: .infinity)
            } else {
                topTypes(rows)
                table(rows).card(padding: 0)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle("Error Log")
        .searchable(text: $search, placement: .toolbar, prompt: "Search notes and types")
        .toolbar {
            ToolbarItem {
                Button { state.editor = .error(nil, nil) } label: { Label("Log Error", systemImage: "plus") }
                    .help("Log an error (⌘E)")
            }
        }
        .confirmationDialog(
            pendingDelete.count == 1 ? "Delete this entry?" : "Delete \(pendingDelete.count) entries?",
            isPresented: Binding(get: { !pendingDelete.isEmpty }, set: { if !$0 { pendingDelete = [] } })
        ) {
            Button("Delete", role: .destructive) {
                pendingDelete.forEach(context.delete)
                pendingDelete = []
                selection = []
            }
        }
        .onChange(of: skillFilter) { typeFilter = nil }
    }

    // MARK: Filters

    private func filterBar(count: Int) -> some View {
        HStack(spacing: 12) {
            Picker("Skill", selection: $skillFilter) {
                Text("All skills").tag(Skill?.none)
                Divider()
                ForEach(Skill.allCases) { s in Text(s.title).tag(Optional(s)) }
            }
            .frame(width: 170)

            Picker("Type", selection: $typeFilter) {
                Text("All types").tag(UUID?.none)
                Divider()
                ForEach(types.filter { skillFilter == nil || $0.skill == skillFilter }) { t in
                    Text(skillFilter == nil ? "\(t.name) (\(t.skill.title))" : t.name).tag(Optional(t.uid))
                }
            }
            .frame(width: 240)

            Picker("Range", selection: $range) {
                ForEach(ErrorDateRange.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 210)

            Spacer()

            if skillFilter != nil || typeFilter != nil || range != .all || !search.isEmpty {
                Button("Clear Filters") {
                    skillFilter = nil
                    typeFilter = nil
                    range = .all
                    search = ""
                }
                .buttonStyle(.link)
                .foregroundStyle(Theme.accent)
            }
            Text("\(count) error\(count == 1 ? "" : "s")")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .card(padding: 12)
    }

    /// The most frequent types in the current filter, clickable to drill down.
    private func topTypes(_ rows: [ErrorEntry]) -> some View {
        let counts = Dictionary(grouping: rows.filter { $0.errorType != nil }) { $0.errorType!.uid }
            .compactMap { (_, items) -> (ErrorType, Int)? in
                guard let t = items.first?.errorType else { return nil }
                return (t, items.count)
            }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.name < $1.0.name }
            .prefix(6)

        return HStack(spacing: 10) {
            Text("Most frequent")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
            if counts.isEmpty {
                Text("No typed errors in this view.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(Array(counts), id: \.0.uid) { (type, n) in
                Button {
                    skillFilter = type.skill
                    DispatchQueue.main.async { typeFilter = type.uid }
                } label: {
                    HStack(spacing: 6) {
                        Circle().fill(type.skill.color).frame(width: 8, height: 8)
                        Text(type.name)
                        Text("×\(n)").fontWeight(.bold).monospacedDigit()
                    }
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(typeFilter == type.uid ? type.skill.color.opacity(0.25) : Theme.card))
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .help("Show only \(type.name) (\(type.skill.title))")
            }
            Spacer()
        }
    }

    // MARK: Table

    private func table(_ rows: [ErrorEntry]) -> some View {
        Table(rows, selection: $selection) {
            TableColumn("Date") { e in
                Text(e.date.formatted(date: .abbreviated, time: .omitted))
            }
            .width(min: 90, ideal: 105)
            TableColumn("Skill") { e in
                SkillTag(skill: e.skill)
            }
            .width(min: 90, ideal: 110)
            TableColumn("Type") { e in
                Text(e.errorType?.name ?? "Untyped")
                    .foregroundStyle(e.errorType == nil ? .secondary : .primary)
            }
            .width(min: 110, ideal: 160)
            TableColumn("Note") { e in
                Text(e.note).lineLimit(2)
            }
            TableColumn("Mock") { e in
                Text(e.mockLabel ?? "–").foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 170)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: false))
        .scrollContentBackground(.hidden)
        .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
            let items = rows.filter { ids.contains($0.persistentModelID) }
            if items.count == 1, let e = items.first {
                Button("Edit…") { state.editor = .error(e, nil) }
                Button("Log Another Like This…") {
                    state.editor = .error(nil, ErrorPrefill(date: e.date, skill: e.skill,
                                                            ieltsMockID: e.ieltsMock?.uid, satMockID: e.satMock?.uid))
                }
                Divider()
            }
            if !items.isEmpty {
                Button("Delete", role: .destructive) { pendingDelete = items }
            }
        } primaryAction: { ids in
            if let e = rows.first(where: { ids.contains($0.persistentModelID) }) { state.editor = .error(e, nil) }
        }
        .onDeleteCommand {
            pendingDelete = rows.filter { selection.contains($0.persistentModelID) }
        }
    }
}
