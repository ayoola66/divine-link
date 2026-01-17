# Story 1.4: Audio Level Monitoring UI

**Epic:** 1 - Foundation & Audio Capture  
**Story ID:** 1.4  
**Status:** Not Started  
**Complexity:** Small  

---

## User Story

**As an** operator,  
**I want** to see a visual indicator that audio is being captured,  
**so that** I have confidence the app is listening.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Main window displays real-time audio level indicator | Visual meter visible in UI |
| 2 | Indicator shows relative volume (not absolute dB) | Bar scales 0-100% based on input |
| 3 | Indicator updates smoothly (minimum 10fps) | No visible stuttering |
| 4 | When no audio is detected, indicator shows minimal/zero level | Quiet room → indicator near zero |
| 5 | When audio is present, indicator responds proportionally | Speaking → indicator rises |
| 6 | Indicator uses calm blue colour per UI specification | Colour: #3B82F6 or similar |
| 7 | Indicator has subtle pulse animation when in "Listening" state | Gentle 1s pulse visible |

---

## Technical Notes

### Audio Level Indicator View

```swift
import SwiftUI

struct AudioLevelIndicator: View {
    let level: Float // 0.0 to 1.0
    let isListening: Bool
    
    @State private var pulseOpacity: Double = 0.3
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                
                // Level bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * CGFloat(min(level, 1.0)))
                
                // Pulse overlay when listening
                if isListening {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(pulseOpacity))
                        .onAppear {
                            withAnimation(
                                .easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true)
                            ) {
                                pulseOpacity = 0.1
                            }
                        }
                }
            }
        }
        .frame(height: 8)
    }
}
```

### Integration with AudioCaptureService

```swift
struct ContentView: View {
    @StateObject private var audioService = AudioCaptureService()
    
    var body: some View {
        VStack {
            // Header with status
            HeaderView(status: audioService.isCapturing ? "Listening" : "Paused")
            
            // Audio level indicator
            AudioLevelIndicator(
                level: audioService.audioLevel,
                isListening: audioService.isCapturing
            )
            .padding(.horizontal)
            
            // ... rest of UI
        }
    }
}
```

### Colour Constants (per UI Spec)

```swift
extension Color {
    static let divineBlue = Color(hex: "#3B82F6")      // Listening indicator
    static let divineGold = Color(hex: "#D4AF37")      // Pending accent
    static let divineMuted = Color(hex: "#9CA3AF")     // Paused state
}
```

---

## Dependencies

- Story 1.3 (Audio Capture Engine)

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] Indicator responds to audio in real-time
- [ ] Animation is smooth and non-distracting
- [ ] Colours match UI specification
- [ ] Committed to Git
