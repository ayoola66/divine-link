# Epic 7: Advanced Detection & Personalisation

**Epic ID:** 7  
**Status:** In Progress (2/3 Complete)  
**Priority:** High  
**Source:** Professor BMAD Technical Review (Feb 2026)  
**Target Version:** v1.3.0

---

## Epic Goal

Transform Divine Link from a "Great App" to a "Market-Dominating Product" by implementing advanced AI features that provide contextual awareness, implicit detection, and personalised pastor profiles.

---

## Business Context

**Professor BMAD Assessment:**
> "You are no longer in the 'Idea' phase. You are in the 'Optimization & Scaling' phase."

Key competitive advantages identified:

1. **Stateful Detection**: Remember context so "verse 18" after "John 3:16" is understood
2. **Implicit Detection**: AI-powered detection of phrases like "the verse we just read"
3. **Pastor Profiles**: Sticky feature that locks churches into the platform

These features will put Divine Link "miles ahead of any competitor."

---

## Stories

| # | Story | Complexity | Status | Priority |
|---|-------|------------|--------|----------|
| 7.1 | [Reference Buffer (Stateful Detection)](story-7.1-reference-buffer.md) | Medium | Not Started | P0 |
| 7.2 | [Implicit Detection (AI-Powered)](story-7.2-implicit-detection.md) | Large | ⚠️ Basic (Phrase-based, not AI) | P1 |
| 7.3 | [Pastor Profiles](story-7.3-pastor-profiles.md) | Medium | ✅ Complete | P1 |

---

## Implementation Notes

### Story 7.2 - Current State
- `ImplicitReferenceDetector.swift` exists with **phrase-matching** for famous verses
- Does NOT yet use AI/MLX for true implicit detection (e.g., "the verse we just read")
- This is a basic implementation; full AI-powered version still pending

### Story 7.3 - Complete ✅
- `PastorProfilesView.swift` - Full UI for managing pastor profiles
- `SpeechCorrectionService.swift` - Speech learning per pastor
- `PastorProfile` model with speech corrections, service counts
- Profiles persist across sessions

---

## Success Criteria

- [ ] "Verse 18" detected correctly after "John 3:16" mention (stateful context) - **7.1 PENDING**
- [ ] "The verse we just read" triggers previous scripture (AI-powered) - **7.2 PENDING**
- [x] Pastor profiles save preferred translation per pastor ✅
- [x] Profiles persist across sessions and app restarts ✅
- [ ] Zero cloud costs for AI features (local processing only) - **7.2 PENDING**
- [ ] Detection accuracy improved measurably

---

## Technical Strategy

### Local-First AI

All AI features use local processing to avoid cloud costs:

- **MLX Framework**: Apple's ML acceleration for macOS
- **Quantised Models**: Llama-3 or Mistral (4-bit quantised)
- **On-Device Processing**: No internet required during services

### Detection Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                    Detection Pipeline (Enhanced)                 │
│                                                                  │
│  Audio → ASR → ┌─────────────────────────────────────────────┐  │
│                │           Detection Engine                   │  │
│                │  ┌───────────────────────────────────────┐  │  │
│                │  │ 1. Explicit Pattern Matching          │  │  │
│                │  │    "John 3:16" → Direct match         │  │  │
│                │  ├───────────────────────────────────────┤  │  │
│                │  │ 2. Stateful Context (NEW - 7.1)       │  │  │
│                │  │    "verse 18" → John 3:18 (buffered)  │  │  │
│                │  ├───────────────────────────────────────┤  │  │
│                │  │ 3. Implicit Detection (NEW - 7.2)     │  │  │
│                │  │    "the verse" → Last pushed verse    │  │  │
│                │  └───────────────────────────────────────┘  │  │
│                └─────────────────────────────────────────────┘  │
│                                    │                             │
│                                    ▼                             │
│                           Scripture Match                        │
│                      (with confidence score)                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## Dependencies

- Epic 2 (Scripture Detection Engine) ✅ Complete
- Epic 6 (Operator Safety) ✅ Complete
- Apple MLX Framework for local AI (for 7.2 AI upgrade)
- Quantised LLM model (Llama-3 or Mistral) (for 7.2 AI upgrade)

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Local LLM too slow for real-time | Medium | High | Benchmark extensively, use smaller model |
| Mac hardware insufficient | Low | High | Minimum spec requirements (M1+) |
| Context buffer causes false positives | Medium | Medium | Timeout on context, confidence scoring |
| Model download size too large | Low | Medium | Offer as optional download |

---

## Hardware Requirements

For AI features (Story 7.2):

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| Chip | Apple M1 | Apple M2/M3 |
| RAM | 8GB | 16GB |
| Storage | 5GB free | 10GB free |

---

## Estimated Effort

| Story | Complexity | Est. Hours |
|-------|------------|------------|
| 7.1 Reference Buffer | Medium | 8-12 |
| 7.2 Implicit Detection | Large | 16-24 |
| 7.3 Pastor Profiles | Medium | 8-12 |
| **Total** | | **32-48 hours** |

---

## Market Impact

**Professor BMAD:**
> "Once a church sets up their 4 pastors with their preferred translations, they will never switch to another app."

These features create:
1. **Switching Costs**: Pastor profiles are sticky
2. **Competitive Moat**: AI detection is hard to replicate
3. **Love Tier Value**: Justifies premium subscription

---

## Notes

- All AI processing is local (no cloud costs)
- Features are progressive enhancements (app works without them)
- Pastor profiles are the "sticky feature" for retention
- Implicit detection is the "Love Tier" selling point
