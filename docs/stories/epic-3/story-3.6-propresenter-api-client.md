# Story 3.6: ProPresenter API Client

**Epic:** 3 - Pending Buffer & ProPresenter Integration  
**Story ID:** 3.6  
**Status:** Not Started  
**Complexity:** Medium  

---

## User Story

**As a** developer,  
**I want** a client that communicates with ProPresenter's Network API,  
**so that** approved scriptures can be displayed on stage screens.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | `ProPresenterClient` class created | Class compiles and initialises |
| 2 | Client connects to ProPresenter at configured IP:port | Connection established |
| 3 | Client implements `PUT /v1/stage/message` endpoint | Stage message updates |
| 4 | Client handles connection errors gracefully | Errors caught, not crashed |
| 5 | Client supports automatic reconnection on failure | Reconnects after disconnect |
| 6 | Client exposes connection status as published property | Status observable |
| 7 | Client uses async/await for network operations | Modern Swift concurrency |

---

## Technical Notes

### ProPresenterClient Implementation

```swift
import Foundation
import Combine
import os

class ProPresenterClient: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastError: Error?
    
    private var baseURL: URL?
    private let session: URLSession
    private let logger = Logger(subsystem: "com.divinelink", category: "ProPresenter")
    
    private var reconnectTask: Task<Void, Never>?
    private let maxReconnectAttempts = 5
    private let reconnectDelay: TimeInterval = 2.0
    
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
    }
    
    // MARK: - Connection Testing
    
    func testConnection(to url: URL) async throws -> Bool {
        self.baseURL = url
        
        // Try to get current stage message as health check
        let testURL = url.appendingPathComponent("v1/stage/message")
        
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
            
        } catch {
            logger.error("Connection test failed: \(error.localizedDescription)")
            connectionStatus = .error(error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - Stage Message
    
    func sendStageMessage(_ message: String) async throws {
        guard let baseURL = baseURL else {
            throw ProPresenterError.notConfigured
        }
        
        let url = baseURL.appendingPathComponent("v1/stage/message")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // ProPresenter expects the message as a JSON string
        let jsonData = try JSONEncoder().encode(message)
        request.httpBody = jsonData
        
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
    
    func clearStageMessage() async throws {
        try await sendStageMessage("")
    }
    
    // MARK: - Reconnection
    
    private func startReconnection() {
        reconnectTask?.cancel()
        
        reconnectTask = Task {
            for attempt in 1...maxReconnectAttempts {
                guard !Task.isCancelled else { return }
                
                logger.info("Reconnection attempt \(attempt)/\(maxReconnectAttempts)")
                connectionStatus = .testing
                
                try? await Task.sleep(nanoseconds: UInt64(reconnectDelay * 1_000_000_000))
                
                guard let baseURL = baseURL else { return }
                
                do {
                    let success = try await testConnection(to: baseURL)
                    if success {
                        logger.info("Reconnection successful")
                        return
                    }
                } catch {
                    logger.warning("Reconnection attempt \(attempt) failed")
                }
            }
            
            logger.error("All reconnection attempts failed")
            connectionStatus = .disconnected
        }
    }
    
    func stopReconnection() {
        reconnectTask?.cancel()
        reconnectTask = nil
    }
}

// MARK: - Errors

enum ProPresenterError: LocalizedError {
    case notConfigured
    case invalidResponse
    case httpError(Int)
    case connectionFailed
    
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
        }
    }
}
```

### Message Formatting

```swift
extension ProPresenterClient {
    /// Format a PendingVerse for ProPresenter stage display
    func formatStageMessage(from verse: PendingVerse) -> String {
        """
        \(verse.displayReference)
        
        \(verse.fullText)
        """
    }
}
```

### Usage Example

```swift
class PushCoordinator {
    private let ppClient: ProPresenterClient
    private let bufferManager: BufferManager
    
    func pushCurrentVerse() async throws {
        guard let verse = bufferManager.approveCurrentVerse() else {
            return
        }
        
        let message = ppClient.formatStageMessage(from: verse)
        try await ppClient.sendStageMessage(message)
    }
}
```

---

## Dependencies

- Story 3.5 (ProPresenter Connection Settings)

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] Stage message sends successfully
- [ ] Connection errors handled
- [ ] Automatic reconnection works
- [ ] Status updates reactively
- [ ] Tested with real ProPresenter instance
- [ ] Committed to Git
