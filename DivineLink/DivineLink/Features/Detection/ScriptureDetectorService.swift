import Foundation
import Combine
import os

// MARK: - Detection Rejection

/// A detection the detector refused to surface, and why.
///
/// "Reject rather than guess" is the right policy, but on its own it trades a visible
/// wrong verse for an invisible missing one: the operator cannot tell silence-because-
/// rejected from silence-because-nothing-was-said. Publishing the refusal restores that
/// distinction without ever putting a wrong reference on screen.
struct DetectionRejection: Identifiable, Equatable {
    let id = UUID()
    /// The reference as heard, before normalisation — e.g. "sames 3 verse 5".
    let heard: String
    /// Operator-facing explanation, in British English.
    ///
    /// States the *kind* of failure only. It deliberately does not name the books in
    /// contention: those live in `candidateBooks` and are rendered from there, so
    /// rewording this string cannot silently remove them from the operator's view.
    let reason: String
    /// Books that were genuinely in contention, and only then.
    ///
    /// Invariant: either empty, or two or more entries. A single already-resolved book
    /// is not "in contention" and must not be passed here — five call sites used to do
    /// exactly that, which made the field unreadable as evidence of ambiguity.
    let candidateBooks: [String]
    let timestamp: Date
    
    init(heard: String, reason: String, candidateBooks: [String] = [], timestamp: Date = Date()) {
        self.heard = heard
        self.reason = reason
        self.candidateBooks = candidateBooks
        self.timestamp = timestamp
    }
    
    /// Single-line summary for the operator console.
    var summary: String {
        "Heard \u{201C}\(heard)\u{201D} — \(reason)"
    }
    
    /// The books in contention, phrased for the operator — "1 Samuel or James".
    /// `nil` unless this was a genuine ambiguity, so the console renders the line only
    /// when there really was a choice to be made.
    var candidateSummary: String? {
        guard candidateBooks.count >= 2, let last = candidateBooks.last else { return nil }
        let leading = candidateBooks.dropLast().joined(separator: ", ")
        return "\(leading) or \(last)"
    }
    
    static func == (lhs: DetectionRejection, rhs: DetectionRejection) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Detection Result

/// Result of scripture detection with metadata
struct DetectionResult: Identifiable {
    let id = UUID()
    let reference: ScriptureReference
    let rawMatch: String
    let detectionConfidence: DetectionConfidence
    let timestamp: Date
    let patternType: String  // For debugging/analytics
    
    /// Legacy confidence value for backwards compatibility
    var confidence: Float {
        Float(detectionConfidence.overall)
    }
    
    /// Formatted display string
    var displayReference: String {
        reference.formatted
    }
    
    /// Convenience init with legacy Float confidence (for backwards compatibility)
    init(
        reference: ScriptureReference,
        rawMatch: String,
        confidence: Float,
        timestamp: Date
    ) {
        self.reference = reference
        self.rawMatch = rawMatch
        self.detectionConfidence = DetectionConfidence.fromLegacy(confidence)
        self.timestamp = timestamp
        self.patternType = "legacy"
    }
    
    /// Full init with DetectionConfidence
    init(
        reference: ScriptureReference,
        rawMatch: String,
        detectionConfidence: DetectionConfidence,
        timestamp: Date,
        patternType: String
    ) {
        self.reference = reference
        self.rawMatch = rawMatch
        self.detectionConfidence = detectionConfidence
        self.timestamp = timestamp
        self.patternType = patternType
    }
}

// MARK: - Scripture Detector Service

/// Service that detects scripture references in transcript text
@MainActor
class ScriptureDetectorService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var lastDetection: DetectionResult?
    @Published var isProcessing = false
    
    /// The most recent refusal, for the transient row in the operator console.
    /// Cleared automatically after `rejectionDisplayDuration` so it never accumulates.
    @Published var lastRejection: DetectionRejection?
    
    // MARK: - Publishers
    
    /// Publishes detected scripture references
    let detectionPublisher = PassthroughSubject<DetectionResult, Never>()
    
    /// Publishes references the detector refused, so a rejection is visible rather
    /// than merely silent. Subscribers must treat these as informational only —
    /// nothing here is safe to present to a congregation.
    let rejectionPublisher = PassthroughSubject<DetectionRejection, Never>()
    
    /// How long a refusal stays on screen before clearing itself.
    private let rejectionDisplayDuration: TimeInterval = 6.0
    private var rejectionClearTask: Task<Void, Never>?
    
    // MARK: - Confidence Tuning
    
    /// Confidence deducted from `referenceClarity` for each edit between the book name as
    /// heard and the nearest known alias.
    ///
    /// **Coupled to `minimumConfidence`.** The penalty applies to `referenceClarity`,
    /// weighted 0.4 in `DetectionConfidence`, so each edit costs `0.4 × penalty` overall.
    /// The tightest pattern is `chapterOnly`, whose base overall is 0.780 — only 0.030
    /// above the 0.75 gate. A one-edit guess therefore survives only while
    /// `penalty < 0.030 / 0.4 = 0.075`.
    ///
    /// At 0.15 it did not survive: 0.780 − 0.4 × 0.15 = 0.720, so ordinary utterances such
    /// as "Romans 8" with a slightly misheard book were silently dropped, and the same flip
    /// hit `spoken`, `spokenRange` and `spokenWords` at distance 2. 0.07 is the largest
    /// round value below that 0.075 ceiling: distance 1 clears the gate for every pattern
    /// (`chapterOnly` = 0.752, the tightest), while distance 2 still costs enough to refuse
    /// a two-edit guess carrying no verse number (`chapterOnly` = 0.724, refused).
    /// `ConfidencePenaltyTests` pins the whole grid, so any future change is measured.
    static let bookGuessPenaltyPerEdit = 0.07
    
    /// Detections below this overall confidence are refused rather than shown.
    /// **Coupled to `bookGuessPenaltyPerEdit`** — raising either can silently start
    /// dropping detections that previously displayed. Change them together, against the
    /// grid in `ConfidencePenaltyTests`.
    static let minimumConfidence: Double = 0.75
    
    // MARK: - Dependencies
    
    /// Returns true when a reference actually exists in the loaded Bible.
    /// Injected by `DetectionPipeline`; when unset every reference is accepted, so
    /// unit tests and previews keep working without a database.
    var referenceValidator: ((ScriptureReference) -> Bool)?
    
    // MARK: - Private Properties
    
    let bookNormaliser = BookNameNormaliser()
    private var recentDetections: [String: Date] = [:]
    private let debounceInterval: TimeInterval = 5.0
    
    // Compiled regex patterns
    private var patterns: [(NSRegularExpression, PatternType)] = []
    
    // MARK: - Pattern Types
    
    private enum PatternType {
        case standard       // John 3:16 or John 3:16-18
        case spoken         // John 316 or John 3 16 (speech recognition format)
        case spokenRange    // John 316 to 18 or John 3 16 to 18 (spoken with range)
        case verbal         // John chapter 3 verse 16
        case verbalShort    // Genesis 1 verse 1 (no "chapter" keyword)
        case spokenWords    // Genesis twenty one one → 21:1, John three sixteen → 3:16
        case chapterOnly    // Romans 8
        case invertedVerbal // "verse 31 of Romans 8" or "verse 31 of Romans eight"
        case bookVerseChapter // "John verse 16 chapter 5" → John 5:16 (verse spoken before chapter)
        case partialVerse   // "verse 18" or "verses 5 to 7" (requires context)
    }
    
    // MARK: - Reference Buffer
    
    /// Reference buffer for stateful context tracking. Injectable so tests can supply a
    /// fresh instance rather than mutating the process-wide singleton and depending on
    /// whatever `UserDefaults` happens to say on the machine running them.
    private let referenceBuffer: ReferenceBuffer
    
    // MARK: - Number Word Conversion
    
    private let numberWords: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
        "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19, "twenty": 20,
        "twenty-one": 21, "twenty-two": 22, "twenty-three": 23, "twenty-four": 24, "twenty-five": 25,
        "twenty-six": 26, "twenty-seven": 27, "twenty-eight": 28, "twenty-nine": 29, "thirty": 30,
        "thirty-one": 31, "thirty-two": 32, "thirty-three": 33, "thirty-four": 34, "thirty-five": 35,
        "thirty-six": 36, "thirty-seven": 37, "thirty-eight": 38, "thirty-nine": 39, "forty": 40,
        "forty-one": 41, "forty-two": 42, "forty-three": 43, "forty-four": 44, "forty-five": 45,
        "forty-six": 46, "forty-seven": 47, "forty-eight": 48, "forty-nine": 49, "fifty": 50,
        "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5,
        "1st": 1, "2nd": 2, "3rd": 3, "4th": 4, "5th": 5,
    ]
    
    // MARK: - Initialisation
    
    init(referenceBuffer: ReferenceBuffer = .shared) {
        self.referenceBuffer = referenceBuffer
        compilePatterns()
    }
    
    private func compilePatterns() {
        // IMPORTANT: Order matters! More specific patterns should come FIRST
        // to prevent less specific patterns from matching partial references
        
        // 1. VERBAL FORMAT (most specific - has "chapter" and "verse" keywords)
        // "John chapter 3 verse 16" or "Genesis chapter 1 verses 1 to 5"
        // Book capture accepts spoken/roman ordinals ("Second Timothy", "First John",
        // "II Timothy") as well as digit forms ("2 Timothy" / "2Timothy"). Without this,
        // "Second Timothy chapter…" matched bare "Timothy" → wrongly normalised to 1 Timothy.
        // Accepts both digits and number words for chapter and verse
        // Also accepts "versus" as speech recognition often mishears "verse"
        // The end of a range may repeat the keyword — "verse 8 to verse 12" is as common
        // from the pulpit as "verse 8 to 12", and without the optional keyword the range
        // was dropped and only verse 8 shown.
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:(?:first|second|third|1st|2nd|3rd|i|ii|iii)\s+)?(?:\d\s?)?[A-Za-z]+)\s+chapter\s+(\d{1,3}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|twenty-?\w*|thirty|thirty-?\w*|forty|forty-?\w*|fifty)\s+(?:verse?s?|versus)\s+(\d{1,3}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|twenty-?\w*|thirty|thirty-?\w*|forty|forty-?\w*|fifty)(?:\s+(?:to|through|-)\s+(?:(?:verse?s?|versus)\s+)?(\d{1,3}|[a-z-]+))?"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .verbal))
            print("✅ verbal pattern compiled (priority 1)")
        }

        // 1b. INVERTED BOOK-VERSE-CHAPTER: "John verse 16 chapter 5" → John 5:16
        // Some speakers say the verse before the chapter. Requires BOTH the "verse"
        // AND "chapter" keywords in that order, so it is unambiguous and cannot
        // produce false positives. High priority (right after the standard verbal).
        // Groups: (1)book (2)verse_start (3)verse_end optional (4)chapter
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:(?:first|second|third|1st|2nd|3rd|i|ii|iii)\s+)?(?:\d\s?)?[A-Za-z]+)\s+(?:verse?s?|versus)\s+(\d{1,3}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|twenty-?\w*|thirty|thirty-?\w*|forty|forty-?\w*|fifty)(?:\s+(?:to|through|-)\s+(?:(?:verse?s?|versus)\s+)?(\d{1,3}|[a-z]+(?:-[a-z]+)?))?\s+chapter\s+(\d{1,3}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|twenty-?\w*|thirty|thirty-?\w*|forty|forty-?\w*|fifty)(?:\s|$|[,.])"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .bookVerseChapter))
            print("✅ bookVerseChapter pattern compiled (priority 1b - verse before chapter)")
        }

        // 2. VERBAL SHORT: "Genesis 1 verse 1" or "John 3 verse 16 to 20" (no "chapter" keyword)
        // Limit chapter to 1-2 digits (max 99) to avoid matching "316" as chapter
        // Also accept "versus" as speech recognition often mishears "verse"
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:(?:first|second|third|1st|2nd|3rd|i|ii|iii)\s+)?(?:\d\s?)?[A-Za-z]+)\s+(\d{1,2})\s+(?:verse?s?|versus)\s+(\d{1,3}|[a-z]+(?:-[a-z]+)?)(?:\s+(?:to|through|-)\s+(?:(?:verse?s?|versus)\s+)?(\d{1,3}|[a-z]+(?:-[a-z]+)?))?(?:\s|$|[,.])"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .verbalShort))
            print("✅ verbalShort pattern compiled (priority 2)")
        }
        
        // 2b. VERBAL SHORT with word chapter: "John three verse 16" or "Genesis one verse 1"
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:(?:first|second|third|1st|2nd|3rd|i|ii|iii)\s+)?(?:\d\s?)?[A-Za-z]+)\s+(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|twenty-?\w*|thirty|thirty-?\w*|forty|forty-?\w*|fifty)\s+(?:verse?s?|versus)\s+(\d{1,3}|[a-z]+(?:-[a-z]+)?)(?:\s+(?:to|through|-)\s+(?:(?:verse?s?|versus)\s+)?(\d{1,3}|[a-z]+(?:-[a-z]+)?))?(?:\s|$|[,.])"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .verbalShort))
            print("✅ verbalShort (word chapter) pattern compiled")
        }
        
        // 3. STANDARD FORMAT: "John 3:16" or "John 3:16-18" or "1 John 3:16"
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:\d\s?)?[A-Za-z]+(?:\s[A-Za-z]+)?)\s+(\d{1,3}):(\d{1,3})(?:\s?-\s?(\d{1,3}))?"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .standard))
        }
        
        // 4. SPOKEN RANGE FORMAT: "John 316 to 18" → John 3:16-18 (concatenated with range)
        // Groups: (1)book (2)chapter (3)verse_start (4)verse_end
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:\d\s?)?[A-Za-z]+(?:\s[A-Za-z]+)?)\s+(\d{1,2})(\d{2})\s+(?:to|through|-)\s+(\d{1,3})(?:\s|$|[,.])"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .spokenRange))
            print("✅ spokenRange (concatenated) pattern compiled")
        }
        
        // 5. SPOKEN RANGE FORMAT with spaces: "John 3 16 to 18" → John 3:16-18
        // Groups: (1)book (2)chapter (3)verse_start (4)verse_end
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:\d\s?)?[A-Za-z]+(?:\s[A-Za-z]+)?)\s+(\d{1,3})\s+(\d{1,3})\s+(?:to|through|-)\s+(\d{1,3})(?:\s|$|[,.])"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .spokenRange))
            print("✅ spokenRange (spaced) pattern compiled")
        }
        
        // 6. SPOKEN FORMAT without colon: "John 316" (chapter+verse concatenated) - NO RANGE
        // ONLY matches 3+ digits to avoid "11" being split into "1:1"
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:\d\s?)?[A-Za-z]+(?:\s[A-Za-z]+)?)\s+(\d{1,2})(\d{2})(?:\s|$|[,.])"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .spoken))
        }
        
        // 7. SPOKEN FORMAT with space: "John 3 16" (space instead of colon) - NO RANGE
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:\d\s?)?[A-Za-z]+(?:\s[A-Za-z]+)?)\s+(\d{1,3})\s+(\d{1,3})(?:\s|$|[,.])"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .spoken))
        }
        
        // 6. VERBAL with word numbers: "Genesis one verse one"
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:(?:first|second|third|1st|2nd|3rd|i|ii|iii)\s+)?(?:\d\s?)?[A-Za-z]+)\s+(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|twenty-\w+|thirty|thirty-\w+|forty|forty-\w+|fifty)\s+verse?s?\s+(\d{1,3}|[a-z]+(?:-[a-z]+)?)(?:\s|$|[,.])"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .verbalShort))
        }
        
        // 7. SPOKEN WORD NUMBERS: "John three sixteen" → 3:16
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:(?:first|second|third|1st|2nd|3rd|i|ii|iii)\s+)?(?:\d\s?)?[A-Za-z]+)\s+(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\s+(ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|twenty-?\w*|thirty|thirty-?\w*)(?:\s|$|[,.])"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .spokenWords))
        }
        
        // 8. CHAPTER ONLY: "Romans 8" (LAST - least specific)
        // Only match at end of text or followed by punctuation to avoid partial matches
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:(?:first|second|third|1st|2nd|3rd|i|ii|iii)\s+)?(?:\d\s?)?[A-Za-z]+)\s+(\d{1,3})(?:\s*[,.!?;:]|\s*$)"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .chapterOnly))
        }
        
        // 9. INVERTED VERBAL: "verse 31 of Romans 8" or "verse 31 of Romans eight"
        // Captures: (verse_start) (verse_end optional) (book) (chapter as number or word)
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)(?:verse?s?|versus)\s+(\d{1,3}|[a-z]+(?:-[a-z]+)?)(?:\s+(?:to|through|-)\s+(?:(?:verse?s?|versus)\s+)?(\d{1,3}|[a-z]+(?:-[a-z]+)?))?\s+(?:of|in|from)\s+((?:(?:first|second|third|1st|2nd|3rd|i|ii|iii)\s+)?(?:\d\s?)?[A-Za-z]+)\s+(\d{1,3}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|twenty-?\w*|thirty|thirty-?\w*|forty|forty-?\w*|fifty)(?:\s|$|[,.])"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .invertedVerbal))
            print("✅ invertedVerbal pattern compiled (verse X of Book Y)")
        }
        
        // 10. PARTIAL VERSE: "verse 18" or "verses 5 to 7" (requires context buffer)
        // This is lowest priority - only works if we have context from a previous detection
        // Pattern captures: (verse_start) and optionally (verse_end)
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)(?:verse?s?|versus)\s+(\d{1,3}|[a-z]+(?:-[a-z]+)?)(?:\s+(?:to|through|-)\s+(?:(?:verse?s?|versus)\s+)?(\d{1,3}|[a-z]+(?:-[a-z]+)?))?"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .partialVerse))
            print("✅ partialVerse pattern compiled (priority 10 - requires context)")
        }
        
        // 9b. PARTIAL VERSE with "the": "the next verse", "the following verse", or "the previous verse"
        // Handles: "the next verse", "the following verse", "the previous verse"
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)(?:the\s+)?(?:next|following|previous)\s+verse"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .partialVerse))
            print("✅ partialVerse (next/following/previous) pattern compiled")
        }
    }
    
    // MARK: - Detection
    
    /// Detect scripture references in the given text
    func detect(in text: String) -> [DetectionResult] {
        isProcessing = true
        defer { isProcessing = false }
        
        var results: [DetectionResult] = []
        
        for (regex, patternType) in patterns {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: range)
            
            for match in matches {
                if let result = parseMatch(match, in: text, type: patternType) {
                    // Check for duplicate (debounce)
                    let key = result.displayReference
                    if !isDuplicate(key) {
                        results.append(result)
                        recentDetections[key] = Date()
                        
                        // Update last detection and publish
                        lastDetection = result
                        detectionPublisher.send(result)
                    }
                }
            }
        }
        
        return results
    }
    
    /// Process a transcript segment for scripture references
    func processSegment(_ segment: TranscriptionSegment) -> [DetectionResult] {
        return detect(in: segment.text)
    }
    
    // MARK: - Parsing
    
    private func parseMatch(_ match: NSTextCheckingResult, in text: String, type: PatternType) -> DetectionResult? {
        // Handle partial verse references (requires context buffer)
        if type == .partialVerse {
            return parsePartialVerseMatch(match, in: text)
        }
        
        // Handle inverted verbal references: "verse X of Book Y"
        if type == .invertedVerbal {
            return parseInvertedVerbalMatch(match, in: text)
        }

        // Handle book-verse-chapter references: "John verse 16 chapter 5" → John 5:16
        if type == .bookVerseChapter {
            return parseBookVerseChapterMatch(match, in: text)
        }
        
        // Extract book name
        guard match.numberOfRanges >= 3,
              let bookRange = Range(match.range(at: 1), in: text),
              let chapterRange = Range(match.range(at: 2), in: text) else {
            return nil
        }
        
        var rawBook = String(text[bookRange]).trimmingCharacters(in: .whitespaces)
        
        // CRITICAL: Reject common words that are frequently misidentified as book names
        // These cause false detections when audio quality is poor
        let commonWordsToReject: Set<String> = [
            "for", "of", "on", "and", "or", "but", "the", "a", "an", "in", "at", "to",
            "drop", "instead", "instead of", "with", "from", "by", "about", "through",
            "is", "are", "was", "were", "be", "been", "being", "have", "has", "had",
            "do", "does", "did", "done", "go", "goes", "went", "gone", "get", "got",
            "say", "says", "said", "see", "sees", "saw", "know", "knows", "knew",
            "think", "thinks", "thought", "take", "takes", "took", "come", "comes", "came"
        ]
        
        let rawBookLower = rawBook.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Reject if the entire "book name" is a common word
        if commonWordsToReject.contains(rawBookLower) {
            Logger.detection.debug("Rejected common word as book name: '\(rawBook, privacy: .public)' (pattern: \(String(describing: type), privacy: .public))")
            return nil
        }
        
        // Strip common leading words that get captured before book names
        // e.g., "to Exodus" → "Exodus", "you John" → "John", "the Psalms" → "Psalms"
        let wordsToStrip = [
            // Prepositions
            "to", "in", "from", "the", "of", "at", "on", "for", "by", "into", "unto", "about", "through",
            // Common speech fragments
            "you", "we", "lets", "let's", "let", "us", "our", "and", "or", "but", "so", "now",
            "open", "read", "turn", "go", "see", "look", "find",
            // Filler words
            "a", "an", "would", "could", "should", "please", "just", "also", "then"
        ]
        for word in wordsToStrip {
            let prefix = word + " "
            if rawBook.lowercased().hasPrefix(prefix) {
                rawBook = String(rawBook.dropFirst(prefix.count))
                // Don't break - strip multiple words if needed ("would you John" → "John")
            }
        }
        rawBook = rawBook.trimmingCharacters(in: .whitespaces)
        
        // After stripping, check again if it's a common word
        let strippedLower = rawBook.lowercased().trimmingCharacters(in: .whitespaces)
        if strippedLower.isEmpty || commonWordsToReject.contains(strippedLower) {
            Logger.detection.debug("Rejected stripped result as common word: '\(rawBook, privacy: .public)' (pattern: \(String(describing: type), privacy: .public))")
            return nil
        }
        
        // The chapter is parsed properly further down, but an approximate value is
        // needed now: when the book name is an ambiguous mishearing, the chapter
        // number is often the only thing that can settle which book was meant.
        let chapterHint = parseNumber(
            String(text[chapterRange]).trimmingCharacters(in: .whitespaces).lowercased()
        )
        
        // Normalise book name. `match` rather than `normalise` because the edit distance
        // it resolved is needed below to score the detection, and recomputing it would
        // mean sweeping every alias a second time for the same input.
        let bookOutcome = bookNormaliser.match(rawBook, chapterHint: chapterHint)
        guard case .matched(let canonicalBook, let matchQuality) = bookOutcome else {
            if case .rejected(let failure) = bookOutcome {
                let heard = Range(match.range, in: text).map {
                    String(text[$0]).trimmingCharacters(in: .whitespaces)
                } ?? rawBook
                // Candidates are logged explicitly rather than relied upon to appear
                // inside `failure.reason`, which no longer interpolates them.
                let candidateLog = failure.candidateBooks.isEmpty
                    ? "none"
                    : failure.candidateBooks.joined(separator: ", ")
                Logger.detection.warning("Book not recognised: '\(rawBook, privacy: .public)' (pattern: \(String(describing: type), privacy: .public)) — \(failure.reason, privacy: .public) [candidates: \(candidateLog, privacy: .public)]")
                // Only surface genuine ambiguities to the operator. Excluded words and
                // short fragments fire constantly on ordinary speech, so reporting them
                // would bury the refusals that actually matter.
                if case .ambiguous = failure {
                    publishRejection(
                        DetectionRejection(
                            heard: heard,
                            reason: failure.reason,
                            candidateBooks: failure.candidateBooks
                        )
                    )
                }
            }
            return nil // Not a valid book name
        }
        
        Logger.detection.debug("Parsing match: book='\(rawBook, privacy: .public)'→'\(canonicalBook, privacy: .public)' (pattern: \(String(describing: type), privacy: .public))")
        
        var chapter: Int
        var verseStart = 1
        var verseEnd: Int? = nil
        // Distinguishes a verse the speaker actually said from `verseStart`'s default of 1.
        // The concatenation-repair path in `DetectionPipeline` depends on the difference.
        var verseWasSpoken = false
        
        // Special handling for spokenWords pattern: "twenty one one" → 21:1
        if type == .spokenWords {
            // For compound chapter numbers, groups are: (book)(tens)(units)(verse)
            // Or for simple: (book)(chapter)(verse)
            let chapterPart1 = String(text[chapterRange]).trimmingCharacters(in: .whitespaces).lowercased()
            
            if match.numberOfRanges >= 4, let part2Range = Range(match.range(at: 3), in: text) {
                let chapterPart2 = String(text[part2Range]).trimmingCharacters(in: .whitespaces).lowercased()
                
                // Check if this is a compound number (twenty + one = 21)
                if let tens = parseNumber(chapterPart1), tens >= 20 && tens % 10 == 0,
                   let units = parseNumber(chapterPart2), units >= 1 && units <= 9 {
                    // Compound: "twenty" (20) + "one" (1) = 21
                    chapter = tens + units
                    
                    // Verse is in group 4
                    if match.numberOfRanges >= 5, let verseRange = Range(match.range(at: 4), in: text) {
                        let verseStr = String(text[verseRange]).trimmingCharacters(in: .whitespaces).lowercased()
                        if let verse = parseNumber(verseStr) {
                            verseStart = verse
                            verseWasSpoken = true
                        }
                    }
                } else {
                    // Not compound, just two separate numbers: chapter and verse
                    guard let ch = parseNumber(chapterPart1) else { return nil }
                    chapter = ch
                    if let verse = parseNumber(chapterPart2) {
                        verseStart = verse
                        verseWasSpoken = true
                    }
                }
            } else {
                guard let ch = parseNumber(chapterPart1) else { return nil }
                chapter = ch
            }
        } else {
            // Standard parsing for other pattern types
            let chapterStr = String(text[chapterRange]).trimmingCharacters(in: .whitespaces).lowercased()
            guard let ch = parseNumber(chapterStr) else {
                return nil
            }
            
            // Validate chapter is reasonable (Psalms has max 150 chapters)
            // This prevents "316" being parsed as chapter 316
            if ch > 150 {
                Logger.detection.warning("Rejected invalid chapter number: \(ch, privacy: .public) (max allowed: 150)")
                publishRejection(
                    DetectionRejection(
                        heard: "\(rawBook) \(ch)",
                        reason: "chapter \(ch) is beyond the 150 chapters of the longest book"
                    )
                )
                return nil
            }
            
            // Additional validation: most books have far fewer chapters
            // Only Psalms has 150, Isaiah has 66, Jeremiah 52, etc.
            // Reject obviously wrong chapter numbers for non-Psalms books
            if ch > 50 && type != .chapterOnly {
                // This is suspicious - log it for review
                Logger.detection.info("Suspicious high chapter number: \(ch, privacy: .public) for pattern \(String(describing: type), privacy: .public)")
            }
            
            chapter = ch
            
            if type != .chapterOnly {
                // Get start verse - handle both numbers and words
                if match.numberOfRanges >= 4,
                   let verseRange = Range(match.range(at: 3), in: text) {
                    let verseStr = String(text[verseRange]).trimmingCharacters(in: .whitespaces).lowercased()
                    if let verse = parseNumber(verseStr) {
                        verseStart = verse
                        verseWasSpoken = true
                    }
                }
                
                // Get end verse (for ranges) - handle both numbers and words
                if match.numberOfRanges >= 5,
                   match.range(at: 4).location != NSNotFound,
                   let endRange = Range(match.range(at: 4), in: text) {
                    let endStr = String(text[endRange]).trimmingCharacters(in: .whitespaces).lowercased()
                    verseEnd = parseNumber(endStr)
                }
            }
        }
        
        // Validate verse numbers are reasonable
        // Most chapters have fewer than 50 verses, very few have more than 100
        // Psalm 119 has 176 verses (the longest)
        if verseStart > 176 {
            Logger.detection.warning("Rejected invalid verse number: \(verseStart, privacy: .public) (max allowed: 176)")
            publishRejection(
                DetectionRejection(
                    heard: "\(canonicalBook) \(chapter):\(verseStart)",
                    reason: "verse \(verseStart) is beyond the 176 verses of the longest chapter"
                )
            )
            return nil
        }
        
        if let endVerse = verseEnd, endVerse > 176 {
            Logger.detection.warning("Rejected invalid end verse: \(endVerse, privacy: .public) (max allowed: 176)")
            return nil
        }
        
        // Reject if verse start is higher than verse end (invalid range)
        if let endVerse = verseEnd, verseStart > endVerse {
            Logger.detection.warning("Rejected invalid verse range: \(verseStart, privacy: .public)-\(endVerse, privacy: .public) (start > end)")
            return nil
        }
        
        // Reject suspiciously large verse ranges (more than 30 verses at once is unusual)
        if let endVerse = verseEnd, (endVerse - verseStart) > 30 {
            Logger.detection.info("Suspicious large verse range: \(verseStart, privacy: .public)-\(endVerse, privacy: .public) (\(endVerse - verseStart, privacy: .public) verses)")
            // Still allow but log it
        }
        
        // Extract the raw matched text
        let rawMatch: String
        if let fullRange = Range(match.range, in: text) {
            rawMatch = String(text[fullRange]).trimmingCharacters(in: .whitespaces)
        } else {
            rawMatch = "\(rawBook) \(chapter):\(verseStart)"
        }
        
        // Create scripture reference
        let reference = ScriptureReference(
            book: canonicalBook,
            chapter: chapter,
            verseStart: verseStart,
            verseEnd: verseEnd,
            verseWasSpoken: verseWasSpoken
        )
        
        // Calculate multi-factor confidence using DetectionConfidence model
        // 
        // Factors:
        // 1. Reference Clarity - How clear and unambiguous was the reference pattern?
        // 2. Speech Confidence - Pattern-based estimation (true speech confidence comes from Whisper)
        // 3. Context Match - How well does the match fit expected patterns?
        // 4. Verse Existence - held at 1.0 here, deliberately. See the note below.
        //
        // On `verseExistence`: `referenceValidator` is available by this point, and it is
        // tempting to score the factor from it. It is wrong to do so. An unresolvable
        // chapter is very often a concatenated chapter+verse that
        // `DetectionPipeline.reinterpretConcatenatedRef` repairs — "James 123" → James 1:23.
        // Downgrading the factor would take `chapterOnly` from 0.780 to 0.730, below the
        // 0.75 gate, so the detection would be refused here and the repair would never run.
        // The validator is therefore applied where invalidity actually matters and costs
        // nothing: `cacheContext(for:)` refuses to remember an impossible reference, and the
        // pipeline refuses to display one. The factor stays structural, describing the
        // pattern rather than the database.
        
        let referenceClarity: Double
        let speechConfidence: Double
        let contextMatch: Double
        let verseExistence: Double
        let patternTypeName: String
        
        switch type {
        case .standard:
            // "John 3:16" - clearest format with explicit colon delimiter
            referenceClarity = 0.98
            speechConfidence = 0.95
            contextMatch = 0.95
            verseExistence = 1.0  // Structural, not a database check — see the note above.
            patternTypeName = "standard"
            
        case .spoken:
            // "John 316" - concatenated digits, more ambiguous
            referenceClarity = 0.80
            speechConfidence = 0.85
            contextMatch = 0.80
            verseExistence = 1.0
            patternTypeName = "spoken"
            
        case .spokenRange:
            // "John 316 to 18" - spoken format with range
            referenceClarity = 0.82
            speechConfidence = 0.86
            contextMatch = 0.82
            verseExistence = 1.0
            patternTypeName = "spokenRange"
            
        case .verbal:
            // "John chapter 3 verse 16" - explicit keywords, high clarity
            referenceClarity = 0.95
            speechConfidence = 0.92
            contextMatch = 0.90
            verseExistence = 1.0
            patternTypeName = "verbal"
            
        case .verbalShort:
            // "Genesis 1 verse 1" - partial verbal format
            referenceClarity = 0.88
            speechConfidence = 0.88
            contextMatch = 0.85
            verseExistence = 1.0
            patternTypeName = "verbalShort"
            
        case .spokenWords:
            // "John three sixteen" - word numbers, requires interpretation
            referenceClarity = 0.78
            speechConfidence = 0.85
            contextMatch = 0.80
            verseExistence = 1.0
            patternTypeName = "spokenWords"
            
        case .chapterOnly:
            // "Romans 8" - no verse, lowest specificity
            referenceClarity = 0.75
            speechConfidence = 0.80
            contextMatch = 0.70
            verseExistence = 1.0
            patternTypeName = "chapterOnly"
            
        case .invertedVerbal:
            // "verse 31 of Romans 8" - inverted order, good specificity
            // Note: This case should not normally be reached as invertedVerbal
            // is handled separately in parseInvertedVerbalMatch
            referenceClarity = 0.85
            speechConfidence = 0.80
            contextMatch = 1.0
            verseExistence = 1.0
            patternTypeName = "invertedVerbal"

        case .bookVerseChapter:
            // "John verse 16 chapter 5" - inverted verse/chapter, explicit keywords.
            // Note: normally handled separately in parseBookVerseChapterMatch; this
            // case exists for switch exhaustiveness and mirrors invertedVerbal.
            referenceClarity = 0.85
            speechConfidence = 0.80
            contextMatch = 1.0
            verseExistence = 1.0
            patternTypeName = "bookVerseChapter"

        case .partialVerse:
            // "verse 18" - requires context buffer, lower confidence
            // Note: This case should not normally be reached as partialVerse
            // is handled separately in parsePartialVerseMatch
            referenceClarity = 0.70
            speechConfidence = 0.75
            contextMatch = 0.65
            verseExistence = 1.0
            patternTypeName = "partialVerse"
        }
        
        // Adjust confidence based on book name recognition quality.
        // A book we had to guess at is far less trustworthy than one heard verbatim.
        // `bookGuessPenaltyPerEdit` is COUPLED TO `minimumConfidence` below — see the
        // arithmetic at its declaration before changing either.
        var adjustedReferenceClarity = referenceClarity
        if !matchQuality.isExact {
            // The distance resolved during normalisation. A book settled by its chapter
            // number is still a guess, so it is scored by its spelling distance too.
            let distance = matchQuality.editDistance
            adjustedReferenceClarity = max(0.4, referenceClarity - Double(distance) * Self.bookGuessPenaltyPerEdit)
        }
        
        // Adjust context match based on raw match quality
        var adjustedContextMatch = contextMatch
        
        // Penalise if there were stripped leading words (indicates noise in speech)
        let bookNameLower = rawBook.lowercased()
        if rawMatch.lowercased().hasPrefix(bookNameLower) == false {
            adjustedContextMatch = max(0.5, contextMatch - 0.1)
        }
        
        // Create the confidence object
        let detectionConfidence = DetectionConfidence(
            referenceClarity: adjustedReferenceClarity,
            speechConfidence: speechConfidence,
            contextMatch: adjustedContextMatch,
            verseExistence: verseExistence
        )
        
        // CRITICAL: Apply minimum confidence threshold to prevent false detections.
        // Coupled to `bookGuessPenaltyPerEdit` — see the note at its declaration.
        if detectionConfidence.overall < Self.minimumConfidence {
            Logger.detection.warning("Rejected detection below minimum confidence: \(detectionConfidence.percentage, privacy: .public)% < \(Int(Self.minimumConfidence * 100), privacy: .public)% for \(reference.formatted, privacy: .public)")
            publishRejection(
                DetectionRejection(
                    heard: rawMatch,
                    reason: "confidence \(detectionConfidence.percentage)% is below the \(Int(Self.minimumConfidence * 100))% threshold"
                )
            )
            return nil
        }
        
        Logger.detection.info("Detection: \(reference.formatted, privacy: .public) [\(patternTypeName, privacy: .public)] — confidence \(detectionConfidence.percentage, privacy: .public)% (\(detectionConfidence.level.rawValue, privacy: .public))")
        
        // Update reference buffer context for future partial reference resolution
        // This enables "verse 18" to resolve to "John 3:18" after detecting "John 3:16"
        // Also enables "next verse" to resolve correctly
        cacheContext(for: reference)
        
        return DetectionResult(
            reference: reference,
            rawMatch: rawMatch,
            detectionConfidence: detectionConfidence,
            timestamp: Date(),
            patternType: patternTypeName
        )
    }
    
    // MARK: - Inverted Verbal Parsing
    
    /// Parse an inverted verbal reference: "verse X of Book Y"
    /// Pattern captures: (verseStart) (verseEnd optional) (book) (chapter)
    private func parseInvertedVerbalMatch(_ match: NSTextCheckingResult, in text: String) -> DetectionResult? {
        // Pattern: verse (\d+) (to \d+)? of (Book) (Chapter)
        // Groups: 1=verseStart, 2=verseEnd (optional), 3=book, 4=chapter
        guard match.numberOfRanges >= 5 else {
            print("⚠️ [invertedVerbal] Not enough capture groups: \(match.numberOfRanges)")
            return nil
        }
        
        // Extract the full matched text
        guard let fullRange = Range(match.range, in: text) else {
            return nil
        }
        let rawMatch = String(text[fullRange]).trimmingCharacters(in: .whitespaces)
        
        // Extract verse start (group 1)
        guard let verseStartRange = Range(match.range(at: 1), in: text) else {
            print("⚠️ [invertedVerbal] Could not extract verse start")
            return nil
        }
        let verseStartRaw = String(text[verseStartRange])
        
        // Parse verse start (could be number or word)
        guard let verseStart = parseNumber(verseStartRaw) else {
            print("⚠️ [invertedVerbal] Could not parse verse start: \(verseStartRaw)")
            return nil
        }
        
        // Extract verse end (group 2) - optional
        var verseEnd: Int? = nil
        if match.range(at: 2).location != NSNotFound,
           let verseEndRange = Range(match.range(at: 2), in: text) {
            let verseEndRaw = String(text[verseEndRange])
            verseEnd = parseNumber(verseEndRaw)
        }
        
        // Extract book name (group 3)
        guard let bookRange = Range(match.range(at: 3), in: text) else {
            print("⚠️ [invertedVerbal] Could not extract book name")
            return nil
        }
        let rawBook = String(text[bookRange]).trimmingCharacters(in: .whitespaces)
        
        // Extract chapter (group 4)
        guard let chapterRange = Range(match.range(at: 4), in: text) else {
            print("⚠️ [invertedVerbal] Could not extract chapter")
            return nil
        }
        let chapterRaw = String(text[chapterRange])
        
        // Parse chapter (could be number or word)
        guard let chapter = parseNumber(chapterRaw) else {
            print("⚠️ [invertedVerbal] Could not parse chapter: \(chapterRaw)")
            return nil
        }
        
        // Normalize the book name using the book normaliser
        guard let canonicalBook = bookNormaliser.normalise(rawBook, chapterHint: chapter) else {
            Logger.detection.warning("[invertedVerbal] Could not normalise book: \(rawBook, privacy: .public)")
            return nil
        }
        
        // Validate chapter is reasonable (max 150 like Psalms)
        if chapter > 150 {
            Logger.detection.warning("[invertedVerbal] Rejected invalid chapter: \(chapter, privacy: .public)")
            return nil
        }
        
        // Validate verse is reasonable (max 176 like Psalm 119)
        if verseStart > 176 {
            Logger.detection.warning("[invertedVerbal] Rejected invalid verse: \(verseStart, privacy: .public)")
            return nil
        }
        
        // Create the scripture reference
        let reference = ScriptureReference(
            book: canonicalBook,
            chapter: chapter,
            verseStart: verseStart,
            verseEnd: verseEnd,
            verseWasSpoken: true  // "verse 31 of Romans 8" states the verse outright.
        )
        
        // Calculate confidence
        let confidence = DetectionConfidence(
            referenceClarity: 0.85,
            speechConfidence: 0.80,
            contextMatch: 1.0,
            verseExistence: 1.0
        )
        
        // Update reference buffer context
        cacheContext(for: reference)
        
        print("✅ Detection: \(reference.formatted) [invertedVerbal] - Confidence: \(confidence.percentage)%")
        print("   Raw: '\(rawMatch)' → Book: \(canonicalBook), Chapter: \(chapter), Verse: \(verseStart)\(verseEnd.map { "-\($0)" } ?? "")")
        
        return DetectionResult(
            reference: reference,
            rawMatch: rawMatch,
            detectionConfidence: confidence,
            timestamp: Date(),
            patternType: "invertedVerbal"
        )
    }
    
    // MARK: - Book-Verse-Chapter Parsing

    /// Parse a "book verse X chapter Y" reference (verse spoken before the chapter) → book Y:X.
    /// Groups: 1=book, 2=verse_start, 3=verse_end (optional), 4=chapter
    private func parseBookVerseChapterMatch(_ match: NSTextCheckingResult, in text: String) -> DetectionResult? {
        guard match.numberOfRanges >= 5 else {
            print("⚠️ [bookVerseChapter] Not enough capture groups: \(match.numberOfRanges)")
            return nil
        }

        guard let fullRange = Range(match.range, in: text) else { return nil }
        let rawMatch = String(text[fullRange]).trimmingCharacters(in: .whitespaces)

        // Book (group 1)
        guard let bookRange = Range(match.range(at: 1), in: text) else { return nil }
        let rawBook = String(text[bookRange]).trimmingCharacters(in: .whitespaces)

        // Reject obvious non-book filler words captured as the "book"
        let commonWordsToReject: Set<String> = [
            "for", "of", "on", "and", "or", "but", "the", "a", "an", "in", "at", "to",
            "with", "from", "by", "is", "are", "was", "were", "you", "we", "our"
        ]
        if commonWordsToReject.contains(rawBook.lowercased()) {
            print("⚠️ [bookVerseChapter] Rejected common word as book: '\(rawBook)'")
            return nil
        }

        // Verse start (group 2 — number or word)
        guard let verseStartRange = Range(match.range(at: 2), in: text),
              let verseStart = parseNumber(String(text[verseStartRange])) else {
            print("⚠️ [bookVerseChapter] Could not parse verse start")
            return nil
        }

        // Verse end (group 3 — optional)
        var verseEnd: Int? = nil
        if match.range(at: 3).location != NSNotFound,
           let verseEndRange = Range(match.range(at: 3), in: text) {
            verseEnd = parseNumber(String(text[verseEndRange]))
        }

        // Chapter (group 4 — number or word)
        guard let chapterRange = Range(match.range(at: 4), in: text),
              let chapter = parseNumber(String(text[chapterRange])) else {
            print("⚠️ [bookVerseChapter] Could not parse chapter")
            return nil
        }

        // Normalise the book name
        guard let canonicalBook = bookNormaliser.normalise(rawBook, chapterHint: chapter) else {
            Logger.detection.warning("[bookVerseChapter] Could not normalise book: '\(rawBook, privacy: .public)'")
            return nil
        }

        // Validate ranges (Psalms has 150 chapters; Psalm 119 has 176 verses)
        if chapter > 150 {
            Logger.detection.warning("[bookVerseChapter] Rejected invalid chapter: \(chapter, privacy: .public)")
            return nil
        }
        if verseStart > 176 {
            Logger.detection.warning("[bookVerseChapter] Rejected invalid verse: \(verseStart, privacy: .public)")
            return nil
        }

        let reference = ScriptureReference(
            book: canonicalBook,
            chapter: chapter,
            verseStart: verseStart,
            verseEnd: verseEnd,
            verseWasSpoken: true  // "John verse 16 chapter 5" states the verse outright.
        )

        let confidence = DetectionConfidence(
            referenceClarity: 0.85,
            speechConfidence: 0.80,
            contextMatch: 1.0,
            verseExistence: 1.0
        )

        cacheContext(for: reference)

        print("✅ Detection: \(reference.formatted) [bookVerseChapter] - Confidence: \(confidence.percentage)%")
        print("   Raw: '\(rawMatch)' → Book: \(canonicalBook), Chapter: \(chapter), Verse: \(verseStart)\(verseEnd.map { "-\($0)" } ?? "")")

        return DetectionResult(
            reference: reference,
            rawMatch: rawMatch,
            detectionConfidence: confidence,
            timestamp: Date(),
            patternType: "bookVerseChapter"
        )
    }

    // MARK: - Partial Verse Parsing

    /// Parse a partial verse reference using context buffer
    private func parsePartialVerseMatch(_ match: NSTextCheckingResult, in text: String) -> DetectionResult? {
        guard referenceBuffer.isEnabled else {
            print("📚 [partialVerse] Reference buffer disabled, skipping partial reference")
            return nil
        }
        
        guard let context = referenceBuffer.getValidContext() else {
            print("📚 [partialVerse] No valid context available for partial reference")
            return nil
        }
        
        // Extract the raw matched text
        guard let fullRange = Range(match.range, in: text) else {
            return nil
        }
        let rawMatch = String(text[fullRange]).trimmingCharacters(in: .whitespaces)
        
        // Check for "next verse", "following verse", or "previous verse" pattern
        let lowercasedMatch = rawMatch.lowercased()
        
        if lowercasedMatch.contains("next") || lowercasedMatch.contains("following") {
            // Resolve using the next verse from context
            guard let reference = referenceBuffer.resolveNextVerseReference() else {
                print("📚 [partialVerse] 'Next/following verse' detected but no verse context available")
                return nil
            }
            
            // Also update the context to the new verse for potential chained references
            cacheContext(for: reference)
            
            // Return the detection result
            let confidence = DetectionConfidence(
                referenceClarity: 0.70,
                speechConfidence: 0.75,
                contextMatch: 0.85, // Higher context match since we're using buffer
                verseExistence: 1.0
            )
            
            print("✅ Detection: \(reference.formatted) [partialVerse-next] - Confidence: \(confidence.percentage)%")
            
            return DetectionResult(
                reference: reference,
                rawMatch: rawMatch,
                detectionConfidence: confidence,
                timestamp: Date(),
                patternType: "partialVerse-next"
            )
        }
        
        if lowercasedMatch.contains("previous") {
            // Resolve using the previous verse from context
            guard let reference = referenceBuffer.resolvePreviousVerseReference() else {
                print("📚 [partialVerse] 'Previous verse' detected but no verse context available or at verse 1")
                return nil
            }
            
            // Also update the context to the new verse for potential chained references
            cacheContext(for: reference)
            
            // Return the detection result
            let confidence = DetectionConfidence(
                referenceClarity: 0.70,
                speechConfidence: 0.75,
                contextMatch: 0.85, // Higher context match since we're using buffer
                verseExistence: 1.0
            )
            
            print("✅ Detection: \(reference.formatted) [partialVerse-previous] - Confidence: \(confidence.percentage)%")
            
            return DetectionResult(
                reference: reference,
                rawMatch: rawMatch,
                detectionConfidence: confidence,
                timestamp: Date(),
                patternType: "partialVerse-previous"
            )
        }
        
        // Extract verse numbers from the match
        // Pattern: "verse(s) X (to Y)"
        var verseStart: Int?
        var verseEnd: Int?
        
        // Group 1 is the start verse
        if match.numberOfRanges >= 2,
           let verseRange = Range(match.range(at: 1), in: text) {
            let verseStr = String(text[verseRange]).trimmingCharacters(in: .whitespaces).lowercased()
            verseStart = parseNumber(verseStr)
        }
        
        // Group 2 is the end verse (optional)
        if match.numberOfRanges >= 3,
           match.range(at: 2).location != NSNotFound,
           let endRange = Range(match.range(at: 2), in: text) {
            let endStr = String(text[endRange]).trimmingCharacters(in: .whitespaces).lowercased()
            verseEnd = parseNumber(endStr)
        }
        
        guard let startVerse = verseStart else {
            print("📚 [partialVerse] Could not extract verse number from: '\(rawMatch)'")
            return nil
        }
        
        // Validate verse numbers
        if startVerse > 176 {
            print("⚠️ Rejected invalid partial verse: \(startVerse) (max: 176)")
            return nil
        }
        
        if let end = verseEnd, end > 176 {
            print("⚠️ Rejected invalid partial end verse: \(end) (max: 176)")
            return nil
        }
        
        if let end = verseEnd, startVerse > end {
            print("⚠️ Rejected invalid partial verse range: \(startVerse)-\(end)")
            return nil
        }
        
        // Create the resolved reference using context
        let reference = ScriptureReference(
            book: context.book,
            chapter: context.chapter,
            verseStart: startVerse,
            verseEnd: verseEnd,
            verseWasSpoken: true  // A partial reference is nothing but a spoken verse.
        )
        
        // Calculate confidence - lower because we're relying on context
        let detectionConfidence = DetectionConfidence(
            referenceClarity: 0.70,     // Partial reference is less clear
            speechConfidence: 0.85,
            contextMatch: 0.95,          // High because we're using valid context
            verseExistence: 1.0
        )
        
        // Apply minimum confidence threshold
        if detectionConfidence.overall < Self.minimumConfidence {
            Logger.detection.warning("Rejected partial verse below minimum confidence: \(detectionConfidence.percentage, privacy: .public)%")
            publishRejection(
                DetectionRejection(
                    heard: rawMatch,
                    reason: "confidence \(detectionConfidence.percentage)% is below the \(Int(Self.minimumConfidence * 100))% threshold"
                )
            )
            return nil
        }
        
        Logger.detection.info("Partial verse resolved: '\(rawMatch, privacy: .public)' → \(reference.formatted, privacy: .public) using context [\(context.book, privacy: .public) \(context.chapter, privacy: .public)]")
        
        return DetectionResult(
            reference: reference,
            rawMatch: rawMatch,
            detectionConfidence: detectionConfidence,
            timestamp: Date(),
            patternType: "partialVerse"
        )
    }
    
    // MARK: - Number Parsing
    
    /// Parse a number from either digits or word form
    private func parseNumber(_ input: String) -> Int? {
        // Try parsing as integer first
        if let number = Int(input) {
            return number
        }
        
        // Try word lookup
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespaces)
        if let number = numberWords[lowercased] {
            return number
        }
        
        // Handle compound numbers with space: "twenty one" -> "twenty-one"
        let hyphenated = lowercased.replacingOccurrences(of: " ", with: "-")
        if let number = numberWords[hyphenated] {
            return number
        }
        
        return nil
    }
    
    // MARK: - Debouncing
    
    private func isDuplicate(_ key: String) -> Bool {
        guard let lastDetection = recentDetections[key] else {
            return false
        }
        return Date().timeIntervalSince(lastDetection) < debounceInterval
    }
    
    /// Clear the recent detections cache
    func clearCache() {
        recentDetections.removeAll()
    }
    
    // MARK: - Reference Context
    
    /// Commit a reference to the context buffer, but only when it actually exists.
    /// A detection such as "Amos 91" (Amos has nine chapters) must never become the
    /// context that later partial references like "verse 8 to 12" resolve against,
    /// or one misheard book name poisons every reference for the next five minutes.
    ///
    /// Internal rather than private so `DetectionPipeline` can cache the *corrected*
    /// reference after the concatenation-repair path has run. Caching here alone left the
    /// buffer empty after a successful split, because the pre-split reference was
    /// (correctly) refused and the post-split one never reached the detector again.
    func cacheContext(for reference: ScriptureReference) {
        if let validate = referenceValidator, !validate(reference) {
            Logger.detection.warning("Not caching implausible reference: \(reference.formatted, privacy: .public)")
            publishRejection(
                DetectionRejection(
                    heard: reference.formatted,
                    reason: "no such chapter in \(reference.book), so it was not kept as context"
                )
            )
            return
        }
        
        referenceBuffer.updateContext(
            book: reference.book,
            chapter: reference.chapter,
            verseStart: reference.verseStart,
            verseEnd: reference.verseEnd
        )
    }
    
    // MARK: - Rejection Reporting
    
    /// Surface a refusal to the operator, then clear it so the console does not
    /// accumulate stale rows. Purely informational — nothing here reaches the projector.
    private func publishRejection(_ rejection: DetectionRejection) {
        lastRejection = rejection
        rejectionPublisher.send(rejection)
        
        rejectionClearTask?.cancel()
        let duration = rejectionDisplayDuration
        rejectionClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.lastRejection = nil
        }
    }
}

// MARK: - Book Name Normaliser

/// Normalises various book name formats to canonical names
class BookNameNormaliser {
    
    // Common words that should NEVER be matched as book names
    // These get incorrectly fuzzy-matched to short book abbreviations
    private let excludedWords: Set<String> = [
        // Prepositions and articles
        "to", "the", "a", "an", "in", "on", "at", "by", "of", "for", "from",
        "into", "unto", "upon", "with", "about", "through", "between", "among",
        // Common verbs
        "go", "be", "do", "is", "am", "are", "was", "were", "has", "have", "had",
        "can", "may", "will", "would", "could", "should", "let", "lets", "let's",
        // Pronouns
        "i", "me", "my", "we", "us", "our", "you", "your", "he", "him", "his",
        "she", "her", "it", "its", "they", "them", "their", "this", "that",
        // Common words in church context
        "open", "turn", "read", "chapter", "verse", "verses", "and", "or", "but",
        "bible", "scripture", "word", "passage", "text", "book", "books",
        "today", "now", "here", "there", "where", "when", "what", "which", "who",
        // Numbers as words that might be mistaken
        "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
        // Other common short words
        "bar", "so", "if", "as", "up", "no", "yes", "ok", "oh", "ah", "um", "uh",
        // Additional words found in logs causing false detections
        "drop", "instead", "instead of", "insteadof",
        // Ordinary English words that sit close enough to a Psalms mishearing to be
        // reached by the fuzzy path. "size" was briefly a direct alias for Psalms,
        // which turned "…a size 10." into Psalms 10 with no warning at all.
        "size", "sizes",
    ]
    
    // Canonical book names mapped from various inputs (mutable for learned corrections)
    private var bookMappings: [String: String] = [
        // Old Testament
        "genesis": "Genesis", "gen": "Genesis", "ge": "Genesis", "genisis": "Genesis", "jenesis": "Genesis",
        "exodus": "Exodus", "exod": "Exodus", "ex": "Exodus",
        "leviticus": "Leviticus", "lev": "Leviticus", "le": "Leviticus",
        "numbers": "Numbers", "num": "Numbers", "nu": "Numbers",
        "deuteronomy": "Deuteronomy", "deut": "Deuteronomy", "de": "Deuteronomy",
        "joshua": "Joshua", "josh": "Joshua", "jos": "Joshua",
        "judges": "Judges", "judg": "Judges", "jdg": "Judges",
        "ruth": "Ruth", "ru": "Ruth", "roof": "Ruth", "rooth": "Ruth", "route": "Ruth",  // Common STT misheard
        // The short "sam" forms carry the ordinal in words as well as in digits. Bare
        // "sam" maps to Psalms below, so without "first sam" and "second sam" a speaker
        // saying the ordinal aloud would have their numbered Samuel silently rejected.
        // Deliberately no "i sam" or "ii sam": "i am" sits one edit from "i sam", so those
        // two aliases turned "I am 40." into 1 Samuel 40. The long roman forms are safe.
        "1 samuel": "1 Samuel", "1samuel": "1 Samuel", "first samuel": "1 Samuel", "i samuel": "1 Samuel", "1 sam": "1 Samuel", "1sam": "1 Samuel", "first sam": "1 Samuel",
        "2 samuel": "2 Samuel", "2samuel": "2 Samuel", "second samuel": "2 Samuel", "ii samuel": "2 Samuel", "2 sam": "2 Samuel", "2sam": "2 Samuel", "second sam": "2 Samuel",
        "1 kings": "1 Kings", "1kings": "1 Kings", "first kings": "1 Kings", "i kings": "1 Kings", "1 kgs": "1 Kings",
        "2 kings": "2 Kings", "2kings": "2 Kings", "second kings": "2 Kings", "ii kings": "2 Kings", "2 kgs": "2 Kings",
        "1 chronicles": "1 Chronicles", "1chronicles": "1 Chronicles", "first chronicles": "1 Chronicles", "i chronicles": "1 Chronicles", "1 chr": "1 Chronicles",
        "2 chronicles": "2 Chronicles", "2chronicles": "2 Chronicles", "second chronicles": "2 Chronicles", "ii chronicles": "2 Chronicles", "2 chr": "2 Chronicles",
        "ezra": "Ezra", "ezr": "Ezra",
        "nehemiah": "Nehemiah", "neh": "Nehemiah", "ne": "Nehemiah",
        "esther": "Esther", "est": "Esther", "es": "Esther",
        "job": "Job", "jb": "Job", "jobe": "Job",
        "psalms": "Psalms", "psalm": "Psalms", "ps": "Psalms", "psa": "Psalms",
        "some": "Psalms", "sum": "Psalms", "salm": "Psalms", "sums": "Psalms", "palms": "Psalms",  // Common speech-to-text misheard
        // Apple's recogniser routinely collapses "Psalms" to a single syllable. These are
        // mappings for what it actually produced in the field, not guesses: bare "sam"
        // cannot be Samuel because Samuel is always spoken with its number ("1 Sam"),
        // and those numbered forms are matched exactly above.
        //
        // Deliberately absent: "size", an ordinary English word that made "…a size 10."
        // resolve to Psalms 10, and is now an excluded word; and "sames", which sits one
        // edit from "james" and so turned a misheard James into Psalms by exact match,
        // bypassing the tie logic that exists precisely to catch that. "sames" is left to
        // the fuzzy path, where it ties Psalms against James and is rejected — or settled
        // honestly by the chapter number when one was spoken.
        "sam": "Psalms", "sams": "Psalms", "salms": "Psalms", "psams": "Psalms",
        "sarms": "Psalms", "psalmes": "Psalms",
        "proverbs": "Proverbs", "prov": "Proverbs", "pr": "Proverbs", "pro": "Proverbs",
        "ecclesiastes": "Ecclesiastes", "eccles": "Ecclesiastes", "eccl": "Ecclesiastes", "ec": "Ecclesiastes",
        "song of solomon": "Song of Solomon", "song of songs": "Song of Solomon", "songs of solomon": "Song of Solomon", "songs": "Song of Solomon", "sos": "Song of Solomon", "ss": "Song of Solomon", "canticles": "Song of Solomon", "song": "Song of Solomon",
        "isaiah": "Isaiah", "isa": "Isaiah", "is": "Isaiah",
        "jeremiah": "Jeremiah", "jer": "Jeremiah", "je": "Jeremiah",
        "lamentations": "Lamentations", "lam": "Lamentations", "la": "Lamentations",
        "ezekiel": "Ezekiel", "ezek": "Ezekiel", "eze": "Ezekiel",
        "daniel": "Daniel", "dan": "Daniel", "da": "Daniel",
        "hosea": "Hosea", "hos": "Hosea", "ho": "Hosea",
        "joel": "Joel", "joe": "Joel", "jl": "Joel",
        "amos": "Amos", "am": "Amos",
        "obadiah": "Obadiah", "obad": "Obadiah", "ob": "Obadiah",
        "jonah": "Jonah", "jon": "Jonah", "jnh": "Jonah",
        "micah": "Micah", "mic": "Micah", "mi": "Micah",
        "nahum": "Nahum", "nah": "Nahum", "na": "Nahum",
        "habakkuk": "Habakkuk", "hab": "Habakkuk",
        "zephaniah": "Zephaniah", "zeph": "Zephaniah", "zep": "Zephaniah",
        "haggai": "Haggai", "hag": "Haggai", "hg": "Haggai",
        "zechariah": "Zechariah", "zech": "Zechariah", "zec": "Zechariah",
        "malachi": "Malachi", "mal": "Malachi",
        
        // New Testament
        "matthew": "Matthew", "matt": "Matthew", "mat": "Matthew", "mt": "Matthew",
        "mark": "Mark", "mk": "Mark", "mr": "Mark",
        "luke": "Luke", "luk": "Luke", "lk": "Luke",
        "john": "John", "jn": "John", "joh": "John",
        "acts": "Acts", "act": "Acts", "ac": "Acts",
        "romans": "Romans", "rom": "Romans", "ro": "Romans",
        "romance": "Romans", "roman": "Romans",  // Common speech-to-text misheard
        "1 corinthians": "1 Corinthians", "1corinthians": "1 Corinthians", "first corinthians": "1 Corinthians", "i corinthians": "1 Corinthians", "1 cor": "1 Corinthians", "1cor": "1 Corinthians",
        "2 corinthians": "2 Corinthians", "2corinthians": "2 Corinthians", "second corinthians": "2 Corinthians", "ii corinthians": "2 Corinthians", "2 cor": "2 Corinthians", "2cor": "2 Corinthians",
        "galatians": "Galatians", "gal": "Galatians", "ga": "Galatians", "glacians": "Galatians", "galatia": "Galatians",
        "ephesians": "Ephesians", "eph": "Ephesians", "ep": "Ephesians", "ephesian": "Ephesians", "fusions": "Ephesians", "a fusions": "Ephesians",
        "philippians": "Philippians", "phil": "Philippians", "php": "Philippians",
        "filipinos": "Philippians", "filipino": "Philippians", "philipians": "Philippians", "phillipians": "Philippians",
        "philippines": "Philippians", "philippine": "Philippians",  // Country name confusion
        "colossians": "Colossians", "col": "Colossians", "cautions": "Colossians", "closions": "Colossians", "collision": "Colossians",
        "1 thessalonians": "1 Thessalonians", "1thessalonians": "1 Thessalonians", "first thessalonians": "1 Thessalonians", "i thessalonians": "1 Thessalonians", "1 thess": "1 Thessalonians", "1thess": "1 Thessalonians",
        "thessalonians": "1 Thessalonians", "thessalonian": "1 Thessalonians", "the saloni": "1 Thessalonians", "the salonika": "1 Thessalonians",
        "2 thessalonians": "2 Thessalonians", "2thessalonians": "2 Thessalonians", "second thessalonians": "2 Thessalonians", "ii thessalonians": "2 Thessalonians", "2 thess": "2 Thessalonians", "2thess": "2 Thessalonians",
        "1 timothy": "1 Timothy", "1timothy": "1 Timothy", "first timothy": "1 Timothy", "i timothy": "1 Timothy", "1 tim": "1 Timothy", "1tim": "1 Timothy",
        "2 timothy": "2 Timothy", "2timothy": "2 Timothy", "second timothy": "2 Timothy", "ii timothy": "2 Timothy", "2 tim": "2 Timothy", "2tim": "2 Timothy",
        "titus": "Titus", "tit": "Titus",
        "philemon": "Philemon", "phlm": "Philemon", "phm": "Philemon",
        "hebrews": "Hebrews", "heb": "Hebrews",
        "james": "James", "jas": "James", "jam": "James",
        "1 peter": "1 Peter", "1peter": "1 Peter", "first peter": "1 Peter", "i peter": "1 Peter", "1 pet": "1 Peter", "1pet": "1 Peter",
        "2 peter": "2 Peter", "2peter": "2 Peter", "second peter": "2 Peter", "ii peter": "2 Peter", "2 pet": "2 Peter", "2pet": "2 Peter",
        "1 john": "1 John", "1john": "1 John", "first john": "1 John", "i john": "1 John", "1 jn": "1 John", "1jn": "1 John",
        "2 john": "2 John", "2john": "2 John", "second john": "2 John", "ii john": "2 John", "2 jn": "2 John", "2jn": "2 John",
        "3 john": "3 John", "3john": "3 John", "third john": "3 John", "iii john": "3 John", "3 jn": "3 John", "3jn": "3 John",
        "jude": "Jude", "jud": "Jude",
        "revelation": "Revelation", "revelations": "Revelation", "rev": "Revelation", "re": "Revelation", "the revelation": "Revelation",
        "revelations of john": "Revelation", "the revelations": "Revelation", "book of revelation": "Revelation",
    ]
    
    /// Supplies the highest chapter number a book actually has, used to settle
    /// ambiguous mishearings. Injected by `DetectionPipeline` from `BibleService`.
    var chapterCountProvider: ((String) -> Int?)?
    
    // MARK: - Match Outcome
    
    /// How a book name was arrived at. The caller needs this to score the detection:
    /// a book heard verbatim is a certainty, a book reached by two edits is a guess,
    /// and a book settled by its chapter number is a guess that happened to be checkable.
    enum MatchQuality: Equatable {
        case exact
        case fuzzy(distance: Int)
        case chapterDisambiguated(distance: Int)
        
        /// Edit distance from the nearest alias. Zero for a verbatim match.
        var editDistance: Int {
            switch self {
            case .exact: return 0
            case .fuzzy(let distance), .chapterDisambiguated(let distance): return distance
            }
        }
        
        var isExact: Bool { self == .exact }
    }
    
    /// Why a book name could not be resolved. Carried to the operator console so a
    /// rejection is visible rather than merely silent.
    enum MatchFailure: Equatable {
        case excludedWord
        case tooShort
        case ambiguous(books: [String])
        case unrecognised
        
        /// Operator-facing explanation, in British English.
        ///
        /// `.ambiguous` names the failure but not the books. The books are carried
        /// structurally in `candidateBooks` and rendered from there, so this string can
        /// be reworded without the operator silently losing sight of what was in
        /// contention — which is exactly what the previous interpolation risked.
        var reason: String {
            switch self {
            case .excludedWord: return "ordinary word, not a book name"
            case .tooShort: return "too short to identify a book"
            case .ambiguous: return "the book name was ambiguous"
            case .unrecognised: return "book not recognised"
            }
        }
        
        /// Books that were in contention. Empty unless this is an ambiguity.
        var candidateBooks: [String] {
            if case .ambiguous(let books) = self { return books }
            return []
        }
    }
    
    /// Result of resolving a raw book name.
    enum MatchOutcome {
        case matched(canonical: String, quality: MatchQuality)
        case rejected(MatchFailure)
    }
    
    /// Normalise a book name to its canonical form.
    /// - Parameters:
    ///   - input: The raw book name as heard.
    ///   - chapterHint: The chapter number spoken alongside it, if known. Used only
    ///     to break ties between equally-close mishearings.
    func normalise(_ input: String, chapterHint: Int? = nil) -> String? {
        guard case .matched(let canonical, _) = match(input, chapterHint: chapterHint) else {
            return nil
        }
        return canonical
    }
    
    /// Resolve a book name and report how it was resolved, or why it was not.
    ///
    /// Prefer this over `normalise(_:chapterHint:)` when the caller needs the edit
    /// distance: it is computed here already, so asking for it again means running the
    /// whole alias sweep twice for the same input.
    /// - Parameters:
    ///   - input: The raw book name as heard.
    ///   - chapterHint: The chapter number spoken alongside it, if known. Used only
    ///     to break ties between equally-close mishearings.
    func match(_ input: String, chapterHint: Int? = nil) -> MatchOutcome {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespaces)
        
        // FIRST: Check if this is a common word that should NEVER be a book name
        // This prevents "to" from being fuzzy-matched to "ho" → Hosea
        if excludedWords.contains(lowercased) {
            return .rejected(.excludedWord)
        }
        
        // Check for numbered prefixes with excluded words: "1 to" → check if "to" is excluded
        // This prevents "1 to" from fuzzy-matching to "1 Timothy"
        if let match = lowercased.firstMatch(of: /^(\d+)\s+(.+)$/) {
            let baseWord = String(match.output.2)
            if excludedWords.contains(baseWord) {
                Logger.detection.warning("Rejecting '\(lowercased, privacy: .public)' — base word '\(baseWord, privacy: .public)' is excluded")
                return .rejected(.excludedWord)
            }
        }
        
        // Also exclude very short words (1-2 chars) unless they're exact matches
        // This prevents random short words from fuzzy-matching
        if lowercased.count <= 2 && bookMappings[lowercased] == nil {
            return .rejected(.tooShort)
        }
        
        // Direct lookup in primary mappings
        if let canonical = bookMappings[lowercased] {
            return .matched(canonical: canonical, quality: .exact)
        }
        
        // Try BibleVocabularyData STT mishearings
        if let canonical = BibleVocabularyData.sttMishearings[lowercased] {
            return .matched(canonical: canonical, quality: .exact)
        }
        
        // Try abbreviations
        if let canonical = BibleVocabularyData.abbreviations[lowercased] {
            return .matched(canonical: canonical, quality: .exact)
        }
        
        // Try without spaces for numbered books
        let noSpaces = lowercased.replacingOccurrences(of: " ", with: "")
        if let canonical = bookMappings[noSpaces] {
            return .matched(canonical: canonical, quality: .exact)
        }
        
        // Try fuzzy match if no exact match (only for words 3+ chars to avoid false matches)
        guard lowercased.count >= 3 else { return .rejected(.tooShort) }
        
        let candidates = fuzzyCandidates(lowercased, maxDistance: 2)
        let books = Set(candidates.map(\.canonical))
        
        if books.count == 1, let only = books.first, let distance = candidates.first?.distance {
            return .matched(canonical: only, quality: .fuzzy(distance: distance))
        }
        
        guard books.count > 1, let distance = candidates.first?.distance else {
            return .rejected(.unrecognised)
        }
        
        // Ambiguous. If we know which chapter was spoken, discard the books that
        // cannot possibly contain it — "sam 91" is impossible for Amos (9 chapters)
        // or either Samuel (31 and 24) but unremarkable for Psalms (150).
        if let chapterHint, let chapterCount = chapterCountProvider {
            let viable = books.filter { book in
                guard let maxChapter = chapterCount(book) else { return true }
                return chapterHint <= maxChapter
            }
            if viable.count == 1, let only = viable.first {
                Logger.detection.info("Ambiguous '\(lowercased, privacy: .public)' resolved to \(only, privacy: .public) — only book with a chapter \(chapterHint)")
                return .matched(canonical: only, quality: .chapterDisambiguated(distance: distance))
            }
        }
        
        let sortedBooks = books.sorted()
        Logger.detection.warning("Ambiguous book '\(lowercased, privacy: .public)': \(sortedBooks.joined(separator: ", "), privacy: .public) — rejecting rather than guessing")
        return .rejected(.ambiguous(books: sortedBooks))
    }
    
    /// Aliases shorter than this are exact-match only. A two-letter alias such as
    /// "am" (Amos) or "ho" (Hosea) sits one edit away from dozens of ordinary words,
    /// so allowing them as fuzzy targets turns almost any short mishearing into a
    /// confident but wrong book.
    private static let minimumFuzzyAliasLength = 3
    
    /// Aliases in sorted order, cached because this runs several times a second while
    /// listening and there are roughly five hundred of them. Invalidated by `addMapping`.
    ///
    /// `sorted()` on `[String]` uses Swift's locale-independent Unicode ordering — not
    /// `localizedStandardCompare` — so the order is byte-stable across machines and
    /// locales. That matters: the determinism guarantee would otherwise hold here and
    /// break on a differently-configured Mac.
    private var sortedAliasesCache: [String]?
    
    private var sortedAliases: [String] {
        if let cached = sortedAliasesCache { return cached }
        let sorted = bookMappings.keys.sorted()
        sortedAliasesCache = sorted
        return sorted
    }
    
    /// All aliases tied at the smallest edit distance within `maxDistance`.
    /// Iteration is over a sorted key list because Swift randomises `Dictionary`
    /// order per process launch — without this, the same misheard word resolves to
    /// a different book on every app start.
    func fuzzyCandidates(_ input: String, maxDistance: Int = 2) -> [(canonical: String, alias: String, distance: Int)] {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespaces)
        let inputLength = lowercased.count
        
        var bestDistance = Int.max
        var tied: [(canonical: String, alias: String, distance: Int)] = []
        
        for alias in sortedAliases {
            guard alias.count >= Self.minimumFuzzyAliasLength,
                  let canonical = bookMappings[alias] else { continue }
            
            // Cheap pre-filter: two strings differing in length by more than the budget
            // cannot be within it, since each insertion or deletion costs one edit.
            // Skipping these avoids allocating a Levenshtein matrix for most aliases.
            guard abs(alias.count - inputLength) <= min(maxDistance, bestDistance) else { continue }
            
            let distance = levenshteinDistance(lowercased, alias)
            guard distance <= maxDistance else { continue }
            
            if distance < bestDistance {
                bestDistance = distance
                tied = [(canonical, alias, distance)]
            } else if distance == bestDistance {
                tied.append((canonical, alias, distance))
            }
        }
        
        return tied
    }
    
    /// Fuzzy match a book name using Levenshtein distance.
    /// Returns nil when the closest aliases disagree on which book they mean —
    /// "sam" is one edit from Amos, James, Lamentations, Psalms and both Samuels,
    /// and guessing one at random is worse than admitting we do not know.
    func fuzzyMatch(_ input: String, maxDistance: Int = 2) -> (canonical: String, matchedAlias: String, distance: Int)? {
        let candidates = fuzzyCandidates(input, maxDistance: maxDistance)
        guard let first = candidates.first else { return nil }
        
        let books = Set(candidates.map(\.canonical))
        guard books.count == 1 else {
            let sortedBooks = books.sorted()
            Logger.detection.warning("Ambiguous fuzzy match for '\(input.lowercased(), privacy: .public)' at distance \(first.distance): \(sortedBooks.joined(separator: ", "), privacy: .public) — rejecting")
            return nil
        }
        
        return (first.canonical, first.alias, first.distance)
    }
    
    /// True when the input is a known alias verbatim, so no fuzzy guessing was needed.
    /// Mirrors every exact-match branch in `match(_:chapterHint:)`, including the
    /// space-stripped lookup for numbered books, so the two functions cannot disagree
    /// about whether a resolution was a certainty or a guess.
    func isExactAlias(_ input: String) -> Bool {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespaces)
        if bookMappings[lowercased] != nil
            || BibleVocabularyData.sttMishearings[lowercased] != nil
            || BibleVocabularyData.abbreviations[lowercased] != nil {
            return true
        }
        let noSpaces = lowercased.replacingOccurrences(of: " ", with: "")
        return bookMappings[noSpaces] != nil
    }
    
    /// Suggest a correction for a misheard book name
    /// Returns (suggestedBook, confidence) where confidence is 0.0-1.0
    func suggestCorrection(for input: String) -> (book: String, confidence: Float)? {
        suggestCorrections(for: input).first
    }
    
    /// Ranked correction candidates for a misheard book name, best first.
    ///
    /// Deliberately more lenient than `fuzzyMatch(_:maxDistance:)`, which returns nil
    /// whenever the closest aliases disagree. That is right for detection, where guessing
    /// shows the congregation the wrong verse — but wrong here, because a suggestion goes
    /// to a person for confirmation. Offering "did you mean Psalms, James or Amos?" is
    /// strictly more useful than offering nothing.
    func suggestCorrections(for input: String) -> [(book: String, confidence: Float)] {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Try exact match first
        if let canonical = bookMappings[lowercased] {
            return [(canonical, 1.0)]
        }
        
        // Widen the search until something turns up. Confidence reflects the distance,
        // so a two-edit suggestion presents itself as the guess it is.
        let confidenceForDistance: [Int: Float] = [0: 1.0, 1: 0.9, 2: 0.7, 3: 0.5]
        for maxDistance in 1...3 {
            let candidates = fuzzyCandidates(lowercased, maxDistance: maxDistance)
            guard !candidates.isEmpty else { continue }
            
            // Several aliases can point at the same book ("sams" and "salms" are both
            // Psalms); collapse to one entry per book, preserving the sorted alias order.
            var seen = Set<String>()
            var ranked: [(book: String, confidence: Float)] = []
            for candidate in candidates where seen.insert(candidate.canonical).inserted {
                ranked.append((candidate.canonical, confidenceForDistance[candidate.distance] ?? 0.4))
            }
            return ranked
        }
        
        return []
    }
    
    /// Calculate Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }
        
        return matrix[m][n]
    }
    
    /// Add a custom mapping (for learned corrections)
    func addMapping(_ alias: String, to canonical: String) {
        bookMappings[alias.lowercased()] = canonical
        sortedAliasesCache = nil  // The alias set changed; the sorted view is now stale.
        Logger.detection.info("Added book mapping: '\(alias, privacy: .public)' → '\(canonical, privacy: .public)'")
    }
    
    /// Get all canonical book names
    var allCanonicalNames: [String] {
        Array(Set(bookMappings.values)).sorted()
    }
    
    /// Get all known aliases for vocabulary building
    var allAliases: [String] {
        Array(bookMappings.keys)
    }
}
