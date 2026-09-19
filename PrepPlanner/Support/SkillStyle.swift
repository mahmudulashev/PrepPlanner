import SwiftUI

extension Skill {
    var colorHex: String {
        switch self {
        case .listening: "#3F8FD2"
        case .reading: "#4E9F6E"
        case .writing: "#F28C38"
        case .speaking: "#E0679A"
        case .satRW: "#C9A227"
        case .satMath: "#7B61D9"
        }
    }

    var color: Color { Color(hex: colorHex) }

    var symbol: String {
        switch self {
        case .listening: "headphones"
        case .reading: "book"
        case .writing: "pencil.line"
        case .speaking: "mic"
        case .satRW: "text.book.closed"
        case .satMath: "function"
        }
    }

    static var ielts: [Skill] { allCases.filter(\.isIELTS) }
    static var sat: [Skill] { allCases.filter { !$0.isIELTS } }
}

/// Small colored skill label used in tables and chips.
struct SkillTag: View {
    let skill: Skill

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(skill.color).frame(width: 8, height: 8)
            Text(skill.title)
        }
    }
}

/// Rounded pill showing a band, highlighted when it meets the target.
struct BandBadge: View {
    let band: Double
    var target: Double? = nil
    var large = false

    private var meetsTarget: Bool { target.map { band >= $0 } ?? false }

    var body: some View {
        Text(Band.format(band))
            .font(large ? .title3.weight(.bold) : .callout.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, large ? 12 : 8)
            .padding(.vertical, large ? 5 : 2)
            .background(Capsule().fill(meetsTarget ? Theme.success.opacity(0.2) : Theme.cardMuted))
            .foregroundStyle(meetsTarget ? Theme.success : .primary)
    }
}
