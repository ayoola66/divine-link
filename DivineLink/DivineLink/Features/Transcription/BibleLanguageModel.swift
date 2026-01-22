import Foundation
import Speech
import Combine
import os

/// Custom language model for Bible vocabulary
/// Uses contextual strings to bias recognition toward Bible book names
/// Note: Full SFCustomLanguageModelData requires macOS 15+, this provides fallback for macOS 14
@MainActor
class BibleLanguageModel: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.divinelink", category: "BibleLanguageModel")
    
    @Published var isReady = false
    @Published var isLoading = false
    @Published var error: String?
    
    // MARK: - Bible Books (All 66)
    
    private let oldTestamentBooks = [
        "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
        "Joshua", "Judges", "Ruth", "Samuel", "Kings",
        "Chronicles", "Ezra", "Nehemiah", "Esther", "Job",
        "Psalms", "Psalm", "Proverbs", "Ecclesiastes", "Song of Solomon",
        "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel",
        "Hosea", "Joel", "Amos", "Obadiah", "Jonah",
        "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai",
        "Zechariah", "Malachi"
    ]
    
    private let newTestamentBooks = [
        "Matthew", "Mark", "Luke", "John", "Acts",
        "Romans", "Corinthians", "Galatians", "Ephesians", "Philippians",
        "Colossians", "Thessalonians", "Timothy", "Titus", "Philemon",
        "Hebrews", "James", "Peter", "Jude", "Revelation"
    ]
    
    // Numbered book variations
    private let numberedBookVariations = [
        "First Samuel", "Second Samuel", "1 Samuel", "2 Samuel",
        "First Kings", "Second Kings", "1 Kings", "2 Kings",
        "First Chronicles", "Second Chronicles", "1 Chronicles", "2 Chronicles",
        "First Corinthians", "Second Corinthians", "1 Corinthians", "2 Corinthians",
        "First Thessalonians", "Second Thessalonians", "1 Thessalonians", "2 Thessalonians",
        "First Timothy", "Second Timothy", "1 Timothy", "2 Timothy",
        "First Peter", "Second Peter", "1 Peter", "2 Peter",
        "First John", "Second John", "Third John", "1 John", "2 John", "3 John"
    ]
    
    // Difficult pronunciations and common misheards
    private let difficultNames = [
        "Habakkuk", "Zephaniah", "Ecclesiastes", "Deuteronomy",
        "Leviticus", "Nahum", "Obadiah", "Philemon", "Colossians",
        "Galatians", "Ephesians", "Philippians", "Thessalonians",
        "Lamentations", "Zechariah", "Malachi", "Nehemiah"
    ]
    
    // Common theological terms
    private let theologicalTerms = [
        "chapter", "verse", "verses", "scripture", "scriptures",
        "testament", "gospel", "epistle", "prophecy", "apostle",
        "justification", "sanctification", "propitiation", "redemption",
        "atonement", "covenant", "parable", "beatitudes", "sabbath"
    ]
    
    // MARK: - Computed Properties
    
    /// All vocabulary phrases for use with speech recognition
    var allPhrases: [String] {
        var phrases: [String] = []
        phrases.append(contentsOf: oldTestamentBooks)
        phrases.append(contentsOf: newTestamentBooks)
        phrases.append(contentsOf: numberedBookVariations)
        phrases.append(contentsOf: difficultNames)
        phrases.append(contentsOf: theologicalTerms)
        return phrases
    }
    
    /// Contextual strings for SFSpeechRecognitionRequest
    var contextualStrings: [String] {
        // Include book names with common patterns
        var strings: [String] = []
        
        // Add base book names
        strings.append(contentsOf: oldTestamentBooks)
        strings.append(contentsOf: newTestamentBooks)
        strings.append(contentsOf: numberedBookVariations)
        
        // Add common scripture citation patterns
        for book in oldTestamentBooks + newTestamentBooks {
            strings.append("\(book) chapter")
            strings.append("\(book) verse")
        }
        
        // Add theological terms
        strings.append(contentsOf: theologicalTerms)
        
        return strings
    }
    
    // MARK: - Initialisation
    
    init() {
        // Mark as ready immediately - we provide contextual strings, not a compiled model
        isReady = true
        logger.info("Bible vocabulary loaded: \(self.allPhrases.count) phrases")
    }
    
    // MARK: - Apply to Recognition Request
    
    /// Apply Bible vocabulary hints to a speech recognition request
    func applyTo(request: SFSpeechAudioBufferRecognitionRequest) {
        // Use contextual strings to bias recognition (available in macOS 14+)
        request.contextualStrings = contextualStrings
        logger.debug("Applied \(self.contextualStrings.count) contextual strings to recognition request")
    }
}
