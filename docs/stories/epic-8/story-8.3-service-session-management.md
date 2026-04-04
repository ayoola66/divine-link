# Story 8.3: Service Session Management

**Story ID:** 8.3
**Epic:** 8 - UX/UI Modernization & Platform Expansion
**Priority:** P0 (Must-Have)
**Complexity:** Medium
**Estimated Effort:** 12-18 hours
**Phase:** Phase 2 (Week 2)
**Target Version:** v2.0.0

---

## Story Description

Enable operators to organize detected scriptures into service sessions, creating a timeline view of all services with metadata (date, pastor, sermon title), and allowing review and export of historical sermon scripture usage.

---

## User Story

**As a** church media operator or pastor
**I want** to group scriptures by service date and review past services
**So that** I can track sermon scripture usage over time and prepare reports

---

## Business Value

- **Data Organization:** Transforms ephemeral data into historical record
- **Pastor Value:** Pastors can review sermon scripture patterns
- **Retention:** Increases long-term value (more data = stickier product)
- **Competitive Parity:** QuickVerse has session management; Divine Link needs it

**Impact Score:** 4/5 (High value, less urgent than UI/Search)

---

## Acceptance Criteria

### Service Session Model
- [ ] Session has: ID, Date/Time, Pastor Name, Sermon Title, Scripture List
- [ ] Sessions persist to local database (SQLite or Core Data)
- [ ] Sessions auto-create when first scripture detected
- [ ] Sessions auto-save every 30 seconds during active service

### Session Creation Flow
- [ ] "New Service" button in main window (top-left, near logo)
- [ ] Clicking opens modal with form:
  - Service Date (date picker, defaults to today)
  - Service Time (time picker, defaults to current time)
  - Pastor (dropdown, from pastor profiles list)
  - Sermon Title (text input, optional)
- [ ] "Create" button (gold) saves and starts new session
- [ ] "Cancel" button closes modal without creating

### Active Session Indicator
- [ ] Header bar shows current session info when active:
  - "Sunday Morning - Pastor John" (small text below status)
- [ ] Clicking session info opens session details modal

### Session History View
- [ ] Menu item: "View History" or keyboard shortcut ⌘H
- [ ] Opens full-window sheet with timeline view

### Timeline View (Session History)
- [ ] Left sidebar (300px): List of services by date (newest first)
  - Each item: Date, Time, Pastor, Verse Count
  - Selected session: Gold border, white background
  - Unselected: Light gray background
- [ ] Main area (flex): Selected session details
  - Header: Service metadata (Date, Pastor, Title)
  - Scripture grid: 2-column card grid
  - Each card: Reference + verse preview (truncated)
  - Click card to expand full verse
  - Export button: PDF, Markdown, Text (Story 8.4 integration)

### Statistics
- [ ] Per-session stats: Total verses used, Service duration
- [ ] Overall stats (bottom of history): Services this month, Total verses tracked

---

## Technical Specifications

### Data Model
```swift
struct ServiceSession: Codable, Identifiable {
    let id: UUID
    var date: Date
    var pastor: String
    var sermonTitle: String?
    var scriptures: [DetectedScripture]
    var startTime: Date
    var endTime: Date?

    var duration: TimeInterval? {
        guard let endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
}

struct DetectedScripture: Codable, Identifiable {
    let id: UUID
    let reference: String // "John 3:16"
    let verse: String
    let translation: String
    let confidence: Double
    let timestamp: Date
    var wasPushed: Bool // Did operator push to ProPresenter?
}
```

### Session Manager
```swift
class SessionManager: ObservableObject {
    @Published var currentSession: ServiceSession?
    @Published var allSessions: [ServiceSession] = []

    func createSession(date: Date, pastor: String, title: String?) {
        // Create new session, save to DB
    }

    func addScripture(_ scripture: DetectedScripture) {
        // Add to current session, auto-save
    }

    func endSession() {
        // Set endTime, final save
    }

    func loadSessions() async -> [ServiceSession] {
        // Load from local DB, sorted by date descending
    }

    func deleteSession(id: UUID) {
        // Delete from DB (with confirmation)
    }
}
```

### Database Schema (SQLite)
```sql
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,
    date INTEGER NOT NULL, -- Unix timestamp
    pastor TEXT NOT NULL,
    sermon_title TEXT,
    start_time INTEGER NOT NULL,
    end_time INTEGER,
    created_at INTEGER DEFAULT (strftime('%s', 'now'))
);

CREATE TABLE session_scriptures (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    reference TEXT NOT NULL,
    verse TEXT NOT NULL,
    translation TEXT NOT NULL,
    confidence REAL NOT NULL,
    timestamp INTEGER NOT NULL,
    was_pushed INTEGER DEFAULT 0, -- Boolean: 0 or 1
    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
);

CREATE INDEX idx_sessions_date ON sessions(date DESC);
CREATE INDEX idx_scriptures_session ON session_scriptures(session_id);
```

---

## Dependencies

### Before This Story
- Story 8.1: Modern UI Redesign (provides card layout patterns)
- Story 7.3: Pastor Profiles (provides pastor list for dropdown)

### After This Story
- Story 8.4: Export Functionality (uses session data for exports)

### External Dependencies
- SQLite or Core Data for persistence
- Existing `PastorProfile` model (from Epic 7)

---

## Testing Requirements

### Functional Testing
- [ ] Create new session with all fields populated
- [ ] Scriptures auto-add to active session when detected
- [ ] Session auto-saves every 30 seconds
- [ ] Session ends when "End Service" clicked
- [ ] History view loads all sessions correctly
- [ ] Selecting session shows correct details
- [ ] Delete session removes from DB and UI

### Data Integrity Testing
- [ ] Session persists after app restart
- [ ] Scriptures remain associated with correct session
- [ ] No orphaned scriptures in DB
- [ ] Date sorting works correctly (newest first)

### Edge Cases
- [ ] Creating session with no pastor selected (validation)
- [ ] Detecting scripture with no active session (auto-create?)
- [ ] Deleting session while it's active (confirmation dialog)
- [ ] 100+ sessions performance (pagination or lazy loading)

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] Sessions persist correctly to local database
- [ ] History view displays all sessions with metadata
- [ ] Session details show all scriptures in grid layout
- [ ] Create/Edit/Delete operations work correctly
- [ ] Auto-save during active service functional
- [ ] Code review completed
- [ ] Testing passed
- [ ] Merged to main

---

## UI Mockup Notes

### New Service Button
- Position: Top-left, near logo (or in menu bar)
- Style: Secondary button (not gold, to avoid confusion with primary actions)
- Icon: Plus symbol or calendar icon
- Size: 36px height

### Session Info Display (Active)
- Position: Below status indicator in header
- Text: "Sunday Morning • Pastor John" (14pt, gray)
- Clickable: Opens session details modal

### History View Layout
```
┌─────────────────────────────────────────────────────────┐
│ ● ● ●          Service History                       × │
├──────────────┬──────────────────────────────────────────┤
│              │                                          │
│ SESSION LIST │ SESSION DETAILS                          │
│              │                                          │
│ Feb 18, 2026 │ Sunday Morning Service                   │
│ 10:00 AM     │ Pastor: John Smith                       │
│ Pastor John  │ Sermon: "God's Love"                     │
│ 5 verses     │                                          │
│ [SELECTED]   │ Scriptures Used (5):                     │
│              │                                          │
│ Feb 11, 2026 │ ┌──────────┐  ┌──────────┐             │
│ 10:00 AM     │ │ John 3:16│  │ Rom 8:28 │             │
│ Pastor Jane  │ │ For God..│  │ And we...│             │
│ 3 verses     │ └──────────┘  └──────────┘             │
│              │                                          │
│ Feb 4, 2026  │ [Export as PDF] [Export as Markdown]     │
│ 10:00 AM     │                                          │
└──────────────┴──────────────────────────────────────────┘
```

---

## Related Documents

- [Epic 8 README](./README.md)
- [Story 8.1 - Modern UI Redesign](./story-8.1-modern-ui-redesign.md)
- [Story 8.4 - Export Functionality](./story-8.4-export-share.md)
- [Technical Specification](../../epic-8-technical-specification.md)

---

**Story Owner:** coachAOG
**Created:** February 18, 2026
**Status:** 📋 Ready for Implementation
**Blocked By:** Story 8.1
**Blocks:** Story 8.4
