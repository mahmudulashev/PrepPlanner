import XCTest
@testable import PrepPlanner

/// SAT section scores: 200–800 in steps of ten, and the total built from them.
final class SATScoreTests: XCTestCase {

    func testClampsToTheSectionRange() {
        XCTAssertEqual(SATScore.clampSection(0), 200)
        XCTAssertEqual(SATScore.clampSection(199), 200)
        XCTAssertEqual(SATScore.clampSection(-40), 200, "a negative score cannot escape the floor")
        XCTAssertEqual(SATScore.clampSection(801), 800)
        XCTAssertEqual(SATScore.clampSection(2000), 800)
    }

    func testKeepsScoresAlreadyOnAStep() {
        for score in stride(from: 200, through: 800, by: 10) {
            XCTAssertEqual(SATScore.clampSection(score), score, "\(score) is already a valid score")
        }
    }

    func testSnapsToTheNearestStepOfTen() {
        XCTAssertEqual(SATScore.clampSection(634), 630)
        XCTAssertEqual(SATScore.clampSection(636), 640)
        XCTAssertEqual(SATScore.clampSection(635), 640, "a midpoint rounds up")
        XCTAssertEqual(SATScore.clampSection(795), 800)
    }

    func testSnappingNeverLeavesTheRange() {
        // Snapping happens before clamping, so a value just under the floor must not
        // round down out of range, and one just over the ceiling must not round up.
        XCTAssertEqual(SATScore.clampSection(196), 200)
        XCTAssertEqual(SATScore.clampSection(204), 200)
        XCTAssertEqual(SATScore.clampSection(796), 800)
        XCTAssertEqual(SATScore.clampSection(804), 800)
    }

    func testFormatDeltaUsesATypographicMinus() {
        XCTAssertEqual(SATScore.formatDelta(40), "+40")
        XCTAssertEqual(SATScore.formatDelta(-40), "\u{2212}40", "a minus sign, not a hyphen")
        XCTAssertEqual(SATScore.formatDelta(0), "±0")
    }

    func testTotalIsTheSumOfBothSections() {
        let mock = SATMock(date: Date())
        mock.readingWriting = 670
        mock.math = 710
        XCTAssertEqual(mock.total, 1380)

        mock.readingWriting = 200
        mock.math = 200
        XCTAssertEqual(mock.total, 400, "the lowest possible total")

        mock.readingWriting = 800
        mock.math = 800
        XCTAssertEqual(mock.total, 1600, "the highest possible total")
    }
}
