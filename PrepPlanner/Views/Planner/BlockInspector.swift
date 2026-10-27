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
    @Environment(\.colorScheme) private var scheme
    @FocusState private var titleFocused: Bool
    @FocusState private var noteFocused: Bool

    private var hex: String { block.category?.colorHex ?? "#8E8E93" }
    private var color: Color { Color(hex: hex) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                InspectorCard(title: "Time") { time }
                InspectorCard(title: "Status") { status }
                InspectorCard(title: "Note") { note }
                actions
            }
            .padding(14)
            .animation(.spring(duration: 0.3), value: block.status)
        }
        .scrollIndicators(.never)
        .task(id: block.uid) {
            guard state.pendingTitleFocusID == block.uid else { return }
            state.pendingTitleFocusID = nil
            try? await Task.sleep(for: .milliseconds(100))
            titleFocused = true
        }
    }

    // MARK: Header

    /// Pastel card in the block's color with the category menu and the title.
    private var header: some View {
        let dark = scheme == .dark
        let fill = NSColor(hex: dark ? "#1B1B1D" : "#FFFFFF").mixed(with: NSColor(hex: hex), fraction: dark ? 0.34 : 0.22)
        let deep = NSColor(hex: hex).mixed(with: dark ? .white : .black, fraction: dark ? 0.35 : 0.42)

        return VStack(alignment: .leading, spacing: 10) {
            Menu {
                Button("None") { setCategory(nil) }
                Divider()
                ForEach(categories) { c in
                    Button(c.name) { setCategory(c) }
                }
            } label: {
                HStack(spacing: 6) {
                    Circle().fill(color).frame(width: 8, height: 8)
                    Text(block.category?.name ?? String(localized: "None"))
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .opacity(0.6)
                }
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color(nsColor: deep))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color(nsColor: deep).opacity(0.1)))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()

            TextField("Title", text: $block.title, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(nsColor: deep))
                .lineLimit(1...3)
                .focused($titleFocused)

            Text(verbatim: "\(TimeFmt.range(block.startMin, block.endMin)) · \(TimeFmt.duration(block.plannedMinutes))")
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(Color(nsColor: deep).opacity(0.65))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(nsColor: fill)))
    }

    private func setCategory(_ c: StudyCategory?) {
        // Keep the auto-title in sync if the user hasn't renamed the block.
        if block.title == block.category?.name, let c { block.title = c.name }
        block.category = c
        state.lastCategoryID = c?.uid
    }

    // MARK: Time

    private var time: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TimeChip(label: "Start", minutes: block.startMin,
                         options: Array(TimelineBounds.slots.dropLast())) { newStart in
                    let length = block.plannedMinutes
                    block.startMin = newStart
                    block.endMin = min(newStart + length, TimelineBounds.end)
                }
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                TimeChip(label: "End", minutes: block.endMin,
                         options: TimelineBounds.slots.filter { $0 > block.startMin }) { block.endMin = $0 }
            }
            HStack(spacing: 6) {
                ForEach([30, 45, 60, 90, 120], id: \.self) { length in
                    let fits = block.startMin + length <= TimelineBounds.end
                    let on = block.plannedMinutes == length
                    Button {
                        withAnimation(.spring(duration: 0.25)) { block.endMin = block.startMin + length }
                    } label: {
                        Text(TimeFmt.duration(length))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(on ? Theme.onInk : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(on ? Theme.ink : Theme.cardMuted))
                    }
                    .buttonStyle(.plain)
                    .disabled(!fits)
                    .opacity(fits ? 1 : 0.4)
                }
            }
        }
    }

    // MARK: Status

    private var status: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(BlockStatus.allCases) { s in
                    StatusTile(status: s, isOn: block.status == s, color: color) {
                        block.setStatus(s)
                    }
                }
            }
            if block.status != .planned {
                HStack {
                    Text("Actual minutes")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    RoundIconButton(symbol: "minus") { adjustActual(-5) }
                    TextField("Minutes", value: actualBinding, format: .number)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .semibold).monospacedDigit())
                        .multilineTextAlignment(.center)
                        .frame(width: 44)
                    RoundIconButton(symbol: "plus") { adjustActual(5) }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if block.needsReview {
                Label("This block has ended. How did it go?", systemImage: "clock.badge.questionmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .transition(.opacity)
            }
        }
    }

    private var actualBinding: Binding<Int> {
        Binding(
            get: { block.actualMinutes ?? block.plannedMinutes },
            set: { block.actualMinutes = min(max(0, $0), 1080) }
        )
    }

    private func adjustActual(_ delta: Int) {
        actualBinding.wrappedValue += delta
    }

    // MARK: Note

    private var note: some View {
        TextEditor(text: $block.note)
            .font(.system(size: 13))
            .scrollContentBackground(.hidden)
            .focused($noteFocused)
            .frame(minHeight: 90)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.cardMuted))
            .overlay(alignment: .topLeading) {
                if block.note.isEmpty && !noteFocused {
                    Text("Add a note…")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
    }

    // MARK: Actions

    private var actions: some View {
        HStack(spacing: 8) {
            Button { state.duplicate(block) } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card))
            }
            Button(role: .destructive) { state.delete(block) } label: {
                Label("Delete", systemImage: "trash")
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.danger.opacity(0.1)))
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .buttonStyle(.plain)
    }
}

/// White rounded section of the inspector with a small caption above its content.
private struct InspectorCard<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
    }
}

/// A time with its caption; clicking it lists the 15-minute slots.
private struct TimeChip: View {
    let label: LocalizedStringKey
    let minutes: Int
    let options: [Int]
    var onPick: (Int) -> Void

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { m in
                Button(TimeFmt.hm(m)) { onPick(m) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(TimeFmt.hm(minutes))
                    .font(.system(size: 20, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.cardMuted))
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }
}

/// One of the four statuses as a tappable tile; the chosen one fills with the block's color.
private struct StatusTile: View {
    let status: BlockStatus
    let isOn: Bool
    let color: Color
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(status.title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            // Planned fills with ink, which turns light in dark mode, so its label inverts with it.
            .foregroundStyle(isOn ? (status == .planned ? Theme.onInk : .white) : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isOn ? fill : (hovering ? Theme.cardMuted.opacity(0.7) : Theme.cardMuted))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(status.actionTitle)
    }

    private var fill: Color {
        switch status {
        case .planned: Theme.ink
        case .done: Theme.success
        case .partial: color
        case .skipped: Color.secondary
        }
    }

    private var symbol: String {
        switch status {
        case .planned: "circle"
        case .done: "checkmark.circle.fill"
        case .partial: "circle.lefthalf.filled"
        case .skipped: "minus.circle"
        }
    }
}

/// Small round button with a symbol, for steppers.
private struct RoundIconButton: View {
    let symbol: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 24, height: 24)
                .background(Circle().fill(Theme.cardMuted))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct DaySummary: View {
    let blocks: [TimeBlock]
    let categories: [StudyCategory]
    @Environment(AppState.self) private var state

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if blocks.isEmpty {
                    ContentUnavailableView(
                        "No blocks yet",
                        systemImage: "calendar.badge.plus",
                        description: Text("Drag on the timeline to create a block, press ⌘N, or apply a template (⇧⌘T).")
                    )
                    .padding(.top, 40)
                } else {
                    totals
                    InspectorCard(title: "By category") { breakdown }
                    InspectorCard(title: "Schedule") { schedule }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
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
            DotNumber(value: value, dot: 2.4)
                .foregroundStyle(color)
                .frame(height: 20, alignment: .bottomLeading)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
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
