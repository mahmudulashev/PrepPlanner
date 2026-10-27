import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        NavigationSplitView {
            AppSidebar()
                .navigationSplitViewColumnWidth(min: 200, ideal: 224, max: 280)
        } detail: {
            ZStack {
                detail
                    .id(state.section)
                    .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.18), value: state.section)
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

extension SidebarSection {
    /// Tile color for the sidebar icon.
    var color: Color {
        switch self {
        case .planner: Theme.accent
        case .habits: Theme.success
        case .results: Color(hex: "#7B61D9")
        case .errors: Color(hex: "#E5484D")
        case .analytics: Color(hex: "#3F8FD2")
        }
    }
}

// MARK: - Sidebar

/// App sidebar: brand, sections with colored icon tiles and live badges, and the exam
/// countdown at the bottom. Drawn by hand so the selection can slide between rows.
struct AppSidebar: View {
    @Environment(AppState.self) private var state
    @Query private var todayBlocks: [TimeBlock]
    @Query private var habits: [Habit]
    @Namespace private var selection

    init() {
        let today = Date().startOfDay
        _todayBlocks = Query(filter: #Predicate<TimeBlock> { $0.day == today })
        _habits = Query(filter: #Predicate<Habit> { !$0.isArchived })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            brand
                .padding(.horizontal, 8)
                .padding(.bottom, 14)

            ForEach(SidebarSection.allCases) { section in
                row(section)
            }

            Spacer(minLength: 12)
            ExamCountdownCard()
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    private var brand: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "PrepPlanner")
                    .font(.system(size: 13, weight: .bold))
                Text(verbatim: "IELTS · SAT")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func row(_ section: SidebarSection) -> some View {
        let isSelected = (state.section ?? .planner) == section
        return SidebarRow(section: section, isSelected: isSelected, badge: badge(for: section), namespace: selection) {
            withAnimation(.spring(duration: 0.3, bounce: 0.15)) { state.section = section }
        }
    }

    private func badge(for section: SidebarSection) -> Text? {
        switch section {
        case .planner:
            // Read each time the sidebar redraws; good enough for a count, cheap to compute.
            let review = todayBlocks.filter(\.needsReview).count
            return review > 0 ? Text(verbatim: "\(review)") : nil
        case .habits:
            let today = Date().startOfDay
            let left = habits.filter { h in !h.checks.contains { $0.day == today } }.count
            return left > 0 ? Text(verbatim: "\(left)") : nil
        default:
            return nil
        }
    }
}

private struct SidebarRow: View {
    let section: SidebarSection
    let isSelected: Bool
    let badge: Text?
    let namespace: Namespace.ID
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.symbol)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(section.color.gradient)
                    )
                Text(section.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let badge {
                    badge
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundStyle(isSelected ? Theme.onHighlight : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(isSelected ? Theme.highlight : Color.primary.opacity(0.08)))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.09))
                        .matchedGeometryEffect(id: "selection", in: namespace)
                } else if hovering {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(section.title + " (⌘" + String(section.shortcut.character) + ")")
    }
}

/// Dark card with the days left to each exam; the nearer one is lit.
private struct ExamCountdownCard: View {
    @Query private var settings: [AppSettings]

    var body: some View {
        if let s = settings.first {
            let exams = [("IELTS", Countdown.days(to: s.ieltsDate)), ("SAT", Countdown.days(to: s.satDate))]
            let next = exams.filter { $0.1 >= 0 }.min { $0.1 < $1.1 }?.0
            VStack(alignment: .leading, spacing: 10) {
                Text("Exams")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                ForEach(exams, id: \.0) { name, days in
                    HStack(alignment: .bottom) {
                        Text(verbatim: name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(days >= 0 ? 0.9 : 0.4))
                        Spacer()
                        if days >= 0 {
                            DotNumber(value: String(localized: "\(days)d"), dot: 2.2)
                                .foregroundStyle(name == next ? Theme.highlight : .white.opacity(0.85))
                        } else {
                            Text("done")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HeroGlow(colors: [Color(hex: "#7B61D9"), Theme.accent]))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
