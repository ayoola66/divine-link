import XCTest
@testable import DivineLink

/// `DetectionRejection.candidateBooks` was populated and threaded all the way to the
/// operator console, then never rendered. The books in contention reached the operator
/// only because `MatchFailure.ambiguous`'s reason string happened to interpolate them —
/// an incidental coupling that would have vanished silently the first time anyone
/// reworded that string.
///
/// The field is now the single structured source of that information: the reason names
/// the *kind* of failure, `candidateBooks` carries the books, and the console renders
/// from the field. These tests pin both halves of that split, so a rewording of either
/// cannot quietly drop the books again.
@MainActor
final class RejectionPresentationTests: XCTestCase {

    // MARK: - The reason string no longer carries the books

    /// If this starts failing because the books crept back into the reason, the console
    /// is printing them twice.
    func testAmbiguityReasonDoesNotNameTheBooks() {
        let failure = BookNameNormaliser.MatchFailure.ambiguous(books: ["1 Samuel", "James"])

        XCTAssertFalse(failure.reason.contains("Samuel"))
        XCTAssertFalse(failure.reason.contains("James"))
        XCTAssertEqual(failure.reason, "the book name was ambiguous")
    }

    func testAmbiguityCarriesItsCandidatesStructurally() {
        let failure = BookNameNormaliser.MatchFailure.ambiguous(books: ["1 Samuel", "James"])
        XCTAssertEqual(failure.candidateBooks, ["1 Samuel", "James"])
    }

    /// Every other failure mode is a single resolved book or none at all — never a
    /// contest — so it must contribute no candidates.
    func testNonAmbiguousFailuresCarryNoCandidates() {
        for failure: BookNameNormaliser.MatchFailure in [.excludedWord, .tooShort, .unrecognised] {
            XCTAssertTrue(
                failure.candidateBooks.isEmpty,
                "\(failure) is not a contest and must not populate candidateBooks"
            )
        }
    }

    // MARK: - What the operator actually sees

    func testCandidateSummaryReadsAsBritishProse() {
        let two = DetectionRejection(
            heard: "sames 3 verse 5",
            reason: "the book name was ambiguous",
            candidateBooks: ["1 Samuel", "James"]
        )
        XCTAssertEqual(two.candidateSummary, "1 Samuel or James")

        let three = DetectionRejection(
            heard: "a john 2",
            reason: "the book name was ambiguous",
            candidateBooks: ["1 John", "2 John", "3 John"]
        )
        XCTAssertEqual(three.candidateSummary, "1 John, 2 John or 3 John")
    }

    /// A single book is not "in contention". Rendering "Could be Psalms" under a
    /// chapter-out-of-range refusal would invent an ambiguity that never happened.
    func testSingleOrAbsentCandidatesRenderNothing() {
        XCTAssertNil(
            DetectionRejection(heard: "psalms 400", reason: "chapter out of range", candidateBooks: ["Psalms"])
                .candidateSummary
        )
        XCTAssertNil(
            DetectionRejection(heard: "psalms 400", reason: "chapter out of range")
                .candidateSummary
        )
    }

    /// The summary line is independent of the candidate line, so the console can render
    /// them as two bounded rows without either one swallowing the other.
    func testSummaryStatesWhatWasHeardAndWhy() {
        let rejection = DetectionRejection(
            heard: "sames 3 verse 5",
            reason: "the book name was ambiguous",
            candidateBooks: ["1 Samuel", "James"]
        )
        XCTAssertEqual(
            rejection.summary,
            "Heard \u{201C}sames 3 verse 5\u{201D} — the book name was ambiguous"
        )
    }

    // MARK: - The invariant the five stripped call sites were breaking

    /// Refusals raised by range and confidence checks resolve a book before they refuse,
    /// so there is nothing in contention to report. Five call sites used to pass that
    /// single resolved book, which made the field unreadable as evidence of ambiguity.
    func testRangeRefusalsReportNoCandidates() {
        let detector = ScriptureDetectorService()

        // Beyond the 150 chapters of the longest book.
        _ = detector.detect(in: "turn to psalms chapter 400 verse 2")

        if let rejection = detector.lastRejection {
            XCTAssertTrue(
                rejection.candidateBooks.isEmpty,
                "a range refusal resolved its book; it must not claim a contest: \(rejection.candidateBooks)"
            )
            XCTAssertNil(rejection.candidateSummary)
        }
    }
}
