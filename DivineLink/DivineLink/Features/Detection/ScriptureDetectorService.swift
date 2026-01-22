import Foundation
import Combine

// MARK: - Detection Result

/// Result of scripture detection with metadata
struct DetectionResult: Identifiable {
    let id = UUID()
    let reference: ScriptureReference
    let rawMatch: String
    let confidence: Float
    let timestamp: Date
    
    /// Formatted display string
    var displayReference: String {
        reference.formatted
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
    
    private let bookNormaliser = BookNameNormaliser()
    private var recentDetections: [String: Date] = [:]
    private let debounceInterval: TimeInterval = 5.0
    
    // Compiled regex patterns
    private var patterns: [(NSRegularExpression, PatternType)] = []
    
    // MARK: - Pattern Types
    
    private enum PatternType {
        case standard       // John 3:16 or John 3:16-18
        case spoken         // John 316 or John 3 16 (speech recognition format)
        case verbal         // John chapter 3 verse 16
        case verbalShort    // Genesis 1 verse 1 (no "chapter" keyword)
        case chapterOnly    // Romans 8
    }
    
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
        // Standard format: "John 3:16" or "John 3:16-18" or "1 John 3:16"
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:\d\s?)?[A-Za-z]+(?:\s[A-Za-z]+)?)\s+(\d{1,3}):(\d{1,3})(?:\s?-\s?(\d{1,3}))?"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .standard))
        }
        
        // Spoken format without colon: "John 316" (chapter+verse concatenated)
        // Matches: John 316, Romans 828, Psalm 231 (interprets as chapter+verse)
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:\d\s?)?[A-Za-z]+(?:\s[A-Za-z]+)?)\s+(\d)(\d{1,2})(?:\s|$|[,.])"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .spoken))
        }
        
        // Spoken format with space: "John 3 16" (space instead of colon)
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:\d\s?)?[A-Za-z]+(?:\s[A-Za-z]+)?)\s+(\d{1,3})\s+(\d{1,3})(?:\s|$|[,.])"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .spoken))
        }
        
        // Verbal format: "John chapter 3 verse 16" or "John chapter 3 verses 16 through 18"
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:\d\s?)?[A-Za-z]+(?:\s[A-Za-z]+)?)\s+chapter\s+(\d{1,3})\s+verse?s?\s+(\d{1,3})(?:\s+(?:to|through|-)\s+(\d{1,3}))?"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .verbal))
        }
        
        // Verbal short format: "Genesis 1 verse 1" or "Genesis 1 verse one" (no "chapter" keyword)
        // Pattern: Book Number verse Number/Word
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:\d\s?)?[A-Za-z]+(?:\s[A-Za-z]+)?)\s+(\d{1,3})\s+verse?s?\s+(\d{1,3}|[a-z]+(?:-[a-z]+)?)(?:\s+(?:to|through|-)\s+(\d{1,3}|[a-z]+(?:-[a-z]+)?))?"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .verbalShort))
        }
        
        // Verbal with word numbers: "Genesis one verse one", "Psalm twenty-three"
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:\d\s?)?[A-Za-z]+(?:\s[A-Za-z]+)?)\s+(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|twenty-\w+|thirty|thirty-\w+|forty|forty-\w+|fifty)\s+verse?s?\s+(\d{1,3}|[a-z]+(?:-[a-z]+)?)(?:\s|$|[,.])"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .verbalShort))
        }
        
        // Chapter only format: "Romans 8" (at end of sentence or followed by comma/period)
        if let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)((?:\d\s?)?[A-Za-z]+(?:\s[A-Za-z]+)?)\s+(\d{1,3})(?:\s*[,.\s]|$)"#,
            options: .caseInsensitive
        ) {
            patterns.append((regex, .chapterOnly))
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
        // Extract book name
        guard match.numberOfRanges >= 3,
              let bookRange = Range(match.range(at: 1), in: text),
              let chapterRange = Range(match.range(at: 2), in: text) else {
            return nil
        }
        
        let rawBook = String(text[bookRange]).trimmingCharacters(in: .whitespaces)
        
        // Normalise book name
        guard let canonicalBook = bookNormaliser.normalise(rawBook) else {
            return nil // Not a valid book name
        }
        
        // Parse chapter - handle both numbers and words
        let chapterStr = String(text[chapterRange]).trimmingCharacters(in: .whitespaces).lowercased()
        guard let chapter = parseNumber(chapterStr) else {
            return nil
        }
        
        // Parse verse(s)
        var verseStart = 1
        var verseEnd: Int? = nil
        
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
        
        // Calculate confidence based on pattern type
        let confidence: Float = switch type {
        case .standard: 0.95
        case .spoken: 0.85    // Lower confidence for speech-to-text formats
        case .verbal: 0.90
        case .verbalShort: 0.88  // Natural speech without "chapter" keyword
        case .chapterOnly: 0.80
        }
        
        return DetectionResult(
            reference: reference,
            rawMatch: rawMatch,
            confidence: confidence,
            timestamp: Date()
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
    
    // Canonical book names mapped from various inputs
    private let bookMappings: [String: String] = [
        // Old Testament
        "genesis": "Genesis", "gen": "Genesis", "ge": "Genesis", "genisis": "Genesis", "jenesis": "Genesis",
        "exodus": "Exodus", "exod": "Exodus", "ex": "Exodus",
        "leviticus": "Leviticus", "lev": "Leviticus", "le": "Leviticus",
        "numbers": "Numbers", "num": "Numbers", "nu": "Numbers",
        "deuteronomy": "Deuteronomy", "deut": "Deuteronomy", "de": "Deuteronomy",
        "joshua": "Joshua", "josh": "Joshua", "jos": "Joshua",
        "judges": "Judges", "judg": "Judges", "jdg": "Judges",
        "ruth": "Ruth", "ru": "Ruth",
        "1 samuel": "1 Samuel", "1samuel": "1 Samuel", "first samuel": "1 Samuel", "i samuel": "1 Samuel", "1 sam": "1 Samuel", "1sam": "1 Samuel",
        "2 samuel": "2 Samuel", "2samuel": "2 Samuel", "second samuel": "2 Samuel", "ii samuel": "2 Samuel", "2 sam": "2 Samuel", "2sam": "2 Samuel",
        "1 kings": "1 Kings", "1kings": "1 Kings", "first kings": "1 Kings", "i kings": "1 Kings", "1 kgs": "1 Kings",
        "2 kings": "2 Kings", "2kings": "2 Kings", "second kings": "2 Kings", "ii kings": "2 Kings", "2 kgs": "2 Kings",
        "1 chronicles": "1 Chronicles", "1chronicles": "1 Chronicles", "first chronicles": "1 Chronicles", "i chronicles": "1 Chronicles", "1 chr": "1 Chronicles",
        "2 chronicles": "2 Chronicles", "2chronicles": "2 Chronicles", "second chronicles": "2 Chronicles", "ii chronicles": "2 Chronicles", "2 chr": "2 Chronicles",
        "ezra": "Ezra", "ezr": "Ezra",
        "nehemiah": "Nehemiah", "neh": "Nehemiah", "ne": "Nehemiah",
        "esther": "Esther", "est": "Esther", "es": "Esther",
        "job": "Job", "jb": "Job",
        "psalms": "Psalms", "psalm": "Psalms", "ps": "Psalms", "psa": "Psalms",
        "some": "Psalms", "sum": "Psalms", "salm": "Psalms", "sums": "Psalms", "palms": "Psalms",  // Common speech-to-text misheard
        "proverbs": "Proverbs", "prov": "Proverbs", "pr": "Proverbs", "pro": "Proverbs",
        "ecclesiastes": "Ecclesiastes", "eccles": "Ecclesiastes", "eccl": "Ecclesiastes", "ec": "Ecclesiastes",
        "song of solomon": "Song of Solomon", "song of songs": "Song of Solomon", "songs": "Song of Solomon", "sos": "Song of Solomon", "ss": "Song of Solomon",
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
        "galatians": "Galatians", "gal": "Galatians", "ga": "Galatians",
        "ephesians": "Ephesians", "eph": "Ephesians", "ep": "Ephesians",
        "philippians": "Philippians", "phil": "Philippians", "php": "Philippians",
        "colossians": "Colossians", "col": "Colossians",
        "1 thessalonians": "1 Thessalonians", "1thessalonians": "1 Thessalonians", "first thessalonians": "1 Thessalonians", "i thessalonians": "1 Thessalonians", "1 thess": "1 Thessalonians", "1thess": "1 Thessalonians",
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
        
        // Direct lookup
        if let canonical = bookMappings[lowercased] {
            return canonical
        }
        
        // Try without spaces for numbered books
        let noSpaces = lowercased.replacingOccurrences(of: " ", with: "")
        if let canonical = bookMappings[noSpaces] {
            return canonical
        }
        
        return nil
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
