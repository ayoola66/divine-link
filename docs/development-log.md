# Divine Link - Development Log

This document tracks issues encountered, fixes applied, and technical decisions made during development.

---

## Log Format

Each entry follows this format:
```
### [DATE] - Brief Title
**Type:** Bug | Issue | Decision | Enhancement | Investigation
**Status:** Open | Resolved | Investigating | Deferred
**Severity:** Critical | High | Medium | Low
**Related:** Story/File references

**Problem:** Description of the issue
**Cause:** Root cause (if known)
**Solution:** How it was fixed
**Notes:** Additional context
```

---

## Active Issues

### [2026-01-22] - Bible Database Incomplete (ASV/WEB)
**Type:** Issue  
**Status:** Open  
**Severity:** Medium  
**Related:** Story 2.1, Story 2.7, `scripts/repair_bible_database.py`

**Problem:**  
The Bible database has incomplete data for ASV and WEB translations:
- KJV: 24,328 verses (mostly complete)
- ASV: 9,848 verses (incomplete - should be ~31,000)
- WEB: 9,010 verses (incomplete - should be ~31,000)

**Cause:**  
1. API fetch failures during initial build (empty JSON responses)
2. Database lock error during repair script execution:
   ```
   sqlite3.OperationalError: database is locked
   ```

**Solution:** Pending - Story 2.7 will address full database validation and repair

**Notes:**  
- KJV is the primary translation and works correctly
- Log files: `scripts/bible_build.log`, `scripts/bible_repair.log`

---

## Resolved Issues

### [2026-01-22] - "Philippines" Country Not Mapping to Philippians
**Type:** Bug  
**Status:** Resolved  
**Severity:** Medium  
**Related:** `ScriptureDetectorService.swift`, `BibleVocabularyData.swift`

**Problem:**  
When pastor says "Philippians", speech recognition sometimes outputs "Philippines" (the country), which was not being detected as a valid book name.

**Cause:**  
Book name mappings did not include country name variations.

**Solution:**  
Added to `bookMappings`:
```swift
"philippines": "Philippians",
"philippine": "Philippians",
```

---

### [2026-01-22] - Leading Prepositions Captured in Book Name
**Type:** Bug  
**Status:** Resolved  
**Severity:** High  
**Related:** `ScriptureDetectorService.swift:parseMatch()`

**Problem:**  
When pastor says "open our Bible to Exodus 12 verse 6", the detector was capturing "to Exodus" instead of just "Exodus", causing lookup failure.

**Cause:**  
Regex pattern was capturing words before the book name as part of the match.

**Solution:**  
Added preposition stripping in `parseMatch()`:
```swift
let prepositions = ["to", "in", "from", "the", "of", "at", "on", "for", "by", "into", "unto", "about", "through"]
for prep in prepositions {
    let prefix = prep + " "
    if rawBook.lowercased().hasPrefix(prefix) {
        rawBook = String(rawBook.dropFirst(prefix.count))
        break
    }
}
```

---

### [2026-01-22] - Invalid Chapter Detection (Philippians 6:7)
**Type:** Bug  
**Status:** Resolved  
**Severity:** High  
**Related:** `BibleService.swift`, `DetectionPipeline.swift`

**Problem:**  
When speech produced "Philippians 6:7" (Philippians only has 4 chapters), the app was showing "[Verse text not available]" instead of rejecting the invalid reference.

**Cause:**  
No validation that the chapter number exists for the given book.

**Solution:**  
1. Added `bookChapterCounts` cache in `BibleService.swift`
2. Added `isValidChapter()` validation function
3. Modified `DetectionPipeline.processDetection()` to reject invalid detections:
```swift
guard let verseText = bible.getVerseText(from: detection.reference) else {
    Logger.pipeline.warning("Rejected invalid detection: \(detection.displayReference)")
    return // REJECT instead of showing placeholder
}
```

---

### [2026-01-22] - Pushed Verses Being Removed from List
**Type:** Bug  
**Status:** Resolved  
**Severity:** Medium  
**Related:** `MainView.swift`, `BufferManager.swift`

**Problem:**  
When a verse was pushed to ProPresenter, it was removed from the pending list, making it impossible to push again if needed.

**Cause:**  
Original design removed verses on push. User feedback indicated this was undesirable.

**Solution:**  
1. Added `pushCount` and `isPushed` properties to `PendingVerse`
2. Changed `pushVerse()` to call `markAsPushed()` instead of `remove()`
3. Added visual indicators:
   - Green background for pushed verses
   - Checkmark icon
   - Push count badge (×2, ×3, etc.)
4. Added explicit delete button for manual removal

---

### [2026-01-22] - Nonsensical Correction Suggestions
**Type:** Bug  
**Status:** Resolved  
**Severity:** Medium  
**Related:** `MainView.swift:processEditedTranscript()`

**Problem:**  
Correction dialog was suggesting nonsensical replacements like "let's" → "Philippians".

**Cause:**  
All changed words were being considered as potential book name corrections, including common words.

**Solution:**  
Added ignore list for common words:
```swift
let ignoreWords = Set(["let's", "lets", "the", "to", "our", "a", "an", "in", "on", "of", 
    "for", "and", "or", "is", "it", "we", "i", "you", "he", "she", "they", 
    "this", "that", "be", "at", "as", "by", "from", "with", "open", "bible", 
    "chapter", "verse", "turn", "read", "go"])
```
Also added Cancel button to the dialog.

---

### [2026-01-22] - Bible Database Loading Indicator Missing
**Type:** Enhancement  
**Status:** Resolved  
**Severity:** Low  
**Related:** `BibleService.swift`, `MainView.swift`

**Problem:**  
Users didn't know if the app was loading the Bible database, leading to confusion when detection didn't work immediately.

**Solution:**  
1. Added `isLoading` and `loadingProgress` properties to `BibleService`
2. Added loading overlay in `MainView`:
```swift
.overlay {
    if pipeline.bible.isLoading {
        ZStack {
            Color.black.opacity(0.6)
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5).tint(.white)
                Text("Loading Bible Database")
                Text(pipeline.bible.loadingProgress)
            }
        }
    }
}
```

---

### [2026-01-22] - "Filipinos" Mishearing for Philippians
**Type:** Bug  
**Status:** Resolved  
**Severity:** Medium  
**Related:** `ScriptureDetectorService.swift`

**Problem:**  
Speech recognition was outputting "Filipinos" when pastor said "Philippians".

**Cause:**  
Common speech-to-text error not in book mappings.

**Solution:**  
Added mappings:
```swift
"filipinos": "Philippians",
"filipino": "Philippians",
"philipians": "Philippians",
"phillipians": "Philippians",
```

---

### [2026-01-21] - Space Key Toggling Listening During Edit
**Type:** Bug  
**Status:** Resolved  
**Severity:** Medium  
**Related:** `MainView.swift`

**Problem:**  
When editing the transcript, pressing space to type words would toggle listening on/off.

**Cause:**  
Keyboard shortcut handler wasn't checking if text field was focused.

**Solution:**  
Added check for editing state:
```swift
.onKeyPress(.space) {
    guard !isEditingTranscript else { return .ignored }
    toggleListening()
    return .handled
}
```

---

### [2026-01-21] - Verbal Pattern Not Matching Number Words
**Type:** Bug  
**Status:** Resolved  
**Severity:** High  
**Related:** `ScriptureDetectorService.swift`

**Problem:**  
"Philippians three seven" was being parsed as 6:7 instead of 3:7.

**Cause:**  
Number word conversion was incorrect - "three seven" was being treated as a single number.

**Solution:**  
1. Added `spokenWords` pattern for natural number speech
2. Improved number word parsing to handle separate chapter and verse words
3. Added comprehensive number word dictionary (1-50 + ordinals)

---

### [2026-01-21] - Song of Solomon Not Detected
**Type:** Bug  
**Status:** Resolved  
**Severity:** Low  
**Related:** `ScriptureDetectorService.swift`

**Problem:**  
"Song of Solomon" variations not being detected.

**Solution:**  
Added aliases:
```swift
"song of solomon": "Song of Solomon",
"song of songs": "Song of Solomon",
"songs of solomon": "Song of Solomon",
"songs": "Song of Solomon",
"sos": "Song of Solomon",
"canticles": "Song of Solomon",
```

---

### [2026-01-20] - 2-Digit Numbers Split Incorrectly
**Type:** Bug  
**Status:** Resolved  
**Severity:** High  
**Related:** `ScriptureDetectorService.swift`

**Problem:**  
"John 11" was being incorrectly parsed as "John 1:1".

**Cause:**  
Spoken pattern was splitting any 2-digit number into chapter:verse.

**Solution:**  
Changed spoken pattern to only split 3+ digit numbers:
```swift
// Before: (\d{1,2})(\d{1,2}) - "11" → "1:1"
// After:  (\d{1,2})(\d{2})   - "11" stays as chapter 11, "316" → "3:16"
```

---

### [2026-01-20] - Fuzzy Matching Too Aggressive
**Type:** Bug  
**Status:** Resolved  
**Severity:** Medium  
**Related:** `BookNameNormaliser.swift`

**Problem:**  
Random words were being matched to book names with low confidence.

**Solution:**  
Reduced maximum Levenshtein distance from 3 to 2 for initial matches, with confidence scoring:
- Distance 1: 90% confidence
- Distance 2: 70% confidence
- Distance 3: 50% confidence (only used for suggestions, not auto-match)

---

### [2026-01-20] - Speech Recognition Bible Bias
**Type:** Enhancement  
**Status:** Resolved  
**Severity:** Medium  
**Related:** Story 2.3, `BibleLanguageModel.swift`, `TranscriptionService.swift`

**Problem:**  
Speech recognition was mishearing Bible book names (e.g., "Habakkuk" → "have a cook")

**Cause:**  
Default language model not trained on Biblical vocabulary

**Solution:**  
Implemented `SFCustomLanguageModelData` with:
- All 66 Bible book names
- Common theological terms
- Chapter/verse number patterns
- Custom pronunciations for difficult names

**Notes:**  
Users can now also manually correct transcripts and save corrections per pastor

---

### [2026-01-19] - Wrong Translation Column Name
**Type:** Bug  
**Status:** Resolved  
**Severity:** Critical  
**Related:** `BibleService.swift`

**Problem:**  
Query failing with "no such column: translation_id"

**Cause:**  
Database uses `translation` column, not `translation_id`

**Solution:**  
Changed query from:
```sql
WHERE translation_id = 'KJV'
-- to
WHERE translation = 'KJV'
```

---

### [2026-01-19] - Hardcoded BSB Translation
**Type:** Bug  
**Status:** Resolved  
**Severity:** Medium  
**Related:** `BibleService.swift`

**Problem:**  
All queries were using hardcoded "BSB" translation which doesn't exist in database.

**Cause:**  
Copy-paste error from reference code

**Solution:**  
Changed to use `selectedTranslation` from `@AppStorage`

---

### [2026-01-18] - Audio Level Not Updating
**Type:** Bug  
**Status:** Resolved  
**Severity:** High  
**Related:** Story 1.4, `AudioCaptureService.swift`

**Problem:**  
Audio level indicator was not updating in real-time

**Cause:**  
The `@Published` property was being updated on a background thread

**Solution:**  
Wrapped audio level updates in `DispatchQueue.main.async`:
```swift
DispatchQueue.main.async {
    self.audioLevel = normalizedLevel
    self.peakLevel = max(self.peakLevel, normalizedLevel)
}
```

---

### [2026-01-16] - App Icon Not Showing in Menu Bar
**Type:** Bug  
**Status:** Resolved  
**Severity:** Medium  
**Related:** Story 1.1, `AppDelegate.swift`

**Problem:**  
Menu bar showed system icon instead of custom Divine Link icon

**Cause:**  
Asset catalog not properly configured for template images

**Solution:**  
- Added icon variants for all required sizes (16x16 through 512x512)
- Set "Render As: Template Image" for menu bar icon
- Updated `Contents.json` with correct scale factors

---

### [2026-01-14] - Microphone Permission Not Requested
**Type:** Bug  
**Status:** Resolved  
**Severity:** Critical  
**Related:** Story 1.3, `Info.plist`, `DivineLink.entitlements`

**Problem:**  
App crashed on first audio capture attempt - no permission dialog shown

**Cause:**  
Missing `NSMicrophoneUsageDescription` in Info.plist

**Solution:**  
Added to `Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Divine Link needs microphone access to listen for scripture references during sermons.</string>
```

---

## Technical Decisions Log

### [2026-01-22] - Implicit Reference Detection for Famous Verses
**Decision:** Detect well-known verses from content without explicit reference

**Rationale:**  
- Pastors often quote famous verses without citing the reference
- Congregation knows "For God so loved the world" is John 3:16
- Adding these automatically helps operators

**Implementation:**  
- `ImplicitReferenceDetector` checks for phrase matches
- Only triggers with ≥60% confidence
- Limited to ~20 most famous verses to avoid false positives

---

### [2026-01-22] - Keep Pushed Verses Visible
**Decision:** Don't remove verses from list when pushed; mark them visually instead

**Rationale:**  
- Pastors often return to previously mentioned verses
- Operators may need to push the same verse multiple times
- Visual history of what was pushed is useful

**Implementation:**  
- Green background for pushed verses
- Checkmark icon
- Push count badge (×2, ×3)
- Explicit delete button for removal

---

### [2026-01-22] - Reject Invalid Detections Silently
**Decision:** Don't show "[Verse text not available]" for invalid references

**Rationale:**  
- Invalid references (e.g., Philippians 6:7) are speech recognition errors
- Showing them clutters the UI and confuses operators
- Better to silently reject and let correct detections through

**Implementation:**  
- Validate chapter exists for book before adding to pending list
- Validate verse text can be retrieved from database
- Log rejections for debugging but don't show to user

---

### [2026-01-22] - Transcript Editing for Speech Corrections
**Decision:** Allow users to edit live transcripts to correct misheard words

**Rationale:**  
- Speech recognition will inevitably make mistakes
- Users know what the pastor actually said
- Corrections can be saved per pastor for future learning

**Implementation:**  
- Added edit button on transcript section
- Text field replaces display when editing
- Detects if correction is a book name → offers to save
- Corrections stored in pastor profile

---

### [2026-01-20] - Bible Translation Selection
**Decision:** Allow runtime switching between KJV, ASV, and WEB

**Rationale:**  
- Different churches prefer different translations
- Detection should work regardless of translation
- Display verse text in user's preferred translation

**Implementation:**  
- `@AppStorage("selectedTranslation")` for persistence
- Dropdown menu in status indicators row
- `BibleService` queries with translation filter

---

### [2026-01-15] - No Dock Icon (Menu Bar Only)
**Decision:** App runs exclusively as menu bar application

**Rationale:**  
- Operators need quick access without window management
- App should stay out of the way during services
- Consistent with utility app patterns (e.g., Bartender, Alfred)

**Implementation:**  
- Set `LSUIElement = true` in Info.plist
- Main window accessible via menu bar click
- Settings via standard macOS Settings Link

---

### [2026-01-12] - Local-First Bible Database
**Decision:** Bundle SQLite database instead of API calls

**Rationale:**  
- Zero latency for verse lookups
- Works offline (critical for churches with poor internet)
- No ongoing API costs or rate limits
- User data privacy (no sermon content sent to servers)

**Implementation:**  
- `Bible.db` bundled in Resources/
- `BibleService` uses raw SQLite3 C API
- Verses table: id, book, chapter, verse, text, translation

---

## Performance Notes

### Audio Processing
- Buffer size: 1024 samples
- Sample rate: Device default (typically 44.1kHz or 48kHz)
- Audio level calculation: RMS with smoothing
- Memory: ~5MB for audio engine

### Speech Recognition
- Uses on-device model (no network required)
- Latency: ~200-500ms for phrase completion
- Memory: ~50MB for speech framework
- Custom language model adds ~2MB

### Bible Database
- Database size: ~15MB
- Query time: <5ms for single verse lookup
- Index on (book, chapter, verse, translation)
- Chapter count cache loaded on startup

### Detection Pipeline
- Debounce: 300ms between detection runs
- Deduplication: 5-second window for same reference
- Pattern matching: 6 regex patterns checked in order
- Implicit detection: Only if no explicit matches found

---

## Debug Commands

### Check Audio Devices
```swift
AudioDeviceManager.shared.availableDevices.forEach { device in
    print("Device: \(device.name) - \(device.uid)")
}
```

### Force Bible Reload
```swift
BibleService.shared.reload(translation: "KJV")
```

### Test Scripture Detection
```swift
let detector = ScriptureDetectorService()
let results = detector.detect(in: "Let's turn to John chapter 3 verse 16")
print(results) // Should find "John 3:16"
```

### Test Implicit Detection
```swift
let implicit = ImplicitReferenceDetector()
let match = implicit.bestMatch(in: "For God so loved the world")
print(match?.reference) // Should print "John 3:16"
```

### Check Database Integrity
```bash
sqlite3 DivineLink/DivineLink/Resources/Bible.db "SELECT translation, COUNT(*) FROM verses GROUP BY translation;"
```

### Test Book Name Normalisation
```swift
let normaliser = BookNameNormaliser()
print(normaliser.normalise("filipinos")) // Should print "Philippians"
print(normaliser.normalise("glacians"))  // Should print "Galatians"
```

---

## Environment Notes

- **Xcode Version:** 15.0+
- **macOS Target:** 14.0 (Sonoma)+
- **Swift Version:** 5.9+
- **Test Device:** MacBook Pro M1/M2/M3 recommended

---

*Last Updated: 2026-01-22*
