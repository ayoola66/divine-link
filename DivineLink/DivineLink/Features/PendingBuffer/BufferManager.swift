import Foundation
import Combine

// MARK: - Individual Verse Item

/// Represents a single verse within a scripture reference
struct VerseItem: Identifiable, Equatable {
    let id = UUID()
    let verseNumber: Int
    let text: String
    
    /// Formatted verse number (e.g., "16")
    var formattedNumber: String {
        "\(verseNumber)"
    }
}

// MARK: - Pending Verse Model

/// Represents a detected scripture verse pending operator approval
struct PendingVerse: Identifiable, Equatable {
    let id = UUID()
    let reference: ScriptureReference
    let verses: [VerseItem]  // Individual verses for verse-by-verse display
    let translation: String
    let timestamp: Date
    let confidence: Float
    let rawTranscript: String  // What was actually heard (for learning)
    var pushCount: Int = 0  // How many times this verse has been pushed
    var lastPushedAt: Date? = nil  // When it was last pushed
    var currentVerseIndex: Int = 0  // For verse-by-verse navigation
    
    /// Combined full text of all verses (for backwards compatibility)
    var fullText: String {
        verses.map { $0.text }.joined(separator: " ")
    }
    
    /// Whether this verse has been pushed at least once
    var isPushed: Bool {
        pushCount > 0
    }
    
    /// Formatted display reference
    var displayReference: String {
        reference.formatted
    }
    
    /// Whether this contains multiple verses
    var isMultiVerse: Bool {
        verses.count > 1
    }
    
    /// Get the currently selected verse (for verse-by-verse push)
    var currentVerse: VerseItem? {
        guard currentVerseIndex >= 0 && currentVerseIndex < verses.count else { return nil }
        return verses[currentVerseIndex]
    }
    
    /// Get formatted text for current verse with reference
    var currentVerseFormatted: String {
        guard let verse = currentVerse else { return fullText }
        if isMultiVerse {
            return "\(reference.book) \(reference.chapter):\(verse.verseNumber)\n\(verse.text)"
        } else {
            return "\(displayReference)\n\(verse.text)"
        }
    }
    
    // MARK: - Initialisers
    
    /// New initialiser with individual verses
    init(
        reference: ScriptureReference,
        verses: [VerseItem],
        translation: String,
        timestamp: Date,
        confidence: Float,
        rawTranscript: String = ""
    ) {
        self.reference = reference
        self.verses = verses
        self.translation = translation
        self.timestamp = timestamp
        self.confidence = confidence
        self.rawTranscript = rawTranscript
    }
    
    /// Legacy initialiser with combined text (creates single verse)
    init(
        reference: ScriptureReference,
        fullText: String,
        translation: String,
        timestamp: Date,
        confidence: Float,
        rawTranscript: String = ""
    ) {
        self.reference = reference
        self.verses = [VerseItem(verseNumber: reference.verseStart, text: fullText)]
        self.translation = translation
        self.timestamp = timestamp
        self.confidence = confidence
        self.rawTranscript = rawTranscript
    }
    
    static func == (lhs: PendingVerse, rhs: PendingVerse) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Buffer Manager

/// Manages the queue of pending scripture verses awaiting operator action
@MainActor
class BufferManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var pendingVerses: [PendingVerse] = []
    @Published var history: [PendingVerse] = []
    
    // MARK: - Configuration
    
    private let maxPendingCount = 10
    private let maxHistoryCount = 50
    
    // MARK: - Publishers
    
    /// Publishes when a new verse is added
    let verseAddedPublisher = PassthroughSubject<PendingVerse, Never>()
    
    /// Publishes when the current verse changes
    let currentVersePublisher = PassthroughSubject<PendingVerse?, Never>()
    
    // MARK: - Computed Properties
    
    /// The current (first) pending verse
    var currentVerse: PendingVerse? {
        pendingVerses.first
    }
    
    /// Whether there are any pending verses
    var hasPendingVerses: Bool {
        !pendingVerses.isEmpty
    }
    
    /// Number of pending verses
    var pendingCount: Int {
        pendingVerses.count
    }
    
    // MARK: - Buffer Operations
    
    /// Add a new pending verse to the buffer
    func add(_ verse: PendingVerse) {
        // Check if this reference is already pending
        if pendingVerses.contains(where: { $0.reference == verse.reference }) {
            return // Ignore duplicate
        }
        
        // Add to pending queue
        pendingVerses.append(verse)
        
        // Trim if exceeding max
        if pendingVerses.count > maxPendingCount {
            pendingVerses.removeFirst()
        }
        
        verseAddedPublisher.send(verse)
        currentVersePublisher.send(currentVerse)
        
        print("[Buffer] Added: \(verse.displayReference)")
    }
    
    /// Remove and return the current verse (after push or ignore)
    @discardableResult
    func removeCurrent() -> PendingVerse? {
        guard !pendingVerses.isEmpty else { return nil }
        
        let removed = pendingVerses.removeFirst()
        history.insert(removed, at: 0)
        
        // Trim history
        if history.count > maxHistoryCount {
            history.removeLast()
        }
        
        currentVersePublisher.send(currentVerse)
        
        return removed
    }
    
    /// Clear the current pending verse without adding to history
    func ignoreCurrent() {
        guard !pendingVerses.isEmpty else { return }
        pendingVerses.removeFirst()
        currentVersePublisher.send(currentVerse)
    }
    
    /// Clear all pending verses
    func clearAll() {
        pendingVerses.removeAll()
        currentVersePublisher.send(nil)
    }
    
    /// Clear history
    func clearHistory() {
        history.removeAll()
    }
    
    /// Mark a verse as pushed (keeps it in list but changes appearance)
    func markAsPushed(id: UUID) {
        if let index = pendingVerses.firstIndex(where: { $0.id == id }) {
            pendingVerses[index].pushCount += 1
            pendingVerses[index].lastPushedAt = Date()
            print("[Buffer] Marked as pushed: \(pendingVerses[index].displayReference) (push count: \(pendingVerses[index].pushCount))")
        }
    }
    
    /// Remove a specific verse by ID (explicit delete)
    @discardableResult
    func remove(id: UUID) -> PendingVerse? {
        if let index = pendingVerses.firstIndex(where: { $0.id == id }) {
            let removed = pendingVerses.remove(at: index)
            history.insert(removed, at: 0)
            
            // Trim history
            if history.count > maxHistoryCount {
                history.removeLast()
            }
            
            currentVersePublisher.send(currentVerse)
            print("[Buffer] Removed: \(removed.displayReference)")
            return removed
        }
        return nil
    }
    
    /// Get a verse by ID
    func getVerse(id: UUID) -> PendingVerse? {
        pendingVerses.first(where: { $0.id == id })
    }
    
    // MARK: - Verse Navigation (for multi-verse references)
    
    /// Move to next verse within a multi-verse reference
    func nextVerse(id: UUID) -> Bool {
        guard let index = pendingVerses.firstIndex(where: { $0.id == id }) else { return false }
        let verse = pendingVerses[index]
        
        if verse.currentVerseIndex < verse.verses.count - 1 {
            pendingVerses[index].currentVerseIndex += 1
            print("[Buffer] Advanced to verse \(pendingVerses[index].currentVerseIndex + 1) of \(verse.verses.count)")
            return true
        }
        return false
    }
    
    /// Move to previous verse within a multi-verse reference
    func previousVerse(id: UUID) -> Bool {
        guard let index = pendingVerses.firstIndex(where: { $0.id == id }) else { return false }
        
        if pendingVerses[index].currentVerseIndex > 0 {
            pendingVerses[index].currentVerseIndex -= 1
            print("[Buffer] Moved back to verse \(pendingVerses[index].currentVerseIndex + 1)")
            return true
        }
        return false
    }
    
    /// Set current verse index directly
    func setCurrentVerse(id: UUID, index: Int) {
        guard let verseIndex = pendingVerses.firstIndex(where: { $0.id == id }) else { return }
        let verse = pendingVerses[verseIndex]
        
        if index >= 0 && index < verse.verses.count {
            pendingVerses[verseIndex].currentVerseIndex = index
        }
    }
}
