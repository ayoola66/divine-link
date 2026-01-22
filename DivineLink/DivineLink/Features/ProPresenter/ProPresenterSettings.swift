import Foundation
import SwiftUI

// MARK: - Connection Status

enum ConnectionStatus: Equatable {
    case unknown
    case testing
    case connected
    case disconnected
    case error(String)
    
    var displayText: String {
        switch self {
        case .unknown: return "Not tested"
        case .testing: return "Testing..."
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .error(let message): return "Error: \(message)"
        }
    }
    
    var color: Color {
        switch self {
        case .connected: return .green
        case .disconnected, .error: return .red
        case .testing: return .orange
        case .unknown: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .connected: return "checkmark.circle.fill"
        case .disconnected: return "xmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .testing: return "arrow.triangle.2.circlepath"
        case .unknown: return "questionmark.circle"
        }
    }
    
    static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown),
             (.testing, .testing),
             (.connected, .connected),
             (.disconnected, .disconnected):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - ProPresenter Settings

/// Settings for ProPresenter connection
class ProPresenterSettings: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var ipAddress: String {
        didSet { save() }
    }
    
    @Published var port: Int {
        didSet { save() }
    }
    
    @Published var connectionStatus: ConnectionStatus = .unknown
    
    // MARK: - Private Properties
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let ipAddress = "propresenter.ipAddress"
        static let port = "propresenter.port"
    }
    
    // MARK: - Initialisation
    
    init() {
        self.ipAddress = defaults.string(forKey: Keys.ipAddress) ?? "192.168.1.100"
        self.port = defaults.integer(forKey: Keys.port)
        if self.port == 0 { self.port = 1025 }
    }
    
    // MARK: - Persistence
    
    private func save() {
        defaults.set(ipAddress, forKey: Keys.ipAddress)
        defaults.set(port, forKey: Keys.port)
    }
    
    // MARK: - Validation
    
    var isValid: Bool {
        isValidIPAddress(ipAddress) && port > 0 && port < 65536
    }
    
    var connectionURL: URL? {
        URL(string: "http://\(ipAddress):\(port)")
    }
    
    private func isValidIPAddress(_ string: String) -> Bool {
        // Allow localhost
        if string == "localhost" || string == "127.0.0.1" {
            return true
        }
        
        let parts = string.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let num = Int(part) else { return false }
            return num >= 0 && num <= 255
        }
    }
    
    var validationError: String? {
        if !isValidIPAddress(ipAddress) {
            return "Invalid IP address format"
        }
        if port <= 0 || port >= 65536 {
            return "Port must be between 1 and 65535"
        }
        return nil
    }
}
