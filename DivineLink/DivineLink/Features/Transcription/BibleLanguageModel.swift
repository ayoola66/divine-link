import Foundation
import Speech
import os

/// Custom language model for Bible vocabulary
/// Uses Apple's SFSpeechLanguageModel to bias recognition toward Bible book names
@MainActor
class BibleLanguageModel: ObservableObject {
    
    // MARK: - Properties
    
    private let modelIdentifier = "com.divinelink.bible-vocabulary"
    private let modelVersion = "1.0"
    private let logger = Logger(subsystem: "com.divinelink", category: "BibleLanguageModel")
    
    @Published var isReady = false
    @Published var isLoading = false
    @Published var error: String?
    
    private var languageModelConfiguration: SFSpeechLanguageModelConfiguration?
    
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
    
    // MARK: - Initialisation
    
    init() {
        Task {
            await prepareLanguageModel()
        }
    }
    
    // MARK: - Model Preparation
    
    /// Prepare the custom language model for use with speech recognition
    func prepareLanguageModel() async {
        isLoading = true
        error = nil
        
        do {
            let modelData = createLanguageModelData()
            
            // Get Application Support directory
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let modelDir = appSupport.appendingPathComponent("DivineLink/LanguageModel")
            
            try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
            
            let dataURL = modelDir.appendingPathComponent("bible-vocabulary.bin")
            
            // Export training data
            try await modelData.export(to: dataURL)
            logger.info("Language model data exported to: \(dataURL.path)")
            
            // Create configuration
            let config = SFSpeechLanguageModelConfiguration(modelID: modelIdentifier)
            
            // Prepare compiled model
            try await SFSpeechLanguageModel.prepareCustomLanguageModel(
                for: dataURL,
                clientIdentifier: "com.divinelink",
                configuration: config
            )
            
            languageModelConfiguration = config
            isReady = true
            logger.info("✅ Bible language model ready")
            
        } catch {
            self.error = error.localizedDescription
            logger.error("❌ Failed to prepare language model: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Get the language model configuration for use with speech recognition
    var configuration: SFSpeechLanguageModelConfiguration? {
        return languageModelConfiguration
    }
    
    // MARK: - Model Data Creation
    
    @SFCustomLanguageModelDataBuilder
    private func createLanguageModelData() -> SFCustomLanguageModelData {
        SFCustomLanguageModelData(
            locale: Locale(identifier: "en-GB"),
            identifier: modelIdentifier,
            version: modelVersion
        ) {
            // Old Testament Books - High priority
            for book in oldTestamentBooks {
                SFCustomLanguageModelData.PhraseCount(phrase: book, count: 1000)
            }
            
            // New Testament Books - High priority
            for book in newTestamentBooks {
                SFCustomLanguageModelData.PhraseCount(phrase: book, count: 1000)
            }
            
            // Numbered book variations
            for variation in numberedBookVariations {
                SFCustomLanguageModelData.PhraseCount(phrase: variation, count: 800)
            }
            
            // Difficult pronunciations - Highest priority
            for name in difficultNames {
                SFCustomLanguageModelData.PhraseCount(phrase: name, count: 1200)
            }
            
            // Theological terms
            for term in theologicalTerms {
                SFCustomLanguageModelData.PhraseCount(phrase: term, count: 500)
            }
            
            // Custom pronunciations for difficult names
            SFCustomLanguageModelData.CustomPronunciation(
                grapheme: "Habakkuk",
                phonemes: ["h æ b ə k ʌ k"]
            )
            SFCustomLanguageModelData.CustomPronunciation(
                grapheme: "Zephaniah",
                phonemes: ["z ɛ f ə n aɪ ə"]
            )
            SFCustomLanguageModelData.CustomPronunciation(
                grapheme: "Ecclesiastes",
                phonemes: ["ɪ k l iː z i æ s t iː z"]
            )
            SFCustomLanguageModelData.CustomPronunciation(
                grapheme: "Deuteronomy",
                phonemes: ["d uː t ə r ɒ n ə m i"]
            )
            SFCustomLanguageModelData.CustomPronunciation(
                grapheme: "Leviticus",
                phonemes: ["l ɪ v ɪ t ɪ k ə s"]
            )
            SFCustomLanguageModelData.CustomPronunciation(
                grapheme: "Philippians",
                phonemes: ["f ɪ l ɪ p i ə n z"]
            )
            SFCustomLanguageModelData.CustomPronunciation(
                grapheme: "Colossians",
                phonemes: ["k ə l ɒ ʃ ə n z"]
            )
            SFCustomLanguageModelData.CustomPronunciation(
                grapheme: "Thessalonians",
                phonemes: ["θ ɛ s ə l oʊ n i ə n z"]
            )
            SFCustomLanguageModelData.CustomPronunciation(
                grapheme: "Galatians",
                phonemes: ["ɡ ə l eɪ ʃ ə n z"]
            )
            SFCustomLanguageModelData.CustomPronunciation(
                grapheme: "Ephesians",
                phonemes: ["ɪ f iː ʒ ə n z"]
            )
        }
    }
}
