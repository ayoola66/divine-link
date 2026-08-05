import Foundation

// MARK: - Output Type

/// Types of ProPresenter output paths
enum ProPresenterOutputType: String, Codable, CaseIterable {
    case stageDisplay       // HTTP REST API for Stage Display Message
    case audienceWebSocket  // WebSocket Messages API for Audience screen
    case audienceKeyboard   // Keyboard automation (⌘B) for Audience Bible
    
    var displayName: String {
        switch self {
        case .stageDisplay:
            return "Stage Display"
        case .audienceWebSocket:
            return "Audience (Messages API)"
        case .audienceKeyboard:
            return "Audience (Keyboard)"
        }
    }
    
    var description: String {
        switch self {
        case .stageDisplay:
            return "Shows scripture on the Stage Display/Confidence Monitor for operators"
        case .audienceWebSocket:
            return "Displays scripture on the Audience screen via ProPresenter Messages layer"
        case .audienceKeyboard:
            return "Uses keyboard automation to trigger ProPresenter's native Bible feature"
        }
    }
    
    var requiresPremium: Bool {
        switch self {
        case .stageDisplay, .audienceKeyboard:
            return false  // Available to all users
        case .audienceWebSocket:
            return true   // Grace/Love tiers only
        }
    }
    
    var icon: String {
        switch self {
        case .stageDisplay:
            return "display"
        case .audienceWebSocket:
            return "network"
        case .audienceKeyboard:
            return "keyboard"
        }
    }
}

// MARK: - Scripture Data

/// Data structure for scripture to be displayed
struct ScriptureDisplayData {
    let reference: String       // e.g., "John 3:16"
    let text: String           // The verse text
    let translation: String?   // e.g., "KJV", "NIV"
    let confidence: Double?    // Detection confidence (0.0 - 1.0)
    
    /// Formatted for stage display (includes confidence if available)
    var stageDisplayText: String {
        var lines = [reference]
        if let confidence = confidence {
            let percentage = Int(confidence * 100)
            lines.append("Confidence: \(percentage)%")
        }
        lines.append("")
        lines.append(text)
        if let translation = translation {
            lines.append("(\(translation))")
        }
        return lines.joined(separator: "\n")
    }
    
    /// Formatted for audience display (clean, no confidence)
    var audienceDisplayText: String {
        var lines = [reference, "", text]
        if let translation = translation {
            lines.append("— \(translation)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Output Result

/// Result of a display operation
enum ProPresenterOutputResult {
    case success
    case failure(Error)
    case unavailable(reason: String)
    
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

// MARK: - Output Protocol

/// Protocol for all ProPresenter output implementations
protocol ProPresenterOutput: AnyObject {
    
    /// The type of this output
    var outputType: ProPresenterOutputType { get }
    
    /// Current connection status
    var connectionStatus: ConnectionStatus { get }
    
    /// Whether this output is currently available
    var isAvailable: Bool { get }
    
    /// Display scripture on this output
    /// - Parameter scripture: The scripture data to display
    /// - Returns: Result of the operation
    func display(_ scripture: ScriptureDisplayData) async -> ProPresenterOutputResult
    
    /// Clear the current display
    /// - Returns: Result of the operation
    func clear() async -> ProPresenterOutputResult
    
    /// Test the connection to this output
    /// - Returns: True if connection is healthy
    func testConnection() async -> Bool
    
    /// Configure the output with settings
    /// - Parameter settings: ProPresenter settings
    func configure(with settings: ProPresenterSettings)
}

// MARK: - Factory

/// Factory for creating ProPresenter output instances
class ProPresenterOutputFactory {
    
    /// Shared instance
    static let shared = ProPresenterOutputFactory()
    
    // MARK: - Cached Outputs
    
    private var stageDisplayOutput: StageDisplayOutput?
    private var audienceWebSocketOutput: AudienceWebSocketOutput?
    private var audienceKeyboardOutput: AudienceKeyboardOutput?
    
    private init() {}
    
    // MARK: - Factory Methods
    
    /// Create or retrieve an output for the specified type
    /// - Parameter type: The type of output to create
    /// - Returns: An output instance
    func createOutput(for type: ProPresenterOutputType) -> ProPresenterOutput {
        switch type {
        case .stageDisplay:
            if stageDisplayOutput == nil {
                stageDisplayOutput = StageDisplayOutput()
            }
            return stageDisplayOutput!
            
        case .audienceWebSocket:
            if audienceWebSocketOutput == nil {
                audienceWebSocketOutput = AudienceWebSocketOutput()
            }
            return audienceWebSocketOutput!
            
        case .audienceKeyboard:
            if audienceKeyboardOutput == nil {
                audienceKeyboardOutput = AudienceKeyboardOutput()
            }
            return audienceKeyboardOutput!
        }
    }
    
    /// Get all available outputs
    /// - Parameter settings: Settings to check for enabled outputs
    /// - Returns: Array of configured output instances
    func getEnabledOutputs(settings: ProPresenterSettings) -> [ProPresenterOutput] {
        var outputs: [ProPresenterOutput] = []
        
        if settings.stageDisplayEnabled {
            outputs.append(createOutput(for: .stageDisplay))
        }
        
        if settings.messagesAPIEnabled {
            outputs.append(createOutput(for: .audienceWebSocket))
        } else if settings.effectiveKeyboardAutomationEnabled {
            // Only use keyboard if Messages API is not enabled, and never in two-machine mode
            outputs.append(createOutput(for: .audienceKeyboard))
        }
        
        return outputs
    }
    
    /// Configure all outputs with settings
    func configureAll(with settings: ProPresenterSettings) {
        stageDisplayOutput?.configure(with: settings)
        audienceWebSocketOutput?.configure(with: settings)
        audienceKeyboardOutput?.configure(with: settings)
    }
    
    /// Reset all cached outputs
    func resetAll() {
        stageDisplayOutput = nil
        audienceWebSocketOutput = nil
        audienceKeyboardOutput = nil
    }
}
