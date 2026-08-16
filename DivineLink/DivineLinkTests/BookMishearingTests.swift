import XCTest
@testable import DivineLink

/// Regression fixture for the "Psalms became Amos" incident.
///
/// Three defects combined to put the wrong passage on screen while the operator
/// said "Psalms 91 verse 8 to 12":
///   1. Fuzzy book matching walked an unsorted dictionary, so a misheard word
///      resolved to a different book on each app launch.
///   2. Two-letter aliases such as "am" (Amos) were valid fuzzy targets, putting
///      Amos one edit away from almost anything.
///   3. Nothing rejected a tie, so one of several equally-close books was picked.
@MainActor
final class BookMishearingTests: XCTestCase {

    private var normaliser: BookNameNormaliser!

    override func setUp() async throws {
        normaliser = BookNameNormaliser()
    }

    override func tearDown() async throws {
        normaliser = nil
    }

    // MARK: - The reported incident

    func testPsalmsMishearingsResolveToPsalms() {
        for heard in ["sam", "sams", "size", "salms", "psams", "some", "sum", "palms"] {
            XCTAssertEqual(
                normaliser.normalise(heard),
                "Psalms",
                "'\(heard)' is a recorded Psalms mishearing"
            )
        }
    }

    func testSamIsNeverAmos() {
        XCTAssertNotEqual(normaliser.normalise("sam", chapterHint: 91), "Amos")
        XCTAssertNotEqual(normaliser.normalise("sams", chapterHint: 91), "Amos")
    }

    // MARK: - Determinism

    /// Swift randomises `Dictionary` iteration order per process, so the original
    /// first-match-wins loop returned a different book on different launches. The
    /// same input must now always give the same answer.
    func testFuzzyMatchingIsDeterministic() {
        let probes = ["aim", "a john", "jame", "hoses", "mica"]
        for probe in probes {
            let first = normaliser.normalise(probe)
            for _ in 0..<25 {
                XCTAssertEqual(
                    normaliser.normalise(probe),
                    first,
                    "'\(probe)' must resolve identically on every call"
                )
            }
        }
    }

    func testFuzzyCandidateOrderIsStable() {
        let first = normaliser.fuzzyCandidates("aim").map(\.alias)
        for _ in 0..<20 {
            XCTAssertEqual(normaliser.fuzzyCandidates("aim").map(\.alias), first)
        }
    }

    // MARK: - Ties are refused, not guessed

    func testTiedCandidatesAcrossBooksAreRejected() {
        // "aim" sits two edits from thirteen aliases spanning James, Micah, Romans,
        // Titus and more. Any single answer would be a coin toss.
        XCTAssertNil(normaliser.fuzzyMatch("aim"))
        XCTAssertNil(normaliser.normalise("aim"))
    }

    func testAmbiguousNumberedBookIsRejectedWithoutAChapter() {
        // Equally close to 1, 2 and 3 John.
        XCTAssertNil(normaliser.normalise("a john"))
    }

    func testShortAliasesAreExactMatchOnly() {
        // A two-letter alias still resolves when typed verbatim…
        XCTAssertEqual(normaliser.normalise("ho"), "Hosea")
        // …but must never be reachable by fuzzy matching, which is how ordinary
        // speech used to arrive at Amos and Hosea.
        for probe in ["amo", "hos", "aim", "hoe"] {
            let aliases = normaliser.fuzzyCandidates(probe).map(\.alias)
            XCTAssertFalse(
                aliases.contains { $0.count < 3 },
                "'\(probe)' must not fuzzy-match a one- or two-letter alias: \(aliases)"
            )
        }
    }

    /// "am" is an everyday word, so it is barred outright — "I am 40" must never
    /// put Amos on the screen. This is deliberate, not an oversight.
    func testEverydayWordsNeverBecomeBooks() {
        for word in ["am", "is", "to", "so", "the", "and"] {
            XCTAssertNil(
                normaliser.normalise(word),
                "'\(word)' is ordinary speech and must not resolve to a book"
            )
        }
    }

    // MARK: - Chapter-aware disambiguation

    func testChapterHintSettlesAmbiguousNumberedBook() {
        normaliser.chapterCountProvider = { book in
            ["1 Kings": 22, "2 Kings": 25][book]
        }

        // Chapter 23 exists only in 2 Kings, so the tie has one survivor.
        XCTAssertEqual(normaliser.normalise("a kings", chapterHint: 23), "2 Kings")
        // Chapter 5 exists in both, so the tie stands and nothing is guessed.
        XCTAssertNil(normaliser.normalise("a kings", chapterHint: 5))
    }

    func testChapterHintSettlesJohannineEpistles() {
        normaliser.chapterCountProvider = { book in
            ["1 John": 5, "2 John": 1, "3 John": 1][book]
        }

        XCTAssertEqual(normaliser.normalise("a john", chapterHint: 4), "1 John")
        XCTAssertNil(normaliser.normalise("a john", chapterHint: 1))
    }

    func testChapterHintNeverOverridesAnExactAlias() {
        // An impossible chapter must not turn a book the operator named clearly
        // into something else; validation happens later, against the database.
        normaliser.chapterCountProvider = { _ in 9 }
        XCTAssertEqual(normaliser.normalise("amos", chapterHint: 91), "Amos")
    }

    // MARK: - Exact-alias reporting (drives the confidence penalty)

    func testIsExactAliasDistinguishesGuessesFromCertainties() {
        XCTAssertTrue(normaliser.isExactAlias("psalms"))
        XCTAssertTrue(normaliser.isExactAlias("sam"))
        XCTAssertFalse(normaliser.isExactAlias("aim"))
        XCTAssertFalse(normaliser.isExactAlias("a john"))
    }
}

// MARK: - Detection-level regression

/// End-to-end checks on the sentence the operator actually spoke.
@MainActor
final class SpokenPsalmsRangeTests: XCTestCase {

    private var detector: ScriptureDetectorService!

    override func setUp() async throws {
        detector = ScriptureDetectorService()
    }

    override func tearDown() async throws {
        detector = nil
    }

    func testMisheardPsalmsKeepsTheWholeVerseRange() {
        let results = detector.detect(in: "Sam 91 verse 8 to 12")

        XCTAssertFalse(
            results.contains { $0.reference.book == "Amos" },
            "A Psalms mishearing must never surface as Amos: \(results.map(\.displayReference))"
        )

        let match = results.first { $0.reference.book == "Psalms" }
        XCTAssertNotNil(match, "Expected Psalms, got: \(results.map(\.displayReference))")
        XCTAssertEqual(match?.reference.chapter, 91)
        XCTAssertEqual(match?.reference.verseStart, 8)
        XCTAssertEqual(match?.reference.verseEnd, 12, "The spoken range must survive parsing")
    }

    func testSpokenPsalmsRangeParsesCleanly() {
        let results = detector.detect(in: "Psalms chapter 91 verse 8 to 12")
        let match = results.first { $0.reference.book == "Psalms" && $0.reference.chapter == 91 }
        XCTAssertNotNil(match, "Expected Psalms 91, got: \(results.map(\.displayReference))")
        XCTAssertEqual(match?.reference.verseStart, 8)
        XCTAssertEqual(match?.reference.verseEnd, 12)
    }

    /// An invalid reference must not become the context that later partial
    /// references resolve against, or one mishearing poisons the whole service.
    func testImplausibleReferenceIsNotCachedAsContext() {
        ReferenceBuffer.shared.clearContext()
        detector.referenceValidator = { reference in
            // Amos genuinely stops at chapter 9.
            !(reference.book == "Amos" && reference.chapter > 9)
        }

        _ = detector.detect(in: "Amos 91 verse 1")

        XCTAssertNil(
            ReferenceBuffer.shared.currentContext,
            "Amos 91 does not exist and must never be cached as context"
        )
    }
}
