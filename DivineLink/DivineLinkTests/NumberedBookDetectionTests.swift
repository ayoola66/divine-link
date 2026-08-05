import XCTest
@testable import DivineLink

/// Regression fixture for spoken/digit ordinal numbered books
/// (e.g. "Second Timothy" must not collapse to 1 Timothy).
@MainActor
final class NumberedBookDetectionTests: XCTestCase {

    private var detector: ScriptureDetectorService!

    override func setUp() async throws {
        detector = ScriptureDetectorService()
    }

    override func tearDown() async throws {
        detector = nil
    }

    func testSecondTimothyVerbalResolvesTo2Timothy() {
        assertDetection(
            in: "Second Timothy chapter 1 verse seven",
            book: "2 Timothy",
            chapter: 1,
            verse: 7
        )
    }

    func testDigit2TimothyVerbalStillWorks() {
        assertDetection(
            in: "2 Timothy chapter 1 verse seven",
            book: "2 Timothy",
            chapter: 1,
            verse: 7
        )
    }

    func testFirstJohnVerbalResolvesTo1John() {
        assertDetection(
            in: "First John chapter 1 verse one",
            book: "1 John",
            chapter: 1,
            verse: 1
        )
    }

    func testPlainJohnVerbalUnchanged() {
        assertDetection(
            in: "John chapter 3 verse 16",
            book: "John",
            chapter: 3,
            verse: 16
        )
    }

    func testSecondCorinthiansVerbal() {
        assertDetection(
            in: "Second Corinthians chapter 5 verse 17",
            book: "2 Corinthians",
            chapter: 5,
            verse: 17
        )
    }

    func testRomanIITimothyVerbal() {
        assertDetection(
            in: "II Timothy chapter 1 verse 7",
            book: "2 Timothy",
            chapter: 1,
            verse: 7
        )
    }

    func testSecondTimothyVerseTwoNot1Timothy() {
        let results = detector.detect(in: "Second Timothy chapter 1 verse two")
        XCTAssertFalse(
            results.contains { $0.reference.book == "1 Timothy" },
            "Spoken Second Timothy must not produce a 1 Timothy card"
        )
        XCTAssertTrue(
            results.contains {
                $0.reference.book == "2 Timothy"
                    && $0.reference.chapter == 1
                    && $0.reference.verseStart == 2
            },
            "Expected 2 Timothy 1:2, got: \(results.map(\.displayReference))"
        )
    }

    func testBookNormaliserOrdinalAliases() {
        let normaliser = BookNameNormaliser()
        XCTAssertEqual(normaliser.normalise("Second Timothy"), "2 Timothy")
        XCTAssertEqual(normaliser.normalise("2 Timothy"), "2 Timothy")
        XCTAssertEqual(normaliser.normalise("ii timothy"), "2 Timothy")
        XCTAssertEqual(normaliser.normalise("First John"), "1 John")
        XCTAssertEqual(normaliser.normalise("timothy"), "1 Timothy")
    }

    /// Spoken "I …" can reach the ordinal-aware book capture as "i …" and fuzzy-match
    /// toward 1 Samuel. Confidence currently blocks it (~0.74 < 0.75); pin no-detection
    /// so a threshold tweak cannot silently ship this false positive.
    func testIAmFortyDoesNotDetect1Samuel() {
        let results = detector.detect(in: "I am 40.")
        XCTAssertTrue(
            results.isEmpty,
            "Ordinary speech must not detect scripture; got: \(results.map(\.displayReference))"
        )
    }

    // MARK: - Helpers

    private func assertDetection(
        in text: String,
        book: String,
        chapter: Int,
        verse: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let results = detector.detect(in: text)
        let match = results.first {
            $0.reference.book == book
                && $0.reference.chapter == chapter
                && $0.reference.verseStart == verse
        }
        XCTAssertNotNil(
            match,
            "Expected \(book) \(chapter):\(verse) in \(results.map(\.displayReference))",
            file: file,
            line: line
        )
    }
}
