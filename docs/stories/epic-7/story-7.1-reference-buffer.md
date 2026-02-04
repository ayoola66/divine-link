# Story 7.1: Reference Buffer (Stateful Detection)

**Epic:** 7 - Advanced Detection & Personalisation  
**Story ID:** 7.1  
**Status:** Not Started  
**Complexity:** Medium  
**Priority:** P0 (Key Differentiator)

---

## User Story

**As an** operator during a sermon,  
**I want** the app to remember the current book/chapter context,  
**so that** when the pastor says "verse 18" after "John 3:16", it correctly detects John 3:18.

---

## Background

**The Problem:**
Pastors frequently reference verses in shorthand:
- "John 3:16" ... (minutes later) ... "Now look at verse 18"
- "In Romans chapter 8" ... "verse 28" ... "and then verse 31"
- "Psalm 23" ... "verse 4" ... "verse 6"

Currently, "verse 18" alone won't be detected because there's no context.

**The Solution:**
Implement a "Reference Buffer" that remembers the most recent book and chapter, enabling stateful detection.

**Professor BMAD:**
> "The app should be smart enough to know 'verse 18' refers back to 'John 3.' This is what we call Stateful Detection, and it would put you miles ahead of any competitor."

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Explicit reference updates the context buffer | "John 3:16" sets buffer to John 3 |
| 2 | "Verse X" alone resolves using buffer | After "John 3:16", "verse 18" → John 3:18 |
| 3 | "Chapter X verse Y" uses buffered book | After "Romans", "chapter 8 verse 28" → Romans 8:28 |
| 4 | Buffer times out after inactivity | 10-minute timeout clears context |
| 5 | Buffer resets on new explicit reference | "Matthew 5:1" clears John context |
| 6 | UI shows current context | "Context: John 3" visible to operator |
| 7 | Manual context override available | Operator can set/clear context |
| 8 | Context-resolved verses flagged in UI | Visual indicator for "inferred from context" |

---

## Technical Notes

### Reference Buffer Model

```swift
// ReferenceBuffer.swift
class ReferenceBuffer: ObservableObject {
    @Published var currentBook: String?
    @Published var currentChapter: Int?
    @Published var lastUpdateTime: Date?
    
    private let timeoutInterval: TimeInterval = 600 // 10 minutes
    private var timeoutTimer: Timer?
    
    var isActive: Bool {
        guard let lastUpdate = lastUpdateTime else { return false }
        return Date().timeIntervalSince(lastUpdate) < timeoutInterval
    }
    
    var contextDescription: String? {
        guard isActive, let book = currentBook else { return nil }
        if let chapter = currentChapter {
            return "\(book) \(chapter)"
        }
        return book
    }
    
    // MARK: - Update Context
    
    func updateContext(book: String, chapter: Int?) {
        currentBook = book
        currentChapter = chapter
        lastUpdateTime = Date()
        resetTimeout()
    }
    
    func updateChapter(_ chapter: Int) {
        guard currentBook != nil else { return }
        currentChapter = chapter
        lastUpdateTime = Date()
        resetTimeout()
    }
    
    // MARK: - Clear Context
    
    func clear() {
        currentBook = nil
        currentChapter = nil
        lastUpdateTime = nil
        timeoutTimer?.invalidate()
    }
    
    // MARK: - Resolve Partial Reference
    
    func resolve(verse: Int) -> ScriptureReference? {
        guard isActive,
              let book = currentBook,
              let chapter = currentChapter else {
            return nil
        }
        
        return ScriptureReference(book: book, chapter: chapter, verse: verse)
    }
    
    func resolve(chapter: Int, verse: Int) -> ScriptureReference? {
        guard isActive, let book = currentBook else {
            return nil
        }
        
        // Update chapter context for future references
        updateChapter(chapter)
        
        return ScriptureReference(book: book, chapter: chapter, verse: verse)
    }
    
    // MARK: - Timeout
    
    private func resetTimeout() {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeoutInterval, repeats: false) { [weak self] _ in
            self?.clear()
        }
    }
}

struct ScriptureReference {
    let book: String
    let chapter: Int
    let verse: Int
    var endVerse: Int?
    
    var formatted: String {
        if let end = endVerse {
            return "\(book) \(chapter):\(verse)-\(end)"
        }
        return "\(book) \(chapter):\(verse)"
    }
}
```

### Detection Engine Update

```swift
// ScriptureDetectionEngine.swift (updated)
class ScriptureDetectionEngine: ObservableObject {
    @Published var referenceBuffer = ReferenceBuffer()
    
    // Partial reference patterns (no book specified)
    let partialPatterns = [
        // "verse 18" or "verses 18 through 20"
        "verse[s]?\\s+(\\d+)(?:\\s*(?:through|to|-)\\s*(\\d+))?",
        // "chapter 8 verse 28"
        "chapter\\s+(\\d+)\\s+verse[s]?\\s+(\\d+)",
        // "v. 18" or "v18"
        "v\\.?\\s*(\\d+)"
    ]
    
    func detectReferences(in text: String) -> [ScriptureMatch] {
        var matches: [ScriptureMatch] = []
        
        // 1. Try explicit references first (existing logic)
        let explicitMatches = detectExplicitReferences(in: text)
        
        // Update context buffer with any explicit matches
        for match in explicitMatches {
            referenceBuffer.updateContext(book: match.book, chapter: match.chapter)
        }
        
        matches.append(contentsOf: explicitMatches)
        
        // 2. Try partial references using context buffer
        if referenceBuffer.isActive {
            let partialMatches = detectPartialReferences(in: text)
            matches.append(contentsOf: partialMatches)
        }
        
        return matches
    }
    
    private func detectPartialReferences(in text: String) -> [ScriptureMatch] {
        var matches: [ScriptureMatch] = []
        
        // Pattern: "verse X" or "verse X through Y"
        let versePattern = try! NSRegularExpression(
            pattern: "\\bverse[s]?\\s+(\\d+)(?:\\s*(?:through|to|-)\\s*(\\d+))?\\b",
            options: .caseInsensitive
        )
        
        let range = NSRange(text.startIndex..., in: text)
        let verseMatches = versePattern.matches(in: text, range: range)
        
        for match in verseMatches {
            if let verseRange = Range(match.range(at: 1), in: text),
               let verse = Int(text[verseRange]),
               let resolved = referenceBuffer.resolve(verse: verse) {
                
                var endVerse: Int? = nil
                if match.numberOfRanges > 2,
                   let endRange = Range(match.range(at: 2), in: text) {
                    endVerse = Int(text[endRange])
                }
                
                // Create match with context source flag
                let scriptureMatch = ScriptureMatch(
                    book: resolved.book,
                    chapter: resolved.chapter,
                    verse: resolved.verse,
                    endVerse: endVerse,
                    verseText: fetchVerseText(resolved),
                    rawTranscript: String(text[Range(match.range, in: text)!]),
                    matchedPattern: "partial_verse",
                    confidence: buildContextConfidence(),
                    timestamp: Date(),
                    sourceType: .contextInferred  // NEW: Flag as context-inferred
                )
                
                matches.append(scriptureMatch)
            }
        }
        
        return matches
    }
    
    private func buildContextConfidence() -> DetectionConfidence {
        // Context-inferred matches have slightly lower confidence
        return DetectionConfidence(
            referenceClarity: 0.7,  // Partial reference
            speechConfidence: 0.9,  // ASR still confident
            contextMatch: 0.8,      // Context helps
            verseExistence: 1.0     // Verse verified
        )
    }
}

// Add source type to ScriptureMatch
enum MatchSourceType {
    case explicit       // Full reference spoken
    case contextInferred // Resolved via buffer
    case implicit       // AI-detected (Story 7.2)
}
```

### UI: Context Indicator

```swift
// ContextIndicatorView.swift
struct ContextIndicatorView: View {
    @ObservedObject var buffer: ReferenceBuffer
    
    var body: some View {
        if buffer.isActive, let context = buffer.contextDescription {
            HStack(spacing: 6) {
                Image(systemName: "text.quote")
                    .foregroundColor(.blue)
                
                Text("Context: \(context)")
                    .font(.caption)
                    .foregroundColor(.primary)
                
                // Time remaining indicator
                if let lastUpdate = buffer.lastUpdateTime {
                    TimeRemainingBadge(since: lastUpdate, timeout: 600)
                }
                
                // Manual clear button
                Button(action: { buffer.clear() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct TimeRemainingBadge: View {
    let since: Date
    let timeout: TimeInterval
    @State private var remaining: TimeInterval = 0
    
    var body: some View {
        Text(formatRemaining())
            .font(.caption2)
            .foregroundColor(.secondary)
            .onAppear { startTimer() }
    }
    
    func formatRemaining() -> String {
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(since)
            remaining = max(0, timeout - elapsed)
        }
    }
}
```

### UI: Context-Inferred Badge

```swift
// In ScriptureCardView.swift
struct ScriptureCardView: View {
    let match: ScriptureMatch
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(match.reference)
                    .font(.headline)
                
                // Source type badge
                if match.sourceType == .contextInferred {
                    ContextInferredBadge()
                }
                
                Spacer()
                
                ConfidenceIndicatorView(confidence: match.confidence)
            }
            
            // ... rest of card
        }
    }
}

struct ContextInferredBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.turn.down.right")
            Text("from context")
        }
        .font(.caption2)
        .foregroundColor(.blue)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(4)
    }
}
```

---

## Detection Examples

| Pastor Says | Context Buffer | Detected |
|-------------|----------------|----------|
| "John 3:16" | → John 3 | John 3:16 ✅ |
| "verse 18" | John 3 | John 3:18 ✅ |
| "verses 18 through 21" | John 3 | John 3:18-21 ✅ |
| "chapter 4 verse 1" | John | John 4:1 ✅ |
| "Matthew 5:1" | → Matthew 5 | Matthew 5:1 ✅ (context reset) |
| "verse 5" | Matthew 5 | Matthew 5:5 ✅ |
| (10 min silence) | (cleared) | — |
| "verse 10" | (no context) | ❌ Not detected |

---

## Settings

```swift
// Settings: Detection tab
Section("Context Buffer") {
    Toggle("Enable stateful detection", isOn: $enableContextBuffer)
    
    if enableContextBuffer {
        Stepper("Timeout: \(contextTimeout) min", value: $contextTimeout, in: 5...30)
        
        Toggle("Show context indicator", isOn: $showContextIndicator)
        
        Toggle("Flag context-inferred verses", isOn: $flagContextInferred)
    }
}
```

---

## Dependencies

- Story 2.5 (Scripture Detection Engine) ✅ Complete
- Story 6.2 (Confidence Indicator) - For consistent styling

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] ReferenceBuffer class implemented
- [ ] Detection engine updated for partial references
- [ ] Context indicator visible in UI
- [ ] Context-inferred badge on cards
- [ ] Timeout works correctly (10 min default)
- [ ] Manual clear works
- [ ] Settings for timeout adjustment
- [ ] Unit tests for buffer logic
- [ ] Edge cases tested (rapid context changes)
- [ ] Committed to Git

---

## Testing Scenarios

1. **Basic Context**: "John 3:16" then "verse 18" → Both detected
2. **Cross-Chapter**: "John 3:16" then "chapter 4 verse 1" → John 4:1
3. **Context Reset**: "John 3:16" then "Matthew 5:1" → Matthew context now
4. **Timeout**: Wait 10 min → Context cleared
5. **Manual Clear**: Click X on context indicator → Cleared
6. **No Context**: "verse 18" with no prior reference → Not detected
7. **Verse Range**: "verses 5 through 10" → Range detected with context

---

## Estimated Effort

| Task | Hours |
|------|-------|
| ReferenceBuffer implementation | 3 |
| Detection engine updates | 4 |
| Context indicator UI | 2 |
| Settings integration | 1 |
| Testing & edge cases | 2 |
| **Total** | **12** |
