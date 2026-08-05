import Foundation
import SwiftUI
import Combine

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

// MARK: - Topology

/// Physical setup: is ProPresenter running on this same Mac, or a separate machine on the network?
enum ProPresenterTopology: String, Codable, CaseIterable {
    case sameMachine
    case twoMachines

    var displayName: String {
        switch self {
        case .sameMachine: return "Same Machine"
        case .twoMachines: return "Two Machines (Network)"
        }
    }

    var description: String {
        switch self {
        case .sameMachine:
            return "Divine Link and ProPresenter run on this Mac. All output paths are available."
        case .twoMachines:
            return "ProPresenter runs on a different Mac on the same network. Keyboard automation can't reach another machine, so only Stage Display and the Messages API are used."
        }
    }
}

// MARK: - ProPresenter Settings

/// Settings for ProPresenter connection
class ProPresenterSettings: ObservableObject {

    // MARK: - Published Properties

    /// IP address of the ProPresenter machine
    @Published var ipAddress: String {
        didSet { save() }
    }

    /// Physical setup of Divine Link relative to ProPresenter.
    /// Two-machine mode requires Premium — see `effectiveTopology`.
    @Published var topology: ProPresenterTopology {
        didSet { save() }
    }
    
    /// Port for the ProPresenter API (default 50233)
    @Published var port: Int {
        didSet { save() }
    }
    
    /// Enable Stage Display output via HTTP REST API
    @Published var stageDisplayEnabled: Bool {
        didSet { save() }
    }
    
    /// Enable Messages API output via WebSocket (Premium feature)
    @Published var messagesAPIEnabled: Bool {
        didSet { save() }
    }
    
    /// Enable keyboard automation for Audience display (fallback when Messages API unavailable)
    @Published var keyboardAutomationEnabled: Bool {
        didSet { save() }
    }
    
    /// Auto-fallback to keyboard automation if WebSocket fails
    @Published var autoFallbackEnabled: Bool {
        didSet { save() }
    }
    
    /// Current connection status
    @Published var connectionStatus: ConnectionStatus = .unknown
    
    /// WebSocket connection status (separate from HTTP)
    @Published var webSocketStatus: ConnectionStatus = .disconnected
    
    // MARK: - Private Properties
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let ipAddress = "propresenter.ipAddress"
        static let port = "propresenter.port"
        static let topology = "propresenter.topology"
        static let stageDisplayEnabled = "propresenter.stageDisplayEnabled"
        static let messagesAPIEnabled = "propresenter.messagesAPIEnabled"
        static let keyboardAutomationEnabled = "propresenter.keyboardAutomationEnabled"
        static let autoFallbackEnabled = "propresenter.autoFallbackEnabled"
    }
    
    // MARK: - Initialisation
    
    init() {
        self.ipAddress = defaults.string(forKey: Keys.ipAddress) ?? "127.0.0.1"
        self.topology = ProPresenterTopology(rawValue: defaults.string(forKey: Keys.topology) ?? "") ?? .sameMachine

        // Load port with default fallback
        let savedPort = defaults.integer(forKey: Keys.port)
        self.port = savedPort == 0 ? 50233 : savedPort  // ProPresenter 7 default API port
        
        // Default to Stage Display enabled, others disabled
        self.stageDisplayEnabled = defaults.object(forKey: Keys.stageDisplayEnabled) as? Bool ?? true
        self.messagesAPIEnabled = defaults.bool(forKey: Keys.messagesAPIEnabled)
        self.keyboardAutomationEnabled = defaults.object(forKey: Keys.keyboardAutomationEnabled) as? Bool ?? true
        self.autoFallbackEnabled = defaults.object(forKey: Keys.autoFallbackEnabled) as? Bool ?? true
    }
    
    // MARK: - Persistence
    
    private func save() {
        defaults.set(ipAddress, forKey: Keys.ipAddress)
        defaults.set(port, forKey: Keys.port)
        defaults.set(topology.rawValue, forKey: Keys.topology)
        defaults.set(stageDisplayEnabled, forKey: Keys.stageDisplayEnabled)
        defaults.set(messagesAPIEnabled, forKey: Keys.messagesAPIEnabled)
        defaults.set(keyboardAutomationEnabled, forKey: Keys.keyboardAutomationEnabled)
        defaults.set(autoFallbackEnabled, forKey: Keys.autoFallbackEnabled)
    }
    
    // MARK: - Topology Enforcement

    /// The topology actually in effect, after enforcing entitlement.
    /// Two-machine mode requires Premium — a lapsed or free user is always
    /// treated as same-machine regardless of the stored preference (which is
    /// preserved so their choice comes back if they resubscribe).
    var effectiveTopology: ProPresenterTopology {
        topology == .twoMachines && SubscriptionService.shared.canUsePremiumFeatures ? .twoMachines : .sameMachine
    }

    /// Whether keyboard automation is actually usable right now.
    /// Always false in two-machine mode regardless of the raw toggle — keyboard
    /// automation is local keystroke simulation (Accessibility API) and is
    /// structurally incapable of reaching ProPresenter on a different Mac.
    var effectiveKeyboardAutomationEnabled: Bool {
        keyboardAutomationEnabled && effectiveTopology == .sameMachine
    }

    // MARK: - Convenience

    /// Check if any output is enabled
    var hasEnabledOutput: Bool {
        stageDisplayEnabled || messagesAPIEnabled || effectiveKeyboardAutomationEnabled
    }

    /// Get all enabled output types
    var enabledOutputTypes: [ProPresenterOutputType] {
        var types: [ProPresenterOutputType] = []
        if stageDisplayEnabled { types.append(.stageDisplay) }
        if messagesAPIEnabled { types.append(.audienceWebSocket) }
        else if effectiveKeyboardAutomationEnabled { types.append(.audienceKeyboard) }
        return types
    }
    
    /// WebSocket URL for Messages API
    var webSocketURL: URL? {
        var components = URLComponents()
        components.scheme = "ws"
        components.host = ipAddress
        components.port = port
        components.path = "/messaging"
        return components.url
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
