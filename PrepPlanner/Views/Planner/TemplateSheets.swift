import SwiftUI
import SwiftData

/// Lightweight row used to preview blocks from a day or a template.
struct TemplatePreviewItem: Identifiable {
    let id = UUID()
    let start: Int
    let end: Int
    let title: String
    let colorHex: String
}

struct TemplatePreviewList: View {
    let items: [TemplatePreviewItem]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items) { item in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: item.colorHex))
                            .frame(width: 4, height: 22)
                        Text(TimeFmt.range(item.start, item.end))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 96, alignment: .leading)
                        Text(item.title)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer()
                        Text(TimeFmt.duration(item.end - item.start))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
        }
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.cardMuted))
    }
}

// MARK: - Save

struct SaveTemplateSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DayTemplate.name) private var templates: [DayTemplate]
    @State private var name = ""
    @State private var blocks: [TimeBlock] = []

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var willReplace: Bool { templates.contains { $0.name == trimmed } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Save day as template")
                .font(.title2.bold())
            Text("Saves ^[\(blocks.count) block](inflect: true) from \(state.day.formatted(date: .complete, time: .omitted)): times, titles, categories and notes. Statuses aren't saved.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Template name, e.g. IELTS full day", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)

            if willReplace {
                Label("A template named “\(trimmed)” already exists. It will be replaced.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.callout)
            }

            if blocks.isEmpty {
                Text("This day has no blocks yet, so there's nothing to save.")
                    .foregroundStyle(.secondary)
            } else {
                TemplatePreviewList(items: blocks.map {
                    TemplatePreviewItem(start: $0.startMin, end: $0.endMin, title: $0.title,
                                        colorHex: $0.category?.colorHex ?? "#8E8E93")
                })
                .frame(height: 200)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(willReplace ? "Replace" : "Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty || blocks.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear { blocks = state.blocks(on: state.day) }
    }

    private func save() {
        guard !trimmed.isEmpty, !blocks.isEmpty else { return }
        state.saveTemplate(named: trimmed)
        dismiss()
    }
}

// MARK: - Apply

struct ApplyTemplateSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \DayTemplate.name) private var templates: [DayTemplate]

    @State private var selectedID: UUID?
    @State private var from = Date()
    @State private var to = Date()
    @State private var weekdays: Set<Int> = Set(1...7)
    @State private var mode: TemplateConflictMode = .merge

    /// Calendar weekday numbers in Monday-first order, with the locale's one-letter names.
    private let weekdayOrder: [(Int, String)] = {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        return [2, 3, 4, 5, 6, 7, 1].map { ($0, symbols[$0 - 1]) }
    }()
    private let maxDays = 180

    private var selected: DayTemplate? { templates.first { $0.uid == selectedID } }

    private var targetDays: [Date] {
        let start = from.startOfDay, end = to.startOfDay
        guard end >= start else { return [] }
        var days: [Date] = []
        var d = start
        while d <= end && days.count < maxDays {
            if weekdays.contains(Calendar.current.component(.weekday, from: d)) { days.append(d) }
            d = d.adding(days: 1)
        }
        return days
    }

    var body: some View {
        let days = targetDays
        let conflicts = days.filter { state.blockCount(on: $0) > 0 }.count

        VStack(alignment: .leading, spacing: 16) {
            Text("Apply template")
                .font(.title2.bold())

            HStack(alignment: .top, spacing: 18) {
                templateList
                    .frame(width: 200)

                VStack(alignment: .leading, spacing: 14) {
                    if let t = selected {
                        TemplatePreviewList(items: t.sortedBlocks.map {
                            TemplatePreviewItem(start: $0.startMin, end: $0.endMin, title: $0.title,
                                                colorHex: $0.category?.colorHex ?? "#8E8E93")
                        })
                        .frame(height: 170)
                    } else {
                        Text("Choose a template on the left.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 170)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.cardMuted))
                    }

                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                        GridRow {
                            Text("From").foregroundStyle(.secondary)
                            DatePicker("From", selection: $from, displayedComponents: .date).labelsHidden()
                        }
                        GridRow {
                            Text("To").foregroundStyle(.secondary)
                            DatePicker("To", selection: $to, in: from..., displayedComponents: .date).labelsHidden()
                        }
                        GridRow {
                            Text("Days").foregroundStyle(.secondary)
                            weekdayChips
                        }
                    }

                    if conflicts > 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Days that already have blocks: \(conflicts)")
                                .font(.callout.weight(.medium))
                            Picker("Conflicts", selection: $mode) {
                                ForEach(TemplateConflictMode.allCases) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.radioGroup)
                            .labelsHidden()
                        }
                    }
                }
            }

            HStack {
                summary(days: days.count)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Apply") { apply(days) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selected == nil || days.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 680)
        .onAppear {
            from = state.day
            to = state.day
            if selectedID == nil { selectedID = templates.first?.uid }
        }
        .onChange(of: from) { if to < from { to = from } }
    }

    private var templateList: some View {
        List(selection: $selectedID) {
            ForEach(templates) { t in
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.name).font(.body.weight(.medium))
                    Text("^[\(t.blocks.count) block](inflect: true) · \(TimeFmt.hours(t.totalMinutes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
                .tag(t.uid)
                .contextMenu {
                    Button("Delete Template", role: .destructive) {
                        if selectedID == t.uid { selectedID = nil }
                        context.delete(t)
                    }
                }
            }
        }
        .listStyle(.bordered)
        .overlay {
            if templates.isEmpty {
                Text("No templates yet.\nSave a day first (⇧⌘S).")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }

    private var weekdayChips: some View {
        HStack(spacing: 6) {
            ForEach(weekdayOrder, id: \.0) { (weekday, label) in
                let on = weekdays.contains(weekday)
                Button {
                    if on { weekdays.remove(weekday) } else { weekdays.insert(weekday) }
                } label: {
                    Text(verbatim: label)
                        .font(.callout.weight(.semibold))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(on ? Theme.ink : Theme.cardMuted))
                        .foregroundStyle(on ? Theme.onInk : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func summary(days: Int) -> Text {
        guard let t = selected else { return Text(verbatim: "") }
        if days == 0 { return Text("No days match the selected range and weekdays.") }
        if days == maxDays { return Text("Adds ^[\(t.blocks.count) block](inflect: true) to \(days) days (the maximum).") }
        return Text("Adds ^[\(t.blocks.count) block](inflect: true) to ^[\(days) day](inflect: true).")
    }

    private func apply(_ days: [Date]) {
        guard let t = selected else { return }
        let n = state.apply(t, to: days, mode: mode)
        state.showToast(String.inflected("Applied “\(t.name)” to ^[\(n) day](inflect: true)"))
        dismiss()
    }
}
