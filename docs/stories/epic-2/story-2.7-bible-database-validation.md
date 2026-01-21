# Story 2.7: Bible Database Validation & Repair

**Epic:** 2 - Transcription & Scripture Detection  
**Story ID:** 2.7  
**Status:** Not Started  
**Complexity:** Medium  
**Priority:** High (blocking full functionality)

---

## User Story

**As a** developer,  
**I want** to validate the Bible database has all chapters and verses,  
**so that** every scripture reference can be resolved to actual verse text.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Validation script checks all 66 books exist | Script reports missing books |
| 2 | Script checks expected chapter count per book | Reports books with missing chapters |
| 3 | Script checks minimum verse count per chapter | Reports chapters with missing/low verses |
| 4 | Repair mode re-downloads missing content | Missing data filled in |
| 5 | Report shows completion percentage per translation | Summary displayed |
| 6 | All 5 translations validated: KJV, WEB, ASV, YLT, BBE | Each translation checked |
| 7 | Final database has 95%+ coverage | Near-complete data |

---

## Technical Notes

### Expected Verse Counts (approximate)

| Testament | Books | Chapters | Verses |
|-----------|-------|----------|--------|
| Old Testament | 39 | 929 | ~23,145 |
| New Testament | 27 | 260 | ~7,957 |
| **Total** | 66 | 1,189 | ~31,102 |

### Validation Script

```python
#!/usr/bin/env python3
"""validate_bible_db.py - Check and repair Bible database"""

import sqlite3

EXPECTED_BOOKS = 66
EXPECTED_VERSES_MIN = 30000  # per translation

def validate(db_path):
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    
    # Check translations
    c.execute("SELECT id, name FROM translations")
    translations = c.fetchall()
    print(f"Translations found: {len(translations)}")
    
    for trans_id, trans_name in translations:
        # Count verses per translation
        c.execute("SELECT COUNT(*) FROM verses WHERE translation_id = ?", (trans_id,))
        count = c.fetchone()[0]
        pct = (count / EXPECTED_VERSES_MIN) * 100
        status = "✅" if count > EXPECTED_VERSES_MIN * 0.9 else "❌"
        print(f"  {status} {trans_name}: {count:,} verses ({pct:.1f}%)")
        
        # Find missing books
        c.execute("""
            SELECT b.id, b.name, COUNT(v.id) as verse_count
            FROM books b
            LEFT JOIN verses v ON v.book_id = b.id AND v.translation_id = ?
            GROUP BY b.id
            HAVING verse_count = 0 OR verse_count IS NULL
        """, (trans_id,))
        missing = c.fetchall()
        if missing:
            print(f"    Missing books: {[m[1] for m in missing]}")
    
    conn.close()

def repair(db_path, translation_id):
    """Re-download missing chapters for a translation."""
    # Implementation: re-fetch from API for missing books/chapters
    pass

if __name__ == "__main__":
    validate("Bible.db")
```

### Repair Strategy

1. **Identify gaps**: Run validation to find missing books/chapters
2. **Alternative APIs**: Try multiple sources if one fails:
   - Bible-API.com (primary)
   - HelloAO (backup)
   - GetBible.net (backup)
3. **Rate limiting**: Add delays between requests (0.5s)
4. **Retry logic**: 3 attempts per chapter before marking failed
5. **Manual fallback**: For persistently missing content, document for manual addition

### Book Verse Expectations

```python
BOOK_VERSE_COUNTS = {
    "Genesis": 1533, "Exodus": 1213, "Leviticus": 859,
    "Psalms": 2461, "Proverbs": 915, "Isaiah": 1292,
    "Matthew": 1071, "Mark": 678, "Luke": 1151,
    "John": 879, "Acts": 1007, "Romans": 433,
    "Revelation": 404,
    # ... etc
}
```

---

## Dependencies

- Story 2.1 (Bible Database Setup) - Complete
- Bible download scripts - In progress

---

## Definition of Done

- [ ] Validation script created
- [ ] All translations checked
- [ ] Missing content identified
- [ ] Repair script re-downloads gaps
- [ ] 95%+ coverage achieved
- [ ] Database committed to Git (or download instructions)
- [ ] Committed to Git
