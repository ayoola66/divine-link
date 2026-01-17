# Story 2.3: Custom Language Model for Bible Vocabulary

**Epic:** 2 - Transcription & Scripture Detection  
**Story ID:** 2.3  
**Status:** Not Started  
**Complexity:** Medium  

---

## User Story

**As a** developer,  
**I want** speech recognition biased toward Bible book names and theological terms,  
**so that** "Habakkuk" is recognised correctly instead of "have a cook".

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Custom language model created using SFCustomLanguageModelData | Model compiles without errors |
| 2 | Model includes all 66 Bible book names with high phrase counts | All books in phrase list |
| 3 | Model includes common variations (1 Corinthians, First Corinthians, I Corinthians) | Variations recognised correctly |
| 4 | Model includes custom pronunciations for difficult names | Habakkuk, Zephaniah tested |
| 5 | Model exported and compiled at app first launch | Model file created in App Support |
| 6 | TranscriptionService uses custom language model configuration | Recognition uses custom model |
| 7 | Model file stored in Application Support directory | Persistent storage location |
| 8 | Fallback to standard recognition if custom model fails | Graceful degradation |

---

## Technical Notes

### Custom Language Model Creation

```swift
import Speech

class BibleLanguageModel {
    private let modelIdentifier = "com.divinelink.bible-vocabulary"
    private let modelVersion = "1.0"
    
    func createLanguageModelData() -> SFCustomLanguageModelData {
        SFCustomLanguageModelData(
            locale: Locale(identifier: "en-GB"),
            identifier: modelIdentifier,
            version: modelVersion
        ) {
            // Old Testament Books
            SFCustomLanguageModelData.PhraseCount(phrase: "Genesis", count: 1000)
            SFCustomLanguageModelData.PhraseCount(phrase: "Exodus", count: 1000)
            SFCustomLanguageModelData.PhraseCount(phrase: "Leviticus", count: 1000)
            // ... all 66 books
            
            // Difficult pronunciations
            SFCustomLanguageModelData.PhraseCount(phrase: "Habakkuk", count: 1000)
            SFCustomLanguageModelData.PhraseCount(phrase: "Zephaniah", count: 1000)
            SFCustomLanguageModelData.PhraseCount(phrase: "Ecclesiastes", count: 1000)
            
            // Numbered book variations
            SFCustomLanguageModelData.PhraseCount(phrase: "First Corinthians", count: 500)
            SFCustomLanguageModelData.PhraseCount(phrase: "1 Corinthians", count: 500)
            SFCustomLanguageModelData.PhraseCount(phrase: "Second Timothy", count: 500)
            SFCustomLanguageModelData.PhraseCount(phrase: "2 Timothy", count: 500)
            
            // Common theological terms
            SFCustomLanguageModelData.PhraseCount(phrase: "justification", count: 300)
            SFCustomLanguageModelData.PhraseCount(phrase: "sanctification", count: 300)
            SFCustomLanguageModelData.PhraseCount(phrase: "propitiation", count: 300)
            
            // Custom pronunciations
            SFCustomLanguageModelData.CustomPronunciation(
                grapheme: "Habakkuk",
                phonemes: ["h æ b ə k ʌ k"]
            )
            SFCustomLanguageModelData.CustomPronunciation(
                grapheme: "Zephaniah",
                phonemes: ["z ɛ f ə n aɪ ə"]
            )
        }
    }
}
```

### Complete Book List

```swift
let bibleBooks = [
    // Old Testament (39)
    "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
    "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel",
    "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles",
    "Ezra", "Nehemiah", "Esther", "Job", "Psalms", "Proverbs",
    "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah",
    "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
    "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah",
    "Haggai", "Zechariah", "Malachi",
    
    // New Testament (27)
    "Matthew", "Mark", "Luke", "John", "Acts", "Romans",
    "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
    "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians",
    "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews",
    "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John",
    "Jude", "Revelation"
]
```

### Model Compilation & Storage

```swift
func prepareLanguageModel() async throws -> SFSpeechLanguageModelConfiguration {
    let modelData = createLanguageModelData()
    
    // Get Application Support directory
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let modelDir = appSupport.appendingPathComponent("DivineLink/LanguageModel")
    
    try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
    
    let dataURL = modelDir.appendingPathComponent("bible-vocabulary.bin")
    let compiledURL = modelDir.appendingPathComponent("compiled")
    
    // Export training data
    try await modelData.export(to: dataURL)
    
    // Prepare compiled model
    let config = SFSpeechLanguageModelConfiguration(modelID: modelIdentifier)
    
    try await SFSpeechLanguageModel.prepareCustomLanguageModel(
        for: dataURL,
        clientIdentifier: "com.divinelink",
        configuration: config
    )
    
    return config
}
```

### Integration with TranscriptionService

```swift
// In TranscriptionService
func startWithCustomModel(audioEngine: AVAudioEngine, modelConfig: SFSpeechLanguageModelConfiguration) throws {
    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    recognitionRequest?.customizedLanguageModel = modelConfig
    recognitionRequest?.requiresOnDeviceRecognition = true
    // ... rest of start logic
}
```

---

## Dependencies

- Story 2.2 (Speech Recognition Service)

---

## Definition of Done

- [ ] All 66 books included in model
- [ ] Common variations included
- [ ] Custom pronunciations for difficult names
- [ ] Model compiles and exports successfully
- [ ] Recognition accuracy improved for Bible terms
- [ ] Fallback works if model fails
- [ ] Committed to Git
