import SwiftUI
import SwiftData
import AppKit

/// Text shown in the menu bar: the current block and time left, or the next start time.
struct MenuBarLabel: View {
    let tracker: NowTracker

    var body: some View {
        if let c = tracker.current, let left = tracker.minutesLeft {
            Text(Image(systemName: "timer")) + Text(verbatim: " \(Self.short(c.title)) · \(TimeFmt.duration(left))")
        } else if let n = tracker.next {
            Text(Image(systemName: "calendar")) + Text(verbatim: " ") + Text("Next \(TimeFmt.hm(n.startMin))")
        } else {
            Image(systemName: "graduationcap")
        }
    }

    static func short(_ title: String) -> String {
        title.count > 18 ? String(title.prefix(17)) + "…" : title
    }
}

/// The panel that opens from the menu bar item.
struct MenuBarPanel: View {
    let tracker: NowTracker
    @Query private var settings: [AppSettings]
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let c = tracker.current {
                section("NOW") { currentCard(c) }
            } else {
                Text("No block right now")
                    .font(.headline)
            }

            if let j = tracker.justEnded, j.uid != tracker.current?.uid {
                section("JUST FINISHED") {
                    VStack(alignment: .leading, spacing: 8) {
                        blockLine(j)
                        Text("How did it go?").font(.caption).foregroundStyle(.secondary)
                        statusButtons(for: j.uid)
                    }
                }
            }

            if let n = tracker.next {
                section("NEXT") {
                    HStack {
                        blockLine(n)
                        Spacer()
                        Text(relative(to: n.start))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today").font(.caption).foregroundStyle(.secondary)
                    Text(verbatim: "\(TimeFmt.hours(tracker.doneMinutes)) / \(TimeFmt.hours(tracker.plannedMinutes))")
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                }
                Spacer()
                if let s = settings.first {
                    countdown("IELTS", s.ieltsDate)
                    countdown("SAT", s.satDate)
                }
            }

            HStack {
                Button("Open PrepPlanner") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(.defaultAction)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 320)
        .tint(Theme.accent)
        .onAppear { tracker.refresh() }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func currentCard(_ c: BlockSnapshot) -> some View {
        let total = c.end.timeIntervalSince(c.start)
        let elapsed = min(max(tracker.now.timeIntervalSince(c.start), 0), total)
        return VStack(alignment: .leading, spacing: 8) {
            blockLine(c)
            ProgressView(value: elapsed, total: max(total, 1))
                .tint(Color(hex: c.colorHex))
            HStack {
                if let left = tracker.minutesLeft {
                    Text("\(TimeFmt.duration(left)) left")
                        .font(.caption.weight(.semibold))
                }
                Spacer()
                if c.status != .planned {
                    Text(c.status.title).font(.caption).foregroundStyle(.secondary)
                }
            }
            statusButtons(for: c.uid)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(hex: c.colorHex).opacity(0.15)))
    }

    private func blockLine(_ b: BlockSnapshot) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: b.colorHex))
                .frame(width: 4, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: b.title).font(.callout.weight(.semibold)).lineLimit(1)
                Text(verbatim: [TimeFmt.range(b.startMin, b.endMin), b.category].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func statusButtons(for uid: UUID) -> some View {
        HStack(spacing: 6) {
            ForEach([BlockStatus.done, .partial, .skipped]) { s in
                Button(s.title) { tracker.setStatus(s, for: uid) }
                    .controlSize(.small)
            }
        }
    }

    private func countdown(_ exam: String, _ date: Date) -> some View {
        let days = Countdown.days(to: date)
        return VStack(alignment: .trailing, spacing: 2) {
            Text(verbatim: exam).font(.caption).foregroundStyle(.secondary)
            Text(days >= 0 ? "\(days)d" : "done")
                .font(.callout.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.leading, 10)
    }

    private func relative(to date: Date) -> String {
        let minutes = max(0, Int((date.timeIntervalSince(tracker.now) / 60).rounded(.up)))
        return String(localized: "in \(TimeFmt.duration(minutes))")
    }
}
