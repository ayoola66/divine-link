# Epic 6: Operator Safety & Detection Confidence

**Epic ID:** 6  
**Status:** Not Started  
**Priority:** High  
**Source:** Product Feedback Review (Feb 2026)

---

## Epic Goal

Enhance operator confidence and safety during live services by adding panic controls, detection confidence indicators, and researching improved ProPresenter integration methods.

---

## Business Context

Feedback from product review identified three key gaps:

1. **Safety Toggle**: Operators need an instant "panic button" to clear the screen during unexpected situations
2. **Confidence Indicator**: Operators should know when the AI is uncertain about a detected verse
3. **ProPresenter Integration**: Current keyboard automation may be fragile; API-based approach could be more reliable

---

## Stories

| # | Story | Complexity | Status | Priority |
|---|-------|------------|--------|----------|
| 6.1 | [Panic Button & Clear Screen](story-6.1-panic-button.md) | Small | Not Started | P0 |
| 6.2 | [Detection Confidence Indicator](story-6.2-confidence-indicator.md) | Medium | Not Started | P0 |
| 6.3 | [ProPresenter Message API Research](story-6.3-propresenter-message-api.md) | Medium | Not Started | P1 |
| 6.4 | [ProPresenter Message API Implementation](story-6.4-propresenter-message-implementation.md) | Large | Not Started | P2 |
| 6.5 | [ProPresenter Theme/Slide Injection](story-6.5-propresenter-theme-injection.md) | Large | Not Started | P0 |

**Note:** Story 6.5 is the **#1 technical priority** per Professor BMAD's assessment. ✅ **Research Complete:** Messages API verified - Messages layer CAN route to Audience screen via Looks feature. This enables direct API injection without keyboard automation.

---

## Success Criteria

- [ ] Operator can instantly clear any displayed verse with one keypress
- [ ] Confidence level (Low/Medium/High) visible on detected verses
- [ ] Low-confidence verses visually distinct from high-confidence ones
- [x] ProPresenter Messages API evaluated as alternative to keyboard automation ✅ **VERIFIED**
- [x] Messages layer routing to Audience screen confirmed ✅ **VERIFIED**
- [ ] Messages API implementation complete
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
| Confidence scoring too complex | Low | Medium | Start with simple word-match percentage |
| Panic button conflicts with existing shortcuts | Low | Low | Use dedicated key (F12 or Cmd+Esc) |

---

## Estimated Effort

| Story | Complexity | Est. Hours |
|-------|------------|------------|
| 6.1 Panic Button | Small | 2-4 |
| 6.2 Confidence Indicator | Medium | 4-8 |
| 6.3 API Research | Medium | 4-6 |
| 6.4 API Implementation | Large | 8-16 |
| 6.5 Theme/Slide Injection | Large | 16-24 |
| **Total** | | **34-58 hours** |

**Priority Order per Professor BMAD:**
1. **6.5 Theme Injection** (P0) - ✅ Research complete, ready for implementation
2. **6.1 Panic Button** (P0) - Critical safety feature
3. **6.2 Confidence Indicator** (P0) - Operator trust feature
4. ✅ **6.3 API Research** (P1) - **COMPLETE** - Messages API verified
5. **6.4 Message API** (P2) - Stage Display implemented, Audience via 6.5

**Updated Strategy:**
- **Mercy (Free) Tier:** Keyboard automation (⌘B) - zero configuration
- **Grace/Premium Tier:** Messages API - requires Messages layer setup
- **Love (Pro) Tier:** Messages API + advanced features
