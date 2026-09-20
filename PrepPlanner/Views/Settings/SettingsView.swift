import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            CategorySettings()
                .tabItem { Label("Categories", systemImage: "paintpalette") }
            TemplateSettings()
                .tabItem { Label("Templates", systemImage: "square.on.square") }
            ErrorTypeSettings()
                .tabItem { Label("Error Types", systemImage: "exclamationmark.bubble") }
            AboutSettings()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 640, height: 560)
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
    @Environment(\.modelContext) private var context
    @State private var language = AppLanguage.current
    @State private var renameResult: String?
    @State private var notificationStatus: UNAuthorizationStatus?
    @AppStorage(MenuBarPreference.key) private var showMenuBar = true
    private let launchLanguage = AppLanguage.current
    private let bands = Array(stride(from: 4.0, through: 9.0, by: 0.5))

    var body: some View {
        Form {
            Section("Language") {
                Picker("App language", selection: $language) {
                    Text("System default").tag(AppLanguage.system)
                    Text(verbatim: "English").tag(AppLanguage.english)
                    Text(verbatim: "Oʻzbekcha").tag(AppLanguage.uzbek)
                }
                .onChange(of: language) { language.apply() }
                if language != launchLanguage {
                    HStack {
                        Text("Restart PrepPlanner to switch the language.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Restart Now") { AppLanguage.relaunch() }
                    }
                }
                LabeledContent("Built-in names") {
                    HStack {
                        Button { rename(toUzbek: true) } label: { Text(verbatim: "Oʻzbekcha") }
                        Button { rename(toUzbek: false) } label: { Text(verbatim: "English") }
                    }
                }
                Text(renameResult ?? String(localized: "Renames the default categories, templates and error types. Names you changed yourself are kept."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Notifications") {
                Toggle("Notify before each block starts", isOn: $settings.notificationsEnabled)
                Picker("Remind me", selection: $settings.notificationLeadMinutes) {
                    ForEach([1, 5, 10, 15], id: \.self) { m in
                        Text("\(m) min before").tag(m)
                    }
                }
                .disabled(!settings.notificationsEnabled)
                if settings.notificationsEnabled && notificationStatus != .authorized && notificationStatus != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("macOS isn't delivering notifications for this copy of PrepPlanner, so reminders appear in a small window on top of your screen instead.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Button("Open System Settings") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            Spacer()
                        }
                    }
                    .font(.callout)
                }
                Toggle("Play a sound with reminders", isOn: $settings.reminderSound)
                    .disabled(!settings.notificationsEnabled)
                Toggle("Ask how it went when a block ends", isOn: $settings.endOfBlockPrompt)
                    .disabled(!settings.notificationsEnabled)
                Button("Show a Test Reminder") { InAppReminder.shared.showTest() }
                    .disabled(!settings.notificationsEnabled)
            }
            Section("Menu bar") {
                Toggle("Show the current block in the menu bar", isOn: $showMenuBar)
            }
            Section("Data") {
                LabeledContent("Backup (JSON)") {
                    HStack {
                        Button("Export…") { DataTransfer.exportBackup(context: context) }
                        Button("Import…") { DataTransfer.importBackup(context: context) }
                    }
                }
                LabeledContent("Results (CSV)") {
                    HStack {
                        Button { DataTransfer.exportCSV(.ielts, context: context) } label: { Text(verbatim: "IELTS") }
                        Button { DataTransfer.exportCSV(.sat, context: context) } label: { Text(verbatim: "SAT") }
                        Button("Error Log") { DataTransfer.exportCSV(.errors, context: context) }
                    }
                }
                Button("Show Backups Folder") { DataTransfer.showBackupsFolder() }
                    .buttonStyle(.link)
                    .foregroundStyle(Theme.accent)
            }
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
        .task(id: settings.notificationsEnabled) {
            NotificationScheduler.shared.scheduleSoon()
            try? await Task.sleep(for: .seconds(2))
            notificationStatus = await NotificationScheduler.shared.authorizationStatus()
        }
    }

    private func rename(toUzbek: Bool) {
        let n = DefaultNames.translate(toUzbek: toUzbek, in: context)
        renameResult = String(localized: "Renamed \(n) items.")
    }

    private func bandPicker(_ title: LocalizedStringKey, _ value: Binding<Double>) -> some View {
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
            Text("Blocks using this category: \(c.blocks.count). They stay on your planner without a category.")
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
            .frame(width: 148)

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
            Text("^[\(template.blocks.count) block](inflect: true) · \(TimeFmt.hours(template.totalMinutes))")
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

// MARK: - Error types

private struct ErrorTypeSettings: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ErrorType.order) private var allTypes: [ErrorType]
    @State private var skill: Skill = .listening
    @State private var pendingDelete: ErrorType?

    private var types: [ErrorType] { allTypes.filter { $0.skill == skill } }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Skill", selection: $skill) {
                ForEach(Skill.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)

            List {
                ForEach(types) { t in
                    ErrorTypeRow(type: t) { pendingDelete = t }
                }
                .onMove(perform: move)
            }
            .overlay {
                if types.isEmpty {
                    Text("No error types for \(skill.title) yet.").foregroundStyle(.secondary)
                }
            }

            Divider()
            HStack {
                Button { add() } label: { Label("Add Type", systemImage: "plus") }
                Spacer()
                Text("Drag rows to reorder.").font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .confirmationDialog(
            "Delete “\(pendingDelete?.name ?? "")”?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { t in
            Button("Delete", role: .destructive) { context.delete(t) }
        } message: { t in
            Text("Logged errors using this type: \(t.entries.count). They are kept and marked Untyped.")
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = types
        ordered.move(fromOffsets: source, toOffset: destination)
        for (i, t) in ordered.enumerated() { t.order = i }
    }

    private func add() {
        context.insert(ErrorType(name: "New type", skill: skill, order: (types.last?.order ?? -1) + 1))
    }
}

private struct ErrorTypeRow: View {
    @Bindable var type: ErrorType
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("Name", text: $type.name)
                .textFieldStyle(.roundedBorder)
            Text("\(type.entries.count) logged")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete type")
        }
        .padding(.vertical, 2)
    }
}

// MARK: - About

struct AboutSettings: View {
    private let repo = URL(string: "https://github.com/mahmudulashev/PrepPlanner")!
    private let email = "mahmud_u@icloud.com"

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(build))"
    }

    var body: some View {
        VStack(spacing: 16) {
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 96, height: 96)
            }
            VStack(spacing: 4) {
                Text(verbatim: "PrepPlanner")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Version \(version)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("IELTS and SAT study planner for macOS")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                Link(destination: repo) {
                    Label { Text(verbatim: "github.com/mahmudulashev/PrepPlanner") } icon: { Image(systemName: "chevron.left.forwardslash.chevron.right") }
                }
                Link(destination: URL(string: "mailto:\(email)")!) {
                    Label { Text(verbatim: email) } icon: { Image(systemName: "envelope") }
                }
            }
            .font(.callout)
            .tint(Theme.accent)

            Text("Made by Mahmud Ulashev. Your data stays on this Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
