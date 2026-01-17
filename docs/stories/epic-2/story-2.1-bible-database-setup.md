# Story 2.1: Bible Database Setup

**Epic:** 2 - Transcription & Scripture Detection  
**Story ID:** 2.1  
**Status:** Not Started  
**Complexity:** Medium  

---

## User Story

**As a** developer,  
**I want** a local SQLite database containing the Berean Standard Bible,  
**so that** detected scripture references can be resolved to full verse text.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | SQLite database file (`Bible.db`) created with BSB text | File exists and opens in SQLite browser |
| 2 | Database schema includes tables: `books`, `verses` | Tables exist with correct columns |
| 3 | `books` table contains 66 entries with canonical names and aliases | Query returns 66 books |
| 4 | `verses` table contains all verses with book_id, chapter, verse, text | Query returns ~31,000 verses |
| 5 | Database is embedded in app bundle (`Resources/`) | App accesses DB from bundle |
| 6 | `BibleService` class provides verse lookup by reference | `getVerse("John", 3, 16)` returns text |
| 7 | Lookup returns verse text or nil if not found | Invalid reference returns nil |
| 8 | Service handles edge cases (invalid chapter/verse numbers) | No crashes on bad input |

---

## Technical Notes

### Database Schema

```sql
-- Books table
CREATE TABLE books (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,           -- "Genesis", "1 Corinthians"
    aliases TEXT,                 -- JSON array: ["Gen", "Ge"]
    testament TEXT NOT NULL,      -- "OT" or "NT"
    chapters INTEGER NOT NULL     -- Number of chapters
);

-- Verses table
CREATE TABLE verses (
    id INTEGER PRIMARY KEY,
    book_id INTEGER NOT NULL,
    chapter INTEGER NOT NULL,
    verse INTEGER NOT NULL,
    text TEXT NOT NULL,
    FOREIGN KEY (book_id) REFERENCES books(id)
);

-- Indexes for fast lookup
CREATE INDEX idx_verses_lookup ON verses(book_id, chapter, verse);
CREATE INDEX idx_books_name ON books(name);
```

### BibleService Implementation

```swift
import GRDB

class BibleService {
    private let dbQueue: DatabaseQueue
    
    init() throws {
        guard let dbPath = Bundle.main.path(forResource: "Bible", ofType: "db") else {
            throw BibleError.databaseNotFound
        }
        dbQueue = try DatabaseQueue(path: dbPath)
    }
    
    func getVerse(book: String, chapter: Int, verse: Int) -> String? {
        try? dbQueue.read { db in
            let bookRow = try Row.fetchOne(db, sql: """
                SELECT id FROM books 
                WHERE name = ? OR aliases LIKE ?
                """, arguments: [book, "%\"\(book)\"%"])
            
            guard let bookId = bookRow?["id"] as? Int else { return nil }
            
            let verseRow = try Row.fetchOne(db, sql: """
                SELECT text FROM verses 
                WHERE book_id = ? AND chapter = ? AND verse = ?
                """, arguments: [bookId, chapter, verse])
            
            return verseRow?["text"] as? String
        }
    }
    
    func getVerseRange(book: String, chapter: Int, startVerse: Int, endVerse: Int) -> String? {
        // Similar implementation for verse ranges
    }
}
```

### Data Source

**Berean Standard Bible** - Public Domain (April 2023)
- Source: [HelloAO Bible API](https://bible.helloao.org) or direct download
- Format: JSON or CSV, convert to SQLite
- Licence: Public Domain - no attribution required

### Book Aliases

```json
{
  "Genesis": ["Gen", "Ge"],
  "Exodus": ["Exod", "Ex"],
  "1 Corinthians": ["1 Cor", "First Corinthians", "I Corinthians", "1Cor"],
  "Revelation": ["Rev", "Revelations", "The Revelation"]
}
```

---

## Dependencies

- Story 1.1 (Project Scaffolding) - for Resources folder

---

## Definition of Done

- [ ] Database file created with all 66 books
- [ ] All ~31,000 verses imported correctly
- [ ] BibleService returns correct verse text
- [ ] Edge cases tested (invalid refs return nil)
- [ ] Database bundled with app
- [ ] Committed to Git
