import XCTest
@testable import PrepPlanner

/// IELTS raw-score conversion and band rounding.
///
/// A wrong band here is invisible: the app reports a score that looks plausible and the
/// study plan gets built on it. These cases pin the published tables and the .25/.75 rule.
final class BandTests: XCTestCase {

    // MARK: Listening

    func testListeningTableBoundaries() {
        // (raw, expected band) at each step of the table, highest first.
        let cases: [(Int, Double)] = [
            (40, 9), (39, 9),
            (38, 8.5), (37, 8.5),
            (36, 8), (35, 8),
            (34, 7.5), (32, 7.5),
            (31, 7), (30, 7),
            (29, 6.5), (26, 6.5),
            (25, 6), (23, 6),
            (22, 5.5), (18, 5.5),
            (17, 5), (16, 5),
            (15, 4.5), (13, 4.5),
            (12, 4), (10, 4),
            (9, 3.5), (7, 3.5),
            (6, 3), (5, 3),
            (4, 2.5), (3, 2.5),
            (2, 1), (1, 1),
            (0, 0),
        ]
        for (raw, expected) in cases {
            XCTAssertEqual(Band.listening(raw), expected, "listening raw \(raw)")
        }
    }

    func testReadingTableBoundaries() {
        let cases: [(Int, Double)] = [
            (40, 9), (39, 9),
            (38, 8.5), (37, 8.5),
            (36, 8), (35, 8),
            (34, 7.5), (33, 7.5),
            (32, 7), (30, 7),
            (29, 6.5), (27, 6.5),
            (26, 6), (23, 6),
            (22, 5.5), (19, 5.5),
            (18, 5), (15, 5),
            (14, 4.5), (13, 4.5),
            (12, 4), (10, 4),
            (9, 3.5), (8, 3.5),
            (7, 3), (6, 3),
            (5, 2.5), (4, 2.5),
            (3, 1), (1, 1),
            (0, 0),
        ]
        for (raw, expected) in cases {
            XCTAssertEqual(Band.reading(raw), expected, "reading raw \(raw)")
        }
    }

    /// A typo in either table would most likely show up as a band that dips as the raw
    /// score rises, so assert the whole range is monotonic.
    func testBandsNeverDecreaseAsRawScoreRises() {
        for raw in 1...40 {
            XCTAssertGreaterThanOrEqual(
                Band.listening(raw), Band.listening(raw - 1),
                "listening dipped between raw \(raw - 1) and \(raw)"
            )
            XCTAssertGreaterThanOrEqual(
                Band.reading(raw), Band.reading(raw - 1),
                "reading dipped between raw \(raw - 1) and \(raw)"
            )
        }
    }

    func testRawScoresOutsideTheRange() {
        XCTAssertEqual(Band.listening(0), 0)
        XCTAssertEqual(Band.reading(0), 0)
        XCTAssertEqual(Band.listening(-5), 0, "a negative raw score should not match a row")
        XCTAssertEqual(Band.reading(-5), 0)
        XCTAssertEqual(Band.listening(99), 9, "above 40 stays at the top band")
        XCTAssertEqual(Band.reading(99), 9)
    }

    // MARK: Overall band rounding

    func testOverallRoundsToTheNearestHalfBand() {
        // .25 rounds up to .5, .75 rounds up to the next whole band.
        XCTAssertEqual(Band.overall([6.5, 6.5, 6.5, 6.5]), 6.5, "an exact average is unchanged")
        XCTAssertEqual(Band.overall([6.5, 6.5, 5.5, 6.0]), 6.0, "6.125 rounds down")
        XCTAssertEqual(Band.overall([6.5, 6.5, 6.0, 6.0]), 6.5, "6.25 rounds up to the half band")
        XCTAssertEqual(Band.overall([7.0, 7.0, 6.5, 6.5]), 7.0, "6.75 rounds up to the whole band")
        XCTAssertEqual(Band.overall([6.5, 6.5, 6.5, 6.0]), 6.5, "6.375 rounds to the half band")
        XCTAssertEqual(Band.overall([7.0, 6.5, 6.5, 6.5]), 6.5, "6.625 rounds to the half band")
    }

    /// The two thresholds in the rule, hit exactly rather than approached.
    func testOverallRoundingThresholds() {
        XCTAssertEqual(Band.overall([6.0, 6.0, 6.0, 7.0]), 6.5, "exactly 6.25 goes up, not down")
        XCTAssertEqual(Band.overall([6.0, 7.0, 7.0, 7.0]), 7.0, "exactly 6.75 goes to the whole band")
        XCTAssertEqual(Band.overall([6.0, 6.0, 6.0, 6.5]), 6.0, "6.125 stays below the first threshold")
    }

    func testOverallAcrossWholeBands() {
        XCTAssertEqual(Band.overall([8.5, 9.0, 9.0, 9.0]), 9.0)
        XCTAssertEqual(Band.overall([9.0, 9.0, 9.0, 9.0]), 9.0, "the top band does not overflow")
        XCTAssertEqual(Band.overall([4.0, 4.5, 5.0, 5.5]), 5.0)
    }

    func testOverallWithUnusualInput() {
        XCTAssertEqual(Band.overall([]), 0, "no bands means no score, not a crash")
        XCTAssertEqual(Band.overall([7.0]), 7.0, "a single band is its own average")
        XCTAssertEqual(Band.overall([6.0, 7.0]), 6.5, "the rule is not specific to four skills")
    }

    // MARK: Marking criteria

    func testCriteriaNeedsEveryValue() {
        XCTAssertNil(Band.criteria([nil, nil, nil, nil]), "an untouched set has no suggestion")
        XCTAssertNil(Band.criteria([6.5, nil, 6.0, 6.0]), "a partly filled set has no suggestion")
        XCTAssertNil(Band.criteria([]), "an empty set has no suggestion")
    }

    func testCriteriaAveragesAndRoundsDown() {
        let exact = Band.criteria([6.0, 6.0, 6.0, 6.0])
        XCTAssertEqual(exact?.average, 6.0)
        XCTAssertEqual(exact?.band, 6.0)

        // 6.375 sits between half bands and is rounded down, unlike the overall rule.
        let between = Band.criteria([6.5, 6.5, 6.5, 6.0])
        XCTAssertEqual(between?.average ?? 0, 6.375, accuracy: 0.0001)
        XCTAssertEqual(between?.band, 6.0, "criteria round down to the half band")

        let half = Band.criteria([7.0, 6.5, 6.5, 6.0])
        XCTAssertEqual(half?.average ?? 0, 6.5, accuracy: 0.0001)
        XCTAssertEqual(half?.band, 6.5)
    }

    // MARK: Formatting

    func testFormatAlwaysShowsOneDecimal() {
        XCTAssertEqual(Band.format(7), "7.0")
        XCTAssertEqual(Band.format(6.5), "6.5")
        XCTAssertEqual(Band.format(0), "0.0")
    }

    func testFormatDeltaUsesATypographicMinus() {
        XCTAssertEqual(Band.formatDelta(0.5), "+0.5")
        XCTAssertEqual(Band.formatDelta(-0.5), "\u{2212}0.5", "a minus sign, not a hyphen")
        XCTAssertEqual(Band.formatDelta(0), "±0")
    }
}
