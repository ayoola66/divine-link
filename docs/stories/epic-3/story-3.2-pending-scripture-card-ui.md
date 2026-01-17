# Story 3.2: Pending Scripture Card UI

**Epic:** 3 - Pending Buffer & ProPresenter Integration  
**Story ID:** 3.2  
**Status:** Not Started  
**Complexity:** Medium  

---

## User Story

**As an** operator,  
**I want** to see the detected scripture displayed clearly,  
**so that** I can verify it before pushing to the screen.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Zone 2 (centre) displays pending scripture card | Card visible in centre zone |
| 2 | Card shows: book, chapter, verse(s), full text, translation name | All elements displayed |
| 3 | Card has off-white background with blue scripture text | Colours match UI spec |
| 4 | Card shows "Detected Scripture (Pending)" label | Label visible at top of card |
| 5 | When no verse pending, zone shows empty state | Empty message displayed |
| 6 | Card has gold accent border when verse is pending | Gold border visible |
| 7 | Card displays confidence indicator | Visual confidence shown |

---

## Technical Notes

### PendingScriptureCard View

```swift
import SwiftUI

struct PendingScriptureCard: View {
    let verse: PendingVerse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header label
            Text("DETECTED SCRIPTURE (PENDING)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .tracking(1)
            
            // Reference
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.divineBlue)
                
                Text(verse.displayReference)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Confidence indicator
                ConfidenceIndicator(confidence: verse.confidence)
            }
            
            // Scripture text
            Text(verse.fullText)
                .font(.body)
                .foregroundColor(.divineBlue)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            // Translation
            Text(verse.translation)
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.divineGold, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}
```

### Empty State View

```swift
struct EmptyBufferView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("Listening for scriptures...")
                .font(.body)
                .foregroundColor(.secondary)
                .italic()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(Color.cardBackground.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
```

### Confidence Indicator

```swift
struct ConfidenceIndicator: View {
    let confidence: Float
    
    private var level: ConfidenceLevel {
        if confidence >= 0.9 { return .high }
        if confidence >= 0.7 { return .medium }
        return .low
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(index < level.bars ? level.color : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
        .help("Confidence: \(Int(confidence * 100))%")
    }
    
    enum ConfidenceLevel {
        case high, medium, low
        
        var bars: Int {
            switch self {
            case .high: return 3
            case .medium: return 2
            case .low: return 1
            }
        }
        
        var color: Color {
            switch self {
            case .high: return .green
            case .medium: return .orange
            case .low: return .red
            }
        }
    }
}
```

### Colour Constants

```swift
extension Color {
    static let divineBlue = Color(hex: "#2563EB")     // Scripture text
    static let divineGold = Color(hex: "#D4AF37")     // Pending border
    static let cardBackground = Color(hex: "#F8F8F8") // Off-white
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}
```

### Zone 2 Container

```swift
struct Zone2_PendingBuffer: View {
    @EnvironmentObject var bufferManager: BufferManager
    
    var body: some View {
        Group {
            if let verse = bufferManager.currentVerse {
                PendingScriptureCard(verse: verse)
            } else {
                EmptyBufferView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.2), value: bufferManager.currentVerse?.id)
    }
}
```

---

## Dependencies

- Story 3.1 (Pending Buffer Data Model)

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] Card displays all required elements
- [ ] Empty state shows when no verses
- [ ] Colours match UI specification
- [ ] Gold border visible on pending card
- [ ] Confidence indicator works
- [ ] Committed to Git
