# Story 3.3: Operator Action Buttons

**Epic:** 3 - Pending Buffer & ProPresenter Integration  
**Story ID:** 3.3  
**Status:** Not Started  
**Complexity:** Small  

---

## User Story

**As an** operator,  
**I want** clear buttons to push or ignore a pending verse,  
**so that** I control what appears on the main screen.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Zone 3 displays action buttons per UI spec | Buttons visible at bottom |
| 2 | "Push to ProPresenter" button with gold accent | Gold button visible |
| 3 | "Ignore" button with neutral styling | Neutral button visible |
| 4 | "Pause" button with grey styling | Grey button visible |
| 5 | Buttons are large and touch-friendly (44pt minimum) | Buttons are large |
| 6 | Keyboard shortcuts displayed on buttons | Shortcuts shown |
| 7 | Buttons disabled when no verse pending (Push, Ignore) | Buttons grey out |
| 8 | Button states update reactively | State changes reflected |

---

## Technical Notes

### Zone 3 Action Buttons View

```swift
import SwiftUI

struct Zone3_ActionButtons: View {
    @EnvironmentObject var bufferManager: BufferManager
    @EnvironmentObject var appState: AppState
    
    let onPush: () -> Void
    let onIgnore: () -> Void
    
    private var hasPendingVerse: Bool {
        bufferManager.currentVerse != nil
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Push button
            ActionButton(
                title: "Push to ProPresenter",
                shortcut: "Enter",
                icon: "arrow.up.circle.fill",
                style: .primary,
                isEnabled: hasPendingVerse,
                action: onPush
            )
            
            // Ignore button
            ActionButton(
                title: "Ignore",
                shortcut: "Esc",
                icon: "xmark.circle.fill",
                style: .secondary,
                isEnabled: hasPendingVerse,
                action: onIgnore
            )
            
            // Pause button
            ActionButton(
                title: appState.listeningState == .listening ? "Pause" : "Resume",
                shortcut: "Space",
                icon: appState.listeningState == .listening ? "pause.fill" : "play.fill",
                style: .tertiary,
                isEnabled: true,
                action: { appState.toggleListening() }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
```

### ActionButton Component

```swift
struct ActionButton: View {
    let title: String
    let shortcut: String
    let icon: String
    let style: ActionButtonStyle
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                }
                
                Text(shortcut)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isEnabled ? style.shortcutColor : .gray)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44) // Minimum touch target
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isEnabled ? style.backgroundColor : Color.gray.opacity(0.2))
            .foregroundColor(isEnabled ? style.foregroundColor : .gray)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

enum ActionButtonStyle {
    case primary    // Push - Gold
    case secondary  // Ignore - Neutral
    case tertiary   // Pause - Grey
    
    var backgroundColor: Color {
        switch self {
        case .primary: return .divineGold
        case .secondary: return Color(NSColor.controlBackgroundColor)
        case .tertiary: return Color.gray.opacity(0.2)
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .primary: return .white
        case .secondary: return .primary
        case .tertiary: return .secondary
        }
    }
    
    var shortcutColor: Color {
        switch self {
        case .primary: return .white.opacity(0.8)
        case .secondary: return .secondary
        case .tertiary: return .secondary
        }
    }
}
```

### Button State Reactivity

```swift
struct ContentView: View {
    @StateObject private var bufferManager = BufferManager()
    @StateObject private var appState = AppState()
    
    var body: some View {
        VStack(spacing: 0) {
            // Zone 1: Listening Feed
            Zone1_ListeningFeed()
            
            Divider()
            
            // Zone 2: Pending Scripture
            Zone2_PendingBuffer()
            
            Divider()
            
            // Zone 3: Action Buttons
            Zone3_ActionButtons(
                onPush: handlePush,
                onIgnore: handleIgnore
            )
        }
        .environmentObject(bufferManager)
        .environmentObject(appState)
    }
    
    private func handlePush() {
        guard let verse = bufferManager.approveCurrentVerse() else { return }
        // Push to ProPresenter (Story 3.7)
    }
    
    private func handleIgnore() {
        bufferManager.dismissCurrentVerse()
    }
}
```

---

## Dependencies

- Story 3.1 (Pending Buffer Data Model)
- Story 1.5 (Listening State Management)

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] All three buttons visible
- [ ] Correct styling applied
- [ ] Disabled state works correctly
- [ ] Keyboard shortcuts displayed
- [ ] Buttons are 44pt+ height
- [ ] Committed to Git
