import Foundation
import Observation
import SwiftData

/// A copy of a block's display data, so the menu bar never holds on to live model objects.
struct BlockSnapshot: Equatable {
    let uid: UUID
    let title: String
    let category: String?
    let colorHex: String
    let startMin: Int
    let endMin: Int
    let start: Date
    let end: Date
    let status: BlockStatus

    init(_ block: TimeBlock) {
        uid = block.uid
        title = block.title.isEmpty ? String(localized: "Untitled") : block.title
        category = block.category?.name
        colorHex = block.category?.colorHex ?? "#8E8E93"
        startMin = block.startMin
        endMin = block.endMin
        start = block.startDate
        end = block.endDate
        status = block.status
    }
}

/// Tracks today's current, next and just-finished block for the menu bar.
@MainActor
@Observable
final class NowTracker {
    private(set) var now = Date()
    private(set) var current: BlockSnapshot?
    private(set) var next: BlockSnapshot?
    /// The most recent block that ended within the last hour and still has no status.
    private(set) var justEnded: BlockSnapshot?
    private(set) var plannedMinutes = 0
    private(set) var doneMinutes = 0

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var observer: NSObjectProtocol?

    init(context: ModelContext) {
        self.context = context
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        observer = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        now = Date()
        let today = now.startOfDay
        let descriptor = FetchDescriptor<TimeBlock>(
            predicate: #Predicate { $0.day == today },
            sortBy: [SortDescriptor(\.startMin)]
        )
        let blocks = (try? context.fetch(descriptor)) ?? []
        current = blocks.first { $0.startDate <= now && now < $0.endDate }.map(BlockSnapshot.init)
        next = blocks.first { $0.startDate > now }.map(BlockSnapshot.init)
        justEnded = blocks.last { $0.needsReview && now.timeIntervalSince($0.endDate) < 3600 }.map(BlockSnapshot.init)
        checkReminders(blocks)
        let study = blocks.filter(\.isStudy)
        plannedMinutes = study.reduce(0) { $0 + $1.plannedMinutes }
        doneMinutes = study.reduce(0) { $0 + $1.effectiveActual }
    }

    /// Shows the in-app reminder for blocks about to start or just finished,
    /// but only when system notifications don't work.
    private func checkReminders(_ blocks: [TimeBlock]) {
        guard !NotificationScheduler.shared.systemDeliveryWorks,
              let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first,
              settings.notificationsEnabled else { return }

        let lead = TimeInterval(settings.notificationLeadMinutes * 60)
        for block in blocks where block.status == .planned {
            let snapshot = BlockSnapshot(block)
            let subtitle = [TimeFmt.range(block.startMin, block.endMin), block.category?.name]
                .compactMap { $0 }.joined(separator: " · ")

            // About to start.
            let fire = block.startDate.addingTimeInterval(-lead)
            if fire <= now, now.timeIntervalSince(fire) < 120 {
                InAppReminder.shared.show(
                    key: "start-\(snapshot.uid.uuidString)-\(snapshot.startMin)",
                    content: InAppReminder.Content(
                        title: String(localized: "Starts in \(settings.notificationLeadMinutes) min: \(snapshot.title)"),
                        subtitle: subtitle,
                        colorHex: snapshot.colorHex,
                        symbol: "clock.badge",
                        actions: [
                            InAppReminder.Action(title: String(localized: "Snooze 5 min")) { InAppReminder.shared.snooze(minutes: 5) },
                            InAppReminder.Action(title: String(localized: "Open Planner"), isProminent: true) { InAppReminder.shared.openPlanner() },
                        ],
                        playSound: settings.reminderSound
                    )
                )
            }

            // Just finished and still unmarked: offer the three statuses.
            if settings.endOfBlockPrompt, block.endDate <= now, now.timeIntervalSince(block.endDate) < 120 {
                let uid = snapshot.uid
                InAppReminder.shared.show(
                    key: "end-\(uid.uuidString)-\(snapshot.endMin)",
                    content: InAppReminder.Content(
                        title: String(localized: "How did it go? \(snapshot.title)"),
                        subtitle: subtitle,
                        colorHex: snapshot.colorHex,
                        symbol: "checkmark.circle",
                        actions: BlockStatus.allCases.filter { $0 != .planned }.map { status in
                            InAppReminder.Action(title: status.title, isProminent: status == .done) { [weak self] in
                                self?.setStatus(status, for: uid)
                                InAppReminder.shared.dismiss()
                            }
                        },
                        autoDismiss: 40,
                        playSound: settings.reminderSound
                    )
                )
            }
        }
    }

    func setStatus(_ status: BlockStatus, for uid: UUID) {
        var descriptor = FetchDescriptor<TimeBlock>(predicate: #Predicate { $0.uid == uid })
        descriptor.fetchLimit = 1
        guard let block = try? context.fetch(descriptor).first else { return }
        block.setStatus(status)
        try? context.save()
        refresh()
    }

    /// Minutes left in the current block, rounded up.
    var minutesLeft: Int? {
        current.map { max(0, Int(($0.end.timeIntervalSince(now) / 60).rounded(.up))) }
    }
}
