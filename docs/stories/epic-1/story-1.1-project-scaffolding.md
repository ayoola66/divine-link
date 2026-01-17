# Story 1.1: Project Scaffolding & Menu Bar App Shell

**Epic:** 1 - Foundation & Audio Capture  
**Story ID:** 1.1  
**Status:** Not Started  
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

- [ ] All acceptance criteria verified
- [ ] Code reviewed (self or peer)
- [ ] No compiler warnings
- [ ] App launches and displays menu bar icon
- [ ] README updated with setup instructions
- [ ] Committed to Git with descriptive message
