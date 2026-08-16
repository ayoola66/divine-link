import XCTest
@testable import DivineLink

/// Pins the arithmetic that decides whether a detection is shown or silently dropped.
///
/// The book-guess penalty and the rejection gate are coupled, and neither used to say so.
/// Raising the penalty from 0.05 to 0.15 pushed ordinary utterances — "Romans 8" with a
/// slightly misheard book — from 0.760 to 0.720, below the 0.75 gate, so they stopped
/// appearing with no visible sign. This grid exists so any future change to either number
/// is measured rather than intuited.
///
/// The weights are fixed in `DetectionConfidence`: reference 0.4, speech 0.3, context 0.2,
/// existence 0.1. The penalty applies to `referenceClarity` alone, so each edit costs
/// `0.4 × penalty` of the overall score.
@MainActor
final class ConfidencePenaltyTests: XCTestCase {

    /// The base factors for each pattern, mirroring the switch in `parseMatch`.
    /// Kept here as data so the grid below reads as a table rather than as code.
    private struct PatternBase {
        let name: String
        let clarity: Double
        let speech: Double
        let context: Double
    }

    private let bases: [PatternBase] = [
        PatternBase(name: "standard", clarity: 0.98, speech: 0.95, context: 0.95),
        PatternBase(name: "spoken", clarity: 0.80, speech: 0.85, context: 0.80),
        PatternBase(name: "spokenRange", clarity: 0.82, speech: 0.86, context: 0.82),
        PatternBase(name: "verbal", clarity: 0.95, speech: 0.92, context: 0.90),
        PatternBase(name: "verbalShort", clarity: 0.88, speech: 0.88, context: 0.85),
        PatternBase(name: "spokenWords", clarity: 0.78, speech: 0.85, context: 0.80),
        PatternBase(name: "chapterOnly", clarity: 0.75, speech: 0.80, context: 0.70),
        PatternBase(name: "invertedVerbal", clarity: 0.85, speech: 0.80, context: 1.00),
        PatternBase(name: "bookVerseChapter", clarity: 0.85, speech: 0.80, context: 1.00),
        PatternBase(name: "partialVerse", clarity: 0.70, speech: 0.75, context: 0.65)
    ]

    /// Reproduces exactly what `parseMatch` does: penalise clarity by the edit distance,
    /// floored at 0.4, then weight the four factors.
    private func overall(_ base: PatternBase, editDistance: Int) -> Double {
        let penalised = editDistance == 0
            ? base.clarity
            : max(0.4, base.clarity - Double(editDistance) * ScriptureDetectorService.bookGuessPenaltyPerEdit)
        return DetectionConfidence(
            referenceClarity: penalised,
            speechConfidence: base.speech,
            contextMatch: base.context,
            verseExistence: 1.0
        ).overall
    }

    // MARK: - The grid

    /// Expected overall confidence for every pattern at edit distance 0, 1 and 2, and
    /// whether each clears `minimumConfidence`. These numbers are the contract; if a
    /// change moves one, that is the change being visible rather than silent.
    ///
    /// At the shipped penalty of 0.07 each edit costs 0.028 overall.
    func testConfidenceGridIsPinned() {
        // name, d0, d1, d2
        let expected: [(String, Double, Double, Double)] = [
            ("standard",         0.967, 0.939, 0.911),
            ("spoken",           0.835, 0.807, 0.779),
            ("spokenRange",      0.850, 0.822, 0.794),
            ("verbal",           0.936, 0.908, 0.880),
            ("verbalShort",      0.886, 0.858, 0.830),
            ("spokenWords",      0.827, 0.799, 0.771),
            ("chapterOnly",      0.780, 0.752, 0.724),
            ("invertedVerbal",   0.880, 0.852, 0.824),
            ("bookVerseChapter", 0.880, 0.852, 0.824),
            ("partialVerse",     0.735, 0.707, 0.679)
        ]

        for (name, d0, d1, d2) in expected {
            guard let base = bases.first(where: { $0.name == name }) else {
                XCTFail("Unknown pattern \(name)")
                continue
            }
            XCTAssertEqual(overall(base, editDistance: 0), d0, accuracy: 0.0005, "\(name) at distance 0")
            XCTAssertEqual(overall(base, editDistance: 1), d1, accuracy: 0.0005, "\(name) at distance 1")
            XCTAssertEqual(overall(base, editDistance: 2), d2, accuracy: 0.0005, "\(name) at distance 2")
        }
    }

    /// Every pattern that can reach the gate must survive a one-edit book guess. This is
    /// the invariant the 0.15 penalty broke, and the reason 0.07 was chosen: the tightest
    /// pattern, `chapterOnly`, has only 0.030 of headroom above the 0.75 gate, so the
    /// penalty must stay below 0.030 / 0.4 = 0.075.
    func testDistanceOneSurvivesForEveryGatedPattern() {
        // `partialVerse` is scored in its own function and never reaches this gate, so it
        // is excluded here — its 0.735 base is unreachable through `parseMatch`.
        for base in bases where base.name != "partialVerse" {
            let score = overall(base, editDistance: 1)
            XCTAssertGreaterThanOrEqual(
                score,
                ScriptureDetectorService.minimumConfidence,
                "\(base.name) at one edit scores \(score) and would be silently dropped"
            )
        }
    }

    /// Two edits on the least specific pattern is a guess too far: "Romans 8" carries no
    /// verse to corroborate the book, so a two-edit book name is refused.
    func testDistanceTwoRefusesTheLeastSpecificPattern() {
        guard let chapterOnly = bases.first(where: { $0.name == "chapterOnly" }) else {
            return XCTFail("chapterOnly missing")
        }
        XCTAssertLessThan(
            overall(chapterOnly, editDistance: 2),
            ScriptureDetectorService.minimumConfidence,
            "A two-edit guess with no verse number should be refused"
        )
    }

    /// Patterns that do carry a verse number have enough corroboration to survive two
    /// edits. Refusing these would trade a wrong verse for a missing one.
    func testDistanceTwoSurvivesWhenAVerseCorroboratesTheBook() {
        for name in ["standard", "verbal", "verbalShort", "spoken", "spokenRange", "spokenWords"] {
            guard let base = bases.first(where: { $0.name == name }) else {
                XCTFail("Unknown pattern \(name)")
                continue
            }
            XCTAssertGreaterThanOrEqual(
                overall(base, editDistance: 2),
                ScriptureDetectorService.minimumConfidence,
                "\(name) at two edits scores \(overall(base, editDistance: 2))"
            )
        }
    }

    // MARK: - The coupling itself

    /// States the relationship in one assertion, so a future edit to either constant
    /// fails here with the arithmetic spelled out rather than in a distant behavioural test.
    func testPenaltyAndGateRemainCompatible() {
        let chapterOnlyBase = 0.780
        let costPerEdit = 0.4 * ScriptureDetectorService.bookGuessPenaltyPerEdit
        let headroom = chapterOnlyBase - ScriptureDetectorService.minimumConfidence

        XCTAssertLessThan(
            costPerEdit,
            headroom,
            """
            The book-guess penalty (\(ScriptureDetectorService.bookGuessPenaltyPerEdit)) costs \
            \(costPerEdit) of overall confidence per edit, but chapterOnly has only \(headroom) \
            of headroom above the \(ScriptureDetectorService.minimumConfidence) gate. \
            A one-edit book guess on "Romans 8" would be silently dropped.
            """
        )
    }

    /// The floor matters only once the penalty is large enough to reach it. At 0.07 it
    /// takes five edits, which fuzzy matching never allows, so the floor is inert — worth
    /// pinning, because lowering it from 0.5 to 0.4 was assumed to help and did not.
    func testClarityFloorIsNotReachedAtTheShippedPenalty() {
        guard let chapterOnly = bases.first(where: { $0.name == "chapterOnly" }) else {
            return XCTFail("chapterOnly missing")
        }
        let atTwoEdits = chapterOnly.clarity - 2 * ScriptureDetectorService.bookGuessPenaltyPerEdit
        XCTAssertGreaterThan(atTwoEdits, 0.4, "The floor should not be doing the work at two edits")
    }
}
