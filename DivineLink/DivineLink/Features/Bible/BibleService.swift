import Foundation
import SQLite3
import Combine

// MARK: - Bible Errors

enum BibleError: LocalizedError {
    case databaseNotFound
    case databaseOpenFailed(String)
    case queryFailed(String)
    case bookNotFound(String)
    case verseNotFound
    
    var errorDescription: String? {
        switch self {
        case .databaseNotFound:
            return "Bible database not found in app bundle"
        case .databaseOpenFailed(let message):
            return "Failed to open Bible database: \(message)"
        case .queryFailed(let message):
            return "Database query failed: \(message)"
        case .bookNotFound(let name):
            return "Book not found: \(name)"
        case .verseNotFound:
            return "Verse not found"
        }
    }
}

// MARK: - Bible Book Model

struct BibleBook: Identifiable {
    let id: Int
    let name: String
    let aliases: [String]
    let testament: String  // "OT" or "NT"
    let chapters: Int
}

// MARK: - Bible Verse Model

struct BibleVerse: Identifiable {
    let id: Int
    let bookId: Int
    let bookName: String
    let chapter: Int
    let verse: Int
    let text: String
    
    /// Formatted reference e.g. "John 3:16"
    var reference: String {
        "\(bookName) \(chapter):\(verse)"
    }
}

// MARK: - Scripture Reference (for detection)

struct ScriptureReference: Equatable {
    let book: String
    let chapter: Int
    let verseStart: Int
    let verseEnd: Int?
    
    /// Formatted reference string
    var formatted: String {
        if let end = verseEnd, end != verseStart {
            return "\(book) \(chapter):\(verseStart)-\(end)"
        }
        return "\(book) \(chapter):\(verseStart)"
    }
    
    /// Check if this is a verse range
    var isRange: Bool {
        verseEnd != nil && verseEnd != verseStart
    }
}

// MARK: - Bible Service

/// Service for looking up Bible verses from the local SQLite database
@MainActor
class BibleService: ObservableObject {
    
    // MARK: - Properties
    
    private var db: OpaquePointer?
    @Published var isLoaded = false
    @Published var error: BibleError?
    
    // Cache for book lookups
    private var bookCache: [String: Int] = [:]
    private var allBooks: [BibleBook] = []
    
    // MARK: - Initialisation
    
    init() {
        Task {
            await loadDatabase()
        }
    }
    
    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
    
    // MARK: - Database Loading
    
    private func loadDatabase() async {
        // Try to find the database in the bundle
        guard let dbPath = Bundle.main.path(forResource: "Bible", ofType: "db") else {
            // Database not yet bundled - this is expected during development
            print("Bible database not found in bundle - will use placeholder data")
            isLoaded = false
            return
        }
        
        var dbPointer: OpaquePointer?
        let result = sqlite3_open_v2(dbPath, &dbPointer, SQLITE_OPEN_READONLY, nil)
        
        if result != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(dbPointer))
            error = .databaseOpenFailed(message)
            sqlite3_close(dbPointer)
            return
        }
        
        db = dbPointer
        
        // Load book cache
        await loadBookCache()
        
        isLoaded = true
    }
    
    private func loadBookCache() async {
        guard let db = db else { return }
        
        let query = "SELECT id, name, aliases FROM books"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return
        }
        
        defer { sqlite3_finalize(statement) }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            
            if let namePtr = sqlite3_column_text(statement, 1) {
                let name = String(cString: namePtr)
                bookCache[name.lowercased()] = id
                
                // Parse aliases from JSON if available
                if let aliasPtr = sqlite3_column_text(statement, 2) {
                    let aliasJson = String(cString: aliasPtr)
                    if let data = aliasJson.data(using: .utf8),
                       let aliases = try? JSONDecoder().decode([String].self, from: data) {
                        for alias in aliases {
                            bookCache[alias.lowercased()] = id
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Verse Lookup
    
    /// Get a single verse by reference
    func getVerse(book: String, chapter: Int, verse: Int) -> BibleVerse? {
        guard let db = db else { return nil }
        
        guard let bookId = findBookId(name: book) else {
            return nil
        }
        
        let query = """
            SELECT v.id, v.text, b.name 
            FROM verses v 
            JOIN books b ON v.book_id = b.id 
            WHERE v.book_id = ? AND v.chapter = ? AND v.verse = ?
            """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_int(statement, 1, Int32(bookId))
        sqlite3_bind_int(statement, 2, Int32(chapter))
        sqlite3_bind_int(statement, 3, Int32(verse))
        
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }
        
        let id = Int(sqlite3_column_int(statement, 0))
        let text = String(cString: sqlite3_column_text(statement, 1))
        let bookName = String(cString: sqlite3_column_text(statement, 2))
        
        return BibleVerse(
            id: id,
            bookId: bookId,
            bookName: bookName,
            chapter: chapter,
            verse: verse,
            text: text
        )
    }
    
    /// Get a range of verses
    func getVerseRange(book: String, chapter: Int, startVerse: Int, endVerse: Int) -> [BibleVerse] {
        guard let db = db else { return [] }
        
        guard let bookId = findBookId(name: book) else {
            return []
        }
        
        let query = """
            SELECT v.id, v.verse, v.text, b.name 
            FROM verses v 
            JOIN books b ON v.book_id = b.id 
            WHERE v.book_id = ? AND v.chapter = ? AND v.verse >= ? AND v.verse <= ?
            ORDER BY v.verse
            """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_int(statement, 1, Int32(bookId))
        sqlite3_bind_int(statement, 2, Int32(chapter))
        sqlite3_bind_int(statement, 3, Int32(startVerse))
        sqlite3_bind_int(statement, 4, Int32(endVerse))
        
        var verses: [BibleVerse] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let verse = Int(sqlite3_column_int(statement, 1))
            let text = String(cString: sqlite3_column_text(statement, 2))
            let bookName = String(cString: sqlite3_column_text(statement, 3))
            
            verses.append(BibleVerse(
                id: id,
                bookId: bookId,
                bookName: bookName,
                chapter: chapter,
                verse: verse,
                text: text
            ))
        }
        
        return verses
    }
    
    /// Get verse(s) from a scripture reference
    func getVerses(from reference: ScriptureReference) -> [BibleVerse] {
        if let endVerse = reference.verseEnd, endVerse != reference.verseStart {
            return getVerseRange(
                book: reference.book,
                chapter: reference.chapter,
                startVerse: reference.verseStart,
                endVerse: endVerse
            )
        } else {
            if let verse = getVerse(book: reference.book, chapter: reference.chapter, verse: reference.verseStart) {
                return [verse]
            }
            return []
        }
    }
    
    /// Combine verses into a single text string
    func getVerseText(from reference: ScriptureReference) -> String? {
        let verses = getVerses(from: reference)
        guard !verses.isEmpty else { return nil }
        
        return verses.map { $0.text }.joined(separator: " ")
    }
    
    // MARK: - Book Lookup
    
    private func findBookId(name: String) -> Int? {
        // Check cache first
        if let id = bookCache[name.lowercased()] {
            return id
        }
        
        // Try partial match
        let lowerName = name.lowercased()
        for (key, id) in bookCache {
            if key.hasPrefix(lowerName) || lowerName.hasPrefix(key) {
                return id
            }
        }
        
        return nil
    }
    
    /// Get all book names for speech recognition vocabulary
    func getAllBookNames() -> [String] {
        return Array(bookCache.keys)
    }
}

// MARK: - Placeholder Data (for development without database)

extension BibleService {
    /// Returns placeholder verse for testing when database is not loaded
    func getPlaceholderVerse(for reference: ScriptureReference) -> BibleVerse {
        return BibleVerse(
            id: 0,
            bookId: 0,
            bookName: reference.book,
            chapter: reference.chapter,
            verse: reference.verseStart,
            text: "[Verse text for \(reference.formatted) - database not loaded]"
        )
    }
}
