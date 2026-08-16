import Foundation
import Combine

// MARK: - Reference Context

/// Stores the context of a previous scripture detection for resolving partial references
struct ReferenceContext {
    let book: String
    let chapter: Int
    let verseStart: Int?
    let verseEnd: Int?
    let timestamp: Date
    
    /// Check if this context is still valid (not expired)
    func isValid(timeout: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) < timeout
    }
    
    /// The last verse number referenced (end of range, or single verse)
    var lastVerse: Int? {
        verseEnd ?? verseStart
    }
    
    /// Calculate the next verse after this context
    var nextVerse: Int? {
        guard let last = lastVerse else { return nil }
        return last + 1
    }
}

// MARK: - Reference Buffer

/// Manages stateful context for scripture detection
/// Enables resolution of partial references like "verse 18" → "John 3:18"
/// when "John 3:16" was recently detected
@MainActor
class ReferenceBuffer: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The current active context (book/chapter)
    @Published private(set) var currentContext: ReferenceContext?
    
    /// Whether the buffer has active context
    var hasContext: Bool {
        guard let context = currentContext else { return false }
        return context.isValid(timeout: contextTimeout)
    }
    
    // MARK: - Configuration
    
    /// How long context remains valid (default: 5 minutes)
    var contextTimeout: TimeInterval {
        get { UserDefaults.standard.double(forKey: "ReferenceBufferTimeout").nonZeroOr(300) }
        set { UserDefaults.standard.set(newValue, forKey: "ReferenceBufferTimeout") }
    }
    
    /// Whether the reference buffer is enabled
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "ReferenceBufferEnabled", defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: "ReferenceBufferEnabled") }
    }
    
    // MARK: - Singleton
    
    static let shared = ReferenceBuffer()
    
    /// Internal rather than private so tests can hold their own buffer and inject it into
    /// `ScriptureDetectorService`, instead of mutating the process-wide singleton and
    /// leaking state between test cases. Production code should use `.shared`.
    init() {
        // Start cleanup timer
        startCleanupTimer()
    }
    
    // MARK: - Context Management
    
    /// Update the context with a new scripture detection
    /// - Parameters:
    ///   - book: The canonical book name (e.g., "John")
    ///   - chapter: The chapter number
    ///   - verseStart: Optional start verse
    ///   - verseEnd: Optional end verse (for ranges)
    func updateContext(book: String, chapter: Int, verseStart: Int? = nil, verseEnd: Int? = nil) {
        guard isEnabled else { return }
        
        let newContext = ReferenceContext(
            book: book,
            chapter: chapter,
            verseStart: verseStart,
            verseEnd: verseEnd,
            timestamp: Date()
        )
        
        currentContext = newContext
        let verseInfo = verseStart.map { v in 
            verseEnd.map { ":\(v)-\($0)" } ?? ":\(v)"
        } ?? ""
        print("📚 [ReferenceBuffer] Context updated: \(book) \(chapter)\(verseInfo)")
    }
    
    // Note: an `updateContext(from: DetectionResult)` overload was removed. It had no
    // callers and offered an unvalidated back door around
    // `ScriptureDetectorService.cacheContext(for:)`, which is the single entry point that
    // checks the reference actually exists before it becomes the context that later
    // partial references resolve against.
    
    /// Clear the current context
    func clearContext() {
        currentContext = nil
        print("📚 [ReferenceBuffer] Context cleared")
    }
    
    /// Get the current valid context, or nil if expired
    func getValidContext() -> ReferenceContext? {
        guard let context = currentContext, context.isValid(timeout: contextTimeout) else {
            return nil
        }
        return context
    }
    
    // MARK: - Partial Reference Resolution
    
    /// Attempt to resolve a partial verse reference using current context
    /// - Parameters:
    ///   - verseStart: The start verse number
    ///   - verseEnd: Optional end verse for ranges
    /// - Returns: A complete ScriptureReference if context exists, nil otherwise
    func resolvePartialReference(verseStart: Int, verseEnd: Int? = nil) -> ScriptureReference? {
        guard let context = getValidContext() else {
            print("📚 [ReferenceBuffer] Cannot resolve partial reference - no valid context")
            return nil
        }
        
        let reference = ScriptureReference(
            book: context.book,
            chapter: context.chapter,
            verseStart: verseStart,
            verseEnd: verseEnd,
            verseWasSpoken: true  // The verse is the only thing the speaker did say.
        )
        
        print("📚 [ReferenceBuffer] Resolved partial reference: verse \(verseStart)\(verseEnd.map { "-\($0)" } ?? "") → \(reference.formatted)")
        
        return reference
    }
    
    /// Attempt to resolve a "next verse" or "following verse" reference
    /// - Returns: A complete ScriptureReference for the next verse if context exists with verse info, nil otherwise
    func resolveNextVerseReference() -> ScriptureReference? {
        guard let context = getValidContext() else {
            print("📚 [ReferenceBuffer] Cannot resolve next verse - no valid context")
            return nil
        }
        
        guard let nextVerse = context.nextVerse else {
            print("📚 [ReferenceBuffer] Cannot resolve next verse - no verse in context")
            return nil
        }
        
        let reference = ScriptureReference(
            book: context.book,
            chapter: context.chapter,
            verseStart: nextVerse,
            verseEnd: nil,
            verseWasSpoken: true  // Derived from a stated verse, so equally explicit.
        )
        
        print("📚 [ReferenceBuffer] Resolved next verse: \(context.lastVerse ?? 0) → \(nextVerse) = \(reference.formatted)")
        
        return reference
    }
    
    /// Attempt to resolve a "previous verse" reference
    /// - Returns: A complete ScriptureReference for the previous verse if context exists with verse info, nil otherwise
    func resolvePreviousVerseReference() -> ScriptureReference? {
        guard let context = getValidContext() else {
            print("📚 [ReferenceBuffer] Cannot resolve previous verse - no valid context")
            return nil
        }
        
        guard let currentVerse = context.verseStart, currentVerse > 1 else {
            print("📚 [ReferenceBuffer] Cannot resolve previous verse - no valid verse or already at verse 1")
            return nil
        }
        
        let previousVerse = currentVerse - 1
        
        let reference = ScriptureReference(
            book: context.book,
            chapter: context.chapter,
            verseStart: previousVerse,
            verseEnd: nil,
            verseWasSpoken: true  // Derived from a stated verse, so equally explicit.
        )
        
        print("📚 [ReferenceBuffer] Resolved previous verse: \(currentVerse) → \(previousVerse) = \(reference.formatted)")
        
        return reference
    }
    
    /// Attempt to resolve a chapter-only reference using current context for book
    /// - Parameter chapter: The chapter number
    /// - Returns: A complete ScriptureReference if context exists, nil otherwise
    func resolveChapterOnlyReference(chapter: Int, verseStart: Int = 1, verseEnd: Int? = nil) -> ScriptureReference? {
        guard let context = getValidContext() else {
            print("📚 [ReferenceBuffer] Cannot resolve chapter reference - no valid context")
            return nil
        }
        
        // Use the book from context, but the new chapter
        let reference = ScriptureReference(
            book: context.book,
            chapter: chapter,
            verseStart: verseStart,
            verseEnd: verseEnd
        )
        
        print("📚 [ReferenceBuffer] Resolved chapter reference: chapter \(chapter) → \(reference.formatted)")
        
        return reference
    }
    
    // MARK: - Cleanup
    
    private var cleanupTimer: Timer?
    
    private func startCleanupTimer() {
        // Check every minute if context should be cleared
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.cleanupExpiredContext()
            }
        }
    }
    
    private func cleanupExpiredContext() {
        guard let context = currentContext else { return }
        
        if !context.isValid(timeout: contextTimeout) {
            print("📚 [ReferenceBuffer] Context expired, clearing...")
            currentContext = nil
        }
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
}

// MARK: - UserDefaults Extension

private extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return bool(forKey: key)
    }
}

private extension Double {
    func nonZeroOr(_ defaultValue: Double) -> Double {
        self == 0 ? defaultValue : self
    }
}
