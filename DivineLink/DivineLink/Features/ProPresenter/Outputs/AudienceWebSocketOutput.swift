import Foundation
import os
import Combine

/// Output implementation for ProPresenter Audience Display via WebSocket Messages API
class AudienceWebSocketOutput: NSObject, ProPresenterOutput {
    
    // MARK: - Properties
    
    let outputType: ProPresenterOutputType = .audienceWebSocket
    
    private(set) var connectionStatus: ConnectionStatus = .disconnected {
        didSet {
            Task { @MainActor in
                connectionStatusSubject.send(connectionStatus)
            }
        }
    }
    
    var isAvailable: Bool {
        connectionStatus == .connected
    }
    
    /// Publisher for connection status changes
    var connectionStatusPublisher: AnyPublisher<ConnectionStatus, Never> {
        connectionStatusSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    private var settings: ProPresenterSettings?
    
    private var isListening = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3
    private var currentMessageId: String?
    
    private let logger = Logger(subsystem: "com.divinelink", category: "AudienceWebSocketOutput")
    private let connectionStatusSubject = CurrentValueSubject<ConnectionStatus, Never>(.disconnected)
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialisation
    
    override init() {
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: - ProPresenterOutput Protocol
    
    func configure(with settings: ProPresenterSettings) {
        self.settings = settings
        
        // Disconnect existing connection if any
        disconnect()
        
        // Only auto-connect if Messages API is enabled
        if settings.messagesAPIEnabled {
            Task {
                _ = await connect()
            }
        }
    }
    
    func display(_ scripture: ScriptureDisplayData) async -> ProPresenterOutputResult {
        guard connectionStatus == .connected else {
            // Try to reconnect
            if await connect() {
                return await display(scripture)
            }
            return .unavailable(reason: "WebSocket not connected")
        }
        
        do {
            // First, create/update the message
            let messageId = try await sendMessage(scripture)
            currentMessageId = messageId
            
            // Then show the message
            try await showMessage(messageId)
            
            logger.info("Audience message displayed: \(scripture.reference)")
            return .success
            
        } catch {
            logger.error("Failed to display audience message: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    func clear() async -> ProPresenterOutputResult {
        guard connectionStatus == .connected else {
            return .unavailable(reason: "WebSocket not connected")
        }
        
        do {
            // Hide all messages
            try await hideAllMessages()
            
            logger.info("Audience messages cleared")
            return .success
            
        } catch {
            logger.error("Failed to clear audience messages: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    func testConnection() async -> Bool {
        let wasConnected = connectionStatus == .connected
        
        connectionStatus = .testing
        
        let connected = await connect()
        
        if !wasConnected && connected {
            // Stay connected for future use
        }
        
        return connected
    }
    
    // MARK: - WebSocket Connection
    
    private func connect() async -> Bool {
        guard let settings = settings, settings.messagesAPIEnabled else {
            return false
        }
        
        guard let wsURL = buildWebSocketURL(from: settings) else {
            logger.error("Invalid WebSocket URL")
            connectionStatus = .error("Invalid URL")
            return false
        }
        
        // Disconnect any existing connection
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        
        connectionStatus = .testing
        
        webSocketTask = session.webSocketTask(with: wsURL)
        webSocketTask?.resume()
        
        // Wait for connection confirmation via ping
        do {
            // Use withCheckedContinuation to bridge callback-based sendPing to async/await
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                webSocketTask?.sendPing { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
            
            connectionStatus = .connected
            reconnectAttempts = 0
            
            // Start listening for messages
            startListening()
            
            logger.info("WebSocket connected to \(wsURL.absoluteString)")
            return true
            
        } catch {
            logger.error("WebSocket connection failed: \(error.localizedDescription)")
            connectionStatus = .error(error.localizedDescription)
            return false
        }
    }
    
    private func disconnect() {
        isListening = false
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        connectionStatus = .disconnected
    }
    
    private func buildWebSocketURL(from settings: ProPresenterSettings) -> URL? {
        // ProPresenter Messages WebSocket is typically ws://host:port/messaging
        var components = URLComponents()
        components.scheme = "ws"
        components.host = settings.ipAddress
        components.port = settings.port
        components.path = "/messaging"
        
        return components.url
    }
    
    // MARK: - Message Listening
    
    private func startListening() {
        guard !isListening else { return }
        isListening = true
        
        Task {
            await listenForMessages()
        }
    }
    
    private func listenForMessages() async {
        while isListening, let webSocket = webSocketTask {
            do {
                let message = try await webSocket.receive()
                
                switch message {
                case .string(let text):
                    handleIncomingMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleIncomingMessage(text)
                    }
                @unknown default:
                    break
                }
                
            } catch {
                if isListening {
                    logger.error("WebSocket receive error: \(error.localizedDescription)")
                    await handleDisconnection()
                }
                break
            }
        }
    }
    
    private func handleIncomingMessage(_ text: String) {
        // Parse and handle ProPresenter messages (acknowledgements, etc.)
        logger.debug("WebSocket received: \(text)")
        
        // ProPresenter may send various message types
        // For now, we mainly care about connection health
    }
    
    private func handleDisconnection() async {
        guard isListening else { return }
        
        connectionStatus = .disconnected
        
        // Try to reconnect
        reconnectAttempts += 1
        
        if reconnectAttempts <= maxReconnectAttempts {
            logger.info("Attempting reconnection (\(self.reconnectAttempts)/\(self.maxReconnectAttempts))")
            
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
            
            if await connect() {
                logger.info("Reconnected successfully")
            }
        } else {
            logger.warning("Max reconnection attempts reached")
            isListening = false
        }
    }
    
    // MARK: - ProPresenter Messages API
    
    /// Send a message to be displayed
    private func sendMessage(_ scripture: ScriptureDisplayData) async throws -> String {
        guard let webSocket = webSocketTask else {
            throw ProPresenterError.notConnected
        }
        
        // Generate a unique message ID
        let messageId = "divinelink_\(UUID().uuidString.prefix(8))"
        
        // Build the message command
        // ProPresenter Messages API format
        let messagePayload: [String: Any] = [
            "action": "message_send",
            "message_id": messageId,
            "tokens": [
                [
                    "name": "Text",
                    "text": [
                        "text": scripture.audienceDisplayText
                    ]
                ]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: messagePayload)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
        
        try await webSocket.send(.string(jsonString))
        
        return messageId
    }
    
    /// Show a specific message by ID
    private func showMessage(_ messageId: String) async throws {
        guard let webSocket = webSocketTask else {
            throw ProPresenterError.notConnected
        }
        
        let showPayload: [String: Any] = [
            "action": "message_show",
            "message_id": messageId
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: showPayload)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
        
        try await webSocket.send(.string(jsonString))
    }
    
    /// Hide all messages
    private func hideAllMessages() async throws {
        guard let webSocket = webSocketTask else {
            throw ProPresenterError.notConnected
        }
        
        let hidePayload: [String: Any] = [
            "action": "message_hide"
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: hidePayload)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
        
        try await webSocket.send(.string(jsonString))
        
        currentMessageId = nil
    }
}

// MARK: - URLSessionWebSocketDelegate

extension AudienceWebSocketOutput: URLSessionWebSocketDelegate {
    
    func urlSession(_ session: URLSession, 
                    webSocketTask: URLSessionWebSocketTask, 
                    didOpenWithProtocol protocol: String?) {
        logger.info("WebSocket connection opened")
    }
    
    func urlSession(_ session: URLSession, 
                    webSocketTask: URLSessionWebSocketTask, 
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, 
                    reason: Data?) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "unknown"
        logger.info("WebSocket closed: \(closeCode.rawValue) - \(reasonString)")
        
        if isListening {
            Task {
                await handleDisconnection()
            }
        }
    }
}
