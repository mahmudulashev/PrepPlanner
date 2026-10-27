import SwiftUI
import SwiftData

struct ResultsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 16) {
            HeroBanner(title: Text("Results"),
                       subtitle: Text(state.resultsTab == .ielts ? "IELTS mocks" : "SAT mocks"),
                       colors: state.resultsTab == .ielts ? [Theme.accent, Color(hex: "#E0679A")]
                                                          : [Color(hex: "#7B61D9"), Color(hex: "#3F8FD2")]) {
                HStack(spacing: 10) {
                    PillToggle(selection: $state.resultsTab,
                               options: ResultsTab.allCases.map { ($0, $0.rawValue) })
                    PillButton(title: "New Mock") {
                        state.editor = state.resultsTab == .ielts ? .ielts(nil) : .sat(nil)
                    }
                    .help(state.resultsTab == .ielts ? "New IELTS mock (⌘R)" : "New SAT mock (⇧⌘R)")
                }
            }
            Group {
                switch state.resultsTab {
                case .ielts: IELTSResults()
                case .sat: SATResults()
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle("Results")
    }
}

// MARK: - IELTS

private struct IELTSResults: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var context
    @Query(sort: \IELTSMock.date, order: .reverse) private var mocks: [IELTSMock]
    @Query private var settings: [AppSettings]
    @State private var selection = Set<PersistentIdentifier>()
    @State private var pendingDelete: [IELTSMock] = []

    var body: some View {
        if mocks.isEmpty {
            ContentUnavailableView {
                Label("No IELTS mocks yet", systemImage: "graduationcap")
            } description: {
                Text("Enter raw Listening and Reading scores; bands and the overall score are calculated for you.")
            } actions: {
                PillButton(title: "Add IELTS Mock") { state.editor = .ielts(nil) }

            }
        } else {
            VStack(spacing: 16) {
                summary
                table.card(padding: 0)
            }
            .confirmationDialog(
                "Delete ^[\(pendingDelete.count) mock](inflect: true)?",
                isPresented: Binding(get: { !pendingDelete.isEmpty }, set: { if !$0 { pendingDelete = [] } })
            ) {
                Button("Delete", role: .destructive) {
                    pendingDelete.forEach(context.delete)
                    pendingDelete = []
                    selection = []
                }
            } message: {
                Text("Error log entries linked to it are kept but unlinked.")
            }
        }
    }

    private var summary: some View {
        let latest = mocks[0]
        let previous = mocks.count > 1 ? mocks[1] : nil
        let s = settings.first
        let cards = Skill.ielts.map { skill in
            SkillBandCard(
                skill: skill,
                band: latest.band(for: skill) ?? 0,
                previous: previous?.band(for: skill),
                target: s?.target(for: skill)
            )
        }
        let target = s?.targetOverall
        let hero = MetricCard(
            title: Text("Overall"),
            subtitle: Text(verbatim: overallSubtitle(latest: latest, previous: previous, target: nil)),
            value: Band.format(latest.overallBand),
            symbol: "graduationcap.fill",
            color: Theme.accent
        ) {
            VStack(alignment: .leading, spacing: 6) {
                BandProgress(band: latest.overallBand, target: target, color: Theme.accent)
                if let t = target {
                    Text(latest.overallBand >= t ? "Target \(Band.format(t)) reached" : "\(Band.format(t - latest.overallBand)) to target \(Band.format(t))")
                        .font(.caption)
                        .foregroundStyle(latest.overallBand >= t ? Theme.success : .secondary)
                        .lineLimit(1)
                }
            }
        }

        // All five across while they fit, then the hero over one row of four, then two by two.
        return ViewThatFits(in: .horizontal) {
            CardRow {
                hero
                ForEach(0..<cards.count, id: \.self) { cards[$0] }
            }
            VStack(alignment: .leading, spacing: 14) {
                CardRow { hero }
                CardRow { ForEach(0..<cards.count, id: \.self) { cards[$0] } }
            }
            VStack(alignment: .leading, spacing: 14) {
                CardRow { hero }
                CardRow { cards[0]; cards[1] }
                CardRow { cards[2]; cards[3] }
            }
        }
    }

    private func overallSubtitle(latest: IELTSMock, previous: IELTSMock?, target: Double?) -> String {
        var parts: [String] = [latest.date.formatted(.dateTime.day().month(.abbreviated))]
        if let p = previous { parts.append(String(localized: "\(Band.formatDelta(latest.overallBand - p.overallBand)) vs last")) }
        if let t = target { parts.append(String(localized: "target \(Band.format(t))")) }
        return parts.joined(separator: " · ")
    }

    private var table: some View {
        let target = settings.first
        return Table(mocks, selection: $selection) {
            TableColumn("Date") { m in
                Text(m.date.formatted(date: .abbreviated, time: .omitted))
            }
            .width(min: 90, ideal: 110)
            TableColumn("Listening") { m in
                rawCell(raw: m.listeningRaw, band: m.listeningBand, target: target?.targetListening)
            }
            TableColumn("Reading") { m in
                rawCell(raw: m.readingRaw, band: m.readingBand, target: target?.targetReading)
            }
            TableColumn("Writing") { m in
                criteriaCell(band: m.writingBand, criteria: m.writingCriteria, labels: ["TR", "CC", "LR", "GRA"],
                             target: target?.targetWriting)
            }
            TableColumn("Speaking") { m in
                criteriaCell(band: m.speakingBand, criteria: m.speakingCriteria, labels: ["FC", "LR", "GRA", "P"],
                             target: target?.targetSpeaking)
            }
            TableColumn("Overall") { m in
                BandBadge(band: m.overallBand, target: target?.targetOverall)
            }
            .width(70)
            TableColumn("Errors") { m in
                Text(m.errors.isEmpty ? "–" : "\(m.errors.count)")
                    .foregroundStyle(.secondary)
            }
            .width(50)
            TableColumn("Note") { m in
                Text(m.note).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: false))
        .scrollContentBackground(.hidden)
        .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
            let items = mocks.filter { ids.contains($0.persistentModelID) }
            if items.count == 1, let m = items.first {
                Button("Edit…") { state.editor = .ielts(m) }
                Button("Log Error for This Mock…") {
                    state.editor = .error(nil, ErrorPrefill(date: m.date, skill: .reading, ieltsMockID: m.uid))
                }
                Divider()
            }
            if !items.isEmpty {
                Button("Delete", role: .destructive) { pendingDelete = items }
            }
        } primaryAction: { ids in
            if let m = mocks.first(where: { ids.contains($0.persistentModelID) }) { state.editor = .ielts(m) }
        }
        .onDeleteCommand {
            pendingDelete = mocks.filter { selection.contains($0.persistentModelID) }
        }
    }

    private func rawCell(raw: Int, band: Double, target: Double?) -> some View {
        HStack(spacing: 6) {
            Text("\(raw)/40").monospacedDigit().foregroundStyle(.secondary)
            BandBadge(band: band, target: target)
        }
    }

    private func criteriaCell(band: Double, criteria: [Double?], labels: [String], target: Double?) -> some View {
        HStack(spacing: 6) {
            BandBadge(band: band, target: target)
            if criteria.contains(where: { $0 != nil }) {
                Text(zip(labels, criteria).map { "\($0) \($1.map(Band.format) ?? "–")" }.joined(separator: " "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .help(zip(labels, criteria).map { "\($0): \($1.map(Band.format) ?? "–")" }.joined(separator: "\n"))
    }
}

private struct SkillBandCard: View {
    let skill: Skill
    let band: Double
    let previous: Double?
    let target: Double?

    var body: some View {
        let delta = previous.map { band - $0 }
        MetricCard(
            title: Text(skill.title),
            subtitle: delta.map { Text("\(Band.formatDelta($0)) vs last") } ?? Text("latest"),
            subtitleTint: delta.map { $0 > 0 ? Theme.success : $0 < 0 ? Theme.danger : nil } ?? nil,
            value: Band.format(band),
            symbol: skill.symbol,
            color: skill.color
        ) {
            VStack(alignment: .leading, spacing: 6) {
                BandProgress(band: band, target: target, color: skill.color)
                if let t = target {
                    Text(band >= t ? "Target \(Band.format(t)) reached" : "\(Band.format(t - band)) to target \(Band.format(t))")
                        .font(.caption)
                        .foregroundStyle(band >= t ? Theme.success : .secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(minWidth: 150)
    }
}

/// Horizontal 0–9 bar with a tick at the target band.
private struct BandProgress: View {
    let band: Double
    let target: Double?
    let color: Color

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.cardMuted)
                Capsule().fill(color).frame(width: g.size.width * band / 9)
                if let t = target {
                    Rectangle()
                        .fill(Theme.ink)
                        .frame(width: 2, height: 12)
                        .offset(x: g.size.width * t / 9 - 1)
                }
            }
        }
        .frame(height: 8)
    }
}

// MARK: - SAT

private struct SATResults: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var context
    @Query(sort: \SATMock.date, order: .reverse) private var mocks: [SATMock]
    @Query private var settings: [AppSettings]
    @State private var selection = Set<PersistentIdentifier>()
    @State private var pendingDelete: [SATMock] = []

    private var target: Int { settings.first?.targetSAT ?? 1450 }

    var body: some View {
        if mocks.isEmpty {
            ContentUnavailableView {
                Label("No SAT mocks yet", systemImage: "graduationcap")
            } description: {
                Text("Enter your Reading & Writing and Math section scores; the total is calculated for you.")
            } actions: {
                PillButton(title: "Add SAT Mock") { state.editor = .sat(nil) }

            }
        } else {
            VStack(spacing: 16) {
                summary
                table.card(padding: 0)
            }
            .confirmationDialog(
                "Delete ^[\(pendingDelete.count) mock](inflect: true)?",
                isPresented: Binding(get: { !pendingDelete.isEmpty }, set: { if !$0 { pendingDelete = [] } })
            ) {
                Button("Delete", role: .destructive) {
                    pendingDelete.forEach(context.delete)
                    pendingDelete = []
                    selection = []
                }
            } message: {
                Text("Error log entries linked to it are kept but unlinked.")
            }
        }
    }

    private var summary: some View {
        let latest = mocks[0]
        let previous = mocks.count > 1 ? mocks[1] : nil
        let best = mocks.map(\.total).max() ?? latest.total
        let gap = target - latest.total
        let hero = MetricCard(
            title: Text("Total"),
            subtitle: gap > 0 ? Text("\(gap) to target \(String(target))") : Text("Target \(String(target)) reached"),
            subtitleTint: gap > 0 ? nil : Theme.success,
            value: String(latest.total),
            symbol: "graduationcap.fill",
            color: Color(hex: Skill.satMath.colorHex)
        ) {
            ProgressTrack(fraction: Double(latest.total - 400) / 1200, color: Color(hex: Skill.satMath.colorHex), height: 8)
        }

        return ViewThatFits(in: .horizontal) {
            CardRow {
                hero
                sectionCard(.satRW, score: latest.readingWriting, previous: previous?.readingWriting)
                sectionCard(.satMath, score: latest.math, previous: previous?.math)
                bestCard(best)
            }
            VStack(alignment: .leading, spacing: 14) {
                CardRow { hero }
                CardRow {
                    sectionCard(.satRW, score: latest.readingWriting, previous: previous?.readingWriting)
                    sectionCard(.satMath, score: latest.math, previous: previous?.math)
                    bestCard(best)
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                CardRow { hero }
                CardRow {
                    sectionCard(.satRW, score: latest.readingWriting, previous: previous?.readingWriting)
                    sectionCard(.satMath, score: latest.math, previous: previous?.math)
                }
                CardRow { bestCard(best) }
            }
        }
    }

    private func bestCard(_ best: Int) -> some View {
        MetricCard(title: Text("Best total"), subtitle: Text("^[\(mocks.count) mock](inflect: true) logged"),
                   value: String(best), symbol: "trophy.fill", color: Theme.success) {
            ProgressTrack(fraction: Double(best - 400) / 1200, color: Theme.success, height: 8)
        }
            .frame(minWidth: 150)
    }

    private func sectionCard(_ skill: Skill, score: Int, previous: Int?) -> some View {
        let delta = previous.map { score - $0 }
        return MetricCard(
            title: Text(skill.title),
            subtitle: delta.map { Text("\(SATScore.formatDelta($0)) vs last") } ?? Text("out of 800"),
            subtitleTint: delta.map { $0 > 0 ? Theme.success : $0 < 0 ? Theme.danger : nil } ?? nil,
            value: String(score),
            symbol: skill.symbol,
            color: skill.color
        ) {
            ProgressTrack(fraction: Double(score - 200) / 600, color: skill.color, height: 8)
        }
        .frame(minWidth: 150)
    }

    private var table: some View {
        Table(mocks, selection: $selection) {
            TableColumn("Date") { m in
                Text(m.date.formatted(date: .abbreviated, time: .omitted))
            }
            .width(min: 90, ideal: 110)
            TableColumn("Reading & Writing") { m in
                Text(verbatim: String(m.readingWriting)).monospacedDigit()
            }
            TableColumn("Math") { m in
                Text(verbatim: String(m.math)).monospacedDigit()
            }
            TableColumn("Total") { m in
                Text(verbatim: String(m.total))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(m.total >= target ? Theme.success.opacity(0.2) : Theme.cardMuted))
                    .foregroundStyle(m.total >= target ? Theme.success : .primary)
            }
            TableColumn("vs Target") { m in
                Text(SATScore.formatDelta(m.total - target))
                    .monospacedDigit()
                    .foregroundStyle(m.total >= target ? Theme.success : .secondary)
            }
            TableColumn("Errors") { m in
                Text(m.errors.isEmpty ? "–" : "\(m.errors.count)")
                    .foregroundStyle(.secondary)
            }
            .width(50)
            TableColumn("Note") { m in
                Text(m.note).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: false))
        .scrollContentBackground(.hidden)
        .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
            let items = mocks.filter { ids.contains($0.persistentModelID) }
            if items.count == 1, let m = items.first {
                Button("Edit…") { state.editor = .sat(m) }
                Button("Log Error for This Mock…") {
                    state.editor = .error(nil, ErrorPrefill(date: m.date, skill: .satRW, satMockID: m.uid))
                }
                Divider()
            }
            if !items.isEmpty {
                Button("Delete", role: .destructive) { pendingDelete = items }
            }
        } primaryAction: { ids in
            if let m = mocks.first(where: { ids.contains($0.persistentModelID) }) { state.editor = .sat(m) }
        }
        .onDeleteCommand {
            pendingDelete = mocks.filter { selection.contains($0.persistentModelID) }
        }
    }
}
