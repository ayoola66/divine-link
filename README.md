# Divine Link

**Version 1.6.2** | [Changelog](CHANGELOG.md) | [Feature Matrix](docs/FEATURE-MATRIX.md) | [Full Context](Divine-Link-Context.md)

**Real-time Scripture Detection & ProPresenter Integration for macOS**

Divine Link listens to live speech (sermons, Bible studies, etc.) and automatically detects scripture references, making them instantly available to push to ProPresenter for display.

---

## Table of Contents

1. [Overview](#overview)
2. [Features](#features)
3. [Requirements](#requirements)
4. [Installation](#installation)
5. [Configuration](#configuration)
6. [Usage](#usage)
7. [ProPresenter Integration](#propresenter-integration)
8. [Architecture](#architecture)
9. [Development](#development)
10. [Troubleshooting](#troubleshooting)

---

## Overview

Divine Link bridges the gap between spoken scripture references and visual display. When a pastor or speaker mentions a Bible verse, Divine Link:

1. **Captures** audio from system input (microphone)
2. **Transcribes** speech in real-time using Apple's Speech Recognition
3. **Detects** scripture references using pattern matching
4. **Looks up** verse text from a local Bible database
5. **Pushes** to ProPresenter for display on Stage or Audience screens

---

## Features

### Scripture Detection
- **Multiple input formats supported:**
  - Standard: "John 3:16" or "John 3:16-18"
  - Verbal: "John chapter 3 verse 16"
  - Spoken: "John 316" or "John 3 16"
  - Word numbers: "John three sixteen"
  - Ranges: "John 3:16 to 18" or "verse 16 through 20"

- **Speech-to-text correction:**
  - Handles common mishearings (e.g., "versus" → "verse")
  - Fuzzy book name matching
  - Excludes common words from false matches

### Multi-Verse Support
- Detects verse ranges (e.g., John 3:16-18)
- Displays individual verses with verse number badges
- Expandable/collapsible verse view
- Navigate between verses with prev/next buttons
- Push one verse at a time or all at once

### ProPresenter Integration
- **Stage Screen:** Direct API integration for stage messages
- **Audience Screen:** Keyboard automation using PP's native Bible feature
- Real-time connection status
- Automatic reconnection on failure

### User Interface
- Clean, modern macOS design
- Menu bar icon for quick access
- Live transcript display
- Session management
- Multiple Bible translations (KJV, ESV, etc.)

---

## Requirements

- **macOS** 13.0 (Ventura) or later
- **Xcode** 15.0+ (for development)
- **ProPresenter** 7 (for display integration)
- **Microphone** permission
- **Speech Recognition** permission
- **Accessibility** permission (for Audience screen automation)

---

## Installation

### Development Setup

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd "Divine Link"
   ```

   **Note:** This project uses two separate repositories. See [Repository Structure Guide](docs/REPOSITORY_STRUCTURE.md) for details.

2. Open in Xcode:
   ```bash
   open DivineLink/DivineLink.xcodeproj
   ```

3. Build and run:
   - Press ⌘R or click the Play button

### First Run Permissions

On first launch, grant the following permissions when prompted:

1. **Microphone Access** - For audio capture
2. **Speech Recognition** - For real-time transcription
3. **Accessibility** (optional) - For Audience screen keyboard automation

---

## Configuration

### ProPresenter Connection

1. **In ProPresenter:**
   - Go to ProPresenter → Preferences (⌘,)
   - Click the **Network** tab
   - Enable **"Enable Network"**
   - Note the **Port** (default: 50233)

2. **In Divine Link:**
   - Click the ⚙️ Settings icon
   - Go to **ProPresenter** tab
   - Enter:
     - **IP Address:** `127.0.0.1` (if PP is on same Mac)
     - **Port:** `50233` (or your configured port)
   - Click **Test Connection**

### Bible Translation

- Click the translation dropdown (e.g., "KJV")
- Select your preferred translation
- Translations are stored locally in SQLite database

### Accessibility Permission (for Audience Push)

1. Go to **System Settings → Privacy & Security → Accessibility**
2. Click **+** and add Divine Link (or Xcode if running via debugger)
3. Toggle the permission **ON**
4. In DL Settings → ProPresenter, click **Refresh** to confirm

---

## Usage

### Basic Workflow

1. **Start Listening:**
   - Click the **Pause/Listen** button to toggle audio capture
   - The "Listening" indicator shows when active

2. **Speak Scripture References:**
   - Say something like "Turn to John chapter 3 verse 16"
   - Divine Link will detect and display the reference

3. **Review Detected Scriptures:**
   - Detected verses appear in the list
   - Click to select, hover to see action buttons
   - Multi-verse references show expandable verse list

4. **Push to ProPresenter:**
   - **Stage Screen:** Click the gold ↑ button
   - **Audience Screen:** Click the blue 👥 button

### Push Options

| Button | Icon | Action |
|--------|------|--------|
| Push All | ↑ (gold) | Push all verses to Stage Screen |
| Push One | 1 (gold) | Push current verse only to Stage |
| Audience | 👥 (blue) | Push to Audience via PP Bible |
| Delete | 🗑️ (red) | Remove from list |

### Verse Navigation (Multi-Verse)

- Click the **▼** chevron to expand verses
- Click any verse to select it
- Use **◀ ▶** buttons to navigate
- **1/3** indicator shows current position

---

## ProPresenter Integration

### Stage Screen (API)

Divine Link sends text directly to ProPresenter's Stage Display via the REST API:

```
PUT http://{ip}:{port}/v1/stage/message
Body: "John 3:16\n\nFor God so loved the world..."
```

**Setup in ProPresenter:**
1. Go to **Stage Editor** (••• menu → Stage Editor)
2. Ensure you have a **"Stage Message"** text object
3. This is where Divine Link messages appear

### Audience Screen (Keyboard Automation)

Divine Link simulates keyboard input to trigger PP's native Bible feature:

```
1. Activate ProPresenter window
2. Press ⌘B (opens Bible search)
3. Type "John 3:16-18"
4. Press Enter (displays on Audience screen)
```

**Benefits:**
- Uses PP's own Bible database
- Applies PP's configured Bible theme
- Professional formatting
- No manual typing required

**Requirements:**
- Accessibility permission granted
- ProPresenter must be running
- Works with PP's configured Bible version

---

## Architecture

### Project Structure

```
DivineLink/
├── App/
│   ├── DivineLinkApp.swift       # App entry point
│   ├── AppDelegate.swift         # Menu bar, window management
│   ├── MainView.swift            # Primary UI
│   ├── SettingsView.swift        # Settings interface
│   └── AccessibilitySettings.swift # Font scaling & display preferences
│
├── Features/
│   ├── AudioCapture/
│   │   ├── AudioCaptureService.swift
│   │   └── AudioDeviceManager.swift
│   │
│   ├── Transcription/
│   │   ├── TranscriptionService.swift
│   │   └── TranscriptBuffer.swift
│   │
│   ├── Detection/
│   │   ├── ScriptureDetectorService.swift
│   │   ├── DetectionPipeline.swift
│   │   └── ImplicitReferenceDetector.swift
│   │
│   ├── Bible/
│   │   ├── BibleService.swift
│   │   └── BibleVocabularyData.swift
│   │
│   ├── PendingBuffer/
│   │   └── BufferManager.swift
│   │
│   └── ProPresenter/
│       ├── ProPresenterClient.swift
│       ├── ProPresenterSettings.swift
│       ├── ProPresenterSettingsView.swift
│       └── KeyboardAutomationService.swift
│
└── Resources/
    └── Bible.db                  # SQLite Bible database
```

### Data Flow

```
Audio Input
    ↓
AudioCaptureService (captures microphone)
    ↓
TranscriptionService (speech → text)
    ↓
ScriptureDetectorService (pattern matching)
    ↓
BibleService (verse lookup)
    ↓
BufferManager (pending verses queue)
    ↓
MainView (UI display)
    ↓
ProPresenterClient (Stage API / Keyboard automation)
    ↓
ProPresenter Display
```

### Key Classes

| Class | Purpose |
|-------|---------|
| `DetectionPipeline` | Coordinates audio → detection → buffer flow |
| `ScriptureDetectorService` | Regex pattern matching for references |
| `BookNameNormaliser` | Converts book names/aliases to canonical form |
| `BibleService` | SQLite queries for verse lookup |
| `BufferManager` | Manages pending verses queue |
| `ProPresenterClient` | API communication with PP |
| `KeyboardAutomationService` | Simulates keystrokes for Audience push |

---

## Development

**⚠️ Repository Structure:** This project uses two separate GitHub repositories. See [Repository Structure Guide](docs/REPOSITORY_STRUCTURE.md) for details on which files go to which repository.

### Building

```bash
# Open project
open DivineLink/DivineLink.xcodeproj

# Build (⌘B)
xcodebuild -scheme DivineLink build

# Run (⌘R)
xcodebuild -scheme DivineLink run
```

### Testing Detection Patterns

The detector supports these pattern types:

| Pattern | Example | Regex Type |
|---------|---------|------------|
| Standard | "John 3:16" | `standard` |
| Standard Range | "John 3:16-18" | `standard` |
| Spoken | "John 316" | `spoken` |
| Spoken Range | "John 316 to 18" | `spokenRange` |
| Verbal | "John chapter 3 verse 16" | `verbal` |
| Verbal Short | "John 3 verse 16" | `verbalShort` |
| Word Numbers | "John three sixteen" | `spokenWords` |
| Chapter Only | "Romans 8" | `chapterOnly` |

### Adding Book Aliases

Edit `ScriptureDetectorService.swift` → `BookNameNormaliser`:

```swift
bookMappings["new-alias"] = "Canonical Name"
```

### Common Speech Corrections

The system handles these common mishearings:
- "versus" → "verse"
- "to" blocked from matching "Hosea"
- "you John" → "John" (strips leading words)

---

## Troubleshooting

### Detection Issues

**Problem:** Scripture not detected
- Check the Xcode console for pattern matching logs
- Verify the book name is recognized
- Try different phrasing ("John 3:16" vs "John chapter 3 verse 16")

**Problem:** Wrong book detected
- Check for fuzzy match issues in console
- Add specific alias if needed

**Problem:** Invalid chapter/verse detected
- The system validates against the Bible database
- Max 150 chapters (Psalms), verses validated per chapter

### ProPresenter Connection

**Problem:** "Connection Failed"
- Verify ProPresenter is running
- Check IP address and port in settings
- Ensure "Enable Network" is checked in PP Preferences
- Test with: `curl http://127.0.0.1:50233/version`

**Problem:** Stage message not appearing
- Verify Stage Editor has a "Stage Message" object
- Check PP's stage display is configured

### Audience Push (Keyboard Automation)

**Problem:** Nothing happens when clicking Audience button
- Grant Accessibility permission to DivineLink.app (or Xcode)
- Toggle the permission OFF and ON again
- Restart the app after granting permission
- Ensure ProPresenter is running and visible

**Problem:** Wrong keys typed
- ProPresenter must be frontmost when automation runs
- Check console for "Activated ProPresenter" message

### Permissions

**Problem:** "Microphone access denied"
- System Settings → Privacy & Security → Microphone → Enable Divine Link

**Problem:** "Speech recognition unavailable"
- System Settings → Privacy & Security → Speech Recognition → Enable Divine Link

---

## Documentation

- **[Feature Matrix](docs/FEATURE-MATRIX.md)** - Complete feature listing by tier (source of truth)
- **[Full Context Document](Divine-Link-Context.md)** - Comprehensive application context (includes **§10 Development Roadmap**)
- **[Project Status](PROJECT_STATUS.md)** - Release snapshot + future product roadmap table
- **[v2 Redesign Spec](REDESIGN-SPEC-v2.0.0.md)** - Sidebar UI redesign (Settings · Detection links Love quote matching when built)
- **[Changelog](CHANGELOG.md)** - Detailed version history

**Parked Love feature (designed, not building yet):** Spoken Quote → Verse Matching — see roadmap §10 and [`docs/superpowers/specs/2026-08-06-quote-verse-matching-design.md`](docs/superpowers/specs/2026-08-06-quote-verse-matching-design.md).

## Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed release notes.

---

## Licence

[Add your licence here]

---

## Contributing

[Add contribution guidelines here]

---

## Acknowledgements

- Apple Speech Recognition Framework
- ProPresenter Network API
- SQLite Bible databases
