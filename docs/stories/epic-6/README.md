# Epic 6: Operator Safety & Detection Confidence

**Epic ID:** 6  
**Status:** In Progress  
**Priority:** High  
**Source:** Product Feedback Review (Feb 2026)  
**Target Version:** v1.2.0

---

## Epic Goal

Enhance operator confidence and safety during live services by adding panic controls, detection confidence indicators, and implementing a robust hybrid ProPresenter integration system with automatic fallbacks.

---

## Business Context

Feedback from product review identified three key gaps:

1. **Safety Toggle**: Operators need an instant "panic button" to clear the screen during unexpected situations
2. **Confidence Indicator**: Operators should know when the AI is uncertain about a detected verse
3. **ProPresenter Integration**: Current keyboard automation may be fragile; need a hybrid approach with API-based methods and automatic fallbacks

---

## Stories

| # | Story | Complexity | Status | Priority |
|---|-------|------------|--------|----------|
| 6.1 | [Panic Button & Clear Screen](story-6.1-panic-button.md) | Small | Not Started | P0 |
| 6.2 | [Detection Confidence Indicator](story-6.2-confidence-indicator.md) | Medium | Not Started | P0 |
| 6.3 | [ProPresenter Message API Research](story-6.3-propresenter-message-api.md) | Medium | ✅ Complete | P1 |
| 6.4 | [ProPresenter WebSocket Messages API](story-6.4-propresenter-message-implementation.md) | Large | Not Started | P1 |
| 6.5 | [Hybrid Integration Manager](story-6.5-propresenter-theme-injection.md) | Large | Not Started | P0 |

### Story Summaries (Updated)

**6.3 - API Research** ✅ Complete
- Verified Messages API can display on Audience screen via Looks feature
- Documented WebSocket protocol (messageSend, messageHide, looksRequest)
- Recommended hybrid approach: WebSocket for Premium, Keyboard for Free

**6.4 - WebSocket Messages API** (Rewritten)
- Implements `AudienceWebSocketOutput` using WebSocket `messageSend`
- Factory Pattern (`ProPresenterOutputFactory`) for swappable outputs
- Three output types: StageDisplay (HTTP), AudienceWebSocket, AudienceKeyboard
- Tier-gated: Grace/Love tiers get WebSocket access

**6.5 - Hybrid Integration Manager** (Rewritten)
- Orchestrates all three ProPresenter output paths
- Automatic fallback from WebSocket to Keyboard on failure
- Messages layer detection via `looksRequest`
- Connection health dashboard in Settings
- Integrates with Panic Button for unified clear

---

## Success Criteria

- [ ] Operator can instantly clear any displayed verse with one keypress
- [ ] Confidence level (Low/Medium/High) visible on detected verses
- [ ] Low-confidence verses visually distinct from high-confidence ones
- [x] ProPresenter Messages API evaluated as alternative to keyboard automation ✅ **VERIFIED**
- [x] Messages layer routing to Audience screen confirmed ✅ **VERIFIED**
- [ ] Factory Pattern implemented for swappable outputs
- [ ] WebSocket Messages API implementation complete
- [ ] Hybrid Integration Manager coordinates all output paths
- [ ] Automatic fallback from WebSocket to Keyboard works
- [ ] Tier strategy implemented (Messages API for Premium, keyboard for Free)

---

## Dependencies

- Epic 3 (ProPresenter Integration) - already complete
- Epic 2 (Scripture Detection Engine) - already complete

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| ~~ProPresenter API not supporting /message~~ | ~~Medium~~ | ~~High~~ | ✅ **RESOLVED** - Messages API verified |
| Messages layer not enabled by users | High | Medium | Provide setup guide + keyboard fallback |
| WebSocket connection drops mid-service | Low | Medium | Auto-reconnect + keyboard fallback |
| Confidence scoring too complex | Low | Medium | Start with simple word-match percentage |
| Panic button conflicts with existing shortcuts | Low | Low | Use dedicated key (F12 or Cmd+Esc) |

---

## Estimated Effort

| Story | Complexity | Est. Hours |
|-------|------------|------------|
| 6.1 Panic Button | Small | 2-4 |
| 6.2 Confidence Indicator | Medium | 4-8 |
| 6.3 API Research | Medium | ✅ Complete |
| 6.4 WebSocket Messages API | Large | 16-20 |
| 6.5 Hybrid Integration Manager | Large | 20-24 |
| **Total** | | **42-56 hours** |

---

## Implementation Order

1. ✅ **6.3 API Research** - Complete
2. **6.4 WebSocket Messages API** - Implements Factory Pattern + WebSocket output
3. **6.1 Panic Button** - Critical safety feature (integrates with 6.5)
4. **6.5 Hybrid Integration Manager** - Orchestrates all paths + fallbacks
5. **6.2 Confidence Indicator** - Operator trust feature

---

## Tier Strategy

| Tier | Stage Display | Audience Screen | Setup Required |
|------|---------------|-----------------|----------------|
| **Mercy (Free)** | HTTP REST | Keyboard (⌘B) | Accessibility only |
| **Grace** | HTTP REST | WebSocket Messages | Looks + Template |
| **Love (Pro)** | HTTP REST | WebSocket Messages | Looks + Template |

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    HybridIntegrationManager                   │
│  ┌─────────────┐  ┌─────────────────┐  ┌──────────────────┐  │
│  │ StageOutput │  │ AudienceWebSocket│  │ AudienceKeyboard │  │
│  │  (HTTP PUT) │  │   (WebSocket)    │  │   (CGEvent)      │  │
│  └─────────────┘  └─────────────────┘  └──────────────────┘  │
│         │                 │                    │              │
│         ▼                 ▼                    ▼              │
│  /v1/stage/message    messageSend         Keyboard ⌘B        │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
                     ProPresenter 7+
```
