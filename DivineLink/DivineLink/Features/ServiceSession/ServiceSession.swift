import Foundation

// MARK: - Service Session Model

/// Represents a single service session (e.g., "Sunday Service - 19 Jan 2026")
struct ServiceSession: Identifiable, Codable {
    let id: UUID
    var name: String
    var serviceType: String          // "Sunday Service", "Wednesday Bible Study"
    var date: Date
    var pastorId: UUID?              // Optional linked pastor profile
    var startTime: Date
    var endTime: Date?
    var detectedScriptures: [DetectedScripture]
    var transcriptSnippets: [String] // Rolling transcript history
    
    /// Whether the session is currently active
    var isActive: Bool { endTime == nil }
    
    /// Duration of the session
    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }
    
    /// Formatted duration string
    var formattedDuration: String {
        guard let duration = duration else { return "In progress" }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) minutes"
    }
    
    /// Create a new session
    init(
        id: UUID = UUID(),
        name: String,
        serviceType: String,
        date: Date = Date(),
        pastorId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.serviceType = serviceType
        self.date = date
        self.pastorId = pastorId
        self.startTime = Date()
        self.endTime = nil
        self.detectedScriptures = []
        self.transcriptSnippets = []
    }
    
    /// Generate default session name from type and date
    static func defaultName(for serviceType: String, on date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return "\(serviceType) - \(formatter.string(from: date))"
    }
}

// MARK: - Detected Scripture

/// A scripture reference detected during a service session
struct DetectedScripture: Identifiable, Codable {
    let id: UUID
    let reference: String            // "John 3:16"
    let verseText: String            // Full verse text
    let translation: String          // "KJV"
    let timestamp: Date
    var wasPushed: Bool              // Did operator push to ProPresenter?
    let rawTranscript: String        // What was actually heard
    let confidence: Float            // Detection confidence 0-1
    
    init(
        reference: String,
        verseText: String,
        translation: String = "KJV",
        rawTranscript: String,
        confidence: Float
    ) {
        self.id = UUID()
        self.reference = reference
        self.verseText = verseText
        self.translation = translation
        self.timestamp = Date()
        self.wasPushed = false
        self.rawTranscript = rawTranscript
        self.confidence = confidence
    }
}

// MARK: - Pastor Profile (Placeholder for Story 4.5)

/// Pastor profile for speech learning
struct PastorProfile: Identifiable, Codable {
    let id: UUID
    var name: String
    var createdAt: Date
    var speechCorrections: [SpeechCorrection]
    var servicesCount: Int
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.speechCorrections = []
        self.servicesCount = 0
    }
}

/// A learned speech correction for a pastor
struct SpeechCorrection: Codable {
    let heard: String       // "Some"
    var corrected: String   // "Psalms" - var to allow updates
    var occurrences: Int    // How many times this correction was made
    var lastUsed: Date
}
