import Foundation
import SQLite3

// MARK: - Service Archive

/// Manages persistent storage of service sessions using SQLite
class ServiceArchive {
    
    // MARK: - Singleton
    
    static let shared = ServiceArchive()
    
    // MARK: - Properties
    
    private var db: OpaquePointer?
    private let retentionDays = 90
    private let dbName = "ServiceHistory.db"
    
    // MARK: - Initialisation
    
    private init() {
        openDatabase()
        createTables()
        performCleanup()
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    // MARK: - Database Setup
    
    private func openDatabase() {
        let fileManager = FileManager.default
        
        // Use Application Support directory
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("[ServiceArchive] Failed to find Application Support directory")
            return
        }
        
        let appFolder = appSupport.appendingPathComponent("DivineLink", isDirectory: true)
        
        // Create app folder if needed
        try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        let dbPath = appFolder.appendingPathComponent(dbName).path
        
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("[ServiceArchive] Error opening database: \(String(cString: sqlite3_errmsg(db)))")
        } else {
            print("[ServiceArchive] Database opened at: \(dbPath)")
        }
    }
    
    private func createTables() {
        let createSessionsSQL = """
            CREATE TABLE IF NOT EXISTS service_sessions (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                service_type TEXT NOT NULL,
                date TEXT NOT NULL,
                pastor_id TEXT,
                start_time TEXT NOT NULL,
                end_time TEXT,
                transcript_snippets TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            );
            """
        
        let createScripturesSQL = """
            CREATE TABLE IF NOT EXISTS detected_scriptures (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                reference TEXT NOT NULL,
                verse_text TEXT,
                translation TEXT,
                timestamp TEXT NOT NULL,
                was_pushed INTEGER DEFAULT 0,
                raw_transcript TEXT,
                confidence REAL,
                FOREIGN KEY (session_id) REFERENCES service_sessions(id) ON DELETE CASCADE
            );
            """
        
        let createIndexSQL = """
            CREATE INDEX IF NOT EXISTS idx_sessions_date ON service_sessions(date);
            """
        
        executeSQL(createSessionsSQL)
        executeSQL(createScripturesSQL)
        executeSQL(createIndexSQL)
    }
    
    private func executeSQL(_ sql: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let errMsg = errMsg {
                print("[ServiceArchive] SQL Error: \(String(cString: errMsg))")
                sqlite3_free(errMsg)
            }
        }
    }
    
    // MARK: - Save Session
    
    /// Save a completed session to the archive
    func save(_ session: ServiceSession) {
        guard session.endTime != nil else {
            print("[ServiceArchive] Cannot save active session")
            return
        }
        
        let formatter = ISO8601DateFormatter()
        
        let insertSessionSQL = """
            INSERT OR REPLACE INTO service_sessions 
            (id, name, service_type, date, pastor_id, start_time, end_time, transcript_snippets)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """
        
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSessionSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, session.id.uuidString, -1, nil)
            sqlite3_bind_text(stmt, 2, session.name, -1, nil)
            sqlite3_bind_text(stmt, 3, session.serviceType, -1, nil)
            sqlite3_bind_text(stmt, 4, formatter.string(from: session.date), -1, nil)
            
            if let pastorId = session.pastorId {
                sqlite3_bind_text(stmt, 5, pastorId.uuidString, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 5)
            }
            
            sqlite3_bind_text(stmt, 6, formatter.string(from: session.startTime), -1, nil)
            
            if let endTime = session.endTime {
                sqlite3_bind_text(stmt, 7, formatter.string(from: endTime), -1, nil)
            } else {
                sqlite3_bind_null(stmt, 7)
            }
            
            // Encode transcript snippets as JSON
            if let snippetsData = try? JSONEncoder().encode(session.transcriptSnippets),
               let snippetsString = String(data: snippetsData, encoding: .utf8) {
                sqlite3_bind_text(stmt, 8, snippetsString, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 8)
            }
            
            if sqlite3_step(stmt) != SQLITE_DONE {
                print("[ServiceArchive] Error saving session: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
        sqlite3_finalize(stmt)
        
        // Save detected scriptures
        for scripture in session.detectedScriptures {
            saveScripture(scripture, sessionId: session.id)
        }
        
        print("[ServiceArchive] Saved session: \(session.name)")
    }
    
    private func saveScripture(_ scripture: DetectedScripture, sessionId: UUID) {
        let formatter = ISO8601DateFormatter()
        
        let insertSQL = """
            INSERT OR REPLACE INTO detected_scriptures 
            (id, session_id, reference, verse_text, translation, timestamp, was_pushed, raw_transcript, confidence)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, scripture.id.uuidString, -1, nil)
            sqlite3_bind_text(stmt, 2, sessionId.uuidString, -1, nil)
            sqlite3_bind_text(stmt, 3, scripture.reference, -1, nil)
            sqlite3_bind_text(stmt, 4, scripture.verseText, -1, nil)
            sqlite3_bind_text(stmt, 5, scripture.translation, -1, nil)
            sqlite3_bind_text(stmt, 6, formatter.string(from: scripture.timestamp), -1, nil)
            sqlite3_bind_int(stmt, 7, scripture.wasPushed ? 1 : 0)
            sqlite3_bind_text(stmt, 8, scripture.rawTranscript, -1, nil)
            sqlite3_bind_double(stmt, 9, Double(scripture.confidence))
            
            if sqlite3_step(stmt) != SQLITE_DONE {
                print("[ServiceArchive] Error saving scripture: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
        sqlite3_finalize(stmt)
    }
    
    // MARK: - Load Sessions
    
    /// Load all archived sessions
    func loadAll() -> [ServiceSession] {
        var sessions: [ServiceSession] = []
        let formatter = ISO8601DateFormatter()
        
        let querySQL = """
            SELECT id, name, service_type, date, pastor_id, start_time, end_time, transcript_snippets
            FROM service_sessions
            ORDER BY date DESC;
            """
        
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let idStr = sqlite3_column_text(stmt, 0),
                      let nameStr = sqlite3_column_text(stmt, 1),
                      let typeStr = sqlite3_column_text(stmt, 2),
                      let dateStr = sqlite3_column_text(stmt, 3),
                      let startStr = sqlite3_column_text(stmt, 5) else {
                    continue
                }
                
                let id = UUID(uuidString: String(cString: idStr)) ?? UUID()
                let name = String(cString: nameStr)
                let serviceType = String(cString: typeStr)
                let date = formatter.date(from: String(cString: dateStr)) ?? Date()
                // Note: startTime/endTime are auto-set by ServiceSession init
                // We parse but don't use them since the model auto-generates
                _ = formatter.date(from: String(cString: startStr)) // startTime (unused)
                
                var pastorId: UUID?
                if let pastorStr = sqlite3_column_text(stmt, 4) {
                    pastorId = UUID(uuidString: String(cString: pastorStr))
                }
                
                // Parse endTime but session model manages this
                if let endStr = sqlite3_column_text(stmt, 6) {
                    _ = formatter.date(from: String(cString: endStr)) // endTime (unused)
                }
                
                var snippets: [String] = []
                if let snippetsStr = sqlite3_column_text(stmt, 7),
                   let data = String(cString: snippetsStr).data(using: .utf8),
                   let decoded = try? JSONDecoder().decode([String].self, from: data) {
                    snippets = decoded
                }
                
                var session = ServiceSession(
                    id: id,
                    name: name,
                    serviceType: serviceType,
                    date: date,
                    pastorId: pastorId
                )
                
                // Load scriptures for this session
                session.detectedScriptures = loadScriptures(for: id)
                session.transcriptSnippets = snippets
                
                sessions.append(session)
            }
        }
        sqlite3_finalize(stmt)
        
        return sessions
    }
    
    private func loadScriptures(for sessionId: UUID) -> [DetectedScripture] {
        var scriptures: [DetectedScripture] = []
        let formatter = ISO8601DateFormatter()
        
        let querySQL = """
            SELECT id, reference, verse_text, translation, timestamp, was_pushed, raw_transcript, confidence
            FROM detected_scriptures
            WHERE session_id = ?
            ORDER BY timestamp;
            """
        
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, sessionId.uuidString, -1, nil)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let refStr = sqlite3_column_text(stmt, 1),
                      let timestampStr = sqlite3_column_text(stmt, 4) else {
                    continue
                }
                
                let reference = String(cString: refStr)
                let verseText = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
                let translation = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "KJV"
                // Note: timestamp parsed but not used - DetectedScripture auto-sets it
                _ = formatter.date(from: String(cString: timestampStr)) // stored timestamp
                let wasPushed = sqlite3_column_int(stmt, 5) == 1
                let rawTranscript = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? ""
                let confidence = Float(sqlite3_column_double(stmt, 7))
                
                var scripture = DetectedScripture(
                    reference: reference,
                    verseText: verseText,
                    translation: translation,
                    rawTranscript: rawTranscript,
                    confidence: confidence
                )
                scripture.wasPushed = wasPushed
                
                scriptures.append(scripture)
            }
        }
        sqlite3_finalize(stmt)
        
        return scriptures
    }
    
    // MARK: - Cleanup
    
    /// Delete sessions older than retention period
    func performCleanup() {
        guard let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) else {
            return
        }
        
        let formatter = ISO8601DateFormatter()
        let cutoffString = formatter.string(from: cutoffDate)
        
        // First get count for logging
        let countSQL = "SELECT COUNT(*) FROM service_sessions WHERE date < ?;"
        var countStmt: OpaquePointer?
        var deleteCount = 0
        
        if sqlite3_prepare_v2(db, countSQL, -1, &countStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(countStmt, 1, cutoffString, -1, nil)
            if sqlite3_step(countStmt) == SQLITE_ROW {
                deleteCount = Int(sqlite3_column_int(countStmt, 0))
            }
        }
        sqlite3_finalize(countStmt)
        
        if deleteCount > 0 {
            // Delete scriptures first (foreign key)
            let deleteScripturesSQL = """
                DELETE FROM detected_scriptures 
                WHERE session_id IN (SELECT id FROM service_sessions WHERE date < ?);
                """
            var scriptureStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, deleteScripturesSQL, -1, &scriptureStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(scriptureStmt, 1, cutoffString, -1, nil)
                sqlite3_step(scriptureStmt)
            }
            sqlite3_finalize(scriptureStmt)
            
            // Delete sessions
            let deleteSessionsSQL = "DELETE FROM service_sessions WHERE date < ?;"
            var sessionStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, deleteSessionsSQL, -1, &sessionStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(sessionStmt, 1, cutoffString, -1, nil)
                sqlite3_step(sessionStmt)
            }
            sqlite3_finalize(sessionStmt)
            
            print("[ServiceArchive] Cleaned up \(deleteCount) sessions older than \(retentionDays) days")
        }
    }
    
    // MARK: - Export
    
    /// Export a session to JSON file
    func exportToJSON(_ session: ServiceSession) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(session) else {
            print("[ServiceArchive] Failed to encode session")
            return nil
        }
        
        let fileName = "\(session.name.replacingOccurrences(of: " ", with: "_")).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempURL)
            print("[ServiceArchive] Exported to: \(tempURL.path)")
            return tempURL
        } catch {
            print("[ServiceArchive] Export failed: \(error)")
            return nil
        }
    }
    
    /// Export a session to CSV file
    func exportToCSV(_ session: ServiceSession) -> URL? {
        var csv = "Reference,Verse Text,Translation,Timestamp,Was Pushed,Raw Transcript,Confidence\n"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for scripture in session.detectedScriptures {
            let row = [
                scripture.reference,
                scripture.verseText.replacingOccurrences(of: "\"", with: "\"\""),
                scripture.translation,
                formatter.string(from: scripture.timestamp),
                scripture.wasPushed ? "Yes" : "No",
                scripture.rawTranscript.replacingOccurrences(of: "\"", with: "\"\""),
                String(format: "%.0f%%", scripture.confidence * 100)
            ].map { "\"\($0)\"" }.joined(separator: ",")
            
            csv += row + "\n"
        }
        
        let fileName = "\(session.name.replacingOccurrences(of: " ", with: "_")).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            print("[ServiceArchive] Exported to: \(tempURL.path)")
            return tempURL
        } catch {
            print("[ServiceArchive] Export failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Statistics
    
    /// Get storage usage info
    func getStorageInfo() -> (sessionCount: Int, scriptureCount: Int, sizeBytes: Int64) {
        var sessionCount = 0
        var scriptureCount = 0
        var sizeBytes: Int64 = 0
        
        // Count sessions
        let sessionSQL = "SELECT COUNT(*) FROM service_sessions;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sessionSQL, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                sessionCount = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        
        // Count scriptures
        let scriptureSQL = "SELECT COUNT(*) FROM detected_scriptures;"
        if sqlite3_prepare_v2(db, scriptureSQL, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                scriptureCount = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        
        // Get file size
        let fileManager = FileManager.default
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dbPath = appSupport
                .appendingPathComponent("DivineLink")
                .appendingPathComponent(dbName)
            
            if let attrs = try? fileManager.attributesOfItem(atPath: dbPath.path) {
                sizeBytes = attrs[.size] as? Int64 ?? 0
            }
        }
        
        return (sessionCount, scriptureCount, sizeBytes)
    }
}
