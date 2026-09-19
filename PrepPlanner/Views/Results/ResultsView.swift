import SwiftUI
import SwiftData

struct ResultsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        Group {
            switch state.resultsTab {
            case .ielts: IELTSResults()
            case .sat: SATResults()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle("Results")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Exam", selection: $state.resultsTab) {
                    ForEach(ResultsTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            ToolbarItem {
                Button {
                    state.editor = state.resultsTab == .ielts ? .ielts(nil) : .sat(nil)
                } label: {
                    Label("New Mock", systemImage: "plus")
                }
                .help(state.resultsTab == .ielts ? "New IELTS mock (⌘R)" : "New SAT mock (⇧⌘R)")
            }
        }
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
                Button("Add IELTS Mock") { state.editor = .ielts(nil) }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            VStack(spacing: 16) {
                summary
                table.card(padding: 0)
            }
            .confirmationDialog(
                pendingDelete.count == 1 ? "Delete this mock?" : "Delete \(pendingDelete.count) mocks?",
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
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("LATEST OVERALL")
                    .font(.caption.weight(.semibold))
                    .opacity(0.85)
                Text(Band.format(latest.overallBand))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(overallSubtitle(latest: latest, previous: previous, target: s?.targetOverall))
                    .font(.caption)
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .padding(16)
            .frame(width: 190, height: 120, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).fill(Theme.accent))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)

            ForEach(Skill.ielts) { skill in
                SkillBandCard(
                    skill: skill,
                    band: latest.band(for: skill) ?? 0,
                    previous: previous?.band(for: skill),
                    target: s?.target(for: skill)
                )
            }
        }
    }

    private func overallSubtitle(latest: IELTSMock, previous: IELTSMock?, target: Double?) -> String {
        var parts: [String] = [latest.date.formatted(.dateTime.day().month(.abbreviated))]
        if let p = previous { parts.append("\(Band.formatDelta(latest.overallBand - p.overallBand)) vs last") }
        if let t = target { parts.append("target \(Band.format(t))") }
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
        .tableStyle(.inset)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: skill.symbol).foregroundStyle(skill.color)
                Text(skill.title).font(.callout.weight(.semibold))
                Spacer()
                if let p = previous {
                    let d = band - p
                    Text(Band.formatDelta(d))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(d > 0 ? Theme.success : d < 0 ? Theme.danger : .secondary)
                }
            }
            Text(Band.format(band))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
            BandProgress(band: band, target: target, color: skill.color)
            if let t = target {
                Text(band >= t ? "Target \(Band.format(t)) reached" : "\(Band.format(t - band)) to target \(Band.format(t))")
                    .font(.caption)
                    .foregroundStyle(band >= t ? Theme.success : .secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 88)
        .card(padding: 14)
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
                Button("Add SAT Mock") { state.editor = .sat(nil) }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            VStack(spacing: 16) {
                summary
                table.card(padding: 0)
            }
            .confirmationDialog(
                pendingDelete.count == 1 ? "Delete this mock?" : "Delete \(pendingDelete.count) mocks?",
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
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("LATEST TOTAL")
                    .font(.caption.weight(.semibold))
                    .opacity(0.8)
                Text("\(latest.total)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(gap > 0 ? "\(gap) to target \(target)" : "Target \(target) reached 🎉")
                    .font(.caption)
                    .opacity(0.8)
            }
            .foregroundStyle(Theme.onInk)
            .padding(16)
            .frame(width: 190, height: 120, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).fill(Theme.ink))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)

            sectionCard(.satRW, score: latest.readingWriting, previous: previous?.readingWriting)
            sectionCard(.satMath, score: latest.math, previous: previous?.math)

            VStack(alignment: .leading, spacing: 6) {
                Text("Best total").font(.callout.weight(.semibold))
                Text("\(best)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("\(mocks.count) mock\(mocks.count == 1 ? "" : "s") logged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 88)
            .card(padding: 14)
        }
    }

    private func sectionCard(_ skill: Skill, score: Int, previous: Int?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: skill.symbol).foregroundStyle(skill.color)
                Text(skill.title).font(.callout.weight(.semibold))
                Spacer()
                if let p = previous {
                    let d = score - p
                    Text(SATScore.formatDelta(d))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(d > 0 ? Theme.success : d < 0 ? Theme.danger : .secondary)
                }
            }
            Text("\(score)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.cardMuted)
                    Capsule().fill(skill.color).frame(width: g.size.width * Double(score - 200) / 600)
                }
            }
            .frame(height: 8)
            Text("out of 800").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 88)
        .card(padding: 14)
    }

    private var table: some View {
        Table(mocks, selection: $selection) {
            TableColumn("Date") { m in
                Text(m.date.formatted(date: .abbreviated, time: .omitted))
            }
            .width(min: 90, ideal: 110)
            TableColumn("Reading & Writing") { m in
                Text("\(m.readingWriting)").monospacedDigit()
            }
            TableColumn("Math") { m in
                Text("\(m.math)").monospacedDigit()
            }
            TableColumn("Total") { m in
                Text("\(m.total)")
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
        .tableStyle(.inset)
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
