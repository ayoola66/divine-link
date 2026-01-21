import Foundation
import Combine

// MARK: - Speech Correction Service

/// Applies learned speech corrections to transcripts based on pastor profiles
@MainActor
class SpeechCorrectionService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SpeechCorrectionService()
    
    // MARK: - Properties
    
    @Published var lastAppliedCorrections: [String] = []
    
    private init() {}
    
    // MARK: - Apply Corrections
    
    /// Apply corrections to transcript text
    /// - Parameters:
    ///   - corrections: List of speech corrections to apply
    ///   - text: Original transcript text
    /// - Returns: Corrected text with replacements applied
    func apply(corrections: [SpeechCorrection], to text: String) -> String {
        guard !corrections.isEmpty else { return text }
        
        var result = text
        var appliedCorrections: [String] = []
        
        // Sort by occurrences (most common corrections first for priority)
        let sorted = corrections.sorted { $0.occurrences > $1.occurrences }
        
        for correction in sorted {
            // Skip empty corrections
            guard !correction.heard.isEmpty, !correction.corrected.isEmpty else { continue }
            
            // Check if the heard word exists in text
            if result.localizedCaseInsensitiveContains(correction.heard) {
                // Apply case-insensitive replacement
                let beforeCount = result.count
                result = result.replacingOccurrences(
                    of: correction.heard,
                    with: correction.corrected,
                    options: .caseInsensitive
                )
                
                // Track if replacement was made
                if result.count != beforeCount || !result.localizedCaseInsensitiveContains(correction.heard) {
                    appliedCorrections.append("\(correction.heard) → \(correction.corrected)")
                }
            }
        }
        
        lastAppliedCorrections = appliedCorrections
        
        if !appliedCorrections.isEmpty {
            print("[SpeechCorrection] Applied \(appliedCorrections.count) correction(s): \(appliedCorrections.joined(separator: ", "))")
        }
        
        return result
    }
    
    // MARK: - Suggestion Detection
    
    /// Analyse transcript to suggest possible corrections
    /// - Parameters:
    ///   - rawTranscript: What was heard
    ///   - manualReference: What operator manually entered
    /// - Returns: Suggested correction if a pattern is found
    func suggestCorrection(rawTranscript: String, manualReference: String) -> SuggestedCorrection? {
        // Extract book name from manual reference
        let manualWords = manualReference.components(separatedBy: .whitespaces)
        guard let manualBook = extractBookName(from: manualWords) else { return nil }
        
        // Find words in raw transcript that might be misheard book names
        let rawWords = rawTranscript.components(separatedBy: .whitespaces)
        
        for rawWord in rawWords {
            // Skip numbers and very short words
            guard rawWord.count >= 3, !rawWord.allSatisfy({ $0.isNumber }) else { continue }
            
            // Check if this word sounds similar to the correct book name
            if isSimilar(rawWord, to: manualBook) {
                return SuggestedCorrection(
                    heard: rawWord,
                    corrected: manualBook
                )
            }
        }
        
        return nil
    }
    
    /// Extract book name from words (handles multi-word books like "1 John")
    private func extractBookName(from words: [String]) -> String? {
        guard !words.isEmpty else { return nil }
        
        // Check for numbered books (1 John, 2 Timothy, etc.)
        if words.count >= 2, words[0].count == 1, words[0].first?.isNumber == true {
            return "\(words[0]) \(words[1])"
        }
        
        return words[0]
    }
    
    /// Check if two words are phonetically similar
    private func isSimilar(_ word1: String, to word2: String) -> Bool {
        let w1 = word1.lowercased()
        let w2 = word2.lowercased()
        
        // Exact match
        if w1 == w2 { return false } // Not a correction if they match
        
        // Common phonetic confusions
        let confusions: [(String, String)] = [
            ("some", "psalms"),
            ("psalm", "psalms"),
            ("song", "psalms"),
            ("sam", "psalms"),
            ("john", "john"),
            ("gene", "genesis"),
            ("jen", "genesis"),
            ("acts", "acts"),
            ("axe", "acts"),
            ("rome", "romans"),
            ("roman", "romans"),
            ("mark", "mark"),
            ("luke", "luke"),
            ("look", "luke"),
            ("ruth", "ruth"),
            ("roof", "ruth"),
        ]
        
        for (heard, correct) in confusions {
            if w1 == heard && w2 == correct {
                return true
            }
        }
        
        // Check Levenshtein distance for similar words
        let distance = levenshteinDistance(w1, w2)
        let maxLength = max(w1.count, w2.count)
        let similarity = 1.0 - (Double(distance) / Double(maxLength))
        
        // Consider similar if > 60% match but not exact
        return similarity > 0.6 && similarity < 1.0
    }
    
    /// Calculate Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        
        let m = s1Array.count
        let n = s2Array.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[m][n]
    }
}

// MARK: - Suggested Correction

struct SuggestedCorrection {
    let heard: String
    let corrected: String
}

// MARK: - ServiceSessionManager Extension

extension ServiceSessionManager {
    
    /// Add or update a speech correction for a pastor
    func addCorrection(to pastorId: UUID, heard: String, corrected: String) {
        guard let index = pastorProfiles.firstIndex(where: { $0.id == pastorId }) else {
            return
        }
        
        let trimmedHeard = heard.trimmingCharacters(in: .whitespaces).lowercased()
        let trimmedCorrected = corrected.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedHeard.isEmpty, !trimmedCorrected.isEmpty else { return }
        
        // Check if correction already exists
        if let correctionIndex = pastorProfiles[index].speechCorrections.firstIndex(where: {
            $0.heard.lowercased() == trimmedHeard
        }) {
            // Update existing
            pastorProfiles[index].speechCorrections[correctionIndex].corrected = trimmedCorrected
            pastorProfiles[index].speechCorrections[correctionIndex].occurrences += 1
            pastorProfiles[index].speechCorrections[correctionIndex].lastUsed = Date()
        } else {
            // Add new
            let correction = SpeechCorrection(
                heard: trimmedHeard,
                corrected: trimmedCorrected,
                occurrences: 1,
                lastUsed: Date()
            )
            pastorProfiles[index].speechCorrections.append(correction)
        }
        
        savePastorProfiles()
        print("[SpeechCorrection] Added: '\(trimmedHeard)' → '\(trimmedCorrected)' for pastor \(pastorProfiles[index].name)")
    }
    
    /// Remove a speech correction from a pastor
    func removeCorrection(from pastorId: UUID, heard: String) {
        guard let index = pastorProfiles.firstIndex(where: { $0.id == pastorId }) else {
            return
        }
        
        pastorProfiles[index].speechCorrections.removeAll {
            $0.heard.lowercased() == heard.lowercased()
        }
        
        savePastorProfiles()
    }
    
    /// Get corrections for current session's pastor
    func currentPastorCorrections() -> [SpeechCorrection] {
        guard let pastorId = currentSession?.pastorId,
              let pastor = pastorProfiles.first(where: { $0.id == pastorId }) else {
            return []
        }
        return pastor.speechCorrections
    }
    
    /// Export corrections for a pastor to JSON file
    func exportCorrections(for pastorId: UUID) -> URL? {
        guard let pastor = pastorProfiles.first(where: { $0.id == pastorId }) else {
            return nil
        }
        
        let export = CorrectionExport(
            pastorName: pastor.name,
            exportDate: Date(),
            corrections: pastor.speechCorrections
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(export) else { return nil }
        
        let fileName = "\(pastor.name.replacingOccurrences(of: " ", with: "_"))_corrections.json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: url)
            return url
        } catch {
            print("[SpeechCorrection] Export failed: \(error)")
            return nil
        }
    }
    
    /// Import corrections for a pastor from JSON file
    func importCorrections(for pastorId: UUID, from url: URL) -> Int {
        guard let index = pastorProfiles.firstIndex(where: { $0.id == pastorId }) else {
            return 0
        }
        
        guard let data = try? Data(contentsOf: url),
              let export = try? JSONDecoder().decode(CorrectionExport.self, from: data) else {
            return 0
        }
        
        var importedCount = 0
        
        for correction in export.corrections {
            if !pastorProfiles[index].speechCorrections.contains(where: {
                $0.heard.lowercased() == correction.heard.lowercased()
            }) {
                pastorProfiles[index].speechCorrections.append(correction)
                importedCount += 1
            }
        }
        
        if importedCount > 0 {
            savePastorProfiles()
        }
        
        return importedCount
    }
}

// MARK: - Correction Export Model

struct CorrectionExport: Codable {
    let pastorName: String
    let exportDate: Date
    let corrections: [SpeechCorrection]
}
