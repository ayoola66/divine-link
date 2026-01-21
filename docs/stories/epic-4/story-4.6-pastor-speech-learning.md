# Story 4.6: Pastor Speech Learning

**Epic:** 4 - Service Sessions & Pastor Profiles  
**Story ID:** 4.6  
**Status:** Not Started  
**Complexity:** Large  

---

## User Story

**As an** operator,  
**I want** the app to learn how each pastor pronounces words,  
**so that** detection accuracy improves over time for each speaker.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | When operator corrects a detection, correction is saved to pastor profile | Correction stored |
| 2 | Corrections are applied in real-time during detection | "Some" → "Psalms" works |
| 3 | Multiple pastors can have different corrections | Isolated per pastor |
| 4 | Correction UI available for operator to add/edit mappings | UI accessible |
| 5 | Most-used corrections applied with higher priority | Priority ordering |
| 6 | Corrections can be manually deleted | Remove works |
| 7 | Import/export corrections for backup | File operations work |

---

## Technical Notes

### Learning Flow

1. **Detection Phase**:
   - Speech: "Some 23 verse 1"
   - Detection fails (no book "Some")
   
2. **Manual Correction**:
   - Operator manually types "Psalms 23:1"
   - App detects the mismatch and offers: "Learn: 'Some' → 'Psalms' for Pastor John?"
   
3. **Apply Learning**:
   - Next time "Some" is detected with Pastor John active, auto-correct to "Psalms"
   - Then re-run detection with corrected text

### Correction Application

```swift
class SpeechCorrectionService {
    func apply(corrections: [SpeechCorrection], to text: String) -> String {
        var result = text
        
        // Sort by occurrences (most common first)
        let sorted = corrections.sorted { $0.occurrences > $1.occurrences }
        
        for correction in sorted {
            // Case-insensitive replacement
            result = result.replacingOccurrences(
                of: correction.heard,
                with: correction.corrected,
                options: .caseInsensitive
            )
        }
        
        return result
    }
}
```

### Integration with Detection Pipeline

```swift
// In DetectionPipeline
func processTranscript(_ transcript: String) {
    var correctedTranscript = transcript
    
    // Apply pastor-specific corrections if active
    if let pastorId = currentSession?.pastorId,
       let profile = pastorManager.profile(for: pastorId) {
        correctedTranscript = correctionService.apply(
            corrections: profile.speechCorrections,
            to: transcript
        )
    }
    
    // Now run detection on corrected text
    let detections = detector.detect(in: correctedTranscript)
    // ...
}
```

### Manual Correction UI

```swift
struct AddCorrectionSheet: View {
    @State private var heard: String = ""
    @State private var corrected: String = ""
    let pastor: PastorProfile
    
    var body: some View {
        Form {
            TextField("What you heard (e.g., 'Some')", text: $heard)
            TextField("Correct word (e.g., 'Psalms')", text: $corrected)
            
            Button("Save Correction") {
                // Add to pastor profile
            }
        }
    }
}
```

---

## Dependencies

- Story 4.5 (Pastor Profile Management)

---

## Definition of Done

- [ ] Corrections saved per pastor
- [ ] Applied during detection
- [ ] Manual add/edit/delete UI
- [ ] Import/export works
- [ ] Committed to Git
