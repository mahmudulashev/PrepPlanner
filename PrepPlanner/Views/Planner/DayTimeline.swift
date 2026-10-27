import SwiftUI
import SwiftData
import AppKit

/// Vertical 06:00–24:00 timeline: drag empty space to create, drag a block to move, drag its edges to resize.
struct DayTimeline: View {
    static let pointsPerMinute: CGFloat = 1.25
    static let gutter: CGFloat = 58
    static let trailingInset: CGFloat = 16
    /// Narrowest a block may get before overlapping blocks start to cascade instead of divide.
    static let minBlockWidth: CGFloat = 118
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

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    var body: some View {
        GeometryReader { geo in
            let columnWidth = max(geo.size.width - Self.gutter - Self.trailingInset, 100)
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    ZStack(alignment: .topLeading) {
                        anchors
                        TimelineGrid(day: day, columnWidth: columnWidth, showsHover: drag == nil && creating == nil)
                            .gesture(createGesture)
                            .simultaneousGesture(doubleClickToCreate)
                            .onTapGesture {
                                state.selectedBlockID = nil
                                focused = true
                            }
                        if let r = creating { creationGhost(r, width: columnWidth) }
                        TimelineView(.everyMinute) { context in
                            // TimelineView stacks several children vertically; keep the blocks in one layer.
                            ZStack(alignment: .topLeading) {
                                blockLayer(columnWidth: columnWidth, now: context.date)
                            }
                        }
                        if isToday { NowIndicator(width: columnWidth) }
                    }
                    .frame(height: Self.totalHeight, alignment: .top)
                    .coordinateSpace(.named("timeline"))
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.automatic)
                .onAppear { scrollToStart(proxy) }
                .onChange(of: day) { scrollToStart(proxy) }
            }
        }
        .background(Theme.card)
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

    /// Invisible per-hour views the scroll view can jump to.
    private var anchors: some View {
        VStack(spacing: 0) {
            ForEach(6..<24, id: \.self) { hour in
                Color.clear.frame(height: Self.hourHeight).id(hour)
            }
        }
        .allowsHitTesting(false)
    }

    private func blockLayer(columnWidth: CGFloat, now: Date) -> some View {
        let frames = blocks.map { (block: $0, range: previewRange($0)) }
        let layout = Self.columns(for: frames.map { ($0.block.uid, $0.range.lowerBound, $0.range.upperBound) })
        let nowMinute = isToday ? TimeFmt.minutesSinceMidnight(now) : (day < now ? Int.max : Int.min)
        return ForEach(frames, id: \.block.uid) { item in
            let b = item.block
            let slot = layout[b.uid] ?? ColumnSlot(column: 0, count: 1)
            // Overlapping blocks share the column, but never below a readable width: past
            // that they cascade, each one starting a little right of the last so every
            // block's left edge and title stay visible.
            let width = max(columnWidth / CGFloat(slot.count), min(Self.minBlockWidth, columnWidth))
            let step = slot.count > 1 ? (columnWidth - width) / CGFloat(slot.count - 1) : 0
            let height = CGFloat(item.range.upperBound - item.range.lowerBound) * Self.pointsPerMinute
            let isDragging = drag?.id == b.uid
            BlockView(
                block: b,
                start: item.range.lowerBound,
                end: item.range.upperBound,
                isSelected: state.selectedBlockID == b.uid,
                needsReview: b.status == .planned && b.endMin <= nowMinute,
                isDragging: isDragging,
                onToggleDone: { state.toggleDone(b) }
            )
            .frame(width: width - 3, height: max(height - 2, 14))
            .overlay(alignment: .top) { ResizeHandle().gesture(resizeGesture(b, kind: .top)) }
            .overlay(alignment: .bottom) { ResizeHandle().gesture(resizeGesture(b, kind: .bottom)) }
            .contentShape(Rectangle())
            .gesture(moveGesture(b))
            .onTapGesture {
                state.selectedBlockID = b.uid
                focused = true
            }
            .contextMenu { contextMenu(for: b) }
            .offset(x: Self.gutter + CGFloat(slot.column) * step + 1,
                    y: y(for: item.range.lowerBound) + 1)
            .zIndex(isDragging ? 1000 : Double(slot.column))
        }
    }

    private func creationGhost(_ r: ClosedRange<Int>, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Theme.accent.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Theme.accent, lineWidth: 1.5)
            )
            .overlay(alignment: .topLeading) {
                Text("\(TimeFmt.range(r.lowerBound, r.upperBound)) · \(TimeFmt.duration(r.upperBound - r.lowerBound))")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .frame(width: width - 3, height: CGFloat(r.upperBound - r.lowerBound) * Self.pointsPerMinute)
            .offset(x: Self.gutter + 1, y: y(for: r.lowerBound))
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
                let r = snappedRange(v.startLocation.y, v.location.y)
                if r != creating { creating = r }
            }
            .onEnded { v in
                let r = snappedRange(v.startLocation.y, v.location.y)
                creating = nil
                state.createBlock(start: r.lowerBound, end: r.upperBound)
            }
    }

    /// Double-click an empty slot for a one-hour block starting there.
    private var doubleClickToCreate: some Gesture {
        SpatialTapGesture(count: 2, coordinateSpace: .named("timeline"))
            .onEnded { v in
                let start = min(snappedRange(v.location.y, v.location.y).lowerBound, TimelineBounds.end - 60)
                state.createBlock(start: start, end: start + 60)
            }
    }

    private func moveGesture(_ b: TimeBlock) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named("timeline"))
            .onChanged { v in
                if state.selectedBlockID != b.uid { state.selectedBlockID = b.uid }
                let edit = DragEdit(id: b.uid, kind: .move, delta: snappedDelta(v.translation.height))
                if edit != drag { drag = edit }
            }
            .onEnded { _ in commit(b) }
    }

    private func resizeGesture(_ b: TimeBlock, kind: DragEdit.Kind) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named("timeline"))
            .onChanged { v in
                if state.selectedBlockID != b.uid { state.selectedBlockID = b.uid }
                let edit = DragEdit(id: b.uid, kind: kind, delta: snappedDelta(v.translation.height))
                if edit != drag { drag = edit }
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

    static func y(for minute: Int) -> CGFloat {
        CGFloat(minute - TimelineBounds.start) * pointsPerMinute
    }

    private func y(for minute: Int) -> CGFloat { Self.y(for: minute) }

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
        if isToday {
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

// MARK: - Grid

/// Hour labels, hour and half-hour lines, the elapsed part of today, and a hint under the
/// pointer showing where a new block would start. Drawn in one Canvas so dragging a block
/// does not rebuild a view per hour.
private struct TimelineGrid: View {
    let day: Date
    let columnWidth: CGFloat
    let showsHover: Bool

    @State private var hoverMinute: Int?
    @Environment(\.colorScheme) private var scheme

    /// Hour labels sit centred on their line, so the drawing extends this far past the
    /// timeline at both ends to keep 06:00 and 24:00 from being cut in half.
    private static let overhang: CGFloat = 8

    var body: some View {
        Color.clear
            .frame(height: DayTimeline.totalHeight)
            .background(alignment: .top) {
                TimelineView(.everyMinute) { context in
                    Canvas { ctx, size in
                        ctx.translateBy(x: 0, y: Self.overhang)
                        draw(in: &ctx, size: size, now: context.date)
                    }
                }
                .frame(height: DayTimeline.totalHeight + 2 * Self.overhang)
                .offset(y: -Self.overhang)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) { hoverHint }
            .contentShape(Rectangle())
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let p) where p.x > DayTimeline.gutter:
                    let m = TimelineBounds.start + Int((p.y / DayTimeline.pointsPerMinute / 15).rounded(.down)) * 15
                    let clamped = min(max(m, TimelineBounds.start), TimelineBounds.end - 15)
                    if clamped != hoverMinute { hoverMinute = clamped }
                default:
                    if hoverMinute != nil { hoverMinute = nil }
                }
            }
    }

    private func draw(in ctx: inout GraphicsContext, size: CGSize, now: Date) {
        let left = DayTimeline.gutter
        let right = left + columnWidth

        // Elapsed part of today, lightly shaded.
        if Calendar.current.isDateInToday(day) {
            let m = min(max(TimeFmt.minutesSinceMidnight(now), TimelineBounds.start), TimelineBounds.end)
            let rect = CGRect(x: left, y: 0, width: columnWidth, height: DayTimeline.y(for: m))
            ctx.fill(Path(rect), with: .color(.primary.opacity(scheme == .dark ? 0.025 : 0.018)))
        }

        for hour in 6...24 {
            let y = DayTimeline.y(for: hour * 60)
            var line = Path()
            line.move(to: CGPoint(x: left, y: y))
            line.addLine(to: CGPoint(x: right, y: y))
            ctx.stroke(line, with: .color(Theme.gridLine), lineWidth: 1)

            if hour < 24 {
                var half = Path()
                half.move(to: CGPoint(x: left, y: y + DayTimeline.hourHeight / 2))
                half.addLine(to: CGPoint(x: right, y: y + DayTimeline.hourHeight / 2))
                ctx.stroke(half, with: .color(Theme.gridLine.opacity(0.45)), lineWidth: 1)
            }

            let label = ctx.resolve(
                Text(verbatim: String(format: "%02d:00", hour))
                    .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(.tertiary)
            )
            ctx.draw(label, at: CGPoint(x: left - 10, y: y), anchor: .trailing)
        }
    }

    @ViewBuilder
    private var hoverHint: some View {
        if showsHover, let m = hoverMinute {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                Text(TimeFmt.hm(m)).monospacedDigit()
            }
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 8)
            .frame(width: columnWidth - 3, height: 15 * DayTimeline.pointsPerMinute, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
            )
            .offset(x: DayTimeline.gutter + 1, y: DayTimeline.y(for: m))
            .allowsHitTesting(false)
        }
    }
}

/// Current time: a line across the day with the time in a pill over the gutter.
private struct NowIndicator: View {
    let width: CGFloat

    var body: some View {
        TimelineView(.everyMinute) { context in
            let m = TimeFmt.minutesSinceMidnight(context.date)
            if m >= TimelineBounds.start && m < TimelineBounds.end {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.danger)
                        .frame(width: width, height: 1.5)
                        .offset(x: DayTimeline.gutter)
                    Text(TimeFmt.hm(m))
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.danger))
                        .frame(width: DayTimeline.gutter - 4, alignment: .trailing)
                }
                .frame(height: 16)
                .offset(y: DayTimeline.y(for: m) - 8)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Invisible strip at a block's top/bottom edge for resizing.
private struct ResizeHandle: View {
    @State private var pushed = false

    var body: some View {
        Color.clear
            .frame(height: 7)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { push() } else { pop() }
            }
            // A block can be deleted or moved away while the pointer is over its edge; without
            // this the resize cursor would stay on screen.
            .onDisappear { pop() }
    }

    private func push() {
        guard !pushed else { return }
        NSCursor.resizeUpDown.push()
        pushed = true
    }

    private func pop() {
        guard pushed else { return }
        NSCursor.pop()
        pushed = false
    }
}
