import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            CategorySettings()
                .tabItem { Label("Categories", systemImage: "paintpalette") }
            TemplateSettings()
                .tabItem { Label("Templates", systemImage: "square.on.square") }
        }
        .frame(width: 600, height: 500)
        .tint(Theme.accent)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @Query private var settings: [AppSettings]

    var body: some View {
        if let s = settings.first {
            GeneralForm(settings: s)
        } else {
            ProgressView()
        }
    }
}

private struct GeneralForm: View {
    @Bindable var settings: AppSettings
    private let bands = Array(stride(from: 4.0, through: 9.0, by: 0.5))

    var body: some View {
        Form {
            Section("Exam dates") {
                DatePicker("IELTS", selection: $settings.ieltsDate, displayedComponents: .date)
                DatePicker("SAT", selection: $settings.satDate, displayedComponents: .date)
            }
            Section("IELTS band targets") {
                bandPicker("Listening", $settings.targetListening)
                bandPicker("Reading", $settings.targetReading)
                bandPicker("Writing", $settings.targetWriting)
                bandPicker("Speaking", $settings.targetSpeaking)
            }
            Section("SAT target") {
                Stepper(value: $settings.targetSAT, in: 400...1600, step: 10) {
                    LabeledContent("Total score", value: "\(settings.targetSAT)")
                }
            }
        }
        .formStyle(.grouped)
    }

    private func bandPicker(_ title: String, _ value: Binding<Double>) -> some View {
        Picker(title, selection: value) {
            ForEach(bands, id: \.self) { b in
                Text(String(format: "%.1f", b)).tag(b)
            }
        }
    }
}

// MARK: - Categories

private struct CategorySettings: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \StudyCategory.order) private var categories: [StudyCategory]
    @State private var pendingDelete: StudyCategory?

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(categories) { c in
                    CategoryRow(category: c) { pendingDelete = c }
                }
                .onMove(perform: move)
            }
            Divider()
            HStack {
                Button { add() } label: { Label("Add Category", systemImage: "plus") }
                Spacer()
                Text("Drag rows to reorder. “Study” categories count toward study hours; linking a skill feeds analytics.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(12)
        }
        .confirmationDialog(
            "Delete “\(pendingDelete?.name ?? "")”?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { c in
            Button("Delete", role: .destructive) { context.delete(c) }
        } message: { c in
            Text("\(c.blocks.count) block(s) use this category. They stay on your planner without a category.")
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = categories
        ordered.move(fromOffsets: source, toOffset: destination)
        for (i, c) in ordered.enumerated() { c.order = i }
    }

    private func add() {
        let c = StudyCategory(name: "New Category", colorHex: "#5A8DEE", order: (categories.last?.order ?? -1) + 1)
        context.insert(c)
    }
}

private struct CategoryRow: View {
    @Bindable var category: StudyCategory
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ColorPicker("Color", selection: Binding(
                get: { Color(hex: category.colorHex) },
                set: { category.colorHex = $0.hexString }
            ), supportsOpacity: false)
            .labelsHidden()

            TextField("Name", text: $category.name)
                .textFieldStyle(.roundedBorder)

            Picker("Skill", selection: $category.skillRaw) {
                Text("No skill").tag(String?.none)
                ForEach(Skill.allCases) { s in
                    Text(s.title).tag(Optional(s.rawValue))
                }
            }
            .labelsHidden()
            .frame(width: 120)

            Toggle("Study", isOn: $category.isStudy)
                .toggleStyle(.checkbox)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete category")
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Templates

private struct TemplateSettings: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DayTemplate.name) private var templates: [DayTemplate]
    @State private var pendingDelete: DayTemplate?

    var body: some View {
        VStack(spacing: 0) {
            if templates.isEmpty {
                ContentUnavailableView("No templates", systemImage: "square.on.square",
                                       description: Text("Plan a day, then choose Block ▸ Save Day as Template (⇧⌘S)."))
            } else {
                List {
                    ForEach(templates) { t in
                        TemplateRow(template: t) { pendingDelete = t }
                    }
                }
            }
            Divider()
            Text("To change a template's blocks: apply it to a day, edit that day, then save it again with the same name.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .confirmationDialog(
            "Delete template “\(pendingDelete?.name ?? "")”?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { t in
            Button("Delete", role: .destructive) { context.delete(t) }
        } message: { _ in
            Text("Days you already applied it to are not changed.")
        }
    }
}

private struct TemplateRow: View {
    @Bindable var template: DayTemplate
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("Name", text: $template.name)
                .textFieldStyle(.roundedBorder)
            Text("\(template.blocks.count) blocks · \(TimeFmt.hours(template.totalMinutes))")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .trailing)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }
}
