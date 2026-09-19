import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        NavigationSplitView {
            List(selection: $state.section) {
                Section("Prep") {
                    ForEach(SidebarSection.allCases) { section in
                        Label(section.title, systemImage: section.symbol)
                            .tag(section)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
            .safeAreaInset(edge: .bottom) {
                SidebarCountdown()
                    .padding(12)
            }
        } detail: {
            detail
        }
        .tint(Theme.accent)
    }

    @ViewBuilder
    private var detail: some View {
        switch state.section ?? .planner {
        case .planner:
            PlannerView()
        case .habits:
            ComingSoonView(title: "Habits", symbol: "checkmark.circle", phase: 4)
        case .results:
            ComingSoonView(title: "Results", symbol: "graduationcap", phase: 2)
        case .errors:
            ComingSoonView(title: "Error Log", symbol: "exclamationmark.bubble", phase: 2)
        case .analytics:
            ComingSoonView(title: "Analytics", symbol: "chart.xyaxis.line", phase: 3)
        }
    }
}

private struct SidebarCountdown: View {
    @Query private var settings: [AppSettings]

    var body: some View {
        if let s = settings.first {
            VStack(alignment: .leading, spacing: 6) {
                row("IELTS", date: s.ieltsDate, color: Theme.accent)
                row("SAT", date: s.satDate, color: Theme.ink)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.cardMuted))
        }
    }

    private func row(_ exam: String, date: Date, color: Color) -> some View {
        let days = Countdown.days(to: date)
        return HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(exam).font(.callout.weight(.semibold))
            Spacer()
            Text(days >= 0 ? "\(days)d" : "done")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

private struct ComingSoonView: View {
    let title: String
    let symbol: String
    let phase: Int

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol,
                               description: Text("This screen is built in Phase \(phase)."))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .navigationTitle(title)
    }
}
