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
        for heard in ["sam", "sams", "salms", "psams", "some", "sum", "palms"] {
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

    /// "size" was an alias for Psalms. Being a direct alias it took no fuzzy penalty, so
    /// "…a size 10." scored 0.780 and quietly put Psalms 10 on the screen. It is an
    /// ordinary English word and must now be barred by both routes: no alias, and
    /// excluded outright so no future fuzzy path can reach it.
    func testOrdinaryWordSizeIsNeverABook() {
        XCTAssertNil(normaliser.normalise("size"))
        XCTAssertNil(normaliser.normalise("sizes"))
        XCTAssertFalse(normaliser.isExactAlias("size"))

        let detector = ScriptureDetectorService()
        let results = detector.detect(in: "and he was wearing a size 10")
        XCTAssertTrue(
            results.isEmpty,
            "A shoe size must not become scripture: \(results.map(\.displayReference))"
        )
    }

    /// "sames" sat one edit from "james" and mapped to Psalms, so a misheard James
    /// resolved to Psalms by exact match — bypassing the tie logic that exists to
    /// refuse exactly that guess.
    func testSamesDoesNotSilentlyBecomePsalms() {
        XCTAssertNotEqual(
            normaliser.normalise("sames"),
            "Psalms",
            "'sames' must not shortcut to Psalms; it is closer to James"
        )
    }

    /// Numbered forms must keep their number. These pass through exact match today,
    /// which is the desired behaviour — pin it so it cannot become incidental.
    func testNumberedSamuelKeepsItsNumber() {
        let cases: [(String, String)] = [
            ("1 sam", "1 Samuel"),
            ("first sam", "1 Samuel"),
            ("2 sam", "2 Samuel"),
            ("second sam", "2 Samuel")
        ]
        for (heard, expected) in cases {
            XCTAssertEqual(
                normaliser.normalise(heard),
                expected,
                "'\(heard)' must resolve to \(expected), not Psalms"
            )
        }
    }

    /// "I am" is one edit from a hypothetical "i sam" alias, and the chapter-only regex
    /// happily captures the ordinal prefix, so "I am 40." would resolve to 1 Samuel 40.
    /// The roman short forms are therefore deliberately absent from the table.
    func testOrdinarySpeechIsNotMistakenForRomanNumeralSamuel() {
        XCTAssertNil(normaliser.normalise("i am"), "'i am' must not resolve to a book")
        XCTAssertEqual(normaliser.normalise("i samuel"), "1 Samuel", "the long roman form must still work")
        XCTAssertEqual(normaliser.normalise("ii samuel"), "2 Samuel", "the long roman form must still work")
    }

    func testNumberedSamuelSurvivesDetection() {
        let detector = ScriptureDetectorService()
        let cases: [(String, String, Int)] = [
            ("1 sam 3", "1 Samuel", 3),
            ("first sam 3", "1 Samuel", 3),
            ("2 sam 11", "2 Samuel", 11),
            ("second sam 11", "2 Samuel", 11)
        ]
        for (spoken, book, chapter) in cases {
            // "1 sam 3" and "first sam 3" name the same passage, so the duplicate guard
            // would silently swallow the second of each pair.
            detector.clearCache()

            let results = detector.detect(in: spoken)
            XCTAssertTrue(
                results.contains { $0.reference.book == book && $0.reference.chapter == chapter },
                "'\(spoken)' should give \(book) \(chapter), got: \(results.map(\.displayReference))"
            )
        }
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

    /// The `sam` → Psalms alias means the reported utterance never reaches the
    /// chapter-hint code at all: exact match answers first. So the disambiguation path
    /// needs coverage that cannot be satisfied by the alias table. This probe is three
    /// characters or more, is provably *not* an alias, is refused outright without a
    /// chapter, and is settled only by the chapter — and reports that it was settled
    /// that way, rather than by spelling.
    func testChapterHintPathIsGenuinelyExercised() {
        let probe = "a kings"
        XCTAssertFalse(normaliser.isExactAlias(probe), "The probe must not be an alias")
        XCTAssertGreaterThanOrEqual(probe.count, 3)

        normaliser.chapterCountProvider = { book in
            ["1 Kings": 22, "2 Kings": 25][book]
        }

        // Without a chapter the tie stands, proving no alias is answering.
        XCTAssertNil(normaliser.normalise(probe))

        // With a chapter only 2 Kings can satisfy, the tie has exactly one survivor…
        guard case .matched(let canonical, let quality) = normaliser.match(probe, chapterHint: 23) else {
            return XCTFail("Chapter 23 should settle the tie in favour of 2 Kings")
        }
        XCTAssertEqual(canonical, "2 Kings")
        // …and the outcome must say it was the chapter that settled it, not the spelling.
        if case .chapterDisambiguated = quality {
            // Expected.
        } else {
            XCTFail("Expected chapterDisambiguated, got \(quality)")
        }
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
    private var buffer: ReferenceBuffer!

    override func setUp() async throws {
        // Its own buffer, not `.shared`: the singleton leaks state between cases and reads
        // live `UserDefaults`, so a machine where the buffer was once disabled would make
        // the context assertions below green for entirely the wrong reason.
        buffer = ReferenceBuffer()
        buffer.isEnabled = true
        buffer.clearContext()
        detector = ScriptureDetectorService(referenceBuffer: buffer)
    }

    override func tearDown() async throws {
        detector = nil
        buffer = nil
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
    ///
    /// Asserting only that the context is nil proves nothing: it is equally nil when the
    /// regex never matched, when the confidence gate refused the detection, or when the
    /// buffer was switched off. So this asserts positively too — the buffer is on, the
    /// detection did happen, and a *valid* reference is cached in the same test.
    func testImplausibleReferenceIsNotCachedAsContext() {
        XCTAssertTrue(buffer.isEnabled, "A disabled buffer would make this test vacuous")

        detector.referenceValidator = { reference in
            // Amos genuinely stops at chapter 9.
            !(reference.book == "Amos" && reference.chapter > 9)
        }

        let refused = detector.detect(in: "Amos 91 verse 1")
        XCTAssertFalse(
            refused.isEmpty,
            "The detection must actually happen, otherwise the nil context proves nothing"
        )
        XCTAssertTrue(
            refused.contains { $0.reference.book == "Amos" && $0.reference.chapter == 91 },
            "Expected Amos 91 to be detected but refused as context: \(refused.map(\.displayReference))"
        )
        XCTAssertNil(
            buffer.currentContext,
            "Amos 91 does not exist and must never be cached as context"
        )

        // Same detector, same validator, a reference that does exist: the caching path
        // must still work, proving the nil above was a refusal and not a broken fixture.
        let accepted = detector.detect(in: "Amos 9 verse 1")
        XCTAssertFalse(accepted.isEmpty, "Amos 9:1 is a real reference and must be detected")
        XCTAssertEqual(buffer.currentContext?.book, "Amos")
        XCTAssertEqual(buffer.currentContext?.chapter, 9)
    }

    // MARK: - Verse-range breadth (the defect-4 guard only fires on a recognised range)

    /// The refusal to split a concatenated chapter depends on a range having been
    /// recognised. A narrow parser would mean the guard silently never engages, so the
    /// breadth of accepted range phrasings is pinned here.
    func testVerseRangesParseAcrossPhrasings() {
        // "and following" has no representation in `ScriptureReference` — there is no
        // open-ended range — so it parses as the single verse named and the trailing words
        // are ignored. Verse 8 alone is honest; inventing an end verse would not be. The
        // expectation below pins that, rather than pretending the phrasing yields a range.
        let cases: [(String, Int, Int?)] = [
            ("Psalms 9 verse 8 to 12", 8, 12),
            ("Psalms 9 verse 8 through 12", 8, 12),
            ("Psalms 9:8-12", 8, 12),
            ("Psalms 9 verse 8 to verse 12", 8, 12),
            ("Psalms 9 verse 8 and following", 8, nil)
        ]

        for (spoken, start, end) in cases {
            // The five-second duplicate guard would swallow every phrasing after the
            // first, since they all describe the same passage.
            detector.clearCache()

            let results = detector.detect(in: spoken)
            guard let match = results.first(where: { $0.reference.book == "Psalms" }) else {
                XCTFail("'\(spoken)' produced no Psalms detection: \(results.map(\.displayReference))")
                continue
            }
            XCTAssertEqual(match.reference.chapter, 9, "'\(spoken)' chapter")
            XCTAssertEqual(match.reference.verseStart, start, "'\(spoken)' start verse")
            XCTAssertEqual(match.reference.verseEnd, end, "'\(spoken)' end verse")
        }
    }

    // MARK: - Context must not bias the tie-break

    /// A confirmed Amos reference must not make the next mishearing more likely to be
    /// Amos, or a single error becomes self-reinforcing.
    func testPriorAmosContextDoesNotBiasTowardsAmos() {
        // Establish Amos 9:1 as the live context, exactly as a real detection would.
        let amos = detector.detect(in: "Amos 9 verse 1")
        XCTAssertFalse(amos.isEmpty, "Amos 9:1 must be detected to establish the context")
        XCTAssertEqual(buffer.currentContext?.book, "Amos")

        let results = detector.detect(in: "Psalms 9 verse 8 to 12")
        XCTAssertFalse(
            results.contains { $0.reference.book == "Amos" },
            "A stale Amos context must not drag the next reference back to Amos: \(results.map(\.displayReference))"
        )
        let match = results.first { $0.reference.book == "Psalms" }
        XCTAssertNotNil(match, "Expected Psalms, got: \(results.map(\.displayReference))")
        XCTAssertEqual(match?.reference.chapter, 9)
        XCTAssertEqual(match?.reference.verseStart, 8)
        XCTAssertEqual(match?.reference.verseEnd, 12)
    }

    /// The same check through the mishearing, which is the shape the incident took.
    func testPriorAmosContextDoesNotBiasAMisheardPsalms() {
        _ = detector.detect(in: "Amos 9 verse 1")
        XCTAssertEqual(buffer.currentContext?.book, "Amos")

        let results = detector.detect(in: "Sam 9 verse 8 to 12")
        XCTAssertFalse(
            results.contains { $0.reference.book == "Amos" },
            "Mishearing plus stale context must still not yield Amos: \(results.map(\.displayReference))"
        )
    }
}
