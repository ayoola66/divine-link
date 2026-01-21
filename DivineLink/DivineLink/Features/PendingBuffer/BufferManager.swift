import Foundation
import Combine

// MARK: - Pending Verse Model

/// Represents a detected scripture verse pending operator approval
struct PendingVerse: Identifiable, Equatable {
    let id = UUID()
    let reference: ScriptureReference
    let fullText: String
    let translation: String
    let timestamp: Date
    let confidence: Float
    let rawTranscript: String  // What was actually heard (for learning)
    
    /// Formatted display reference
    var displayReference: String {
        reference.formatted
    }
    
    init(
        reference: ScriptureReference,
        fullText: String,
        translation: String,
        timestamp: Date,
        confidence: Float,
        rawTranscript: String = ""
    ) {
        self.reference = reference
        self.fullText = fullText
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
}
