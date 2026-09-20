import SwiftUI

/// A row of cards that all take the height of the tallest one, so a card with an extra line
/// of text does not leave its neighbours short.
struct CardRow<Content: View>: View {
    var spacing: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: spacing) { content }
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Lays subviews out left to right, wrapping onto a new row when the current one is full.
///
/// `HStack` cannot wrap: it squeezes its subviews until their text truncates. Use this for
/// rows of pills or chips whose number and width depend on the data.
struct WrapLayout: Layout {
    var spacing: CGFloat = 10
    var rowSpacing: CGFloat = 8
    var alignment: VerticalAlignment = .center

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let rows = rows(subviews, maxWidth: proposal.width ?? .infinity)
        let height = rows.reduce(0) { $0 + $1.height } + rowSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var y = bounds.minY
        for row in rows(subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                let dy: CGFloat
                switch alignment {
                case .top: dy = 0
                case .bottom: dy = row.height - size.height
                default: dy = (row.height - size.height) / 2
                }
                subviews[index].place(
                    at: CGPoint(x: x, y: y + dy),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private func rows(_ subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let widthWithSubview = current.indices.isEmpty ? size.width : current.width + spacing + size.width

            if !current.indices.isEmpty && widthWithSubview > maxWidth {
                rows.append(current)
                current = Row(indices: [index], width: size.width, height: size.height)
            } else {
                current.indices.append(index)
                current.width = widthWithSubview
                current.height = max(current.height, size.height)
            }
        }

        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
