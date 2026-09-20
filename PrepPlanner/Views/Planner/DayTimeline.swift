import SwiftUI
import SwiftData
import AppKit

/// Vertical 06:00–24:00 timeline: drag empty space to create, drag a block to move, drag its edges to resize.
struct DayTimeline: View {
    static let pointsPerMinute: CGFloat = 1.25
    static let gutter: CGFloat = 60
    static var hourHeight: CGFloat { 60 * pointsPerMinute }
    static var totalHeight: CGFloat { CGFloat(TimelineBounds.end - TimelineBounds.start) * pointsPerMinute }

    let day: Date
    @Query private var blocks: [TimeBlock]
    @Query(sort: \StudyCategory.order) private var categories: [StudyCategory]
    @Environment(AppState.self) private var state
    @State private var drag: DragEdit?
    @State private var creating: ClosedRange<Int>?
    @FocusState private var focused: Bool

    init(day: Date) {
        self.day = day
        let d = day
        _blocks = Query(filter: #Predicate<TimeBlock> { $0.day == d }, sort: \TimeBlock.startMin)
    }

    private struct DragEdit: Equatable {
        enum Kind { case move, top, bottom }
        var id: UUID
        var kind: Kind
        var delta: Int
    }

    var body: some View {
        GeometryReader { geo in
            let columnWidth = max(geo.size.width - Self.gutter - 14, 100)
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    ZStack(alignment: .topLeading) {
                        grid
                        if let r = creating { creationGhost(r, width: columnWidth) }
                        blockLayer(columnWidth: columnWidth)
                        if Calendar.current.isDateInToday(day) { nowLine(width: columnWidth) }
                    }
                    .frame(height: Self.totalHeight, alignment: .top)
                    .coordinateSpace(.named("timeline"))
                    .padding(.top, 14)
                    .padding(.bottom, 22)
                }
                .scrollIndicators(.never)
                .onAppear { scrollToStart(proxy) }
                .onChange(of: day) { scrollToStart(proxy) }
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onKeyPress(.delete) { handleDeleteKey() }
        .onKeyPress(.deleteForward) { handleDeleteKey() }
        .onKeyPress(.upArrow) { nudge(-15) }
        .onKeyPress(.downArrow) { nudge(15) }
        .onKeyPress(.escape) {
            state.selectedBlockID = nil
            return .handled
        }
    }

    // MARK: Layers

    private var grid: some View {
        VStack(spacing: 0) {
            ForEach(6..<24, id: \.self) { hour in
                HourRow(hour: hour)
                    .frame(height: Self.hourHeight)
                    .id(hour)
            }
        }
        .overlay(alignment: .bottomLeading) {
            Text("24:00")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: Self.gutter - 8, alignment: .trailing)
                .offset(y: 7)
        }
        .contentShape(Rectangle())
        .gesture(createGesture)
        .onTapGesture {
            state.selectedBlockID = nil
            focused = true
        }
    }

    private func blockLayer(columnWidth: CGFloat) -> some View {
        let frames = blocks.map { (block: $0, range: previewRange($0)) }
        let layout = Self.columns(for: frames.map { ($0.block.uid, $0.range.lowerBound, $0.range.upperBound) })
        return ForEach(frames, id: \.block.uid) { item in
            let b = item.block
            let slot = layout[b.uid] ?? ColumnSlot(column: 0, count: 1)
            let width = columnWidth / CGFloat(slot.count)
            let height = CGFloat(item.range.upperBound - item.range.lowerBound) * Self.pointsPerMinute
            BlockView(
                block: b,
                start: item.range.lowerBound,
                end: item.range.upperBound,
                isSelected: state.selectedBlockID == b.uid,
                onToggleDone: { state.toggleDone(b) }
            )
            .frame(width: width - 4, height: max(height - 2, 14))
            .overlay(alignment: .top) { ResizeHandle().gesture(resizeGesture(b, kind: .top)) }
            .overlay(alignment: .bottom) { ResizeHandle().gesture(resizeGesture(b, kind: .bottom)) }
            .contentShape(Rectangle())
            .gesture(moveGesture(b))
            .onTapGesture {
                state.selectedBlockID = b.uid
                focused = true
            }
            .contextMenu { contextMenu(for: b) }
            .offset(x: Self.gutter + CGFloat(slot.column) * width + 2,
                    y: y(for: item.range.lowerBound) + 1)
            .zIndex(drag?.id == b.uid ? 1 : 0)
        }
    }

    private func creationGhost(_ r: ClosedRange<Int>, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Theme.accent.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
            .overlay(alignment: .topLeading) {
                Text("\(TimeFmt.range(r.lowerBound, r.upperBound)) · \(TimeFmt.duration(r.upperBound - r.lowerBound))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(6)
            }
            .frame(width: width - 4, height: CGFloat(r.upperBound - r.lowerBound) * Self.pointsPerMinute)
            .offset(x: Self.gutter + 2, y: y(for: r.lowerBound))
            .allowsHitTesting(false)
    }

    private func nowLine(width: CGFloat) -> some View {
        TimelineView(.everyMinute) { context in
            let m = TimeFmt.minutesSinceMidnight(context.date)
            if m >= TimelineBounds.start && m < TimelineBounds.end {
                HStack(spacing: 0) {
                    Circle().fill(Theme.danger).frame(width: 9, height: 9)
                    Rectangle().fill(Theme.danger).frame(height: 1.5)
                }
                .frame(width: width + 8)
                .offset(x: Self.gutter - 5, y: y(for: m) - 4.5)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func contextMenu(for b: TimeBlock) -> some View {
        ForEach(BlockStatus.allCases) { s in
            Button { b.setStatus(s) } label: { Label(s.actionTitle, systemImage: s.symbol) }
        }
        Divider()
        Menu("Category") {
            ForEach(categories) { c in
                Button(c.name) {
                    if b.title == b.category?.name { b.title = c.name }
                    b.category = c
                    state.lastCategoryID = c.uid
                }
            }
        }
        Button("Duplicate") { state.duplicate(b) }
        Divider()
        Button("Delete", role: .destructive) { state.delete(b) }
    }

    // MARK: Gestures

    private var createGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("timeline"))
            .onChanged { v in
                creating = snappedRange(v.startLocation.y, v.location.y)
            }
            .onEnded { v in
                let r = snappedRange(v.startLocation.y, v.location.y)
                creating = nil
                state.createBlock(start: r.lowerBound, end: r.upperBound)
            }
    }

    private func moveGesture(_ b: TimeBlock) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named("timeline"))
            .onChanged { v in
                if state.selectedBlockID != b.uid { state.selectedBlockID = b.uid }
                drag = DragEdit(id: b.uid, kind: .move, delta: snappedDelta(v.translation.height))
            }
            .onEnded { _ in commit(b) }
    }

    private func resizeGesture(_ b: TimeBlock, kind: DragEdit.Kind) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named("timeline"))
            .onChanged { v in
                if state.selectedBlockID != b.uid { state.selectedBlockID = b.uid }
                drag = DragEdit(id: b.uid, kind: kind, delta: snappedDelta(v.translation.height))
            }
            .onEnded { _ in commit(b) }
    }

    private func commit(_ b: TimeBlock) {
        let r = previewRange(b)
        drag = nil
        guard r.lowerBound != b.startMin || r.upperBound != b.endMin else { return }
        b.startMin = r.lowerBound
        b.endMin = r.upperBound
    }

    /// Block range including any in-progress drag.
    private func previewRange(_ b: TimeBlock) -> ClosedRange<Int> {
        guard let d = drag, d.id == b.uid else { return b.startMin...b.endMin }
        let lo = TimelineBounds.start, hi = TimelineBounds.end
        switch d.kind {
        case .move:
            let delta = min(max(d.delta, lo - b.startMin), hi - b.endMin)
            return (b.startMin + delta)...(b.endMin + delta)
        case .top:
            let s = min(max(b.startMin + d.delta, lo), b.endMin - 15)
            return s...b.endMin
        case .bottom:
            let e = max(min(b.endMin + d.delta, hi), b.startMin + 15)
            return b.startMin...e
        }
    }

    // MARK: Geometry helpers

    private func y(for minute: Int) -> CGFloat {
        CGFloat(minute - TimelineBounds.start) * Self.pointsPerMinute
    }

    private func snappedDelta(_ dy: CGFloat) -> Int {
        Int((dy / Self.pointsPerMinute / 15).rounded()) * 15
    }

    private func snappedRange(_ y0: CGFloat, _ y1: CGFloat) -> ClosedRange<Int> {
        let a = Double(TimelineBounds.start) + Double(min(y0, y1) / Self.pointsPerMinute)
        let b = Double(TimelineBounds.start) + Double(max(y0, y1) / Self.pointsPerMinute)
        var s = Int((a / 15).rounded(.down)) * 15
        var e = Int((b / 15).rounded(.up)) * 15
        s = min(max(s, TimelineBounds.start), TimelineBounds.end - 15)
        e = min(max(e, s + 15), TimelineBounds.end)
        return s...e
    }

    private func scrollToStart(_ proxy: ScrollViewProxy) {
        let hour: Int
        if Calendar.current.isDateInToday(day) {
            hour = TimeFmt.minutesSinceMidnight(Date()) / 60 - 1
        } else {
            hour = (blocks.first?.startMin ?? 7 * 60) / 60
        }
        let target = min(max(hour, 6), 20)
        DispatchQueue.main.async {
            proxy.scrollTo(target, anchor: .top)
        }
    }

    // MARK: Keys

    private func handleDeleteKey() -> KeyPress.Result {
        guard state.selectedBlockID != nil else { return .ignored }
        state.deleteSelected()
        return .handled
    }

    private func nudge(_ delta: Int) -> KeyPress.Result {
        guard state.selectedBlockID != nil else { return .ignored }
        state.nudgeSelected(by: delta)
        return .handled
    }

    // MARK: Overlap layout

    struct ColumnSlot {
        var column: Int
        var count: Int
    }

    /// Assigns side-by-side columns to overlapping blocks.
    static func columns(for items: [(UUID, Int, Int)]) -> [UUID: ColumnSlot] {
        let sorted = items.sorted { ($0.1, $0.2) < ($1.1, $1.2) }
        var result: [UUID: ColumnSlot] = [:]
        var cluster: [(UUID, Int)] = []
        var columnEnds: [Int] = []
        var clusterEnd = Int.min

        func flush() {
            for (id, col) in cluster { result[id] = ColumnSlot(column: col, count: columnEnds.count) }
            cluster = []
            columnEnds = []
            clusterEnd = Int.min
        }

        for (id, start, end) in sorted {
            if !cluster.isEmpty && start >= clusterEnd { flush() }
            let col: Int
            if let i = columnEnds.firstIndex(where: { $0 <= start }) {
                columnEnds[i] = end
                col = i
            } else {
                columnEnds.append(end)
                col = columnEnds.count - 1
            }
            cluster.append((id, col))
            clusterEnd = max(clusterEnd, end)
        }
        flush()
        return result
    }
}

private struct HourRow: View {
    let hour: Int

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(String(format: "%02d:00", hour))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: DayTimeline.gutter - 8, alignment: .trailing)
                .offset(y: -7)
            GeometryReader { g in
                Path { p in
                    p.move(to: .zero)
                    p.addLine(to: CGPoint(x: g.size.width, y: 0))
                }
                .stroke(Theme.gridLine, lineWidth: 1)
                Path { p in
                    p.move(to: CGPoint(x: 0, y: g.size.height / 2))
                    p.addLine(to: CGPoint(x: g.size.width, y: g.size.height / 2))
                }
                .stroke(Theme.gridLine, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            }
            .padding(.trailing, 14)
        }
    }
}

/// Invisible strip at a block's top/bottom edge for resizing.
private struct ResizeHandle: View {
    @State private var hovering = false

    var body: some View {
        Color.clear
            .frame(height: 7)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside, !hovering {
                    NSCursor.resizeUpDown.push()
                    hovering = true
                } else if !inside, hovering {
                    NSCursor.pop()
                    hovering = false
                }
            }
    }
}
