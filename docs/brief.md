# Project Brief: Divine Link

**Document Type:** Project Brief  
**Version:** 1.0  
**Date:** January 2026  
**Status:** Analysis Phase Complete  
**BMAD Level:** 3 (Complex System)

---

## Executive Summary

Divine Link is a macOS application that listens to live preaching, detects Bible verse references (both explicit and implicit), and automatically populates scripture slides in ProPresenter 7+ via its network API. The application prioritises **user trust** through a human-in-the-loop workflow, ensuring no scripture appears on screen without operator confirmation.

**Primary Problem:** Church media operators must manually search for and display scriptures in real-time, often missing references or creating delays that disrupt the worship experience.

**Target Market:** Churches and ministries using ProPresenter for live presentation, particularly those with dedicated media/tech teams.

**Key Value Proposition:** Sub-second scripture detection with local-first processing, zero variable costs, and seamless ProPresenter integration—all while keeping humans in control.

---

## Problem Statement

### Current State & Pain Points

1. **Manual Scripture Lookup:** Operators must listen, identify the verse, search a Bible database, copy text, and paste into presentation software—often taking 15-30 seconds
2. **Missed References:** Preachers frequently reference scriptures in passing; operators miss 30-50% of verse mentions during dynamic sermons
3. **Cognitive Overload:** Operators juggle multiple responsibilities (lyrics, announcements, cameras) while trying to catch scripture references
4. **Delayed Display:** By the time a verse appears on screen, the preacher has moved on, reducing the educational impact

### Why Existing Solutions Fall Short

- **Cloud-based transcription services:** High latency (2-5 seconds), ongoing costs, privacy concerns with sermon content
- **Manual hotkey systems:** Still require operator to identify and search for verses
- **Pre-loaded sermon notes:** Preachers often deviate from prepared notes; doesn't handle spontaneous references

### Urgency

Churches are increasingly investing in production quality. Real-time scripture display is an expected feature that most cannot achieve reliably with current tools.

---

## Proposed Solution

### Core Concept

A macOS menu bar application that:

1. **Listens** to live audio via system audio or microphone input
2. **Transcribes** speech locally using Apple's native Speech framework
3. **Detects** Bible references using pattern matching and NLP
4. **Queues** detected verses in a "Pending Buffer" UI
5. **Pushes** operator-approved verses to ProPresenter via network API

### Key Differentiators

| Feature | Divine Link | Competitors |
|---------|-------------|-------------|
| **Latency** | Sub-second (local processing) | 2-5 seconds (cloud-based) |
| **Variable Costs** | £0 (local-first) | £50-200/month (API calls) |
| **Human Control** | Mandatory approval | Often auto-push |
| **ProPresenter Native** | Direct API integration | Copy/paste workflows |
| **Privacy** | Sermon audio never leaves device | Cloud processing required |

### High-Level Vision

Divine Link becomes the invisible assistant for church media teams—always listening, always ready, but never acting without human oversight. It transforms scripture display from a stressful reactive task into a calm, confirmatory workflow.

---

## Target Users

### Primary User Segment: Church Media Operators

**Profile:**
- Volunteer or part-time staff members aged 16-65
- Moderate technical proficiency (comfortable with presentation software)
- Responsible for managing slides, lyrics, and media during services
- Often multitasking across multiple systems

**Current Behaviours:**
- Manually searching Bible apps/websites during sermons
- Pre-loading expected scriptures before service
- Missing spontaneous scripture references
- Using keyboard shortcuts to navigate presentations

**Specific Needs:**
- Reduce cognitive load during services
- Catch verses they would otherwise miss
- Maintain control over what appears on screen
- Seamless integration with existing ProPresenter workflow

**Goals:**
- Zero missed scripture references
- Confident, stress-free operation
- Enhanced worship experience for congregation

### Secondary User Segment: Pastors/Preachers

**Profile:**
- Primary speakers who reference scriptures during messages
- May review post-service analytics on scripture usage

**Needs:**
- Confidence that referenced scriptures will appear on screen
- No disruption to natural preaching flow
- Potential for sermon analytics (verses referenced, frequency)

---

## Goals & Success Metrics

### Business Objectives

- Launch MVP within 6 months of development start
- Achieve 100 paying customers within first year
- Maintain >90% customer retention rate
- Establish Divine Link as the standard for real-time scripture automation

### User Success Metrics

- Scripture detection accuracy >95% for explicit references
- Detection latency <1 second from spoken reference
- Operator approval workflow <2 seconds per verse
- Zero unintended scripture displays (100% human-in-the-loop compliance)

### Key Performance Indicators (KPIs)

| KPI | Definition | Target |
|-----|------------|--------|
| **Detection Rate** | % of spoken scripture references correctly identified | >95% |
| **False Positive Rate** | % of detected references that were incorrect | <5% |
| **Latency** | Time from spoken word to pending buffer display | <1 second |
| **Adoption Rate** | % of services where Divine Link is actively used | >90% |
| **NPS Score** | Net Promoter Score from user surveys | >50 |

---

## MVP Scope

### Core Features (Must Have)

1. **Audio Input Selection**
   - System audio capture (BlackHole/Loopback integration)
   - Microphone input selection
   - Audio level monitoring

2. **Real-Time Transcription**
   - Local speech-to-text using macOS Speech framework
   - Custom language model biased toward Bible vocabulary
   - Continuous transcription with rolling buffer

3. **Scripture Detection Engine**
   - Explicit reference parsing (e.g., "John chapter 3 verse 16")
   - Common format variations (e.g., "John 3:16", "the third chapter of John")
   - Book name fuzzy matching (e.g., "Revelations" → "Revelation")

4. **Pending Buffer UI**
   - Queue of detected scriptures awaiting approval
   - One-click or hotkey approval to push to ProPresenter
   - Dismiss/ignore option for false positives
   - Visual indicator of confidence level

5. **ProPresenter Integration**
   - Connection to ProPresenter via Network API
   - Push scripture text to stage message
   - Support for message templates with verse tokens

6. **Bible Database**
   - Local SQLite database with Berean Standard Bible
   - Verse lookup by reference
   - Full text retrieval for display

7. **Basic Settings**
   - ProPresenter connection configuration (IP, port)
   - Audio input selection
   - Hotkey customisation

### Out of Scope for MVP

- Multiple Bible translation support
- Implicit reference detection (thematic matching)
- Sermon analytics and reporting
- Cloud backup/sync
- Multi-user/multi-device support
- Windows/Linux versions
- Mobile companion app
- Auto-push mode (even as option)
- Video output/preview

### MVP Success Criteria

The MVP is successful when:
1. A media operator can run Divine Link during a live service
2. >90% of explicit scripture references are detected and queued
3. Operator can approve verses to ProPresenter in <2 seconds
4. Zero verses appear on screen without operator approval
5. System runs for 90+ minutes without crashes or memory issues

---

## Post-MVP Vision

### Phase 2 Features

- **Multiple Bible Translations:** NIV, ESV, KJV (with appropriate licensing)
- **Implicit Reference Detection:** "The woman at the well" → John 4
- **Sermon Analytics Dashboard:** Verses used, frequency, time-stamped log
- **Custom Vocabulary Training:** Add church-specific terms and phrases
- **Template Designer:** Create custom ProPresenter message templates

### Long-term Vision (1-2 Years)

- **Multi-Platform:** Windows and Linux support
- **Team Features:** Shared settings, role-based access
- **AI Enhancements:** Predictive verse suggestions, sermon themes
- **Integration Ecosystem:** OBS, vMix, Companion, church management systems
- **Mobile Companion:** Verse approval from phone/tablet

### Expansion Opportunities

- **Enterprise/Denominational Licensing:** Multi-church deployments
- **Sermon Archive Integration:** Searchable scripture history
- **Accessibility Features:** Real-time captions with scripture highlights
- **Education Market:** Bible study tools, lecture capture

---

## Technical Considerations

### Platform Requirements

| Requirement | Specification |
|-------------|---------------|
| **Target Platform** | macOS 14+ (Sonoma and later) |
| **Architecture** | Native macOS (SwiftUI + Swift) |
| **Minimum Hardware** | Apple Silicon (M1) or Intel Core i5 |
| **Memory** | 4GB RAM minimum, 8GB recommended |
| **Storage** | ~500MB for app + Bible database |

### Technology Preferences

| Layer | Technology | Rationale |
|-------|------------|-----------|
| **UI Framework** | SwiftUI | Native macOS look and feel |
| **Language** | Swift 5.9+ | Modern, safe, performant |
| **Speech Recognition** | SFSpeechRecognizer + SFCustomLanguageModelData | Local-first, customisable |
| **Database** | SQLite (via GRDB.swift) | Lightweight, embedded |
| **Networking** | URLSession / async-await | Native, modern patterns |
| **Audio Capture** | AVAudioEngine | Low-latency capture |

### Architecture Considerations

```
┌─────────────────────────────────────────────────────────────┐
│                     Divine Link App                          │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ Audio Input  │→ │ Transcriber  │→ │  Detector    │       │
│  │   Manager    │  │  (Speech)    │  │  (Parsing)   │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│                                              ↓               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ ProPresenter │← │   Buffer     │← │    Bible     │       │
│  │   Client     │  │   Manager    │  │   Database   │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
├─────────────────────────────────────────────────────────────┤
│                      SwiftUI Views                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │  Menu Bar   │  │  Pending    │  │  Settings   │          │
│  │    Icon     │  │   Buffer    │  │   Panel     │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

### Integration Requirements

| Integration | Method | Notes |
|-------------|--------|-------|
| **ProPresenter** | HTTP API (v1/stage/message) | Requires PP 7.9+ |
| **System Audio** | BlackHole/Loopback | Third-party audio driver |
| **HelloAO API** | REST (initial DB population) | One-time or periodic sync |

### Security/Compliance

- All audio processing occurs locally (no cloud transmission)
- No user data collection beyond crash reports (opt-in)
- App Store distribution with standard sandboxing
- Microphone permission required (user-granted)

---

## Constraints & Assumptions

### Constraints

| Type | Constraint |
|------|------------|
| **Budget** | Bootstrap/self-funded; minimal external costs |
| **Timeline** | MVP within 6 months |
| **Resources** | Solo developer with design support |
| **Technical** | macOS-only for MVP; Apple Silicon priority |

### Key Assumptions

- ProPresenter 7.9+ Network API will remain stable and publicly available
- Apple's Speech framework will continue to support custom language models
- Churches have sufficient network connectivity between Divine Link and ProPresenter machines
- Media operators are willing to adopt a new tool if it reduces their workload
- Berean Standard Bible is acceptable as the initial/only translation
- BlackHole or similar audio routing is acceptable for system audio capture

---

## Risks & Open Questions

### Key Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| **Speech recognition accuracy varies by accent** | High | Medium | Fallback to cloud ASR option; user training on custom vocabulary |
| **ProPresenter API changes in future versions** | Medium | Low | Abstract integration layer; monitor PP release notes |
| **Apple deprecates/changes Speech framework** | High | Low | SpeechAnalyzer emerging as successor; maintain abstraction |
| **Latency exceeds 1 second threshold** | High | Low | Local-first architecture minimises; profiling and optimisation |
| **User adoption resistance** | Medium | Medium | Emphasise human control; free trial period |

### Open Questions

1. How will the app handle multiple preachers/speakers during a service?
2. Should we support split-screen display (scripture on one screen, stage notes on another)?
3. What's the best UX for verse disambiguation ("John" could be Gospel of John or 1/2/3 John)?
4. How do we handle verses that span multiple chapters?
5. Should keyboard shortcuts be global (system-wide) or app-focused?

### Areas Needing Further Research

1. **Audio routing solutions:** Evaluate BlackHole vs Loopback vs other options for system audio capture
2. **Verse reference patterns:** Compile comprehensive list of how preachers reference scriptures
3. **ProPresenter template design:** Best practices for scripture display templates
4. **Competitor analysis:** Deep dive into existing solutions (if any) for this specific use case

---

## Appendices

### A. Research Summary

Technical validation has been completed for three critical pillars:

1. **ProPresenter API:** `/v1/stage/message` endpoint confirmed for real-time text injection (PP 7.9+)
2. **macOS Speech Framework:** `SFCustomLanguageModelData` supports custom Bible vocabulary biasing
3. **Licensing:** Berean Standard Bible is Public Domain; HelloAO API is MIT licensed—both cleared for commercial use

Full research documentation: [docs/research/technical-validation.md](research/technical-validation.md)

### B. Stakeholder Input

Initial consultation conducted with Professor BMAD V6, establishing:
- Local-first hybrid ASR strategy
- Human-in-the-loop as non-negotiable requirement
- Trust as primary product differentiator

### C. References

- [ProPresenter API Documentation](https://github.com/jeffmikels/ProPresenter-API)
- [Apple Speech Framework](https://developer.apple.com/documentation/speech)
- [Berean Standard Bible](https://berean.bible)
- [HelloAO Bible API](https://bible.helloao.org)
- [BMAD Method Documentation](https://bmadcodes.com)

---

## Next Steps

### Immediate Actions

1. ✅ Complete technical validation research
2. ✅ Create project brief document
3. 🔄 Conduct technical challenge brainstorming session
4. ⏳ Transition to PM agent for PRD generation
5. ⏳ Create detailed technical architecture document
6. ⏳ Design UI/UX wireframes for Pending Buffer
7. ⏳ Set up development environment and repository

### PM Handoff

This Project Brief provides the full context for **Divine Link**. Please start in 'PRD Generation Mode', review the brief thoroughly to work with the user to create the PRD section by section as the template indicates, asking for any necessary clarification or suggesting improvements.

---

**Document Version:** 1.0  
**Created By:** Mary (BMAD Business Analyst)  
**Next Phase:** Planning (PRD with PM Agent)
