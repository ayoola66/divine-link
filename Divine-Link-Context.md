# Divine Link - Comprehensive Application Context

**Last Updated:** 17 January 2026  
**Version:** 1.1.0  
**Status:** Active Development  
**Platform:** macOS 13.0+

---

## 1. What Divine Link Is

**Divine Link is a macOS application that automatically detects Bible verse references spoken during live preaching and enables operators to display those scriptures on screen via ProPresenter.**

### Core Purpose
Divine Link solves a common problem in church media operations: when a pastor mentions a Bible verse during a sermon, the media team must quickly find and display that scripture. Divine Link automates the detection process, reducing stress and improving accuracy.

### What Divine Link Does
1. **Listens** to audio input (microphone or system audio)
2. **Transcribes** speech to text in real-time using macOS Speech Recognition
3. **Detects** Bible verse references within the transcribed text
4. **Fetches** the actual verse text from a local Bible database
5. **Displays** detected verses in a pending buffer for operator review
6. **Pushes** approved verses to ProPresenter for display on screens

### What Divine Link Is NOT
- **NOT a worship lyric app** — It does not handle song lyrics or worship slides
- **NOT automatic display** — It requires human confirmation before displaying (Human-in-the-Loop)
- **NOT a Bible reading app** — It specifically detects verses mentioned during preaching
- **NOT a replacement for ProPresenter** — It works alongside ProPresenter as a detection/push tool

---

## 2. Target Users

| Role | How They Use Divine Link |
|------|--------------------------|
| **Media Operators** | Primary users who run the app during services, confirm detected verses, and push to display |
| **Technical Directors** | Set up the integration with ProPresenter and configure settings |
| **Church Leadership** | Benefit from improved scripture display without additional volunteer training |

---

## 3. Key Features

### 3.1 Scripture Detection Engine

**Supported Detection Formats:**

| Format Type | Example | Detection Pattern |
|-------------|---------|-------------------|
| Standard | "John 3:16" | `Book Chapter:Verse` |
| Verbal | "John chapter 3 verse 16" | Spoken format with keywords |
| Spoken Numbers | "John three sixteen" | Word-based numbers |
| Verse Ranges | "John 3:16-18" or "John 3:16 to 18" | Multiple verses |
| Chapter Only | "John chapter 3" | Chapter reference without verse |
| Implicit | "that same verse" | Context-based detection (Pro tier) |

**Detection Algorithm:**
- Uses regex pattern matching with book name normalisation
- Fuzzy matching for book names (handles "Revelations" → "Revelation")
- Filters out false positives (common words like "to", "the", "you")
- Confidence scoring for match quality

### 3.2 Bible Database

- **Local SQLite database** — No internet required for verse lookup
- **Default translation:** KJV (Free tier)
- **Additional translations (Paid):** ESV, NIV, NASB, NLT, NKJV, and more
- **Complete canon:** All 66 books, 1,189 chapters, 31,102 verses

### 3.3 ProPresenter Integration

**Stage Screen (Stage Display API):**
- Uses ProPresenter's REST API at `/v1/stage/message`
- Sends text directly to the Stage Display
- Configurable port (default: 1025)
- Useful for confidence monitor / pastor reference

**Audience Screen (Two Methods):**

**Method 1: Messages API (Premium/Pro Tiers)** ✅ **RECOMMENDED**
- Uses ProPresenter's Messages API via WebSocket
- Sends templated content to Messages layer
- Messages layer routed to Audience screen via Looks feature
- Requires one-time setup: Enable Messages layer in Audience Look
- Faster (~50ms), more reliable, works in background
- Uses church's configured Message themes

**Method 2: Keyboard Automation (Free Tier / Fallback)**
- Uses macOS Accessibility to simulate keyboard input
- Triggers ProPresenter's native Bible feature (⌘B)
- Types the scripture reference and presses Enter
- Displays verse using ProPresenter's own Bible formatting
- Zero configuration required

### 3.4 Multi-Verse Handling

When a verse range is detected (e.g., "John 3:16-18"):
- All verses in the range are fetched and displayed
- Operator can navigate between verses (◀ ▶ buttons)
- **Push One:** Send only the currently selected verse
- **Push All:** Send all verses at once
- Current verse is highlighted in the interface

### 3.5 Pastor Profiles (Pro Tier)

- Save preferred Bible translations per pastor
- Store speech correction mappings (e.g., "Revelations" → "Revelation")
- Quick-switch between profiles during service
- Useful for churches with multiple speakers

### 3.6 Session Management

- **Free tier:** 8 sessions per month
- **Paid tiers:** Unlimited sessions
- Session history and export (Pro tier only)

---

## 4. Subscription Tiers

### Mercy (Free)
**Price:** £0/forever

| Feature | Included |
|---------|----------|
| Live speech detection | ✓ |
| Full detection algorithm | ✓ |
| KJV translation | ✓ |
| Push to Stage Screen | ✓ |
| Multi-verse display | ✓ |
| Sessions per month | 8 |
| Detections per session | Unlimited |
| Sidebar advertisements | Yes |
| Push to Audience Screen (Keyboard) | ✗ |
| Additional translations | ✗ |
| Pastor profiles | ✗ |

### Grace (Premium)
**Price:** £9.99/month or £79.99/year (save 33%)

| Feature | Included |
|---------|----------|
| Everything in Mercy | ✓ |
| No advertisements | ✓ |
| Push to Audience Screen (Messages API) | ✓ |
| All Bible translations | ✓ |
| Unlimited sessions | ✓ |
| Verse-by-verse push | ✓ |
| Verse navigation controls | ✓ |
| Devices | 2 |
| Support | Email |

### Love (Pro)
**Price:** £19.99/month or £149.99/year (save 37%)

| Feature | Included |
|---------|----------|
| Everything in Grace | ✓ |
| Pastor profiles | ✓ |
| Session history & export | ✓ |
| Speech corrections per pastor | ✓ |
| Implicit verse detection | ✓ |
| Auto-advance slideshow | ✓ |
| Devices | 3 |
| Support | Priority |
| Early access to features | ✓ |
| Church site licence option | ✓ |

---

## 5. Technical Architecture

### 5.1 Core Components

```
Divine Link/
├── Features/
│   ├── AudioCapture/          # Microphone input handling
│   │   ├── AudioCaptureManager.swift
│   │   └── AudioInputSelector.swift
│   ├── Transcription/         # Speech-to-text
│   │   ├── TranscriptionEngine.swift
│   │   └── SpeechRecognitionService.swift
│   ├── Detection/             # Scripture detection
│   │   ├── ScriptureDetectorService.swift
│   │   ├── DetectionPipeline.swift
│   │   ├── BookNameNormaliser.swift
│   │   └── ImplicitReferenceDetector.swift
│   ├── Bible/                 # Verse database
│   │   └── BibleService.swift
│   ├── PendingBuffer/         # Detected verse queue
│   │   └── BufferManager.swift
│   └── ProPresenter/          # PP integration
│       ├── ProPresenterClient.swift
│       ├── KeyboardAutomationService.swift
│       └── ProPresenterSettings.swift
├── Services/
│   ├── SubscriptionService.swift
│   ├── AuthService.swift
│   └── DynamicAdService.swift
└── App/
    ├── DivineLink.swift       # App entry point
    └── MainView.swift         # Primary UI
```

### 5.2 Data Flow

```
[Microphone] 
    ↓
[AudioCaptureManager] captures audio stream
    ↓
[TranscriptionEngine] converts speech to text
    ↓
[ScriptureDetectorService] identifies verse references
    ↓
[BibleService] fetches verse text from SQLite
    ↓
[BufferManager] queues verse for operator review
    ↓
[MainView] displays pending verse with push buttons
    ↓
[ProPresenterClient] sends to Stage/Audience screen
```

### 5.3 Key Classes

| Class | Responsibility |
|-------|----------------|
| `ScriptureDetectorService` | Regex-based detection of Bible references |
| `BookNameNormaliser` | Normalises book names (handles variations, typos) |
| `BibleService` | SQLite queries for verse text |
| `BufferManager` | Manages pending verses queue |
| `ProPresenterClient` | REST API calls to ProPresenter |
| `KeyboardAutomationService` | Simulates keyboard for Audience screen (Free tier) |
| `MessagesService` | Sends scripture via Messages API (Premium tier) |
| `DetectionPipeline` | Orchestrates the full detection workflow |

---

## 6. Required Permissions

Divine Link requires the following macOS permissions:

| Permission | Purpose | Required For |
|------------|---------|--------------|
| **Microphone** | Capture audio for speech recognition | All tiers |
| **Speech Recognition** | Convert speech to text | All tiers |
| **Accessibility** | Simulate keyboard for Audience push | Grace/Love tiers |

---

## 7. ProPresenter Configuration

### Stage Screen Setup
1. Open ProPresenter → Preferences → Network
2. Enable "Network" and note the port (default: 1025)
3. In Divine Link, enter the ProPresenter IP and port
4. Test connection using the "Test Connection" button

### Audience Screen Setup

**Option A: Messages API (Premium/Pro Tiers)** ✅ **RECOMMENDED**
1. Open ProPresenter → Screens → Edit Looks
2. Select your Audience Look preset (or create new)
3. Enable "Messages" layer checkbox for Audience screen(s)
4. Configure a Message template with placeholders:
   - `${ScriptureText}` for verse text
   - `${Reference}` for scripture reference
5. Apply your preferred theme/styling to the Message template
6. Save the Look preset
7. In Divine Link, verify Messages layer is detected
8. Divine Link will use Messages API automatically

**Option B: Keyboard Automation (Free Tier / Fallback)**
1. Grant Divine Link Accessibility permission in macOS Settings
2. Ensure ProPresenter is running
3. Configure ProPresenter's Bible with your preferred translation
4. Divine Link will use ⌘B to trigger ProPresenter's Bible search

---

## 8. Common Detection Patterns

The detector handles various ways pastors reference scripture:

| Spoken Phrase | Detected As |
|--------------|-------------|
| "John 3:16" | John 3:16 |
| "John chapter 3 verse 16" | John 3:16 |
| "John three sixteen" | John 3:16 |
| "First John 3:16" | 1 John 3:16 |
| "Romans 8:28 through 30" | Romans 8:28-30 |
| "Turn to the book of Psalms chapter 23" | Psalm 23 |
| "The gospel of Matthew 5:1 to 12" | Matthew 5:1-12 |

---

## 9. Advertising (Free Tier)

The free tier (Mercy) displays sidebar advertisements to support ongoing development:

- Ads appear in a designated sidebar area
- Ads do not interrupt the detection workflow
- Anonymous ad metrics are collected (impressions, clicks)
- No personal data is shared with advertisers
- Upgrade to Grace or Love tier for ad-free experience

---

## 10. Development Roadmap

### Completed (Epic 6)
- ✅ Story 6.1: Enhanced Scripture Detection Patterns
- ✅ Story 6.2: Verse Navigation & Push Controls
- ✅ Story 6.3: Stage Screen Integration (REST API)
- ✅ Story 6.4: Stage Screen Integration (REST API)
- ✅ Story 6.5: Audience Screen Integration (Messages API) - Research Complete

### Pending
- ⏳ Story 6.5: ProPresenter Messages API Implementation (Research Complete ✅)
- ⏳ Pastor Profile Management
- ⏳ Session History & Export
- ⏳ Implicit Verse Detection (AI-powered)
- ⏳ Auto-advance Slideshow Mode

---

## 11. Troubleshooting

### Detection Issues
- **Verse not detected:** Check that the book name is spoken clearly
- **Wrong verse:** Review the transcription for mishearings
- **Duplicate verses:** Database deduplication should prevent this; report if seen

### ProPresenter Connection
- **Connection failed:** Verify IP address and port, ensure PP is running
- **Stage push not working:** Check that Stage Display is configured in PP
- **Audience push not working (Messages API):** Enable Messages layer in Audience Look preset
- **Audience push not working (Keyboard):** Grant Accessibility permission to Divine Link

### Permissions
- **Microphone denied:** Go to System Settings → Privacy & Security → Microphone
- **Accessibility denied:** Go to System Settings → Privacy & Security → Accessibility

---

## 12. Contact & Support

- **Website:** https://divinelink.netlify.app
- **Email:** support@orekunmedia.com
- **Privacy:** privacy@orekunmedia.com

---

## 13. Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Jan 2026 | Initial release with core detection |
| 1.0.2 | Jan 2026 | Bug fixes, improved book matching |
| 1.1.0 | Jan 2026 | Audience screen integration, multi-verse navigation |

---

*This document serves as the authoritative reference for Divine Link functionality. It should be updated as new features are added.*
