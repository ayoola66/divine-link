# Story 4.1: Service Session Creation

**Epic:** 4 - Service Sessions & Pastor Profiles  
**Story ID:** 4.1  
**Status:** Not Started  
**Complexity:** Medium  

---

## User Story

**As an** operator,  
**I want** to start a new service session with a name and type,  
**so that** detected scriptures are organised by service for later review.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | "New Service" button/flow available before starting detection | Button visible |
| 2 | Service type field with auto-complete from past types | Typing shows suggestions |
| 3 | Service name auto-generated from type + date (e.g., "Sunday Service - 19 Jan 2026") | Default name appears |
| 4 | Confirm date picker (defaults to today) | Date selectable |
| 5 | Optional pastor selection from saved profiles | Dropdown available |
| 6 | Session starts after confirmation | Detection begins |
| 7 | Current session info shown in header during operation | Session name visible |
| 8 | Session data persisted to local storage | Survives app restart |

---

## Technical Notes

### Service Session Model

```swift
struct ServiceSession: Identifiable, Codable {
    let id: UUID
    var name: String
    var serviceType: String          // "Sunday Service", "Wednesday Bible Study"
    var date: Date
    var pastorId: UUID?              // Optional linked pastor
    var startTime: Date
    var endTime: Date?
    var detectedScriptures: [DetectedScripture]
    var transcriptSegments: [String] // Rolling transcript snippets
    
    var isActive: Bool { endTime == nil }
}

struct DetectedScripture: Identifiable, Codable {
    let id: UUID
    let reference: String            // "John 3:16"
    let verseText: String
    let timestamp: Date
    let wasPushed: Bool              // Did operator push to ProPresenter?
    let rawTranscript: String        // What was actually heard
}
```

### Service Type Cache

```swift
class ServiceTypeCache: ObservableObject {
    @Published var recentTypes: [String] = []
    private let maxCached = 20
    
    func addType(_ type: String) {
        if let index = recentTypes.firstIndex(of: type) {
            recentTypes.remove(at: index)
        }
        recentTypes.insert(type, at: 0)
        if recentTypes.count > maxCached {
            recentTypes.removeLast()
        }
        save()
    }
    
    func suggestions(for query: String) -> [String] {
        if query.isEmpty { return recentTypes }
        return recentTypes.filter { 
            $0.localizedCaseInsensitiveContains(query) 
        }
    }
}
```

### UI Flow

1. Click "New Service" or auto-prompt on first launch
2. Modal/sheet with:
   - Service Type (text field with autocomplete dropdown)
   - Date (date picker, defaults today)
   - Pastor (optional dropdown)
   - Service Name (auto-generated, editable)
3. "Start Service" button begins detection
4. Header shows: "📅 Sunday Service - 19 Jan 2026"

---

## Dependencies

- Epic 2 complete (detection pipeline)

---

## Definition of Done

- [ ] New service flow implemented
- [ ] Service type caching works
- [ ] Session data persists
- [ ] Header shows active session
- [ ] Committed to Git
