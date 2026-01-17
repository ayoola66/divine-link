# Story 1.5: Listening State Management

**Epic:** 1 - Foundation & Audio Capture  
**Story ID:** 1.5  
**Status:** Not Started  
**Complexity:** Small  

---

## User Story

**As an** operator,  
**I want** to pause and resume listening,  
**so that** I can control when Divine Link is active.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Pause button visible in main window (per UI spec: Zone 3) | Button visible at bottom of window |
| 2 | Pressing Pause (or Space) stops audio capture | Audio capture stops; no new transcription |
| 3 | UI transitions to "Paused" state (muted grey per UI spec) | UI colours desaturate |
| 4 | Status text in header updates to "Paused" | Header shows "Paused" |
| 5 | Pressing Resume (or Space again) restarts audio capture | Audio capture resumes; transcription continues |
| 6 | UI transitions back to "Listening" state | UI colours restore |
| 7 | Pause state is NOT persisted between app launches | App always starts in Listening state |

---

## Technical Notes

### App State Model

```swift
import SwiftUI

enum ListeningState {
    case listening
    case paused
    
    var statusText: String {
        switch self {
        case .listening: return "Listening"
        case .paused: return "Paused"
        }
    }
    
    var statusColor: Color {
        switch self {
        case .listening: return .divineBlue
        case .paused: return .divineMuted
        }
    }
}

class AppState: ObservableObject {
    @Published var listeningState: ListeningState = .listening
    
    func toggleListening() {
        switch listeningState {
        case .listening:
            listeningState = .paused
        case .paused:
            listeningState = .listening
        }
    }
}
```

### Pause Button View

```swift
struct PauseButton: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Button(action: { appState.toggleListening() }) {
            HStack {
                Image(systemName: appState.listeningState == .listening ? "pause.fill" : "play.fill")
                Text(appState.listeningState == .listening ? "Pause" : "Resume")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.space, modifiers: [])
    }
}
```

### UI State Transitions

```swift
struct MainView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack {
            // Header
            HeaderView(status: appState.listeningState.statusText)
            
            // Content with state-based styling
            ContentArea()
                .saturation(appState.listeningState == .paused ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: appState.listeningState)
            
            // Actions
            ActionButtons()
        }
    }
}
```

### Keyboard Shortcut Handling

```swift
// In main App or Window
.onReceive(NotificationCenter.default.publisher(for: .toggleListening)) { _ in
    appState.toggleListening()
}

// Or using SwiftUI keyboard shortcuts
.keyboardShortcut(.space, modifiers: [])
```

---

## Dependencies

- Story 1.3 (Audio Capture Engine)
- Story 1.4 (Audio Level Monitoring)

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] Pause/Resume works via button and Space key
- [ ] UI visually transitions between states
- [ ] Audio capture actually stops/starts
- [ ] App starts in Listening state
- [ ] Committed to Git
