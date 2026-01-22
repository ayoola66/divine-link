import Foundation
import Combine
import os

// MARK: - ProPresenter Errors

enum ProPresenterError: LocalizedError {
    case notConfigured
    case invalidResponse
    case httpError(Int)
    case connectionFailed
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "ProPresenter connection not configured"
        case .invalidResponse:
            return "Invalid response from ProPresenter"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .connectionFailed:
            return "Failed to connect to ProPresenter"
        case .encodingFailed:
            return "Failed to encode message"
        }
    }
}

// MARK: - ProPresenter Client

/// Client for communicating with ProPresenter's Network API
class ProPresenterClient: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastError: Error?
    
    // MARK: - Private Properties
    
    private var baseURL: URL?
    private let session: URLSession
    private let logger = Logger(subsystem: "com.divinelink", category: "ProPresenter")
    
    private var reconnectTask: Task<Void, Never>?
    private let maxReconnectAttempts = 5
    private let reconnectDelay: TimeInterval = 2.0
    
    // MARK: - Initialisation
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 10.0
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Configuration
    
    func configure(baseURL: URL) {
        self.baseURL = baseURL
        connectionStatus = .unknown
        logger.info("Configured ProPresenter client: \(baseURL.absoluteString)")
    }
    
    func configure(settings: ProPresenterSettings) {
        if let url = settings.connectionURL {
            configure(baseURL: url)
        }
    }
    
    // MARK: - Connection Testing
    
    func testConnection() async throws -> Bool {
        guard let baseURL = baseURL else {
            throw ProPresenterError.notConfigured
        }
        return try await testConnection(to: baseURL)
    }
    
    func testConnection(to url: URL) async throws -> Bool {
        self.baseURL = url
        connectionStatus = .testing
        
        // Try to get ProPresenter version as health check
        let testURL = url.appendingPathComponent("v1/version")
        
        var request = URLRequest(url: testURL)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProPresenterError.invalidResponse
            }
            
            let success = (200...299).contains(httpResponse.statusCode)
            connectionStatus = success ? .connected : .disconnected
            
            logger.info("Connection test: \(success ? "success" : "failed")")
            return success
            
        } catch let error as ProPresenterError {
            connectionStatus = .error(error.localizedDescription)
            throw error
        } catch {
            logger.error("Connection test failed: \(error.localizedDescription)")
            connectionStatus = .error(error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - Stage Message
    
    /// Send a message to ProPresenter's stage display
    func sendStageMessage(_ message: String) async throws {
        guard let baseURL = baseURL else {
            throw ProPresenterError.notConfigured
        }
        
        let url = baseURL.appendingPathComponent("v1/stage/message")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // ProPresenter expects the message in a specific format
        let payload = ["message": message]
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            throw ProPresenterError.encodingFailed
        }
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProPresenterError.invalidResponse
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                throw ProPresenterError.httpError(httpResponse.statusCode)
            }
            
            logger.info("Stage message sent successfully")
            connectionStatus = .connected
            
        } catch {
            logger.error("Failed to send stage message: \(error.localizedDescription)")
            lastError = error
            connectionStatus = .error(error.localizedDescription)
            
            // Trigger reconnection attempt
            startReconnection()
            
            throw error
        }
    }
    
    /// Clear the stage message
    func clearStageMessage() async throws {
        try await sendStageMessage("")
    }
    
    /// Format a PendingVerse for ProPresenter stage display
    func formatStageMessage(from verse: PendingVerse) -> String {
        """
        \(verse.displayReference)
        
        \(verse.fullText)
        """
    }
    
    // MARK: - Reconnection
    
    private func startReconnection() {
        reconnectTask?.cancel()
        
        reconnectTask = Task { [weak self] in
            guard let self = self else { return }
            let maxAttempts = self.maxReconnectAttempts
            
            for attempt in 1...maxAttempts {
                guard !Task.isCancelled else { return }
                
                self.logger.info("Reconnection attempt \(attempt)/\(maxAttempts)")
                await MainActor.run { self.connectionStatus = .testing }
                
                try? await Task.sleep(nanoseconds: UInt64(self.reconnectDelay * 1_000_000_000))
                
                guard let baseURL = self.baseURL else { return }
                
                do {
                    let success = try await self.testConnection(to: baseURL)
                    if success {
                        self.logger.info("Reconnection successful")
                        return
                    }
                } catch {
                    self.logger.warning("Reconnection attempt \(attempt) failed")
                }
            }
            
            self.logger.error("All reconnection attempts failed")
            await MainActor.run { self.connectionStatus = .disconnected }
        }
    }
    
    func stopReconnection() {
        reconnectTask?.cancel()
        reconnectTask = nil
    }
}
