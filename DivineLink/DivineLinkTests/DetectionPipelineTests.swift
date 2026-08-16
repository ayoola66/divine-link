import XCTest
@testable import DivineLink

/// The detector-level tests build a bare `ScriptureDetectorService`, which leaves
/// `referenceValidator` and `bookNormaliser.chapterCountProvider` nil — so both
/// mechanisms the fix depends on are inert in those tests. These exercise the wiring the
/// application actually ships.
@MainActor
final class DetectionPipelineWiringTests: XCTestCase {

    private var pipeline: DetectionPipeline!

    override func setUp() async throws {
        pipeline = DetectionPipeline()
        try await waitForBible()
    }

    override func tearDown() async throws {
        pipeline = nil
    }

    private func waitForBible() async throws {
        let deadline = Date().addingTimeInterval(15)
        while !pipeline.bible.isLoaded && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertTrue(
            pipeline.bible.isLoaded,
            "The Bible must load before wiring can be verified: \(pipeline.bible.loadingProgress)"
        )
    }

    // MARK: - The closures exist and answer correctly

    func testReferenceValidatorIsWiredAndCorrect() throws {
        let validate = try XCTUnwrap(
            pipeline.detector.referenceValidator,
            "DetectionPipeline must give the detector a reference validator"
        )

        XCTAssertTrue(validate(ScriptureReference(book: "Psalms", chapter: 91, verseStart: 8, verseEnd: 12)))
        XCTAssertTrue(validate(ScriptureReference(book: "Judges", chapter: 5, verseStart: 1, verseEnd: nil)))
        XCTAssertFalse(validate(ScriptureReference(book: "Amos", chapter: 91, verseStart: 1, verseEnd: nil)))
    }

    func testChapterCountProviderIsWiredAndCorrect() throws {
        let counts = try XCTUnwrap(
            pipeline.detector.bookNormaliser.chapterCountProvider,
            "DetectionPipeline must give the normaliser real chapter counts"
        )

        XCTAssertEqual(counts("Psalms"), 150)
        XCTAssertEqual(counts("Amos"), 9)
        XCTAssertEqual(counts("Judges"), 21)
        XCTAssertEqual(counts("Jude"), 1)
    }

    /// The reported incident, run through the production wiring rather than a stub.
    func testReportedIncidentThroughProductionWiring() {
        let results = pipeline.detector.detect(in: "Sam 91 verse 8 to 12")

        XCTAssertFalse(
            results.contains { $0.reference.book == "Amos" },
            "A Psalms mishearing must never surface as Amos: \(results.map(\.displayReference))"
        )
        let match = results.first { $0.reference.book == "Psalms" }
        XCTAssertNotNil(match, "Expected Psalms, got: \(results.map(\.displayReference))")
        XCTAssertEqual(match?.reference.chapter, 91)
        XCTAssertEqual(match?.reference.verseStart, 8)
        XCTAssertEqual(match?.reference.verseEnd, 12)
    }
}

// MARK: - Concatenation repair

/// `reinterpretConcatenatedRef` recovers from speech recognition collapsing "James 1 23"
/// into "James 123". The new guard against splitting a spoken verse could easily have made
/// it too timid, and nothing was testing either direction.
@MainActor
final class ConcatenatedReferenceRepairTests: XCTestCase {

    private var pipeline: DetectionPipeline!

    override func setUp() async throws {
        pipeline = DetectionPipeline()
        let deadline = Date().addingTimeInterval(15)
        while !pipeline.bible.isLoaded && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertTrue(pipeline.bible.isLoaded, "The split needs real verses to validate against")
    }

    override func tearDown() async throws {
        pipeline = nil
    }

    /// The original purpose: an impossible chapter that is really a chapter and verse
    /// run together.
    func testSplitRecoversConcatenatedChapterAndVerse() {
        let heard = ScriptureReference(book: "James", chapter: 123, verseStart: 1, verseEnd: nil)
        let repaired = pipeline.reinterpretConcatenatedRef(heard)

        XCTAssertEqual(repaired?.book, "James")
        XCTAssertEqual(repaired?.chapter, 1)
        XCTAssertEqual(repaired?.verseStart, 23)
        XCTAssertNil(repaired?.verseEnd)
    }

    /// The defect this commit fixed: "Psalms 91 verse 8 to 12" was misheard as chapter 91
    /// of a nine-chapter book, and splitting it threw the requested range away, putting
    /// "Amos 9:1" on the screen. A range must never be split.
    func testSplitIsRefusedWhenARangeWasSpoken() {
        let heard = ScriptureReference(book: "Amos", chapter: 91, verseStart: 8, verseEnd: 12)
        XCTAssertNil(
            pipeline.reinterpretConcatenatedRef(heard),
            "Splitting would discard verses 8 to 12 and show the wrong passage"
        )
    }

    /// The subtle one. `verseStart` defaults to 1, so testing it alone cannot tell a
    /// chapter-only utterance from "verse 1" spoken aloud. `verseWasSpoken` records the
    /// difference, and this pair proves it is being used.
    func testSplitIsRefusedWhenASingleVerseWasSpoken() {
        let spoken = ScriptureReference(book: "Amos", chapter: 91, verseStart: 1, verseEnd: nil, verseWasSpoken: true)
        XCTAssertNil(
            pipeline.reinterpretConcatenatedRef(spoken),
            "'Amos 91 verse 1' names its verse; the trailing 1 of the chapter is not it"
        )

        let chapterOnly = ScriptureReference(book: "Amos", chapter: 91, verseStart: 1, verseEnd: nil, verseWasSpoken: false)
        XCTAssertNotNil(
            pipeline.reinterpretConcatenatedRef(chapterOnly),
            "'Amos 91' with no verse is exactly the case the split exists for"
        )
    }

    func testSplitReturnsNilWhenNoCandidateResolves() {
        // 999 splits every way into chapters and verses that no book has.
        let heard = ScriptureReference(book: "Amos", chapter: 999, verseStart: 1, verseEnd: nil)
        XCTAssertNil(pipeline.reinterpretConcatenatedRef(heard))
    }

    func testSplitIsRefusedForASingleDigitChapter() {
        let heard = ScriptureReference(book: "Amos", chapter: 9, verseStart: 1, verseEnd: nil)
        XCTAssertNil(pipeline.reinterpretConcatenatedRef(heard), "There is nothing to split")
    }

    /// A repaired reference must never be split a second time — the verse is explicit now.
    func testRepairedReferenceIsMarkedAsHavingASpokenVerse() {
        let heard = ScriptureReference(book: "James", chapter: 123, verseStart: 1, verseEnd: nil)
        let repaired = pipeline.reinterpretConcatenatedRef(heard)
        XCTAssertEqual(repaired?.verseWasSpoken, true)
    }

    /// The detector refuses to remember the pre-split reference, quite rightly, since its
    /// chapter does not exist. Without this the buffer is left empty after a successful
    /// repair and a follow-up "verse 25" has nothing to resolve against.
    func testSuccessfulRepairLeavesUsableContext() {
        ReferenceBuffer.shared.clearContext()

        let heard = ScriptureReference(book: "James", chapter: 123, verseStart: 1, verseEnd: nil)
        guard let repaired = pipeline.reinterpretConcatenatedRef(heard) else {
            return XCTFail("James 123 should split to James 1:23")
        }

        // This is what `processDetection` does with the corrected reference.
        pipeline.detector.cacheContext(for: repaired)

        XCTAssertEqual(ReferenceBuffer.shared.currentContext?.book, "James")
        XCTAssertEqual(ReferenceBuffer.shared.currentContext?.chapter, 1)
        XCTAssertEqual(ReferenceBuffer.shared.currentContext?.verseStart, 23)
    }
}
