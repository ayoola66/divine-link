# Story 6.4: ProPresenter WebSocket Messages API Implementation

**Epic:** 6 - Operator Safety & Detection Confidence  
**Story ID:** 6.4  
**Status:** ✅ Complete  
**Complexity:** Large  
**Priority:** P1 (Technical Improvement)

**Implementation Files:**
- `DivineLink/Features/ProPresenter/Outputs/AudienceWebSocketOutput.swift`
- `DivineLink/Features/ProPresenter/ProPresenterOutputProtocol.swift`
- `DivineLink/Features/ProPresenter/ProPresenterOutputFactory.swift` (if separate) or within HybridIntegrationManager

---

## User Story

**As an** operator using Divine Link with ProPresenter,  
**I want** scriptures to be displayed via the WebSocket Messages API,  
**so that** verses appear on the Audience screen reliably without requiring window focus or accessibility permissions.

---

## Background

Story 6.3 research confirmed:
1. **Direct slide text injection is NOT available** via ProPresenter API
2. **Messages API CAN display on Audience screen** via Looks routing
3. **WebSocket is required** for `messageSend` (HTTP REST only supports Stage Display)

This story implements the WebSocket Messages API integration as the primary method for Premium/Pro tiers, with keyboard automation as fallback for Mercy tier or unconfigured setups.

---

## Prerequisites

- [x] Story 6.3 completed with positive recommendation for Messages API
- [x] ProPresenter 7+ confirmed as minimum supported version
- [x] Looks routing mechanism verified for Audience screen
- [ ] WebSocket client implementation for ProPresenter

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Scripture displays on Audience screen via Messages API | Verse appears in ProPresenter via Looks |
| 2 | Reference and text show correctly formatted | Uses church's message template |
| 3 | WebSocket connection established with ProPresenter | Connected status shown |
| 4 | Authentication handled (if password set) | Password stored securely in Keychain |
| 5 | Message clears when requested | `messageHide` API called |
| 6 | Fallback to keyboard if WebSocket fails | Graceful degradation |
| 7 | User can configure message template index | Settings option available |
| 8 | Setup guide for Looks configuration | Help documentation included |
| 9 | Connection status indicator in UI | Real-time status badge |
| 10 | Factory Pattern enables swappable outputs | Architecture supports multiple output methods |

---

## Technical Notes

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Divine Link                                  │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                ProPresenterOutputFactory                        │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐   │ │
│  │  │ StageDisplay │  │ AudienceAPI  │  │ AudienceFallback   │   │ │
│  │  │  (HTTP PUT)  │  │ (WebSocket)  │  │ (Keyboard)         │   │ │
│  │  └──────────────┘  └──────────────┘  └────────────────────┘   │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
                              │
            ┌─────────────────┼─────────────────┐
            ▼                 ▼                 ▼
   HTTP REST (:1025)    WebSocket (:1025)   Keyboard Sim
   /v1/stage/message    /remote             CGEvent
            │                 │                 │
            ▼                 ▼                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       ProPresenter 7+                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │ Stage Display│  │ Audience     │  │ Audience (Bible View)    │  │
│  │ (Confidence) │  │ (via Looks)  │  │ (via ⌘B)                 │  │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### Factory Pattern Implementation

```swift
// ProPresenterOutput.swift
import Foundation

/// Protocol for all ProPresenter output methods
protocol ProPresenterOutput {
    var displayName: String { get }
    var isAvailable: Bool { get }
    var requiresConfiguration: Bool { get }
    
    func display(reference: String, text: String) async throws
    func clear() async throws
    func checkConnection() async -> Bool
}

/// Factory to create appropriate output based on tier and configuration
class ProPresenterOutputFactory {
    enum OutputType: String, CaseIterable {
        case stageDisplay = "Stage Display (HTTP)"
        case audienceWebSocket = "Audience Screen (Messages API)"
        case audienceKeyboard = "Audience Screen (Keyboard)"
    }
    
    static func createOutput(
        type: OutputType,
        host: String = "localhost",
        port: Int = 1025,
        password: String? = nil
    ) -> ProPresenterOutput {
        switch type {
        case .stageDisplay:
            return StageDisplayOutput(host: host, port: port)
        case .audienceWebSocket:
            return AudienceWebSocketOutput(host: host, port: port, password: password)
        case .audienceKeyboard:
            return AudienceKeyboardOutput()
        }
    }
    
    /// Returns available outputs for the user's subscription tier
    static func availableOutputs(for tier: SubscriptionTier) -> [OutputType] {
        switch tier {
        case .mercy:
            return [.stageDisplay, .audienceKeyboard]
        case .grace, .love:
            return [.stageDisplay, .audienceWebSocket, .audienceKeyboard]
        }
    }
}
```

### WebSocket Messages Implementation

```swift
// AudienceWebSocketOutput.swift
import Foundation

class AudienceWebSocketOutput: NSObject, ProPresenterOutput, URLSessionWebSocketDelegate {
    let displayName = "Audience Screen (Messages API)"
    var isAvailable: Bool { isConnected }
    let requiresConfiguration = true
    
    private var webSocket: URLSessionWebSocketTask?
    private let host: String
    private let port: Int
    private let password: String?
    private var isConnected = false
    private var messageTemplateIndex: Int = 0
    
    init(host: String, port: Int, password: String?) {
        self.host = host
        self.port = port
        self.password = password
        super.init()
    }
    
    // MARK: - Connection
    
    func connect() async throws {
        let url = URL(string: "ws://\(host):\(port)/remote")!
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        
        // Authenticate
        let authMessage: [String: Any] = [
            "action": "authenticate",
            "protocol": 701,
            "password": password ?? ""
        ]
        try await send(authMessage)
        
        // Start receiving messages
        receiveMessages()
        
        isConnected = true
    }
    
    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        isConnected = false
    }
    
    // MARK: - ProPresenterOutput Protocol
    
    func checkConnection() async -> Bool {
        if !isConnected {
            try? await connect()
        }
        return isConnected
    }
    
    func display(reference: String, text: String) async throws {
        guard isConnected else {
            throw ProPresenterError.notConnected
        }
        
        // Format verse for multi-line display
        let formattedText = formatVerseText(text, reference: reference)
        
        let message: [String: Any] = [
            "action": "messageSend",
            "messageIndex": messageTemplateIndex,
            "messageKeys": ["ScriptureText", "Reference"],
            "messageValues": [formattedText, reference]
        ]
        
        try await send(message)
    }
    
    func clear() async throws {
        guard isConnected else { return }
        
        let message: [String: Any] = [
            "action": "messageHide",
            "messageIndex": messageTemplateIndex
        ]
        
        try await send(message)
    }
    
    // MARK: - Private Helpers
    
    private func send(_ message: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: message)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ProPresenterError.encodingFailed
        }
        
        try await webSocket?.send(.string(jsonString))
    }
    
    private func receiveMessages() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessages() // Continue listening
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self?.isConnected = false
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            if let data = text.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                handleResponse(json)
            }
        case .data(let data):
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                handleResponse(json)
            }
        @unknown default:
            break
        }
    }
    
    private func handleResponse(_ json: [String: Any]) {
        if let action = json["action"] as? String {
            switch action {
            case "authenticate":
                if let authenticated = json["authenticated"] as? Bool, authenticated {
                    print("ProPresenter WebSocket authenticated")
                    isConnected = true
                } else {
                    print("ProPresenter WebSocket authentication failed")
                    isConnected = false
                }
            case "messageResponse":
                // Handle message template list response
                break
            default:
                break
            }
        }
    }
    
    private func formatVerseText(_ text: String, reference: String) -> String {
        // Add reference on separate line if long verse
        if text.count > 100 {
            return "\(text)\n\n— \(reference)"
        }
        return text
    }
    
    // MARK: - URLSessionWebSocketDelegate
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, 
                    didOpenWithProtocol protocol: String?) {
        print("WebSocket connected")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, 
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        isConnected = false
    }
}

enum ProPresenterError: LocalizedError {
    case notConnected
    case encodingFailed
    case authenticationFailed
    case messageNotConfigured
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to ProPresenter"
        case .encodingFailed:
            return "Failed to encode message"
        case .authenticationFailed:
            return "ProPresenter authentication failed"
        case .messageNotConfigured:
            return "No message template configured in ProPresenter"
        }
    }
}
```

### Stage Display Output (HTTP - Already Implemented)

```swift
// StageDisplayOutput.swift
import Foundation

class StageDisplayOutput: ProPresenterOutput {
    let displayName = "Stage Display (HTTP)"
    var isAvailable: Bool { lastCheckSucceeded }
    let requiresConfiguration = false
    
    private let baseURL: URL
    private let session: URLSession
    private var lastCheckSucceeded = false
    
    init(host: String, port: Int) {
        self.baseURL = URL(string: "http://\(host):\(port)/v1")!
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        self.session = URLSession(configuration: config)
    }
    
    func checkConnection() async -> Bool {
        do {
            let url = baseURL.appendingPathComponent("status")
            let (_, response) = try await session.data(from: url)
            lastCheckSucceeded = (response as? HTTPURLResponse)?.statusCode == 200
            return lastCheckSucceeded
        } catch {
            lastCheckSucceeded = false
            return false
        }
    }
    
    func display(reference: String, text: String) async throws {
        let url = baseURL.appendingPathComponent("stage/message")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = "\(reference)\n\(text)".data(using: .utf8)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ProPresenterError.notConnected
        }
    }
    
    func clear() async throws {
        let url = baseURL.appendingPathComponent("stage/message")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, _) = try await session.data(for: request)
    }
}
```

### Keyboard Fallback Output (Existing)

```swift
// AudienceKeyboardOutput.swift
import Foundation
import ApplicationServices

class AudienceKeyboardOutput: ProPresenterOutput {
    let displayName = "Audience Screen (Keyboard)"
    var isAvailable: Bool { AXIsProcessTrusted() }
    let requiresConfiguration = false
    
    private let keyboardService = KeyboardAutomationService.shared
    
    func checkConnection() async -> Bool {
        return AXIsProcessTrusted()
    }
    
    func display(reference: String, text: String) async throws {
        await keyboardService.pushToProPresenterBible(reference: reference)
    }
    
    func clear() async throws {
        await keyboardService.clearProPresenterBible()
    }
}
```

### Integration Manager

```swift
// ProPresenterIntegrationManager.swift
import Foundation
import Combine

class ProPresenterIntegrationManager: ObservableObject {
    @Published var stageOutput: ProPresenterOutput
    @Published var audienceOutput: ProPresenterOutput
    @Published var stageConnected = false
    @Published var audienceConnected = false
    
    private let settings: ProPresenterSettings
    private var cancellables = Set<AnyCancellable>()
    
    init(settings: ProPresenterSettings) {
        self.settings = settings
        
        // Create outputs based on tier
        let tier = SubscriptionService.shared.currentTier
        let availableOutputs = ProPresenterOutputFactory.availableOutputs(for: tier)
        
        // Stage always uses HTTP
        stageOutput = ProPresenterOutputFactory.createOutput(
            type: .stageDisplay,
            host: settings.host,
            port: settings.port
        )
        
        // Audience uses WebSocket for Premium, Keyboard for Free
        if availableOutputs.contains(.audienceWebSocket) && settings.useMessagesAPI {
            audienceOutput = ProPresenterOutputFactory.createOutput(
                type: .audienceWebSocket,
                host: settings.host,
                port: settings.port,
                password: settings.password
            )
        } else {
            audienceOutput = ProPresenterOutputFactory.createOutput(
                type: .audienceKeyboard
            )
        }
        
        // Start connection monitoring
        Task { await checkConnections() }
    }
    
    func checkConnections() async {
        stageConnected = await stageOutput.checkConnection()
        audienceConnected = await audienceOutput.checkConnection()
    }
    
    func displayToStage(reference: String, text: String) async throws {
        try await stageOutput.display(reference: reference, text: text)
    }
    
    func displayToAudience(reference: String, text: String) async throws {
        do {
            try await audienceOutput.display(reference: reference, text: text)
        } catch {
            // If WebSocket fails, try keyboard fallback
            if audienceOutput is AudienceWebSocketOutput {
                let fallback = ProPresenterOutputFactory.createOutput(type: .audienceKeyboard)
                try await fallback.display(reference: reference, text: text)
            } else {
                throw error
            }
        }
    }
    
    func clearAll() async {
        try? await stageOutput.clear()
        try? await audienceOutput.clear()
    }
}
```

---

## User Setup Requirements

### One-Time ProPresenter Configuration

For Messages API to display on Audience screen:

1. **Enable Messages Layer in Look**
   - Open ProPresenter → View → Looks
   - Select your Audience Look preset
   - Enable "Messages" layer checkbox
   - Save the Look

2. **Create Scripture Message Template**
   - Go to Messages → New Message
   - Add tokens: `${ScriptureText}`, `${Reference}`
   - Name it "Scripture" or "Divine Link"
   - Style to match church branding

3. **Enable Network API**
   - ProPresenter Preferences → Network
   - Enable "Enable Network"
   - Note the port (default: 1025)
   - Set password if desired

---

## Settings UI Updates

```swift
struct ProPresenterSettingsView: View {
    @ObservedObject var manager: ProPresenterIntegrationManager
    @StateObject private var settings = ProPresenterSettings.shared
    
    var body: some View {
        Form {
            Section("Connection") {
                TextField("Host", text: $settings.host)
                TextField("Port", value: $settings.port, format: .number)
                SecureField("Password", text: $settings.password)
                
                HStack {
                    Button("Test Connection") {
                        Task { await manager.checkConnections() }
                    }
                    Spacer()
                    ConnectionStatusBadge(
                        stage: manager.stageConnected,
                        audience: manager.audienceConnected
                    )
                }
            }
            
            Section("Audience Screen Method") {
                Toggle("Use Messages API (Premium)", isOn: $settings.useMessagesAPI)
                    .disabled(!SubscriptionService.shared.isPremium)
                
                if settings.useMessagesAPI {
                    Stepper("Message Template Index: \(settings.messageTemplateIndex)",
                            value: $settings.messageTemplateIndex, in: 0...10)
                    
                    Link("Setup Guide: Configure Messages Layer",
                         destination: URL(string: "https://divinelink.app/docs/propresenter-setup")!)
                }
            }
        }
    }
}
```

---

## Dependencies

- Story 6.3 (Research) - COMPLETE
- Story 3.6 (ProPresenter Connection) - Existing Stage Display implementation
- Story 6.1 (Panic Button) - Clear integration via Factory outputs

---

## Definition of Done

- [ ] Factory Pattern implemented with `ProPresenterOutput` protocol
- [ ] `AudienceWebSocketOutput` connects via WebSocket
- [ ] `messageSend` correctly displays on Audience screen (via Looks)
- [ ] `messageHide` clears the message
- [ ] Fallback to keyboard if WebSocket unavailable
- [ ] Connection status indicators in Settings
- [ ] Premium tier check for Messages API access
- [ ] Setup documentation for Looks configuration
- [ ] Unit tests for Factory and outputs
- [ ] Integration tests with ProPresenter
- [ ] Committed to Git

---

## Testing Scenarios

| Scenario | Expected Result |
|----------|-----------------|
| Premium user with Messages API configured | Verse via WebSocket |
| Premium user without Looks configured | Falls back to keyboard |
| Free user | Uses keyboard automation |
| WebSocket disconnects mid-service | Auto-fallback to keyboard |
| Password required but not configured | Auth error, prompt user |
| Message template deleted in PP | Error shown, guide to recreate |
| Both Stage and Audience enabled | Both outputs receive content |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| WebSocket API changes in PP update | Low | High | Abstract via Factory Pattern |
| Looks not configured by user | Medium | Medium | Clear setup documentation |
| Authentication complexity | Low | Medium | Keychain storage, clear errors |
| Dual-output timing issues | Low | Low | Sequential async calls |

---

## Estimated Effort

| Task | Hours |
|------|-------|
| ProPresenterOutput protocol | 1 |
| Factory implementation | 2 |
| AudienceWebSocketOutput | 6 |
| Integration manager | 3 |
| Settings UI updates | 2 |
| Fallback logic | 2 |
| Testing & debugging | 4 |
| Documentation | 2 |
| **Total** | **22** |

---

## Notes

- Factory Pattern allows easy addition of future output methods
- WebSocket maintains persistent connection for lower latency
- Keyboard fallback ensures reliability for all users
- Tier-based feature gating via SubscriptionService
