# Story 1.1: Project Scaffolding & Menu Bar App Shell

**Epic:** 1 - Foundation & Audio Capture  
**Story ID:** 1.1  
**Status:** Complete  
**Complexity:** Medium  

---

## User Story

**As a** developer,  
**I want** a properly configured Xcode project with a menu bar app shell,  
**so that** I have a solid foundation for building Divine Link features.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Xcode project created with SwiftUI lifecycle and macOS 14+ deployment target | Project opens in Xcode 15+, builds successfully |
| 2 | App runs as a menu bar application (no Dock icon) | `LSUIElement = true` in Info.plist; no Dock icon appears |
| 3 | Menu bar displays a simple icon (placeholder) with status indicator | Icon visible in menu bar when app runs |
| 4 | Clicking menu bar icon opens a popover/window with placeholder content | Click → popover appears with "Divine Link" text |
| 5 | App includes "Quit" menu item that terminates the application | Menu item visible; clicking quits app |
| 6 | Project structure follows the agreed folder organisation | Folders: `App/`, `Features/`, `Core/`, `Models/`, `Resources/` exist |
| 7 | `.gitignore` configured for Xcode/Swift projects | Standard Xcode ignores (DerivedData, xcuserdata, etc.) |
| 8 | README.md created with basic project description and setup instructions | README exists with project name and build instructions |
| 9 | App is code-signed for local development | App runs without Gatekeeper warnings in dev |

---

## Technical Notes

### Project Structure

```
DivineLink/
├── App/
│   ├── DivineLink.swift          # @main App entry
│   ├── AppDelegate.swift         # Menu bar setup
│   └── MainView.swift            # Popover content
├── Features/
│   ├── AudioCapture/
│   ├── Transcription/
│   ├── Detection/
│   ├── PendingBuffer/
│   └── ProPresenter/
├── Core/
│   └── (shared utilities)
├── Models/
│   └── (data models)
└── Resources/
    └── Assets.xcassets
```

### Key Implementation Details

1. **Menu Bar App Setup:**
   ```swift
   @main
   struct DivineLink: App {
       @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
       
       var body: some Scene {
           Settings {
               SettingsView()
           }
       }
   }
   ```

2. **Info.plist Settings:**
   - `LSUIElement` = `YES` (hides from Dock)
   - `NSMicrophoneUsageDescription` = "Divine Link needs microphone access to detect scripture references"
   - `NSSpeechRecognitionUsageDescription` = "Divine Link uses speech recognition to detect Bible verses"

3. **Menu Bar Icon:**
   - Use SF Symbol `book.fill` as placeholder
   - Or create simple custom icon (16x16, 32x32 @2x)

---

## Dependencies

- None (first story)

---

## Definition of Done

- [x] All acceptance criteria verified
- [x] Code reviewed (self or peer)
- [x] No compiler warnings
- [x] App launches and displays menu bar icon
- [x] README updated with setup instructions
- [ ] Committed to Git with descriptive message

---

## Dev Agent Record

### Tasks

- [x] Create folder structure (App/, Features/, Core/, Models/, Resources/)
- [x] Create menu bar app shell (AppDelegate, MainView)
- [x] Create Info.plist with LSUIElement and usage descriptions
- [x] Update .gitignore for Xcode projects
- [x] Update README.md with project description and setup instructions
- [x] Add files to Xcode project
- [x] Verify app builds and runs
- [x] Test menu bar icon appears
- [x] Test popover opens on click
- [x] Test Quit functionality
- [x] Add custom app icon

### File List

**Created:**
- `App/DivineLinkApp.swift` - Main app entry point with menu bar setup
- `App/AppDelegate.swift` - Menu bar status item and popover management
- `App/MainView.swift` - Popover content view
- `App/SettingsView.swift` - Settings view placeholder
- `Info.plist` - App configuration (LSUIElement, usage descriptions)
- `Assets.xcassets/AppIcon.appiconset/AppIcon.png` - Custom app icon
- `README.md` - Updated with project description and setup instructions
- `.gitignore` - Updated with Xcode-specific ignores

**Modified:**
- `project.pbxproj` - Configured to use custom Info.plist, added file exceptions

**Deleted:**
- Feature folder `.gitkeep` files (caused Xcode build conflicts)

### Completion Notes

- Folder structure created following architecture document
- Menu bar app shell implemented with NSStatusItem and NSPopover
- Info.plist configured for menu bar app (LSUIElement = YES)
- Usage descriptions added for microphone and speech recognition
- README updated with comprehensive setup instructions
- Custom Divine Link logo set as app icon
- SF Symbol `book.fill` used for menu bar icon
- All acceptance criteria verified and passing

### Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-01-17 | Created menu bar app shell and folder structure | James (Dev) |
| 2026-01-18 | Fixed Xcode build errors, added custom app icon | James (Dev) |
