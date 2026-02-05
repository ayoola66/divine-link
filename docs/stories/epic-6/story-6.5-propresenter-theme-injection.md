# Story 6.5: ProPresenter Hybrid Integration Manager

**Epic:** 6 - Operator Safety & Detection Confidence  
**Story ID:** 6.5  
**Status:** ✅ Complete  
**Complexity:** Large  
**Priority:** P0 (Critical - "Pro Grade" Requirement)

**Implementation Files:**
- `DivineLink/Features/ProPresenter/HybridIntegrationManager.swift`
- `DivineLink/Features/ProPresenter/Outputs/StageDisplayOutput.swift`
- `DivineLink/Features/ProPresenter/Outputs/AudienceKeyboardOutput.swift`
- `DivineLink/Features/ProPresenter/ProPresenterSettings.swift`

---

## User Story

**As an** operator using Divine Link,  
**I want** a unified integration system that intelligently manages all ProPresenter output paths,  
**so that** scriptures display reliably whether I'm using Stage Display, Audience screen, or both, with automatic fallbacks if any path fails.

---

## Background

Divine Link needs to support three distinct ProPresenter output paths:

| Path | Method | Target | Tier | Status |
|------|--------|--------|------|--------|
| Stage Display | HTTP REST `/v1/stage/message` | Confidence monitor | All | ✅ Implemented |
| Audience (Primary) | WebSocket `messageSend` | Main screen via Looks | Grace/Love | Story 6.4 |
| Audience (Fallback) | Keyboard ⌘B | Bible view | All | ✅ Implemented |

This story implements the **Hybrid Integration Manager** - an orchestration layer that:
1. Detects which paths are available
2. Routes scripture to appropriate outputs based on tier
3. Provides automatic fallback if primary method fails
4. Monitors connection health across all paths
5. Integrates with Panic Button (Story 6.1) for unified clear

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Unified API for scripture display | Single method routes to all configured outputs |
| 2 | Automatic fallback on failure | WebSocket failure → Keyboard automatically |
| 3 | Messages layer detection | Checks `looksRequest` for Audience routing |
| 4 | Setup guide for Looks configuration | Step-by-step instructions in app |
| 5 | Tier-based output selection | Mercy uses keyboard, Grace/Love uses WebSocket |
| 6 | Connection health dashboard | Status for all three paths |
| 7 | Panic button clears all paths | Single clear command to all outputs |
| 8 | Manual path override in settings | User can force specific method |
| 9 | Retry logic with backoff | Reconnects on transient failures |
| 10 | Logging of path decisions | Debug log shows which path used |

---

## Technical Notes

### Architecture: Hybrid Integration Manager

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              Divine Link                                       │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                    HybridIntegrationManager                             │  │
│  │  ┌────────────────────────────────────────────────────────────────┐   │  │
│  │  │                    PathDecisionEngine                           │   │  │
│  │  │  - Tier detection (Mercy/Grace/Love)                            │   │  │
│  │  │  - Messages layer availability                                  │   │  │
│  │  │  - Connection health per path                                   │   │  │
│  │  │  - User preference overrides                                    │   │  │
│  │  └────────────────────────────────────────────────────────────────┘   │  │
│  │  ┌─────────────┐  ┌─────────────────┐  ┌────────────────────────┐   │  │
│  │  │ StageOutput │  │ AudienceWebSocket │  │ AudienceKeyboard     │   │  │
│  │  │ (HTTP PUT)  │  │ (WebSocket)       │  │ (CGEvent)            │   │  │
│  │  └─────────────┘  └─────────────────┘  └────────────────────────┘   │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                    │                                          │
│  ┌────────────────────────────────┴───────────────────────────────────────┐  │
│  │                    ConnectionHealthMonitor                               │  │
│  │  Stage: ✅ Connected  |  Audience API: ⚠️ Connecting  |  Keyboard: ✅     │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
                                    │
              ┌─────────────────────┼─────────────────────┐
              ▼                     ▼                     ▼
    HTTP REST (:1025)        WebSocket (:1025)      Keyboard Sim
    /v1/stage/message        /remote → messageSend  CGEvent
              │                     │                     │
              ▼                     ▼                     ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                            ProPresenter 7+                                    │
│  ┌──────────────────┐  ┌──────────────────────┐  ┌────────────────────────┐ │
│  │ Stage Display    │  │ Audience Screen      │  │ Audience Screen        │ │
│  │ (Confidence)     │  │ (Messages via Looks) │  │ (Bible via ⌘B)         │ │
│  └──────────────────┘  └──────────────────────┘  └────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Hybrid Integration Manager Implementation

```swift
// HybridIntegrationManager.swift
import Foundation
import Combine

/// Orchestrates all ProPresenter output paths with intelligent routing and fallback
class HybridIntegrationManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published var stageStatus: ConnectionStatus = .disconnected
    @Published var audienceAPIStatus: ConnectionStatus = .disconnected
    @Published var keyboardStatus: ConnectionStatus = .available
    @Published var currentAudiencePath: AudiencePath = .keyboard
    @Published var lastPathDecision: PathDecision?
    
    // MARK: - Outputs (Factory-created)
    
    private var stageOutput: ProPresenterOutput
    private var audienceWebSocket: ProPresenterOutput
    private var audienceKeyboard: ProPresenterOutput
    
    // MARK: - Configuration
    
    private let settings: ProPresenterSettings
    private let subscriptionService: SubscriptionService
    private let healthMonitor: ConnectionHealthMonitor
    private var cancellables = Set<AnyCancellable>()
    
    enum ConnectionStatus: String {
        case connected = "Connected"
        case connecting = "Connecting"
        case disconnected = "Disconnected"
        case failed = "Failed"
        case available = "Available" // For keyboard (no connection needed)
    }
    
    enum AudiencePath: String, CaseIterable {
        case webSocket = "Messages API"
        case keyboard = "Keyboard Automation"
        case auto = "Automatic"
    }
    
    // MARK: - Initialisation
    
    init(settings: ProPresenterSettings = .shared,
         subscriptionService: SubscriptionService = .shared) {
        self.settings = settings
        self.subscriptionService = subscriptionService
        self.healthMonitor = ConnectionHealthMonitor()
        
        // Create outputs via Factory
        self.stageOutput = ProPresenterOutputFactory.createOutput(
            type: .stageDisplay,
            host: settings.host,
            port: settings.port
        )
        
        self.audienceWebSocket = ProPresenterOutputFactory.createOutput(
            type: .audienceWebSocket,
            host: settings.host,
            port: settings.port,
            password: settings.password
        )
        
        self.audienceKeyboard = ProPresenterOutputFactory.createOutput(
            type: .audienceKeyboard
        )
        
        // Start health monitoring
        startHealthMonitoring()
    }
    
    // MARK: - Unified Display API
    
    /// Display scripture to all configured outputs
    /// - Parameters:
    ///   - reference: Scripture reference (e.g., "John 3:16")
    ///   - text: Verse text content
    ///   - displayTo: Target outputs (default: both stage and audience)
    func displayScripture(
        reference: String,
        text: String,
        displayTo: OutputTarget = .both
    ) async {
        let decision = makePathDecision()
        lastPathDecision = decision
        
        // Stage Display (always HTTP)
        if displayTo.includesStage && settings.enableStageDisplay {
            await displayToStage(reference: reference, text: text)
        }
        
        // Audience Display (WebSocket or Keyboard)
        if displayTo.includesAudience {
            await displayToAudience(
                reference: reference,
                text: text,
                primaryPath: decision.audiencePath
            )
        }
    }
    
    /// Clear all outputs (Panic Button integration)
    func clearAll() async {
        async let stageClear: () = clearStage()
        async let audienceClear: () = clearAudience()
        
        await stageClear
        await audienceClear
        
        print("[HybridManager] All outputs cleared")
    }
    
    // MARK: - Path Decision Engine
    
    private func makePathDecision() -> PathDecision {
        let tier = subscriptionService.currentTier
        
        // Mercy tier: Always keyboard
        if tier == .mercy {
            return PathDecision(
                audiencePath: .keyboard,
                reason: "Mercy tier uses keyboard automation",
                fallbackPath: nil
            )
        }
        
        // Premium tiers: Check if WebSocket available
        if currentAudiencePath == .auto {
            if audienceAPIStatus == .connected {
                return PathDecision(
                    audiencePath: .webSocket,
                    reason: "Messages API connected and preferred",
                    fallbackPath: .keyboard
                )
            } else {
                return PathDecision(
                    audiencePath: .keyboard,
                    reason: "Messages API unavailable, using keyboard",
                    fallbackPath: nil
                )
            }
        }
        
        // User override
        return PathDecision(
            audiencePath: currentAudiencePath,
            reason: "User selected \(currentAudiencePath.rawValue)",
            fallbackPath: currentAudiencePath == .webSocket ? .keyboard : nil
        )
    }
    
    // MARK: - Private Display Methods
    
    private func displayToStage(reference: String, text: String) async {
        do {
            try await stageOutput.display(reference: reference, text: text)
            await MainActor.run { stageStatus = .connected }
        } catch {
            await MainActor.run { stageStatus = .failed }
            print("[HybridManager] Stage display failed: \(error)")
        }
    }
    
    private func displayToAudience(
        reference: String,
        text: String,
        primaryPath: AudiencePath
    ) async {
        let output = primaryPath == .webSocket ? audienceWebSocket : audienceKeyboard
        
        do {
            try await output.display(reference: reference, text: text)
            print("[HybridManager] Audience displayed via \(primaryPath.rawValue)")
        } catch {
            print("[HybridManager] \(primaryPath.rawValue) failed: \(error)")
            
            // Attempt fallback if WebSocket failed
            if primaryPath == .webSocket {
                print("[HybridManager] Falling back to keyboard automation")
                do {
                    try await audienceKeyboard.display(reference: reference, text: text)
                    await MainActor.run { audienceAPIStatus = .failed }
                } catch {
                    print("[HybridManager] Fallback also failed: \(error)")
                }
            }
        }
    }
    
    private func clearStage() async {
        try? await stageOutput.clear()
    }
    
    private func clearAudience() async {
        // Clear both methods to ensure clean state
        try? await audienceWebSocket.clear()
        try? await audienceKeyboard.clear()
    }
    
    // MARK: - Health Monitoring
    
    private func startHealthMonitoring() {
        // Check connections every 30 seconds
        healthMonitor.startMonitoring(interval: 30) { [weak self] in
            await self?.checkAllConnections()
        }
    }
    
    func checkAllConnections() async {
        // Check Stage Display (HTTP)
        let stageConnected = await stageOutput.checkConnection()
        await MainActor.run {
            stageStatus = stageConnected ? .connected : .disconnected
        }
        
        // Check Audience WebSocket (only for premium tiers)
        if subscriptionService.isPremium {
            let apiConnected = await audienceWebSocket.checkConnection()
            await MainActor.run {
                audienceAPIStatus = apiConnected ? .connected : .disconnected
            }
        }
        
        // Keyboard is always "available" if accessibility permitted
        let keyboardAvailable = await audienceKeyboard.checkConnection()
        await MainActor.run {
            keyboardStatus = keyboardAvailable ? .available : .disconnected
        }
    }
    
    // MARK: - Messages Layer Detection
    
    /// Check if Messages layer is enabled in ProPresenter Looks
    func checkMessagesLayerStatus() async throws -> MessagesLayerStatus {
        guard let webSocketOutput = audienceWebSocket as? AudienceWebSocketOutput else {
            return .notAvailable
        }
        
        return try await webSocketOutput.checkMessagesLayerInLooks()
    }
}

// MARK: - Supporting Types

struct PathDecision {
    let audiencePath: HybridIntegrationManager.AudiencePath
    let reason: String
    let fallbackPath: HybridIntegrationManager.AudiencePath?
    let timestamp = Date()
}

struct OutputTarget: OptionSet {
    let rawValue: Int
    
    static let stage = OutputTarget(rawValue: 1 << 0)
    static let audience = OutputTarget(rawValue: 1 << 1)
    static let both: OutputTarget = [.stage, .audience]
    
    var includesStage: Bool { contains(.stage) }
    var includesAudience: Bool { contains(.audience) }
}

enum MessagesLayerStatus {
    case enabled       // Ready to use Messages API on Audience
    case disabled      // Messages layer not enabled in Looks
    case notConfigured // No message template found
    case notAvailable  // WebSocket not connected
}
```

### Connection Health Monitor

```swift
// ConnectionHealthMonitor.swift
import Foundation

class ConnectionHealthMonitor {
    private var timer: Timer?
    private var checkTask: (() async -> Void)?
    
    func startMonitoring(interval: TimeInterval, check: @escaping () async -> Void) {
        self.checkTask = check
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                await self?.checkTask?()
            }
        }
        
        // Initial check
        Task { await check() }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
}
```

### Messages Layer Detection (via looksRequest)

```swift
// Extension to AudienceWebSocketOutput
extension AudienceWebSocketOutput {
    
    /// Query ProPresenter Looks to check if Messages layer is enabled on Audience
    func checkMessagesLayerInLooks() async throws -> MessagesLayerStatus {
        guard isConnected else {
            return .notAvailable
        }
        
        let request: [String: Any] = ["action": "looksRequest"]
        try await send(request)
        
        // Parse response (simplified - actual implementation handles async response)
        // The WebSocket will receive a looksResponse with layer configurations
        
        // Example response structure:
        // {
        //   "action": "looksCurrentSet",
        //   "looks": [
        //     {
        //       "name": "Standard",
        //       "screens": [
        //         { "name": "Audience", "layers": { "messages": true, "slides": true } }
        //       ]
        //     }
        //   ]
        // }
        
        // For now, return based on cached state
        return messagesLayerEnabled ? .enabled : .disabled
    }
}
```

### Settings UI: Integration Dashboard

```swift
// IntegrationDashboardView.swift
import SwiftUI

struct IntegrationDashboardView: View {
    @ObservedObject var manager: HybridIntegrationManager
    @State private var messagesLayerStatus: MessagesLayerStatus = .notAvailable
    @State private var showSetupGuide = false
    
    var body: some View {
        Form {
            // Connection Status
            Section("Connection Status") {
                StatusRow(
                    label: "Stage Display (HTTP)",
                    status: manager.stageStatus,
                    icon: "tv"
                )
                
                if SubscriptionService.shared.isPremium {
                    StatusRow(
                        label: "Audience API (WebSocket)",
                        status: manager.audienceAPIStatus,
                        icon: "antenna.radiowaves.left.and.right"
                    )
                }
                
                StatusRow(
                    label: "Keyboard Automation",
                    status: manager.keyboardStatus,
                    icon: "keyboard"
                )
                
                Button("Refresh Status") {
                    Task { await manager.checkAllConnections() }
                }
            }
            
            // Audience Path Selection
            Section("Audience Screen Method") {
                Picker("Method", selection: $manager.currentAudiencePath) {
                    ForEach(HybridIntegrationManager.AudiencePath.allCases, id: \.self) { path in
                        Text(path.rawValue).tag(path)
                    }
                }
                .pickerStyle(.radioGroup)
                
                if manager.currentAudiencePath != .keyboard {
                    // Messages Layer Status
                    HStack {
                        Label(messagesLayerLabel, systemImage: messagesLayerIcon)
                        Spacer()
                        Text(messagesLayerStatus.description)
                            .foregroundColor(messagesLayerStatus.color)
                    }
                    
                    if messagesLayerStatus == .disabled {
                        Button("Show Setup Guide") {
                            showSetupGuide = true
                        }
                    }
                }
            }
            
            // Last Path Decision (Debug)
            if let decision = manager.lastPathDecision {
                Section("Last Path Decision") {
                    Text("Path: \(decision.audiencePath.rawValue)")
                    Text("Reason: \(decision.reason)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .sheet(isPresented: $showSetupGuide) {
            MessagesLayerSetupGuide()
        }
        .onAppear {
            Task { await checkMessagesLayer() }
        }
    }
    
    private func checkMessagesLayer() async {
        do {
            messagesLayerStatus = try await manager.checkMessagesLayerStatus()
        } catch {
            messagesLayerStatus = .notAvailable
        }
    }
    
    private var messagesLayerLabel: String {
        switch messagesLayerStatus {
        case .enabled: return "Messages Layer"
        case .disabled: return "Messages Layer"
        case .notConfigured: return "Message Template"
        case .notAvailable: return "Messages Layer"
        }
    }
    
    private var messagesLayerIcon: String {
        switch messagesLayerStatus {
        case .enabled: return "checkmark.circle.fill"
        case .disabled: return "xmark.circle"
        case .notConfigured: return "exclamationmark.triangle"
        case .notAvailable: return "questionmark.circle"
        }
    }
}

struct StatusRow: View {
    let label: String
    let status: HybridIntegrationManager.ConnectionStatus
    let icon: String
    
    var body: some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(status.rawValue)
                .foregroundColor(.secondary)
        }
    }
    
    var statusColor: Color {
        switch status {
        case .connected, .available: return .green
        case .connecting: return .orange
        case .disconnected: return .gray
        case .failed: return .red
        }
    }
}
```

### Messages Layer Setup Guide

```swift
// MessagesLayerSetupGuide.swift
import SwiftUI

struct MessagesLayerSetupGuide: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 1
    
    var body: some View {
        VStack(spacing: 20) {
            // Progress
            HStack {
                ForEach(1...5, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.top)
            
            // Step Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch currentStep {
                    case 1:
                        StepContent(
                            title: "Open ProPresenter Screens",
                            description: "In ProPresenter, go to **Screens** menu → **Edit Looks**"
                        )
                    case 2:
                        StepContent(
                            title: "Select Your Audience Look",
                            description: "Click on the Look preset you use for your Audience screen (or create a new one)"
                        )
                    case 3:
                        StepContent(
                            title: "Enable Messages Layer",
                            description: "Find the **Messages** row in the layer list.\n\nCheck the box for your **Audience screen** column."
                        )
                    case 4:
                        StepContent(
                            title: "Create Scripture Message Template",
                            description: """
                            Go to **Messages** → **New Message**
                            
                            Add two text boxes with tokens:
                            • `${Reference}` - For "John 3:16"
                            • `${ScriptureText}` - For the verse text
                            
                            Style to match your church branding.
                            """
                        )
                    case 5:
                        StepContent(
                            title: "Test Connection",
                            description: "Click **Make Live** in ProPresenter to apply the Look.\n\nReturn to Divine Link and click **Refresh Status**."
                        )
                    default:
                        EmptyView()
                    }
                }
                .padding()
            }
            
            // Navigation
            HStack {
                if currentStep > 1 {
                    Button("Back") { currentStep -= 1 }
                }
                Spacer()
                if currentStep < 5 {
                    Button("Next") { currentStep += 1 }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 450)
    }
}

struct StepContent: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())
            
            Text(.init(description))
                .font(.body)
        }
    }
}
```

### Panic Button Integration (Story 6.1)

```swift
// Update PanicButtonService to use HybridIntegrationManager
extension PanicButtonService {
    func clearAllOutputs() async {
        // Use the hybrid manager for unified clear
        await hybridManager.clearAll()
        
        // Also clear local state
        await MainActor.run {
            currentlyDisplayedVerse = nil
            isPanicCleared = true
        }
    }
}
```

---

## User Setup Flow

### First-Time Premium User

1. User upgrades to Grace/Love tier
2. Divine Link detects premium and checks Messages layer
3. If disabled: Show "Enable Messages API" banner with setup guide
4. User follows 5-step setup guide in ProPresenter
5. Divine Link verifies connection and Messages layer
6. "Messages API Ready" confirmation shown
7. Future detections automatically use Messages API

### Fallback Scenario

1. Scripture detected during service
2. Manager checks WebSocket connection
3. WebSocket times out (network issue)
4. Manager automatically switches to keyboard
5. User sees brief notification: "Using keyboard fallback"
6. Scripture still displays successfully
7. Manager retries WebSocket in background

---

## Comparison: Output Paths

| Aspect | Stage (HTTP) | Audience (WebSocket) | Audience (Keyboard) |
|--------|--------------|---------------------|---------------------|
| **Target** | Confidence monitor | Main screen | Main screen |
| **Method** | HTTP PUT | WebSocket msg | CGEvent simulation |
| **Background-safe** | ✅ Yes | ✅ Yes | ❌ No |
| **Setup required** | Network API | Looks + Template | Accessibility |
| **Reliability** | High | High | Medium |
| **Speed** | ~100ms | ~50ms | ~300ms |
| **Tier** | All | Grace/Love | All |

---

## Dependencies

- Story 6.1 (Panic Button) - Integration for unified clear
- Story 6.4 (WebSocket Messages) - Audience WebSocket output
- Factory Pattern from Story 6.4 - Output abstraction
- SubscriptionService - Tier detection for path selection

---

## Definition of Done

- [ ] HybridIntegrationManager implemented
- [ ] PathDecisionEngine routes based on tier and availability
- [ ] Automatic fallback from WebSocket to keyboard
- [ ] Messages layer detection via `looksRequest`
- [ ] Setup guide UI for enabling Messages layer
- [ ] Connection health dashboard in Settings
- [ ] Panic button clears all paths
- [ ] Path decision logging for debugging
- [ ] Retry logic for transient failures
- [ ] Unit tests for path decision logic
- [ ] Integration tests with all three paths
- [ ] Documentation updated
- [ ] Committed to Git

---

## Testing Scenarios

| Scenario | Expected Behaviour |
|----------|-------------------|
| Premium + WebSocket connected | Uses Messages API |
| Premium + WebSocket disconnected | Falls back to keyboard |
| Mercy tier | Always uses keyboard |
| Messages layer disabled in PP | Detects and prompts setup |
| Panic button pressed | Clears Stage + Audience |
| WebSocket reconnects mid-service | Next verse uses WebSocket |
| Both outputs enabled | Scripture on both screens |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| User doesn't complete setup | High | Medium | Keyboard fallback + persistent reminder |
| WebSocket disconnects frequently | Low | Medium | Auto-reconnect with backoff |
| Fallback too slow | Low | Low | Optimised keyboard path |
| Path decision logged wrong | Low | Low | Comprehensive logging |

---

## Estimated Effort

| Task | Hours |
|------|-------|
| HybridIntegrationManager | 4 |
| PathDecisionEngine | 2 |
| ConnectionHealthMonitor | 2 |
| Messages layer detection | 2 |
| Setup guide UI | 3 |
| Dashboard UI | 3 |
| Panic button integration | 1 |
| Fallback logic | 2 |
| Testing & debugging | 4 |
| Documentation | 1 |
| **Total** | **24** |

---

## Notes

- Factory Pattern from Story 6.4 enables clean output swapping
- Hybrid approach ensures reliability for all tiers
- Messages layer detection prevents silent failures
- Setup guide reduces support burden
- Version target: v1.2.0 (with Epic 6)
