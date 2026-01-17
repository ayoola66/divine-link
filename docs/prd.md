# Divine Link - Product Requirements Document (PRD)

**Document Type:** Product Requirements Document  
**Version:** 1.0  
**Date:** January 2026  
**Author:** John (BMAD Product Manager)  
**Status:** Approved for Development

---

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| January 2026 | 1.0 | Initial PRD from Project Brief | John (PM) |

---

## 1. Goals and Background Context

### 1.1 Goals

- **Capture >95% of explicit scripture references** during live sermons through real-time speech detection and verse queueing
- **Reduce operator workflow from 4 steps to 1** by automating listen-identify-search to a simple approve-or-dismiss action
- **Achieve <1 second latency** from spoken verse reference to pending buffer display using local-first processing
- **Ensure 100% human-in-the-loop compliance** with mandatory operator approval before any scripture appears on screen
- **Deliver £0 variable costs per service** by prioritising on-device processing over cloud API dependencies
- **Support ProPresenter 7.9+ out of the box** via the Network API `/v1/stage/message` endpoint

### 1.2 Background Context

Church media operators face an increasingly demanding role—managing lyrics, announcements, cameras, and scripture display simultaneously during live services. When a preacher references a Bible verse, operators must: (1) listen carefully, (2) identify the reference, (3) search a Bible database, and (4) display the verse. Studies of operator behaviour suggest 30-50% of spontaneous scripture references are missed entirely, and those that are caught often appear 15-30 seconds late—after the preacher has moved on.

Existing solutions fall short: cloud-based transcription services introduce 2-5 second latency and ongoing costs; manual hotkey systems still require operators to identify and search for verses; pre-loaded sermon notes fail when preachers deviate from their scripts.

Divine Link addresses this gap by creating an intelligent listening layer between the preacher and ProPresenter. Using Apple's native Speech framework with custom vocabulary biasing (`SFCustomLanguageModelData`) for Bible terminology, the application transcribes sermon audio in real-time, detects scripture references through layered pattern matching, and queues them for operator approval. This human-in-the-loop approach ensures trust remains paramount—no verse appears on screen without explicit confirmation—while dramatically reducing cognitive burden.

The technical foundation has been validated: ProPresenter's `/v1/stage/message` API supports real-time text injection, Apple's Speech framework enables biasing toward the 66 Bible book names, and the Berean Standard Bible (Public Domain since April 2023) provides a legally safe text source for commercial deployment.

**Known Constraints:** MVP targets explicit scripture references only (e.g., "John 3:16", "turn to Romans chapter 8"); implicit references ("the love chapter") require NLP capabilities planned for Phase 2. Detection accuracy targets >95% for standard accents; a cloud fallback option addresses accent variation in future versions. Single-platform (macOS) for MVP aligns with the local-first strategy using Apple's Speech framework.

---

## 2. Requirements

### 2.1 Functional Requirements

| ID | Requirement |
|----|-------------|
| **FR1** | The application shall capture audio from user-selected input sources (system audio via BlackHole/Loopback, or microphone). |
| **FR2** | The application shall provide real-time audio level monitoring to confirm audio capture is functioning. |
| **FR3** | The application shall transcribe captured audio to text in real-time using macOS native Speech framework. |
| **FR4** | The application shall apply a custom language model biased toward the 66 Bible book names and common theological terms to improve transcription accuracy. |
| **FR5** | The application shall detect explicit scripture references in transcribed text using pattern matching (e.g., "John 3:16", "Romans chapter 8 verse 28", "First Corinthians 13"). |
| **FR6** | The application shall support detection of verse ranges (e.g., "John 3:16-18", "Romans 8:28 through 39"). |
| **FR7** | The application shall normalise book name variations to canonical names (e.g., "Revelations" → "Revelation", "1st Corinthians" → "1 Corinthians"). |
| **FR8** | The application shall retrieve full verse text from a local SQLite database containing the Berean Standard Bible. |
| **FR9** | The application shall display detected verses in a "Pending Buffer" UI showing verse reference, full text preview, and confidence indicator. |
| **FR10** | The application shall allow the operator to approve a pending verse via click or configurable hotkey, triggering push to ProPresenter. |
| **FR11** | The application shall allow the operator to dismiss/ignore a pending verse via click or hotkey. |
| **FR12** | The application shall connect to ProPresenter 7.9+ via HTTP Network API using user-configured IP address and port. |
| **FR13** | The application shall push approved scripture text to ProPresenter using the `/v1/stage/message` endpoint. |
| **FR14** | The application shall provide visual feedback on ProPresenter connection status (connected, disconnected, error). |
| **FR15** | The application shall run as a macOS menu bar application with quick access to pending buffer and settings. |
| **FR16** | The application shall provide a Settings panel for configuring audio input, ProPresenter connection, and hotkeys. |
| **FR17** | The application shall persist user settings between sessions. |

### 2.2 Non-Functional Requirements

| ID | Requirement |
|----|-------------|
| **NFR1** | The application shall achieve <1 second latency from spoken scripture reference to pending buffer display. |
| **NFR2** | The application shall detect >95% of explicit scripture references with standard accent English speech. |
| **NFR3** | The application shall maintain <5% false positive rate for scripture detection. |
| **NFR4** | The application shall operate continuously for 120+ minutes without memory leaks, crashes, or performance degradation. |
| **NFR5** | The application shall consume <500MB RAM during normal operation. |
| **NFR6** | The application shall require macOS 14 (Sonoma) or later. |
| **NFR7** | The application shall support Apple Silicon (M1/M2/M3) and Intel-based Macs. |
| **NFR8** | The application shall perform all speech recognition locally without transmitting audio to external servers (MVP). |
| **NFR9** | The application shall handle network disconnection to ProPresenter gracefully with automatic reconnection attempts. |
| **NFR10** | The application shall provide clear error messages and recovery guidance when issues occur. |
| **NFR11** | The application shall be distributed as a signed and notarised DMG for direct download. |
| **NFR12** | The application shall include no recurring API costs for core functionality (local-first mandate). |

---

## 3. User Interface Design Goals

> Full UI specification available in [docs/ui-specification.md](ui-specification.md)

### 3.1 Overall UI Philosophy

- **Single-window application** - No modal dialogs or floating panels during operation
- **No nested menus during live use** - Every action is one click or keystroke away
- **Everything visible at a glance** - Operator never hunts for information
- **Designed for live pressure environments** - Calm, predictable, zero surprises

> **Think: mission control, not creative software.**

### 3.2 Layout Structure

```
┌─────────────────────────────────────────────────────────────────┐
│  [Logo]          STATUS: Listening              [⚙️ Settings]   │  ← Header
├─────────────────────────────────────────────────────────────────┤
│  Live transcription text (greyed, scrolling)                    │  ← Zone 1
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  DETECTED SCRIPTURE (PENDING)                            │   │  ← Zone 2
│  │  📖 Romans 8:28                                          │   │
│  │  "And we know that in all things God works..."           │   │
│  └─────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│   [▶ PUSH TO PROPRESENTER]    [✕ IGNORE]    [⏸ PAUSE]         │  ← Zone 3
└─────────────────────────────────────────────────────────────────┘
```

### 3.3 Operator Control Rules (Non-Negotiable)

1. **Never override the operator** - The app suggests; the human decides
2. **Never auto-display scripture** - All pushes require explicit approval
3. **Manual ProPresenter use must always remain possible** - Divine Link is additive, not exclusive

### 3.4 What NOT to Build

- ❌ Slide editor
- ❌ AI configuration panels
- ❌ Multi-tab complexity
- ❌ Flashy animations
- ❌ Hidden automation
- ❌ Auto-push mode

---

## 4. Technical Assumptions

> Full technical decisions available in [docs/technical-decisions.md](technical-decisions.md)

### 4.1 Technology Stack

| Layer | Technology |
|-------|------------|
| **Language** | Swift 5.9+ |
| **UI Framework** | SwiftUI |
| **Speech** | SFSpeechRecognizer + SFCustomLanguageModelData |
| **Audio** | AVAudioEngine |
| **Database** | SQLite via GRDB.swift |
| **Networking** | URLSession (async/await) |
| **Updates** | Sparkle framework |

### 4.2 Distribution Strategy

| Aspect | MVP Decision |
|--------|--------------|
| **Primary** | Direct download (signed DMG) |
| **Code Signing** | Developer ID + Notarisation |
| **Auto-Updates** | Sparkle framework |
| **App Store** | Future enhancement |

### 4.3 Audio Capture Strategy

| Aspect | MVP Decision |
|--------|--------------|
| **Primary Input** | System microphone (works out of box) |
| **Secondary Input** | BlackHole (user-installed, guided setup) |
| **BlackHole Bundling** | Not bundled (GPL licence); guided installation |

### 4.4 Repository Structure

```
divine-link/
├── DivineLink/                 # Main app target
│   ├── App/                    # App entry, main views
│   ├── Features/               # Feature modules
│   ├── Core/                   # Shared utilities
│   ├── Models/                 # Data models
│   └── Resources/              # Assets, Bible.db
├── Tests/
├── docs/
└── scripts/
```

---

## 5. Epic List

| Epic | Title | Goal |
|------|-------|------|
| **Epic 1** | Foundation & Audio Capture | Establish project infrastructure and deliver a working menu bar app that captures and monitors audio input |
| **Epic 2** | Transcription & Scripture Detection | Implement real-time speech-to-text with Bible vocabulary biasing and pattern-based scripture detection |
| **Epic 3** | Pending Buffer & ProPresenter Integration | Build the operator workflow UI and complete the integration with ProPresenter's Network API |

---

## 6. Epic Details

### Epic 1: Foundation & Audio Capture

**Goal:** Establish project infrastructure and deliver a working menu bar app that captures and monitors audio input.

**Delivered Value:** A functional macOS menu bar application that runs in the menu bar, captures audio from user-selected input, and displays real-time audio level monitoring.

---

#### Story 1.1: Project Scaffolding & Menu Bar App Shell

**As a** developer,  
**I want** a properly configured Xcode project with a menu bar app shell,  
**so that** I have a solid foundation for building Divine Link features.

**Acceptance Criteria:**
1. Xcode project created with SwiftUI lifecycle and macOS 14+ deployment target
2. App runs as a menu bar application (no Dock icon)
3. Menu bar displays a simple icon (placeholder) with status indicator
4. Clicking menu bar icon opens a popover/window with placeholder content
5. App includes "Quit" menu item that terminates the application
6. Project structure follows the agreed folder organisation
7. `.gitignore` configured for Xcode/Swift projects
8. README.md created with basic project description
9. App is code-signed for local development

---

#### Story 1.2: Audio Input Device Selection

**As an** operator,  
**I want** to select which audio input device Divine Link listens to,  
**so that** I can choose between my microphone or system audio (BlackHole).

**Acceptance Criteria:**
1. Settings panel lists all available audio input devices
2. User can select an input device from the list
3. Selected device is persisted between app launches
4. If previously selected device is unavailable, app falls back to default input
5. App displays friendly device names
6. If BlackHole is not installed, a help link explains how to install it
7. Settings accessible via menu bar icon → Settings (⌘,)

---

#### Story 1.3: Audio Capture Engine

**As a** developer,  
**I want** a service that captures audio from the selected input device,  
**so that** audio data is available for transcription.

**Acceptance Criteria:**
1. `AudioCaptureService` class created using AVAudioEngine
2. Service starts/stops audio capture on demand
3. Service uses the user-selected input device
4. Audio is captured in a format compatible with SFSpeechRecognizer
5. Service handles device disconnection gracefully
6. Service exposes audio buffer for downstream consumers
7. Memory is managed properly during extended capture

---

#### Story 1.4: Audio Level Monitoring UI

**As an** operator,  
**I want** to see a visual indicator that audio is being captured,  
**so that** I have confidence the app is listening.

**Acceptance Criteria:**
1. Main window displays real-time audio level indicator
2. Indicator shows relative volume
3. Indicator updates smoothly (minimum 10fps)
4. When no audio is detected, indicator shows minimal/zero level
5. When audio is present, indicator responds proportionally
6. Indicator uses calm blue colour per UI specification
7. Indicator has subtle pulse animation when in "Listening" state

---

#### Story 1.5: Listening State Management

**As an** operator,  
**I want** to pause and resume listening,  
**so that** I can control when Divine Link is active.

**Acceptance Criteria:**
1. Pause button visible in main window
2. Pressing Pause (or Space) stops audio capture
3. UI transitions to "Paused" state (muted grey)
4. Status text in header updates to "Paused"
5. Pressing Resume (or Space again) restarts audio capture
6. UI transitions back to "Listening" state
7. Pause state is NOT persisted between app launches

---

### Epic 2: Transcription & Scripture Detection

**Goal:** Implement real-time speech-to-text with Bible vocabulary biasing and pattern-based scripture detection.

**Delivered Value:** The app transcribes speech in real-time, detects explicit scripture references, and looks up verse text from a local Bible database.

---

#### Story 2.1: Bible Database Setup

**As a** developer,  
**I want** a local SQLite database containing the Berean Standard Bible,  
**so that** detected scripture references can be resolved to full verse text.

**Acceptance Criteria:**
1. SQLite database file (`Bible.db`) created with BSB text
2. Database schema includes tables: `books`, `verses`
3. `books` table contains 66 entries with canonical names and aliases
4. `verses` table contains all verses with book_id, chapter, verse, text
5. Database is embedded in app bundle
6. `BibleService` class provides verse lookup by reference
7. Lookup returns verse text or nil if not found
8. Service handles edge cases (invalid chapter/verse numbers)

---

#### Story 2.2: Speech Recognition Service

**As a** developer,  
**I want** a service that transcribes audio to text using Apple's Speech framework,  
**so that** spoken words can be analysed for scripture references.

**Acceptance Criteria:**
1. `TranscriptionService` class created using SFSpeechRecognizer
2. Service requests and handles microphone/speech recognition permissions
3. Service receives audio buffer from AudioCaptureService
4. Service produces streaming transcription results (partial and final)
5. Transcription uses British English locale (en-GB)
6. Service handles recognition errors gracefully
7. Service can be started/stopped on demand
8. Memory is managed properly during extended operation

---

#### Story 2.3: Custom Language Model for Bible Vocabulary

**As a** developer,  
**I want** speech recognition biased toward Bible book names and theological terms,  
**so that** "Habakkuk" is recognised correctly instead of "have a cook".

**Acceptance Criteria:**
1. Custom language model created using SFCustomLanguageModelData
2. Model includes all 66 Bible book names with high phrase counts
3. Model includes common variations (1 Corinthians, First Corinthians, I Corinthians)
4. Model includes custom pronunciations for difficult names
5. Model exported and compiled at app first launch
6. TranscriptionService uses custom language model configuration
7. Model file stored in Application Support directory
8. Fallback to standard recognition if custom model fails

---

#### Story 2.4: Listening Feed UI

**As an** operator,  
**I want** to see a live transcript of what's being said,  
**so that** I have confidence the app is hearing correctly.

**Acceptance Criteria:**
1. Zone 1 (top) displays scrolling transcript text
2. Text is greyed and non-editable
3. New text appears at bottom, auto-scrolls
4. Transcript shows last ~500 characters (rolling buffer)
5. When paused, transcript stops updating
6. Transcript clears when listening resumes
7. Font uses SF Mono 13pt per UI spec

---

#### Story 2.5: Scripture Reference Detection Engine

**As a** developer,  
**I want** a service that detects scripture references in transcript text,  
**so that** detected verses can be queued for operator approval.

**Acceptance Criteria:**
1. `ScriptureDetectorService` class created
2. Service accepts transcript text and returns detected references
3. Detects standard formats: "John 3:16", "Romans 8:28-30"
4. Detects verbal formats: "John chapter 3 verse 16"
5. Detects book-only with chapter: "Romans 8", "Genesis 1"
6. Normalises book names: "Revelations" → "Revelation"
7. Handles numbered books: "1 Corinthians", "First John", "I Peter"
8. Returns structured reference object
9. Ignores duplicate detections within short time window

---

#### Story 2.6: Detection Pipeline Integration

**As a** developer,  
**I want** the transcription and detection services connected,  
**so that** detected scriptures flow to the pending buffer.

**Acceptance Criteria:**
1. TranscriptionService output feeds into ScriptureDetectorService
2. Detected references trigger BibleService lookup
3. Successful lookups create PendingVerse objects
4. PendingVerse includes: reference, fullText, timestamp, confidence
5. PendingVerse objects are added to BufferManager
6. Pipeline handles rapid successive detections
7. Pipeline logs detections for debugging

---

### Epic 3: Pending Buffer & ProPresenter Integration

**Goal:** Build the operator workflow UI and complete the integration with ProPresenter's Network API.

**Delivered Value:** Complete MVP—operators see detected verses, approve or dismiss them, and approved verses push to ProPresenter.

---

#### Story 3.1: Pending Buffer Data Model

**As a** developer,  
**I want** a buffer manager that holds pending scripture detections,  
**so that** the UI can display and the operator can act on them.

**Acceptance Criteria:**
1. `BufferManager` class created as ObservableObject
2. Manages queue of PendingVerse objects
3. Supports add, remove, clear operations
4. Exposes current pending verse for UI
5. Limits queue size (max 10 pending verses)
6. Older verses auto-expire after 60 seconds
7. Publishes changes for SwiftUI binding

---

#### Story 3.2: Pending Scripture Card UI

**As an** operator,  
**I want** to see the detected scripture displayed clearly,  
**so that** I can verify it before pushing to the screen.

**Acceptance Criteria:**
1. Zone 2 (centre) displays pending scripture card
2. Card shows: book, chapter, verse(s), full text, translation name
3. Card has off-white background with blue scripture text
4. Card shows "Detected Scripture (Pending)" label
5. When no verse pending, zone shows empty state
6. Card has gold accent border when verse is pending
7. Card displays confidence indicator

---

#### Story 3.3: Operator Action Buttons

**As an** operator,  
**I want** clear buttons to push or ignore a pending verse,  
**so that** I control what appears on the main screen.

**Acceptance Criteria:**
1. Zone 3 displays action buttons per UI spec
2. "Push to ProPresenter" button with gold accent
3. "Ignore" button with neutral styling
4. "Pause" button with grey styling
5. Buttons are large and touch-friendly
6. Keyboard shortcuts displayed on buttons
7. Buttons disabled when no verse pending
8. Button states update reactively

---

#### Story 3.4: Keyboard Shortcut Handling

**As an** operator,  
**I want** to use keyboard shortcuts for all actions,  
**so that** I can work quickly without using the mouse.

**Acceptance Criteria:**
1. Enter key triggers "Push to ProPresenter"
2. Escape key triggers "Ignore/Clear"
3. Space key toggles Pause/Resume
4. ⌘+, opens Settings
5. ⌘+Q quits application
6. Shortcuts work when main window is focused
7. Shortcuts are global when app is frontmost

---

#### Story 3.5: ProPresenter Connection Settings

**As an** operator,  
**I want** to configure the ProPresenter connection,  
**so that** Divine Link can communicate with my ProPresenter instance.

**Acceptance Criteria:**
1. Settings panel includes ProPresenter section
2. User can enter ProPresenter IP address
3. User can enter port number (default: 1025)
4. "Test Connection" button verifies connectivity
5. Connection status displayed
6. Settings persisted between app launches
7. Invalid IP/port shows validation error

---

#### Story 3.6: ProPresenter API Client

**As a** developer,  
**I want** a client that communicates with ProPresenter's Network API,  
**so that** approved scriptures can be displayed on stage screens.

**Acceptance Criteria:**
1. `ProPresenterClient` class created
2. Client connects to ProPresenter at configured IP:port
3. Client implements `PUT /v1/stage/message` endpoint
4. Client handles connection errors gracefully
5. Client supports automatic reconnection on failure
6. Client exposes connection status as published property
7. Client uses async/await for network operations

---

#### Story 3.7: Push to ProPresenter Action

**As an** operator,  
**I want** approved verses to appear on the ProPresenter stage screen,  
**so that** the congregation can see the scripture.

**Acceptance Criteria:**
1. Pressing "Push" sends verse to ProPresenter
2. Message format: "{Book} {Chapter}:{Verse}\n{Full Text}"
3. Multi-line text supported
4. Success removes verse from pending buffer
5. Failure shows error message in UI
6. UI shows brief success indicator
7. Next pending verse (if any) becomes active

---

#### Story 3.8: Connection Status Header

**As an** operator,  
**I want** to see the ProPresenter connection status,  
**so that** I know if pushes will work.

**Acceptance Criteria:**
1. Header bar shows connection status icon
2. Connected: Green dot or checkmark
3. Disconnected: Red dot or warning icon
4. Reconnecting: Amber/pulsing indicator
5. Hovering shows tooltip with details
6. Status updates in real-time

---

#### Story 3.9: Settings Panel Polish

**As an** operator,  
**I want** a clean, simple settings panel,  
**so that** I can configure the app without confusion.

**Acceptance Criteria:**
1. Settings opens in separate window or sheet
2. Sections: Audio Input, ProPresenter Connection
3. Clean layout with appropriate spacing
4. Close button or standard window controls
5. Changes apply immediately
6. Settings window closable with Escape key

---

## 7. MVP Story Summary

| Epic | Stories | Focus |
|------|---------|-------|
| Epic 1 | 5 | Foundation & Audio |
| Epic 2 | 6 | Transcription & Detection |
| Epic 3 | 9 | UI & ProPresenter |
| **Total** | **20** | **Complete MVP** |

---

## 8. Next Steps

### 8.1 UX Expert Prompt

> Review the UI Specification (`docs/ui-specification.md`) and PRD to create detailed wireframes and visual designs for Divine Link. Focus on the three-zone layout, state transitions, and the "mission control" aesthetic appropriate for live pressure environments.

### 8.2 Architect Prompt

> Review this PRD and technical decisions (`docs/technical-decisions.md`) to create the detailed technical architecture document. Define the module structure, service interfaces, data flow, and implementation approach for each epic. Ensure the architecture supports <1 second latency and 2+ hour continuous operation.

---

## Appendices

### A. Related Documents

- [Project Brief](brief.md) - Initial project scope and context
- [UI Specification](ui-specification.md) - Detailed UI/UX specification
- [Technical Decisions](technical-decisions.md) - Technology stack and distribution strategy
- [Technical Validation](research/technical-validation.md) - API and platform research
- [Technical Challenges](research/technical-challenges.md) - Risk analysis and mitigations

### B. References

- [ProPresenter Network API](https://github.com/jeffmikels/ProPresenter-API)
- [Apple Speech Framework](https://developer.apple.com/documentation/speech)
- [Berean Standard Bible](https://berean.bible)
- [HelloAO Bible API](https://bible.helloao.org)
- [BlackHole Audio Driver](https://github.com/ExistentialAudio/BlackHole)

---

**Document Version:** 1.0  
**Created By:** John (BMAD Product Manager)  
**Approved By:** coachAOG  
**Next Phase:** Architecture & Design
