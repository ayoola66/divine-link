# Story 2.6: Detection Pipeline Integration

**Epic:** 2 - Transcription & Scripture Detection  
**Story ID:** 2.6  
**Status:** Complete  
**Complexity:** Small  

---

## User Story

**As a** developer,  
**I want** the transcription and detection services connected,  
**so that** detected scriptures flow to the pending buffer.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | TranscriptionService output feeds into ScriptureDetectorService | Transcription triggers detection |
| 2 | Detected references trigger BibleService lookup | Verse text retrieved |
| 3 | Successful lookups create PendingVerse objects | PendingVerse created with full data |
| 4 | PendingVerse includes: reference, fullText, timestamp, confidence | All fields populated |
| 5 | PendingVerse objects are added to BufferManager | Buffer receives new verses |
| 6 | Pipeline handles rapid successive detections | Queue, don't overwrite |
| 7 | Pipeline logs detections for debugging | Console/log output visible |

---

## Technical Notes

### PendingVerse Model

```swift
struct PendingVerse: Identifiable {
    let id = UUID()
    let reference: ScriptureReference
    let fullText: String
    let translation: String = "Berean Standard Bible"
    let timestamp: Date
    let confidence: Float
    
    var displayReference: String {
        reference.displayReference
    }
}
```

### Detection Pipeline Coordinator

```swift
import Combine

class DetectionPipeline: ObservableObject {
    private let transcriptionService: TranscriptionService
    private let detectorService: ScriptureDetectorService
    private let bibleService: BibleService
    private let bufferManager: BufferManager
    
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.divinelink", category: "Detection")
    
    init(
        transcriptionService: TranscriptionService,
        detectorService: ScriptureDetectorService,
        bibleService: BibleService,
        bufferManager: BufferManager
    ) {
        self.transcriptionService = transcriptionService
        self.detectorService = detectorService
        self.bibleService = bibleService
        self.bufferManager = bufferManager
        
        setupPipeline()
    }
    
    private func setupPipeline() {
        transcriptionService.transcriptPublisher
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] transcript in
                self?.processTranscript(transcript)
            }
            .store(in: &cancellables)
    }
    
    private func processTranscript(_ transcript: String) {
        // Detect scripture references
        let detections = detectorService.detect(in: transcript)
        
        for reference in detections {
            logger.info("Detected: \(reference.displayReference)")
            
            // Look up verse text
            if let verseText = lookupVerse(reference) {
                let pendingVerse = PendingVerse(
                    reference: reference,
                    fullText: verseText,
                    timestamp: Date(),
                    confidence: reference.confidence
                )
                
                // Add to buffer
                bufferManager.add(pendingVerse)
                logger.info("Added to buffer: \(reference.displayReference)")
            } else {
                logger.warning("Verse not found: \(reference.displayReference)")
            }
        }
    }
    
    private func lookupVerse(_ reference: ScriptureReference) -> String? {
        if let endVerse = reference.verseEnd {
            return bibleService.getVerseRange(
                book: reference.book,
                chapter: reference.chapter,
                startVerse: reference.verseStart,
                endVerse: endVerse
            )
        } else {
            return bibleService.getVerse(
                book: reference.book,
                chapter: reference.chapter,
                verse: reference.verseStart
            )
        }
    }
}
```

### BufferManager (Placeholder for Story 3.1)

```swift
class BufferManager: ObservableObject {
    @Published var pendingVerses: [PendingVerse] = []
    
    func add(_ verse: PendingVerse) {
        pendingVerses.append(verse)
    }
    
    var currentVerse: PendingVerse? {
        pendingVerses.first
    }
}
```

### Logging Setup

```swift
import os

extension Logger {
    static let detection = Logger(subsystem: "com.divinelink", category: "Detection")
    static let transcription = Logger(subsystem: "com.divinelink", category: "Transcription")
    static let propresenter = Logger(subsystem: "com.divinelink", category: "ProPresenter")
}

// Usage
Logger.detection.info("Detected: \(reference.displayReference)")
Logger.detection.error("Lookup failed: \(error.localizedDescription)")
```

### Integration in App

```swift
@main
struct DivineLink: App {
    @StateObject private var pipeline: DetectionPipeline
    
    init() {
        let transcription = TranscriptionService()
        let detector = ScriptureDetectorService()
        let bible = try! BibleService()
        let buffer = BufferManager()
        
        _pipeline = StateObject(wrappedValue: DetectionPipeline(
            transcriptionService: transcription,
            detectorService: detector,
            bibleService: bible,
            bufferManager: buffer
        ))
    }
    
    var body: some Scene {
        // ...
    }
}
```

---

## Dependencies

- Story 2.1 (Bible Database)
- Story 2.2 (Speech Recognition Service)
- Story 2.5 (Scripture Detection Engine)

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] Pipeline connects all services
- [ ] Detected verses appear in buffer
- [ ] Logging visible in Console.app
- [ ] No crashes on rapid input
- [ ] Committed to Git
