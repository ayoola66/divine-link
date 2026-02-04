# Story 6.1: Panic Button & Clear Screen

**Epic:** 6 - Operator Safety & Detection Confidence  
**Story ID:** 6.1  
**Status:** Not Started  
**Complexity:** Small  
**Priority:** P0 (Critical Safety Feature)

---

## User Story

**As an** operator during a live service,  
**I want** an instant keyboard shortcut to clear any displayed scripture from ProPresenter,  
**so that** I can recover quickly from unexpected situations without disruption.

---

## Background

During live services, operators may encounter situations where they need to immediately clear the screen:
- Wrong verse was pushed (misdetection)
- Pastor changed direction mid-sentence
- Technical glitch showing incorrect content
- Need to pause scripture display temporarily

Currently, the only way to clear is through ProPresenter directly, which may require mouse interaction and takes valuable seconds during live services.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | F12 key triggers immediate clear/stop action | Press F12 → ProPresenter clears slide |
| 2 | Alternative: Cmd+Esc triggers same action | Press ⌘+Esc → ProPresenter clears slide |
| 3 | Clear action sends appropriate command to ProPresenter | API call or keyboard command sent |
| 4 | Visual feedback shown in Divine Link (brief flash or status) | UI confirms action was sent |
| 5 | Works when main window is focused | Shortcut works in app |
| 6 | Audio cue option (subtle click sound) | Optional: sound plays on clear |
| 7 | Shortcut documented in Settings panel | Shortcut visible in UI |

---

## Technical Notes

### Keyboard Shortcut Options

**Primary Option - F12 Key:**
- Not used by macOS system
- Single key press (no modifier needed)
- Easy to reach in panic situations
- Industry standard for "stop/clear" actions

**Alternative Option - Cmd+Esc:**
- Follows macOS conventions
- Two-key combo prevents accidental triggers
- Similar to Force Quit pattern

### Implementation Approach

#### Option A: ProPresenter API Clear (Preferred)

```swift
// ProPresenterService.swift
func clearCurrentSlide() async throws {
    // Option 1: Navigate to blank slide
    let blankURL = baseURL.appendingPathComponent("/v1/presentation/active/focus")
    // Or trigger a "clear all" message
    
    // Option 2: Send to specific blank/logo slide
    let request = URLRequest(url: clearURL)
    try await session.data(for: request)
}
```

#### Option B: Keyboard Automation (Fallback)

```swift
// KeyboardAutomationService.swift
func triggerClear() {
    // Send "Clear All" keyboard shortcut to ProPresenter
    // Default ProPresenter clear: Press 'C' or specific key
    
    let event = CGEvent(keyboardEventSource: nil, virtualKey: 0x08, keyDown: true) // 'C' key
    event?.post(tap: .cghidEventTap)
}
```

### UI Integration

```swift
// MainView.swift - Add to keyboard handlers
.onKeyPress(.F12) {
    Task { await triggerPanicClear() }
    return .handled
}

// KeyboardHandler using NSEvent for F12
func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
    switch event.keyCode {
    case 111: // F12
        Task { await triggerPanicClear() }
        return nil
    default:
        return event
    }
}
```

### Visual Feedback

```swift
// ClearFeedbackView.swift
struct ClearFeedbackOverlay: View {
    @State private var showClearFeedback = false
    
    var body: some View {
        ZStack {
            if showClearFeedback {
                Color.red.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showClearFeedback = false
                        }
                    }
            }
        }
    }
}
```

### Audio Feedback (Optional)

```swift
// AudioFeedback.swift
import AVFoundation

class AudioFeedback {
    static let shared = AudioFeedback()
    private var player: AVAudioPlayer?
    
    func playClearSound() {
        guard let url = Bundle.main.url(forResource: "clear", withExtension: "wav") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = 0.3 // Subtle
        player?.play()
    }
}
```

---

## ProPresenter Clear Methods

Research needed on ProPresenter API:

| Method | Endpoint | Notes |
|--------|----------|-------|
| Clear All | `/v1/clear/all` | Clears all layers |
| Clear Slide | `/v1/clear/slide` | Clears presentation layer |
| Clear Message | `/v1/clear/message` | Clears message layer |
| Go to Logo | `/v1/presentation/slide_index/{index}` | Navigate to blank/logo |

### Fallback Keyboard Commands

ProPresenter default shortcuts:
- `C` - Clear All
- `Shift+C` - Clear Slide Layer
- `Option+C` - Clear Props Layer

---

## UI Updates

### Settings Panel Addition

Add to Settings → General or Shortcuts tab:

```
┌─────────────────────────────────────────────────┐
│ Safety Controls                                  │
├─────────────────────────────────────────────────┤
│                                                  │
│ Panic Button Shortcut:  [ F12 ▼ ]               │
│                                                  │
│ ☑ Play audio cue on clear                       │
│ ☑ Show visual feedback                          │
│                                                  │
│ Clear Method:  ○ API  ● Keyboard                │
│                                                  │
└─────────────────────────────────────────────────┘
```

### Status Bar Indication

Brief "CLEARED" text appears in status area when panic button used.

---

## Dependencies

- Story 3.6 (ProPresenter API Client) ✅ Complete
- Story 3.4 (Keyboard Shortcut Handling) ✅ Complete

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] F12 triggers clear action
- [ ] Cmd+Esc alternative works
- [ ] ProPresenter receives clear command
- [ ] Visual feedback shown in app
- [ ] Shortcut documented in Settings
- [ ] Works during live listening state
- [ ] No conflict with existing shortcuts
- [ ] Tested with ProPresenter connection
- [ ] Committed to Git

---

## Testing Scenarios

1. **Normal Operation**: Press F12 while verse displayed → verse clears
2. **No Verse Displayed**: Press F12 → no error, no action needed
3. **ProPresenter Disconnected**: Press F12 → error handled gracefully
4. **Rapid Press**: Press F12 multiple times → handled without crash
5. **During Detection**: Press F12 while listening → display clears, listening continues

---

## Notes

- This is a **critical safety feature** - operators need absolute confidence it works
- Must be single-key for maximum speed in panic situations
- Consider adding to menu bar for discoverability
- Future enhancement: configurable clear behaviour (clear slide vs clear all)
