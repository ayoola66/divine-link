# Changelog

All notable changes to Divine Link will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Epic 3: Pending Buffer & ProPresenter Integration (9 stories)
- Epic 4: Service Sessions & Pastor Profiles (7 stories)
- Story 2.7: Bible Database Validation

---

## [0.2.0] - 2026-01-22

### Added
- **Epic 2: Transcription & Scripture Detection** (Complete)
  - Bible database with KJV, ASV, and WEB translations
  - Speech recognition service using macOS native Speech framework
  - Custom language model biasing for Bible vocabulary
  - Live transcript feed UI with real-time display
  - Scripture reference detection engine with pattern matching
  - Full detection pipeline integration
  - Transcript editing with speech correction learning
  - Bible translation selection (KJV/ASV/WEB dropdown)

### Changed
- MainView now includes status indicators for Audio, Speech, Bible, and Detection
- Expanded status panel with detailed system information
- Verse cards now display in scrollable list with selection support

### Technical
- Added `BibleService.swift` for SQLite database access
- Added `TranscriptionService.swift` for speech-to-text
- Added `ScriptureDetectorService.swift` with book name normalisation
- Added `DetectionPipeline.swift` for coordinating all services
- Added `ListeningFeedView.swift` for transcript display

---

## [0.1.0] - 2026-01-15

### Added
- **Epic 1: Foundation & Audio Capture** (Complete)
  - macOS menu bar application shell (no Dock icon)
  - Custom app icon with Divine Link branding
  - Audio input device selection and management
  - Real-time audio capture engine using AVAudioEngine
  - Audio level monitoring with visual indicator
  - Peak level detection and display
  - Listening state management (Start/Pause toggle)
  - Settings view with Audio tab
  - Keyboard shortcut: Space to toggle listening

### Technical
- Project scaffolding with SwiftUI lifecycle
- Xcode project configured for macOS 14+ (Sonoma)
- App entitlements for microphone access
- Folder structure: App/, Features/, Resources/
- Added `AudioCaptureService.swift` for audio input handling
- Added `AudioDeviceManager.swift` for device enumeration
- Added `AudioLevelIndicator.swift` for visual feedback

---

## [0.0.1] - 2026-01-10

### Added
- Initial project setup
- Project documentation suite:
  - Project Brief (`docs/brief.md`)
  - Product Requirements Document (`docs/prd.md`)
  - Architecture Document (`docs/architecture.md`)
  - UI Specification (`docs/ui-specification.md`)
  - Technical Decisions (`docs/technical-decisions.md`)
  - Wireframes and design assets
- User stories for all 4 epics (28 stories total)
- BMAD Method integration for development workflow
- README with setup instructions

---

## Version Summary

| Version | Date | Epic | Stories Complete |
|---------|------|------|------------------|
| 0.2.0 | 2026-01-22 | Epic 2 | 6 (2.1-2.6) |
| 0.1.0 | 2026-01-15 | Epic 1 | 5 (1.1-1.5) |
| 0.0.1 | 2026-01-10 | Setup | Documentation |

**Total Progress: 11/28 stories (39%)**

---

## Upcoming Milestones

### v0.3.0 - MVP Complete
- [ ] Epic 3: ProPresenter Integration
- [ ] Story 2.7: Bible Database Validation

### v0.4.0 - Enhanced Features
- [ ] Epic 4: Service Sessions & Pastor Profiles

### v1.0.0 - Production Release
- [ ] Full testing and QA
- [ ] Performance optimisation
- [ ] App Store preparation

---

[Unreleased]: https://github.com/ayoola66/divine-link/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/ayoola66/divine-link/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ayoola66/divine-link/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/ayoola66/divine-link/releases/tag/v0.0.1
