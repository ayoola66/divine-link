#!/usr/bin/env python3
"""
Bible Database Builder for Divine Link
Downloads public domain Bible translations and creates a SQLite database.

Translations included:
- BSB: Berean Standard Bible (2023)
- KJV: King James Version (1769)
- WEB: World English Bible (2000)
- YLT: Young's Literal Translation (1898)
- ASV: American Standard Version (1901)

Usage:
    python3 build_bible_database.py

Output:
    ../DivineLink/DivineLink/Resources/Bible.db
"""

import sqlite3
import json
import urllib.request
import os
import sys

# Output path
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "..", "DivineLink", "DivineLink", "Resources")
OUTPUT_DB = os.path.join(OUTPUT_DIR, "Bible.db")

# Bible translations to include (source = API ID)
TRANSLATIONS = {
    "BSB": {
        "name": "Berean Standard Bible",
        "year": 2023,
        "source": "BSB"
    },
    "KJV": {
        "name": "King James Version", 
        "year": 1769,
        "source": "KJV"
    },
    "WEB": {
        "name": "World English Bible",
        "year": 2000,
        "source": "WEB"
    },
    "YLT": {
        "name": "Young's Literal Translation",
        "year": 1898,
        "source": "YLT"
    },
    "ASV": {
        "name": "American Standard Version",
        "year": 1901,
        "source": "ASV"
    }
}

# Book data with canonical names and chapter counts
BOOKS = [
    # Old Testament
    {"id": 1, "name": "Genesis", "abbrev": "Gen", "testament": "OT", "chapters": 50},
    {"id": 2, "name": "Exodus", "abbrev": "Exod", "testament": "OT", "chapters": 40},
    {"id": 3, "name": "Leviticus", "abbrev": "Lev", "testament": "OT", "chapters": 27},
    {"id": 4, "name": "Numbers", "abbrev": "Num", "testament": "OT", "chapters": 36},
    {"id": 5, "name": "Deuteronomy", "abbrev": "Deut", "testament": "OT", "chapters": 34},
    {"id": 6, "name": "Joshua", "abbrev": "Josh", "testament": "OT", "chapters": 24},
    {"id": 7, "name": "Judges", "abbrev": "Judg", "testament": "OT", "chapters": 21},
    {"id": 8, "name": "Ruth", "abbrev": "Ruth", "testament": "OT", "chapters": 4},
    {"id": 9, "name": "1 Samuel", "abbrev": "1Sam", "testament": "OT", "chapters": 31},
    {"id": 10, "name": "2 Samuel", "abbrev": "2Sam", "testament": "OT", "chapters": 24},
    {"id": 11, "name": "1 Kings", "abbrev": "1Kgs", "testament": "OT", "chapters": 22},
    {"id": 12, "name": "2 Kings", "abbrev": "2Kgs", "testament": "OT", "chapters": 25},
    {"id": 13, "name": "1 Chronicles", "abbrev": "1Chr", "testament": "OT", "chapters": 29},
    {"id": 14, "name": "2 Chronicles", "abbrev": "2Chr", "testament": "OT", "chapters": 36},
    {"id": 15, "name": "Ezra", "abbrev": "Ezra", "testament": "OT", "chapters": 10},
    {"id": 16, "name": "Nehemiah", "abbrev": "Neh", "testament": "OT", "chapters": 13},
    {"id": 17, "name": "Esther", "abbrev": "Esth", "testament": "OT", "chapters": 10},
    {"id": 18, "name": "Job", "abbrev": "Job", "testament": "OT", "chapters": 42},
    {"id": 19, "name": "Psalms", "abbrev": "Ps", "testament": "OT", "chapters": 150},
    {"id": 20, "name": "Proverbs", "abbrev": "Prov", "testament": "OT", "chapters": 31},
    {"id": 21, "name": "Ecclesiastes", "abbrev": "Eccl", "testament": "OT", "chapters": 12},
    {"id": 22, "name": "Song of Solomon", "abbrev": "Song", "testament": "OT", "chapters": 8},
    {"id": 23, "name": "Isaiah", "abbrev": "Isa", "testament": "OT", "chapters": 66},
    {"id": 24, "name": "Jeremiah", "abbrev": "Jer", "testament": "OT", "chapters": 52},
    {"id": 25, "name": "Lamentations", "abbrev": "Lam", "testament": "OT", "chapters": 5},
    {"id": 26, "name": "Ezekiel", "abbrev": "Ezek", "testament": "OT", "chapters": 48},
    {"id": 27, "name": "Daniel", "abbrev": "Dan", "testament": "OT", "chapters": 12},
    {"id": 28, "name": "Hosea", "abbrev": "Hos", "testament": "OT", "chapters": 14},
    {"id": 29, "name": "Joel", "abbrev": "Joel", "testament": "OT", "chapters": 3},
    {"id": 30, "name": "Amos", "abbrev": "Amos", "testament": "OT", "chapters": 9},
    {"id": 31, "name": "Obadiah", "abbrev": "Obad", "testament": "OT", "chapters": 1},
    {"id": 32, "name": "Jonah", "abbrev": "Jonah", "testament": "OT", "chapters": 4},
    {"id": 33, "name": "Micah", "abbrev": "Mic", "testament": "OT", "chapters": 7},
    {"id": 34, "name": "Nahum", "abbrev": "Nah", "testament": "OT", "chapters": 3},
    {"id": 35, "name": "Habakkuk", "abbrev": "Hab", "testament": "OT", "chapters": 3},
    {"id": 36, "name": "Zephaniah", "abbrev": "Zeph", "testament": "OT", "chapters": 3},
    {"id": 37, "name": "Haggai", "abbrev": "Hag", "testament": "OT", "chapters": 2},
    {"id": 38, "name": "Zechariah", "abbrev": "Zech", "testament": "OT", "chapters": 14},
    {"id": 39, "name": "Malachi", "abbrev": "Mal", "testament": "OT", "chapters": 4},
    # New Testament
    {"id": 40, "name": "Matthew", "abbrev": "Matt", "testament": "NT", "chapters": 28},
    {"id": 41, "name": "Mark", "abbrev": "Mark", "testament": "NT", "chapters": 16},
    {"id": 42, "name": "Luke", "abbrev": "Luke", "testament": "NT", "chapters": 24},
    {"id": 43, "name": "John", "abbrev": "John", "testament": "NT", "chapters": 21},
    {"id": 44, "name": "Acts", "abbrev": "Acts", "testament": "NT", "chapters": 28},
    {"id": 45, "name": "Romans", "abbrev": "Rom", "testament": "NT", "chapters": 16},
    {"id": 46, "name": "1 Corinthians", "abbrev": "1Cor", "testament": "NT", "chapters": 16},
    {"id": 47, "name": "2 Corinthians", "abbrev": "2Cor", "testament": "NT", "chapters": 13},
    {"id": 48, "name": "Galatians", "abbrev": "Gal", "testament": "NT", "chapters": 6},
    {"id": 49, "name": "Ephesians", "abbrev": "Eph", "testament": "NT", "chapters": 6},
    {"id": 50, "name": "Philippians", "abbrev": "Phil", "testament": "NT", "chapters": 4},
    {"id": 51, "name": "Colossians", "abbrev": "Col", "testament": "NT", "chapters": 4},
    {"id": 52, "name": "1 Thessalonians", "abbrev": "1Thess", "testament": "NT", "chapters": 5},
    {"id": 53, "name": "2 Thessalonians", "abbrev": "2Thess", "testament": "NT", "chapters": 3},
    {"id": 54, "name": "1 Timothy", "abbrev": "1Tim", "testament": "NT", "chapters": 6},
    {"id": 55, "name": "2 Timothy", "abbrev": "2Tim", "testament": "NT", "chapters": 4},
    {"id": 56, "name": "Titus", "abbrev": "Titus", "testament": "NT", "chapters": 3},
    {"id": 57, "name": "Philemon", "abbrev": "Phlm", "testament": "NT", "chapters": 1},
    {"id": 58, "name": "Hebrews", "abbrev": "Heb", "testament": "NT", "chapters": 13},
    {"id": 59, "name": "James", "abbrev": "Jas", "testament": "NT", "chapters": 5},
    {"id": 60, "name": "1 Peter", "abbrev": "1Pet", "testament": "NT", "chapters": 5},
    {"id": 61, "name": "2 Peter", "abbrev": "2Pet", "testament": "NT", "chapters": 3},
    {"id": 62, "name": "1 John", "abbrev": "1John", "testament": "NT", "chapters": 5},
    {"id": 63, "name": "2 John", "abbrev": "2John", "testament": "NT", "chapters": 1},
    {"id": 64, "name": "3 John", "abbrev": "3John", "testament": "NT", "chapters": 1},
    {"id": 65, "name": "Jude", "abbrev": "Jude", "testament": "NT", "chapters": 1},
    {"id": 66, "name": "Revelation", "abbrev": "Rev", "testament": "NT", "chapters": 22},
]

# Book name aliases for detection
BOOK_ALIASES = {
    "Genesis": ["Gen", "Ge"],
    "Exodus": ["Exod", "Ex"],
    "Leviticus": ["Lev", "Le"],
    "Numbers": ["Num", "Nu"],
    "Deuteronomy": ["Deut", "De"],
    "Joshua": ["Josh", "Jos"],
    "Judges": ["Judg", "Jdg"],
    "Ruth": ["Ru"],
    "1 Samuel": ["1Sam", "1Sa", "First Samuel", "I Samuel"],
    "2 Samuel": ["2Sam", "2Sa", "Second Samuel", "II Samuel"],
    "1 Kings": ["1Kgs", "1Ki", "First Kings", "I Kings"],
    "2 Kings": ["2Kgs", "2Ki", "Second Kings", "II Kings"],
    "1 Chronicles": ["1Chr", "1Ch", "First Chronicles", "I Chronicles"],
    "2 Chronicles": ["2Chr", "2Ch", "Second Chronicles", "II Chronicles"],
    "Ezra": ["Ezr"],
    "Nehemiah": ["Neh", "Ne"],
    "Esther": ["Esth", "Es"],
    "Job": ["Jb"],
    "Psalms": ["Ps", "Psa", "Psalm"],
    "Proverbs": ["Prov", "Pr", "Pro"],
    "Ecclesiastes": ["Eccl", "Ec", "Ecc"],
    "Song of Solomon": ["Song", "SoS", "Songs", "Song of Songs"],
    "Isaiah": ["Isa", "Is"],
    "Jeremiah": ["Jer", "Je"],
    "Lamentations": ["Lam", "La"],
    "Ezekiel": ["Ezek", "Eze"],
    "Daniel": ["Dan", "Da"],
    "Hosea": ["Hos", "Ho"],
    "Joel": ["Joe", "Jl"],
    "Amos": ["Am"],
    "Obadiah": ["Obad", "Ob"],
    "Jonah": ["Jon", "Jnh"],
    "Micah": ["Mic", "Mi"],
    "Nahum": ["Nah", "Na"],
    "Habakkuk": ["Hab"],
    "Zephaniah": ["Zeph", "Zep"],
    "Haggai": ["Hag", "Hg"],
    "Zechariah": ["Zech", "Zec"],
    "Malachi": ["Mal"],
    "Matthew": ["Matt", "Mt"],
    "Mark": ["Mk", "Mr"],
    "Luke": ["Luk", "Lk"],
    "John": ["Jn", "Joh"],
    "Acts": ["Act", "Ac"],
    "Romans": ["Rom", "Ro"],
    "1 Corinthians": ["1Cor", "1Co", "First Corinthians", "I Corinthians"],
    "2 Corinthians": ["2Cor", "2Co", "Second Corinthians", "II Corinthians"],
    "Galatians": ["Gal", "Ga"],
    "Ephesians": ["Eph", "Ep"],
    "Philippians": ["Phil", "Php"],
    "Colossians": ["Col"],
    "1 Thessalonians": ["1Thess", "1Th", "First Thessalonians", "I Thessalonians"],
    "2 Thessalonians": ["2Thess", "2Th", "Second Thessalonians", "II Thessalonians"],
    "1 Timothy": ["1Tim", "1Ti", "First Timothy", "I Timothy"],
    "2 Timothy": ["2Tim", "2Ti", "Second Timothy", "II Timothy"],
    "Titus": ["Tit"],
    "Philemon": ["Phlm", "Phm"],
    "Hebrews": ["Heb"],
    "James": ["Jas", "Jam"],
    "1 Peter": ["1Pet", "1Pe", "First Peter", "I Peter"],
    "2 Peter": ["2Pet", "2Pe", "Second Peter", "II Peter"],
    "1 John": ["1Jn", "1Jo", "First John", "I John"],
    "2 John": ["2Jn", "2Jo", "Second John", "II John"],
    "3 John": ["3Jn", "3Jo", "Third John", "III John"],
    "Jude": ["Jud"],
    "Revelation": ["Rev", "Re", "Revelations", "The Revelation"],
}


def create_database():
    """Create the SQLite database with schema."""
    # Ensure output directory exists
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # Remove existing database
    if os.path.exists(OUTPUT_DB):
        os.remove(OUTPUT_DB)
    
    conn = sqlite3.connect(OUTPUT_DB)
    cursor = conn.cursor()
    
    # Create translations table
    cursor.execute("""
        CREATE TABLE translations (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            abbreviation TEXT NOT NULL,
            year INTEGER,
            is_default INTEGER DEFAULT 0
        )
    """)
    
    # Create books table
    cursor.execute("""
        CREATE TABLE books (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            abbreviation TEXT NOT NULL,
            testament TEXT NOT NULL,
            chapters INTEGER NOT NULL,
            aliases TEXT
        )
    """)
    
    # Create verses table
    cursor.execute("""
        CREATE TABLE verses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            translation_id TEXT NOT NULL,
            book_id INTEGER NOT NULL,
            chapter INTEGER NOT NULL,
            verse INTEGER NOT NULL,
            text TEXT NOT NULL,
            FOREIGN KEY (translation_id) REFERENCES translations(id),
            FOREIGN KEY (book_id) REFERENCES books(id)
        )
    """)
    
    # Create indexes
    cursor.execute("CREATE INDEX idx_verses_lookup ON verses(translation_id, book_id, chapter, verse)")
    cursor.execute("CREATE INDEX idx_books_name ON books(name)")
    
    conn.commit()
    return conn


def insert_metadata(conn):
    """Insert translations and books metadata."""
    cursor = conn.cursor()
    
    # Insert translations
    for abbrev, info in TRANSLATIONS.items():
        is_default = 1 if abbrev == "BSB" else 0
        cursor.execute(
            "INSERT INTO translations (id, name, abbreviation, year, is_default) VALUES (?, ?, ?, ?, ?)",
            (abbrev, info["name"], abbrev, info["year"], is_default)
        )
    
    # Insert books with aliases
    for book in BOOKS:
        aliases = BOOK_ALIASES.get(book["name"], [])
        aliases_json = json.dumps(aliases)
        cursor.execute(
            "INSERT INTO books (id, name, abbreviation, testament, chapters, aliases) VALUES (?, ?, ?, ?, ?, ?)",
            (book["id"], book["name"], book["abbrev"], book["testament"], book["chapters"], aliases_json)
        )
    
    conn.commit()
    print(f"Inserted {len(TRANSLATIONS)} translations and {len(BOOKS)} books")


def fetch_bible_text(translation_source, book_id, chapter):
    """Fetch Bible text from HelloAO API."""
    # Map our book IDs to the API format
    book = next((b for b in BOOKS if b["id"] == book_id), None)
    if not book:
        return []
    
    # HelloAO API endpoint
    # Format: https://bible.helloao.org/api/{translation}/{book}/{chapter}.json
    api_book_name = book["name"].replace(" ", "%20")
    
    url = f"https://bible.helloao.org/api/{translation_source}/{api_book_name}/{chapter}.json"
    
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            data = json.loads(response.read().decode())
            
            # Extract verses from response
            verses = []
            if "chapter" in data and "content" in data["chapter"]:
                for item in data["chapter"]["content"]:
                    if item.get("type") == "verse":
                        verse_num = item.get("number", 0)
                        verse_text = extract_verse_text(item.get("content", []))
                        if verse_num and verse_text:
                            verses.append((verse_num, verse_text.strip()))
            
            return verses
    except Exception as e:
        # Silently skip errors to avoid cluttering output
        return []


def extract_verse_text(content_list):
    """Recursively extract text from verse content."""
    text = ""
    for item in content_list:
        if isinstance(item, str):
            text += item
        elif isinstance(item, dict):
            if "text" in item:
                text += item["text"]
            if "content" in item:
                text += extract_verse_text(item["content"])
    return text


def download_translation(conn, translation_id, translation_source):
    """Download all verses for a translation."""
    cursor = conn.cursor()
    total_verses = 0
    
    print(f"\nDownloading {translation_id}...")
    
    for book in BOOKS:
        book_verses = 0
        for chapter in range(1, book["chapters"] + 1):
            verses = fetch_bible_text(translation_source, book["id"], chapter)
            
            for verse_num, verse_text in verses:
                cursor.execute(
                    "INSERT INTO verses (translation_id, book_id, chapter, verse, text) VALUES (?, ?, ?, ?, ?)",
                    (translation_id, book["id"], chapter, verse_num, verse_text)
                )
                book_verses += 1
            
            # Progress indicator
            if chapter % 10 == 0:
                print(f"  {book['name']}: {chapter}/{book['chapters']} chapters", end="\r")
        
        total_verses += book_verses
        print(f"  {book['name']}: {book_verses} verses                    ")
    
    conn.commit()
    print(f"  Total: {total_verses} verses")
    return total_verses


def main():
    print("=" * 60)
    print("Divine Link Bible Database Builder")
    print("=" * 60)
    
    print(f"\nCreating database at: {OUTPUT_DB}")
    conn = create_database()
    
    print("\nInserting metadata...")
    insert_metadata(conn)
    
    print("\nDownloading Bible translations...")
    print("This may take several minutes...")
    
    total = 0
    for abbrev, info in TRANSLATIONS.items():
        count = download_translation(conn, abbrev, info["source"])
        total += count
    
    conn.close()
    
    # Get file size
    size_bytes = os.path.getsize(OUTPUT_DB)
    size_mb = size_bytes / (1024 * 1024)
    
    print("\n" + "=" * 60)
    print("Database created successfully!")
    print(f"  Location: {OUTPUT_DB}")
    print(f"  Total verses: {total}")
    print(f"  File size: {size_mb:.2f} MB")
    print("=" * 60)
    print("\nNext steps:")
    print("1. Open DivineLink.xcodeproj in Xcode")
    print("2. Drag Bible.db into the Resources folder")
    print("3. Ensure 'Copy items if needed' is checked")
    print("4. Build and run the app")


if __name__ == "__main__":
    main()
