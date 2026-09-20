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

    /// Shows the in-app reminder for blocks about to start, but only when system notifications don't work.
    private func checkReminders(_ blocks: [TimeBlock]) {
        guard !NotificationScheduler.shared.systemDeliveryWorks,
              let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first,
              settings.notificationsEnabled else { return }
        let lead = TimeInterval(settings.notificationLeadMinutes * 60)
        for block in blocks where block.status == .planned {
            let fire = block.startDate.addingTimeInterval(-lead)
            guard fire <= now, now.timeIntervalSince(fire) < 120 else { continue }
            let title = block.title.isEmpty ? String(localized: "Untitled") : block.title
            InAppReminder.shared.show(
                title: String(localized: "Starts in \(settings.notificationLeadMinutes) min: \(title)"),
                subtitle: [TimeFmt.range(block.startMin, block.endMin), block.category?.name].compactMap { $0 }.joined(separator: " · "),
                colorHex: block.category?.colorHex ?? "#F4852B",
                key: "\(block.uid.uuidString)-\(block.startMin)"
            )
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
