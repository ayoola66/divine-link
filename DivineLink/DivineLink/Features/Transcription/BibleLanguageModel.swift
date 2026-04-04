import Foundation
import Speech
import Combine
import os

/// Custom language model for Bible vocabulary.
/// On first run, compiles an SFCustomLanguageModelData model from Bible vocabulary and
/// caches it to Application Support. Subsequent launches load from cache.
/// Falls back to contextualStrings if compilation fails or is still in progress.
@MainActor
class BibleLanguageModel: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.divinelink", category: "BibleLanguageModel")
    
    @Published var isReady = false
    @Published var isLoading = false
    @Published var error: String?

    /// URL of the compiled SFCustomLanguageModelData model, once prepared.
    /// nil until compilation completes — applyTo falls back to contextualStrings meanwhile.
    private var compiledModelURL: URL?
    
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
        // contextualStrings are always ready immediately as the fallback path
        isReady = true
        logger.info("Bible vocabulary loaded: \(self.allPhrases.count) phrases")

        // Capture vocabulary arrays on the main actor before hopping off.
        let books = oldTestamentBooks + newTestamentBooks + numberedBookVariations

        // Run model compilation entirely off the main actor (utility priority) to avoid
        // QoS inversion: the Apple Speech / file I/O callbacks run on Default-QoS threads,
        // and awaiting them from the main actor causes Thread Performance Checker warnings.
        Task.detached(priority: .utility) { [weak self] in
            await self?.prepareCustomLanguageModelDetached(books: books)
        }
    }

    // MARK: - Custom Language Model Compilation

    /// Compiles SFCustomLanguageModelData from Bible vocabulary and caches to disk.
    /// Runs off the main actor (called via Task.detached). Hops back only to set compiledModelURL.
    /// Falls back to contextualStrings if either step fails.
    private nonisolated func prepareCustomLanguageModelDetached(books: [String]) async {
        // Create a local logger — Logger is a Sendable struct, safe off the main actor.
        let log = Logger(subsystem: "com.divinelink", category: "BibleLanguageModel")

        guard let dir = modelDirectory() else {
            log.warning("Could not determine Application Support directory for Bible language model")
            return
        }

        let exportURL = dir.appendingPathComponent("BibleData.exported")
        let modelURL  = dir.appendingPathComponent("BibleModel.bin")

        // Load from cache if the compiled model already exists
        if FileManager.default.fileExists(atPath: modelURL.path) {
            await MainActor.run { [weak self] in
                self?.compiledModelURL = modelURL
                self?.isReady = true
            }
            log.info("Bible language model loaded from cache")
            return
        }

        log.info("Compiling Bible language model (first run — will be cached)…")

        do {
            typealias Template = SFCustomLanguageModelData.TemplatePhraseCountGenerator.Template

            // Build training data using result builder syntax
            let data = SFCustomLanguageModelData(
                locale: Locale(identifier: "en-GB"),
                identifier: "com.divinelink.bible",
                version: "1.0"
            ) {
                SFCustomLanguageModelData.PhraseCountsFromTemplates(
                    classes: ["BOOK": books]
                ) {
                    Template("{BOOK} chapter", count: 100)
                    Template("{BOOK} verse",   count: 100)
                    Template("in {BOOK}",      count: 100)
                    Template("turn to {BOOK}", count: 80)
                    Template("look at {BOOK}", count: 80)
                    Template("open to {BOOK}", count: 80)
                    Template("the book of {BOOK}", count: 60)
                    Template("read from {BOOK}",   count: 60)
                    Template("as {BOOK} says",      count: 50)
                    Template("according to {BOOK}", count: 50)
                }
            }

            // Step 1: Export raw training data to disk
            try await data.export(to: exportURL)

            // Step 2: Compile into a speech language model
            let configuration = SFSpeechLanguageModel.Configuration(languageModel: modelURL)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                SFSpeechLanguageModel.prepareCustomLanguageModel(
                    for: exportURL,
                    configuration: configuration
                ) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }

            // Hop back to the main actor only to update published state
            await MainActor.run { [weak self] in
                self?.compiledModelURL = modelURL
                self?.isReady = true
            }
            log.info("Bible language model compiled and cached at \(modelURL.lastPathComponent)")

        } catch {
            log.error("Bible language model compilation failed: \(error.localizedDescription) — using contextualStrings fallback")
            // isReady remains true — contextualStrings path is always active
        }
    }

    /// Returns the Application Support/DivineLink directory, creating it if needed.
    /// nonisolated so it can be called from the detached compilation task.
    private nonisolated func modelDirectory() -> URL? {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        let dir = appSupport.appendingPathComponent("DivineLink")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    // MARK: - Apply to Recognition Request
    
    /// Apply Bible vocabulary to a speech recognition request.
    /// Uses the compiled SFCustomLanguageModelData if ready, otherwise contextualStrings.
    func applyTo(request: SFSpeechAudioBufferRecognitionRequest) {
        if let modelURL = compiledModelURL {
            request.customizedLanguageModel = SFSpeechLanguageModel.Configuration(languageModel: modelURL)
            logger.debug("Applied compiled Bible language model from \(modelURL.lastPathComponent)")
        } else {
            request.contextualStrings = contextualStrings
            logger.debug("Applied \(self.contextualStrings.count) contextual strings (compiled model not ready yet)")
        }
    }
}
