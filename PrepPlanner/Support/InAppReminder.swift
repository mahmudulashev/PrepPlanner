import AppKit
import SwiftUI

/// Reminder shown by the app itself, because macOS won't deliver notifications for this build.
/// A panel slides in at the top-right, floats above full-screen apps, and fades out on its own.
@MainActor
final class InAppReminder {
    static let shared = InAppReminder()

    struct Action: Identifiable {
        let id = UUID()
        let title: String
        var isProminent = false
        /// Closes the reminder after running, unless the action re-shows it.
        let handler: () -> Void
    }

    struct Content {
        var title: String
        var subtitle: String
        var colorHex: String
        var symbol: String
        var actions: [Action] = []
        var autoDismiss: TimeInterval = 25
        var playSound = true
    }

    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?
    private var snoozeTask: Task<Void, Never>?
    private var lastContent: Content?
    /// Reminders already shown this session, so one block reminds once.
    private var shown = Set<String>()

    /// Shows a reminder unless the same key was already shown.
    func show(key: String, content: Content) {
        guard !shown.contains(key) else { return }
        shown.insert(key)
        present(content)
    }

    func showTest() {
        present(Content(
            title: String(localized: "Test reminder"),
            subtitle: String(localized: "This is how a reminder looks."),
            colorHex: "#F4852B",
            symbol: "bell.badge",
            actions: [Action(title: String(localized: "Dismiss"), handler: {})]
        ))
    }

    /// Hides the panel and shows the same reminder again later.
    func snooze(minutes: Int) {
        guard let content = lastContent else { return }
        dismiss()
        snoozeTask?.cancel()
        snoozeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Double(minutes) * 60))
            guard !Task.isCancelled else { return }
            var again = content
            again.title = String(localized: "Snoozed: \(content.title)")
            self?.present(again)
        }
    }

    func openPlanner() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain && $0.contentViewController != nil }) {
            window.makeKeyAndOrderFront(nil)
        }
        dismiss()
    }

    // MARK: Panel

    private func present(_ content: Content) {
        dismissTask?.cancel()
        panel?.orderOut(nil)
        lastContent = content

        let card = ReminderCard(content: content, onClose: { [weak self] in self?.dismiss() })
        let hosting = NSHostingView(rootView: card)
        let size = NSSize(width: 360, height: hosting.fittingSize.height)
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // Above full-screen apps, and visible on every Space.
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true

        let screen = NSScreen.main?.visibleFrame ?? .zero
        let target = NSPoint(x: screen.maxX - size.width - 20, y: screen.maxY - size.height - 20)
        panel.setFrameOrigin(NSPoint(x: target.x + 40, y: target.y))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrameOrigin(target)
            panel.animator().alphaValue = 1
        }
        self.panel = panel

        if content.playSound { NSSound(named: "Glass")?.play() }

        guard content.autoDismiss > 0 else { return }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(content.autoDismiss))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        guard let panel else { return }
        self.panel = nil
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
    }
}

private struct ReminderCard: View {
    let content: InAppReminder.Content
    var onClose: () -> Void

    var body: some View {
        let color = Color(hex: content.colorHex)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: content.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(color))
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: content.title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: content.subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            if !content.actions.isEmpty {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    ForEach(content.actions) { action in
                        Button {
                            action.handler()
                            if !action.isProminent { onClose() }
                        } label: {
                            Text(verbatim: action.title)
                        }
                        .buttonStyle(.bordered)
                        .tint(action.isProminent ? color : nil)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 360, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 5)
                .padding(.vertical, 12)
                .padding(.leading, 4)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
    }
}
