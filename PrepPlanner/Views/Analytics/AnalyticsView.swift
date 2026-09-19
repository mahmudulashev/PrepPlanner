import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @Query private var blocks: [TimeBlock]
    @Query(sort: \StudyCategory.order) private var categories: [StudyCategory]
    @Query(sort: \IELTSMock.date) private var ielts: [IELTSMock]
    @Query(sort: \SATMock.date) private var sat: [SATMock]
    @Query(sort: \ErrorEntry.date, order: .reverse) private var errors: [ErrorEntry]
    @Query private var settings: [AppSettings]

    @State private var granularity: Granularity = .day
    @State private var errorSkill: Skill?
    @State private var errorRange: ErrorDateRange = .all
    @State private var satShowsSections = false

    init() {
        // 12 weeks of history is enough for every chart and insight on this screen.
        let cutoff = Date().startOfDay.adding(days: -84)
        _blocks = Query(filter: #Predicate<TimeBlock> { $0.day >= cutoff })
    }

    var body: some View {
        let now = Date()
        ScrollView {
            VStack(spacing: 16) {
                kpis(now: now)
                InsightsCard(insights: InsightEngine.make(blocks: blocks, ielts: ielts, sat: sat, errors: errors,
                                                          settings: settings.first, now: now))
                hoursCard(now: now)
                HStack(alignment: .top, spacing: 16) {
                    completionCard(now: now)
                    errorsCard(now: now)
                }
                HStack(alignment: .top, spacing: 16) {
                    ieltsCard
                    satCard
                }
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("Analytics")
    }

    // MARK: KPIs

    private func kpis(now: Date) -> some View {
        let weekStart = Analytics.startOfWeek(now)
        let week = blocks.filter { $0.isStudy && $0.day >= weekStart && $0.day < weekStart.adding(days: 7) }
        let planned = week.reduce(0) { $0 + $1.plannedMinutes }
        let actual = week.reduce(0) { $0 + $1.effectiveActual }
        let rate = Analytics.completionRate(week)
        let errorsThisWeek = errors.filter { $0.date >= now.startOfDay.adding(days: -6) }.count
        let s = settings.first

        return HStack(spacing: 14) {
            KPITile(title: "Study this week", value: TimeFmt.hours(actual),
                    detail: String(localized: "of \(TimeFmt.hours(planned)) planned"),
                    fill: Theme.accent, foreground: .white)
            KPITile(title: "Completion this week", value: rate.map { "\(Int(($0 * 100).rounded()))%" } ?? "–",
                    detail: String(localized: "Done 100% · Partial 50% · Skipped 0%"))
            KPITile(title: "Latest IELTS", value: ielts.last.map { Band.format($0.overallBand) } ?? "–",
                    detail: s.map { String(localized: "Target \(Band.format($0.targetOverall))") } ?? "")
            KPITile(title: "Latest SAT", value: sat.last.map { "\($0.total)" } ?? "–",
                    detail: String(localized: "Target \(String(s?.targetSAT ?? 1450))"))
            KPITile(title: "Errors, last 7 days", value: "\(errorsThisWeek)",
                    detail: String(localized: "\(errors.count) logged in total"),
                    fill: Theme.ink, foreground: Theme.onInk)
        }
    }

    // MARK: Planned vs actual

    private func hoursCard(now: Date) -> some View {
        let periods = Analytics.periods(granularity, count: granularity == .day ? 14 : 8, now: now)
        let rows = Analytics.hours(blocks: blocks, granularity: granularity, periods: periods)
        let unit: Calendar.Component = granularity == .day ? .day : .weekOfYear
        let scale = categoryScale(for: rows)
        let end = granularity == .day ? periods.last!.adding(days: 1) : periods.last!.adding(days: 7)

        return ChartCard(title: "Planned vs actual hours",
                         subtitle: "Study categories only. Light bars are planned, solid bars are actual.") {
            Picker("Granularity", selection: $granularity) {
                ForEach(Granularity.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
        } content: {
            if rows.isEmpty {
                EmptyChart(text: "No study blocks in this period yet.")
            } else {
                Chart(rows) { r in
                    BarMark(
                        x: .value("Period", r.period, unit: unit),
                        y: .value("Hours", r.hours)
                    )
                    .foregroundStyle(by: .value("Category", r.category))
                    .position(by: .value("Kind", r.kind.title))
                    .opacity(r.kind == .planned ? 0.38 : 1)
                    .cornerRadius(3)
                }
                .chartForegroundStyleScale(domain: scale.names, range: scale.colors)
                .chartXScale(domain: periods.first!...end)
                .chartXAxis {
                    AxisMarks(values: .stride(by: unit, count: granularity == .day ? 2 : 1)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                    }
                }
                .chartYAxis {
                    AxisMarks { v in
                        AxisGridLine()
                        AxisValueLabel { if let h = v.as(Double.self) { Text(TimeFmt.hours(Int(h * 60))) } }
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 260)
            }
        }
    }

    private func categoryScale(for rows: [HoursRow]) -> (names: [String], colors: [Color]) {
        let present = Set(rows.map(\.category))
        var names: [String] = []
        var colors: [Color] = []
        for c in categories where present.contains(c.name) && !names.contains(c.name) {
            names.append(c.name)
            colors.append(Color(hex: c.colorHex))
        }
        for name in present.sorted() where !names.contains(name) {
            names.append(name)
            colors.append(.gray)
        }
        return (names, colors)
    }

    // MARK: Completion

    private func completionCard(now: Date) -> some View {
        let points = Analytics.completion(blocks: blocks, days: 30, now: now)
        return ChartCard(title: "Completion rate per day",
                         subtitle: "Last 30 days · Done 100%, Partial 50%, Skipped 0%") {
            EmptyView()
        } content: {
            if points.isEmpty {
                EmptyChart(text: "Mark blocks as Done, Partial or Skipped to see your completion rate.")
            } else {
                Chart(points) { p in
                    AreaMark(x: .value("Day", p.day, unit: .day), y: .value("Completion", p.rate))
                        .foregroundStyle(LinearGradient(colors: [Theme.success.opacity(0.3), Theme.success.opacity(0.02)],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Day", p.day, unit: .day), y: .value("Completion", p.rate))
                        .foregroundStyle(Theme.success)
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    PointMark(x: .value("Day", p.day, unit: .day), y: .value("Completion", p.rate))
                        .foregroundStyle(Theme.success)
                        .symbolSize(30)
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(values: [0, 0.25, 0.5, 0.75, 1]) { v in
                        AxisGridLine()
                        AxisValueLabel { if let d = v.as(Double.self) { Text(d, format: .percent) } }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 220)
            }
        }
    }

    // MARK: Errors

    private func errorsCard(now: Date) -> some View {
        let rows = Analytics.errorCounts(errors, skill: errorSkill, since: errorRange.startDate, limit: 8)
        return ChartCard(title: "Most frequent error types", subtitle: nil) {
            HStack(spacing: 8) {
                Picker("Skill", selection: $errorSkill) {
                    Text("All skills").tag(Skill?.none)
                    Divider()
                    ForEach(Skill.allCases) { Text($0.title).tag(Optional($0)) }
                }
                .labelsHidden()
                .frame(width: 120)
                Picker("Range", selection: $errorRange) {
                    Text("7 days").tag(ErrorDateRange.week)
                    Text("All").tag(ErrorDateRange.all)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 110)
            }
        } content: {
            if rows.isEmpty {
                EmptyChart(text: "No typed errors for this filter.")
            } else {
                Chart(rows) { r in
                    BarMark(
                        x: .value("Count", r.count),
                        y: .value("Type", errorSkill == nil ? "\(r.name) · \(r.skill.title)" : r.name)
                    )
                    .foregroundStyle(r.skill.color)
                    .cornerRadius(4)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("\(r.count)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: max(120, CGFloat(rows.count) * 28))
            }
        }
    }

    // MARK: IELTS

    private var ieltsCard: some View {
        let points = Analytics.ieltsPoints(ielts)
        let s = settings.first
        // Skills that share a target get a single dashed line.
        let targets = Dictionary(grouping: Skill.ielts) { s?.target(for: $0) ?? 0 }
            .sorted { $0.key > $1.key }
        let low = min(4.0, (points.map(\.value).min() ?? 4) - 0.5)

        return ChartCard(title: "IELTS bands", subtitle: "Dashed lines are your targets") {
            EmptyView()
        } content: {
            if ielts.isEmpty {
                EmptyChart(text: "Log IELTS mocks in Results to see your band trends.")
            } else {
                Chart {
                    ForEach(points) { p in
                        LineMark(x: .value("Date", p.date, unit: .day), y: .value("Band", p.value))
                            .foregroundStyle(by: .value("Skill", p.series))
                            .symbol(by: .value("Skill", p.series))
                            .interpolationMethod(.monotone)
                    }
                    ForEach(targets, id: \.key) { target, skills in
                        RuleMark(y: .value("Target", target))
                            .foregroundStyle(skills.count == 1 ? skills[0].color : .secondary)
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("\(skills.map(\.title).joined(separator: ", ")) \(Band.format(target))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .chartForegroundStyleScale(domain: Skill.ielts.map(\.title), range: Skill.ielts.map(\.color))
                .chartYScale(domain: low...9.3)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 240)
            }
        }
    }

    // MARK: SAT

    private var satCard: some View {
        let target = settings.first?.targetSAT ?? 1450
        let sections = Analytics.satSectionPoints(sat)
        let totals = sat.map { ScorePoint(date: $0.date, series: String(localized: "Total"), value: Double($0.total)) }
        let low = max(400, Double((sat.map(\.total).min() ?? 1000) - 100).rounded(.down))

        return ChartCard(title: "SAT scores",
                         subtitle: satShowsSections ? "Section scores (200–800)" : "Total with your target") {
            Picker("SAT view", selection: $satShowsSections) {
                Text("Total").tag(false)
                Text("Sections").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 150)
        } content: {
            if sat.isEmpty {
                EmptyChart(text: "Log SAT mocks in Results to see your score trends.")
            } else if satShowsSections {
                Chart(sections) { p in
                    LineMark(x: .value("Date", p.date, unit: .day), y: .value("Score", p.value))
                        .foregroundStyle(by: .value("Section", p.series))
                        .symbol(by: .value("Section", p.series))
                        .interpolationMethod(.monotone)
                }
                .chartForegroundStyleScale(domain: Skill.sat.map(\.title), range: Skill.sat.map(\.color))
                .chartYScale(domain: 200...800)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 240)
            } else {
                Chart {
                    ForEach(totals) { p in
                        LineMark(x: .value("Date", p.date, unit: .day), y: .value("Total", p.value))
                            .foregroundStyle(Theme.ink)
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Date", p.date, unit: .day), y: .value("Total", p.value))
                            .foregroundStyle(Theme.ink)
                            .annotation(position: .top) {
                                Text(verbatim: String(Int(p.value))).font(.caption2.weight(.semibold))
                            }
                    }
                    RuleMark(y: .value("Target", target))
                        .foregroundStyle(Theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Target \(String(target))").font(.caption2).foregroundStyle(Theme.accent)
                        }
                }
                .chartYScale(domain: low...1600)
                .chartYAxis {
                    AxisMarks { v in
                        AxisGridLine()
                        AxisValueLabel { if let d = v.as(Double.self) { Text(verbatim: String(Int(d))) } }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 240)
            }
        }
    }
}

// MARK: - Building blocks

private struct ChartCard<Controls: View, Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    @ViewBuilder var controls: Controls
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                controls
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 18)
    }
}

private struct EmptyChart: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.cardMuted))
    }
}

private struct KPITile: View {
    let title: LocalizedStringKey
    let value: String
    let detail: String
    var fill: Color = Theme.card
    var foreground: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .opacity(0.75)
                .lineLimit(1)
            Text(verbatim: value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(verbatim: detail)
                .font(.caption)
                .opacity(0.75)
                .lineLimit(1)
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).fill(fill))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}

private struct InsightsCard: View {
    let insights: [Insight]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(Theme.accent)
                Text("Insights").font(.headline)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top),
                                GridItem(.flexible(), spacing: 12, alignment: .top)],
                      alignment: .leading, spacing: 10) {
                ForEach(insights) { insight in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: insight.symbol)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(color(insight.tone))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(color(insight.tone).opacity(0.15)))
                        Text(verbatim: insight.text)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 5)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 18)
    }

    private func color(_ tone: Insight.Tone) -> Color {
        switch tone {
        case .positive: Theme.success
        case .warning: Theme.accent
        case .info: .blue
        }
    }
}
