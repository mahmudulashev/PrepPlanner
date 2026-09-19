import Foundation

struct Insight: Identifiable {
    enum Tone { case positive, warning, info }

    let id = UUID()
    let tone: Tone
    let symbol: String
    let text: String
}

/// Short, rule-based observations shown on the Analytics screen.
enum InsightEngine {
    static func make(blocks: [TimeBlock], ielts: [IELTSMock], sat: [SATMock], errors: [ErrorEntry],
                     settings: AppSettings?, now: Date = Date()) -> [Insight] {
        var warnings: [Insight] = []
        var positives: [Insight] = []
        var infos: [Insight] = []

        let study = blocks.filter(\.isStudy)
        let weekStart = Analytics.startOfWeek(now)
        let lastWeekStart = weekStart.adding(days: -7)

        // Plan vs actual per skill for blocks that have already ended this week.
        let endedThisWeek = study.filter { $0.day >= weekStart && $0.endDate <= now }
        var onPlan: [(skill: Skill, actual: Int, planned: Int)] = []
        for skill in Skill.allCases {
            let items = endedThisWeek.filter { $0.category?.skill == skill }
            let planned = items.reduce(0) { $0 + $1.plannedMinutes }
            guard planned >= 60 else { continue }
            let actual = items.reduce(0) { $0 + $1.effectiveActual }
            let change = Double(actual - planned) / Double(planned)
            if change <= -0.2 {
                let pct = Int((-change * 100).rounded())
                warnings.append(Insight(
                    tone: .warning, symbol: "clock.badge.exclamationmark",
                    text: String(localized: "\(skill.title) time this week is \(pct)% below plan (\(TimeFmt.hours(actual)) of \(TimeFmt.hours(planned)))."))
                )
            } else if change >= -0.05 {
                onPlan.append((skill, actual, planned))
            }
        }
        if let best = onPlan.max(by: { $0.planned < $1.planned }) {
            positives.append(Insight(
                tone: .positive, symbol: "checkmark.seal",
                text: String(localized: "\(best.skill.title) is on plan this week (\(TimeFmt.hours(best.actual)) of \(TimeFmt.hours(best.planned)))."))
            )
        }

        // Blocks that ended but were never marked.
        let unmarked = blocks.filter { $0.needsReview && $0.day >= now.startOfDay.adding(days: -6) }.count
        if unmarked > 0 {
            infos.append(Insight(tone: .info, symbol: "checklist",
                                 text: String(localized: "Blocks from the last 7 days without a status: \(unmarked).")))
        }

        // Completion rate, this week vs last week.
        if let thisRate = Analytics.completionRate(study.filter { $0.day >= weekStart }) {
            let tp = Int((thisRate * 100).rounded())
            if let lastRate = Analytics.completionRate(study.filter { $0.day >= lastWeekStart && $0.day < weekStart }) {
                let lp = Int((lastRate * 100).rounded())
                let tone: Insight.Tone = tp >= lp ? .positive : (lp - tp >= 10 ? .warning : .info)
                let text = String(localized: "Completion rate this week is \(tp)% (last week \(lp)%).")
                let insight = Insight(tone: tone, symbol: "chart.line.uptrend.xyaxis", text: text)
                switch tone {
                case .positive: positives.append(insight)
                case .warning: warnings.append(insight)
                case .info: infos.append(insight)
                }
            } else {
                infos.append(Insight(tone: .info, symbol: "chart.line.uptrend.xyaxis",
                                     text: String(localized: "Completion rate this week is \(tp)%.")))
            }
        }

        // Most frequent error types over the last 30 days.
        let recentErrors = errors.filter { $0.date >= now.startOfDay.adding(days: -29) }
        for row in Analytics.errorCounts(recentErrors, skill: nil, since: nil, limit: 2) where row.count >= 2 {
            warnings.append(Insight(
                tone: .warning, symbol: "exclamationmark.bubble",
                text: String(localized: "Most frequent \(row.skill.title) error: \(row.name) (×\(row.count))."))
            )
        }

        // IELTS: change since the previous mock, and the biggest gap to target.
        if ielts.count >= 2 {
            let latest = ielts[ielts.count - 1], previous = ielts[ielts.count - 2]
            for skill in Skill.ielts {
                let d = (latest.band(for: skill) ?? 0) - (previous.band(for: skill) ?? 0)
                if d > 0 {
                    positives.append(Insight(tone: .positive, symbol: "arrow.up.right",
                                             text: String(localized: "\(skill.title) improved \(Band.formatDelta(d)) since last mock.")))
                } else if d < 0 {
                    warnings.append(Insight(tone: .warning, symbol: "arrow.down.right",
                                            text: String(localized: "\(skill.title) dropped \(Band.format(-d)) since last mock.")))
                }
            }
        }
        if let latest = ielts.last, let s = settings {
            let gaps = Skill.ielts.compactMap { skill -> (skill: Skill, band: Double, target: Double)? in
                guard let b = latest.band(for: skill), let t = s.target(for: skill), t > b else { return nil }
                return (skill, b, t)
            }
            if let worst = gaps.max(by: { ($0.target - $0.band) < ($1.target - $1.band) }) {
                warnings.append(Insight(
                    tone: .warning, symbol: "target",
                    text: String(localized: "Biggest gap to target: \(worst.skill.title) (\(Band.format(worst.band)) vs \(Band.format(worst.target)))."))
                )
            } else {
                positives.append(Insight(tone: .positive, symbol: "star",
                                         text: String(localized: "All four IELTS skills meet their targets in the latest mock.")))
            }
        }

        // SAT: change since the previous mock and distance to target.
        if let latest = sat.last {
            let target = settings?.targetSAT ?? 1450
            if sat.count >= 2 {
                let d = latest.total - sat[sat.count - 2].total
                if d > 0 {
                    positives.append(Insight(tone: .positive, symbol: "arrow.up.right",
                                             text: String(localized: "SAT total is up \(d) since last mock (\(String(latest.total))).")))
                } else if d < 0 {
                    warnings.append(Insight(tone: .warning, symbol: "arrow.down.right",
                                            text: String(localized: "SAT total is down \(-d) since last mock (\(String(latest.total))).")))
                }
            }
            if latest.total >= target {
                positives.append(Insight(tone: .positive, symbol: "star",
                                         text: String(localized: "Latest SAT total \(String(latest.total)) meets your \(String(target)) target.")))
            } else {
                infos.append(Insight(tone: .info, symbol: "target",
                                     text: String(localized: "\(target - latest.total) points to go to your SAT target of \(String(target)).")))
            }
        }

        // Exam coming up with no recent mock.
        if let s = settings {
            let twoWeeksAgo = now.startOfDay.adding(days: -14)
            let ieltsDays = Countdown.days(to: s.ieltsDate, from: now)
            if ieltsDays > 0 && ieltsDays <= 60 && (ielts.last?.date ?? .distantPast) < twoWeeksAgo {
                warnings.append(Insight(tone: .warning, symbol: "calendar.badge.exclamationmark",
                                        text: String(localized: "No IELTS mock in the last 14 days, and the exam is in \(ieltsDays) days.")))
            }
            let satDays = Countdown.days(to: s.satDate, from: now)
            if satDays > 0 && satDays <= 60 && (sat.last?.date ?? .distantPast) < twoWeeksAgo {
                warnings.append(Insight(tone: .warning, symbol: "calendar.badge.exclamationmark",
                                        text: String(localized: "No SAT mock in the last 14 days, and the exam is in \(satDays) days.")))
            }
        }

        let all = warnings + positives + infos
        if all.isEmpty {
            return [Insight(tone: .info, symbol: "lightbulb",
                            text: String(localized: "Plan blocks, mark their status and log mocks to see insights here."))]
        }
        return Array(all.prefix(8))
    }
}
