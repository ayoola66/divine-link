# Story 6.3: ProPresenter Message API Research

**Epic:** 6 - Operator Safety & Detection Confidence  
**Story ID:** 6.3  
**Status:** Not Started  
**Complexity:** Medium  
**Priority:** P1 (Technical Improvement)

---

## User Story

**As a** developer,  
**I want** to research ProPresenter's Message API vs. Bible triggering via keyboard automation,  
**so that** we can determine the most reliable integration method for displaying scriptures.

---

## Background

Divine Link currently uses keyboard automation to trigger scriptures in ProPresenter:
1. Detect scripture reference
2. Activate ProPresenter window
3. Send keyboard shortcuts (Cmd+G, type reference, Enter)

This approach has potential reliability issues:
- Requires ProPresenter window to be accessible
- Keyboard focus can be stolen by other apps
- Different ProPresenter versions may have different shortcuts
- No direct feedback that the action succeeded

ProPresenter has an HTTP API that includes a `/message` endpoint. This research will evaluate whether:
- The Message API is a better integration path
- It provides more reliable verse display
- It offers advantages over keyboard automation

---

## Research Objectives

| # | Objective | Expected Outcome |
|---|-----------|------------------|
| 1 | Document ProPresenter API endpoints for messages | List of relevant endpoints |
| 2 | Test `/v1/message` endpoint functionality | Working example code |
| 3 | Compare Message vs. Bible integration | Pros/cons analysis |
| 4 | Evaluate text formatting options | Can we match Bible styling? |
| 5 | Test reliability in live scenarios | Success rate comparison |
| 6 | Document version compatibility | Which PP versions support API? |

---

## ProPresenter API Endpoints to Research

### Known Endpoints (from ProPresenter 7+ documentation)

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/v1/messages` | GET | List all message tokens |
| `/v1/message/{id}` | GET | Get specific message |
| `/v1/message/{id}/trigger` | GET | Trigger a message |
| `/v1/message/{id}/clear` | GET | Clear a message |
| `/v1/messages/{id}/tokens` | GET | Get message tokens |
| `/v1/messages/{id}/tokens/{token_name}` | PUT | Update token value |

### Key Questions to Answer

1. **What is a "Message" in ProPresenter?**
   - Pre-configured text overlay
   - Uses tokens (placeholders) like `{scripture}`, `{reference}`
   - Typically used for announcements, lower thirds

2. **Can Messages display formatted scripture?**
   - Multiple lines of verse text
   - Reference formatting (book, chapter, verse)
   - Custom styling per message template

3. **How does Message compare to Bible?**
   - Bible module has versified text, search, navigation
   - Message is arbitrary text with tokens
   - Message may be more flexible but less automatic

---

## Research Tasks

### Task 1: API Documentation Review

- [ ] Review official ProPresenter 7 API documentation
- [ ] Identify all message-related endpoints
- [ ] Document request/response formats
- [ ] Note authentication requirements (if any)

### Task 2: Message Template Setup

- [ ] Create test message template in ProPresenter
- [ ] Add tokens: `{book}`, `{chapter}`, `{verse}`, `{text}`
- [ ] Configure styling to match Bible appearance
- [ ] Test manual trigger via ProPresenter UI

### Task 3: API Testing

- [ ] Connect to ProPresenter API (port 1025)
- [ ] List available messages via `/v1/messages`
- [ ] Get message details and tokens
- [ ] Update token values programmatically
- [ ] Trigger message display
- [ ] Clear message

**Test Script (Swift):**

```swift
// MessageAPITest.swift
import Foundation

class ProPresenterMessageAPI {
    let baseURL: URL
    let session = URLSession.shared
    
    init(host: String = "localhost", port: Int = 1025) {
        self.baseURL = URL(string: "http://\(host):\(port)/v1")!
    }
    
    // List all messages
    func listMessages() async throws -> [PPMessage] {
        let url = baseURL.appendingPathComponent("messages")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([PPMessage].self, from: data)
    }
    
    // Update a token value
    func updateToken(messageId: String, tokenName: String, value: String) async throws {
        var url = baseURL
            .appendingPathComponent("messages/\(messageId)/tokens/\(tokenName)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["value": value])
        
        let (_, response) = try await session.data(for: request)
        // Check response status
    }
    
    // Trigger message display
    func triggerMessage(id: String) async throws {
        let url = baseURL.appendingPathComponent("message/\(id)/trigger")
        let (_, _) = try await session.data(from: url)
    }
    
    // Clear message
    func clearMessage(id: String) async throws {
        let url = baseURL.appendingPathComponent("message/\(id)/clear")
        let (_, _) = try await session.data(from: url)
    }
}

struct PPMessage: Codable {
    let id: String
    let name: String
    let tokens: [PPToken]?
}

struct PPToken: Codable {
    let name: String
    let value: String
}
```

### Task 4: Comparison Matrix

Create comparison document:

| Aspect | Keyboard (Bible) | Message API |
|--------|------------------|-------------|
| Reliability | Medium | High |
| Speed | Fast | Fast |
| Requires focus | Yes | No |
| Version support | All | 7+ |
| Formatting | Native Bible styling | Custom templates |
| Error handling | Limited | API responses |
| Multi-verse | Automatic | Manual (multiple tokens) |
| Cross-references | Supported | Manual |

### Task 5: Reliability Testing

- [ ] Run 50 consecutive triggers via keyboard
- [ ] Run 50 consecutive triggers via API
- [ ] Compare success rates
- [ ] Measure response times
- [ ] Test with ProPresenter in background
- [ ] Test during active presentation

---

## Expected Deliverables

1. **Research Report** (`docs/research/propresenter-message-api.md`)
   - API endpoint documentation
   - Working code examples
   - Comparison analysis
   - Recommendation

2. **Test Message Template**
   - ProPresenter template file
   - Token configuration
   - Styling guidelines

3. **Proof of Concept Code**
   - Swift API client
   - Token update functions
   - Trigger/clear functions

4. **Decision Document**
   - Recommended approach (Message API, Keyboard, or Hybrid)
   - Migration path if changing approach
   - Risk assessment

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | All Message API endpoints documented | Research report complete |
| 2 | Working API connection established | Successful API calls |
| 3 | Token values can be updated | Test demonstrates update |
| 4 | Messages can be triggered via API | Verse appears in PP |
| 5 | Comparison matrix completed | Document shows pros/cons |
| 6 | Recommendation documented | Clear decision with rationale |
| 7 | Version compatibility noted | Supported PP versions listed |

---

## Dependencies

- ProPresenter 7 or later installed
- Network API enabled in ProPresenter preferences
- Test message template created

---

## Definition of Done

- [ ] All research tasks completed
- [ ] API endpoints documented
- [ ] Working proof-of-concept code
- [ ] Comparison matrix filled in
- [ ] Reliability testing completed
- [ ] Recommendation documented
- [ ] Research report committed to Git

---

## ProPresenter API Enable Instructions

To enable the API in ProPresenter:

1. Open ProPresenter Preferences
2. Navigate to Network tab
3. Enable "Network" or "API Server"
4. Note the port (default: 1025)
5. Optionally set a password (for remote access)

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| API not available in older PP versions | Medium | High | Document minimum version required |
| Message formatting limited | Low | Medium | Test extensively with templates |
| API changes in future PP updates | Low | Medium | Abstract API calls for easy updates |
| Performance issues | Low | Low | Benchmark vs. keyboard |

---

## Notes

- This is a **research story** - no production code changes
- Findings will inform Story 6.4 implementation
- If Message API is not viable, keyboard automation remains the production method
- Consider hybrid approach: API for display, keyboard as fallback
