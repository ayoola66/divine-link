# Divine Link - Comprehensive Application Context

**Last Updated:** 5 February 2026  
**Version:** 1.3.0  
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

### 3.5 Pastor Profiles (Premium Feature)

- Save preferred Bible translations per pastor
- Store speech correction mappings (e.g., "Revelations" → "Revelation")
- Quick-switch between profiles during service
- Useful for churches with multiple speakers
- **Tier Limits:**
  - **Mercy (Free):** 0 profiles
  - **Grace (Premium):** Up to 2 profiles
  - **Love (Pro):** Up to 5 profiles

### 3.6 Session Management

- **Free tier:** 8 sessions per month
- **Paid tiers:** Unlimited sessions
- Session history and export (Pro tier only)

### 3.7 Detection Settings (Premium Feature)

- **Smart Context Detection:** Stateful reference buffer for partial verse detection
  - Remembers previous book/chapter context during sermon
  - "Verse 18" after "John 3:16" correctly resolves to "John 3:18"
  - Configurable context timeout (default: 5 minutes)
- **Confidence Display:** Visual confidence indicators for detected verses
- **Low Confidence Handling:** Options for how to handle uncertain detections
- **Premium Gating:** All detection settings require Grace or Love subscription

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
| Pastor profiles | 0 |
| Detection Settings (Smart Context, Confidence) | ✗ |

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
| Pastor profiles | 2 |
| Detection Settings (Smart Context, Confidence) | ✓ |
| Devices | 2 |
| Support | Email |

### Love (Pro)
**Price:** £19.99/month or £149.99/year (save 37%)

| Feature | Included |
|---------|----------|
| Everything in Grace | ✓ |
| Pastor profiles | 5 |
| Session history & export | ✓ |
| Speech corrections per pastor | ✓ |
| Implicit verse detection | ✓ |
| Auto-advance slideshow | ✓ |
| Devices | 5 |
| Support | Priority |
| Early access to features | ✓ |
| Church site licence option | ✓ |

### 4.1 Payment & Subscription Management

- **Payment Method:** Stripe (browser-based checkout)
  - Secure payment processing via Stripe Checkout
  - Opens in default browser for payment
  - No Apple App Store commission (15-30% savings)
  - Supports monthly and annual billing cycles
- **Subscription Management:**
  - Real-time subscription status sync via Supabase
  - Offline grace period (7 days) for connectivity issues
  - Device limits enforced per tier (Mercy: 1, Grace: 2, Love: 5)
  - Automatic feature gating based on subscription tier
- **Upgrade Flow:**
  - Premium features visible but disabled for free users
  - "Upgrade" buttons throughout the app
  - Modern PaywallView with tier comparison
  - Clear feature differentiation between Grace and Love tiers

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
| **Accessibility** | Simulate keyboard for Audience push | Grace/Love tiers, Same Machine setup only |

---

## 7. ProPresenter Configuration

### Setup: Same Machine vs. Two Machines

Before configuring the connection, choose the topology in Divine Link → Settings → ProPresenter → **ProPresenter Setup**:

- **Same Machine** (default, all tiers) — Divine Link and ProPresenter run on the same Mac. All three output paths are available: Stage Display, Messages API, and Keyboard Automation.
- **Two Machines** (Premium only) — for large events where ProPresenter runs on a separate laptop connected to the projector, and cabling between the two machines isn't practical. Keyboard Automation is **not offered** in this mode: it's local keystroke simulation (macOS Accessibility API) and is structurally incapable of reaching an app on a different Mac. Only Stage Display (HTTP) and the Messages API (WebSocket) are used — both are standard networked protocols and work reliably as long as both Macs share a network. A non-Premium user who selects Two Machines is shown the upgrade prompt and stays on Same Machine.

### Stage Screen Setup
1. Open ProPresenter → Preferences → Network
2. Enable "Network" and note the port (default: **50233** for ProPresenter 7)
3. In Divine Link, enter the ProPresenter IP and port — use `127.0.0.1` for Same Machine, or the other Mac's LAN IP for Two Machines
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

**Option B: Keyboard Automation (Free Tier / Fallback — Same Machine only)**
1. Confirm ProPresenter Setup is set to **Same Machine** (this option is hidden entirely in Two Machines mode — see above)
2. Grant Divine Link Accessibility permission in macOS Settings
3. Ensure ProPresenter is running on this Mac
4. Configure ProPresenter's Bible with your preferred translation
5. Divine Link will use ⌘B to trigger ProPresenter's Bible search

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

### Completed (Epic 7)
- ✅ Story 7.1: Reference Buffer (Stateful Detection)
  - Context-aware partial reference resolution
  - "Verse 18" after "John 3:16" resolves to "John 3:18"
  - Configurable context timeout
- ✅ Premium Paywall UX Upgrade
  - Detection Settings gated behind premium
  - Pastor profile limits enforced (0/2/5)
  - Modern PaywallView redesign with tier comparison
  - Stripe payment integration

### Pending / Roadmap

#### Love — Spoken Quote → Verse Matching (Story 7.2 evolved)
**Status:** Designed & approved (2026-08-06) — **not building yet**; parked on roadmap  
**Tier:** Love only (unique Pro differentiator)  
**Design:** [`docs/superpowers/specs/2026-08-06-quote-verse-matching-design.md`](docs/superpowers/specs/2026-08-06-quote-verse-matching-design.md)

Today the app only matches ~17 hard-coded famous quotes (e.g. John 3:16). The planned feature matches *any* spoken quote against the full local Bible corpus when enough consecutive words uniquely identify a verse.

| Phase | Scope | Notes |
|-------|--------|-------|
| **1** | Uniqueness-aware n-gram index + FTS5 verify; verse cards with % confidence; never auto-push to ProPresenter; Love Settings + website copy | Approved approach |
| **2** | On-device embeddings for paraphrase | After Phase 1 |
| **3** | Anaphora (“the verse we just read”) via context / MLX | Completes original Story 7.2 LLM vision |

**Product rules (locked):** Love-only · card + confidence % · green ≥ 90% · prefer 7–8 words · short unique verses allowed (e.g. “Jesus wept”) · never auto-push.

#### Other pending
- ⏳ Session History & Export (Love)
- ⏳ Auto-advance Slideshow Mode
- ⏳ UI redesign v2.0.0 — see `REDESIGN-SPEC-v2.0.0.md`

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
| 1.2.0 | Feb 2026 | Panic button, confidence indicators, WebSocket Messages API |
| 1.3.0 | Feb 2026 | Reference Buffer (stateful detection), Premium paywall UX, Detection Settings gating |

---

*This document serves as the authoritative reference for Divine Link functionality. It should be updated as new features are added.*
