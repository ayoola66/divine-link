# Story 3.1: Pending Buffer Data Model

**Epic:** 3 - Pending Buffer & ProPresenter Integration  
**Story ID:** 3.1  
**Status:** Not Started  
**Complexity:** Small  

---

## User Story

**As a** developer,  
**I want** a buffer manager that holds pending scripture detections,  
**so that** the UI can display and the operator can act on them.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | `BufferManager` class created as ObservableObject | Class compiles and publishes changes |
| 2 | Manages queue of PendingVerse objects | Queue operations work correctly |
| 3 | Supports add, remove, clear operations | All operations functional |
| 4 | Exposes current pending verse (first in queue) for UI | `currentVerse` returns first item |
| 5 | Limits queue size (max 10 pending verses) | 11th verse replaces oldest |
| 6 | Older verses auto-expire after 60 seconds | Expired verses removed automatically |
| 7 | Publishes changes for SwiftUI binding | UI updates on changes |

---

## Technical Notes

### BufferManager Implementation

```swift
import Foundation
import Combine

class BufferManager: ObservableObject {
    @Published private(set) var pendingVerses: [PendingVerse] = []
    
    private let maxBufferSize = 10
    private let expirationInterval: TimeInterval = 60.0 // seconds
    private var expirationTimer: Timer?
    
    var currentVerse: PendingVerse? {
        pendingVerses.first
    }
    
    var hasePendingVerses: Bool {
        !pendingVerses.isEmpty
    }
    
    var count: Int {
        pendingVerses.count
    }
    
    init() {
        startExpirationTimer()
    }
    
    deinit {
        expirationTimer?.invalidate()
    }
    
    // MARK: - Queue Operations
    
    func add(_ verse: PendingVerse) {
        // Remove oldest if at capacity
        if pendingVerses.count >= maxBufferSize {
            pendingVerses.removeFirst()
        }
        
        pendingVerses.append(verse)
    }
    
    func removeFirst() -> PendingVerse? {
        guard !pendingVerses.isEmpty else { return nil }
        return pendingVerses.removeFirst()
    }
    
    func remove(_ verse: PendingVerse) {
        pendingVerses.removeAll { $0.id == verse.id }
    }
    
    func clear() {
        pendingVerses.removeAll()
    }
    
    // MARK: - Current Verse Actions
    
    func approveCurrentVerse() -> PendingVerse? {
        return removeFirst()
    }
    
    func dismissCurrentVerse() {
        _ = removeFirst()
    }
    
    // MARK: - Expiration
    
    private func startExpirationTimer() {
        expirationTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.removeExpiredVerses()
        }
    }
    
    private func removeExpiredVerses() {
        let now = Date()
        pendingVerses.removeAll { verse in
            now.timeIntervalSince(verse.timestamp) > expirationInterval
        }
    }
}
```

### PendingVerse Model (Complete)

```swift
struct PendingVerse: Identifiable, Equatable {
    let id: UUID
    let reference: ScriptureReference
    let fullText: String
    let translation: String
    let timestamp: Date
    let confidence: Float
    
    init(
        id: UUID = UUID(),
        reference: ScriptureReference,
        fullText: String,
        translation: String = "Berean Standard Bible",
        timestamp: Date = Date(),
        confidence: Float = 0.9
    ) {
        self.id = id
        self.reference = reference
        self.fullText = fullText
        self.translation = translation
        self.timestamp = timestamp
        self.confidence = confidence
    }
    
    var displayReference: String {
        reference.displayReference
    }
    
    var book: String {
        reference.book
    }
    
    var chapter: Int {
        reference.chapter
    }
    
    var verseDisplay: String {
        if let end = reference.verseEnd, end != reference.verseStart {
            return "\(reference.verseStart)-\(end)"
        }
        return "\(reference.verseStart)"
    }
    
    static func == (lhs: PendingVerse, rhs: PendingVerse) -> Bool {
        lhs.id == rhs.id
    }
}
```

### Usage in Views

```swift
struct PendingBufferView: View {
    @EnvironmentObject var bufferManager: BufferManager
    
    var body: some View {
        if let verse = bufferManager.currentVerse {
            PendingScriptureCard(verse: verse)
        } else {
            EmptyBufferView()
        }
    }
}
```

---

## Dependencies

- Story 2.6 (Detection Pipeline) - for PendingVerse model

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] Queue operations tested
- [ ] Expiration timer works
- [ ] SwiftUI updates on changes
- [ ] Unit tests for buffer operations
- [ ] Committed to Git
