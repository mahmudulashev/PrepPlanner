import AppKit
import SwiftData
import UserNotifications

/// Schedules a local notification a few minutes before each planned block.
/// Rebuilds the queue whenever data is saved, the app becomes active, or every 15 minutes.
@MainActor
final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    private let prefix = "block-"
    /// How far ahead to schedule. Kept short so the system limit on pending notifications is never hit.
    private let horizonDays = 2
    private let maxPending = 50

    private var container: ModelContainer?
    private var pendingWork: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?
    /// Set when the system refuses to even ask for permission (unsigned build, app not registered, …).
    private(set) var lastError: String?
    /// False when macOS won't deliver notifications, so the app falls back to its own reminder window.
    private(set) var systemDeliveryWorks = true

    func start(container: ModelContainer) {
        self.container = container
        center.delegate = self
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleSoon() }
        })
        observers.append(nc.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleSoon() }
        })
        timer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleSoon() }
        }
        // Asking before the app has finished launching fails, so wait for the launch notification.
        if NSApp?.isRunning == true {
            scheduleSoon()
        } else {
            observers.append(nc.addObserver(forName: NSApplication.didFinishLaunchingNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleSoon() }
            })
        }
    }

    /// Debounced so a burst of edits triggers one reschedule.
    func scheduleSoon() {
        pendingWork?.cancel()
        pendingWork = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await self?.reschedule()
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    private func reschedule() async {
        guard let context = container?.mainContext else { return }
        let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first

        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })

        guard let settings, settings.notificationsEnabled else { return }

        var status = await authorizationStatus()
        if status == .notDetermined {
            do {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                lastError = error.localizedDescription
            }
            status = await authorizationStatus()
        }
        systemDeliveryWorks = status == .authorized || status == .provisional
        guard systemDeliveryWorks else { return }

        let now = Date()
        let lead = TimeInterval(settings.notificationLeadMinutes * 60)
        let first = now.startOfDay
        let last = first.adding(days: horizonDays)
        let descriptor = FetchDescriptor<TimeBlock>(
            predicate: #Predicate { $0.day >= first && $0.day <= last },
            sortBy: [SortDescriptor(\.day), SortDescriptor(\.startMin)]
        )
        let blocks = (try? context.fetch(descriptor)) ?? []

        var added = 0
        for block in blocks where block.status == .planned {
            let fireDate = block.startDate.addingTimeInterval(-lead)
            guard fireDate > now, added < maxPending else { continue }

            let content = UNMutableNotificationContent()
            let title = block.title.isEmpty ? String(localized: "Untitled") : block.title
            content.title = String(localized: "Starts in \(settings.notificationLeadMinutes) min: \(title)")
            var body = TimeFmt.range(block.startMin, block.endMin)
            if let category = block.category?.name, category != block.title { body += " · \(category)" }
            if !block.note.isEmpty { body += "\n\(block.note)" }
            content.body = body
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let id = "\(prefix)\(block.uid.uuidString)-\(block.startMin)"
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            added += 1
        }
    }

    // Show the banner even while PrepPlanner is the active app.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
