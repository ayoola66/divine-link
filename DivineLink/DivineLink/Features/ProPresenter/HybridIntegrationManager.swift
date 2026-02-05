import Foundation
import Combine
import os

/// Manages hybrid integration with ProPresenter across multiple output paths
/// Coordinates Stage Display, Messages API, and Keyboard automation
@MainActor
class HybridIntegrationManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = HybridIntegrationManager()
    
    // MARK: - Published Properties
    
    /// Overall system status
    @Published private(set) var systemStatus: SystemStatus = .idle
    
    /// Individual output statuses
    @Published private(set) var outputStatuses: [ProPresenterOutputType: ConnectionStatus] = [:]
    
    /// Last error message
    @Published private(set) var lastError: String?
    
    /// Last successful output used
    @Published private(set) var lastSuccessfulOutput: ProPresenterOutputType?
    
    // MARK: - Dependencies
    
    private let settings: ProPresenterSettings
    private let factory: ProPresenterOutputFactory
    private let subscriptionService: SubscriptionService
    private let logger = Logger(subsystem: "com.divinelink", category: "HybridIntegration")
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - System Status
    
    enum SystemStatus: Equatable {
        case idle
        case configuring
        case ready
        case sending
        case error(String)
        
        var displayText: String {
            switch self {
            case .idle: return "Not Configured"
            case .configuring: return "Configuring..."
            case .ready: return "Ready"
            case .sending: return "Sending..."
            case .error(let message): return "Error: \(message)"
            }
        }
        
        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }
    }
    
    // MARK: - Initialisation
    
    private init() {
        // Explicit initialization to avoid MainActor isolation warnings with default parameters
        self.settings = ProPresenterSettings()
        self.factory = ProPresenterOutputFactory.shared
        self.subscriptionService = SubscriptionService.shared
        
        setupBindings()
    }
    
    private func setupBindings() {
        // React to settings changes
        settings.$stageDisplayEnabled
            .combineLatest(settings.$messagesAPIEnabled, settings.$keyboardAutomationEnabled)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.reconfigure()
                }
            }
            .store(in: &cancellables)
        
        // React to IP/port changes
        settings.$ipAddress
            .combineLatest(settings.$port)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.reconfigure()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Configuration
    
    /// Configure all enabled outputs
    func configure() async {
        systemStatus = .configuring
        logger.info("Configuring hybrid integration...")
        
        // Configure factory with current settings
        factory.configureAll(with: settings)
        
        // Test all enabled outputs
        await testAllConnections()
        
        // Determine overall system status
        let hasConnected = outputStatuses.values.contains(.connected)
        systemStatus = hasConnected ? .ready : .error("No outputs connected")
        
        logger.info("Hybrid integration configured. Status: \(self.systemStatus.displayText)")
    }
    
    /// Reconfigure after settings change
    func reconfigure() async {
        factory.resetAll()
        await configure()
    }
    
    // MARK: - Connection Testing
    
    /// Test all enabled output connections
    func testAllConnections() async {
        outputStatuses.removeAll()
        
        for outputType in settings.enabledOutputTypes {
            // Check premium requirement
            if outputType.requiresPremium && !subscriptionService.canUsePremiumFeatures {
                outputStatuses[outputType] = .error("Premium required")
                continue
            }
            
            let output = factory.createOutput(for: outputType)
            output.configure(with: settings)
            
            let connected = await output.testConnection()
            outputStatuses[outputType] = connected ? .connected : .disconnected
            
            logger.info("\(outputType.displayName) connection: \(connected ? "OK" : "Failed")")
        }
    }
    
    /// Test a specific output connection
    func testConnection(for outputType: ProPresenterOutputType) async -> Bool {
        let output = factory.createOutput(for: outputType)
        output.configure(with: settings)
        
        let connected = await output.testConnection()
        outputStatuses[outputType] = connected ? .connected : .disconnected
        
        return connected
    }
    
    // MARK: - Display Operations
    
    /// Display scripture using all enabled outputs
    /// Uses priority order: Stage Display first, then Audience (WebSocket preferred over Keyboard)
    func displayScripture(_ scripture: ScriptureDisplayData) async -> Bool {
        if !systemStatus.isReady {
            logger.warning("System not ready, attempting to configure...")
            await configure()
            
            guard systemStatus.isReady else {
                lastError = "System not configured"
                return false
            }
        }
        
        systemStatus = .sending
        var anySuccess = false
        var lastFailure: String?
        
        // Get outputs in priority order
        let outputs = getOutputsInPriorityOrder()
        
        for output in outputs {
            // Check premium requirement
            if output.outputType.requiresPremium && !subscriptionService.canUsePremiumFeatures {
                continue
            }
            
            let result = await output.display(scripture)
            
            switch result {
            case .success:
                anySuccess = true
                lastSuccessfulOutput = output.outputType
                outputStatuses[output.outputType] = .connected
                logger.info("Successfully displayed via \(output.outputType.displayName)")
                
            case .failure(let error):
                lastFailure = error.localizedDescription
                outputStatuses[output.outputType] = .error(error.localizedDescription)
                logger.warning("Failed to display via \(output.outputType.displayName): \(error.localizedDescription)")
                
                // Try fallback if enabled
                if settings.autoFallbackEnabled && output.outputType == .audienceWebSocket {
                    if let fallbackResult = await tryFallback(scripture: scripture) {
                        anySuccess = anySuccess || fallbackResult
                    }
                }
                
            case .unavailable(let reason):
                outputStatuses[output.outputType] = .disconnected
                logger.warning("\(output.outputType.displayName) unavailable: \(reason)")
            }
        }
        
        systemStatus = anySuccess ? .ready : .error(lastFailure ?? "All outputs failed")
        lastError = anySuccess ? nil : lastFailure
        
        return anySuccess
    }
    
    /// Clear all active displays
    func clearAllDisplays() async -> Bool {
        var anySuccess = false
        
        let outputs = getOutputsInPriorityOrder()
        
        for output in outputs {
            let result = await output.clear()
            
            if result.isSuccess {
                anySuccess = true
                logger.info("Cleared \(output.outputType.displayName)")
            }
        }
        
        return anySuccess
    }
    
    // MARK: - Priority & Fallback
    
    /// Get outputs in priority order
    private func getOutputsInPriorityOrder() -> [ProPresenterOutput] {
        var outputs: [ProPresenterOutput] = []
        
        // Stage Display first (for operators)
        if settings.stageDisplayEnabled {
            outputs.append(factory.createOutput(for: .stageDisplay))
        }
        
        // Audience outputs (WebSocket preferred)
        if settings.messagesAPIEnabled && subscriptionService.canUsePremiumFeatures {
            outputs.append(factory.createOutput(for: .audienceWebSocket))
        } else if settings.keyboardAutomationEnabled {
            outputs.append(factory.createOutput(for: .audienceKeyboard))
        }
        
        return outputs
    }
    
    /// Try keyboard automation as fallback
    private func tryFallback(scripture: ScriptureDisplayData) async -> Bool? {
        guard settings.keyboardAutomationEnabled else { return nil }
        
        logger.info("Attempting keyboard automation fallback...")
        
        let keyboardOutput = factory.createOutput(for: .audienceKeyboard)
        keyboardOutput.configure(with: settings)
        
        let result = await keyboardOutput.display(scripture)
        
        if result.isSuccess {
            logger.info("Keyboard fallback successful")
            outputStatuses[.audienceKeyboard] = .connected
            lastSuccessfulOutput = .audienceKeyboard
            return true
        } else {
            logger.warning("Keyboard fallback failed")
            return false
        }
    }
    
    // MARK: - Status Helpers
    
    /// Get status for a specific output
    func status(for outputType: ProPresenterOutputType) -> ConnectionStatus {
        outputStatuses[outputType] ?? .unknown
    }
    
    /// Check if a specific output is available
    func isAvailable(_ outputType: ProPresenterOutputType) -> Bool {
        if outputType.requiresPremium && !subscriptionService.canUsePremiumFeatures {
            return false
        }
        return outputStatuses[outputType] == .connected
    }
    
    /// Get summary of all output statuses
    var statusSummary: String {
        let connected = outputStatuses.filter { $0.value == .connected }.count
        let total = outputStatuses.count
        return "\(connected)/\(total) outputs connected"
    }
}
