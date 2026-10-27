import SwiftUI
import SwiftData

struct PlannerView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 14) {
            PlannerHeader(day: state.day)
            VStack(spacing: 0) {
                ScheduleBar(day: state.day)
                DayTimeline(day: state.day)
            }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 12, y: 3)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle("Planner")
        .toolbar { toolbar }
        .inspector(isPresented: $state.showInspector) {
            BlockInspector(day: state.day)
                .inspectorColumnWidth(min: 270, ideal: 310, max: 400)
        }
        .sheet(isPresented: $state.showSaveTemplate) { SaveTemplateSheet().tint(Theme.accent) }
        .sheet(isPresented: $state.showApplyTemplate) { ApplyTemplateSheet().tint(Theme.accent) }
        .overlay(alignment: .bottom) { toast }
        .animation(.spring(duration: 0.3), value: state.toast)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button { state.shiftDay(-1) } label: { Label("Previous Day", systemImage: "chevron.left") }
                .help("Previous day (⌘[)")
            Button("Today") { state.goToday() }
                .help("Jump to today (⌘T)")
            Button { state.shiftDay(1) } label: { Label("Next Day", systemImage: "chevron.right") }
                .help("Next day (⌘])")
        }
        ToolbarItem {
            Button { state.showInspector.toggle() } label: { Label("Inspector", systemImage: "sidebar.trailing") }
                .help("Show or hide the inspector (⌥⌘I)")
        }
    }

    @ViewBuilder
    private var toast: some View {
        if let message = state.toast {
            Text(message)
                .font(.callout.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(Theme.ink))
                .foregroundStyle(Theme.onInk)
                .padding(.bottom, 32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// Title row of the schedule card, with the day's actions as pills.
private struct ScheduleBar: View {
    let day: Date
    @Environment(AppState.self) private var state
    @Query private var blocks: [TimeBlock]

    init(day: Date) {
        self.day = day
        let d = day
        _blocks = Query(filter: #Predicate<TimeBlock> { $0.day == d })
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("Schedule")
                .font(.system(size: 17, weight: .bold))
            Text("^[\(blocks.count) block](inflect: true)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                Button("Save Day as Template…") { state.showSaveTemplate = true }
                Button("Apply Template…") { state.showApplyTemplate = true }
            } label: {
                Label("Templates", systemImage: "square.on.square")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.cardMuted))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Day templates")

            Button { state.newBlockAtNextFreeSlot() } label: {
                Label("New block", systemImage: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.onHighlight)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.highlight))
            }
            .buttonStyle(.plain)
            .help("New block (⌘N)")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 6)
    }
}
