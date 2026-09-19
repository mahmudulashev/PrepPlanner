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
        .sheet(item: $state.editor) { sheet in
            switch sheet {
            case .ielts(let mock): IELTSEditor(mock: mock)
            case .sat(let mock): SATEditor(mock: mock)
            case .error(let entry, let prefill): ErrorEditor(entry: entry, prefill: prefill)
            case .habit(let habit): HabitEditor(habit: habit)
            }
        }
        .tint(Theme.accent)
    }

    @ViewBuilder
    private var detail: some View {
        switch state.section ?? .planner {
        case .planner:
            PlannerView()
        case .habits:
            HabitsView()
        case .results:
            ResultsView()
        case .errors:
            ErrorLogView()
        case .analytics:
            AnalyticsView()
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
