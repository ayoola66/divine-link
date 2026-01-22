import Foundation

/// Detects well-known Bible verses from their content without explicit references
class ImplicitReferenceDetector {
    
    // MARK: - Properties
    
    private let famousVerses: [String: String]
    private let minimumMatchLength = 15 // Minimum characters to consider a match
    
    // MARK: - Initialisation
    
    init() {
        self.famousVerses = BibleVocabularyData.famousVerses
    }
    
    // MARK: - Detection
    
    /// Detect implicit scripture references from transcript text
    /// Returns array of potential matches with confidence scores
    func detect(in text: String) -> [ImplicitMatch] {
        let lowercasedText = text.lowercased()
        var matches: [ImplicitMatch] = []
        
        for (phrase, reference) in famousVerses {
            if lowercasedText.contains(phrase) {
                // Calculate confidence based on how much of the phrase is matched
                let confidence = calculateConfidence(phrase: phrase, in: lowercasedText)
                
                matches.append(ImplicitMatch(
                    reference: reference,
                    matchedPhrase: phrase,
                    confidence: confidence
                ))
            }
        }
        
        // Sort by confidence (highest first)
        return matches.sorted { $0.confidence > $1.confidence }
    }
    
    /// Check if text contains any famous verse phrases
    func containsFamousVerse(_ text: String) -> Bool {
        let lowercasedText = text.lowercased()
        return famousVerses.keys.contains { lowercasedText.contains($0) }
    }
    
    /// Get the best match for a given text
    func bestMatch(in text: String) -> ImplicitMatch? {
        return detect(in: text).first
    }
    
    // MARK: - Private Methods
    
    private func calculateConfidence(phrase: String, in text: String) -> Float {
        // Base confidence from phrase length
        let lengthScore = min(Float(phrase.count) / 30.0, 0.8)
        
        // Bonus for exact word boundaries
        let boundaryBonus: Float = text.contains(phrase) ? 0.2 : 0.0
        
        return min(lengthScore + boundaryBonus, 1.0)
    }
}

// MARK: - Implicit Match

struct ImplicitMatch {
    let reference: String
    let matchedPhrase: String
    let confidence: Float
    
    /// Parse the reference into a ScriptureReference
    var scriptureReference: ScriptureReference? {
        // Parse reference like "John 3:16" or "1 Corinthians 13:4"
        let pattern = #"((?:\d\s)?[A-Za-z]+(?:\s[A-Za-z]+)?)\s+(\d+):(\d+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: reference, options: [], range: NSRange(reference.startIndex..., in: reference)) else {
            return nil
        }
        
        guard let bookRange = Range(match.range(at: 1), in: reference),
              let chapterRange = Range(match.range(at: 2), in: reference),
              let verseRange = Range(match.range(at: 3), in: reference),
              let chapter = Int(reference[chapterRange]),
              let verseStart = Int(reference[verseRange]) else {
            return nil
        }
        
        let book = String(reference[bookRange])
        
        return ScriptureReference(book: book, chapter: chapter, verseStart: verseStart, verseEnd: nil)
    }
}

// MARK: - Extended Detection Phrases

extension BibleVocabularyData {
    
    /// Additional phrases that can be added dynamically
    static var additionalFamousVerses: [String: String] = [:]
    
    /// Add a custom famous verse phrase
    static func addFamousVerse(phrase: String, reference: String) {
        additionalFamousVerses[phrase.lowercased()] = reference
    }
    
    /// Get all famous verses including custom additions
    static var allFamousVerses: [String: String] {
        var combined = famousVerses
        for (key, value) in additionalFamousVerses {
            combined[key] = value
        }
        return combined
    }
}
