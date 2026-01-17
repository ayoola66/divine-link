# Divine Link - Technical Decisions

**Document Type:** Technical Assumptions & Architecture Decisions  
**Version:** 1.0  
**Date:** January 2026  
**Status:** Approved for MVP

---

## Guiding Principle

> **Path of least resistance for commercial MVP. Future updates will add complexity as needed.**

---

## Distribution Strategy

| Aspect | MVP Decision | Future Enhancement |
|--------|--------------|-------------------|
| **Primary Distribution** | Direct download (signed DMG) | App Store submission |
| **Code Signing** | Developer ID + Notarisation | Same |
| **Auto-Updates** | Sparkle framework | Native App Store updates |
| **Installer Type** | DMG with drag-to-Applications | PKG installer (if needed) |

**Rationale:** Direct distribution avoids App Store sandbox restrictions on audio capture and enables faster iteration without review delays.

---

## Audio Capture Strategy

| Aspect | MVP Decision | Future Enhancement |
|--------|--------------|-------------------|
| **Primary Input** | System microphone | BlackHole bundled (with commercial licence) |
| **Secondary Input** | BlackHole (user-installed) | Loopback support |
| **Installation** | Guided setup wizard | One-click bundled install |
| **Fallback** | Built-in microphone always works | N/A |

### MVP Audio Flow

```
Option A (Simplest - MVP Default):
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Microphone │ ──▶ │ Divine Link │ ──▶ │ Detection   │
│  (Built-in) │     │   Audio     │     │   Engine    │
└─────────────┘     └─────────────┘     └─────────────┘

Option B (Better quality - User chooses):
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  BlackHole  │ ──▶ │ Divine Link │ ──▶ │ Detection   │
│  (Installed)│     │   Audio     │     │   Engine    │
└─────────────┘     └─────────────┘     └─────────────┘
```

**Rationale:** Microphone input works out of the box with zero setup. BlackHole offers better quality but requires user installation. MVP ships with both options; microphone is default.

### BlackHole Guidance (Not Bundled)

For users who want system audio capture:
1. App detects BlackHole is not installed
2. App shows simple instructions with download link
3. User installs externally (Homebrew or PKG)
4. App detects installation and enables option

**Future (v1.1+):** Contact Existential Audio for commercial licence to bundle BlackHole directly.

---

## Repository Structure

**Decision:** Monorepo (single Xcode project)

```
divine-link/
├── DivineLink/                 # Main app target
│   ├── App/                    # App entry, main views
│   ├── Features/               # Feature modules
│   │   ├── AudioCapture/       # Audio input handling
│   │   ├── Transcription/      # Speech recognition
│   │   ├── Detection/          # Scripture parsing
│   │   ├── PendingBuffer/      # UI for pending verses
│   │   └── ProPresenter/       # PP API client
│   ├── Core/                   # Shared utilities
│   ├── Models/                 # Data models
│   └── Resources/              # Assets, Bible.db
├── DivineLink.xcodeproj
├── Tests/
├── docs/
└── scripts/
```

---

## Technology Stack (Final)

| Layer | Technology | Rationale |
|-------|------------|-----------|
| **Language** | Swift 5.9+ | Modern, safe, async/await support |
| **UI Framework** | SwiftUI | Native macOS; rapid development |
| **Speech** | SFSpeechRecognizer | Local processing; no API costs |
| **Language Model** | SFCustomLanguageModelData | Bible vocabulary biasing |
| **Audio** | AVAudioEngine | Low-latency capture |
| **Database** | SQLite via GRDB.swift | Lightweight; ships with app |
| **Networking** | URLSession | Native; async/await |
| **Settings** | UserDefaults | Simple; sufficient for MVP |
| **Updates** | Sparkle | Industry standard |

---

## Testing Strategy (MVP)

| Type | Scope | Frequency |
|------|-------|-----------|
| **Unit Tests** | Detection logic, parsing | Every commit |
| **Manual Testing** | Full user journey | Every PR |
| **Stress Test** | 2-hour continuous run | Before release |

**Future:** Add XCUITest, integration tests, CI/CD pipeline.

---

## Platform Requirements

| Requirement | Value |
|-------------|-------|
| **Minimum macOS** | 14.0 (Sonoma) |
| **Architectures** | Universal (Apple Silicon + Intel) |
| **Swift Version** | 5.9+ |
| **Xcode Version** | 15+ |

---

## Deferred Decisions (Post-MVP)

These items are explicitly **not** in MVP scope:

- [ ] App Store distribution
- [ ] Bundled BlackHole (requires licence)
- [ ] Cloud ASR fallback (Whisper API)
- [ ] Multiple Bible translations
- [ ] Windows/Linux ports
- [ ] Team/multi-device sync
- [ ] Analytics dashboard
- [ ] CI/CD automation

---

**Document Version:** 1.0  
**Approved By:** coachAOG
