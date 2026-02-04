# Story 6.4: ProPresenter Message API Implementation

**Epic:** 6 - Operator Safety & Detection Confidence  
**Story ID:** 6.4  
**Status:** Not Started  
**Complexity:** Large  
**Priority:** P2 (Enhancement - Depends on 6.3 Research)

---

## User Story

**As an** operator using Divine Link with ProPresenter,  
**I want** scriptures to be displayed via the Message API,  
**so that** I have more reliable verse display without window focus issues.

---

## Background

**Note: This story should only proceed if Story 6.3 research recommends the Message API approach.**

If the research confirms Message API viability, this story implements:
- New ProPresenter service using HTTP API
- Message template setup workflow
- Token-based verse display
- Fallback to keyboard automation
- User preference for integration method

---

## Prerequisites

- [ ] Story 6.3 completed with positive recommendation for Message API
- [ ] ProPresenter 7+ confirmed as minimum supported version
- [ ] Message template design approved
- [ ] API endpoint compatibility verified

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Scripture displays via Message API | Verse appears in ProPresenter |
| 2 | Reference shows correctly (book, chapter, verse) | Formatting matches expectation |
| 3 | Verse text displays in message area | Text is readable and styled |
| 4 | Message clears when new verse pushed | Previous content replaced |
| 5 | Manual clear works (panic button) | API clear endpoint called |
| 6 | Fallback to keyboard if API fails | Graceful degradation |
| 7 | User can choose integration method | Settings option available |
| 8 | Setup wizard helps configure message | First-run guidance |
| 9 | Connection status shown in UI | API health indicator |

---

## Technical Notes

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Divine Link                              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │            ProPresenterIntegrationService                 │   │
│  │  ┌────────────────────┐  ┌────────────────────────────┐  │   │
│  │  │ KeyboardAutomation │  │     MessageAPIService      │  │   │
│  │  │    (existing)      │  │        (new)               │  │   │
│  │  └────────────────────┘  └────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    HTTP API (port 1025)
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       ProPresenter 7+                            │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Scripture Message                      │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │ {reference}                                        │  │   │
│  │  │ ─────────────────────────────────────────────────  │  │   │
│  │  │ {verse_text}                                       │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Service Implementation

#### ProPresenterMessageService

```swift
// ProPresenterMessageService.swift
import Foundation

class ProPresenterMessageService: ObservableObject {
    @Published var isConnected = false
    @Published var lastError: String?
    
    private let baseURL: URL
    private let session: URLSession
    private var scriptureMessageId: String?
    
    // Token names matching ProPresenter template
    private let referenceToken = "reference"
    private let verseTextToken = "verse_text"
    
    init(host: String = "localhost", port: Int = 1025) {
        self.baseURL = URL(string: "http://\(host):\(port)/v1")!
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Connection
    
    func checkConnection() async -> Bool {
        do {
            let url = baseURL.appendingPathComponent("status")
            let (_, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                await MainActor.run { self.isConnected = true }
                return true
            }
        } catch {
            await MainActor.run { 
                self.isConnected = false
                self.lastError = error.localizedDescription
            }
        }
        return false
    }
    
    // MARK: - Message Discovery
    
    func findScriptureMessage() async throws -> String? {
        let url = baseURL.appendingPathComponent("messages")
        let (data, _) = try await session.data(from: url)
        
        let messages = try JSONDecoder().decode([PPMessage].self, from: data)
        
        // Look for message named "Scripture" or "Divine Link"
        if let scriptureMessage = messages.first(where: { 
            $0.name.lowercased().contains("scripture") || 
            $0.name.lowercased().contains("divine link")
        }) {
            self.scriptureMessageId = scriptureMessage.id
            return scriptureMessage.id
        }
        
        return nil
    }
    
    // MARK: - Display Scripture
    
    func displayScripture(reference: String, text: String) async throws {
        guard let messageId = scriptureMessageId else {
            throw MessageAPIError.noMessageConfigured
        }
        
        // Update reference token
        try await updateToken(
            messageId: messageId,
            tokenName: referenceToken,
            value: reference
        )
        
        // Update verse text token
        try await updateToken(
            messageId: messageId,
            tokenName: verseTextToken,
            value: text
        )
        
        // Trigger the message
        try await triggerMessage(id: messageId)
    }
    
    // MARK: - Clear
    
    func clearScripture() async throws {
        guard let messageId = scriptureMessageId else { return }
        
        let url = baseURL.appendingPathComponent("message/\(messageId)/clear")
        let (_, _) = try await session.data(from: url)
    }
    
    // MARK: - Private Helpers
    
    private func updateToken(messageId: String, tokenName: String, value: String) async throws {
        let url = baseURL.appendingPathComponent("messages/\(messageId)/tokens/\(tokenName)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ["value": value]
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MessageAPIError.tokenUpdateFailed(tokenName)
        }
    }
    
    private func triggerMessage(id: String) async throws {
        let url = baseURL.appendingPathComponent("message/\(id)/trigger")
        let (_, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MessageAPIError.triggerFailed
        }
    }
}

// MARK: - Models

struct PPMessage: Codable {
    let id: String
    let name: String
}

enum MessageAPIError: LocalizedError {
    case noMessageConfigured
    case tokenUpdateFailed(String)
    case triggerFailed
    case connectionFailed
    
    var errorDescription: String? {
        switch self {
        case .noMessageConfigured:
            return "No scripture message configured in ProPresenter"
        case .tokenUpdateFailed(let token):
            return "Failed to update token: \(token)"
        case .triggerFailed:
            return "Failed to trigger message display"
        case .connectionFailed:
            return "Cannot connect to ProPresenter API"
        }
    }
}
```

### Integration Service Update

```swift
// ProPresenterIntegrationService.swift (updated)
class ProPresenterIntegrationService: ObservableObject {
    @Published var integrationMethod: IntegrationMethod = .keyboard
    
    private let keyboardService: KeyboardAutomationService
    private let messageService: ProPresenterMessageService
    
    enum IntegrationMethod: String, CaseIterable {
        case keyboard = "Keyboard Automation"
        case messageAPI = "Message API"
        case hybrid = "Hybrid (API first, keyboard fallback)"
    }
    
    func displayScripture(_ match: ScriptureMatch) async {
        switch integrationMethod {
        case .keyboard:
            await keyboardService.triggerScripture(match)
            
        case .messageAPI:
            do {
                try await messageService.displayScripture(
                    reference: match.reference,
                    text: match.verseText
                )
            } catch {
                print("Message API failed: \(error)")
                // Show error in UI
            }
            
        case .hybrid:
            do {
                try await messageService.displayScripture(
                    reference: match.reference,
                    text: match.verseText
                )
            } catch {
                print("API failed, falling back to keyboard: \(error)")
                await keyboardService.triggerScripture(match)
            }
        }
    }
    
    func clear() async {
        switch integrationMethod {
        case .messageAPI, .hybrid:
            try? await messageService.clearScripture()
        case .keyboard:
            await keyboardService.triggerClear()
        }
    }
}
```

### Settings UI

```swift
// ProPresenterSettingsView.swift
struct ProPresenterSettingsView: View {
    @ObservedObject var integrationService: ProPresenterIntegrationService
    @State private var apiHost = "localhost"
    @State private var apiPort = "1025"
    @State private var showSetupWizard = false
    
    var body: some View {
        Form {
            Section("Integration Method") {
                Picker("Method", selection: $integrationService.integrationMethod) {
                    ForEach(IntegrationMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(.radioGroup)
                
                if integrationService.integrationMethod != .keyboard {
                    GroupBox("API Settings") {
                        TextField("Host", text: $apiHost)
                        TextField("Port", text: $apiPort)
                        
                        HStack {
                            Button("Test Connection") {
                                Task { await testConnection() }
                            }
                            
                            if integrationService.messageService.isConnected {
                                Label("Connected", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    Button("Run Setup Wizard") {
                        showSetupWizard = true
                    }
                }
            }
        }
        .sheet(isPresented: $showSetupWizard) {
            MessageSetupWizardView()
        }
    }
}
```

### Setup Wizard

```swift
// MessageSetupWizardView.swift
struct MessageSetupWizardView: View {
    @State private var step = 1
    
    var body: some View {
        VStack(spacing: 20) {
            // Progress indicator
            HStack {
                ForEach(1...4, id: \.self) { i in
                    Circle()
                        .fill(i <= step ? Color.accentColor : Color.gray)
                        .frame(width: 10, height: 10)
                }
            }
            
            switch step {
            case 1:
                VStack {
                    Text("Step 1: Enable ProPresenter API")
                        .font(.headline)
                    Text("Open ProPresenter Preferences → Network and enable the API server.")
                    Image("pp-network-settings") // Screenshot
                }
                
            case 2:
                VStack {
                    Text("Step 2: Create Scripture Message")
                        .font(.headline)
                    Text("In ProPresenter, create a new Message with these tokens:")
                    VStack(alignment: .leading) {
                        Text("• {reference} - for the scripture reference")
                        Text("• {verse_text} - for the verse content")
                    }
                    Text("Name it 'Scripture' or 'Divine Link'")
                }
                
            case 3:
                VStack {
                    Text("Step 3: Style Your Message")
                        .font(.headline)
                    Text("Configure the message appearance:")
                    Text("• Font size and style")
                    Text("• Position on screen")
                    Text("• Background and effects")
                }
                
            case 4:
                VStack {
                    Text("Step 4: Test Connection")
                        .font(.headline)
                    Button("Test Now") {
                        // Run connection test
                    }
                }
                
            default:
                EmptyView()
            }
            
            HStack {
                if step > 1 {
                    Button("Back") { step -= 1 }
                }
                Spacer()
                if step < 4 {
                    Button("Next") { step += 1 }
                } else {
                    Button("Finish") {
                        // Complete setup
                    }
                }
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}
```

---

## ProPresenter Message Template

### Required Template Structure

Users need to create a message in ProPresenter with:

| Token Name | Purpose | Example Value |
|------------|---------|---------------|
| `{reference}` | Scripture reference | "John 3:16" |
| `{verse_text}` | Full verse text | "For God so loved..." |

### Recommended Styling

- **Reference**: Large, bold, at top
- **Verse Text**: Medium size, below reference
- **Background**: Semi-transparent or match church branding
- **Position**: Lower third or centre

---

## Migration Path

If transitioning from keyboard to Message API:

1. **Phase 1**: Add Message API as option in Settings
2. **Phase 2**: Default to Hybrid mode (API with keyboard fallback)
3. **Phase 3**: After validation period, recommend API as primary
4. **No Breaking Changes**: Keyboard automation remains available

---

## Dependencies

- Story 6.3 (Research) - Must be completed with positive outcome
- Story 3.6 (ProPresenter Connection) - Existing connection logic
- Story 6.1 (Panic Button) - Clear integration

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] ProPresenterMessageService implemented
- [ ] Integration service updated with method selection
- [ ] Settings UI for method choice
- [ ] Setup wizard for message configuration
- [ ] Fallback to keyboard works correctly
- [ ] Connection status indicator in UI
- [ ] Error handling for API failures
- [ ] Unit tests for API service
- [ ] Documentation for message setup
- [ ] Committed to Git

---

## Testing Scenarios

1. **API Display**: Scripture detected → API updates tokens → Message appears
2. **API Clear**: Clear button pressed → Message clears via API
3. **API Failure**: API unavailable → Falls back to keyboard (if hybrid)
4. **Connection Lost**: Mid-service disconnect → Graceful degradation
5. **Invalid Message**: Message deleted in PP → Error shown, prompt reconfigure
6. **Token Update**: Long verse text → Handles multi-line content

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| API endpoints change in PP update | Low | High | Abstract API calls, version check |
| Message accidentally deleted | Medium | Medium | Setup wizard to recreate |
| Hybrid mode causes confusion | Low | Low | Clear UI explanation |
| Performance slower than keyboard | Low | Low | Benchmark during testing |

---

## Estimated Effort

| Task | Hours |
|------|-------|
| ProPresenterMessageService | 4 |
| Integration service update | 2 |
| Settings UI | 2 |
| Setup wizard | 3 |
| Error handling & fallback | 2 |
| Testing & debugging | 3 |
| **Total** | **16** |

---

## Notes

- **Only implement if 6.3 research is positive**
- Maintain backward compatibility with keyboard method
- Consider creating template file for easy import into ProPresenter
- Future: Explore other PP API endpoints for enhanced integration
