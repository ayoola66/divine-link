# Story 2.5: Scripture Reference Detection Engine

**Epic:** 2 - Transcription & Scripture Detection  
**Story ID:** 2.5  
**Status:** Not Started  
**Complexity:** Medium  

---

## User Story

**As a** developer,  
**I want** a service that detects scripture references in transcript text,  
**so that** detected verses can be queued for operator approval.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | `ScriptureDetectorService` class created | Class compiles and initialises |
| 2 | Service accepts transcript text and returns detected references | `detect("John 3:16")` returns reference |
| 3 | Detects standard formats: "John 3:16", "Romans 8:28-30" | Unit tests pass |
| 4 | Detects verbal formats: "John chapter 3 verse 16" | Unit tests pass |
| 5 | Detects book-only with chapter: "Romans 8", "Genesis 1" | Unit tests pass |
| 6 | Normalises book names: "Revelations" → "Revelation" | Normalisation works |
| 7 | Handles numbered books: "1 Corinthians", "First John", "I Peter" | All variations detected |
| 8 | Returns structured reference object | ScriptureReference struct returned |
| 9 | Ignores duplicate detections within short time window | Debounce works |

---

## Technical Notes

### ScriptureReference Model

```swift
struct ScriptureReference: Identifiable, Equatable {
    let id = UUID()
    let book: String           // Canonical name: "1 Corinthians"
    let chapter: Int
    let verseStart: Int
    let verseEnd: Int?         // nil for single verse
    let rawMatch: String       // Original text matched
    let confidence: Float      // 0.0 to 1.0
    
    var displayReference: String {
        if let end = verseEnd, end != verseStart {
            return "\(book) \(chapter):\(verseStart)-\(end)"
        } else {
            return "\(book) \(chapter):\(verseStart)"
        }
    }
}
```

### ScriptureDetectorService

```swift
import Foundation

class ScriptureDetectorService {
    private let bookNormaliser = BookNameNormaliser()
    private var recentDetections: [String: Date] = [:]
    private let debounceInterval: TimeInterval = 5.0 // seconds
    
    // Regex patterns
    private let patterns: [(NSRegularExpression, PatternType)] = [
        // Standard: John 3:16 or John 3:16-18
        (try! NSRegularExpression(pattern: #"(\d?\s?[A-Za-z]+)\s+(\d+):(\d+)(?:-(\d+))?"#), .standard),
        
        // Verbal: John chapter 3 verse 16
        (try! NSRegularExpression(pattern: #"(\d?\s?[A-Za-z]+)\s+chapter\s+(\d+)\s+verse\s+(\d+)"#, options: .caseInsensitive), .verbal),
        
        // Chapter only: Romans 8
        (try! NSRegularExpression(pattern: #"(\d?\s?[A-Za-z]+)\s+(\d+)(?:\s|$|,|\.)"#), .chapterOnly),
    ]
    
    func detect(in text: String) -> [ScriptureReference] {
        var results: [ScriptureReference] = []
        
        for (regex, patternType) in patterns {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            
            for match in matches {
                if let reference = parseMatch(match, in: text, type: patternType) {
                    // Check for duplicate (debounce)
                    let key = reference.displayReference
                    if !isDuplicate(key) {
                        results.append(reference)
                        recentDetections[key] = Date()
                    }
                }
            }
        }
        
        return results
    }
    
    private func parseMatch(_ match: NSTextCheckingResult, in text: String, type: PatternType) -> ScriptureReference? {
        guard let bookRange = Range(match.range(at: 1), in: text),
              let chapterRange = Range(match.range(at: 2), in: text) else {
            return nil
        }
        
        let rawBook = String(text[bookRange]).trimmingCharacters(in: .whitespaces)
        guard let canonicalBook = bookNormaliser.normalise(rawBook) else {
            return nil // Not a valid book name
        }
        
        guard let chapter = Int(text[chapterRange]) else { return nil }
        
        var verseStart = 1
        var verseEnd: Int? = nil
        
        if type != .chapterOnly {
            if let verseRange = Range(match.range(at: 3), in: text),
               let verse = Int(text[verseRange]) {
                verseStart = verse
            }
            
            if match.numberOfRanges > 4,
               let endRange = Range(match.range(at: 4), in: text),
               let end = Int(text[endRange]) {
                verseEnd = end
            }
        }
        
        return ScriptureReference(
            book: canonicalBook,
            chapter: chapter,
            verseStart: verseStart,
            verseEnd: verseEnd,
            rawMatch: String(text[Range(match.range, in: text)!]),
            confidence: 0.9
        )
    }
    
    private func isDuplicate(_ key: String) -> Bool {
        guard let lastDetection = recentDetections[key] else { return false }
        return Date().timeIntervalSince(lastDetection) < debounceInterval
    }
}

enum PatternType {
    case standard    // John 3:16
    case verbal      // John chapter 3 verse 16
    case chapterOnly // Romans 8
}
```

### Book Name Normaliser

```swift
class BookNameNormaliser {
    private let canonicalNames: [String: String] = [
        // Direct matches
        "genesis": "Genesis",
        "gen": "Genesis",
        "exodus": "Exodus",
        "ex": "Exodus",
        // ... all books
        
        // Common mistakes
        "revelations": "Revelation",
        
        // Numbered book variations
        "1 corinthians": "1 Corinthians",
        "first corinthians": "1 Corinthians",
        "i corinthians": "1 Corinthians",
        "1st corinthians": "1 Corinthians",
        // ... etc
    ]
    
    func normalise(_ input: String) -> String? {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespaces)
        return canonicalNames[lowercased]
    }
}
```

---

## Dependencies

- Story 2.1 (Bible Database) - for book name validation

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] Unit tests for all pattern types
- [ ] Book normalisation complete (66 books + variations)
- [ ] Debounce prevents duplicates
- [ ] Edge cases handled (invalid refs ignored)
- [ ] Committed to Git
