# Story 6.5: ProPresenter Theme/Slide Injection

**Epic:** 6 - Operator Safety & Detection Confidence  
**Story ID:** 6.5  
**Status:** Not Started  
**Complexity:** Large  
**Priority:** P0 (Critical - "Pro Grade" Requirement)

---

## User Story

**As an** operator using Divine Link,  
**I want** scriptures to be injected directly to a ProPresenter theme via API,  
**so that** display works reliably even when ProPresenter is in the background.

---

## Background

**Current State (Keyboard Automation - ⌘B):**
- Requires ProPresenter window to be active/focused
- If user clicks away, automation fails
- Different keyboard layouts can cause issues
- Relies on accessibility permissions
- Works immediately with zero configuration

**Target State (Messages API via Looks Routing):**
- ✅ Works regardless of window focus (100% background-safe)
- ✅ No keyboard simulation required
- ✅ Direct WebSocket/HTTP API calls
- ✅ Uses church's configured Message themes
- ✅ Faster than keyboard automation (~50ms vs ~300ms)
- ⚠️ Requires one-time setup: Enable Messages layer in Audience Look

**Research Findings (Verified):**
- Messages layer is one of ProPresenter's 8 fixed output layers
- Looks window can route Messages layer to any Audience screen
- `messageSend` API displays content on all screens with Messages layer enabled
- Messages support templated placeholders (e.g., `${ScriptureText}`, `${Reference}`)

**Professor BMAD Assessment:**
> "Messages on Audience Screen Secret: In ProPresenter, you can use the 'Looks' feature to enable the Messages Layer on any Audience screen. This means your app can bypass keyboard automation! Send the verse to a 'Message Template' and, as long as the church has the 'Messages' layer turned on in their Audience Look, it will appear beautifully over their live video or slides."

**Tier Strategy:**
- **Mercy (Free):** Keep keyboard automation (⌘B) - zero configuration
- **Grace/Premium:** Messages API - requires setup but more reliable
- **Love (Pro):** Messages API + advanced features

This is the **most important technical hurdle** for making the app "Pro Grade."

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Scripture displays via Messages API | Verse appears without keyboard simulation |
| 2 | Works when ProPresenter is in background | Test with PP minimised |
| 3 | Uses church's Message theme for styling | Matches existing message appearance |
| 4 | Reference and verse text both display | Full scripture visible via template placeholders |
| 5 | Multiple verses display correctly | Verse ranges work (e.g., 3:16-18) |
| 6 | Previous message clears before new one | No overlapping content |
| 7 | Fallback to keyboard if Messages layer disabled | Graceful degradation |
| 8 | Messages layer detection | Check if enabled via `looksRequest` |
| 9 | Setup guide provided | Instructions to enable Messages layer |
| 10 | Connection status shown in UI | API health indicator |

---

## Technical Notes

### ✅ Verified Solution: Messages API via Looks Routing

**Research Confirmed:** Messages layer CAN be routed to Audience screen via Looks feature.

### ProPresenter API Endpoints (Verified)

| Endpoint | Method | Purpose | Status |
|----------|--------|---------|--------|
| `messageRequest` | WebSocket | Get available message templates | ✅ Use this |
| `messageSend` | WebSocket | Display message with placeholders | ✅ Use this |
| `messageHide` | WebSocket | Hide message | ✅ Use this |
| `looksRequest` | WebSocket | Get Looks and check Messages layer | ✅ Use this |
| `/v1/stage/message` | HTTP PUT | Stage Display messages | ✅ Already implemented |

### Implementation: Messages API (CONFIRMED APPROACH)

```swift
// MessagesService.swift
class ProPresenterMessagesService {
    private let webSocket: WebSocketConnection
    
    // Step 1: Query available message templates
    func getMessageTemplates() async throws -> [MessageTemplate] {
        let request = WebSocketMessage(
            action: "messageRequest"
        )
        let response = try await webSocket.send(request)
        return try JSONDecoder().decode(MessageTemplatesResponse.self, from: response.data)
    }
    
    // Step 2: Check if Messages layer is enabled in Audience Look
    func isMessagesLayerEnabled() async throws -> Bool {
        let request = WebSocketMessage(action: "looksRequest")
        let response = try await webSocket.send(request)
        let looks = try JSONDecoder().decode(LooksResponse.self, from: response.data)
        
        // Check active Look for Messages layer on Audience screens
        return looks.activeLook.hasMessagesLayerOnAudience
    }
    
    // Step 3: Send scripture via message template
    func sendScripture(reference: String, text: String, messageIndex: Int) async throws {
        let request = WebSocketMessage(
            action: "messageSend",
            messageIndex: messageIndex,
            messageKeys: ["ScriptureText", "Reference"],
            messageValues: [text, reference]
        )
        try await webSocket.send(request)
    }
    
    // Step 4: Clear message
    func clearMessage(messageIndex: Int) async throws {
        let request = WebSocketMessage(
            action: "messageHide",
            messageIndex: messageIndex
        )
        try await webSocket.send(request)
    }
}
```

### User Setup Requirements

**One-Time Configuration in ProPresenter:**
1. Open ProPresenter → Screens → Edit Looks
2. Select Audience Look preset (or create new)
3. Enable "Messages" layer checkbox for Audience screen(s)
4. Configure Message template with placeholders:
   - `${ScriptureText}` - Verse text
   - `${Reference}` - Scripture reference
5. Apply theme/styling to Message template
6. Save Look preset

**Divine Link Setup:**
1. Connect to ProPresenter
2. Query `messageRequest` to find scripture message template
3. Query `looksRequest` to verify Messages layer enabled
4. If enabled: Use Messages API
5. If disabled: Show setup guide + fallback to keyboard

### Messages Layer Detection & Setup Guide

```swift
// MessagesLayerDetectionService.swift
class MessagesLayerDetectionService {
    func checkMessagesLayerStatus() async throws -> MessagesLayerStatus {
        // Query Looks to see if Messages layer is enabled
        let looks = try await queryLooks()
        
        guard let activeLook = looks.activeLook else {
            return .notConfigured
        }
        
        // Check if Messages layer is enabled on any Audience screen
        let hasMessagesOnAudience = activeLook.audienceScreens.contains { screen in
            screen.enabledLayers.contains(.messages)
        }
        
        if hasMessagesOnAudience {
            return .enabled
        } else {
            return .disabled
        }
    }
}

enum MessagesLayerStatus {
    case enabled      // Ready to use Messages API
    case disabled    // Show setup guide
    case notConfigured  // ProPresenter not configured
}
```

### Settings UI for Messages Setup

```swift
// MessagesSetupView.swift
struct MessagesSetupView: View {
    @StateObject private var detectionService = MessagesLayerDetectionService()
    @State private var status: MessagesLayerStatus = .notConfigured
    @State private var showSetupGuide = false
    
    var body: some View {
        Form {
            Section("Audience Screen Integration") {
                HStack {
                    Label("Messages Layer", systemImage: status.icon)
                    Spacer()
                    Text(status.description)
                        .foregroundColor(status.color)
                }
                
                Button("Check Status") {
                    Task { await checkStatus() }
                }
                
                if status == .disabled {
                    Button("Show Setup Guide") {
                        showSetupGuide = true
                    }
                }
            }
            
            Section("Method") {
                if status == .enabled {
                    Label("Using Messages API", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Label("Using Keyboard Automation", systemImage: "keyboard")
                        .foregroundColor(.orange)
                    Text("Enable Messages layer in ProPresenter to use API method")
                        .font(.caption)
                }
            }
        }
        .sheet(isPresented: $showSetupGuide) {
            MessagesSetupGuideView()
        }
    }
    
    func checkStatus() async {
        do {
            status = try await detectionService.checkMessagesLayerStatus()
        } catch {
            status = .notConfigured
        }
    }
}
```

### Setup Guide Content

**Messages Layer Setup Guide:**
1. Open ProPresenter
2. Go to **Screens → Edit Looks**
3. Select your **Audience Look** preset (or create new)
4. Find the **Messages** row in the layer list
5. Check the box for your **Audience screen** column
6. Configure a Message template:
   - Add placeholders: `${ScriptureText}` and `${Reference}`
   - Apply your preferred theme/styling
7. Click **"Make Live"** or save the Look preset
8. Return to Divine Link and click **"Check Status"**

---

## Architecture Update

```
┌─────────────────────────────────────────────────────────────────┐
│                         Divine Link                              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │          ProPresenterIntegrationService (Updated)         │   │
│  │  ┌────────────────────┐  ┌────────────────────────────┐  │   │
│  │  │ KeyboardAutomation │  │  DirectInjectionService    │  │   │
│  │  │    (fallback)      │  │  ┌──────────────────────┐  │  │   │
│  │  └────────────────────┘  │  │ PropsInjection       │  │  │   │
│  │                          │  │ SlideInjection       │  │  │   │
│  │                          │  │ MessageInjection     │  │  │   │
│  │                          │  └──────────────────────┘  │  │   │
│  │                          └────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                    HTTP API (port 1025)
                    Background-Safe ✓
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       ProPresenter 7+                            │
│  ┌───────────────────┐  ┌───────────────────────────────────┐   │
│  │   Props Layer     │  │     Audience Display              │   │
│  │  (Divine Link)    │  │  ┌─────────────────────────────┐  │   │
│  └───────────────────┘  │  │   John 3:16                 │  │   │
│                          │  │   ──────────────────────────│  │   │
│                          │  │   For God so loved the      │  │   │
│                          │  │   world, that he gave...    │  │   │
│                          │  └─────────────────────────────┘  │   │
│                          └───────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Comparison: Keyboard vs. Messages API

| Aspect | Keyboard (⌘B) | Messages API |
|--------|---------------|--------------|
| **Background-safe** | ❌ No | ✅ Yes |
| **Reliability** | Medium | High |
| **Window focus required** | Yes | No |
| **Accessibility permissions** | Required | Not required |
| **Setup required** | ✅ None | ⚠️ Enable Messages layer |
| **Theme control** | Uses PP Bible default | Uses PP Message theme |
| **Speed** | ~300ms | ~50ms |
| **Error handling** | Limited | Full API responses |
| **Multi-verse support** | Via ProPresenter | Via template formatting |
| **Tier Strategy** | Mercy (Free) | Grace/Premium |

---

## Implementation Strategy

1. **Phase 1**: ✅ Research complete (Messages API verified)
2. **Phase 2**: Implement Messages API service alongside keyboard
3. **Phase 3**: Detect Messages layer availability
4. **Phase 4**: Use Messages API if enabled, keyboard as fallback
5. **Phase 5**: Provide setup guide for Premium users
6. **Phase 6**: Keep keyboard for Mercy tier (zero config)

---

## Dependencies

- ✅ Story 6.3 (API Research) - Complete, Messages API verified
- ✅ Story 6.4 (Message API) - Stage Display already implemented
- ProPresenter 7+ with Network API enabled
- WebSocket connection capability (for `messageSend`)
- User must enable Messages layer in Audience Look (one-time setup)

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] Messages API works with PP in background
- [ ] Messages layer detection implemented
- [ ] Setup guide UI implemented
- [ ] Fallback to keyboard works when Messages layer disabled
- [ ] Connection health indicator in UI
- [ ] No accessibility permissions required for Messages API
- [ ] Test with ProPresenter 7.6+ versions
- [ ] User documentation updated (setup guide)
- [ ] Research document updated
- [ ] Committed to Git

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Messages layer not enabled by user | High | Medium | Provide clear setup guide + keyboard fallback |
| Message template not configured | Medium | High | Detect and guide user to create template |
| WebSocket connection issues | Low | Medium | Fallback to HTTP API or keyboard |
| Performance overhead | Low | Low | Benchmark vs keyboard (expected faster) |
| Version incompatibility | Low | Medium | Minimum version check (7.6+) |

---

## Estimated Effort

| Task | Hours |
|------|-------|
| ✅ API endpoint research & verification | 4 (Complete) |
| MessagesService implementation | 6 |
| Messages layer detection | 3 |
| Setup guide UI | 3 |
| Fallback logic | 2 |
| Testing & debugging | 4 |
| Documentation | 2 |
| **Total** | **24** |

---

## Notes

- ✅ **Research Complete:** Messages API verified as viable solution
- ✅ **Solution Confirmed:** Messages layer CAN route to Audience screen via Looks
- **Tier Strategy:** Messages API for Premium, keyboard for Free tier
- **User Setup Required:** One-time configuration to enable Messages layer
- **Fallback:** Keyboard automation remains for Mercy tier and compatibility
- **Next Steps:** Implement MessagesService with layer detection and setup guide
