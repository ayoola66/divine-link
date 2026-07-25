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

// MARK: - Translation Model

/// Access tier for a translation — drives the 3-tier gate.
/// - `.free`: available to everyone, no login (KJV/WEB/ASV).
/// - `.registered`: unlocked by registering an email, still free (BSB/LSV — bundled, no download).
/// - `.premium`: requires a paid subscription (the downloadable versions).
enum AccessTier: String {
    case free
    case registered
    case premium
}

/// A Bible translation available in the app, backed by the `translations` metadata table.
/// Drives the dynamic (tier-aware) version list — no more hardcoded arrays.
struct Translation: Identifiable, Equatable {
    let id: String          // abbreviation, e.g. "KJV" (matches verses.translation_id)
    let name: String        // full name, e.g. "King James Version"
    let year: Int
    let isDefault: Bool
    let isPremium: Bool
    let isPublicDomain: Bool
    let requiresAttribution: Bool
    let attributionText: String?
    let verseCount: Int
    let sortOrder: Int
    var accessTier: AccessTier = .free
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
    @Published var isLoading = true  // Shows loading state
    @Published var loadingProgress: String = "Initialising..."
    @Published var error: BibleError?
    /// Translation abbreviations that actually have verses installed (e.g. ["KJV","WEB","ASV"]).
    /// Populated from the `translations` metadata table at load — never hardcoded.
    @Published var availableTranslations: [String] = []
    /// Full metadata for each available translation (free/premium, attribution, etc.),
    /// ordered by `sort_order`. The UI reads this to build the version switcher.
    @Published var translations: [Translation] = []
    
    // Current translation (reads from UserDefaults)
    var currentTranslation: String {
        UserDefaults.standard.string(forKey: "selectedTranslation") ?? "KJV"
    }
    
    // Cache for book lookups
    private var bookCache: [String: Int] = [:]
    private var allBooks: [BibleBook] = []
    
    // Cache for chapter counts per book (for validation)
    private var bookChapterCounts: [Int: Int] = [:]

    /// Maps a translation_id to the SQLite schema that holds its verses:
    /// "main" for bundled versions, "db_<ID>" for downloaded versions ATTACHed at runtime.
    private var translationSchema: [String: String] = [:]
    private var cancellables = Set<AnyCancellable>()
    
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
        isLoading = true
        loadingProgress = "Looking for Bible database..."
        
        // Try to find the database in the bundle
        guard let dbPath = Bundle.main.path(forResource: "Bible", ofType: "db") else {
            // Database not yet bundled - this is expected during development
            print("❌ Bible database not found in bundle - will use placeholder data")
            print("   Bundle path: \(Bundle.main.bundlePath)")
            loadingProgress = "Database not found"
            isLoaded = false
            isLoading = false
            return
        }
        
        loadingProgress = "Opening database..."
        print("✅ Bible database found at: \(dbPath)")
        
        var dbPointer: OpaquePointer?
        let result = sqlite3_open_v2(dbPath, &dbPointer, SQLITE_OPEN_READONLY, nil)
        
        if result != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(dbPointer))
            print("❌ Failed to open Bible database: \(message)")
            error = .databaseOpenFailed(message)
            loadingProgress = "Failed to open database"
            isLoading = false
            sqlite3_close(dbPointer)
            return
        }
        
        db = dbPointer
        
        // ATTACH any downloaded premium version files, then enumerate all versions
        loadingProgress = "Loading translations..."
        attachDownloadedVersions()
        loadTranslations()
        observeVersionChanges()

        // Load book cache
        loadingProgress = "Loading book index..."
        await loadBookCache()
        
        // Verify data exists
        loadingProgress = "Verifying verses..."
        let verseCount = countVerses()
        
        print("✅ Bible database loaded successfully. Books cached: \(bookCache.count), Verses: \(verseCount)")
        loadingProgress = "Ready - \(verseCount) verses"
        isLoaded = verseCount > 0
        isLoading = false
    }
    
    /// Count total verses in database
    private func countVerses() -> Int {
        guard let db = db else { return 0 }
        
        let translation = currentTranslation
        let query = "SELECT COUNT(*) FROM verses WHERE translation_id = '\(translation)'"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return 0
        }
        
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            return Int(sqlite3_column_int(statement, 0))
        }
        return 0
    }
    
    /// Load available translations from the `translations` metadata table (Phase 0).
    /// Only versions that actually have verses appear (the migration removes empty rows and
    /// sets verse_count from real data). Falls back to a KJV-only list if the table can't be
    /// read, so the app is never left with an empty picker.
    private func loadTranslations() {
        guard let db = db else { return }

        let query = """
            SELECT id, name, year, is_default, is_premium, is_public_domain,
                   requires_attribution, attribution_text, verse_count, sort_order
            FROM translations
            WHERE verse_count > 0
            ORDER BY sort_order, name
        """
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("⚠️ [Bible] Could not read translations table — defaulting to KJV")
            availableTranslations = ["KJV"]
            translations = []
            return
        }
        defer { sqlite3_finalize(statement) }

        var loaded: [Translation] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idPtr = sqlite3_column_text(statement, 0),
                  let namePtr = sqlite3_column_text(statement, 1) else { continue }
            let attribution = sqlite3_column_text(statement, 7).map { String(cString: $0) }
            let isPremium = sqlite3_column_int(statement, 4) == 1
            // Bundled premium versions (BSB/LSV) are the REGISTERED-tier reward (unlocked by
            // registering an email, still free). Bundled non-premium are fully free.
            loaded.append(Translation(
                id: String(cString: idPtr),
                name: String(cString: namePtr),
                year: Int(sqlite3_column_int(statement, 2)),
                isDefault: sqlite3_column_int(statement, 3) == 1,
                isPremium: isPremium,
                isPublicDomain: sqlite3_column_int(statement, 5) == 1,
                requiresAttribution: sqlite3_column_int(statement, 6) == 1,
                attributionText: attribution,
                verseCount: Int(sqlite3_column_int(statement, 8)),
                sortOrder: Int(sqlite3_column_int(statement, 9)),
                accessTier: isPremium ? .registered : .free
            ))
        }

        // Bundled versions live in main.
        for t in loaded { translationSchema[t.id] = "main" }

        // Append downloaded versions that are ATTACHed (their metadata lives in their own
        // version_meta table). These sit after the bundled ones by sort order.
        var all = loaded
        for (id, schema) in translationSchema where schema != "main" {
            if all.contains(where: { $0.id == id }) { continue }
            if let meta = readAttachedMeta(schema: schema, id: id) { all.append(meta) }
        }
        all.sort { $0.sortOrder < $1.sortOrder }

        if all.isEmpty {
            // Table missing/empty (older DB) — fall back so the picker is never blank.
            availableTranslations = ["KJV"]
            translations = []
            print("⚠️ [Bible] translations table empty — defaulting to KJV")
        } else {
            translations = all
            availableTranslations = all.map { $0.id }
            print("📚 [Bible] Loaded \(all.count) translations: \(availableTranslations.joined(separator: ", "))")
        }
    }

    /// Read a downloaded version's metadata from its ATTACHed `version_meta` table.
    private func readAttachedMeta(schema: String, id: String) -> Translation? {
        guard let db = db else { return nil }
        let q = "SELECT name, year, verse_count, requires_attribution, attribution_text FROM \(schema).version_meta WHERE id = '\(id)'"
        var st: OpaquePointer?
        guard sqlite3_prepare_v2(db, q, -1, &st, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(st) }
        guard sqlite3_step(st) == SQLITE_ROW, let namePtr = sqlite3_column_text(st, 0) else { return nil }
        let attribution = sqlite3_column_text(st, 4).map { String(cString: $0) }
        return Translation(
            id: id,
            name: String(cString: namePtr),
            year: Int(sqlite3_column_int(st, 1)),
            isDefault: false,
            isPremium: true,   // downloadable versions are premium
            isPublicDomain: true,
            requiresAttribution: sqlite3_column_int(st, 3) == 1,
            attributionText: attribution,
            verseCount: Int(sqlite3_column_int(st, 2)),
            sortOrder: 100 + (translationSchema.keys.sorted().firstIndex(of: id) ?? 0),
            accessTier: .premium   // downloaded versions require a paid subscription
        )
    }

    /// Sync ATTACHed downloaded-version files to what's actually on disk: attach newly-downloaded
    /// files, detach any whose file was deleted. Sets/clears `translationSchema` "db_<ID>" entries.
    /// Safe to call repeatedly.
    private func attachDownloadedVersions() {
        guard let db = db else { return }
        let installed = Dictionary(uniqueKeysWithValues: BibleVersionManager.installedFiles().map { ($0.id, $0.url) })

        // Detach versions whose file is gone.
        for (id, schema) in translationSchema where schema != "main" {
            if installed[id] == nil {
                if sqlite3_exec(db, "DETACH DATABASE \(schema)", nil, nil, nil) == SQLITE_OK {
                    print("📎 [Bible] Detached removed version \(id)")
                }
                translationSchema[id] = nil
            }
        }

        // Attach newly-downloaded files.
        for (id, url) in installed {
            let alias = "db_\(id)"
            if translationSchema[id] == alias { continue } // already attached
            let safePath = url.path.replacingOccurrences(of: "'", with: "''")
            if sqlite3_exec(db, "ATTACH DATABASE '\(safePath)' AS \(alias)", nil, nil, nil) == SQLITE_OK {
                translationSchema[id] = alias
                print("📎 [Bible] Attached downloaded version \(id)")
            } else {
                print("⚠️ [Bible] Failed to attach \(id): \(String(cString: sqlite3_errmsg(db)))")
            }
        }
    }

    /// Re-attach + refresh the version list whenever a download completes or a version is deleted.
    private func observeVersionChanges() {
        BibleVersionManager.shared.installedDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                self.attachDownloadedVersions()
                self.loadTranslations()
            }
            .store(in: &cancellables)
    }

    /// Schema-qualified `verses` table reference for a translation ("verses" or "db_<ID>.verses").
    private func versesRef(for translation: String) -> String {
        if let schema = translationSchema[translation], schema != "main" {
            return "\(schema).verses"
        }
        return "verses"
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
        
        // Also load chapter counts for validation
        await loadChapterCounts()
    }
    
    private func loadChapterCounts() async {
        guard let db = db else { return }
        
        // Get max chapter for each book
        let query = "SELECT book_id, MAX(chapter) as max_chapter FROM verses GROUP BY book_id"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return
        }
        
        defer { sqlite3_finalize(statement) }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let bookId = Int(sqlite3_column_int(statement, 0))
            let maxChapter = Int(sqlite3_column_int(statement, 1))
            bookChapterCounts[bookId] = maxChapter
        }
        
        print("📖 Loaded chapter counts for \(bookChapterCounts.count) books")
    }
    
    /// Validate if a chapter exists for a book
    func isValidChapter(bookId: Int, chapter: Int) -> Bool {
        guard let maxChapter = bookChapterCounts[bookId] else {
            return true  // If we don't have data, allow it through
        }
        return chapter >= 1 && chapter <= maxChapter
    }
    
    /// Get max chapter for a book
    func getMaxChapter(for bookId: Int) -> Int? {
        return bookChapterCounts[bookId]
    }
    
    // MARK: - Verse Lookup
    
    /// Get a single verse by reference.
    /// Pass `translation` to override the global selection (per-card version switching).
    func getVerse(book: String, chapter: Int, verse: Int, translation translationOverride: String? = nil) -> BibleVerse? {
        guard let db = db else { 
            print("❌ getVerse: Database not open")
            return nil 
        }
        
        guard let bookId = findBookId(name: book) else {
            print("❌ getVerse: Book not found: \(book)")
            return nil
        }
        
        // Validate chapter exists for this book
        if !isValidChapter(bookId: bookId, chapter: chapter) {
            let maxChapter = bookChapterCounts[bookId] ?? 0
            print("❌ getVerse: Invalid chapter \(chapter) for \(book) (max: \(maxChapter))")
            return nil
        }
        
        let translation = translationOverride ?? currentTranslation
        print("🔍 Looking up: \(book) \(chapter):\(verse) (\(translation)) bookId=\(bookId)")
        
        // Use parameterised query with translation embedded to avoid C string issues.
        // verses may live in main (bundled) or an ATTACHed db_<ID> (downloaded); books is in main.
        let query = """
            SELECT v.id, v.text, b.name
            FROM \(versesRef(for: translation)) v
            JOIN books b ON v.book_id = b.id
            WHERE v.book_id = ? AND v.chapter = ? AND v.verse = ? AND v.translation_id = '\(translation)'
            """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ getVerse: Failed to prepare statement")
            return nil
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_int(statement, 1, Int32(bookId))
        sqlite3_bind_int(statement, 2, Int32(chapter))
        sqlite3_bind_int(statement, 3, Int32(verse))
        
        guard sqlite3_step(statement) == SQLITE_ROW else {
            print("❌ getVerse: No results for \(book) \(chapter):\(verse) in \(translation)")
            return nil
        }
        
        let id = Int(sqlite3_column_int(statement, 0))
        let text = String(cString: sqlite3_column_text(statement, 1))
        let bookName = String(cString: sqlite3_column_text(statement, 2))
        
        print("✅ Found verse: \(bookName) \(chapter):\(verse)")
        
        return BibleVerse(
            id: id,
            bookId: bookId,
            bookName: bookName,
            chapter: chapter,
            verse: verse,
            text: text
        )
    }
    
    /// Get a range of verses.
    /// Pass `translation` to override the global selection (per-card version switching).
    func getVerseRange(book: String, chapter: Int, startVerse: Int, endVerse: Int, translation translationOverride: String? = nil) -> [BibleVerse] {
        guard let db = db else { return [] }
        
        guard let bookId = findBookId(name: book) else {
            return []
        }
        
        let translation = translationOverride ?? currentTranslation
        print("📖 getVerseRange: \(book) \(chapter):\(startVerse)-\(endVerse) (\(translation)) bookId=\(bookId)")
        
        // Use GROUP BY to ensure unique verses (in case of duplicates in database).
        // verses may live in main (bundled) or an ATTACHed db_<ID> (downloaded); books is in main.
        let query = """
            SELECT v.id, v.verse, v.text, b.name
            FROM \(versesRef(for: translation)) v
            JOIN books b ON v.book_id = b.id
            WHERE v.book_id = ? AND v.chapter = ? AND v.verse >= ? AND v.verse <= ? AND v.translation_id = '\(translation)'
            GROUP BY v.book_id, v.chapter, v.verse
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
        var seenVerseNumbers = Set<Int>()  // Track to avoid duplicates
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let verseNum = Int(sqlite3_column_int(statement, 1))
            let text = String(cString: sqlite3_column_text(statement, 2))
            let bookName = String(cString: sqlite3_column_text(statement, 3))
            
            // Skip if we've already seen this verse number (duplicate protection)
            guard !seenVerseNumbers.contains(verseNum) else {
                print("⚠️ Skipping duplicate verse \(verseNum) in \(bookName) \(chapter)")
                continue
            }
            seenVerseNumbers.insert(verseNum)
            
            verses.append(BibleVerse(
                id: id,
                bookId: bookId,
                bookName: bookName,
                chapter: chapter,
                verse: verseNum,
                text: text
            ))
        }
        
        print("📖 getVerseRange returned \(verses.count) unique verses")
        return verses
    }
    
    /// Get verse(s) from a scripture reference.
    /// Pass `translation` to override the global selection (per-card version switching).
    func getVerses(from reference: ScriptureReference, translation translationOverride: String? = nil) -> [BibleVerse] {
        if let endVerse = reference.verseEnd, endVerse != reference.verseStart {
            return getVerseRange(
                book: reference.book,
                chapter: reference.chapter,
                startVerse: reference.verseStart,
                endVerse: endVerse,
                translation: translationOverride
            )
        } else {
            if let verse = getVerse(book: reference.book, chapter: reference.chapter, verse: reference.verseStart, translation: translationOverride) {
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
