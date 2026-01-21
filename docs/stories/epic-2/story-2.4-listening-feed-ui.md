# Story 2.4: Listening Feed UI

**Epic:** 2 - Transcription & Scripture Detection  
**Story ID:** 2.4  
**Status:** Complete  
**Complexity:** Small  

---

## User Story

**As an** operator,  
**I want** to see a live transcript of what's being said,  
**so that** I have confidence the app is hearing correctly.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Zone 1 (top) displays scrolling transcript text | Transcript visible in top zone |
| 2 | Text is greyed and non-editable | Text colour grey; no cursor on click |
| 3 | New text appears at bottom, auto-scrolls | Speaking adds text; view scrolls down |
| 4 | Transcript shows last ~500 characters (rolling buffer) | Old text removed as new arrives |
| 5 | When paused, transcript stops updating | Pause → no new text appears |
| 6 | Transcript clears when listening resumes | Resume → fresh transcript |
| 7 | Font uses SF Mono 13pt per UI spec | Correct font applied |

---

## Technical Notes

### Listening Feed View

```swift
import SwiftUI

struct ListeningFeedView: View {
    let transcript: String
    let isListening: Bool
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(transcript)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .id("transcript")
            }
            .onChange(of: transcript) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("transcript", anchor: .bottom)
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .overlay(
            // Empty state
            Group {
                if transcript.isEmpty && isListening {
                    Text("Listening for speech...")
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        )
    }
}
```

### Rolling Buffer for Transcript

```swift
class TranscriptBuffer: ObservableObject {
    @Published var text: String = ""
    private let maxLength = 500
    
    func append(_ newText: String) {
        text = newText
        
        // Trim to last maxLength characters
        if text.count > maxLength {
            let startIndex = text.index(text.endIndex, offsetBy: -maxLength)
            text = String(text[startIndex...])
        }
    }
    
    func clear() {
        text = ""
    }
}
```

### Integration

```swift
struct ContentView: View {
    @StateObject private var transcriptBuffer = TranscriptBuffer()
    @StateObject private var transcriptionService = TranscriptionService()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Zone 1: Listening Feed
            ListeningFeedView(
                transcript: transcriptBuffer.text,
                isListening: appState.listeningState == .listening
            )
            .frame(height: 80)
            
            Divider()
            
            // Zone 2: Pending Scripture (next story)
            // Zone 3: Actions
        }
        .onReceive(transcriptionService.transcriptPublisher) { newTranscript in
            if appState.listeningState == .listening {
                transcriptBuffer.append(newTranscript)
            }
        }
        .onChange(of: appState.listeningState) { newState in
            if newState == .listening {
                transcriptBuffer.clear()
            }
        }
    }
}
```

### Styling Constants

```swift
// Per UI Specification
extension Font {
    static let transcript = Font.system(size: 13, design: .monospaced)
}

extension Color {
    static let transcriptText = Color.secondary // Greyed
    static let transcriptBackground = Color(NSColor.textBackgroundColor).opacity(0.5)
}
```

---

## Dependencies

- Story 2.2 (Speech Recognition Service)
- Story 1.5 (Listening State Management)

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] Transcript scrolls automatically
- [ ] Rolling buffer limits text length
- [ ] Paused state stops updates
- [ ] Resume clears transcript
- [ ] Font matches specification
- [ ] Committed to Git
