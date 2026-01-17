# Technical Challenges Analysis - Divine Link

**Document Type:** Brainstorming Output  
**Analyst:** Mary (BMAD Business Analyst)  
**Date:** January 2026  
**Technique:** SCAMPER + What-If Analysis

---

## Challenge Matrix

| # | Challenge Area | Specific Challenge | Severity | Status |
|---|----------------|-------------------|----------|--------|
| 1 | Speech Recognition | Accent/dialect variations | High | Mitigation identified |
| 2 | Speech Recognition | Background noise interference | High | Mitigation identified |
| 3 | Speech Recognition | Multiple speakers | Medium | Phase 2 feature |
| 4 | Reference Parsing | Ambiguous book names | Medium | Mitigation identified |
| 5 | Reference Parsing | Non-standard formats | High | Layered solution |
| 6 | Reference Parsing | Verse ranges/spans | Medium | Parsing logic defined |
| 7 | Latency | <1 second requirement | High | Budget allocated |
| 8 | ProPresenter | Network connectivity | Medium | Discovery + fallback |
| 9 | ProPresenter | Version compatibility | Medium | Abstraction layer |
| 10 | Audio Capture | Third-party driver requirement | Medium | Onboarding wizard |
| 11 | Performance | 90+ minute operation | High | Memory management |
| 12 | UX | Pending buffer overwhelm | Medium | Confidence thresholds |
| 13 | Database | Fast fuzzy lookup | Low | SQLite FTS5 |
| 14 | Reliability | Crash during live service | Critical | Extensive testing |

---

## Critical Challenge 1: Speech Recognition Accuracy

### Problem
Preachers have diverse accents (American, British, African, Caribbean, Indian). Apple's Speech framework may struggle with non-standard pronunciations.

### Impact
- Detection accuracy could drop to 60-70% for strong accents
- User frustration and abandonment
- Missed scripture references

### Mitigation Strategy

```swift
// 1. Heavy vocabulary biasing
let biasedModel = SFCustomLanguageModelData(
    locale: Locale(identifier: "en_GB"),
    identifier: "com.divinelink.bible"
) {
    // High-frequency Bible books
    SFCustomLanguageModelData.PhraseCount(phrase: "Genesis", count: 1000)
    SFCustomLanguageModelData.PhraseCount(phrase: "Revelation", count: 1000)
    // ... all 66 books
    
    // Custom pronunciations
    SFCustomLanguageModelData.CustomPronunciation(
        grapheme: "Habakkuk",
        phonemes: ["h æ b ə k ʌ k"]
    )
}

// 2. Fallback cloud ASR (optional)
if localAccuracy < 0.8 {
    switchToWhisperAPI()
}
```

### Acceptance Criteria
- >90% accuracy on test corpus with standard accents
- >80% accuracy on diverse accent test corpus
- User can toggle cloud fallback in settings

---

## Critical Challenge 2: Non-Standard Reference Formats

### Problem
Preachers reference scriptures in many ways:
- "John 3:16" (standard)
- "The third chapter of John's Gospel" (verbose)
- "Paul's letter to the Romans, chapter 8" (attributed)
- "The love chapter" (implicit - Phase 2+)

### Parsing Layers

#### Layer 1: Standard Patterns (MVP)
```regex
# Basic: John 3:16
(\d?\s?[A-Za-z]+)\s+(\d+):(\d+)

# With range: John 3:16-18
(\d?\s?[A-Za-z]+)\s+(\d+):(\d+)-(\d+)

# Chapter only: Romans 8
(\d?\s?[A-Za-z]+)\s+(\d+)

# Verbal: John chapter 3 verse 16
(\d?\s?[A-Za-z]+)\s+chapter\s+(\d+)\s+verse\s+(\d+)
```

#### Layer 2: Verbose Patterns (MVP+)
```regex
# Book of X: book of John chapter 3
(book\s+of\s+)?([A-Za-z]+),?\s*(chapter)?\s*(\d+)

# Gospel of X: gospel of John
(gospel\s+(of|according\s+to)\s+)?([A-Za-z]+)

# Paul's letter: Paul's letter to the Romans
(paul's\s+)?(first|second|1st|2nd)?\s*(letter|epistle)\s+to\s+(the\s+)?([A-Za-z]+)
```

#### Layer 3: Implicit References (Phase 2+)
```yaml
implicit_mappings:
  "love chapter": "1 Corinthians 13"
  "faith chapter": "Hebrews 11"
  "shepherd psalm": "Psalm 23"
  "lord's prayer": "Matthew 6:9-13"
  "beatitudes": "Matthew 5:3-12"
  "armour of god": "Ephesians 6:10-18"
  "fruit of the spirit": "Galatians 5:22-23"
```

### Implementation
```swift
class ScriptureDetector {
    private let standardPatterns: [NSRegularExpression]
    private let verbosePatterns: [NSRegularExpression]
    private let bookNameNormaliser: BookNameNormaliser
    
    func detect(in transcript: String) -> [DetectedReference] {
        var results: [DetectedReference] = []
        
        // Layer 1: Standard patterns
        for pattern in standardPatterns {
            results.append(contentsOf: matchPattern(pattern, in: transcript))
        }
        
        // Layer 2: Verbose patterns
        for pattern in verbosePatterns {
            results.append(contentsOf: matchPattern(pattern, in: transcript))
        }
        
        // Normalise book names (Revelations → Revelation)
        return results.map { bookNameNormaliser.normalise($0) }
    }
}
```

---

## Critical Challenge 3: Audio Capture

### Options Analysis

| Method | Setup Complexity | Audio Quality | Cost | Recommended For |
|--------|------------------|---------------|------|-----------------|
| Built-in Microphone | ⭐ Easy | ⭐⭐ Fair | Free | Testing/casual use |
| External Microphone | ⭐⭐ Medium | ⭐⭐⭐ Good | £50-200 | Small venues |
| BlackHole + System Audio | ⭐⭐⭐ Complex | ⭐⭐⭐⭐ Excellent | Free | Primary recommendation |
| Loopback | ⭐⭐ Medium | ⭐⭐⭐⭐ Excellent | £109 | Pro users |
| Audio Interface Direct | ⭐⭐⭐⭐ Expert | ⭐⭐⭐⭐⭐ Best | £100+ | Large venues |

### Onboarding Wizard Design

```
Step 1: Audio Source Selection
├── Option A: Microphone (simple)
│   └── Select input device → Done
├── Option B: System Audio (recommended)
│   ├── Check for BlackHole installation
│   ├── If not installed → Guide installation
│   ├── Configure multi-output device
│   └── Test audio capture → Done
└── Option C: Professional (advanced)
    └── Show audio interface guide → Done
```

### BlackHole Integration
```swift
class AudioCaptureManager {
    func detectBlackHoleInstallation() -> Bool {
        let devices = AVCaptureDevice.devices(for: .audio)
        return devices.contains { $0.localizedName.contains("BlackHole") }
    }
    
    func promptBlackHoleInstallation() {
        // Open BlackHole download page
        NSWorkspace.shared.open(URL(string: "https://existential.audio/blackhole/")!)
    }
}
```

---

## Critical Challenge 4: Latency Management

### Budget Allocation (1000ms total)

| Component | Budget | Optimisation Strategy |
|-----------|--------|----------------------|
| Audio buffer | 100ms | Minimum viable buffer size |
| Speech-to-text | 400ms | Streaming mode; no batch wait |
| Reference parsing | 100ms | Pre-compiled regex; async |
| Database lookup | 50ms | In-memory cache; indexed |
| UI update | 50ms | Debounced; main thread |
| Safety margin | 300ms | Error recovery buffer |

### Pipeline Architecture
```
Audio Input (streaming)
    ↓ [100ms buffer]
Speech Recogniser (streaming results)
    ↓ [partial results every 200-400ms]
Reference Detector (async)
    ↓ [pattern matching: 50-100ms]
Bible Lookup (cached)
    ↓ [SQLite query: 10-50ms]
Pending Buffer UI
    ↓ [SwiftUI update: 16-50ms]
Ready for operator approval
```

### Monitoring
```swift
class LatencyMonitor {
    func measurePipelineLatency() -> TimeInterval {
        let start = CFAbsoluteTimeGetCurrent()
        // ... pipeline execution ...
        let end = CFAbsoluteTimeGetCurrent()
        
        let latency = end - start
        if latency > 1.0 {
            logger.warning("Latency exceeded 1s: \(latency)s")
        }
        return latency
    }
}
```

---

## Critical Challenge 5: Service Reliability

### Requirements
- 90-120 minute continuous operation
- Zero crashes during live service
- No memory leaks or performance degradation
- Graceful error recovery

### Memory Management
```swift
class TranscriptionBuffer {
    private let maxBufferSize = 1000 // Last 1000 words
    private var buffer: [TranscriptionSegment] = []
    
    func append(_ segment: TranscriptionSegment) {
        buffer.append(segment)
        if buffer.count > maxBufferSize {
            buffer.removeFirst(buffer.count - maxBufferSize)
        }
    }
}
```

### Error Recovery
```swift
class ReliabilityManager {
    func handleSpeechRecogniserError(_ error: Error) {
        logger.error("Speech recogniser error: \(error)")
        
        switch error {
        case let speechError as SFSpeechRecognizerError:
            if speechError.code == .notAuthorized {
                showPermissionAlert()
            } else {
                restartRecogniser()
            }
        default:
            restartRecogniser()
        }
    }
    
    private func restartRecogniser() {
        // Graceful restart with 1 second delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.speechService.restart()
        }
    }
}
```

### Testing Requirements

| Test Type | Duration | Frequency | Pass Criteria |
|-----------|----------|-----------|---------------|
| Stress test | 2 hours | Weekly | No crashes, memory stable |
| Memory profiling | 1 hour | Per release | No leaks >1MB |
| Network failure | 30 min | Per release | Graceful recovery |
| CPU throttling | 1 hour | Per release | Latency <2s under load |
| Fuzzing | 1 hour | Per release | No crashes on bad input |

---

## Risk Register

| Risk | Probability | Impact | Mitigation | Owner |
|------|-------------|--------|------------|-------|
| Accent accuracy issues | Medium | High | Cloud fallback + vocabulary biasing | Dev |
| ProPresenter API changes | Low | Medium | Abstraction layer + version checks | Dev |
| BlackHole installation friction | Medium | Medium | In-app guide + microphone fallback | UX |
| Memory leaks during long services | Low | Critical | Profiling + rolling buffers | Dev |
| Network disconnection mid-service | Medium | High | Reconnection logic + offline queue | Dev |

---

## Recommendations

1. **Prioritise local accuracy** - Heavy investment in SFCustomLanguageModelData biasing before considering cloud fallback
2. **Layered parsing approach** - Start with standard patterns; add verbose parsing incrementally
3. **Comprehensive audio onboarding** - Clear wizard with BlackHole installation guidance
4. **Latency monitoring** - Built-in performance metrics from day one
5. **Reliability testing** - 2-hour stress tests as part of release criteria

---

**Document Version:** 1.0  
**Next Phase:** PRD Generation with PM Agent
