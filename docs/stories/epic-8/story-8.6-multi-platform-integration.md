# Story 8.6: Multi-Platform Integration (EasyWorship & FreeShow)

**Story ID:** 8.6
**Epic:** 8 - UX/UI Modernization & Platform Expansion
**Priority:** P1 (Should-Have - High Strategic Value)
**Complexity:** Large
**Estimated Effort:** 24-32 hours (+ 4-8h research spike)
**Phase:** Phase 3 (Week 3)
**Target Version:** v1.8.0 (FreeShow) / v2.0.0 (EasyWorship + protocol cleanup)  
**Depends on:** Story 8.7 (Divine Link Presentation Window) — build that first  
**Canonical roadmap:** [`Plans/Presentation-Outputs-Roadmap.md`](../../../Plans/Presentation-Outputs-Roadmap.md)

---

## Story Description

Expand Divine Link beyond ProPresenter to support EasyWorship and FreeShow presentation platforms, enabling scripture display across multiple church presentation software ecosystems and increasing addressable market by 40%.

---

## User Story

**As a** church using EasyWorship or FreeShow (not ProPresenter)
**I want** Divine Link to integrate with my presentation software
**So that** I can use automated scripture detection regardless of my platform choice

---

## Business Value

- **Market Expansion:** Opens EasyWorship/FreeShow markets (30-40% of churches)
- **Competitive Advantage:** QuickVerse supports 3 platforms; we need parity
- **Revenue Potential:** Directly expands total addressable market (TAM)
- **Strategic Importance:** Removes platform lock-in concerns

**Impact Score:** 5/5 (Highest strategic value - market expansion)

---

## ⚠️ RESEARCH SPIKE REQUIRED

**Before full implementation, conduct 4-8 hour research spike to validate:**
1. EasyWorship API availability and documentation
2. FreeShow API availability and documentation
3. Authentication/connection requirements
4. Feature parity with ProPresenter integration
5. Fallback strategies if APIs are limited

**Decision Gate:** After research spike, decide:
- ✅ **Green Light:** Proceed with full implementation
- ⚠️ **Yellow Light:** Implement with limited features or keyboard fallback
- 🔴 **Red Light:** Defer to Epic 9, ship Epic 8 MVP without this story

---

## Acceptance Criteria

### Settings UI (Platform Selection)
- [ ] New "Platform" tab in Settings window
- [ ] Radio button group with 3 options:
  1. ProPresenter (Recommended - Full feature support)
  2. EasyWorship (API integration)
  3. FreeShow (WebSocket connection)
- [ ] Selected platform has gold radio button (#D4AF37)

### Connection Settings (Per Platform)
- [ ] IP Address input field (e.g., "127.0.0.1")
- [ ] Port number input field (e.g., "8080")
- [ ] "Test Connection" button (blue)
- [ ] Connection status indicator:
  - Green dot ● + "Connected"
  - Red dot ● + "Connection failed"
  - Spinner + "Testing..."

### Advanced Options (Collapsed by Default)
- [ ] "Advanced Options >" disclosure triangle
- [ ] When expanded, shows:
  - Toggle: "Use WebSocket (Premium)" - for EasyWorship/FreeShow
  - Toggle: "Enable keyboard fallback" - if API unavailable
  - Slider: "Connection timeout" (5-60 seconds)

### EasyWorship Integration
**Research Required:** Validate API availability
- [ ] Display scripture text on EasyWorship screen
- [ ] Clear scripture from screen (panic button support)
- [ ] Connection status monitoring
- [ ] Error handling and reconnection logic

### FreeShow Integration
**Research Required:** Validate WebSocket protocol
- [ ] WebSocket connection to FreeShow instance
- [ ] Send scripture via WebSocket message
- [ ] Clear scripture command
- [ ] Connection status monitoring

### Platform Abstraction Layer
- [ ] `PresentationOutputProtocol` interface
- [ ] `ProPresenterClient` (existing, refactored)
- [ ] `EasyWorshipClient` (new)
- [ ] `FreeShowClient` (new)
- [ ] `PresentationOutputFactory` for client instantiation

---

## Technical Specifications

### Protocol Abstraction
```swift
protocol PresentationOutputProtocol {
    func connect(ipAddress: String, port: Int) async throws
    func disconnect()
    func sendScripture(reference: String, text: String) async throws
    func clearScripture() async throws
    func testConnection() async -> Bool
    var isConnected: Bool { get }
    var connectionStatus: ConnectionStatus { get }
}

enum ConnectionStatus {
    case disconnected
    case connecting
    case connected
    case error(String)
}
```

### Factory Pattern
```swift
class PresentationOutputFactory {
    static func createClient(platform: PlatformType) -> PresentationOutputProtocol {
        switch platform {
        case .proPresenter:
            return ProPresenterClient()
        case .easyWorship:
            return EasyWorshipClient()
        case .freeShow:
            return FreeShowClient()
        }
    }
}

enum PlatformType: String, CaseIterable {
    case proPresenter = "ProPresenter"
    case easyWorship = "EasyWorship"
    case freeShow = "FreeShow"

    var defaultPort: Int {
        switch self {
        case .proPresenter: return 50001
        case .easyWorship: return 8080 // TBD - research required
        case .freeShow: return 5510 // TBD - research required
        }
    }
}
```

### EasyWorship Client (Placeholder - Research Required)
```swift
class EasyWorshipClient: PresentationOutputProtocol {
    private var connection: URLSession?
    private var baseURL: String = ""

    func connect(ipAddress: String, port: Int) async throws {
        // Research: Determine EasyWorship API connection method
        // Possible: REST API, WebSocket, or custom protocol
    }

    func sendScripture(reference: String, text: String) async throws {
        // Research: Determine API endpoint for displaying text
        // Example (hypothetical):
        // POST http://{ip}:{port}/api/display/scripture
        // Body: { "reference": "John 3:16", "text": "..." }
    }

    func clearScripture() async throws {
        // Research: Determine clear/hide command
    }
}
```

### FreeShow Client (Placeholder - Research Required)
```swift
class FreeShowClient: PresentationOutputProtocol {
    private var webSocket: URLSessionWebSocketTask?

    func connect(ipAddress: String, port: Int) async throws {
        // Research: FreeShow WebSocket protocol
        // Example: ws://{ip}:{port}/api/websocket
    }

    func sendScripture(reference: String, text: String) async throws {
        // Research: WebSocket message format
        // Example (hypothetical):
        // { "command": "display", "type": "scripture", "content": {...} }
    }
}
```

### Keyboard Fallback (If APIs Unavailable)
```swift
class KeyboardAutomationClient: PresentationOutputProtocol {
    // Similar to current ProPresenter keyboard fallback
    // Send keystrokes to active window
    // Less reliable, but works universally
}
```

---

## Dependencies

### Before This Story
- **Research Spike:** 4-8 hours to validate API availability
- Story 8.1: Modern UI Redesign (provides Settings window)

### After This Story
- None (this is a leaf story)

### External Dependencies
- EasyWorship API documentation (if available)
- FreeShow WebSocket protocol documentation
- macOS CGEvent API (for keyboard fallback)

---

## Research Spike: Tasks & Questions

### EasyWorship Research (4 hours)
**Objectives:**
1. Find official API documentation (check website, forums, GitHub)
2. Determine if API exists (REST, WebSocket, or custom protocol)
3. Test API with curl or Postman (if available)
4. Document connection requirements (authentication, endpoints)
5. Validate scripture display capability

**Questions to Answer:**
- Does EasyWorship have a public API?
- What is the connection method (HTTP, WebSocket, TCP)?
- How do you display custom text on screen?
- Is authentication required?
- What is the latency of API calls?

### FreeShow Research (4 hours)
**Objectives:**
1. Find official WebSocket protocol documentation
2. Test WebSocket connection with test client
3. Document message format for displaying text
4. Validate scripture display capability
5. Test connection stability

**Questions to Answer:**
- What is the WebSocket endpoint URL?
- What is the message format (JSON, custom)?
- How do you display custom text on screen?
- Is authentication required?
- Does it support multiple text layers?

---

## Testing Requirements

### Integration Testing (Per Platform)
- [ ] Connect to each platform successfully
- [ ] Display scripture text correctly
- [ ] Clear scripture command works
- [ ] Connection status updates correctly
- [ ] Reconnection logic works after disconnect
- [ ] Error handling graceful (doesn't crash app)

### Cross-Platform Testing
- [ ] Switch between platforms in Settings
- [ ] Previous platform disconnects cleanly
- [ ] New platform connects without restart
- [ ] Settings persist across app restarts

### Fallback Testing (If APIs Limited)
- [ ] Keyboard automation fallback works
- [ ] User is notified of fallback mode
- [ ] Fallback performs adequately (< 2s latency)

---

## Definition of Done

- [ ] Research spike completed and documented
- [ ] Decision made (proceed, defer, or fallback approach)
- [ ] **If Proceed:**
  - [ ] EasyWorship integration functional
  - [ ] FreeShow integration functional
  - [ ] Platform selection in Settings works
  - [ ] Connection testing for all platforms works
  - [ ] All acceptance criteria met
- [ ] **If Defer:**
  - [ ] Document reasons for deferral
  - [ ] Plan Epic 9 story for retry
  - [ ] Ship Epic 8 without this story
- [ ] Code review completed
- [ ] Testing passed
- [ ] Merged to main

---

## Rollout Strategy

### Phased Rollout (If APIs Available)
1. **Week 1:** Research spike + proof-of-concept
2. **Week 2:** EasyWorship integration + testing
3. **Week 3:** FreeShow integration + testing
4. **Week 4:** Polish, bug fixes, documentation

### Fallback Plan (If APIs Limited/Unavailable)
1. **Option A:** Implement keyboard automation fallback
2. **Option B:** Defer to Epic 9, focus on ProPresenter excellence
3. **Option C:** Partner with EasyWorship/FreeShow for API access

---

## Risks & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **APIs don't exist** | High | High | Keyboard fallback or defer to Epic 9 |
| **APIs are undocumented** | Medium | High | Reverse-engineer or contact vendors |
| **APIs require authentication** | Medium | Medium | Implement auth flow, document setup |
| **Performance issues** | Low | Medium | Optimize, benchmark, cache where possible |
| **Connection instability** | Medium | Medium | Implement robust reconnection logic |

---

## Success Metrics

**After Implementation:**
- **Market Expansion:** +40% TAM (EasyWorship + FreeShow users)
- **User Acquisition:** Track signups from non-ProPresenter users
- **Platform Distribution:** Measure % of users on each platform
- **Support Tickets:** Monitor platform-specific issues

---

## Related Documents

- [Epic 8 README](./README.md)
- [Story 8.1 - Modern UI Redesign](./story-8.1-modern-ui-redesign.md)
- [Settings Window Mockup](../../wireframes/epic-8-settings-window-prompt.md)
- [Competitor Analysis](../../competitor-analysis.md) - QuickVerse multi-platform approach
- [Technical Specification](../../epic-8-technical-specification.md)

---

## Notes

- **Strategic Importance:** This story has highest market impact (5/5)
- **Risk Level:** High (API availability unknown)
- **Decision Gate:** Research spike results determine go/no-go
- **Fallback:** Defer to Epic 9 if APIs unavailable (ship Epic 8 without this)
- **QuickVerse Parity:** They support 3 platforms; we need to match

---

**Story Owner:** coachAOG
**Created:** February 18, 2026
**Status:** 📋 Research Spike Required
**Blocked By:** Story 8.1
**Blocks:** None
**Next Action:** Conduct 4-8 hour research spike on EasyWorship/FreeShow APIs
