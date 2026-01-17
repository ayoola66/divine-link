# Technical Validation Report - Divine Link

**Document Type:** Research Findings  
**Analyst:** Mary (BMAD Business Analyst)  
**Date:** January 2026  
**Status:** All Pillars Validated ✅

---

## Executive Summary

This document validates the three critical technical pillars required for the Divine Link project—a macOS application for live church scripture detection with ProPresenter integration.

| Pillar | Status | Confidence |
|--------|--------|------------|
| ProPresenter Network API | ✅ Validated | High |
| macOS Speech Framework (SFCustomLanguageModelData) | ✅ Validated | High |
| BSB/HelloAO Licensing | ✅ Validated | Very High |

---

## Pillar 1: ProPresenter Network API

### Findings

**Endpoint Confirmed:** `PUT /v1/stage/message`

ProPresenter 7.9+ includes a fully supported public HTTP API with Swagger/OpenAPI documentation accessible via Settings → Network → API Documentation.

### Key Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/v1/stage/message` | PUT | Set stage message text (real-time) |
| `/v1/stage/message` | GET | Retrieve current stage message |
| `/v1/messages/{messageId}/show` | POST/PUT | Trigger pre-built message with token values |
| `/v1/messages/{messageId}/hide` | DELETE/POST | Hide a shown message |

### Implementation Details

```json
// HTTP Request
PUT /v1/stage/message
Content-Type: application/json
Body: "Scripture text here\nVerse reference"

// TCP/IP Socket Alternative
{
  "url": "v1/stage/message",
  "method": "PUT",
  "body": "Scripture text here",
  "chunked": false
}
```

### Technical Notes

- Multi-line text supported via `\n` escape sequences
- Stage screens must have a "stage message region" configured
- Pre-built Message templates support dynamic token values
- TCP/IP socket option available for systems without full HTTP support

### Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Version variations (7.9, 17.x, 18.x) | Medium | Test on target ProPresenter version before deployment |
| 404 errors for presentations not in playlist | Low | Ensure proper presentation/playlist configuration |

### Sources

- [ProPresenter API GitHub](https://github.com/jeffmikels/ProPresenter-API)
- [Renewed Vision Support - TCP/IP Connections](https://support.renewedvision.com/hc/en-us/articles/31606866768147)
- [Reddit r/ProPresenter discussions](https://www.reddit.com/r/ProPresenter/)

---

## Pillar 2: macOS SFCustomLanguageModelData

### Findings

**Framework Status:** Stable since macOS 14 / iOS 17

Apple's `SFCustomLanguageModelData` enables custom phrase biasing for speech recognition, allowing the app to prefer Bible book names and theological terms.

### Implementation Workflow

```swift
// Step 1: Create custom language model data
let data = SFCustomLanguageModelData(
    locale: Locale(identifier: "en_GB"),
    identifier: "com.divinelink.bible-vocabulary",
    version: "1.0"
) {
    // Bible book names with high frequency counts
    SFCustomLanguageModelData.PhraseCount(phrase: "Genesis", count: 100)
    SFCustomLanguageModelData.PhraseCount(phrase: "Exodus", count: 100)
    SFCustomLanguageModelData.PhraseCount(phrase: "Habakkuk", count: 100)
    SFCustomLanguageModelData.PhraseCount(phrase: "Zephaniah", count: 100)
    // ... all 66 books
    
    // Custom pronunciations for difficult names
    SFCustomLanguageModelData.CustomPronunciation(
        grapheme: "Habakkuk",
        phonemes: ["h æ b ə k ʌ k"]
    )
    
    // Theological terms
    SFCustomLanguageModelData.PhraseCount(phrase: "justification", count: 50)
    SFCustomLanguageModelData.PhraseCount(phrase: "sanctification", count: 50)
    SFCustomLanguageModelData.PhraseCount(phrase: "propitiation", count: 50)
}

// Step 2: Export to binary file
try await data.export(to: modelURL)

// Step 3: Prepare compiled language model
try await SFSpeechLanguageModel.prepareCustomLanguageModel(
    for: modelURL,
    clientIdentifier: "com.divinelink",
    configuration: languageModelConfig
)

// Step 4: Attach to recognition request
let request = SFSpeechAudioBufferRecognitionRequest()
request.customizedLanguageModel = languageModelConfig
```

### Constraints

| Constraint | Limit | Impact |
|------------|-------|--------|
| contextualStrings (simple method) | ~100 phrases | Use full SFCustomLanguageModelData for 66+ books |
| Phrase length | Short phrases preferred | Bible books are typically 1-2 words ✅ |
| Model size | Template generation can increase size | Monitor compiled model size |
| Sandbox permissions | Filesystem access for .bin export | Use appropriate app directories |

### SpeechAnalyzer (macOS 26 Tahoe)

- New SpeechAnalyzer API available in macOS 26 beta
- SpeechAnalyzerDylib wrapper released for C/C++/Swift
- Integration with SFCustomLanguageModelData not yet fully documented
- **Recommendation:** Start with SFSpeechRecognizer + SFCustomLanguageModelData; monitor SpeechAnalyzer development

### Recommended Vocabulary List

**66 Bible Books:** Genesis, Exodus, Leviticus, Numbers, Deuteronomy, Joshua, Judges, Ruth, 1 Samuel, 2 Samuel, 1 Kings, 2 Kings, 1 Chronicles, 2 Chronicles, Ezra, Nehemiah, Esther, Job, Psalms, Proverbs, Ecclesiastes, Song of Solomon, Isaiah, Jeremiah, Lamentations, Ezekiel, Daniel, Hosea, Joel, Amos, Obadiah, Jonah, Micah, Nahum, Habakkuk, Zephaniah, Haggai, Zechariah, Malachi, Matthew, Mark, Luke, John, Acts, Romans, 1 Corinthians, 2 Corinthians, Galatians, Ephesians, Philippians, Colossians, 1 Thessalonians, 2 Thessalonians, 1 Timothy, 2 Timothy, Titus, Philemon, Hebrews, James, 1 Peter, 2 Peter, 1 John, 2 John, 3 John, Jude, Revelation

**Common Theological Terms:** justification, sanctification, propitiation, atonement, redemption, salvation, grace, righteousness, covenant, gospel, parable, epistle, apostle, disciple, Pharisee, Sadducee, Messiah, Christ, Lord, Almighty

### Sources

- [Apple WWDC23 - Recognizing Speech in Live Audio](https://github.com/gromb57/ios-wwdc23__RecognizingSpeechInLiveAudio)
- [Speech Framework Documentation](https://github.com/dotnet/macios/wiki/Speech-iOS-xcode26.0-b1)
- [Stack Overflow - SFCustomLanguageModelData export issues](https://stackoverflow.com/questions/79469627)

---

## Pillar 3: Berean Standard Bible / HelloAO API Licensing

### Findings

**Status:** ✅ FULLY CLEARED FOR COMMERCIAL USE

#### Berean Standard Bible (Text)

| Aspect | Status |
|--------|--------|
| **Licence** | Public Domain (since April 30, 2023) |
| **Commercial use** | ✅ Unrestricted |
| **Permission required** | No |
| **Fees/Royalties** | None |
| **Attribution** | Appreciated but NOT legally required |
| **Derivatives** | Allowed (rename if modified) |

#### HelloAO / Free Use Bible API

| Aspect | Status |
|--------|--------|
| **API/Code Licence** | MIT Licence |
| **Text Licence** | Public Domain (BSB) |
| **Commercial use** | ✅ Permitted |
| **Requirements** | Include MIT notice if redistributing code |

### Legal Summary

The Berean Standard Bible text entered the public domain on April 30, 2023. This means:

1. **No permission required** for any use—personal, ministry, or commercial
2. **No royalties or fees** to be paid
3. **Full reproduction rights** including in paid apps and SaaS products
4. **Derivative works permitted** with recommendation to rename modified versions
5. **Attribution is courtesy, not law**

### Implementation Notes

- Use official BSB text to avoid confusion
- Include MIT licence notice if embedding HelloAO API code
- Consider adding voluntary attribution: "Scripture quotations from the Berean Standard Bible"

### Sources

- [Berean Bible Terms of Use](https://berean.bible/terms.htm)
- [Berean Bible Licensing](https://berean.bible/licensing.htm)
- [HelloAO Licensing Model](https://bible.helloao.org/docs/guide/a-biblical-model-for-licensing-the-bible.html)

---

## Conclusion

All three technical pillars have been validated with high confidence. The Divine Link project can proceed to the Planning phase with the following confirmed strategy:

1. **ASR:** Local-first using macOS Speech Framework with SFCustomLanguageModelData for Bible vocabulary biasing
2. **ProPresenter Integration:** `/v1/stage/message` endpoint for real-time text injection
3. **Bible Source:** Berean Standard Bible via HelloAO API (Public Domain, commercial-safe)

---

**Document Version:** 1.0  
**Next Phase:** Planning (PRD Generation with PM Agent)
