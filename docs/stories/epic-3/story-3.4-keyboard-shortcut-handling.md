# Story 3.4: Keyboard Shortcut Handling

**Epic:** 3 - Pending Buffer & ProPresenter Integration  
**Story ID:** 3.4  
**Status:** Not Started  
**Complexity:** Small  

---

## User Story

**As an** operator,  
**I want** to use keyboard shortcuts for all actions,  
**so that** I can work quickly without using the mouse.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Enter key triggers "Push to ProPresenter" | Press Enter → verse pushed |
| 2 | Escape key triggers "Ignore/Clear" | Press Esc → verse dismissed |
| 3 | Space key toggles Pause/Resume | Press Space → state toggles |
| 4 | ⌘+, opens Settings | Press ⌘, → settings open |
| 5 | ⌘+Q quits application | Press ⌘Q → app quits |
| 6 | Shortcuts work when main window is focused | Window focused → shortcuts work |
| 7 | Shortcuts are global when app is frontmost | App frontmost → shortcuts work |

---

## Technical Notes

### Keyboard Handling in SwiftUI

```swift
import SwiftUI

struct MainView: View {
    @EnvironmentObject var bufferManager: BufferManager
    @EnvironmentObject var appState: AppState
    @Environment(\.openSettings) var openSettings
    
    let onPush: () -> Void
    
    var body: some View {
        VStack {
            // ... UI content
        }
        .onKeyPress(.return) {
            handlePush()
            return .handled
        }
        .onKeyPress(.escape) {
            handleIgnore()
            return .handled
        }
        .onKeyPress(.space) {
            handlePauseToggle()
            return .handled
        }
    }
    
    private func handlePush() {
        guard bufferManager.currentVerse != nil else { return }
        onPush()
    }
    
    private func handleIgnore() {
        bufferManager.dismissCurrentVerse()
    }
    
    private func handlePauseToggle() {
        appState.toggleListening()
    }
}
```

### Alternative: NSEvent Monitoring

```swift
class KeyboardHandler: ObservableObject {
    private var monitor: Any?
    
    var onPush: (() -> Void)?
    var onIgnore: (() -> Void)?
    var onPauseToggle: (() -> Void)?
    
    func startMonitoring() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
    }
    
    func stopMonitoring() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 36: // Return/Enter
            onPush?()
            return nil // Consume event
            
        case 53: // Escape
            onIgnore?()
            return nil
            
        case 49: // Space
            onPauseToggle?()
            return nil
            
        default:
            return event // Pass through
        }
    }
}
```

### Menu Commands for Standard Shortcuts

```swift
@main
struct DivineLink: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Settings...") {
                    // Open settings
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        
        Settings {
            SettingsView()
        }
    }
}
```

### Keyboard Shortcut Summary

| Action | Key | Code | Modifier |
|--------|-----|------|----------|
| Push to ProPresenter | Enter/Return | 36 | None |
| Ignore/Clear | Escape | 53 | None |
| Pause/Resume | Space | 49 | None |
| Open Settings | , | 43 | ⌘ |
| Quit | Q | 12 | ⌘ |

### Focus Management

```swift
struct ContentView: View {
    @FocusState private var isWindowFocused: Bool
    
    var body: some View {
        VStack {
            // Content
        }
        .focusable()
        .focused($isWindowFocused)
        .onAppear {
            isWindowFocused = true
        }
    }
}
```

---

## Dependencies

- Story 3.3 (Operator Action Buttons)

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] Enter triggers push (when verse pending)
- [ ] Escape triggers ignore
- [ ] Space toggles pause
- [ ] ⌘, opens settings
- [ ] ⌘Q quits app
- [ ] Shortcuts tested in focused state
- [ ] Committed to Git
