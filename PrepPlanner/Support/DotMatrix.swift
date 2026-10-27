import SwiftUI

/// A number drawn as an LED dot matrix, with any trailing unit ("h", "d", " soat") in plain
/// text beside it: "1.25h" draws "1.25" in dots and "h" small.
///
/// Only digits and a few separators have glyphs; a value that starts with anything else is
/// shown as ordinary text, so translations never break.
struct DotNumber: View {
    let value: String
    /// Diameter of one dot. Glyphs are 7 dots tall.
    var dot: CGFloat = 3
    var unitFont: Font? = nil

    var body: some View {
        let (digits, unit) = DotMatrix.split(value)
        if digits.isEmpty {
            Text(verbatim: value)
                .font(.system(size: dot * 9, weight: .semibold))
                .monospacedDigit()
        } else {
            HStack(alignment: .lastTextBaseline, spacing: dot * 1.2) {
                DotGlyphs(text: digits, dot: dot)
                if !unit.isEmpty {
                    Text(verbatim: unit.trimmingCharacters(in: .whitespaces))
                        .font(unitFont ?? .system(size: dot * 5.5, weight: .medium))
                        .opacity(0.45)
                        .baselineOffset(-dot * 0.2)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: value))
        }
    }
}

private struct DotGlyphs: View {
    let text: String
    let dot: CGFloat

    private var pitch: CGFloat { dot * 1.55 }

    var body: some View {
        let glyphs = text.compactMap { DotMatrix.glyphs[$0] }
        let columns = glyphs.reduce(0) { $0 + $1.width } + max(glyphs.count - 1, 0)
        let width = CGFloat(columns) * pitch - (pitch - dot)
        let height = 7 * pitch - (pitch - dot)

        Canvas { ctx, _ in
            var x: CGFloat = 0
            var path = Path()
            for glyph in glyphs {
                for (row, line) in glyph.rows.enumerated() {
                    for (col, on) in line.enumerated() where on {
                        path.addEllipse(in: CGRect(x: x + CGFloat(col) * pitch, y: CGFloat(row) * pitch,
                                                   width: dot, height: dot))
                    }
                }
                x += CGFloat(glyph.width + 1) * pitch
            }
            ctx.fill(path, with: .foreground)
        }
        .frame(width: max(width, 0), height: height)
        // Lets an HStack line the dots up with the baseline of a unit label.
        .alignmentGuide(.lastTextBaseline) { d in d.height }
    }
}

enum DotMatrix {
    struct Glyph {
        let width: Int
        let rows: [[Bool]]

        init(_ rows: [String]) {
            self.rows = rows.map { $0.map { $0 == "#" } }
            width = rows.map(\.count).max() ?? 0
        }
    }

    /// Splits "1.25h" into ("1.25", "h"). Digits come first or not at all.
    static func split(_ value: String) -> (String, String) {
        guard let first = value.first, first.isNumber || first == "-" || first == "–" else { return ("", value) }
        let digits = value.prefix { glyphs[$0] != nil }
        return (String(digits), String(value.dropFirst(digits.count)))
    }

    static let glyphs: [Character: Glyph] = {
        var g: [Character: Glyph] = [
            "0": Glyph([" ### ", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "]),
            "1": Glyph(["  #  ", " ##  ", "  #  ", "  #  ", "  #  ", "  #  ", " ### "]),
            "2": Glyph([" ### ", "#   #", "    #", "   # ", "  #  ", " #   ", "#####"]),
            "3": Glyph(["#####", "   # ", "  #  ", "   # ", "    #", "#   #", " ### "]),
            "4": Glyph(["   # ", "  ## ", " # # ", "#  # ", "#####", "   # ", "   # "]),
            "5": Glyph(["#####", "#    ", "#### ", "    #", "    #", "#   #", " ### "]),
            "6": Glyph(["  ## ", " #   ", "#    ", "#### ", "#   #", "#   #", " ### "]),
            "7": Glyph(["#####", "    #", "   # ", "  #  ", " #   ", " #   ", " #   "]),
            "8": Glyph([" ### ", "#   #", "#   #", " ### ", "#   #", "#   #", " ### "]),
            "9": Glyph([" ### ", "#   #", "#   #", " ####", "    #", "   # ", " ##  "]),
            ".": Glyph([" ", " ", " ", " ", " ", " ", "#"]),
            ":": Glyph([" ", " ", "#", " ", "#", " ", " "]),
            "%": Glyph(["##  #", "##  #", "   # ", "  #  ", " #   ", "#  ##", "#  ##"]),
            "-": Glyph(["   ", "   ", "   ", "###", "   ", "   ", "   "]),
            "+": Glyph(["     ", "  #  ", "  #  ", "#####", "  #  ", "  #  ", "     "]),
            "/": Glyph(["    #", "    #", "   # ", "  #  ", " #   ", "#    ", "#    "]),
        ]
        g[","] = g["."]
        g["–"] = g["-"]
        return g
    }()
}
