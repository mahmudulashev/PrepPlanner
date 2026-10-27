import SwiftUI
import SwiftData

struct BlockInspector: View {
    let day: Date
    @Environment(AppState.self) private var state
    @Query private var blocks: [TimeBlock]
    @Query(sort: \StudyCategory.order) private var categories: [StudyCategory]

    init(day: Date) {
        self.day = day
        let d = day
        _blocks = Query(filter: #Predicate<TimeBlock> { $0.day == d }, sort: \TimeBlock.startMin)
    }

    var body: some View {
        if let id = state.selectedBlockID, let block = blocks.first(where: { $0.uid == id }) {
            BlockEditor(block: block, categories: categories)
                .id(block.uid)
        } else {
            DaySummary(blocks: blocks, categories: categories)
        }
    }
}

private struct BlockEditor: View {
    @Bindable var block: TimeBlock
    let categories: [StudyCategory]
    @Environment(AppState.self) private var state
    @FocusState private var titleFocused: Bool

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $block.title)
                    .focused($titleFocused)
                HStack {
                    Picker("Category", selection: categoryBinding) {
                        Text("None").tag(UUID?.none)
                        ForEach(categories) { c in
                            Text(c.name).tag(Optional(c.uid))
                        }
                    }
                    Circle()
                        .fill(Color(hex: block.category?.colorHex ?? "#8E8E93"))
                        .frame(width: 12, height: 12)
                }
            }

            Section("Time") {
                Picker("Start", selection: startBinding) {
                    ForEach(TimelineBounds.slots.dropLast(), id: \.self) { m in
                        Text(TimeFmt.hm(m)).tag(m)
                    }
                }
                Picker("End", selection: $block.endMin) {
                    ForEach(TimelineBounds.slots.filter { $0 > block.startMin }, id: \.self) { m in
                        Text(TimeFmt.hm(m)).tag(m)
                    }
                }
                LabeledContent("Duration", value: TimeFmt.duration(block.plannedMinutes))
            }

            Section("Status") {
                Picker("Status", selection: statusBinding) {
                    ForEach(BlockStatus.allCases) { s in Text(s.title).tag(s) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if block.status != .planned {
                    LabeledContent("Actual minutes") {
                        HStack(spacing: 6) {
                            TextField("Minutes", value: actualBinding, format: .number)
                                .labelsHidden()
                                .multilineTextAlignment(.trailing)
                                .frame(width: 64)
                            Stepper("Minutes", value: actualBinding, in: 0...1080, step: 5)
                                .labelsHidden()
                        }
                    }
                } else if block.needsReview {
                    Label("This block has ended. How did it go?", systemImage: "clock.badge.questionmark")
                        .foregroundStyle(Theme.accent)
                        .font(.callout)
                }
            }

            Section("Note") {
                TextEditor(text: $block.note)
                    .font(.body)
                    .frame(minHeight: 90)
            }

            Section {
                HStack {
                    Button { state.duplicate(block) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                    Spacer()
                    Button(role: .destructive) { state.delete(block) } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
        .formStyle(.grouped)
        .task(id: block.uid) {
            guard state.pendingTitleFocusID == block.uid else { return }
            state.pendingTitleFocusID = nil
            try? await Task.sleep(for: .milliseconds(100))
            titleFocused = true
        }
    }

    private var categoryBinding: Binding<UUID?> {
        Binding(
            get: { block.category?.uid },
            set: { id in
                let newCategory = categories.first { $0.uid == id }
                // Keep the auto-title in sync if the user hasn't renamed the block.
                if block.title == block.category?.name, let newCategory { block.title = newCategory.name }
                block.category = newCategory
                state.lastCategoryID = id
            }
        )
    }

    private var startBinding: Binding<Int> {
        Binding(
            get: { block.startMin },
            set: { newStart in
                let length = block.plannedMinutes
                block.startMin = newStart
                block.endMin = min(newStart + length, TimelineBounds.end)
            }
        )
    }

    private var statusBinding: Binding<BlockStatus> {
        Binding(get: { block.status }, set: { block.setStatus($0) })
    }

    private var actualBinding: Binding<Int> {
        Binding(
            get: { block.actualMinutes ?? block.plannedMinutes },
            set: { block.actualMinutes = max(0, $0) }
        )
    }
}

private struct DaySummary: View {
    let blocks: [TimeBlock]
    let categories: [StudyCategory]
    @Environment(AppState.self) private var state

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if blocks.isEmpty {
                    ContentUnavailableView(
                        "No blocks yet",
                        systemImage: "calendar.badge.plus",
                        description: Text("Drag on the timeline to create a block, press ⌘N, or apply a template (⇧⌘T).")
                    )
                    .padding(.top, 40)
                } else {
                    totals
                    section("By category") { breakdown }
                    section("Schedule") { schedule }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func section<C: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    // MARK: Totals

    private var totals: some View {
        TimelineView(.everyMinute) { context in
            let study = blocks.filter(\.isStudy)
            let planned = study.reduce(0) { $0 + $1.plannedMinutes }
            let done = study.reduce(0) { $0 + $1.effectiveActual }
            let review = blocks.filter { $0.status == .planned && $0.endDate < context.date }.count
            HStack(spacing: 8) {
                stat(TimeFmt.hours(planned), "Planned")
                stat(TimeFmt.hours(done), "Done", color: Theme.success)
                stat("\(review)", "To review", color: review > 0 ? Theme.accent : .primary)
            }
        }
    }

    private func stat(_ value: String, _ label: LocalizedStringKey, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value)
                .font(.system(size: 17, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.cardMuted))
    }

    // MARK: Categories

    private var breakdown: some View {
        let grouped = Dictionary(grouping: blocks) { $0.category?.uid }
        let rows: [(name: String, color: String, planned: Int, done: Int)] =
            categories.compactMap { c in
                guard let items = grouped[c.uid] else { return nil }
                return (c.name, c.colorHex, items.reduce(0) { $0 + $1.plannedMinutes }, items.reduce(0) { $0 + $1.effectiveActual })
            } + (grouped[nil].map { items in
                [(String(localized: "No category"), "#8E8E93", items.reduce(0) { $0 + $1.plannedMinutes }, items.reduce(0) { $0 + $1.effectiveActual })]
            } ?? [])

        return VStack(alignment: .leading, spacing: 11) {
            ForEach(rows, id: \.name) { row in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Circle().fill(Color(hex: row.color)).frame(width: 7, height: 7)
                        Text(row.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 8)
                        Text(verbatim: "\(TimeFmt.hours(row.done)) / \(TimeFmt.hours(row.planned))")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .layoutPriority(1)
                    }
                    ProgressTrack(fraction: Double(row.done) / Double(max(row.planned, 1)),
                                  color: Color(hex: row.color), height: 4)
                }
            }
        }
    }

    // MARK: Schedule

    private var schedule: some View {
        VStack(spacing: 2) {
            ForEach(blocks) { b in
                Button { state.selectedBlockID = b.uid } label: {
                    HStack(spacing: 9) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(hex: b.category?.colorHex ?? "#8E8E93"))
                            .frame(width: 3, height: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(b.title.isEmpty ? String(localized: "Untitled") : b.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(b.status == .planned || b.status == .partial ? Color.primary : Color.secondary)
                                .strikethrough(b.status == .done || b.status == .skipped, color: .secondary)
                                .lineLimit(1)
                            Text(TimeFmt.range(b.startMin, b.endMin))
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: statusSymbol(b.status))
                            .font(.system(size: 13))
                            .foregroundStyle(statusColor(b.status))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(ScheduleRowStyle())
            }
        }
    }

    private func statusSymbol(_ s: BlockStatus) -> String {
        switch s {
        case .planned: "circle"
        case .done: "checkmark.circle.fill"
        case .partial: "circle.lefthalf.filled"
        case .skipped: "minus.circle"
        }
    }

    private func statusColor(_ s: BlockStatus) -> Color {
        switch s {
        case .planned: .secondary.opacity(0.6)
        case .done: Theme.success
        case .partial: Theme.accent
        case .skipped: .secondary
        }
    }
}

/// Plain row that highlights on hover and press.
private struct ScheduleRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverRow(pressed: configuration.isPressed) { configuration.label }
    }

    private struct HoverRow<Label: View>: View {
        let pressed: Bool
        @ViewBuilder var label: Label
        @State private var hovering = false

        var body: some View {
            label
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(pressed ? 0.09 : (hovering ? 0.05 : 0)))
                )
                .onHover { hovering = $0 }
        }
    }
}
