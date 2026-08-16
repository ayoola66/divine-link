import XCTest
@testable import DivineLink

/// `findBookId` became load-bearing when `referenceExists` and `maxChapter(forBookNamed:)`
/// were built on top of it. It resolved names by walking `bookCache` — an unsorted Swift
/// `Dictionary` — and taking the first key where either string prefixed the other. Swift
/// randomises dictionary iteration per process, so "Judges" could resolve to Jude's id on
/// one launch and Judges' on the next, which in turn made chapter validation reject
/// perfectly ordinary references.
@MainActor
final class BibleServiceLookupTests: XCTestCase {

    private var bible: BibleService!

    override func setUp() async throws {
        bible = BibleService()
        try await waitForLoad()
    }

    override func tearDown() async throws {
        bible = nil
    }

    /// The database loads asynchronously from the app bundle. Everything here is about
    /// real book ids and chapter counts, so a partially loaded service would produce
    /// meaningless passes.
    private func waitForLoad() async throws {
        let deadline = Date().addingTimeInterval(15)
        while !bible.isLoaded && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertTrue(
            bible.isLoaded,
            "The Bible database must load for these tests to mean anything: \(bible.loadingProgress)"
        )
    }

    // MARK: - Prefix collisions

    /// The pair that made the bug visible: "judges".hasPrefix("jude") is true, so a
    /// first-match-wins loop could answer either way.
    func testJudgesAndJudeAreDistinct() {
        let judges = bible.findBookId(name: "Judges")
        let jude = bible.findBookId(name: "Jude")

        XCTAssertNotNil(judges, "Judges must resolve")
        XCTAssertNotNil(jude, "Jude must resolve")
        XCTAssertNotEqual(judges, jude, "Judges and Jude are different books")
    }

    /// Every prefix collision in the canon, not merely the one that was noticed.
    func testPrefixCollidingBooksResolveDistinctly() {
        let collisions: [(String, String)] = [
            ("Judges", "Jude"),
            ("Philippians", "Philemon"),
            ("John", "1 John"),
            ("1 John", "2 John"),
            ("2 John", "3 John"),
            ("1 Timothy", "2 Timothy"),
            ("1 Kings", "2 Kings"),
            ("1 Samuel", "2 Samuel"),
            ("1 Chronicles", "2 Chronicles"),
            ("1 Corinthians", "2 Corinthians"),
            ("1 Thessalonians", "2 Thessalonians"),
            ("1 Peter", "2 Peter")
        ]

        for (left, right) in collisions {
            let leftId = bible.findBookId(name: left)
            let rightId = bible.findBookId(name: right)
            XCTAssertNotNil(leftId, "\(left) must resolve")
            XCTAssertNotNil(rightId, "\(right) must resolve")
            XCTAssertNotEqual(leftId, rightId, "\(left) and \(right) must not share an id")
        }
    }

    // MARK: - Determinism

    /// The whole point: the same name must give the same id on every call, and by
    /// extension on every launch. `bookCache.keys.sorted()` uses Swift's ordinal
    /// comparison, which is locale-independent, so this holds on any machine.
    func testLookupsAreStableAcrossRepeatedCalls() {
        let probes = ["Judges", "Jude", "John", "1 John", "Philippians", "Philemon", "Psalms", "Amos"]
        for probe in probes {
            let first = bible.findBookId(name: probe)
            XCTAssertNotNil(first, "\(probe) must resolve")
            for _ in 0..<50 {
                XCTAssertEqual(
                    bible.findBookId(name: probe),
                    first,
                    "\(probe) must resolve identically on every call"
                )
            }
        }
    }

    // MARK: - The consequences that made this critical

    /// A wrong id here silently truncated a book, so chapter-aware disambiguation
    /// discarded the correct answer for any chapter above the impostor's count.
    func testChapterCountsFollowTheCorrectBook() {
        XCTAssertEqual(bible.maxChapter(forBookNamed: "Judges"), 21)
        XCTAssertEqual(bible.maxChapter(forBookNamed: "Jude"), 1)
        XCTAssertEqual(bible.maxChapter(forBookNamed: "Philippians"), 4)
        XCTAssertEqual(bible.maxChapter(forBookNamed: "Philemon"), 1)
        XCTAssertEqual(bible.maxChapter(forBookNamed: "Psalms"), 150)
        XCTAssertEqual(bible.maxChapter(forBookNamed: "Amos"), 9)
    }

    func testValidReferencesAreAcceptedAndImpossibleOnesRefused() {
        XCTAssertTrue(
            bible.referenceExists(ScriptureReference(book: "Judges", chapter: 5, verseStart: 1, verseEnd: nil)),
            "Judges 5:1 exists and was being refused when Jude's single chapter was consulted"
        )
        XCTAssertTrue(bible.referenceExists(ScriptureReference(book: "Psalms", chapter: 91, verseStart: 8, verseEnd: 12)))
        XCTAssertFalse(bible.referenceExists(ScriptureReference(book: "Amos", chapter: 91, verseStart: 1, verseEnd: nil)))
        XCTAssertFalse(bible.referenceExists(ScriptureReference(book: "Jude", chapter: 5, verseStart: 1, verseEnd: nil)))
    }

    /// `isValidChapter` is deliberately lenient — it allows a chapter through when no
    /// count is known. `referenceExists` must not inherit that leniency, or during the
    /// asynchronous load window it accepts impossible references as context.
    func testReferenceExistsFailsClosedForAnUnknownBook() {
        XCTAssertFalse(
            bible.referenceExists(ScriptureReference(book: "Nonexistent", chapter: 1, verseStart: 1, verseEnd: nil))
        )
    }

    func testReferenceExistsFailsClosedBeforeTheDatabaseLoads() async throws {
        // A brand-new service has not finished loading, so nothing can be validated yet.
        let fresh = BibleService()
        XCTAssertFalse(
            fresh.referenceExists(ScriptureReference(book: "Psalms", chapter: 91, verseStart: 8, verseEnd: 12)),
            "Before the chapter counts exist, the validator must refuse rather than assume"
        )
    }
}
