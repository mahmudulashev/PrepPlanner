import SwiftUI
import SwiftData

struct PlannerView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 16) {
            PlannerHeader(day: state.day)
            DayTimeline(day: state.day)
                .card(padding: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle("Planner")
        .toolbar { toolbar }
        .inspector(isPresented: $state.showInspector) {
            BlockInspector(day: state.day)
                .inspectorColumnWidth(min: 270, ideal: 310, max: 400)
        }
        .sheet(isPresented: $state.showSaveTemplate) { SaveTemplateSheet() }
        .sheet(isPresented: $state.showApplyTemplate) { ApplyTemplateSheet() }
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
            Menu {
                Button("Save Day as Template…") { state.showSaveTemplate = true }
                Button("Apply Template…") { state.showApplyTemplate = true }
            } label: {
                Label("Templates", systemImage: "square.on.square")
            }
            .help("Day templates")
        }
        ToolbarItem {
            Button { state.newBlockAtNextFreeSlot() } label: { Label("New Block", systemImage: "plus") }
                .help("New block (⌘N)")
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
