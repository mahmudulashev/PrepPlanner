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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Day summary")
                    .font(.title3.bold())

                if blocks.isEmpty {
                    ContentUnavailableView(
                        "No blocks yet",
                        systemImage: "calendar.badge.plus",
                        description: Text("Drag on the timeline to create a block, press ⌘N, or apply a template (⇧⌘T).")
                    )
                } else {
                    breakdown
                }

                Divider()
                shortcuts
            }
            .padding(18)
        }
    }

    private var breakdown: some View {
        let grouped = Dictionary(grouping: blocks) { $0.category?.uid }
        let rows: [(name: String, color: String, planned: Int, done: Int)] =
            categories.compactMap { c in
                guard let items = grouped[c.uid] else { return nil }
                return (c.name, c.colorHex, items.reduce(0) { $0 + $1.plannedMinutes }, items.reduce(0) { $0 + $1.effectiveActual })
            } + (grouped[nil].map { items in
                [("No category", "#8E8E93", items.reduce(0) { $0 + $1.plannedMinutes }, items.reduce(0) { $0 + $1.effectiveActual })]
            } ?? [])

        return VStack(alignment: .leading, spacing: 12) {
            ForEach(rows, id: \.name) { row in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Circle().fill(Color(hex: row.color)).frame(width: 9, height: 9)
                        Text(row.name).font(.callout.weight(.medium))
                        Spacer()
                        Text("\(TimeFmt.hours(row.done)) / \(TimeFmt.hours(row.planned))")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.cardMuted)
                            Capsule().fill(Color(hex: row.color))
                                .frame(width: g.size.width * min(Double(row.done) / Double(max(row.planned, 1)), 1))
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
    }

    private var shortcuts: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Shortcuts").font(.headline)
            Group {
                shortcut("⌘N", "New block")
                shortcut("⌫", "Delete selected block")
                shortcut("↑ ↓", "Move selected block 15 min")
                shortcut("⇧⌘D / P / K", "Done / Partial / Skipped")
                shortcut("⌘[  ⌘]  ⌘T", "Previous / next day / today")
                shortcut("⇧⌘S / ⇧⌘T", "Save / apply template")
            }
            .font(.callout)
        }
    }

    private func shortcut(_ keys: String, _ label: String) -> some View {
        HStack {
            Text(keys).font(.callout.monospaced()).foregroundStyle(.secondary).frame(width: 110, alignment: .leading)
            Text(label)
        }
    }
}
