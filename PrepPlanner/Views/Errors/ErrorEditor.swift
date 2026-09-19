import SwiftUI
import SwiftData

struct ErrorEditor: View {
    let entry: ErrorEntry?
    let prefill: ErrorPrefill?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ErrorType.order) private var types: [ErrorType]
    @Query(sort: \IELTSMock.date, order: .reverse) private var ieltsMocks: [IELTSMock]
    @Query(sort: \SATMock.date, order: .reverse) private var satMocks: [SATMock]

    @State private var date = Date()
    @State private var skill: Skill = .reading
    @State private var typeID: UUID?
    @State private var note = ""
    @State private var mockID: UUID?
    @State private var savedCount = 0
    @FocusState private var noteFocused: Bool

    private var typesForSkill: [ErrorType] { types.filter { $0.skill == skill } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(entry == nil ? "Log an error" : "Edit error").font(.title2.bold())
                Spacer()
                if savedCount > 0 {
                    Label("\(savedCount) saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.success)
                        .font(.callout.weight(.semibold))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 6)

            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Skill", selection: $skill) {
                        Section("IELTS") {
                            ForEach(Skill.ielts) { Label($0.title, systemImage: $0.symbol).tag($0) }
                        }
                        Section("SAT") {
                            ForEach(Skill.sat) { Label($0.title, systemImage: $0.symbol).tag($0) }
                        }
                    }
                    Picker("Error type", selection: $typeID) {
                        Text("Untyped").tag(UUID?.none)
                        ForEach(typesForSkill) { t in Text(t.name).tag(Optional(t.uid)) }
                    }
                    if typesForSkill.isEmpty {
                        HStack {
                            Text("No types for \(skill.title) yet.").foregroundStyle(.secondary)
                            Spacer()
                            SettingsLink { Text("Add in Settings…") }
                        }
                        .font(.callout)
                    }
                }
                Section("What went wrong") {
                    TextField("Note", text: $note, prompt: Text("e.g. wrote “analysis” instead of “analyses”"), axis: .vertical)
                        .labelsHidden()
                        .lineLimit(2...5)
                        .focused($noteFocused)
                }
                Section("Linked mock (optional)") {
                    Picker("Mock test", selection: $mockID) {
                        Text("None").tag(UUID?.none)
                        if skill.isIELTS {
                            ForEach(ieltsMocks) { m in Text(m.shortLabel).tag(Optional(m.uid)) }
                        } else {
                            ForEach(satMocks) { m in Text(m.shortLabel).tag(Optional(m.uid)) }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                if entry == nil {
                    Text("⇧⌘↩ saves and keeps the date, skill and mock for the next one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                if entry == nil {
                    Button("Save & Add Another") {
                        save()
                        note = ""
                        typeID = nil
                        savedCount += 1
                        noteFocused = true
                    }
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                }
                Button("Save") {
                    save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 520, height: 520)
        .onAppear(perform: load)
        .onChange(of: skill) { old, new in
            if let id = typeID, !typesForSkill.contains(where: { $0.uid == id }) { typeID = nil }
            if old.isIELTS != new.isIELTS { mockID = nil }
        }
    }

    private func load() {
        if let e = entry {
            date = e.date
            skill = e.skill
            typeID = e.errorType?.uid
            note = e.note
            mockID = e.ieltsMock?.uid ?? e.satMock?.uid
        } else if let p = prefill {
            date = p.date ?? Date()
            skill = p.skill ?? .reading
            mockID = p.ieltsMockID ?? p.satMockID
        }
        DispatchQueue.main.async { noteFocused = true }
    }

    private func save() {
        let e: ErrorEntry
        if let entry {
            e = entry
        } else {
            e = ErrorEntry(date: date, skill: skill)
            context.insert(e)
        }
        e.date = date
        e.skillRaw = skill.rawValue
        e.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        e.errorType = types.first { $0.uid == typeID }
        e.ieltsMock = skill.isIELTS ? ieltsMocks.first { $0.uid == mockID } : nil
        e.satMock = skill.isIELTS ? nil : satMocks.first { $0.uid == mockID }
        try? context.save()
    }
}
