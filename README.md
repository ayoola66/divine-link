# Divine Link

**Real-time scripture detection for ProPresenter**

Divine Link is a macOS menu bar application that listens to live sermons, detects Bible references in real-time, and allows operators to push verses to ProPresenter with a single click.

## Features

- 🎤 **Real-time Audio Capture** - Listen via microphone or system audio
- 🗣️ **Speech Recognition** - On-device transcription with Bible vocabulary biasing
- 📖 **Scripture Detection** - Automatic detection of Bible references
- ⏸️ **Human-in-the-Loop** - Operator approval required before display
- 🎯 **ProPresenter Integration** - Push detected verses directly to stage

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Swift 5.9 or later
- ProPresenter 7.9+ (for integration)

## Setup Instructions

### Prerequisites

1. **Install Xcode:**
   ```bash
   # Install from App Store or:
   xcode-select --install
   ```

2. **Clone Repository:**
   ```bash
   git clone https://github.com/ayoola66/divine-link.git
   cd divine-link
   ```

### Building the Project

1. **Open in Xcode:**
   ```bash
   open DivineLink/DivineLink.xcodeproj
   ```

2. **Configure Signing:**
   - Select the `DivineLink` target
   - Go to "Signing & Capabilities"
   - Select your development team (or "None" for local development)

3. **Build:**
   - Press `⌘B` (Product → Build)
   - Or run: `⌘R` (Product → Run)

### Running the App

1. Build and run from Xcode (`⌘R`)
2. The app will appear in the menu bar (top-right)
3. Click the menu bar icon to open the popover
4. Use "Quit" to exit the application

## Project Structure

```
DivineLink/
├── App/                    # Application entry point
│   ├── DivineLinkApp.swift
│   ├── AppDelegate.swift
│   └── MainView.swift
├── Features/               # Feature modules
│   ├── AudioCapture/
│   ├── Transcription/
│   ├── Detection/
│   ├── PendingBuffer/
│   └── ProPresenter/
├── Core/                   # Shared utilities
├── Models/                 # Data models
└── Resources/              # Assets, Bible.db
```

## Development

### Running Tests

```bash
# In Xcode: ⌘U (Product → Test)
# Or from terminal:
swift test
```

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftLint (future)
- One type per file
- Document public APIs with doc comments

## Documentation

- [Changelog](CHANGELOG.md) - Version history and release notes
- [Development Log](docs/development-log.md) - Issues, fixes, and technical decisions
- [Project Brief](docs/brief.md)
- [Product Requirements](docs/prd.md)
- [Architecture](docs/architecture.md)
- [User Stories](docs/stories/)

## License

Copyright © 2026 Divine Link. All rights reserved.

---

**Status:** Under Active Development  
**Version:** 0.1.0 (MVP)
