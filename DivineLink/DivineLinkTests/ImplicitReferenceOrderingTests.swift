import XCTest
@testable import DivineLink

/// Third instance of the "Psalms became Amos" defect class.
///
/// `BookNameNormaliser.fuzzyMatch` and `BibleService.findBookId` both used to pick the
/// first entry out of an unordered Swift `Dictionary`. `ImplicitReferenceDetector` had
/// the same shape one layer up: `detect(in:)` walked `famousVerses` and ranked purely on
/// a confidence score that saturates at 1.0 for any phrase of 24 characters or more —
/// 14 of the 15 phrases long enough to clear `minimumPhraseWords`. `sorted(by:)` is not
/// a stable sort, so two quoted verses in one debounce window resolved to whichever the
/// dictionary seed happened to yield first.
///
/// **Why these tests probe the ordering rule rather than repeating a call.** Swift seeds
/// dictionary iteration once per *process*, so within a single test run the old code is
/// perfectly repeatable — a loop calling `detect` fifty times cannot see the defect by
/// construction. `testRankingIsATotalOrder` and `testOrderingIsIndependentOfInputOrder`
/// instead assert the property that makes the seed irrelevant, and both fail against the
/// confidence-only rule that shipped.
@MainActor
final class ImplicitReferenceOrderingTests: XCTestCase {

    private var detector: ImplicitReferenceDetector!

    /// Contains "in the beginning god created" (Genesis 1:1) and "in the beginning was
    /// the word" (John 1:1). Both are 24+ characters, so both score exactly 1.0. A
    /// preacher contrasting the two openings is ordinary, not a contrived edge case.
    private let genesisAndJohn = """
    in the beginning god created the heavens and the earth, and john tells us that \
    in the beginning was the word, and the word was with god
    """

    override func setUp() async throws {
        detector = ImplicitReferenceDetector()
    }

    override func tearDown() async throws {
        detector = nil
    }

    // MARK: - The defect

    /// The comparator must decide every pair in exactly one direction.
    ///
    /// This is the test with teeth. Under the shipped rule — `{ $0.confidence >
    /// $1.confidence }` — every saturated pair returns `false` in *both* directions,
    /// which is precisely the tie an unstable sort resolves by luck. Antisymmetry
    /// failing in even one pair means the order is not total.
    func testRankingIsATotalOrder() {
        let matches = detector.detect(in: allEligiblePhrasesTranscript())
        XCTAssertGreaterThan(matches.count, 1, "fixture must produce several matches")

        for lhs in matches {
            for rhs in matches where lhs.matchedPhrase != rhs.matchedPhrase {
                let forward = ImplicitReferenceDetector.isRankedBefore(lhs, rhs)
                let backward = ImplicitReferenceDetector.isRankedBefore(rhs, lhs)
                XCTAssertNotEqual(
                    forward,
                    backward,
                    "'\(lhs.matchedPhrase)' vs '\(rhs.matchedPhrase)' must be decided in exactly one direction"
                )
            }
        }
    }

    /// Demonstrates that the rule which shipped really is order-dependent, so the test
    /// above is guarding something real rather than restating an implementation detail.
    func testConfidenceOnlyRankingLeavesTiedPhrasesUndecided() {
        let matches = detector.detect(in: genesisAndJohn)
        XCTAssertEqual(matches.count, 2)

        let tied = matches[0].confidence == matches[1].confidence
        XCTAssertTrue(tied, "the fixture must actually tie on confidence, else it proves nothing")

        // The shipped comparator, reproduced verbatim.
        let confidenceOnly: (ImplicitMatch, ImplicitMatch) -> Bool = { $0.confidence > $1.confidence }
        XCTAssertFalse(confidenceOnly(matches[0], matches[1]))
        XCTAssertFalse(confidenceOnly(matches[1], matches[0]))
    }

    /// Sorting the same matches from any starting order must give the same answer.
    /// Under confidence-only ranking each permutation keeps its own input order, so the
    /// winner changes with the arrangement — i.e. with the dictionary seed.
    func testOrderingIsIndependentOfInputOrder() {
        let matches = detector.detect(in: allEligiblePhrasesTranscript())
        let expected = matches.map(\.reference)

        for permutation in permutationsBySeededShuffle(of: matches, count: 40) {
            let ranked = permutation.sorted(by: ImplicitReferenceDetector.isRankedBefore)
            XCTAssertEqual(
                ranked.map(\.reference),
                expected,
                "ranking must not depend on the order matches were collected in"
            )
        }
    }

    /// The pairing that motivated the fix now has one stated answer rather than a
    /// coin toss. John 1:1 wins on specificity: "in the beginning was the word" is 29
    /// characters against Genesis's 28, and the length key outranks position.
    func testGenesisAndJohnPairingResolvesToAStatedWinner() {
        XCTAssertEqual(detector.bestMatch(in: genesisAndJohn)?.reference, "John 1:1")
    }

    /// The weaker in-process probe, kept for parity with `BookMishearingTests`. It
    /// cannot fail against the old code, and is here only to catch a future change that
    /// makes `detect` non-repeatable within one run.
    func testDetectionIsStableAcrossRepeatedCalls() {
        let first = detector.detect(in: genesisAndJohn).map(\.reference)
        for _ in 0..<50 {
            XCTAssertEqual(detector.detect(in: genesisAndJohn).map(\.reference), first)
        }
    }

    // MARK: - Ranking keys

    /// Longest match wins, because it is the most specific evidence — the same rule
    /// `BibleService.findBookId` uses for colliding book keys.
    func testLongerMatchOutranksShorterAtEqualConfidence() {
        let long = ImplicitMatch(reference: "A 1:1", matchedPhrase: String(repeating: "a", count: 40), confidence: 1.0, firstMatchOffset: 90)
        let short = ImplicitMatch(reference: "B 1:1", matchedPhrase: String(repeating: "b", count: 30), confidence: 1.0, firstMatchOffset: 0)

        XCTAssertTrue(ImplicitReferenceDetector.isRankedBefore(long, short))
        XCTAssertFalse(ImplicitReferenceDetector.isRankedBefore(short, long))
    }

    /// Position decides only once confidence and specificity have tied.
    func testEarlierMatchOutranksLaterAtEqualLength() {
        let early = ImplicitMatch(reference: "A 1:1", matchedPhrase: "aaaaaaaaaaaaaaaaaaaaaaaaa", confidence: 1.0, firstMatchOffset: 3)
        let late = ImplicitMatch(reference: "B 1:1", matchedPhrase: "bbbbbbbbbbbbbbbbbbbbbbbbb", confidence: 1.0, firstMatchOffset: 80)

        XCTAssertTrue(ImplicitReferenceDetector.isRankedBefore(early, late))
        XCTAssertFalse(ImplicitReferenceDetector.isRankedBefore(late, early))
    }

    /// Identical on every meaningful axis: the phrase itself is the last resort, so no
    /// pair can ever compare equal and sort stability becomes irrelevant.
    func testIdenticalRanksFallBackToThePhrase() {
        let a = ImplicitMatch(reference: "A 1:1", matchedPhrase: "aaaa", confidence: 1.0, firstMatchOffset: 0)
        let b = ImplicitMatch(reference: "B 1:1", matchedPhrase: "bbbb", confidence: 1.0, firstMatchOffset: 0)

        XCTAssertTrue(ImplicitReferenceDetector.isRankedBefore(a, b))
        XCTAssertFalse(ImplicitReferenceDetector.isRankedBefore(b, a))
    }

    // MARK: - Consistency with ISC-211

    /// `containsFamousVerse` used to ignore `minimumPhraseWords`, so it answered `true`
    /// for four-word fragments that `detect` would never return.
    func testContainsFamousVerseAppliesTheSameWordGateAsDetect() {
        let shortFragment = "he spoke of faith hope and love"

        XCTAssertTrue(detector.detect(in: shortFragment).isEmpty)
        XCTAssertFalse(
            detector.containsFamousVerse(shortFragment),
            "a 4-word fragment must not report a famous verse that detect() will not return"
        )

        // …and a phrase that does clear the gate still reports.
        XCTAssertTrue(detector.containsFamousVerse("for god so loved the world"))
    }

    // MARK: - Helpers

    /// A transcript containing many eligible phrases at once, so the ordering tests see
    /// a realistic spread rather than a single pair.
    private func allEligiblePhrasesTranscript() -> String {
        [
            "in the beginning god created",
            "in the beginning was the word",
            "for god so loved the world",
            "the lord is my shepherd",
            "i can do all things through christ",
            "be still and know that i am god",
            "all things work together for good",
            "greater love has no one than this"
        ].joined(separator: ", and then ")
    }

    /// Deterministic shuffles — a fixed sequence of rotations and swaps — so a failure
    /// reproduces exactly rather than depending on a random seed.
    private func permutationsBySeededShuffle(of matches: [ImplicitMatch], count: Int) -> [[ImplicitMatch]] {
        guard matches.count > 1 else { return [matches] }
        var results: [[ImplicitMatch]] = []
        var working = matches

        for step in 0..<count {
            working = Array(working[1...]) + [working[0]]          // rotate
            let i = step % working.count
            let j = (step * 7 + 3) % working.count                  // coprime stride
            working.swapAt(i, j)
            results.append(working)
        }
        return results
    }
}
