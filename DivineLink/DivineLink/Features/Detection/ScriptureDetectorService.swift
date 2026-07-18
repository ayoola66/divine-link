import Foundation
import Combine

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
    
    // MARK: - Publishers
    
    /// Publishes detected scripture references
    let detectionPublisher = PassthroughSubject<DetectionResult, Never>()
    
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
    
    /// Reference buffer for stateful context tracking
    private let referenceBuffer = ReferenceBuffer.shared
    
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
    
    init() {
        compilePatterns()
    }
    
    private func compilePatterns() {
        // IMPORTANT: Order matters! More specific patterns should come FIRST
        // to prevent less specific patterns from matching partial references
        
        // 1. VERBAL FORMAT (most specific - has "chapter" and "verse" keywords)
        // "John chapter 3 verse 16" or "Genesis chapter 1 verses 1 to 5"
        // Accepts both digits and number words for chapter and verse
        // Also accepts "versus" as speech recognition often mishears "verse"
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:\d\s?)?[A-Za-z]+)\s+chapter\s+(\d{1,3}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|twenty-?\w*|thirty|thirty-?\w*|forty|forty-?\w*|fifty)\s+(?:verse?s?|versus)\s+(\d{1,3}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|twenty-?\w*|thirty|thirty-?\w*|forty|forty-?\w*|fifty)(?:\s+(?:to|through|-)\s+(\d{1,3}|[a-z-]+))?"#,
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
            pattern: #"(?:^|\s)((?:\d\s?)?[A-Za-z]+)\s+(?:verse?s?|versus)\s+(\d{1,3}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|twenty-?\w*|thirty|thirty-?\w*|forty|forty-?\w*|fifty)(?:\s+(?:to|through|-)\s+(\d{1,3}|[a-z]+(?:-[a-z]+)?))?\s+chapter\s+(\d{1,3}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|twenty-?\w*|thirty|thirty-?\w*|forty|forty-?\w*|fifty)(?:\s|$|[,.])"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .bookVerseChapter))
            print("✅ bookVerseChapter pattern compiled (priority 1b - verse before chapter)")
        }

        // 2. VERBAL SHORT: "Genesis 1 verse 1" or "John 3 verse 16 to 20" (no "chapter" keyword)
        // Limit chapter to 1-2 digits (max 99) to avoid matching "316" as chapter
        // Also accept "versus" as speech recognition often mishears "verse"
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:\d\s?)?[A-Za-z]+)\s+(\d{1,2})\s+(?:verse?s?|versus)\s+(\d{1,3}|[a-z]+(?:-[a-z]+)?)(?:\s+(?:to|through|-)\s+(\d{1,3}|[a-z]+(?:-[a-z]+)?))?(?:\s|$|[,.])"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .verbalShort))
            print("✅ verbalShort pattern compiled (priority 2)")
        }
        
        // 2b. VERBAL SHORT with word chapter: "John three verse 16" or "Genesis one verse 1"
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:\d\s?)?[A-Za-z]+)\s+(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|twenty-?\w*|thirty|thirty-?\w*|forty|forty-?\w*|fifty)\s+(?:verse?s?|versus)\s+(\d{1,3}|[a-z]+(?:-[a-z]+)?)(?:\s+(?:to|through|-)\s+(\d{1,3}|[a-z]+(?:-[a-z]+)?))?(?:\s|$|[,.])"#,
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
            pattern: #"(?:^|\s)((?:\d\s?)?[A-Za-z]+)\s+(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|twenty-\w+|thirty|thirty-\w+|forty|forty-\w+|fifty)\s+verse?s?\s+(\d{1,3}|[a-z]+(?:-[a-z]+)?)(?:\s|$|[,.])"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .verbalShort))
        }
        
        // 7. SPOKEN WORD NUMBERS: "John three sixteen" → 3:16
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:\d\s?)?[A-Za-z]+)\s+(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\s+(ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|twenty-?\w*|thirty|thirty-?\w*)(?:\s|$|[,.])"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .spokenWords))
        }
        
        // 8. CHAPTER ONLY: "Romans 8" (LAST - least specific)
        // Only match at end of text or followed by punctuation to avoid partial matches
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:\d\s?)?[A-Za-z]+)\s+(\d{1,3})(?:\s*[,.!?;:]|\s*$)"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .chapterOnly))
        }
        
        // 9. INVERTED VERBAL: "verse 31 of Romans 8" or "verse 31 of Romans eight"
        // Captures: (verse_start) (verse_end optional) (book) (chapter as number or word)
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)(?:verse?s?|versus)\s+(\d{1,3}|[a-z]+(?:-[a-z]+)?)(?:\s+(?:to|through|-)\s+(\d{1,3}|[a-z]+(?:-[a-z]+)?))?\s+(?:of|in|from)\s+((?:\d\s?)?[A-Za-z]+)\s+(\d{1,3}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|twenty-?\w*|thirty|thirty-?\w*|forty|forty-?\w*|fifty)(?:\s|$|[,.])"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .invertedVerbal))
            print("✅ invertedVerbal pattern compiled (verse X of Book Y)")
        }
        
        // 10. PARTIAL VERSE: "verse 18" or "verses 5 to 7" (requires context buffer)
        // This is lowest priority - only works if we have context from a previous detection
        // Pattern captures: (verse_start) and optionally (verse_end)
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)(?:verse?s?|versus)\s+(\d{1,3}|[a-z]+(?:-[a-z]+)?)(?:\s+(?:to|through|-)\s+(\d{1,3}|[a-z]+(?:-[a-z]+)?))?"#,
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
            print("⚠️ Rejected common word as book name: '\(rawBook)' (pattern: \(type))")
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
            print("⚠️ Rejected stripped result as common word: '\(rawBook)' (pattern: \(type))")
            return nil
        }
        
        // Normalise book name
        guard let canonicalBook = bookNormaliser.normalise(rawBook) else {
            print("⚠️ Book not recognized: '\(rawBook)' (pattern: \(type))")
            return nil // Not a valid book name
        }
        
        print("📖 Parsing match: book='\(rawBook)'→'\(canonicalBook)' (pattern: \(type))")
        
        var chapter: Int
        var verseStart = 1
        var verseEnd: Int? = nil
        
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
                        }
                    }
                } else {
                    // Not compound, just two separate numbers: chapter and verse
                    guard let ch = parseNumber(chapterPart1) else { return nil }
                    chapter = ch
                    if let verse = parseNumber(chapterPart2) {
                        verseStart = verse
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
                print("⚠️ Rejected invalid chapter number: \(ch) (max allowed: 150)")
                return nil
            }
            
            // Additional validation: most books have far fewer chapters
            // Only Psalms has 150, Isaiah has 66, Jeremiah 52, etc.
            // Reject obviously wrong chapter numbers for non-Psalms books
            if ch > 50 && type != .chapterOnly {
                // This is suspicious - log it for review
                print("⚠️ Suspicious high chapter number: \(ch) for pattern \(type)")
            }
            
            chapter = ch
            
            if type != .chapterOnly {
                // Get start verse - handle both numbers and words
                if match.numberOfRanges >= 4,
                   let verseRange = Range(match.range(at: 3), in: text) {
                    let verseStr = String(text[verseRange]).trimmingCharacters(in: .whitespaces).lowercased()
                    if let verse = parseNumber(verseStr) {
                        verseStart = verse
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
            print("⚠️ Rejected invalid verse number: \(verseStart) (max allowed: 176)")
            return nil
        }
        
        if let endVerse = verseEnd, endVerse > 176 {
            print("⚠️ Rejected invalid end verse: \(endVerse) (max allowed: 176)")
            return nil
        }
        
        // Reject if verse start is higher than verse end (invalid range)
        if let endVerse = verseEnd, verseStart > endVerse {
            print("⚠️ Rejected invalid verse range: \(verseStart)-\(endVerse) (start > end)")
            return nil
        }
        
        // Reject suspiciously large verse ranges (more than 30 verses at once is unusual)
        if let endVerse = verseEnd, (endVerse - verseStart) > 30 {
            print("⚠️ Suspicious large verse range: \(verseStart)-\(endVerse) (\(endVerse - verseStart) verses)")
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
            verseEnd: verseEnd
        )
        
        // Calculate multi-factor confidence using DetectionConfidence model
        // 
        // Factors:
        // 1. Reference Clarity - How clear and unambiguous was the reference pattern?
        // 2. Speech Confidence - Pattern-based estimation (true speech confidence comes from Whisper)
        // 3. Context Match - How well does the match fit expected patterns?
        // 4. Verse Existence - Assumed valid if book is recognised (full validation done downstream)
        
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
            verseExistence = 1.0  // Validated book + reasonable chapter/verse
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
        
        // Adjust confidence based on book name recognition quality
        // If the book required fuzzy matching, reduce confidence
        var adjustedReferenceClarity = referenceClarity
        if bookNormaliser.fuzzyMatch(rawBook, maxDistance: 0) == nil {
            // Fuzzy match was used
            if let fuzzyResult = bookNormaliser.fuzzyMatch(rawBook, maxDistance: 2) {
                // Reduce clarity based on edit distance
                let penalty = Double(fuzzyResult.distance) * 0.05
                adjustedReferenceClarity = max(0.5, referenceClarity - penalty)
            }
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
        
        // CRITICAL: Apply minimum confidence threshold to prevent false detections
        let minimumConfidence: Double = 0.75
        if detectionConfidence.overall < minimumConfidence {
            print("⚠️ Rejected detection below minimum confidence: \(detectionConfidence.percentage)% < \(Int(minimumConfidence * 100))% for \(reference.formatted)")
            return nil
        }
        
        print("✅ Detection: \(reference.formatted) [\(patternTypeName)] - Confidence: \(detectionConfidence.percentage)% (\(detectionConfidence.level.rawValue))")
        
        // Update reference buffer context for future partial reference resolution
        // This enables "verse 18" to resolve to "John 3:18" after detecting "John 3:16"
        // Also enables "next verse" to resolve correctly
        referenceBuffer.updateContext(
            book: reference.book,
            chapter: reference.chapter,
            verseStart: reference.verseStart,
            verseEnd: reference.verseEnd
        )
        
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
        guard let canonicalBook = bookNormaliser.normalise(rawBook) else {
            print("⚠️ [invertedVerbal] Could not normalize book: \(rawBook)")
            return nil
        }
        
        // Validate chapter is reasonable (max 150 like Psalms)
        if chapter > 150 {
            print("⚠️ [invertedVerbal] Rejected invalid chapter: \(chapter)")
            return nil
        }
        
        // Validate verse is reasonable (max 176 like Psalm 119)
        if verseStart > 176 {
            print("⚠️ [invertedVerbal] Rejected invalid verse: \(verseStart)")
            return nil
        }
        
        // Create the scripture reference
        let reference = ScriptureReference(
            book: canonicalBook,
            chapter: chapter,
            verseStart: verseStart,
            verseEnd: verseEnd
        )
        
        // Calculate confidence
        let confidence = DetectionConfidence(
            referenceClarity: 0.85,
            speechConfidence: 0.80,
            contextMatch: 1.0,
            verseExistence: 1.0
        )
        
        // Update reference buffer context
        referenceBuffer.updateContext(
            book: canonicalBook,
            chapter: chapter,
            verseStart: verseStart,
            verseEnd: verseEnd
        )
        
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
        guard let canonicalBook = bookNormaliser.normalise(rawBook) else {
            print("⚠️ [bookVerseChapter] Could not normalize book: '\(rawBook)'")
            return nil
        }

        // Validate ranges (Psalms has 150 chapters; Psalm 119 has 176 verses)
        if chapter > 150 {
            print("⚠️ [bookVerseChapter] Rejected invalid chapter: \(chapter)")
            return nil
        }
        if verseStart > 176 {
            print("⚠️ [bookVerseChapter] Rejected invalid verse: \(verseStart)")
            return nil
        }

        let reference = ScriptureReference(
            book: canonicalBook,
            chapter: chapter,
            verseStart: verseStart,
            verseEnd: verseEnd
        )

        let confidence = DetectionConfidence(
            referenceClarity: 0.85,
            speechConfidence: 0.80,
            contextMatch: 1.0,
            verseExistence: 1.0
        )

        referenceBuffer.updateContext(
            book: canonicalBook,
            chapter: chapter,
            verseStart: verseStart,
            verseEnd: verseEnd
        )

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
            referenceBuffer.updateContext(
                book: reference.book,
                chapter: reference.chapter,
                verseStart: reference.verseStart,
                verseEnd: reference.verseEnd
            )
            
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
            referenceBuffer.updateContext(
                book: reference.book,
                chapter: reference.chapter,
                verseStart: reference.verseStart,
                verseEnd: reference.verseEnd
            )
            
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
            verseEnd: verseEnd
        )
        
        // Calculate confidence - lower because we're relying on context
        let detectionConfidence = DetectionConfidence(
            referenceClarity: 0.70,     // Partial reference is less clear
            speechConfidence: 0.85,
            contextMatch: 0.95,          // High because we're using valid context
            verseExistence: 1.0
        )
        
        // Apply minimum confidence threshold
        if detectionConfidence.overall < 0.75 {
            print("⚠️ [partialVerse] Below minimum confidence threshold")
            return nil
        }
        
        print("✅ [partialVerse] Resolved: '\(rawMatch)' → \(reference.formatted) using context [\(context.book) \(context.chapter)]")
        
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
        "1 samuel": "1 Samuel", "1samuel": "1 Samuel", "first samuel": "1 Samuel", "i samuel": "1 Samuel", "1 sam": "1 Samuel", "1sam": "1 Samuel",
        "2 samuel": "2 Samuel", "2samuel": "2 Samuel", "second samuel": "2 Samuel", "ii samuel": "2 Samuel", "2 sam": "2 Samuel", "2sam": "2 Samuel",
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
    
    /// Normalise a book name to its canonical form
    func normalise(_ input: String) -> String? {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespaces)
        
        // FIRST: Check if this is a common word that should NEVER be a book name
        // This prevents "to" from being fuzzy-matched to "ho" → Hosea
        if excludedWords.contains(lowercased) {
            return nil
        }
        
        // Check for numbered prefixes with excluded words: "1 to" → check if "to" is excluded
        // This prevents "1 to" from fuzzy-matching to "1 Timothy"
        if let match = lowercased.firstMatch(of: /^(\d+)\s+(.+)$/) {
            let baseWord = String(match.output.2)
            if excludedWords.contains(baseWord) {
                print("   ⚠️ Rejecting '\(lowercased)' - base word '\(baseWord)' is excluded")
                return nil
            }
        }
        
        // Also exclude very short words (1-2 chars) unless they're exact matches
        // This prevents random short words from fuzzy-matching
        if lowercased.count <= 2 && bookMappings[lowercased] == nil {
            return nil
        }
        
        // Direct lookup in primary mappings
        if let canonical = bookMappings[lowercased] {
            return canonical
        }
        
        // Try BibleVocabularyData STT mishearings
        if let canonical = BibleVocabularyData.sttMishearings[lowercased] {
            return canonical
        }
        
        // Try abbreviations
        if let canonical = BibleVocabularyData.abbreviations[lowercased] {
            return canonical
        }
        
        // Try without spaces for numbered books
        let noSpaces = lowercased.replacingOccurrences(of: " ", with: "")
        if let canonical = bookMappings[noSpaces] {
            return canonical
        }
        
        // Try fuzzy match if no exact match (only for words 3+ chars to avoid false matches)
        if lowercased.count >= 3 {
            if let fuzzyMatch = fuzzyMatch(lowercased, maxDistance: 2) {
                return fuzzyMatch.canonical
            }
        }
        
        return nil
    }
    
    /// Fuzzy match a book name using Levenshtein distance
    /// Returns the closest match if within maxDistance, along with the matched alias
    func fuzzyMatch(_ input: String, maxDistance: Int = 2) -> (canonical: String, matchedAlias: String, distance: Int)? {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespaces)
        
        var bestMatch: (canonical: String, matchedAlias: String, distance: Int)?
        var minDistance = Int.max
        
        for (alias, canonical) in bookMappings {
            let distance = levenshteinDistance(lowercased, alias)
            
            if distance < minDistance && distance <= maxDistance {
                minDistance = distance
                bestMatch = (canonical, alias, distance)
            }
        }
        
        return bestMatch
    }
    
    /// Suggest a correction for a misheard book name
    /// Returns (suggestedBook, confidence) where confidence is 0.0-1.0
    func suggestCorrection(for input: String) -> (book: String, confidence: Float)? {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Try exact match first
        if let canonical = bookMappings[lowercased] {
            return (canonical, 1.0)
        }
        
        // Try fuzzy match with different thresholds
        if let match = fuzzyMatch(lowercased, maxDistance: 1) {
            return (match.canonical, 0.9)
        }
        
        if let match = fuzzyMatch(lowercased, maxDistance: 2) {
            return (match.canonical, 0.7)
        }
        
        if let match = fuzzyMatch(lowercased, maxDistance: 3) {
            return (match.canonical, 0.5)
        }
        
        return nil
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
        print("📚 Added book mapping: '\(alias)' → '\(canonical)'")
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
