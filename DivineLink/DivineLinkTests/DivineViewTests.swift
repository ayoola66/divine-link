import XCTest
@testable import DivineLink

@MainActor
final class DivineViewTests: XCTestCase {

    private var controller: DivineViewController { DivineViewController.shared }

    override func setUp() async throws {
        controller.clear()
    }

    override func tearDown() async throws {
        controller.clear()
    }

    func testPresentShowsReferenceTextAndTranslation() {
        controller.present(
            reference: "John 3:16",
            text: "For God so loved the world",
            translation: "KJV"
        )

        XCTAssertTrue(controller.isShowingVerse)
        XCTAssertEqual(controller.reference, "John 3:16")
        XCTAssertEqual(controller.verseText, "For God so loved the world")
        XCTAssertEqual(controller.translation, "KJV")
    }

    func testBlankTextDoesNotShowVerse() {
        controller.present(reference: "John 3:16", text: "   ", translation: "KJV")
        XCTAssertFalse(controller.isShowingVerse)
    }

    func testClearEmptiesDivineView() {
        controller.present(reference: "Psalm 23:1", text: "The Lord is my shepherd", translation: "NIV")
        controller.clear()

        XCTAssertFalse(controller.isShowingVerse)
        XCTAssertEqual(controller.reference, "")
        XCTAssertEqual(controller.verseText, "")
        XCTAssertEqual(controller.translation, "")
    }

    func testPresentAllUsesFullRangeText() {
        let verse = makeVerse(
            book: "John",
            chapter: 3,
            start: 16,
            end: 17,
            items: [
                VerseItem(verseNumber: 16, text: "For God so loved the world"),
                VerseItem(verseNumber: 17, text: "For God sent not his Son")
            ]
        )

        controller.presentAll(from: verse)

        XCTAssertEqual(controller.reference, "John 3:16-17")
        XCTAssertTrue(controller.verseText.contains("For God so loved the world"))
        XCTAssertTrue(controller.verseText.contains("For God sent not his Son"))
        XCTAssertEqual(controller.translation, "KJV")
    }

    func testPresentOneUsesCurrentVerseOnly() {
        var verse = makeVerse(
            book: "John",
            chapter: 3,
            start: 16,
            end: 17,
            items: [
                VerseItem(verseNumber: 16, text: "For God so loved the world"),
                VerseItem(verseNumber: 17, text: "For God sent not his Son")
            ]
        )
        verse.currentVerseIndex = 1

        controller.presentOne(from: verse)

        XCTAssertEqual(controller.reference, "John 3:17")
        XCTAssertEqual(controller.verseText, "For God sent not his Son")
        XCTAssertFalse(controller.verseText.contains("loved the world"))
    }

    func testPresentOneWithNoVersesLeavesCurrentVerseOnScreen() {
        controller.present(reference: "Psalm 23:1", text: "The Lord is my shepherd", translation: "KJV")

        let empty = makeVerse(book: "John", chapter: 3, start: 16, end: nil, items: [])
        controller.presentOne(from: empty)

        // presentOne guards on `currentVerse`; a verse with no items must not blank the screen.
        XCTAssertTrue(controller.isShowingVerse)
        XCTAssertEqual(controller.reference, "Psalm 23:1")
        XCTAssertEqual(controller.verseText, "The Lord is my shepherd")
    }

    func testOpenOnPushDisabledDoesNotRequestWindow() {
        let settings = DivineViewSettings.shared
        let original = settings.openOnPush
        defer { settings.openOnPush = original }

        settings.openOnPush = false
        let tickBeforePush = controller.windowOpenTick

        controller.present(reference: "John 3:16", text: "For God so loved the world", translation: "KJV")

        XCTAssertEqual(controller.windowOpenTick, tickBeforePush)
        XCTAssertTrue(controller.isShowingVerse)
    }

    /// Requirement: the Clear (panic) button must blank DivineView as well as ProPresenter.
    func testPanicClearsDivineView() async {
        let panic = PanicButtonService.shared
        let originalAudio = panic.playAudioFeedback
        panic.playAudioFeedback = false

        // Dependencies are held weakly, so these temporaries deallocate immediately and both
        // ProPresenter clear paths bail out at their `guard let client` — no network in tests.
        panic.configure(ppClient: ProPresenterClient(), buffer: BufferManager(), useHybridManager: false)
        defer {
            panic.playAudioFeedback = originalAudio
            panic.configure(ppClient: ProPresenterClient(), buffer: BufferManager(), useHybridManager: true)
        }

        controller.present(reference: "John 3:16", text: "For God so loved the world", translation: "KJV")
        XCTAssertTrue(controller.isShowingVerse)

        await panic.triggerClear()

        XCTAssertFalse(controller.isShowingVerse)
        XCTAssertEqual(controller.reference, "")
        XCTAssertEqual(controller.verseText, "")
        XCTAssertEqual(controller.translation, "")
    }

    func testBackgroundSettingPersists() {
        let settings = DivineViewSettings.shared
        let original = settings.background
        defer { settings.background = original }

        settings.background = .white
        XCTAssertEqual(UserDefaults.standard.string(forKey: "divineView.background"), "white")
        settings.background = .black
        XCTAssertEqual(UserDefaults.standard.string(forKey: "divineView.background"), "black")
    }

    private func makeVerse(
        book: String,
        chapter: Int,
        start: Int,
        end: Int?,
        items: [VerseItem]
    ) -> PendingVerse {
        PendingVerse(
            reference: ScriptureReference(
                book: book,
                chapter: chapter,
                verseStart: start,
                verseEnd: end
            ),
            verses: items,
            translation: "KJV",
            timestamp: Date(),
            confidence: 0.9
        )
    }
}
