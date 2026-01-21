import Foundation
import Combine

// MARK: - Service Session Manager

/// Manages service sessions - creation, storage, and retrieval
@MainActor
class ServiceSessionManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = ServiceSessionManager()
    
    // MARK: - Published Properties
    
    @Published var currentSession: ServiceSession?
    @Published var recentSessions: [ServiceSession] = []
    @Published var pastorProfiles: [PastorProfile] = []
    
    // MARK: - Service Type Cache
    
    @Published var recentServiceTypes: [String] = []
    private let maxCachedTypes = 20
    
    // MARK: - Storage Keys
    
    private let currentSessionKey = "currentSession"
    private let recentSessionsKey = "recentSessions"
    private let serviceTypesKey = "recentServiceTypes"
    private let pastorProfilesKey = "pastorProfiles"
    
    // MARK: - Initialisation
    
    private init() {
        loadData()
    }
    
    // MARK: - Session Management
    
    /// Start a new service session
    func startSession(
        name: String,
        serviceType: String,
        date: Date,
        pastorId: UUID? = nil
    ) -> ServiceSession {
        // End any existing session
        if currentSession != nil {
            endCurrentSession()
        }
        
        // Create new session
        let session = ServiceSession(
            name: name,
            serviceType: serviceType,
            date: date,
            pastorId: pastorId
        )
        
        currentSession = session
        
        // Cache the service type
        addServiceType(serviceType)
        
        // Save
        saveCurrentSession()
        
        print("[Session] Started: \(session.name)")
        return session
    }
    
    /// End the current session
    func endCurrentSession() {
        guard var session = currentSession else { return }
        
        session.endTime = Date()
        
        // Save to SQLite archive for long-term storage
        ServiceArchive.shared.save(session)
        
        // Add to recent sessions (in-memory cache)
        recentSessions.insert(session, at: 0)
        
        // Limit recent sessions (keep last 100 in memory)
        if recentSessions.count > 100 {
            recentSessions = Array(recentSessions.prefix(100))
        }
        
        currentSession = nil
        
        saveRecentSessions()
        clearCurrentSession()
        
        print("[Session] Ended: \(session.name) - Duration: \(session.formattedDuration)")
    }
    
    /// Add a detected scripture to the current session
    func addDetectedScripture(_ scripture: DetectedScripture) {
        guard currentSession != nil else { return }
        currentSession?.detectedScriptures.append(scripture)
        saveCurrentSession()
    }
    
    /// Mark a scripture as pushed to ProPresenter
    func markScripturePushed(_ scriptureId: UUID) {
        guard let index = currentSession?.detectedScriptures.firstIndex(where: { $0.id == scriptureId }) else {
            return
        }
        currentSession?.detectedScriptures[index].wasPushed = true
        saveCurrentSession()
    }
    
    /// Add a transcript snippet to the current session
    func addTranscriptSnippet(_ snippet: String) {
        guard currentSession != nil else { return }
        currentSession?.transcriptSnippets.append(snippet)
        
        // Keep last 50 snippets
        if let count = currentSession?.transcriptSnippets.count, count > 50 {
            currentSession?.transcriptSnippets.removeFirst()
        }
    }
    
    // MARK: - Service Type Cache
    
    /// Add a service type to the cache
    func addServiceType(_ type: String) {
        let trimmed = type.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        // Remove if exists (to move to front)
        if let index = recentServiceTypes.firstIndex(of: trimmed) {
            recentServiceTypes.remove(at: index)
        }
        
        // Insert at front
        recentServiceTypes.insert(trimmed, at: 0)
        
        // Limit size
        if recentServiceTypes.count > maxCachedTypes {
            recentServiceTypes.removeLast()
        }
        
        saveServiceTypes()
    }
    
    /// Get service type suggestions for autocomplete
    func serviceTypeSuggestions(for query: String) -> [String] {
        if query.isEmpty {
            return recentServiceTypes
        }
        return recentServiceTypes.filter {
            $0.localizedCaseInsensitiveContains(query)
        }
    }
    
    // MARK: - Pastor Profiles
    
    /// Add a new pastor profile
    func addPastor(name: String) -> PastorProfile {
        let profile = PastorProfile(name: name)
        pastorProfiles.append(profile)
        savePastorProfiles()
        return profile
    }
    
    /// Delete a pastor profile
    func deletePastor(_ id: UUID) {
        pastorProfiles.removeAll { $0.id == id }
        savePastorProfiles()
    }
    
    /// Get pastor by ID
    func pastor(for id: UUID) -> PastorProfile? {
        pastorProfiles.first { $0.id == id }
    }
    
    // MARK: - Persistence
    
    private func loadData() {
        // Load current session
        if let data = UserDefaults.standard.data(forKey: currentSessionKey),
           let session = try? JSONDecoder().decode(ServiceSession.self, from: data) {
            currentSession = session
        }
        
        // Load recent sessions
        if let data = UserDefaults.standard.data(forKey: recentSessionsKey),
           let sessions = try? JSONDecoder().decode([ServiceSession].self, from: data) {
            recentSessions = sessions
        }
        
        // Load service types
        if let types = UserDefaults.standard.stringArray(forKey: serviceTypesKey) {
            recentServiceTypes = types
        } else {
            // Default service types
            recentServiceTypes = [
                "Sunday Service",
                "Wednesday Bible Study",
                "Friday Prayer Meeting",
                "Youth Service",
                "Special Service"
            ]
        }
        
        // Load pastor profiles
        if let data = UserDefaults.standard.data(forKey: pastorProfilesKey),
           let profiles = try? JSONDecoder().decode([PastorProfile].self, from: data) {
            pastorProfiles = profiles
        }
    }
    
    private func saveCurrentSession() {
        guard let session = currentSession,
              let data = try? JSONEncoder().encode(session) else {
            return
        }
        UserDefaults.standard.set(data, forKey: currentSessionKey)
    }
    
    private func clearCurrentSession() {
        UserDefaults.standard.removeObject(forKey: currentSessionKey)
    }
    
    private func saveRecentSessions() {
        if let data = try? JSONEncoder().encode(recentSessions) {
            UserDefaults.standard.set(data, forKey: recentSessionsKey)
        }
    }
    
    private func saveServiceTypes() {
        UserDefaults.standard.set(recentServiceTypes, forKey: serviceTypesKey)
    }
    
    private func savePastorProfiles() {
        if let data = try? JSONEncoder().encode(pastorProfiles) {
            UserDefaults.standard.set(data, forKey: pastorProfilesKey)
        }
    }
}
