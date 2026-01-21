# Story 4.3: Service History Archive

**Epic:** 4 - Service Sessions & Pastor Profiles  
**Story ID:** 4.3  
**Status:** Not Started  
**Complexity:** Medium  

---

## User Story

**As an** operator,  
**I want** past services to be saved for 3 months,  
**so that** I can review what scriptures were detected and pushed in previous services.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Completed services saved to local database | Data persists |
| 2 | Service includes: name, date, pastor, all detected scriptures | All fields stored |
| 3 | Transcript snippets saved (rolling buffer per detection) | Context preserved |
| 4 | Services older than 90 days auto-deleted on app launch | Cleanup runs |
| 5 | Export option available before auto-delete | Export button works |
| 6 | Exported format is JSON or CSV | File created |
| 7 | Storage location is app's Application Support folder | Correct path |

---

## Technical Notes

### Storage Strategy

```swift
// Use SQLite via direct API or SwiftData for persistence
class ServiceArchive {
    private let retentionDays = 90
    
    func save(_ session: ServiceSession) {
        // Insert into database
    }
    
    func loadAll() -> [ServiceSession] {
        // Query all sessions
    }
    
    func cleanup() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date())!
        // DELETE FROM sessions WHERE date < cutoff
    }
    
    func export(_ session: ServiceSession, format: ExportFormat) -> URL {
        // Generate file and return path
    }
}

enum ExportFormat {
    case json
    case csv
}
```

### Database Schema

```sql
CREATE TABLE service_sessions (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    service_type TEXT NOT NULL,
    date DATE NOT NULL,
    pastor_id TEXT,
    start_time DATETIME NOT NULL,
    end_time DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE detected_scriptures (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    reference TEXT NOT NULL,
    verse_text TEXT,
    timestamp DATETIME NOT NULL,
    was_pushed BOOLEAN DEFAULT FALSE,
    raw_transcript TEXT,
    FOREIGN KEY (session_id) REFERENCES service_sessions(id)
);

CREATE INDEX idx_sessions_date ON service_sessions(date);
```

---

## Dependencies

- Story 4.1 (Service Session Creation)

---

## Definition of Done

- [ ] Sessions saved to database
- [ ] 90-day auto-cleanup works
- [ ] Export functionality works
- [ ] Committed to Git
