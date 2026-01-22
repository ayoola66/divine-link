# Changelog

All notable changes to Divine Link will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Story 2.7: Bible Database Validation (ASV/WEB completion)
- Full testing and QA
- App Store preparation

---

## [0.5.0] - 2026-01-22

### Added
- **Epic 5: Advanced Bible Vocabulary** (Complete)
  - `BibleVocabularyData.swift` with comprehensive STT mishearing mappings (100+ entries)
  - All 66 Bible book names with abbreviations and common errors
  - Number word mappings (one → 1, twenty-three → 23)
  - Famous verse detection (implicit references without explicit citation)
  - `ImplicitReferenceDetector` for phrases like "For God so loved the world" → John 3:16

### Technical
- Enhanced `BookNameNormaliser` to use `BibleVocabularyData`
- Integrated `ImplicitReferenceDetector` into `DetectionPipeline`
- Added ordinal and trigger word mappings

---

## [0.4.0] - 2026-01-22

### Added
- **Epic 4: Service Sessions & History** (Complete)
  - Service type caching with autocomplete suggestions (`ServiceTypeCache.swift`)
  - SQLite-based service history archive with full CRUD operations
  - Service history UI with monthly grouping and detail views
  - Archive auto-cleanup (90 days retention)
  - Export to JSON and CSV formats

### Changed
- `NewServiceSheet` now caches service types for future suggestions
- `ServiceHistoryView` now allows deletion of individual sessions
- `ArchiveCleanupService` runs automatically on app launch

### Technical
- Added `ServiceTypeCache.swift` for service type suggestions
- Enhanced `ServiceArchive.swift` with delete functionality
- Integrated cleanup notifications with export option

---

## [0.3.0] - 2026-01-22

### Added
- **Epic 3: ProPresenter Integration** (Complete)
  - ProPresenter connection settings UI with IP/port configuration
  - ProPresenter API client with async/await networking
  - Push to ProPresenter action (sends verse to stage display)
  - Connection status indicator in header (colour-coded)
  - Automatic reconnection on connection failure (5 attempts)

### Changed
- MainView header now displays ProPresenter connection status
- Push button now sends verse text to ProPresenter stage display
- Settings panel includes ProPresenter setup instructions

### Technical
- Added `ProPresenterSettings.swift` for connection persistence
- Added `ProPresenterClient.swift` for API communication
- Added `ProPresenterSettingsView.swift` for configuration UI
- Added `PushActionCoordinator.swift` for managing push actions
- Added `ConnectionStatusIndicator` component

---

## [0.2.5] - 2026-01-22

### Fixed
- **Critical: Pushed verses no longer removed from list** - Verses now stay visible with green background and checkmark indicator
- **Invalid chapter detection** - "Philippians 6:7" now correctly rejected (max 4 chapters)
- **Leading prepositions** - "to Exodus 12:6" now correctly strips "to" before lookup
- **"Philippines" country name** - Now correctly maps to "Philippians" book

### Added
- Bible database loading indicator with progress text
- Chapter validation using pre-cached book metadata
- Push count badge (×2, ×3, etc.) for repeatedly pushed verses

### Changed
- Pushed verses show green background instead of being removed
- Invalid detections now silently rejected instead of showing "[Verse text not available]"

---

## [0.2.4] - 2026-01-22

### Fixed
- **Nonsensical correction suggestions** - Added ignore list for common words ("let's", "the", "to")
- **Cancel button missing** - Added "Cancel" button to correction dialog
- **"Filipinos" mishearing** - Added to book mappings for "Philippians"

### Added
- Common STT error mappings for difficult book names:
  - "filipinos", "filipino" → Philippians
  - "glacians" → Galatians
  - "fusions", "a fusions" → Ephesians
  - "cautions", "closions" → Colossians
  - "the saloni", "the salonika" → 1 Thessalonians

---

## [0.2.3] - 2026-01-21

### Fixed
- **Verbal pattern not matching number words** - "three seven" now correctly parsed as 3:7
- **Space key triggering during edit** - Disabled listening toggle when editing transcript

### Added
- `spokenWords` pattern for natural number speech ("Genesis twenty one one")
- Number word dictionary supporting 1-50 plus ordinals
- Song of Solomon aliases ("songs", "sos", "canticles")

---

## [0.2.2] - 2026-01-20

### Fixed
- **2-digit numbers split incorrectly** - "John 11" no longer becomes "John 1:1"
- **Fuzzy matching too aggressive** - Reduced max Levenshtein distance

### Added
- Fuzzy book name matching with confidence scores
- Editable transcript with inline corrections
- Speech correction learning (saved per pastor)
- "roof" → "Ruth", "romance" → "Romans" mappings

---

## [0.2.1] - 2026-01-19

### Fixed
- **Wrong translation column name** - Changed from `translation_id` to `translation`
- **Hardcoded BSB translation** - Now uses user-selected translation
- **App icon missing in header** - Uses custom icon from asset catalog

### Changed
- Redesigned MainView with scrollable verse list
- Translation selector moved to status indicators row
- Available translations limited to KJV, ASV, WEB (database content)

---

## [0.2.0] - 2026-01-18

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
| 0.5.0 | 2026-01-22 | Epic 5 | 2 (5.1-5.2) |
| 0.4.0 | 2026-01-22 | Epic 4 | 4 (4.2-4.4, 4.7) |
| 0.3.0 | 2026-01-22 | Epic 3 | 5 (3.5-3.9) |
| 0.2.x | 2026-01-18-22 | Epic 2 | 6 (2.1-2.6) + fixes |
| 0.1.0 | 2026-01-15 | Epic 1 | 5 (1.1-1.5) |
| 0.0.1 | 2026-01-10 | Setup | Documentation |

**Total Progress: 22/28 stories (79%)**

---

## Upcoming Milestones

### v0.6.0 - Full MVP
- [ ] Story 2.7: Bible Database Validation (ASV/WEB completion)
- [ ] Story 4.1: Service Session Creation
- [ ] Story 4.5: Pastor Profile Management
- [ ] Story 4.6: Pastor Speech Learning

### v1.0.0 - Production Release
- [ ] Full testing and QA
- [ ] Performance optimisation
- [ ] App Store preparation

---

[Unreleased]: https://github.com/ayoola66/divine-link/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/ayoola66/divine-link/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/ayoola66/divine-link/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/ayoola66/divine-link/compare/v0.2.5...v0.3.0
[0.2.5]: https://github.com/ayoola66/divine-link/compare/v0.2.4...v0.2.5
[0.2.4]: https://github.com/ayoola66/divine-link/compare/v0.2.3...v0.2.4
[0.2.3]: https://github.com/ayoola66/divine-link/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/ayoola66/divine-link/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/ayoola66/divine-link/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/ayoola66/divine-link/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ayoola66/divine-link/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/ayoola66/divine-link/releases/tag/v0.0.1
