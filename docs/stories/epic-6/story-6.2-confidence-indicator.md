# Story 6.2: Detection Confidence Indicator

**Epic:** 6 - Operator Safety & Detection Confidence  
**Story ID:** 6.2  
**Status:** Not Started  
**Complexity:** Medium  
**Priority:** P0 (Key User Trust Feature)

---

## User Story

**As an** operator reviewing detected scriptures,  
**I want** to see how confident the AI is about each detection,  
**so that** I can make informed decisions about whether to push a verse or wait for clarification.

---

## Background

The current system detects scripture references and displays them, but operators have no visibility into:
- How certain the AI is about the detection
- Whether the verse was explicitly spoken vs. inferred
- If there are alternative interpretations

This creates risk in live situations where operators may push uncertain detections. A confidence indicator solves this by providing "graceful failure" - when detection is uncertain, operators know to be cautious.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Each detected verse shows confidence level | Visual indicator present |
| 2 | Three levels displayed: High, Medium, Low | Distinct visual for each |
| 3 | High confidence: solid green indicator | ≥80% = green |
| 4 | Medium confidence: yellow/amber indicator | 50-79% = yellow |
| 5 | Low confidence: orange/red indicator with caution | <50% = orange |
| 6 | Confidence percentage available on hover | Tooltip shows "85% confident" |
| 7 | Low-confidence verses have distinct styling | Muted colours or border |
| 8 | Optional: Auto-hold low-confidence verses | Don't auto-push if <50% |
| 9 | Confidence visible in Scripture Card UI | Integrated into existing card |

---

## Technical Notes

### Confidence Scoring Algorithm

The confidence score should factor in:

1. **Reference Clarity (40%)**: How explicit was the reference?
   - Explicit ("John chapter 3 verse 16") = 100%
   - Partial ("John 3:16") = 90%
   - Informal ("John 3 16") = 70%
   - Inferred ("For God so loved the world") = 50%

2. **Speech Recognition Confidence (30%)**: Apple Speech API confidence
   - Use SFSpeechRecognitionResult `confidence` property
   - Higher transcription confidence = higher overall confidence

3. **Context Match (20%)**: How well does the detected text match verse content?
   - Word overlap percentage with actual verse text
   - Fuzzy matching score

4. **Verse Existence (10%)**: Does the verse actually exist?
   - Valid book/chapter/verse = 100%
   - Edge of chapter (could be off by 1) = 80%

### Implementation

#### DetectionConfidence Model

```swift
// DetectionConfidence.swift
struct DetectionConfidence {
    let referenceClarity: Double      // 0.0 - 1.0
    let speechConfidence: Double      // 0.0 - 1.0
    let contextMatch: Double          // 0.0 - 1.0
    let verseExistence: Double        // 0.0 - 1.0
    
    var overall: Double {
        return (referenceClarity * 0.4) +
               (speechConfidence * 0.3) +
               (contextMatch * 0.2) +
               (verseExistence * 0.1)
    }
    
    var level: ConfidenceLevel {
        switch overall {
        case 0.8...1.0: return .high
        case 0.5..<0.8: return .medium
        default: return .low
        }
    }
    
    var percentage: Int {
        return Int(overall * 100)
    }
}

enum ConfidenceLevel: String {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    var colour: Color {
        switch self {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .high: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "questionmark.circle.fill"
        }
    }
}
```

#### Update ScriptureMatch Model

```swift
// ScriptureMatch.swift (updated)
struct ScriptureMatch {
    let book: String
    let chapter: Int
    let verse: Int
    let endVerse: Int?
    let verseText: String
    let rawTranscript: String
    let matchedPattern: String
    let confidence: DetectionConfidence  // NEW
    let timestamp: Date
}
```

#### Confidence Calculation in Detection Engine

```swift
// ScriptureDetectionEngine.swift
func calculateConfidence(
    for match: ScriptureMatch,
    transcriptionConfidence: Float,
    patternType: PatternType
) -> DetectionConfidence {
    
    // 1. Reference Clarity based on pattern type
    let referenceClarity: Double = {
        switch patternType {
        case .explicit: return 1.0      // "John chapter 3 verse 16"
        case .standard: return 0.9      // "John 3:16"
        case .informal: return 0.7      // "John 3 16"
        case .implicit: return 0.5      // Famous verse by content
        }
    }()
    
    // 2. Speech Recognition Confidence
    let speechConfidence = Double(transcriptionConfidence)
    
    // 3. Context Match - compare transcript to verse text
    let contextMatch = calculateTextSimilarity(
        transcript: match.rawTranscript,
        verseText: match.verseText
    )
    
    // 4. Verse Existence
    let verseExistence: Double = match.verseText.isEmpty ? 0.0 : 1.0
    
    return DetectionConfidence(
        referenceClarity: referenceClarity,
        speechConfidence: speechConfidence,
        contextMatch: contextMatch,
        verseExistence: verseExistence
    )
}

private func calculateTextSimilarity(transcript: String, verseText: String) -> Double {
    let transcriptWords = Set(transcript.lowercased().split(separator: " ").map(String.init))
    let verseWords = Set(verseText.lowercased().split(separator: " ").map(String.init))
    
    let intersection = transcriptWords.intersection(verseWords)
    let union = transcriptWords.union(verseWords)
    
    guard !union.isEmpty else { return 0.0 }
    return Double(intersection.count) / Double(union.count)
}
```

### UI Implementation

#### Confidence Indicator Component

```swift
// ConfidenceIndicatorView.swift
struct ConfidenceIndicatorView: View {
    let confidence: DetectionConfidence
    @State private var showTooltip = false
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: confidence.level.icon)
                .foregroundColor(confidence.level.colour)
                .font(.system(size: 14))
            
            Text(confidence.level.rawValue)
                .font(.caption)
                .foregroundColor(confidence.level.colour)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(confidence.level.colour.opacity(0.15))
        .cornerRadius(8)
        .help("\(confidence.percentage)% confident")  // Tooltip
        .onHover { hovering in
            showTooltip = hovering
        }
    }
}
```

#### Updated Scripture Card

```swift
// ScriptureCardView.swift (updated)
struct ScriptureCardView: View {
    let match: ScriptureMatch
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with reference and confidence
            HStack {
                Text(match.reference)
                    .font(.headline)
                
                Spacer()
                
                ConfidenceIndicatorView(confidence: match.confidence)
            }
            
            // Verse text with conditional styling
            Text(match.verseText)
                .font(.body)
                .foregroundColor(match.confidence.level == .low ? .secondary : .primary)
            
            // Low confidence warning
            if match.confidence.level == .low {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Low confidence - please verify before pushing")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(12)
    }
    
    var cardBackground: Color {
        switch match.confidence.level {
        case .high: return Color(.controlBackgroundColor)
        case .medium: return Color.yellow.opacity(0.05)
        case .low: return Color.orange.opacity(0.1)
        }
    }
}
```

### Settings Option

```swift
// Settings: Detection tab
Toggle("Auto-hold low-confidence detections", isOn: $holdLowConfidence)
    .help("Require manual confirmation for verses with <50% confidence")

Slider(value: $confidenceThreshold, in: 0.3...0.9) {
    Text("Minimum confidence threshold: \(Int(confidenceThreshold * 100))%")
}
```

---

## Visual Design

### Confidence Indicators

```
┌──────────────────────────────────────────────────────┐
│ John 3:16                    [✓ High Confidence]     │
│                                                      │
│ For God so loved the world, that he gave his only    │
│ begotten Son, that whosoever believeth in him        │
│ should not perish, but have everlasting life.        │
│                                                      │
│ [ Push ]  [ Ignore ]                                 │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│ Romans 8:28                  [! Medium Confidence]   │
│                                                      │
│ And we know that all things work together for        │
│ good to them that love God...                        │
│                                                      │
│ [ Push ]  [ Ignore ]                                 │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│ Philippians 4:13             [? Low Confidence]      │
│ ─────────────────────────────────────────────────    │
│ I can do all things through Christ which             │  (muted text)
│ strengtheneth me.                                    │
│                                                      │
│ ⚠️ Low confidence - please verify before pushing     │
│                                                      │
│ [ Push ]  [ Ignore ]                                 │
└──────────────────────────────────────────────────────┘
```

### Colour Scheme

| Level | Colour | Hex | Icon |
|-------|--------|-----|------|
| High | Green | #34C759 | checkmark.circle.fill |
| Medium | Yellow/Amber | #FFCC00 | exclamationmark.circle.fill |
| Low | Orange | #FF9500 | questionmark.circle.fill |

---

## Dependencies

- Story 2.5 (Scripture Detection Engine) ✅ Complete
- Story 3.2 (Scripture Card UI) ✅ Complete

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] DetectionConfidence model implemented
- [ ] Confidence calculated for all detections
- [ ] Three visual levels (High/Medium/Low) displayed
- [ ] Low-confidence styling applied (muted colours)
- [ ] Tooltip shows percentage on hover
- [ ] Settings option for auto-hold low confidence
- [ ] Unit tests for confidence calculation
- [ ] Committed to Git

---

## Testing Scenarios

1. **Explicit Reference**: "John chapter 3 verse 16" → High confidence (90%+)
2. **Standard Reference**: "John 3:16" → High confidence (85%+)
3. **Informal Reference**: "John 3 16" → Medium confidence (65-80%)
4. **Implicit/Famous Verse**: "For God so loved" → Medium/Low (50-65%)
5. **Garbled Speech**: Unclear reference → Low confidence (<50%)
6. **Invalid Verse**: Reference that doesn't exist → Very low/error

---

## Enhanced Feature: Live Confidence Visualiser

**Professor BMAD Recommendation:**
> "Produce a UI prototype that shows the transcription 'Live' but highlights references in color based on confidence. This makes the operator feel like the AI is 'thinking' and allows them to prepare for a push before the full sentence is even finished."

### Live Transcription Panel

```
┌──────────────────────────────────────────────────────────────────┐
│ 🎤 Live Transcription                                    [●REC]  │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│ "...and if you turn with me to [John 3:16] you will see          │
│  that God loved the world so much that he..."                    │
│                                          ▲                        │
│                                    [HIGH 92%]                     │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### Colour Highlighting in Transcript

As the pastor speaks, detected scripture references are highlighted in real-time:

- **Green highlight**: High confidence reference detected
- **Yellow highlight**: Medium confidence (possible reference)
- **Orange underline**: Low confidence (ambiguous)

### Implementation

```swift
// LiveTranscriptView.swift
struct LiveTranscriptView: View {
    @ObservedObject var transcriptionService: TranscriptionService
    @ObservedObject var detectionEngine: ScriptureDetectionEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with recording indicator
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
                Text("Live Transcription")
                    .font(.headline)
                Spacer()
                RecordingIndicator()
            }
            
            // Highlighted transcript
            AttributedTranscriptView(
                text: transcriptionService.currentTranscript,
                detections: detectionEngine.liveDetections
            )
            .font(.body)
            .padding()
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct AttributedTranscriptView: View {
    let text: String
    let detections: [LiveDetection]
    
    var body: some View {
        // Build attributed string with highlights
        Text(buildAttributedText())
    }
    
    func buildAttributedText() -> AttributedString {
        var attributed = AttributedString(text)
        
        for detection in detections {
            if let range = attributed.range(of: detection.matchedText) {
                switch detection.confidence.level {
                case .high:
                    attributed[range].backgroundColor = .green.opacity(0.3)
                case .medium:
                    attributed[range].backgroundColor = .yellow.opacity(0.3)
                case .low:
                    attributed[range].underlineStyle = .single
                    attributed[range].underlineColor = .orange
                }
            }
        }
        
        return attributed
    }
}
```

### Benefits

1. **Operator Preparation**: See references before they're fully spoken
2. **AI Transparency**: Operators understand how the system "thinks"
3. **Faster Push**: Can prepare to push while pastor still speaking
4. **Error Prevention**: Spot low-confidence detections early

---

## Future Enhancements

- Machine learning model to improve confidence scoring over time
- User feedback loop (mark detections as correct/incorrect)
- Pastor-specific confidence adjustments based on speech patterns
- Confidence history analytics
- Real-time highlighting refinement as more words are spoken
