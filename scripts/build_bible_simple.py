#!/usr/bin/env python3
"""
Simple Bible Database Builder - Uses reliable Bible-API.com data
Creates a SQLite database with 5 translations for Divine Link.
"""

import sqlite3
import json
import urllib.request
import os
import time

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "..", "DivineLink", "DivineLink", "Resources")
OUTPUT_DB = os.path.join(OUTPUT_DIR, "Bible.db")

# Books of the Bible
BOOKS = [
    {"id": 1, "name": "Genesis", "testament": "OT", "chapters": 50, "aliases": '["Gen","Ge"]'},
    {"id": 2, "name": "Exodus", "testament": "OT", "chapters": 40, "aliases": '["Exod","Ex"]'},
    {"id": 3, "name": "Leviticus", "testament": "OT", "chapters": 27, "aliases": '["Lev","Le"]'},
    {"id": 4, "name": "Numbers", "testament": "OT", "chapters": 36, "aliases": '["Num","Nu"]'},
    {"id": 5, "name": "Deuteronomy", "testament": "OT", "chapters": 34, "aliases": '["Deut","De"]'},
    {"id": 6, "name": "Joshua", "testament": "OT", "chapters": 24, "aliases": '["Josh","Jos"]'},
    {"id": 7, "name": "Judges", "testament": "OT", "chapters": 21, "aliases": '["Judg","Jdg"]'},
    {"id": 8, "name": "Ruth", "testament": "OT", "chapters": 4, "aliases": '["Ru"]'},
    {"id": 9, "name": "1 Samuel", "testament": "OT", "chapters": 31, "aliases": '["1Sam","1Sa"]'},
    {"id": 10, "name": "2 Samuel", "testament": "OT", "chapters": 24, "aliases": '["2Sam","2Sa"]'},
    {"id": 11, "name": "1 Kings", "testament": "OT", "chapters": 22, "aliases": '["1Kgs","1Ki"]'},
    {"id": 12, "name": "2 Kings", "testament": "OT", "chapters": 25, "aliases": '["2Kgs","2Ki"]'},
    {"id": 13, "name": "1 Chronicles", "testament": "OT", "chapters": 29, "aliases": '["1Chr","1Ch"]'},
    {"id": 14, "name": "2 Chronicles", "testament": "OT", "chapters": 36, "aliases": '["2Chr","2Ch"]'},
    {"id": 15, "name": "Ezra", "testament": "OT", "chapters": 10, "aliases": '["Ezr"]'},
    {"id": 16, "name": "Nehemiah", "testament": "OT", "chapters": 13, "aliases": '["Neh","Ne"]'},
    {"id": 17, "name": "Esther", "testament": "OT", "chapters": 10, "aliases": '["Esth","Es"]'},
    {"id": 18, "name": "Job", "testament": "OT", "chapters": 42, "aliases": '["Jb"]'},
    {"id": 19, "name": "Psalms", "testament": "OT", "chapters": 150, "aliases": '["Ps","Psa","Psalm"]'},
    {"id": 20, "name": "Proverbs", "testament": "OT", "chapters": 31, "aliases": '["Prov","Pr","Pro"]'},
    {"id": 21, "name": "Ecclesiastes", "testament": "OT", "chapters": 12, "aliases": '["Eccl","Ec"]'},
    {"id": 22, "name": "Song of Solomon", "testament": "OT", "chapters": 8, "aliases": '["Song","SoS","Songs"]'},
    {"id": 23, "name": "Isaiah", "testament": "OT", "chapters": 66, "aliases": '["Isa","Is"]'},
    {"id": 24, "name": "Jeremiah", "testament": "OT", "chapters": 52, "aliases": '["Jer","Je"]'},
    {"id": 25, "name": "Lamentations", "testament": "OT", "chapters": 5, "aliases": '["Lam","La"]'},
    {"id": 26, "name": "Ezekiel", "testament": "OT", "chapters": 48, "aliases": '["Ezek","Eze"]'},
    {"id": 27, "name": "Daniel", "testament": "OT", "chapters": 12, "aliases": '["Dan","Da"]'},
    {"id": 28, "name": "Hosea", "testament": "OT", "chapters": 14, "aliases": '["Hos","Ho"]'},
    {"id": 29, "name": "Joel", "testament": "OT", "chapters": 3, "aliases": '["Joe","Jl"]'},
    {"id": 30, "name": "Amos", "testament": "OT", "chapters": 9, "aliases": '["Am"]'},
    {"id": 31, "name": "Obadiah", "testament": "OT", "chapters": 1, "aliases": '["Obad","Ob"]'},
    {"id": 32, "name": "Jonah", "testament": "OT", "chapters": 4, "aliases": '["Jon","Jnh"]'},
    {"id": 33, "name": "Micah", "testament": "OT", "chapters": 7, "aliases": '["Mic","Mi"]'},
    {"id": 34, "name": "Nahum", "testament": "OT", "chapters": 3, "aliases": '["Nah","Na"]'},
    {"id": 35, "name": "Habakkuk", "testament": "OT", "chapters": 3, "aliases": '["Hab"]'},
    {"id": 36, "name": "Zephaniah", "testament": "OT", "chapters": 3, "aliases": '["Zeph","Zep"]'},
    {"id": 37, "name": "Haggai", "testament": "OT", "chapters": 2, "aliases": '["Hag","Hg"]'},
    {"id": 38, "name": "Zechariah", "testament": "OT", "chapters": 14, "aliases": '["Zech","Zec"]'},
    {"id": 39, "name": "Malachi", "testament": "OT", "chapters": 4, "aliases": '["Mal"]'},
    {"id": 40, "name": "Matthew", "testament": "NT", "chapters": 28, "aliases": '["Matt","Mt"]'},
    {"id": 41, "name": "Mark", "testament": "NT", "chapters": 16, "aliases": '["Mk","Mr"]'},
    {"id": 42, "name": "Luke", "testament": "NT", "chapters": 24, "aliases": '["Luk","Lk"]'},
    {"id": 43, "name": "John", "testament": "NT", "chapters": 21, "aliases": '["Jn","Joh"]'},
    {"id": 44, "name": "Acts", "testament": "NT", "chapters": 28, "aliases": '["Act","Ac"]'},
    {"id": 45, "name": "Romans", "testament": "NT", "chapters": 16, "aliases": '["Rom","Ro"]'},
    {"id": 46, "name": "1 Corinthians", "testament": "NT", "chapters": 16, "aliases": '["1Cor","1Co"]'},
    {"id": 47, "name": "2 Corinthians", "testament": "NT", "chapters": 13, "aliases": '["2Cor","2Co"]'},
    {"id": 48, "name": "Galatians", "testament": "NT", "chapters": 6, "aliases": '["Gal","Ga"]'},
    {"id": 49, "name": "Ephesians", "testament": "NT", "chapters": 6, "aliases": '["Eph","Ep"]'},
    {"id": 50, "name": "Philippians", "testament": "NT", "chapters": 4, "aliases": '["Phil","Php"]'},
    {"id": 51, "name": "Colossians", "testament": "NT", "chapters": 4, "aliases": '["Col"]'},
    {"id": 52, "name": "1 Thessalonians", "testament": "NT", "chapters": 5, "aliases": '["1Thess","1Th"]'},
    {"id": 53, "name": "2 Thessalonians", "testament": "NT", "chapters": 3, "aliases": '["2Thess","2Th"]'},
    {"id": 54, "name": "1 Timothy", "testament": "NT", "chapters": 6, "aliases": '["1Tim","1Ti"]'},
    {"id": 55, "name": "2 Timothy", "testament": "NT", "chapters": 4, "aliases": '["2Tim","2Ti"]'},
    {"id": 56, "name": "Titus", "testament": "NT", "chapters": 3, "aliases": '["Tit"]'},
    {"id": 57, "name": "Philemon", "testament": "NT", "chapters": 1, "aliases": '["Phlm","Phm"]'},
    {"id": 58, "name": "Hebrews", "testament": "NT", "chapters": 13, "aliases": '["Heb"]'},
    {"id": 59, "name": "James", "testament": "NT", "chapters": 5, "aliases": '["Jas","Jam"]'},
    {"id": 60, "name": "1 Peter", "testament": "NT", "chapters": 5, "aliases": '["1Pet","1Pe"]'},
    {"id": 61, "name": "2 Peter", "testament": "NT", "chapters": 3, "aliases": '["2Pet","2Pe"]'},
    {"id": 62, "name": "1 John", "testament": "NT", "chapters": 5, "aliases": '["1Jn","1Jo"]'},
    {"id": 63, "name": "2 John", "testament": "NT", "chapters": 1, "aliases": '["2Jn","2Jo"]'},
    {"id": 64, "name": "3 John", "testament": "NT", "chapters": 1, "aliases": '["3Jn","3Jo"]'},
    {"id": 65, "name": "Jude", "testament": "NT", "chapters": 1, "aliases": '["Jud"]'},
    {"id": 66, "name": "Revelation", "testament": "NT", "chapters": 22, "aliases": '["Rev","Re","Revelations"]'},
]

# Translations with their Bible-API.com IDs
TRANSLATIONS = [
    {"id": "KJV", "name": "King James Version", "year": 1769, "api_id": "kjv"},
    {"id": "ASV", "name": "American Standard Version", "year": 1901, "api_id": "asv"},
    {"id": "WEB", "name": "World English Bible", "year": 2000, "api_id": "web"},
    {"id": "YLT", "name": "Young's Literal Translation", "year": 1898, "api_id": "ylt"},
    {"id": "BBE", "name": "Bible in Basic English", "year": 1965, "api_id": "bbe"},  # Using BBE as BSB isn't available
]


def create_database():
    """Create the SQLite database."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    if os.path.exists(OUTPUT_DB):
        os.remove(OUTPUT_DB)
    
    conn = sqlite3.connect(OUTPUT_DB)
    c = conn.cursor()
    
    c.execute("""CREATE TABLE translations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        year INTEGER,
        is_default INTEGER DEFAULT 0
    )""")
    
    c.execute("""CREATE TABLE books (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        testament TEXT NOT NULL,
        chapters INTEGER NOT NULL,
        aliases TEXT
    )""")
    
    c.execute("""CREATE TABLE verses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        translation_id TEXT NOT NULL,
        book_id INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        verse INTEGER NOT NULL,
        text TEXT NOT NULL
    )""")
    
    c.execute("CREATE INDEX idx_verses_lookup ON verses(translation_id, book_id, chapter, verse)")
    c.execute("CREATE INDEX idx_books_name ON books(name)")
    
    # Insert books
    for book in BOOKS:
        c.execute("INSERT INTO books VALUES (?,?,?,?,?)",
                  (book["id"], book["name"], book["testament"], book["chapters"], book["aliases"]))
    
    conn.commit()
    return conn


def fetch_chapter(api_id, book_name, chapter):
    """Fetch a chapter from Bible-API.com."""
    # Handle book name formatting for API
    book_api = book_name.lower().replace(" ", "")
    if book_api.startswith("1") or book_api.startswith("2") or book_api.startswith("3"):
        # Handle numbered books: "1john" -> "1john"
        pass
    
    url = f"https://bible-api.com/{book_name.replace(' ', '%20')}+{chapter}?translation={api_id}"
    
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "DivineLink/1.0"})
        with urllib.request.urlopen(req, timeout=30) as response:
            data = json.loads(response.read().decode())
            verses = []
            if "verses" in data:
                for v in data["verses"]:
                    verses.append((v["verse"], v["text"].strip()))
            return verses
    except Exception as e:
        return []


def download_translation(conn, trans):
    """Download all verses for a translation."""
    c = conn.cursor()
    
    # Insert translation
    is_default = 1 if trans["id"] == "KJV" else 0
    c.execute("INSERT INTO translations VALUES (?,?,?,?)",
              (trans["id"], trans["name"], trans["year"], is_default))
    
    print(f"\n📖 Downloading {trans['name']}...")
    total = 0
    
    for book in BOOKS:
        book_total = 0
        for chapter in range(1, book["chapters"] + 1):
            verses = fetch_chapter(trans["api_id"], book["name"], chapter)
            for verse_num, text in verses:
                c.execute("INSERT INTO verses (translation_id, book_id, chapter, verse, text) VALUES (?,?,?,?,?)",
                          (trans["id"], book["id"], chapter, verse_num, text))
                book_total += 1
            
            # Prevent rate limiting
            time.sleep(0.1)
        
        total += book_total
        print(f"  ✓ {book['name']}: {book_total} verses")
    
    conn.commit()
    print(f"  📊 Total: {total} verses")
    return total


def main():
    print("=" * 50)
    print("Divine Link Bible Database Builder")
    print("=" * 50)
    
    conn = create_database()
    print(f"\n✓ Database created: {OUTPUT_DB}")
    
    grand_total = 0
    for trans in TRANSLATIONS:
        count = download_translation(conn, trans)
        grand_total += count
    
    conn.close()
    
    size_mb = os.path.getsize(OUTPUT_DB) / (1024 * 1024)
    
    print("\n" + "=" * 50)
    print("✅ Complete!")
    print(f"   Translations: {len(TRANSLATIONS)}")
    print(f"   Total verses: {grand_total:,}")
    print(f"   File size: {size_mb:.2f} MB")
    print("=" * 50)
    print("\nNext: Add Bible.db to Xcode project Resources")


if __name__ == "__main__":
    main()
