import Foundation
import os

/// Output implementation for ProPresenter Stage Display via HTTP REST API
class StageDisplayOutput: ProPresenterOutput {
    
    // MARK: - Properties
    
    let outputType: ProPresenterOutputType = .stageDisplay
    
    private(set) var connectionStatus: ConnectionStatus = .unknown
    
    var isAvailable: Bool {
        connectionStatus == .connected
    }
    
    // MARK: - Private Properties
    
    private var baseURL: URL?
    private let session: URLSession
    private let logger = Logger(subsystem: "com.divinelink", category: "StageDisplayOutput")
    
    // MARK: - Initialisation
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 10.0
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - ProPresenterOutput Protocol
    
    func configure(with settings: ProPresenterSettings) {
        self.baseURL = settings.connectionURL
        connectionStatus = .unknown
        logger.info("Configured StageDisplayOutput: \(settings.connectionURL?.absoluteString ?? "nil")")
    }
    
    func display(_ scripture: ScriptureDisplayData) async -> ProPresenterOutputResult {
        guard let baseURL = baseURL else {
            return .unavailable(reason: "Not configured")
        }
        
        let url = baseURL.appendingPathComponent("v1/stage/message")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // ProPresenter expects just a JSON string
        let message = scripture.stageDisplayText
        
        do {
            request.httpBody = try JSONEncoder().encode(message)
        } catch {
            return .failure(ProPresenterError.encodingFailed)
        }
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(ProPresenterError.invalidResponse)
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                return .failure(ProPresenterError.httpError(httpResponse.statusCode))
            }
            
            connectionStatus = .connected
            logger.info("Stage display message sent: \(scripture.reference)")
            return .success
            
        } catch {
            logger.error("Failed to send stage message: \(error.localizedDescription)")
            connectionStatus = .error(error.localizedDescription)
            return .failure(error)
        }
    }
    
    func clear() async -> ProPresenterOutputResult {
        guard let baseURL = baseURL else {
            return .unavailable(reason: "Not configured")
        }
        
        let url = baseURL.appendingPathComponent("v1/stage/message")
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(ProPresenterError.invalidResponse)
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                return .failure(ProPresenterError.httpError(httpResponse.statusCode))
            }
            
            logger.info("Stage display cleared")
            return .success
            
        } catch {
            logger.error("Failed to clear stage message: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    func testConnection() async -> Bool {
        guard let baseURL = baseURL else {
            connectionStatus = .disconnected
            return false
        }
        
        connectionStatus = .testing
        
        // Try to get ProPresenter version as health check
        let testURL = baseURL.appendingPathComponent("version")
        
        var request = URLRequest(url: testURL)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                connectionStatus = .disconnected
                return false
            }
            
            let success = (200...299).contains(httpResponse.statusCode)
            connectionStatus = success ? .connected : .disconnected
            
            logger.info("Stage display connection test: \(success ? "success" : "failed")")
            return success
            
        } catch {
            logger.error("Stage display connection test failed: \(error.localizedDescription)")
            connectionStatus = .error(error.localizedDescription)
            return false
        }
    }
}
