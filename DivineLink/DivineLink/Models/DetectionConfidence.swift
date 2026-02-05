import SwiftUI

// MARK: - Detection Confidence Model

/// Represents the confidence level of a scripture detection
/// Calculates overall confidence from multiple factors
struct DetectionConfidence: Equatable, Codable {
    /// How explicit was the reference pattern (0.0 - 1.0)
    /// - 1.0: Explicit ("John chapter 3 verse 16")
    /// - 0.9: Standard ("John 3:16")
    /// - 0.7: Informal ("John 3 16")
    /// - 0.5: Implicit (famous verse by content)
    let referenceClarity: Double
    
    /// Speech recognition confidence from Apple Speech API (0.0 - 1.0)
    let speechConfidence: Double
    
    /// Text similarity between transcript and verse content (0.0 - 1.0)
    let contextMatch: Double
    
    /// Whether the verse exists in the Bible database (0.0 - 1.0)
    let verseExistence: Double
    
    // MARK: - Weights for confidence calculation
    
    private static let referenceWeight = 0.4
    private static let speechWeight = 0.3
    private static let contextWeight = 0.2
    private static let existenceWeight = 0.1
    
    // MARK: - Computed Properties
    
    /// Overall confidence score (0.0 - 1.0)
    var overall: Double {
        return (referenceClarity * Self.referenceWeight) +
               (speechConfidence * Self.speechWeight) +
               (contextMatch * Self.contextWeight) +
               (verseExistence * Self.existenceWeight)
    }
    
    /// Confidence level categorisation
    var level: ConfidenceLevel {
        switch overall {
        case 0.8...1.0: return .high
        case 0.5..<0.8: return .medium
        default: return .low
        }
    }
    
    /// Confidence as a percentage (0-100)
    var percentage: Int {
        return Int(overall * 100)
    }
    
    /// Description of the confidence factors
    var breakdown: String {
        return """
        Reference: \(Int(referenceClarity * 100))%
        Speech: \(Int(speechConfidence * 100))%
        Context: \(Int(contextMatch * 100))%
        Exists: \(Int(verseExistence * 100))%
        """
    }
    
    // MARK: - Factory Methods
    
    /// Creates a high-confidence detection (for testing/explicit references)
    static func high(speechConfidence: Double = 0.95) -> DetectionConfidence {
        DetectionConfidence(
            referenceClarity: 1.0,
            speechConfidence: speechConfidence,
            contextMatch: 0.9,
            verseExistence: 1.0
        )
    }
    
    /// Creates a medium-confidence detection
    static func medium(speechConfidence: Double = 0.75) -> DetectionConfidence {
        DetectionConfidence(
            referenceClarity: 0.7,
            speechConfidence: speechConfidence,
            contextMatch: 0.6,
            verseExistence: 1.0
        )
    }
    
    /// Creates a low-confidence detection
    static func low(speechConfidence: Double = 0.5) -> DetectionConfidence {
        DetectionConfidence(
            referenceClarity: 0.5,
            speechConfidence: speechConfidence,
            contextMatch: 0.3,
            verseExistence: 0.8
        )
    }
    
    /// Creates confidence from a legacy float value (for backwards compatibility)
    static func fromLegacy(_ confidence: Float) -> DetectionConfidence {
        let value = Double(confidence)
        return DetectionConfidence(
            referenceClarity: value,
            speechConfidence: value,
            contextMatch: value,
            verseExistence: 1.0
        )
    }
}

// MARK: - Confidence Level Enum

/// Categorisation of confidence levels
enum ConfidenceLevel: String, Codable, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    /// Colour for the confidence level
    var colour: Color {
        switch self {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .orange
        }
    }
    
    /// System icon for the confidence level
    var icon: String {
        switch self {
        case .high: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "questionmark.circle.fill"
        }
    }
    
    /// Description of what the level means
    var description: String {
        switch self {
        case .high: return "Confident match"
        case .medium: return "Likely match"
        case .low: return "Uncertain - verify before pushing"
        }
    }
    
    /// Threshold value for this level
    var threshold: Double {
        switch self {
        case .high: return 0.8
        case .medium: return 0.5
        case .low: return 0.0
        }
    }
}

// MARK: - Text Similarity Calculation

extension DetectionConfidence {
    /// Calculates Jaccard similarity between two texts
    /// - Parameters:
    ///   - text1: First text (usually transcript excerpt)
    ///   - text2: Second text (usually verse text)
    /// - Returns: Similarity score between 0.0 and 1.0
    static func calculateTextSimilarity(_ text1: String, _ text2: String) -> Double {
        let words1 = Set(text1.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty })
        let words2 = Set(text2.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty })
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        guard !union.isEmpty else { return 0.0 }
        return Double(intersection.count) / Double(union.count)
    }
}
