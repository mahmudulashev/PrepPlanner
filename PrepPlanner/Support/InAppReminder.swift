import AppKit
import SwiftUI

/// Fallback reminder used when macOS won't deliver notifications for this build:
/// a small floating panel in the top-right corner that fades away on its own.
@MainActor
final class InAppReminder {
    static let shared = InAppReminder()

    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?
    /// Reminders already shown this session, so one block reminds once.
    private var shown = Set<String>()

    func show(title: String, subtitle: String, colorHex: String, key: String) {
        guard !shown.contains(key) else { return }
        shown.insert(key)
        present(title: title, subtitle: subtitle, colorHex: colorHex)
    }

    func showTest() {
        present(title: String(localized: "Test reminder"),
                subtitle: String(localized: "This is how a reminder looks."),
                colorHex: "#F4852B")
    }

    private func present(title: String, subtitle: String, colorHex: String) {
        dismissTask?.cancel()
        panel?.orderOut(nil)

        let content = ReminderCard(title: title, subtitle: subtitle, colorHex: colorHex) { [weak self] in
            self?.dismiss()
        }
        let hosting = NSHostingView(rootView: content)
        let size = NSSize(width: 320, height: hosting.fittingSize.height)
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.maxX - size.width - 20, y: frame.maxY - size.height - 20))
        }
        panel.orderFrontRegardless()
        self.panel = panel

        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    private func dismiss() {
        dismissTask?.cancel()
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct ReminderCard: View {
    let title: String
    let subtitle: String
    let colorHex: String
    var onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: colorHex))
                .frame(width: 5)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: subtitle)
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
        }
        .padding(14)
        .frame(width: 320, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
    }
}
