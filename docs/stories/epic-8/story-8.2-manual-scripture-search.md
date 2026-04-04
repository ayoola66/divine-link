# Story 8.2: Manual Scripture Search

**Story ID:** 8.2
**Epic:** 8 - UX/UI Modernization & Platform Expansion
**Priority:** P0 (Critical - Must-Have)
**Complexity:** Medium
**Estimated Effort:** 10-16 hours
**Phase:** Phase 2 (Week 2)
**Target Version:** v2.0.0

---

## Story Description

Add a manual scripture search feature that allows operators to proactively look up Bible verses by reference (e.g., "John 3:16") or by phrase (e.g., "love your neighbor"), enabling pre-sermon preparation and mid-sermon corrections.

---

## User Story

**As a** church media operator
**I want** to search for specific Bible verses manually
**So that** I can prep verses before the sermon or correct misdetected verses during the service

---

## Business Value

- **Critical Gap:** QuickVerse has this; Divine Link doesn't = clear disadvantage
- **Workflow Efficiency:** Enables pre-sermon prep, mid-sermon corrections
- **Market Expectation:** Table stakes for any Bible software
- **User Satisfaction:** Most requested feature from operators

**Impact Score:** 4/5 (High - Critical missing capability)

---

## Acceptance Criteria

### Modal/Sheet UI
- [ ] Clicking FAB (blue circle, bottom-right) opens search modal
- [ ] Modal slides in from right side (400px wide × full height)
- [ ] Modal has white background with left shadow for depth
- [ ] Close button (X icon) in top-right corner
- [ ] Modal closes on ESC key or close button click

### Search Bar
- [ ] Search input field at top (48px height)
- [ ] Placeholder text: "John 3:16 or 'love your neighbor'"
- [ ] Magnifying glass icon on left side
- [ ] Auto-focus on modal open
- [ ] Real-time search as user types (debounced 300ms)

### Bible Version Selector
- [ ] Segmented control below search bar: KJV | ASV | WEB
- [ ] Selected version has gold background (#D4AF37), white text
- [ ] Selection persists across searches

### Search Results
- [ ] Results appear as scrollable list below selector
- [ ] Each result is a compact card (120px height)
  - Reference header (14pt, Bold): "John 3:16"
  - Verse preview (13pt, 2 lines, ellipsis): "For God so loved..."
  - "Send" button (small, gold) on right
- [ ] 1px divider between results (#F3F4F6)
- [ ] Empty state: "No verses found" with search icon
- [ ] Loading state: Spinner with "Searching..." text

### Search Functionality
- [ ] **By Reference:** "John 3:16", "Romans 8:28", "1 Corinthians 13"
- [ ] **By Phrase:** "love your neighbor", "God so loved"
- [ ] **Fuzzy Matching:** "john three sixteen" → John 3:16
- [ ] **Autocomplete:** Show suggestions as user types
- [ ] **Case Insensitive:** "JOHN 3:16" = "john 3:16"

### Quick Actions (Bottom, Fixed)
- [ ] "Copy" button (40px height) - Copies selected verse to clipboard
- [ ] "Send to ProPresenter" button (40px height, gold) - Pushes verse immediately
- [ ] 8px gap between buttons
- [ ] Only enabled when a verse is selected

---

## Technical Specifications

### Component Structure
```swift
ManualSearchView (Sheet/Modal)
├── Header
│   ├── Title ("Search Scripture")
│   └── CloseButton
├── SearchBar
│   ├── MagnifyingGlassIcon
│   └── TextField (with debounce)
├── BibleVersionSelector (Segmented Control)
├── ScrollView {
│   └── SearchResultsList
│       └── ForEach(results) { result in
│           SearchResultCard(result)
│       }
}
└── QuickActionsBar (Fixed Bottom)
    ├── CopyButton
    └── SendToProPresenterButton
```

### Search Service
```swift
class ScriptureSearchService {
    func search(query: String, translation: BibleTranslation) async -> [ScriptureResult] {
        // 1. Check if query is a reference (regex patterns)
        // 2. If reference, fetch exact verse
        // 3. If phrase, full-text search across all verses
        // 4. Return ranked results (relevance score)
    }

    func autocomplete(query: String) async -> [String] {
        // Suggest completions for partial queries
        // e.g., "John 3" → ["John 3:1", "John 3:16", "John 3:17"]
    }
}
```

### Search Patterns
```swift
// Reference Patterns (Regex)
let patterns = [
    "\\b([1-3]?\\s?[A-Z][a-z]+)\\s+(\\d+):(\\d+)(?:-(\\d+))?\\b", // John 3:16-17
    "\\b([1-3]?\\s?[A-Z][a-z]+)\\s+(\\d+)\\b", // John 3 (entire chapter)
    "\\b([1-3]?\\s?[A-Z][a-z]+)\\b" // John (book search)
]
```

---

## Dependencies

### Before This Story
- Story 8.1: Modern UI Redesign (provides FAB button and modal framework)

### After This Story
- Story 8.3: Service Session Management (can save searched verses to sessions)

### External Dependencies
- Existing `BibleDatabase` service (KJV, ASV, WEB)
- SwiftUI Sheet presentation

---

## Testing Requirements

### Functional Testing
- [ ] Reference search: "John 3:16" returns correct verse
- [ ] Phrase search: "love your neighbor" returns relevant verses
- [ ] Fuzzy matching: "john three sixteen" works
- [ ] Bible version switching updates results
- [ ] Copy button copies to clipboard correctly
- [ ] Send button pushes to ProPresenter successfully
- [ ] Modal closes properly (X button, ESC key)

### Edge Cases
- [ ] Invalid references: "John 999:999" shows "No verses found"
- [ ] Empty query: Shows placeholder state
- [ ] Special characters: Handle quotes, apostrophes correctly
- [ ] Long verses: Truncate with ellipsis in preview

### Performance Testing
- [ ] Search completes in < 500ms for phrase queries
- [ ] Debounce prevents excessive queries (300ms delay)
- [ ] Scrolling 100+ results is smooth (60 FPS)

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] Search by reference works accurately
- [ ] Search by phrase returns relevant results
- [ ] All 3 Bible versions supported (KJV, ASV, WEB)
- [ ] Copy and Send buttons functional
- [ ] Modal UI matches design spec
- [ ] Code review completed
- [ ] Testing passed
- [ ] Merged to main

---

## Implementation Notes

### Database Query Optimization
```sql
-- Create full-text search index for phrase queries
CREATE VIRTUAL TABLE verses_fts USING fts5(
    book, chapter, verse, text,
    content=verses
);

-- Fast reference lookup (indexed)
SELECT * FROM verses
WHERE book = 'John' AND chapter = 3 AND verse = 16;

-- Phrase search (full-text)
SELECT * FROM verses_fts
WHERE text MATCH 'love neighbor'
ORDER BY rank
LIMIT 20;
```

### Autocomplete Strategy
- Cache recent searches (last 20)
- Prioritize exact book matches
- Show up to 5 suggestions
- Update as user types (debounced)

---

## Related Documents

- [Epic 8 README](./README.md)
- [Story 8.1 - Modern UI Redesign](./story-8.1-modern-ui-redesign.md)
- [Technical Specification](../../epic-8-technical-specification.md)

---

**Story Owner:** coachAOG
**Created:** February 18, 2026
**Status:** 📋 Ready for Implementation
**Blocked By:** Story 8.1
**Blocks:** None
