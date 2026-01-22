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

### [2026-01-22] - ProPresenter Push Not Implemented
**Type:** Issue  
**Status:** Open (Expected)  
**Severity:** High  
**Related:** Epic 3 (Stories 3.1-3.9), `MainView.swift:485`

**Problem:**  
Push to ProPresenter functionality is a placeholder:
```swift
// TODO: Push to ProPresenter (Epic 3)
print("[Push] \(verse.displayReference)")
```

**Cause:**  
Epic 3 not yet implemented - this is planned work.

**Solution:** Complete Epic 3 stories

---

### [2026-01-22] - Connection Test Not Implemented
**Type:** Issue  
**Status:** Open (Expected)  
**Severity:** Low  
**Related:** `SettingsView.swift:231`

**Problem:**  
ProPresenter connection test button is a placeholder:
```swift
// TODO: Implement connection test in Story 2.x
```

**Cause:**  
Part of Epic 3 ProPresenter integration

**Solution:** Implement in Story 3.5 or 3.6

---

## Resolved Issues

### [2026-01-20] - Speech Recognition Bible Bias
**Type:** Enhancement  
**Status:** Resolved  
**Severity:** Medium  
**Related:** Story 2.3, `TranscriptionService.swift`

**Problem:**  
Speech recognition was mishearing Bible book names (e.g., "Habakkuk" → "have a cook")

**Cause:**  
Default language model not trained on Biblical vocabulary

**Solution:**  
Implemented `SFCustomLanguageModelData` with:
- All 66 Bible book names
- Common theological terms
- Chapter/verse number patterns

**Notes:**  
Users can now also manually correct transcripts and save corrections per pastor

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
- Corrections stored in pastor profile (Epic 4 feature brought forward)

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
- `BibleService` uses SQLite.swift (if available) or raw SQLite3
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

### Bible Database
- Database size: ~15MB
- Query time: <5ms for single verse lookup
- Index on (book, chapter, verse, translation)

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

### Check Database Integrity
```bash
sqlite3 DivineLink/DivineLink/Resources/Bible.db "SELECT translation, COUNT(*) FROM verses GROUP BY translation;"
```

---

## Environment Notes

- **Xcode Version:** 15.0+
- **macOS Target:** 14.0 (Sonoma)+
- **Swift Version:** 5.9+
- **Test Device:** MacBook Pro M1/M2/M3 recommended

---

*Last Updated: 2026-01-22*
