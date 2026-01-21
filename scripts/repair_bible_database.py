#!/usr/bin/env python3
"""
Bible Database Repair Script
Downloads missing verses from wldeh/bible-api via jsDelivr CDN
No rate limits, MIT licensed, commercial use OK
"""

import os
import json
import sqlite3
import urllib.request
import time
from typing import Dict, List, Optional

# Database path
DB_PATH = os.path.join(os.path.dirname(__file__), 
    "../DivineLink/DivineLink/Resources/Bible.db")

# CDN base URL (no rate limits!)
CDN_BASE = "https://cdn.jsdelivr.net/gh/wldeh/bible-api/bibles"

# Translation mappings
TRANSLATIONS = {
    "KJV": "en-kjv",
    "ASV": "en-asv",
    "WEB": "en-web"  # World English Bible
}

# Book name mappings (our DB name -> API name)
BOOK_NAMES = {
    "Genesis": "genesis", "Exodus": "exodus", "Leviticus": "leviticus",
    "Numbers": "numbers", "Deuteronomy": "deuteronomy", "Joshua": "joshua",
    "Judges": "judges", "Ruth": "ruth", "1 Samuel": "1-samuel",
    "2 Samuel": "2-samuel", "1 Kings": "1-kings", "2 Kings": "2-kings",
    "1 Chronicles": "1-chronicles", "2 Chronicles": "2-chronicles",
    "Ezra": "ezra", "Nehemiah": "nehemiah", "Esther": "esther",
    "Job": "job", "Psalms": "psalms", "Proverbs": "proverbs",
    "Ecclesiastes": "ecclesiastes", "Song of Solomon": "song-of-solomon",
    "Isaiah": "isaiah", "Jeremiah": "jeremiah", "Lamentations": "lamentations",
    "Ezekiel": "ezekiel", "Daniel": "daniel", "Hosea": "hosea",
    "Joel": "joel", "Amos": "amos", "Obadiah": "obadiah",
    "Jonah": "jonah", "Micah": "micah", "Nahum": "nahum",
    "Habakkuk": "habakkuk", "Zephaniah": "zephaniah", "Haggai": "haggai",
    "Zechariah": "zechariah", "Malachi": "malachi",
    "Matthew": "matthew", "Mark": "mark", "Luke": "luke", "John": "john",
    "Acts": "acts", "Romans": "romans", "1 Corinthians": "1-corinthians",
    "2 Corinthians": "2-corinthians", "Galatians": "galatians",
    "Ephesians": "ephesians", "Philippians": "philippians",
    "Colossians": "colossians", "1 Thessalonians": "1-thessalonians",
    "2 Thessalonians": "2-thessalonians", "1 Timothy": "1-timothy",
    "2 Timothy": "2-timothy", "Titus": "titus", "Philemon": "philemon",
    "Hebrews": "hebrews", "James": "james", "1 Peter": "1-peter",
    "2 Peter": "2-peter", "1 John": "1-john", "2 John": "2-john",
    "3 John": "3-john", "Jude": "jude", "Revelation": "revelation"
}

# Expected verse counts per book (canonical)
VERSE_COUNTS = {
    "Genesis": 1533, "Exodus": 1213, "Leviticus": 859, "Numbers": 1288,
    "Deuteronomy": 959, "Joshua": 658, "Judges": 618, "Ruth": 85,
    "1 Samuel": 810, "2 Samuel": 695, "1 Kings": 816, "2 Kings": 719,
    "1 Chronicles": 942, "2 Chronicles": 822, "Ezra": 280, "Nehemiah": 406,
    "Esther": 167, "Job": 1070, "Psalms": 2461, "Proverbs": 915,
    "Ecclesiastes": 222, "Song of Solomon": 117, "Isaiah": 1292,
    "Jeremiah": 1364, "Lamentations": 154, "Ezekiel": 1273, "Daniel": 357,
    "Hosea": 197, "Joel": 73, "Amos": 146, "Obadiah": 21, "Jonah": 48,
    "Micah": 105, "Nahum": 47, "Habakkuk": 56, "Zephaniah": 53,
    "Haggai": 38, "Zechariah": 211, "Malachi": 55,
    "Matthew": 1071, "Mark": 678, "Luke": 1151, "John": 879,
    "Acts": 1007, "Romans": 433, "1 Corinthians": 437, "2 Corinthians": 257,
    "Galatians": 149, "Ephesians": 155, "Philippians": 104, "Colossians": 95,
    "1 Thessalonians": 89, "2 Thessalonians": 47, "1 Timothy": 113,
    "2 Timothy": 83, "Titus": 46, "Philemon": 25, "Hebrews": 303,
    "James": 108, "1 Peter": 105, "2 Peter": 61, "1 John": 105,
    "2 John": 13, "3 John": 14, "Jude": 25, "Revelation": 404
}

# Chapters per book
CHAPTERS = {
    "Genesis": 50, "Exodus": 40, "Leviticus": 27, "Numbers": 36,
    "Deuteronomy": 34, "Joshua": 24, "Judges": 21, "Ruth": 4,
    "1 Samuel": 31, "2 Samuel": 24, "1 Kings": 22, "2 Kings": 25,
    "1 Chronicles": 29, "2 Chronicles": 36, "Ezra": 10, "Nehemiah": 13,
    "Esther": 10, "Job": 42, "Psalms": 150, "Proverbs": 31,
    "Ecclesiastes": 12, "Song of Solomon": 8, "Isaiah": 66,
    "Jeremiah": 52, "Lamentations": 5, "Ezekiel": 48, "Daniel": 12,
    "Hosea": 14, "Joel": 3, "Amos": 9, "Obadiah": 1, "Jonah": 4,
    "Micah": 7, "Nahum": 3, "Habakkuk": 3, "Zephaniah": 3,
    "Haggai": 2, "Zechariah": 14, "Malachi": 4,
    "Matthew": 28, "Mark": 16, "Luke": 24, "John": 21,
    "Acts": 28, "Romans": 16, "1 Corinthians": 16, "2 Corinthians": 13,
    "Galatians": 6, "Ephesians": 6, "Philippians": 4, "Colossians": 4,
    "1 Thessalonians": 5, "2 Thessalonians": 3, "1 Timothy": 6,
    "2 Timothy": 4, "Titus": 3, "Philemon": 1, "Hebrews": 13,
    "James": 5, "1 Peter": 5, "2 Peter": 3, "1 John": 5,
    "2 John": 1, "3 John": 1, "Jude": 1, "Revelation": 22
}


def get_existing_verses(conn, translation_id: str, book_id: int) -> set:
    """Get set of (chapter, verse) tuples that exist in DB"""
    cursor = conn.cursor()
    cursor.execute("""
        SELECT chapter, verse FROM verses 
        WHERE translation_id = ? AND book_id = ?
    """, (translation_id, book_id))
    return {(row[0], row[1]) for row in cursor.fetchall()}


def download_chapter(translation_code: str, book_api: str, chapter: int) -> Optional[List[dict]]:
    """Download entire chapter from CDN"""
    url = f"{CDN_BASE}/{translation_code}/books/{book_api}/chapters/{chapter}.json"
    
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'DivineLink/1.0'})
        with urllib.request.urlopen(req, timeout=30) as response:
            data = json.loads(response.read().decode('utf-8'))
            return data.get('verses', data.get('data', []))
    except Exception as e:
        # Try individual verse format if chapter fails
        return None


def download_verse(translation_code: str, book_api: str, chapter: int, verse: int) -> Optional[str]:
    """Download single verse from CDN"""
    url = f"{CDN_BASE}/{translation_code}/books/{book_api}/chapters/{chapter}/verses/{verse}.json"
    
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'DivineLink/1.0'})
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode('utf-8'))
            return data.get('text', data.get('verse', ''))
    except:
        return None


def repair_translation(conn, translation_id: str):
    """Repair missing verses for a translation"""
    translation_code = TRANSLATIONS.get(translation_id)
    if not translation_code:
        print(f"  ❌ Unknown translation: {translation_id}")
        return
    
    cursor = conn.cursor()
    
    # Get all books
    cursor.execute("SELECT id, name FROM books ORDER BY id")
    books = cursor.fetchall()
    
    total_added = 0
    total_missing = 0
    
    for book_id, book_name in books:
        book_api = BOOK_NAMES.get(book_name)
        if not book_api:
            print(f"  ⚠️  Unknown book mapping: {book_name}")
            continue
        
        existing = get_existing_verses(conn, translation_id, book_id)
        expected_total = VERSE_COUNTS.get(book_name, 0)
        num_chapters = CHAPTERS.get(book_name, 0)
        
        if len(existing) >= expected_total * 0.95:  # 95% complete
            print(f"  ✓ {book_name}: {len(existing)} verses (complete)")
            continue
        
        print(f"  📖 {book_name}: {len(existing)}/{expected_total} verses...")
        book_added = 0
        
        # Download chapter by chapter
        for chapter in range(1, num_chapters + 1):
            chapter_verses = download_chapter(translation_code, book_api, chapter)
            
            if chapter_verses:
                for v in chapter_verses:
                    verse_num = v.get('verse', v.get('number', 0))
                    text = v.get('text', '')
                    
                    if not verse_num or not text:
                        continue
                    
                    if (chapter, verse_num) not in existing:
                        for attempt in range(3):  # Retry up to 3 times
                            try:
                                cursor.execute("""
                                    INSERT INTO verses (translation_id, book_id, chapter, verse, text)
                                    VALUES (?, ?, ?, ?, ?)
                                """, (translation_id, book_id, chapter, verse_num, text))
                                book_added += 1
                                total_added += 1
                                break
                            except sqlite3.IntegrityError:
                                break  # Already exists
                            except sqlite3.OperationalError as e:
                                if "locked" in str(e) and attempt < 2:
                                    time.sleep(1)  # Wait and retry
                                else:
                                    raise
            
            # Small delay between chapters
            time.sleep(0.1)
        
        # Commit with retry
        for attempt in range(5):
            try:
                conn.commit()
                break
            except sqlite3.OperationalError as e:
                if "locked" in str(e) and attempt < 4:
                    print(f"     ⚠️  Database locked, retrying commit...")
                    time.sleep(2)
                else:
                    raise
        
        if book_added > 0:
            print(f"     ✅ Added {book_added} verses")
        
        total_missing += max(0, expected_total - len(existing) - book_added)
    
    print(f"\n  📊 {translation_id}: Added {total_added} verses, ~{total_missing} still missing")


def main():
    print("=" * 60)
    print("Bible Database Repair Tool")
    print("Source: wldeh/bible-api via jsDelivr CDN (MIT, no limits)")
    print("=" * 60)
    
    # Check database
    if not os.path.exists(DB_PATH):
        print(f"❌ Database not found: {DB_PATH}")
        return
    
    conn = sqlite3.connect(DB_PATH)
    
    # Current stats
    cursor = conn.cursor()
    cursor.execute("SELECT translation_id, COUNT(*) FROM verses GROUP BY translation_id")
    stats = cursor.fetchall()
    
    print("\n📊 Current Database Status:")
    for trans_id, count in stats:
        print(f"   {trans_id}: {count} verses")
    
    print("\n" + "=" * 60)
    
    # Repair each translation
    for trans_id in TRANSLATIONS.keys():
        print(f"\n🔧 Repairing {trans_id}...")
        repair_translation(conn, trans_id)
    
    # Final stats
    cursor.execute("SELECT translation_id, COUNT(*) FROM verses GROUP BY translation_id")
    final_stats = cursor.fetchall()
    
    print("\n" + "=" * 60)
    print("📊 Final Database Status:")
    for trans_id, count in final_stats:
        print(f"   {trans_id}: {count} verses")
    
    conn.close()
    print("\n✅ Repair complete!")


if __name__ == "__main__":
    main()
