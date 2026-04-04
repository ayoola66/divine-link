# Epic 8: Feature Prioritization Matrix

**Document Type:** Decision Support Tool
**Version:** 1.0
**Date:** February 17, 2026
**Owner:** Product Team

---

## Executive Summary

This matrix evaluates all Epic 8 stories across multiple dimensions to inform implementation priority and resource allocation. **All features maintain local-first architecture** - no cloud dependencies.

---

## 1. Effort vs. Impact Matrix

```
Impact (User Value)
         ↑
    High │
         │
      5  │  [8.1 UI]        [8.6 Multi-Platform]
         │   Modern          EasyWorship/FreeShow
         │   Redesign        Integration
      4  │
         │  [8.2 Search]    [8.3 Sessions]
      3  │   Manual          Service Session
         │   Scripture       Management
         │   Lookup
      2  │
         │  [8.4 Export]    [8.5 Localization]
      1  │   PDF/MD          UK/US English
         │   Export          Toggle
    Low  │
         └────────────────────────────────────→
              Low  1   2   3   4   5  High
                     Effort (Dev Hours)

LEGEND:
[8.1] = 25 hrs, Impact: 5/5 → Quick Wins (do first)
[8.2] = 13 hrs, Impact: 4/5 → Quick Wins
[8.3] = 15 hrs, Impact: 4/5 → Quick Wins
[8.4] = 8 hrs,  Impact: 2/5 → Fill-ins (low effort)
[8.5] = 6 hrs,  Impact: 2/5 → Fill-ins
[8.6] = 28 hrs, Impact: 5/5 → Strategic Bets (high effort, high reward)
```

---

## 2. Detailed Story Evaluation

| Story ID | Feature | Complexity | Dev Hours | Impact | Priority | Phase |
|----------|---------|------------|-----------|--------|----------|-------|
| **8.1** | Modern UI Redesign | Large | 20-30 (avg: 25) | 5/5 | **P0** | Phase 1 |
| **8.2** | Manual Scripture Search | Medium | 10-16 (avg: 13) | 4/5 | **P0** | Phase 2 |
| **8.3** | Service Session Mgmt | Medium | 12-18 (avg: 15) | 4/5 | **P0** | Phase 2 |
| **8.4** | Export Functionality | Small | 6-10 (avg: 8) | 2/5 | **P0** | Phase 2 |
| **8.5** | Language Localization | Small | 4-8 (avg: 6) | 2/5 | **P1** | Phase 1 |
| **8.6** | Multi-Platform Integration | Large | 24-32 (avg: 28) | 5/5 | **P1** | Phase 3 |

**Total Effort:** 76-114 hours (~2-3 weeks full-time)

---

## 3. Impact Scoring Breakdown

### 8.1 - Modern UI Redesign (Impact: 5/5)
| Dimension | Score | Justification |
|-----------|-------|---------------|
| **User Satisfaction** | 5/5 | First impression drives perceived quality; dated UI hurts credibility |
| **Competitive Gap** | 5/5 | QuickVerse's modern UI is primary competitive threat |
| **Market Expectation** | 5/5 | 2026 users expect YouVersion-level polish |
| **Retention** | 4/5 | Poor UI drives churn; modern UI increases stickiness |
| **Conversion (Free→Paid)** | 4/5 | Premium-feeling UI justifies premium pricing |
| **Average** | **4.6** ≈ 5/5 | **Critical foundation for all other features** |

**Dependencies:** All other stories build on new UI components → **Must do first**

---

### 8.2 - Manual Scripture Search (Impact: 4/5)
| Dimension | Score | Justification |
|-----------|-------|---------------|
| **User Satisfaction** | 5/5 | Most requested feature (operators need proactive lookup) |
| **Competitive Gap** | 5/5 | QuickVerse has this; we don't = clear disadvantage |
| **Workflow Efficiency** | 5/5 | Enables pre-sermon preparation, mid-sermon corrections |
| **Market Expectation** | 4/5 | Table stakes for any Bible software |
| **Feature Completeness** | 3/5 | Fills obvious gap but not a differentiator |
| **Average** | **4.4** ≈ 4/5 | **Critical missing capability** |

**Use Cases:**
- Pre-sermon: Operator pre-loads verses for sermon outline
- Mid-sermon: Operator corrects misdetected verse
- Post-sermon: Quick lookup for pastor questions

---

### 8.3 - Service Session Management (Impact: 4/5)
| Dimension | Score | Justification |
|-----------|-------|---------------|
| **User Satisfaction** | 4/5 | Enables review, organization, analytics |
| **Competitive Gap** | 5/5 | QuickVerse's session notes = strong feature |
| **Data Utility** | 5/5 | Transforms ephemeral data into historical record |
| **Pastor Value** | 4/5 | Pastors can review sermon scripture usage over time |
| **Retention** | 3/5 | Increases long-term value (more data = stickier) |
| **Average** | **4.2** ≈ 4/5 | **High value, less urgent than UI/Search** |

**Strategic Value:** Builds foundation for future analytics features

---

### 8.4 - Export Functionality (Impact: 2/5)
| Dimension | Score | Justification |
|-----------|-------|---------------|
| **User Satisfaction** | 3/5 | Nice-to-have but not blocking |
| **Competitive Gap** | 2/5 | QuickVerse has it but less critical |
| **Workflow Integration** | 3/5 | Enables use in other tools (study notes) |
| **Data Portability** | 2/5 | Good practice but low usage expected |
| **Market Expectation** | 2/5 | Expected but not a key differentiator |
| **Average** | **2.4** ≈ 2/5 | **Low-hanging fruit, do when capacity allows** |

**Effort/Impact Ratio:** Low effort (8 hrs) for moderate value → **Include in Phase 2**

---

### 8.5 - Language Localization (Impact: 2/5)
| Dimension | Score | Justification |
|-----------|-------|---------------|
| **User Satisfaction** | 1/5 | Minimal for current market (UK/US English speakers) |
| **Market Expansion** | 3/5 | Opens UK market (currently 95% US-focused) |
| **Competitive Gap** | 2/5 | QuickVerse has it; nice parity feature |
| **Infrastructure Value** | 4/5 | Sets foundation for future internationalization |
| **Market Expectation** | 1/5 | Low priority for native English speakers |
| **Average** | **2.2** ≈ 2/5 | **Strategic investment for future, not urgent** |

**Rationale for P1:** Low effort (6 hrs) + future-proofing = worth doing but not blocking

---

### 8.6 - Multi-Platform Integration (Impact: 5/5)
| Dimension | Score | Justification |
|-----------|-------|---------------|
| **Market Expansion** | 5/5 | Opens EasyWorship/FreeShow markets (30-40% of churches) |
| **Competitive Gap** | 5/5 | QuickVerse supports 3 platforms; we only support 1 |
| **Revenue Potential** | 5/5 | Directly expands addressable market |
| **User Satisfaction** | 4/5 | Removes platform lock-in concern |
| **Strategic Value** | 5/5 | Critical for market leadership |
| **Average** | **4.8** ≈ 5/5 | **Highest strategic value but requires research** |

**Risk Factors:**
- API availability unknown (research phase needed)
- EasyWorship/FreeShow documentation may be limited
- May require reverse-engineering or keyboard automation fallback

**Recommendation:** Start with research spike (4-8 hrs) to validate feasibility before committing

---

## 4. RICE Scoring (Reach × Impact × Confidence ÷ Effort)

| Story | Reach | Impact | Confidence | Effort | RICE Score | Rank |
|-------|-------|--------|------------|--------|------------|------|
| **8.2** Search | 90% | 5 | 90% | 13 hrs | **31.2** | #1 |
| **8.1** UI | 100% | 5 | 80% | 25 hrs | **16.0** | #2 |
| **8.3** Sessions | 70% | 4 | 85% | 15 hrs | **15.9** | #3 |
| **8.4** Export | 40% | 2 | 95% | 8 hrs | **9.5** | #4 |
| **8.6** Multi-Platform | 60% | 5 | 50% | 28 hrs | **5.4** | #5 |
| **8.5** Localization | 10% | 2 | 90% | 6 hrs | **3.0** | #6 |

**RICE Interpretation:**
- **Reach:** % of users who will encounter this feature in first 3 months
- **Impact:** Value per user (1=minimal, 5=transformative)
- **Confidence:** % certainty in estimates
- **Effort:** Developer hours

**Key Insight:** Manual Search (#1) scores higher than UI Redesign (#2) despite lower effort, but UI Redesign must happen first due to dependencies.

---

## 5. MoSCoW Prioritization

### Must-Have (Ship-Blockers)
✅ **8.1 - Modern UI Redesign**
- Rationale: Foundation for all other features; addresses primary competitive weakness
- Risk if cut: Divine Link appears outdated vs. QuickVerse; hurts conversions

✅ **8.2 - Manual Scripture Search**
- Rationale: Critical missing capability; table stakes for Bible software
- Risk if cut: Users frustrated by inability to proactively lookup verses

### Should-Have (High-Value, Not Blocking)
⚠️ **8.3 - Service Session Management**
- Rationale: Organizational feature that increases long-term value
- Risk if cut: Data remains ephemeral; missed opportunity for analytics

⚠️ **8.4 - Export Functionality**
- Rationale: Low effort, enables data portability
- Risk if cut: Users can't integrate Divine Link data into other workflows

### Could-Have (Nice-to-Haves)
🔵 **8.6 - Multi-Platform Integration**
- Rationale: High strategic value but requires feasibility validation
- Risk if cut: Limited to ProPresenter market only (60% TAM)

🔵 **8.5 - Language Localization**
- Rationale: Future-proofing infrastructure investment
- Risk if cut: UK market closed; future internationalization harder

---

## 6. Risk-Adjusted Prioritization

| Story | Value | Effort | Risk Level | Risk-Adjusted Priority |
|-------|-------|--------|------------|------------------------|
| **8.1** UI | 5/5 | 25 hrs | Low (SwiftUI mature) | **P0 - Do First** |
| **8.2** Search | 4/5 | 13 hrs | Low (CRUD + regex) | **P0 - Do Second** |
| **8.3** Sessions | 4/5 | 15 hrs | Low (data modeling) | **P0 - Do Third** |
| **8.4** Export | 2/5 | 8 hrs | Low (PDFKit battle-tested) | **P0 - Do Fourth** |
| **8.5** Localization | 2/5 | 6 hrs | Low (iOS i18n mature) | **P1 - Phase 1** |
| **8.6** Multi-Platform | 5/5 | 28 hrs | **High (API unknown)** | **P1 - Research First** |

**High-Risk Item: 8.6 Multi-Platform Integration**
- **Risk:** EasyWorship/FreeShow APIs may not exist or be undocumented
- **Mitigation:** 4-8 hour research spike before committing to Phase 3
- **Fallback:** Keyboard automation (similar to current ProPresenter fallback)

---

## 7. Recommended Implementation Sequence

### ✅ Phase 1: Visual Foundation (Week 1) - 31 hours
1. **8.1 Modern UI Redesign** (25 hrs) - P0
   - Establish new design system
   - Rebuild core components (cards, buttons, typography)
   - YouVersion-inspired color palette + DL gold accent

2. **8.5 Language Localization** (6 hrs) - P1
   - Set up Localizable.strings infrastructure
   - UK/US English variants
   - *(Low effort, enables future internationalization)*

**Deliverable:** Modern, localized UI ready for feature additions

---

### ✅ Phase 2: Core Features (Week 2) - 36 hours
3. **8.2 Manual Scripture Search** (13 hrs) - P0
   - Search by reference + phrase
   - Bible version selector
   - Quick actions (Copy, Send to ProPresenter)

4. **8.3 Service Session Management** (15 hrs) - P0
   - Session CRUD operations
   - Timeline view of services
   - Scripture-session associations

5. **8.4 Export Functionality** (8 hrs) - P0
   - PDF/Markdown/Text export
   - Share sheet integration

**Deliverable:** Feature-complete UX upgrade with parity to QuickVerse (minus cloud features)

---

### ⚠️ Phase 3: Platform Expansion (Week 3) - 28 hours + research
6. **Research Spike: EasyWorship/FreeShow APIs** (4-8 hrs)
   - Validate API availability
   - Document integration approaches
   - Prototype proof-of-concept

7. **8.6 Multi-Platform Integration** (28 hrs) - P1
   - *(Contingent on research spike success)*
   - EasyWorship client implementation
   - FreeShow client implementation
   - Abstract output layer refactoring

**Decision Point:** After research spike, decide:
- ✅ Proceed if APIs are documented/accessible
- ⚠️ Defer to Epic 9 if APIs require reverse-engineering
- 🔄 Pivot to keyboard automation fallback if APIs don't exist

**Deliverable:** Multi-platform support (2-3 presentation software integrations)

---

## 8. Resource Allocation

### Minimum Viable Epic 8 (MVP)
**Scope:** Phase 1 + Phase 2 only
**Effort:** 67 hours (~1.5 weeks)
**Outcome:** Modern UI + feature parity with QuickVerse (local-first)

**Stories Included:**
- 8.1 Modern UI Redesign ✅
- 8.2 Manual Scripture Search ✅
- 8.3 Service Session Management ✅
- 8.4 Export Functionality ✅
- 8.5 Language Localization ✅

**Stories Deferred:**
- 8.6 Multi-Platform Integration → Epic 9

**Rationale:** Delivers immediate competitive parity while deferring high-risk/high-effort multi-platform work

---

### Full Epic 8 (Recommended)
**Scope:** Phase 1 + Phase 2 + Phase 3
**Effort:** 95-102 hours (~2.5 weeks)
**Outcome:** Modern UI + multi-platform support + feature parity

**Risk Management:**
- Front-load research spike (Week 1)
- Parallel-track UI work during research phase
- Decision gate after research spike

---

## 9. Success Metrics

### User Satisfaction Metrics
- **UI Modernization:** User survey score increase (target: +30%)
- **Manual Search:** Feature usage rate (target: 60% of sessions)
- **Session Management:** Sessions created per church (target: 4+ per month)
- **Export:** Export actions per week (target: 1+ per user)
- **Multi-Platform:** Non-ProPresenter users (target: 20% of user base)

### Business Metrics
- **Conversion (Free→Paid):** Target +15% (modern UI justifies premium)
- **Churn Reduction:** Target -10% (feature completeness increases stickiness)
- **Market Expansion:** +40% TAM (EasyWorship/FreeShow markets)

---

## 10. Decision Matrix Summary

### Recommended Approach: **Phased Rollout with Decision Gate**

**Week 1 (Phase 1):**
- ✅ 8.1 Modern UI Redesign
- ✅ 8.5 Language Localization
- 🔬 **Research Spike: Multi-Platform APIs** (parallel)

**Week 2 (Phase 2):**
- ✅ 8.2 Manual Scripture Search
- ✅ 8.3 Service Session Management
- ✅ 8.4 Export Functionality

**Week 3 (Phase 3 - Conditional):**
- 🚦 **Decision Gate:** Review research spike results
  - ✅ **Green Light:** Proceed with 8.6 Multi-Platform Integration
  - ⚠️ **Yellow Light:** Defer to Epic 9, ship MVP Epic 8
  - 🔴 **Red Light:** Pivot to keyboard automation fallback

---

## 11. Alternative Scenarios

### Scenario A: Time-Constrained (1 Week Budget)
**Minimum Scope:**
- 8.1 Modern UI Redesign (25 hrs)
- 8.2 Manual Scripture Search (13 hrs)
- 8.4 Export (8 hrs)
**Total:** 46 hours
**Trade-off:** Defer sessions + localization + multi-platform

### Scenario B: Feature Parity Focus (No Multi-Platform)
**Scope:** Phase 1 + Phase 2 only (67 hrs)
**Outcome:** QuickVerse feature parity, local-first advantage maintained
**Defer:** Multi-platform to Epic 9

### Scenario C: Market Expansion Priority
**Scope:** Skip 8.3 + 8.4, prioritize 8.6
**Total:** 59 hours
**Outcome:** Multi-platform support at cost of organization features

---

## 12. Final Recommendation

### **Recommended Path: Scenario B (Phase 1 + Phase 2)**

**Rationale:**
1. ✅ Achieves core goal: Modern UI + feature parity
2. ✅ Maintains Divine Link identity (local-first, operator control)
3. ✅ Addresses all P0 competitive gaps
4. ✅ Manageable risk (low-risk stories only)
5. ✅ Ships in 1.5-2 weeks

**Defer to Epic 9:**
- 8.6 Multi-Platform Integration (requires research validation)

**Post-Epic 8 Position:**
- Modern, YouVersion-inspired UI ✅
- Feature parity with QuickVerse (minus cloud) ✅
- Maintained local-first competitive advantage ✅
- Ready for multi-platform expansion in Epic 9 ✅

---

**Decision Maker:** coachAOG
**Status:** Ready for Approval
**Next Step:** Create individual story documents for approved scope
