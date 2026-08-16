import Foundation

/// Detects well-known Bible verses from their content without explicit references
class ImplicitReferenceDetector {
    
    // MARK: - Properties
    
    private let famousVerses: [String: String]
    /// Minimum number of words a famous-verse phrase must contain to be considered.
    /// Prevents 2-3 word fragments (e.g. "in the beginning") from firing before
    /// the preacher has said enough context to confirm which verse they mean.
    private let minimumPhraseWords = 5
    
    // MARK: - Initialisation
    
    init() {
        self.famousVerses = BibleVocabularyData.famousVerses
    }
    
    // MARK: - Detection
    
    /// Detect implicit scripture references from transcript text.
    /// Returns every eligible match, ranked best-first by `isRankedBefore`.
    ///
    /// Two phrases quoted in one debounce window is ordinary preaching — "in the
    /// beginning God created" against "in the beginning was the Word" is a standard
    /// Genesis/John pairing — and both are genuine, independent hits at different
    /// offsets. That is why this ranks rather than refusing the way
    /// `BookNameNormaliser.fuzzyMatch` does: there, one spoken token has several
    /// competing readings and at most one can be right, so choosing is a guess. Here
    /// there is no ambiguity to refuse, only two facts to put in a defensible order.
    func detect(in text: String) -> [ImplicitMatch] {
        let lowercasedText = text.lowercased()
        var matches: [ImplicitMatch] = []
        
        // `keys.sorted()` rather than a bare `for (phrase, reference) in famousVerses`:
        // Swift seeds `Dictionary` iteration per process, so walking the dictionary
        // directly builds a differently-ordered array on every launch. The comparator
        // below is a total order and so does not depend on this, but an unordered
        // source array makes the invariant impossible to see or to test.
        for phrase in famousVerses.keys.sorted() {
            guard let reference = famousVerses[phrase] else { continue }
            
            // Skip phrases that are too short to be unambiguous
            let wordCount = phrase.split(separator: " ").count
            guard wordCount >= minimumPhraseWords else { continue }
            
            guard let range = lowercasedText.range(of: phrase) else { continue }
            let offset = lowercasedText.distance(from: lowercasedText.startIndex, to: range.lowerBound)
            
            matches.append(ImplicitMatch(
                reference: reference,
                matchedPhrase: phrase,
                confidence: calculateConfidence(phrase: phrase, in: lowercasedText),
                firstMatchOffset: offset
            ))
        }
        
        return matches.sorted(by: Self.isRankedBefore)
    }
    
    /// A **total** order over matches — every pair is separated by some key, so no two
    /// entries ever compare equal.
    ///
    /// This is the whole fix. `sorted(by:)` is not a stable sort in Swift, and
    /// `calculateConfidence` saturates: any phrase of 24 characters or more scores
    /// exactly 1.0, which is 14 of the 15 phrases long enough to clear
    /// `minimumPhraseWords`. Ranking on confidence alone therefore left almost every
    /// pair tied, and a tie under an unstable sort resolves to whatever order the
    /// input array happened to arrive in — i.e. to the dictionary seed. Ordering on
    /// keys that cannot tie removes the dependency on both.
    ///
    /// Keys, in order:
    /// 1. **Confidence, descending.** Preserves the existing intent; the one
    ///    non-saturating phrase ("the lord is my shepherd", 0.967) still ranks below
    ///    the saturated ones.
    /// 2. **Matched phrase length, descending.** The most specific match wins — the
    ///    same rule `BibleService.findBookId` uses to choose between colliding book
    ///    keys. No phrase in today's table contains another, so this key currently
    ///    separates rather than subsumes; it is the correct answer either way, and it
    ///    stays correct if the table later gains an overlapping pair.
    /// 3. **First offset in the transcript, ascending.** Reading order.
    /// 4. **Phrase, lexicographically.** Guarantees totality so the result can never
    ///    depend on sort stability.
    static func isRankedBefore(_ lhs: ImplicitMatch, _ rhs: ImplicitMatch) -> Bool {
        if lhs.confidence != rhs.confidence { return lhs.confidence > rhs.confidence }
        if lhs.matchedPhrase.count != rhs.matchedPhrase.count {
            return lhs.matchedPhrase.count > rhs.matchedPhrase.count
        }
        if lhs.firstMatchOffset != rhs.firstMatchOffset {
            return lhs.firstMatchOffset < rhs.firstMatchOffset
        }
        return lhs.matchedPhrase < rhs.matchedPhrase
    }
    
    /// Check if text contains any famous verse phrases.
    ///
    /// Applies the same `minimumPhraseWords` gate as `detect(in:)`. Without it this
    /// answered `true` for four-word fragments such as "faith hope and love" that
    /// `detect` would never return, contradicting itself and ISC-211.
    func containsFamousVerse(_ text: String) -> Bool {
        let lowercasedText = text.lowercased()
        return famousVerses.keys.contains { phrase in
            phrase.split(separator: " ").count >= minimumPhraseWords
                && lowercasedText.contains(phrase)
        }
    }
    
    /// Get the best match for a given text
    func bestMatch(in text: String) -> ImplicitMatch? {
        return detect(in: text).first
    }
    
    // MARK: - Private Methods
    
    /// Confidence for a phrase already known to occur in `text`.
    ///
    /// The scores are deliberately unchanged: `DetectionPipeline` gates implicit
    /// matches at `confidence >= 0.6`, and the shortest eligible phrase already scores
    /// 0.967, so any rescaling risks silently dropping legitimate detections. Note
    /// that it saturates — 24 characters or more gives exactly 1.0 — so it cannot
    /// separate most candidates. `isRankedBefore` does that instead.
    ///
    /// - Precondition: `text` contains `phrase`. `detect(in:)` establishes this before
    ///   calling. The former `boundaryBonus` re-tested that precondition and was
    ///   therefore always 0.2; it is now written as the constant it always was, which
    ///   leaves every score identical.
    private func calculateConfidence(phrase: String, in text: String) -> Float {
        // Base confidence from phrase length
        let lengthScore = min(Float(phrase.count) / 30.0, 0.8)
        let boundaryBonus: Float = 0.2
        
        return min(lengthScore + boundaryBonus, 1.0)
    }
}

// MARK: - Implicit Match

struct ImplicitMatch {
    let reference: String
    let matchedPhrase: String
    let confidence: Float
    /// Character offset of the first occurrence of `matchedPhrase` in the lowercased
    /// transcript. Used by `ImplicitReferenceDetector.isRankedBefore` to order matches
    /// by reading position once confidence and specificity have tied.
    let firstMatchOffset: Int
    
    init(reference: String, matchedPhrase: String, confidence: Float, firstMatchOffset: Int = 0) {
        self.reference = reference
        self.matchedPhrase = matchedPhrase
        self.confidence = confidence
        self.firstMatchOffset = firstMatchOffset
    }
    
    /// Parse the reference into a ScriptureReference
    var scriptureReference: ScriptureReference? {
        // Parse reference like "John 3:16" or "1 Corinthians 13:4"
        let pattern = #"((?:\d\s)?[A-Za-z]+(?:\s[A-Za-z]+)?)\s+(\d+):(\d+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: reference, options: [], range: NSRange(reference.startIndex..., in: reference)) else {
            return nil
        }
        
        guard let bookRange = Range(match.range(at: 1), in: reference),
              let chapterRange = Range(match.range(at: 2), in: reference),
              let verseRange = Range(match.range(at: 3), in: reference),
              let chapter = Int(reference[chapterRange]),
              let verseStart = Int(reference[verseRange]) else {
            return nil
        }
        
        let book = String(reference[bookRange])
        
        return ScriptureReference(book: book, chapter: chapter, verseStart: verseStart, verseEnd: nil)
    }
}

// MARK: - Extended Detection Phrases

extension BibleVocabularyData {
    
    /// Additional phrases that can be added dynamically
    static var additionalFamousVerses: [String: String] = [:]
    
    /// Add a custom famous verse phrase
    static func addFamousVerse(phrase: String, reference: String) {
        additionalFamousVerses[phrase.lowercased()] = reference
    }
    
    /// Get all famous verses including custom additions
    static var allFamousVerses: [String: String] {
        var combined = famousVerses
        for (key, value) in additionalFamousVerses {
            combined[key] = value
        }
        return combined
    }
}
