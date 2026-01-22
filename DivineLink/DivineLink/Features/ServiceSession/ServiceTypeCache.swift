import Foundation
import SwiftUI
import Combine

/// Manages caching and suggestions for service types
class ServiceTypeCache: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = ServiceTypeCache()
    
    // MARK: - Published Properties
    
    @Published private(set) var cachedTypes: [ServiceTypeEntry] = []
    
    // MARK: - Private Properties
    
    private let maxCachedTypes = 20
    private let defaults = UserDefaults.standard
    private let cacheKey = "cachedServiceTypes"
    
    // MARK: - Initialisation
    
    private init() {
        loadCache()
    }
    
    // MARK: - Cache Entry
    
    struct ServiceTypeEntry: Codable, Identifiable, Equatable {
        let id: UUID
        let type: String
        var lastUsed: Date
        var useCount: Int
        
        init(type: String) {
            self.id = UUID()
            self.type = type
            self.lastUsed = Date()
            self.useCount = 1
        }
    }
    
    // MARK: - Public Methods
    
    /// Get suggestions matching the input text
    func suggestions(for input: String) -> [String] {
        let lowercasedInput = input.lowercased().trimmingCharacters(in: .whitespaces)
        
        if lowercasedInput.isEmpty {
            // Return most recent types when empty
            return cachedTypes
                .sorted { $0.lastUsed > $1.lastUsed }
                .prefix(5)
                .map { $0.type }
        }
        
        // Filter matching types, prioritise by use count and recency
        return cachedTypes
            .filter { $0.type.lowercased().contains(lowercasedInput) }
            .sorted { entry1, entry2 in
                // Prefer exact prefix matches
                let prefix1 = entry1.type.lowercased().hasPrefix(lowercasedInput)
                let prefix2 = entry2.type.lowercased().hasPrefix(lowercasedInput)
                if prefix1 != prefix2 { return prefix1 }
                
                // Then by use count
                if entry1.useCount != entry2.useCount {
                    return entry1.useCount > entry2.useCount
                }
                
                // Then by recency
                return entry1.lastUsed > entry2.lastUsed
            }
            .map { $0.type }
    }
    
    /// Add or update a service type in the cache
    func addType(_ type: String) {
        let normalised = type.trimmingCharacters(in: .whitespaces)
        guard !normalised.isEmpty else { return }
        
        if let index = cachedTypes.firstIndex(where: { $0.type.lowercased() == normalised.lowercased() }) {
            // Update existing entry
            cachedTypes[index].lastUsed = Date()
            cachedTypes[index].useCount += 1
        } else {
            // Add new entry
            let entry = ServiceTypeEntry(type: normalised)
            cachedTypes.insert(entry, at: 0)
            
            // Trim if exceeding max
            if cachedTypes.count > maxCachedTypes {
                cachedTypes.removeLast()
            }
        }
        
        saveCache()
    }
    
    /// Remove a service type from the cache
    func removeType(_ type: String) {
        cachedTypes.removeAll { $0.type.lowercased() == type.lowercased() }
        saveCache()
    }
    
    /// Clear all cached types
    func clearCache() {
        cachedTypes.removeAll()
        saveCache()
    }
    
    // MARK: - Persistence
    
    private func loadCache() {
        guard let data = defaults.data(forKey: cacheKey),
              let entries = try? JSONDecoder().decode([ServiceTypeEntry].self, from: data) else {
            // Seed with common types
            cachedTypes = [
                ServiceTypeEntry(type: "Sunday Service"),
                ServiceTypeEntry(type: "Midweek Service"),
                ServiceTypeEntry(type: "Bible Study"),
                ServiceTypeEntry(type: "Prayer Meeting"),
                ServiceTypeEntry(type: "Youth Service")
            ]
            return
        }
        cachedTypes = entries
    }
    
    private func saveCache() {
        if let data = try? JSONEncoder().encode(cachedTypes) {
            defaults.set(data, forKey: cacheKey)
        }
    }
}

// MARK: - Service Type Field View

struct ServiceTypeField: View {
    @Binding var text: String
    @ObservedObject private var cache = ServiceTypeCache.shared
    @State private var showSuggestions = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Service Type", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    showSuggestions = isFocused && !newValue.isEmpty
                }
                .onChange(of: isFocused) { _, focused in
                    showSuggestions = focused && !text.isEmpty
                }
            
            if showSuggestions {
                let suggestions = cache.suggestions(for: text)
                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestions.prefix(5), id: \.self) { suggestion in
                            Button {
                                text = suggestion
                                showSuggestions = false
                                isFocused = false
                            } label: {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(suggestion)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(Color.gray.opacity(0.05))
                            
                            if suggestion != suggestions.last {
                                Divider()
                            }
                        }
                    }
                    .background(Color(NSColor.windowBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(radius: 4)
                    .padding(.top, 2)
                }
            }
        }
    }
}

#Preview {
    ServiceTypeField(text: .constant("Sunday"))
        .frame(width: 300)
        .padding()
}
