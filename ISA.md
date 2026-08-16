---
task: "Divine Link — live spoken-scripture detection and presentation"
slug: 20260816-010000_divine-link-project-isa
project: Divine Link
effort: E4
effort_source: explicit
phase: verify
progress: 48/226
mode: interactive
started: 2026-08-16T00:00:00Z
updated: 2026-08-16T07:58:00Z
---

## Problem

A church media operator running scripture on a projector has one job during a service and no slack in which to do it. The preacher says "turn with me to the book of Psalms, chapter 9, verse 8 to 12"; within a few seconds the congregation expects the passage on screen. Today that means an operator typing a reference into ProPresenter while listening for the next one, and a congregation that watches the wrong verse, a blank screen, or a stale slide whenever the operator falls behind.

Divine Link exists to close that gap: capture the room's audio, transcribe it on device, detect the spoken reference, look the verses up in a bundled SQLite Bible, and present them — either through ProPresenter or through Divine Link's own DivineView window on a second display. The operator stays in the loop and confirms every push. Version 1.6.2 ships that loop end to end, and DivineView landed as an MVP on 16 August 2026.

The immediate problem that forced this ISA into existence is that the recognition path was not trustworthy. On 15–16 August 2026 a live utterance of "the book of Psalms chapter 9, verse 8 to 12" produced **Amos 9:1** on screen. The passage was wrong, the range was gone, and nothing in the interface signalled that anything had failed. Five compounding defects were diagnosed:

1. **Non-deterministic fuzzy book matching.** `BookNameNormaliser.fuzzyMatch` iterated a Swift `Dictionary` of aliases. Swift randomises dictionary iteration order per process, so the mishearing "sam" — which sits at Levenshtein distance 1 from aliases belonging to six different books, including Amos and Psalms — resolved to a different book on different launches. The same audio produced different scripture depending on when the app was started.
2. **Short aliases as fuzzy targets.** One- and two-character aliases such as "am" (Amos) and "ho" (Hosea) were eligible fuzzy targets. Almost any short mishearing lands within two edits of something in that set, so the matcher was confidently wrong at scale.
3. **No chapter-aware disambiguation.** Nothing used the chapter the preacher had actually spoken to settle a tie, even though chapter counts are already in the database. "Chapter 91" is impossible for Amos (9 chapters) and unremarkable for Psalms (150), and that fact was available and unused.
4. **Poisoned reference buffer.** `ReferenceBuffer` was written at parse time, before the reference had been checked against the Bible database. An impossible reference such as "Amos 91" therefore became the cached context that later partial references — "verse 8 to 12" — resolved against, and stayed poisoned for the full five-minute context window.
5. **Verse range discarded by a fallback.** `reinterpretConcatenatedRef` exists to rewrite the speech-recognition artefact "Book123" into "Book 1:23". It fired even when an explicit verse range had already been parsed, and hard-coded `verseEnd: nil`, so "Amos 91:8-12" collapsed to "Amos 9:1" and the spoken range vanished silently.

Individually each defect looks like a rough edge. Together they turned a correctness-critical recognition path into a coin toss whose failures were invisible to the operator. The repository also carries a second, structural problem: two unit test files exist in total (`DivineViewTests.swift`, `NumberedBookDetectionTests.swift`), so almost none of the detection surface is currently verifiable by anything other than a live service.

## Vision

An operator opens Divine Link before the service, selects the desk feed, and does not look at the laptop again except to press Push. The preacher speaks; the reference appears as a card with the verses already loaded and a confidence figure attached; the operator presses Push and the passage is on the projector before the congregation has finished turning pages. When Divine Link is unsure, it says so plainly and shows nothing rather than showing the wrong book — and the operator learns, over one service, that a card on screen can be trusted without being read twice. The euphoric surprise is the moment an operator realises they have stopped pre-reading every card.

## Out of Scope

- **No auto-push.** Every push to any target is operator-confirmed. A 90% auto-push threshold is discussed in `Plans/Presentation-Outputs-Roadmap.md` §7 but is deliberately not part of this ideal state.
- **No FreeShow integration.** Roadmapped as Phase C in `Plans/Presentation-Outputs-Roadmap.md` and Story 8.6; the REST contract (`POST :5506`, `start_scripture`) is documented but no `FreeShowClient.swift` exists. Criteria referencing FreeShow are marked as future and are excluded from this ideal state.
- **No EasyWorship, NDI, OBS or output-protocol rewrite.** Story 8.6 research-spike territory; Phase D explicitly says two working targets must exist before the protocol is extracted.
- **No Windows port.** Divine Link is macOS-only. Confirmed as a competitor capability gap in `Plans/Competitor-Gap-Analysis-Pewbeam.md` §4.2, and deliberately deferred.
- **No semantic or paraphrase quote matching across the full canon.** `ImplicitReferenceDetector` matches a hardcoded list of 17 phrases in `BibleVocabularyData.swift` with `minimumPhraseWords = 5`. Love Quote Matching Phase 1 is roadmapped, not built, and is not in this ideal state.
- **No AI sermon notes, slide generation, or cloud transcription.** Audio never leaves the machine except where Apple's `SFSpeechRecognizer` falls back to server-based recognition when on-device models are unavailable; that fallback is a known behaviour, not a feature to extend.
- **No themes, motion backgrounds or images in DivineView.** Black or white, verse, reference, translation. Nothing else.
- **No changes to the monetisation model.** Mercy/Grace/Love tiers and Stripe billing are existing behaviour; this ISA does not restructure them.
- **No modification of the bundled `Bible.db` contents.** It is read-only and treated as a fixture.

## Principles

- **A wrong verse on screen is worse than no verse.** Recognition should reject ambiguity rather than resolve it. Silence is a recoverable failure; a confident wrong answer is not, because the operator has no signal to act on.
- **Non-determinism in a recognition path is a correctness bug, not a UX nicety.** Any code path where the same input can yield different outputs across process launches is broken regardless of how often it happens to be right.
- **The operator is the last line of defence and must be given something to defend with.** Confidence must be visible, uncertainty must be legible, and the panic path must be one keystroke.
- **Validate before you remember.** State that feeds future decisions — cached context, buffered references — must be checked against reality before it is written, because bad state outlives the utterance that produced it.
- **Never discard what the speaker actually said.** A repair heuristic may add interpretation; it must not remove information that was explicitly spoken.
- **Local first.** Detection, lookup and presentation work with the network unplugged. The bundled database is the product's floor, not its cache.
- **Own a surface before integrating another.** DivineView exists so that a church with a laptop and a projector is a first-class user, not a user waiting for an integration.

## Constraints

- macOS-only, SwiftUI + AppKit, distributed outside the App Store via Sparkle with an EdDSA-signed appcast on Netlify.
- Transcription is Apple `SFSpeechRecognizer` with a WhisperKit path (`WhisperTranscriber`); `requiresOnDeviceRecognition` is only set when `supportsOnDeviceRecognition` is true, otherwise recognition falls back to server-based rather than failing silently.
- The Bible corpus is a read-only bundled SQLite file at `DivineLink/Resources/Bible.db` with tables `books`, `verses`, `translations`, 66 books, and five bundled translations (KJV, WEB, ASV, BSB, LSV) of 31,086–31,104 verses each. Premium translations (WEBBE, YLT, DBY, DRA, BBE) are downloaded, not bundled.
- Concurrency: `TranscriptionService`, `DivineViewController`, `DivineViewSettings`, `PanicButtonService` and `PushActionCoordinator` are `@MainActor`-isolated. `SFSpeechRecognizer` callbacks arrive off the main thread and must be dispatched before touching that state.
- Detection is driven by `NSRegularExpression` over the transcript with a 300 ms Combine debounce; there is no ML model in the reference-detection path.
- Reference context expires after `ReferenceBuffer.contextTimeout`, default 300 seconds, persisted under `ReferenceBufferTimeout`.
- Settings persist through `UserDefaults` with namespaced keys (`divineView.*`, `detection.*`, `panicButton.*`, `ReferenceBuffer*`).
- ProPresenter integration must keep three paths working — Stage Display over HTTP, Messages API over WebSocket, and keyboard automation — behind `HybridIntegrationManager`, with topology (`sameMachine` / `twoMachines`) gated to Premium.
- DivineView must not steal key focus when a verse is pushed; `orderFrontRegardless()` is required for the `versePushed` reason so the operator window keeps Space/Enter/Delete and ProPresenter keyboard automation is not interrupted.
- Feature gating follows the Mercy (Free) / Grace (Premium, £9.99) / Love (Pro, £19.99) tiers defined in `docs/FEATURE-MATRIX.md`.
- All user-facing copy is British English.

## Goal

Divine Link detects a spoken scripture reference from live room audio and puts the correct passage — correct book, correct chapter, complete spoken verse range, correct translation — in front of the operator within the latency budget, refuses to display anything when the reference is ambiguous or implausible, and pushes to ProPresenter and DivineView only on explicit operator confirmation, with the whole detection path covered by unit tests that fail if any of the five 16 August 2026 defects reappear.

## Criteria

### Build and repository health

- [x] ISC-1: `xcodebuild -project DivineLink/DivineLink.xcodeproj -scheme DivineLink build` exits 0.
- [x] ISC-2: `BibleService.swift` declares `maxChapter(forBookNamed:)` exactly once within `class BibleService`.
- [x] ISC-3: `xcodebuild test -scheme DivineLink` exits 0 with zero failing tests.
- [ ] ISC-4: The build emits zero Swift compiler warnings in `Features/Detection/`.
- [ ] ISC-5: `Bible.db` is present in the built app bundle's `Resources` directory.
- [ ] ISC-6: No source file under `Features/` contains a `TODO` marker referencing the Psalms/Amos defects.
- [ ] ISC-7: `git status --porcelain` is clean after a build (no generated artefacts tracked).
- [x] ISC-8: The `DivineLinkTests` target contains at least one test file per detection concern (normalisation, partial resolution, concatenation repair, lookup), not the two files present today.

### Speech capture and device selection

- [ ] ISC-9: `AudioDeviceManager.refreshDevices()` returns a non-empty `availableDevices` array on a Mac with a built-in microphone.
- [ ] ISC-10: Each entry in `availableDevices` is an `AVCaptureDevice` of audio media type.
- [ ] ISC-11: `selectDefaultDevice()` sets `selectedDevice` to the system default input when no device has been saved.
- [ ] ISC-12: `selectDevice(_:)` persists the chosen device identifier and the same device is selected after an app relaunch.
- [ ] ISC-13: Selecting a device that has since been unplugged falls back to the system default rather than leaving `selectedDevice` nil.
- [ ] ISC-14: `AudioCaptureService` begins publishing on `audioBufferPublisher` within 2 seconds of start.
- [ ] ISC-15: The first published `AVAudioPCMBuffer` has a non-zero frame length.
- [ ] ISC-16: RMS computed over a buffer captured while audio is playing is greater than zero.
- [ ] ISC-17: `AudioLevelIndicator` reflects a non-zero level while audio is present and returns to zero within 1 second of silence.
- [ ] ISC-18: Microphone permission denial surfaces a user-visible error rather than a silent no-op.
- [ ] ISC-19: Changing the input device mid-session is debounced by 300 ms before it reaches Core Audio (`DetectionPipeline.setupDeviceObserver`).

### Transcription and transcript buffer

- [ ] ISC-20: `TranscriptionService.requestPermission()` returns true after speech authorisation is granted.
- [ ] ISC-21: `start(with:)` sets `isTranscribing` to true and establishes an audio buffer subscription.
- [ ] ISC-22: `beginRecognitionSession()` returns false and sets `error = .recognizerNotAvailable` when the recogniser is unavailable.
- [ ] ISC-23: `requiresOnDeviceRecognition` is only set true when `speechRecognizer.supportsOnDeviceRecognition` is true.
- [ ] ISC-24: When on-device recognition is unsupported, the service logs the fallback and still produces transcript text.
- [ ] ISC-25: Partial results update `transcript` and publish a `TranscriptionSegment` with `isFinal == false`.
- [ ] ISC-26: A final result publishes a `TranscriptionSegment` with `isFinal == true` even when the text is identical to the last partial.
- [ ] ISC-27: `restartSeamlessly()` creates the new recognition session before retiring the old one, so `appendAudioBuffer` always has a live request.
- [ ] ISC-28: A seamless restart drops zero audio buffers — buffer count in equals buffer count appended across the handoff boundary.
- [ ] ISC-29: A seamless restart resets `lastTranscript` to empty so the new session's partials do not stack on the old text.
- [ ] ISC-30: `isTranscribing` remains true across a seamless restart.
- [ ] ISC-31: The display buffer commits exactly one line per recognition session (no duplicated transcript across a session boundary).
- [ ] ISC-32: Error code 1110 ("no speech") schedules a damped restart on a 0.3 s timer rather than restarting immediately.
- [ ] ISC-33: `kAFAssistantErrorDomain` code 216 is swallowed and does not surface as a user-visible error.
- [ ] ISC-34: `stop()` cancels the restart timer, the recognition task and the audio subscription, and leaves `isTranscribing` false.
- [ ] ISC-35: The Bible language model is applied to the recognition request when `BibleLanguageModel.isReady` is true.
- [ ] ISC-36: A reference spoken across a session-restart boundary is still detected once the transcript reassembles.

### Reference detection — explicit written forms

- [ ] ISC-37: "John 3:16" yields `ScriptureReference(book: "John", chapter: 3, verseStart: 16, verseEnd: nil)`.
- [ ] ISC-38: "John 3:16-18" yields `verseStart: 16, verseEnd: 18`.
- [ ] ISC-39: "1 John 3:16" resolves to book "1 John", not "John".
- [ ] ISC-40: "Psalm 23:1" and "Psalms 23:1" both resolve to the same canonical book.
- [ ] ISC-41: "Song of Solomon 2:1" resolves as a single multi-word book name.
- [ ] ISC-42: "Romans 8" yields a `chapterOnly` detection with `chapter: 8` and no verse.
- [ ] ISC-43: A reference embedded mid-sentence ("as it says in John 3:16, God so loved") is detected.
- [ ] ISC-44: Two distinct references in one transcript segment produce two detections.
- [ ] ISC-45: The same reference repeated within the debounce window produces exactly one detection.
- [ ] ISC-46: `DetectionResult.rawMatch` contains the exact substring matched from the transcript.

### Reference detection — spoken and verbal forms

- [ ] ISC-47: "John chapter 3 verse 16" resolves to John 3:16 via the `verbal` pattern.
- [ ] ISC-48: "Genesis 1 verse 1" resolves to Genesis 1:1 via the `verbalShort` pattern (no "chapter" keyword).
- [ ] ISC-49: "John three sixteen" resolves to John 3:16 via the `spokenWords` pattern.
- [ ] ISC-50: "Genesis twenty one one" resolves to Genesis 21:1, not Genesis 20:11.
- [ ] ISC-51: "John 316" resolves to John 3:16 via the `spoken` pattern.
- [ ] ISC-52: "John 316 to 18" resolves to John 3:16-18 via the `spokenRange` pattern with `verseEnd: 18`.
- [ ] ISC-53: "verse 31 of Romans 8" resolves to Romans 8:31 via the `invertedVerbal` pattern.
- [ ] ISC-54: "verse 31 of Romans eight" resolves to Romans 8:31 with the chapter given as a word.
- [ ] ISC-55: "John verse 16 chapter 5" resolves to John 5:16 via the `bookVerseChapter` pattern.
- [ ] ISC-56: "Second Timothy chapter 3" resolves to "2 Timothy 3", not "Timothy 3".
- [ ] ISC-57: "First Corinthians 13" resolves to "1 Corinthians 13".
- [ ] ISC-58: "Third John verse 4" resolves to "3 John 1:4".
- [ ] ISC-59: Hyphenated number words ("twenty-one") and spaced number words ("twenty one") both parse to 21.
- [ ] ISC-60: "the book of Psalms chapter 9, verse 8 to 12" resolves to Psalms 9:8-12 — the exact utterance that produced Amos 9:1 on 16 August 2026.

### Reference detection — contextual partials

- [ ] ISC-61: After a full reference is detected, "verse 18" resolves to the same book and chapter, verse 18.
- [ ] ISC-62: After a full reference, "verses 5 to 7" resolves with `verseStart: 5, verseEnd: 7`.
- [ ] ISC-63: "the next verse" advances the verse number by one against the cached context.
- [ ] ISC-64: "the previous verse" decrements the verse number by one against the cached context.
- [ ] ISC-65: A partial reference with no cached context produces no detection.
- [ ] ISC-66: A partial reference resolved against context older than `contextTimeout` (default 300 s) produces no detection.
- [ ] ISC-67: `ReferenceBuffer.isEnabled == false` disables partial resolution entirely.
- [ ] ISC-68: `contextTimeout` reads from `UserDefaults` key `ReferenceBufferTimeout` and defaults to 300 when unset.
- [ ] ISC-69: A chapter-only utterance ("chapter 9") after a full reference resolves against the cached book.
- [x] ISC-70: All five context-write sites route through `cacheContext(for:)` — no direct `referenceBuffer.updateContext` call exists outside that helper.
- [ ] ISC-71: A resolved partial reference inherits the book from context and never re-runs fuzzy book matching.
- [ ] ISC-72: Starting a new service session clears the reference context.

### Book name normalisation and the 16 August 2026 regressions

- [x] ISC-73: `fuzzyCandidates` iterates `bookMappings.keys.sorted()`, not raw dictionary order (defect 1).
- [ ] ISC-74: Running `fuzzyCandidates("sam")` 100 times across 100 separate process launches returns an identical ordered result each time (defect 1, behavioural).
- [x] ISC-75: `fuzzyMatch` returns nil when the tied candidates map to more than one canonical book (defect 1).
- [x] ISC-76: `minimumFuzzyAliasLength` is 3 and aliases shorter than that are skipped in `fuzzyCandidates` (defect 2).
- [x] ISC-77: `fuzzyCandidates("am")` returns no candidate whose matched alias is "am" (defect 2).
- [x] ISC-78: `normalise(_:chapterHint:)` filters ambiguous candidates through `chapterCountProvider` before rejecting (defect 3).
- [x] ISC-79: `DetectionPipeline.wireDetectorToBible()` assigns `bookNormaliser.chapterCountProvider` from `BibleService.maxChapter(forBookNamed:)` (defect 3).
- [x] ISC-80: `normalise("sam", chapterHint: 91)` returns "Psalms" — reached by the exact-alias path, ahead of any chapter filtering, and never Amos (defect 3).
- [x] ISC-81: `normalise("a john", chapterHint: 1)` returns nil, because chapter 1 exists in all three Johannine epistles and the tie is unresolved (defect 3, honest-rejection case).
- [ ] ISC-82: [DROPPED — superseded by the "sam" → Psalms alias decision of 2026-08-16; bare "sam" now resolves to Psalms by design, so a nil return would be a regression rather than the ideal state. Honest rejection is now carried by ISC-81.]
- [x] ISC-83: `cacheContext(for:)` returns early without writing when `referenceValidator` reports the reference implausible (defect 4).
- [x] ISC-84: `wireDetectorToBible()` assigns `referenceValidator` from `BibleService.referenceExists(_:)` (defect 4).
- [x] ISC-85: Feeding "Amos 91" into the detector leaves `ReferenceBuffer.currentContext` unchanged (defect 4).
- [ ] ISC-86: A subsequent "verse 8 to 12" after an implausible reference resolves against the last *plausible* context, or produces nothing (defect 4).
- [x] ISC-87: Words in `excludedWords` never normalise to a book name ("I am forty" does not yield 1 Samuel).
- [x] ISC-88: A book name shorter than 3 characters that is not an exact alias returns nil from `normalise`.
- [x] ISC-89: Exact aliases still resolve at length 1–2 ("Ps" → Psalms) via direct lookup, bypassing the fuzzy floor.
- [x] ISC-90: `isExactAlias` returns true for entries in `bookMappings`, `sttMishearings` and `abbreviations`.
- [ ] ISC-91: `suggestCorrection` never returns a book for an input whose fuzzy candidates span multiple books.
- [ ] ISC-92: Every one of the 66 canonical book names in `Bible.db` normalises to itself.

### Concatenated-number repair

- [x] ISC-93: `reinterpretConcatenatedRef` returns nil whenever the speaker supplied verse information — the guard is `!ref.verseWasSpoken, ref.verseEnd == nil` (defect 5). Reworded 2026-08-16: the shipped guard no longer tests `verseStart`, see Decisions.
- [x] ISC-93.1: `ScriptureReference.verseWasSpoken` records whether a verse number was actually heard rather than defaulting to 1, is excluded from `Equatable`, and is set true on a repaired reference so a split can never be applied twice.
- [x] ISC-94: "Amos 91:8-12" is not rewritten to "Amos 9:1" (defect 5).
- [x] ISC-95: "John123" with no spoken verse is rewritten to John 1:23 when that verse exists.
- [x] ISC-96: The rewrite candidate is only accepted when `bible.getVerses(from:)` returns a non-empty result.
- [x] ISC-97: When no split of the concatenated number yields an existing verse, the function returns nil and nothing is displayed.
- [x] ISC-98: A chapter number of a single digit is never split.
- [x] ISC-99: The rejection path emits a log line naming the reference that was not split.
- [x] ISC-100: A repaired reference carries the same book as the original — repair never changes the book.

### Bible lookup correctness

- [ ] ISC-101: `getVerse(book:chapter:verse:)` for John 3:16 in KJV returns text beginning "For God so loved the world".
- [ ] ISC-102: `getVerses(from:)` for Psalms 9:8-12 returns exactly five verses numbered 8 through 12.
- [x] ISC-103: A `SELECT` against `Bible.db` confirms Psalms has 150 chapters and Amos has 9.
- [x] ISC-104: `referenceExists` returns false for Amos 91.
- [x] ISC-105: `referenceExists` returns true for Psalms 91.
- [x] ISC-106: `referenceExists` returns false when `verseEnd < verseStart`.
- [x] ISC-107: `referenceExists` returns false for `verseStart < 1`.
- [ ] ISC-108: A verse range that runs past the end of a chapter returns only the verses that exist, not an error.
- [ ] ISC-109: `getVerseText(from:)` joins a range into a single string separated by single spaces.
- [ ] ISC-110: `maxChapter(forBookNamed:)` returns nil for an unknown book name.
- [ ] ISC-111: `findBookId` resolves both canonical names and the `aliases` column of the `books` table.
- [ ] ISC-112: `isValidChapter` rejects chapter 0 and negative chapters.
- [ ] ISC-113: The `books` table contains exactly 66 rows.
- [ ] ISC-114: Every `verses` row references a `book_id` present in `books`.
- [ ] ISC-115: Lookup for a verse absent from a given translation returns nil rather than a verse from another translation.
- [ ] ISC-116: `BibleService.isLoaded` is false before `loadDatabase()` and detection short-circuits with a warning rather than crashing.

### Translations and version management

- [ ] ISC-117: The five bundled translations KJV, WEB, ASV, BSB and LSV are all present in the `translations` table.
- [x] ISC-118: Each bundled translation has at least 31,086 verse rows.
- [ ] ISC-119: Switching the global translation changes the text returned for the same reference.
- [ ] ISC-120: Per-card translation switching changes only that card, leaving the global selection untouched.
- [ ] ISC-121: `BSB` and `LSV` are flagged premium and are gated for Mercy-tier accounts.
- [ ] ISC-122: KJV, WEB and ASV are available on the Mercy tier without a subscription.
- [ ] ISC-123: Downloadable premium versions (WEBBE, YLT, DBY, DRA, BBE) are listed but not present in the bundled database.
- [ ] ISC-124: A downloaded version's verse count matches the declared `verseCount` for that version.
- [ ] ISC-125: Attribution text for BSB and LSV is displayed wherever those translations are shown.
- [ ] ISC-126: Changing translation on a pushed card updates DivineView's translation label.
- [ ] ISC-127: An unavailable premium translation is never silently substituted with a free one.

### Confidence scoring and thresholds

- [ ] ISC-128: Every `DetectionResult` carries a `confidence` value in the closed range 0.0–1.0.
- [x] ISC-129: An exact-alias book match scores higher than a fuzzy match of the same reference.
- [x] ISC-130: A fuzzy match at Levenshtein distance 2 scores lower than one at distance 1.
- [x] ISC-130.1: The book-guess penalty and the acceptance gate stay compatible: one edit costs `0.4 × bookGuessPenaltyPerEdit` of overall confidence, which must remain below the 0.030 of headroom `chapterOnly` has above `minimumConfidence`. At the shipped 0.07 that is 0.028.
- [ ] ISC-130.2: The confidence figures asserted in `ConfidencePenaltyTests` are the figures `parseMatch` actually produces, rather than a re-derivation of the same formula.
- [ ] ISC-131: An implicit phrase match is only accepted when `confidence >= 0.6` (`DetectionPipeline.swift:297`).
- [ ] ISC-132: `DetectionSettings.lowConfidenceThreshold` defaults to 0.70 and persists under `detection.lowConfidenceThreshold`.
- [ ] ISC-133: `isLowConfidence(_:)` returns true exactly when the value is below the configured threshold.
- [ ] ISC-134: With `autoHoldLowConfidence` enabled, a below-threshold detection is held for review rather than added as a normal card.
- [ ] ISC-135: `showConfidenceIndicators` toggles the confidence badge on verse cards.
- [ ] ISC-136: The confidence figure never appears on the audience-facing surface (DivineView or ProPresenter).
- [ ] ISC-137: `resetToDefaults()` restores all five detection settings to their documented defaults.

### Pending buffer and operator console

- [ ] ISC-138: A confirmed detection adds exactly one `PendingVerse` to `BufferManager.pendingVerses`.
- [ ] ISC-139: `markAsPushed(id:)` keeps the verse in the list with a pushed indicator rather than removing it.
- [ ] ISC-140: `remove(id:)` removes the verse and returns it.
- [ ] ISC-141: `nextVerse(id:)` advances `currentVerseIndex` and returns false at the end of the range.
- [ ] ISC-142: `previousVerse(id:)` decrements `currentVerseIndex` and returns false at index 0.
- [ ] ISC-143: `setCurrentVerse(id:index:)` clamps out-of-range indices rather than crashing.
- [ ] ISC-144: `clearAll()` empties `pendingVerses` and leaves `history` intact.
- [ ] ISC-145: `clearHistory()` empties `history` and leaves `pendingVerses` intact.
- [ ] ISC-146: `updateTranslation(id:translation:verses:)` replaces the verse text in place without changing the reference.
- [ ] ISC-147: `PendingVerse.displayReference` renders a range as "John 3:16-17" and a single verse as "John 3:16".
- [ ] ISC-148: Selecting a card and pressing the Push key pushes that card, not the first card in the list.
- [ ] ISC-149: Deleting the selected card moves selection to a valid neighbouring card.

### DivineView presentation window

- [ ] ISC-150: `Window → DivineView` opens a window distinct from the operator console.
- [x] ISC-151: `present(reference:text:translation:)` sets `isShowingVerse` false when the text is blank or whitespace-only.
- [ ] ISC-152: `presentAll(from:)` renders the full range text and the range reference.
- [x] ISC-153: `presentOne(from:)` guards on `currentVerse` and leaves the existing verse on screen when the pending verse has no items.
- [ ] ISC-154: `presentOne(from:)` renders a single-verse reference of the form "John 3:17".
- [x] ISC-155: `clear()` empties reference, verse text and translation and sets `isShowingVerse` false.
- [ ] ISC-156: The empty state shows the background fill only, with no residual verse text.
- [x] ISC-157: `DivineViewSettings.background` persists to `UserDefaults` key `divineView.background`.
- [ ] ISC-158: Black background renders white text and white background renders black text.
- [x] ISC-159: `openOnPush` persists to `divineView.openOnPush` and defaults to true on first launch.
- [ ] ISC-160: With `openOnPush` false, pushing a verse does not increment `windowOpenTick`.
- [ ] ISC-161: With `openOnPush` true and the window already open, a push calls `orderFrontRegardless()` and does not activate the app.
- [ ] ISC-162: An operator-initiated open (`reason: .userRequested`) calls `makeKeyAndOrderFront` and activates the app.
- [ ] ISC-163: A miniaturised DivineView window is deminiaturised on either open reason.
- [ ] ISC-164: Verse body text scales with window size and never truncates at 1280×720 for a five-verse passage.
- [ ] ISC-165: The translation label is hidden when the translation string is empty.
- [ ] ISC-166: DivineView renders correctly when dragged to a second display and full-screened.

### ProPresenter integration and the panic path

- [ ] ISC-167: Push All sends a formatted stage message containing the reference and the full range text.
- [ ] ISC-168: Push One sends a single-verse stage message of the form "John 3:17\n<text>".
- [ ] ISC-169: Push One auto-advances to the next verse after a successful send.
- [ ] ISC-170: A failed ProPresenter push still writes the verse to DivineView and still marks the card pushed locally.
- [ ] ISC-171: A failed push surfaces an error the operator can see and retry.
- [ ] ISC-172: `PanicButtonService.triggerClear()` clears DivineView before any network call is attempted.
- [ ] ISC-173: `triggerClear()` clears the ProPresenter stage display via HTTP DELETE.
- [ ] ISC-174: `triggerClear()` clears the ProPresenter audience display via the configured path (Messages API or keyboard automation).
- [ ] ISC-175: `triggerClear()` does not clear `pendingVerses` or `history`.
- [ ] ISC-176: A second `triggerClear()` while `state == .clearing` is ignored.
- [ ] ISC-177: Panic state returns to `.idle` within 1.5 seconds of completion.
- [ ] ISC-178: F12 and Cmd+Escape both trigger the clear.
- [ ] ISC-179: `HybridIntegrationManager.clearAllDisplays()` returning false sets `state` to `.error` with a message.
- [ ] ISC-180: `ProPresenterSettings.topology == .twoMachines` hides keyboard automation and requires a Premium entitlement.

### Persistence and settings

- [ ] ISC-181: All DivineView settings survive an app relaunch.
- [ ] ISC-182: All detection settings survive an app relaunch.
- [ ] ISC-183: `panicButton.playAudio` and `panicButton.showVisual` default to true when unset.
- [ ] ISC-184: The selected audio input device survives an app relaunch.
- [ ] ISC-185: The selected translation survives an app relaunch.
- [ ] ISC-186: ProPresenter IP, port and topology survive an app relaunch.
- [ ] ISC-187: A corrupt or unparseable `UserDefaults` value falls back to the documented default rather than crashing.
- [ ] ISC-188: No setting is written to `UserDefaults` under an un-namespaced key.
- [ ] ISC-189: Service session state (pastor profile, service type) is restored on relaunch within the tier's profile limit.

### Performance and latency

- [ ] ISC-190: Time from end of a spoken reference to the verse card appearing is under 2 seconds at p50.
- [ ] ISC-191: The same measurement is under 3.5 seconds at p95.
- [ ] ISC-192: The detection debounce is 300 ms and is measured, not assumed.
- [ ] ISC-193: A single Bible lookup for a five-verse range completes in under 20 ms.
- [ ] ISC-194: `Push` to DivineView renders within one display frame of the button press.
- [ ] ISC-195: `triggerClear()` blanks DivineView in under 100 ms, independent of ProPresenter round-trip time.
- [ ] ISC-196: Sustained 60-minute transcription does not grow resident memory by more than 100 MB.
- [ ] ISC-197: CPU usage while listening in a silent room stays under 15% on Apple silicon (the damped-restart path must not spin).

### Anti-criteria

- [x] ISC-198: Anti: an ambiguous fuzzy book match is never silently resolved to an arbitrary book — `fuzzyMatch` must return nil, not `candidates.first`.
- [ ] ISC-199: Anti: no code path in the detection stack iterates a Swift `Dictionary` and depends on the resulting order. (`BibleService.findBookId` no longer does; `ImplicitReferenceDetector.bestMatch` still does — see ISC-199.2 and Verification.)
- [x] ISC-199.1: `BibleService.findBookId` resolves by exact match first and otherwise walks `bookCache.keys.sorted()` keeping the longest match, so it returns the same id on every launch.
- [ ] ISC-199.2: `ImplicitReferenceDetector.bestMatch(in:)` returns the same famous-verse match on every launch when a transcript contains more than one eligible phrase.
- [x] ISC-200: Anti: a fallback rewrite never discards an explicitly spoken verse range.
- [x] ISC-201: Anti: `ReferenceBuffer` is never written with a reference that failed `referenceExists`.
- [x] ISC-202: Anti: an alias of fewer than 3 characters is never used as a fuzzy match target.
- [ ] ISC-203: Anti: a detection is never displayed when the book was resolved by fuzzy match and the reference failed `referenceExists`.
- [ ] ISC-204: Anti: no verse is pushed to ProPresenter, DivineView or any other target without an explicit operator action.
- [ ] ISC-205: Anti: DivineView never takes key focus when a verse is pushed.
- [ ] ISC-206: Anti: the panic clear never empties the operator's verse history.
- [ ] ISC-207: Anti: the confidence percentage never appears on an audience-facing surface.
- [ ] ISC-208: Anti: audio is never written to disk or transmitted to a Divine Link-operated server.
- [ ] ISC-209: Anti: the app never requires a network connection to detect, look up and display a verse from a bundled translation.
- [ ] ISC-210: Anti: no FreeShow, EasyWorship, NDI or OBS client code ships in this ideal state.
- [ ] ISC-211: Anti: `ImplicitReferenceDetector` never fires on a phrase of fewer than 5 words.
- [ ] ISC-212: Anti: a premium translation is never rendered for a Mercy-tier account.
- [ ] ISC-213: Anti: no user-facing string uses American spelling.
- [ ] ISC-214: Anti: a transcription session restart never duplicates a committed transcript line.
- [ ] ISC-215: Anti: the detector never returns a reference whose book is absent from `Bible.db`.

### Antecedent criteria

- [ ] ISC-216: Antecedent: the operator can see, for every card, whether the book came from an exact alias or a fuzzy match — trust requires knowing which decisions the machine guessed at.
- [ ] ISC-217: Antecedent: rejection is visible. When the detector refuses an ambiguous reference, the operator sees that something was heard and discarded, not silence indistinguishable from a missed cue.
- [ ] ISC-218: Antecedent: the panic clear is reachable without moving the mouse or leaving the operator window.
- [ ] ISC-219: Antecedent: the first three detections of a service are correct, because an operator who is burned early pre-reads every card for the rest of the service.
- [ ] ISC-220: Antecedent: the card carries the full spoken range, so the operator never has to reconstruct what was asked for from what was displayed.
- [ ] ISC-221: Antecedent: DivineView is legible from the back of a 20-metre room at the default type scale on a 1080p projector.
- [ ] ISC-222: Antecedent: nothing in the operator window animates or moves except in response to an operator action, so peripheral vision is not a distraction during the sermon.

## Test Strategy

| isc | type | check | threshold | tool |
|---|---|---|---|---|
| ISC-1 | build | Xcode build of the DivineLink scheme | exit 0 | `xcodebuild build` |
| ISC-2 | static | count declarations of `maxChapter(forBookNamed:)` in BibleService | exactly 1 | `rg -c` |
| ISC-3 | build | full unit test run | exit 0, 0 failures | `xcodebuild test` |
| ISC-4 | build | warning count in Detection sources | 0 | `xcodebuild` log grep |
| ISC-5 | packaging | Bible.db present in built bundle | file exists | `ls` on `.app/Contents/Resources` |
| ISC-6 | static | TODO markers referencing the defects | 0 matches | `rg TODO` |
| ISC-7 | repo | working tree clean post-build | empty output | `git status --porcelain` |
| ISC-8 | static | test file coverage per detection concern | ≥4 files | `ls DivineLinkTests` |
| ISC-9–ISC-13 | integration | device enumeration, default selection, persistence, unplug fallback | expected device identity | XCTest against `AudioDeviceManager` |
| ISC-14–ISC-17 | integration | buffer publication, frame length, RMS, level decay | non-zero / ≤1 s | XCTest with a synthetic audio source |
| ISC-18 | manual | permission denial path | visible error | manual run with permission revoked |
| ISC-19 | unit | device-change debounce interval | 300 ms | XCTest with a virtual scheduler |
| ISC-20–ISC-24 | integration | permission, session start, on-device gating, fallback logging | expected flags | XCTest against `TranscriptionService` |
| ISC-25–ISC-26 | unit | segment publication for partial and final results | one segment each | XCTest on `handleRecognitionResult` |
| ISC-27–ISC-31 | unit | seamless handoff ordering, zero buffer loss, `lastTranscript` reset, single committed line | exact counts | XCTest with a fake recogniser |
| ISC-32–ISC-33 | unit | error-code routing | damped restart / swallowed | XCTest with injected `NSError` |
| ISC-34 | unit | teardown leaves no live subscriptions | all nil | XCTest |
| ISC-35 | unit | contextual strings applied when model ready | applied | XCTest with a stub model |
| ISC-36 | integration | reference spanning a restart boundary | 1 detection | XCTest with scripted segments |
| ISC-37–ISC-46 | unit | table-driven parse of explicit forms | exact `ScriptureReference` | XCTest against `ScriptureDetectorService` |
| ISC-47–ISC-60 | unit | table-driven parse of spoken and verbal forms | exact `ScriptureReference` | XCTest against `ScriptureDetectorService` |
| ISC-61–ISC-69 | unit | partial resolution against seeded context, including expiry and disable | expected reference or nil | XCTest against `ReferenceBuffer` + detector |
| ISC-70 | static | direct `updateContext` calls outside `cacheContext` | 0 matches | `rg 'referenceBuffer.updateContext'` |
| ISC-71–ISC-72 | unit | context inheritance and session-boundary clear | expected book / nil | XCTest |
| ISC-73, ISC-75, ISC-76, ISC-78 | static | source-level assertions on the normaliser | present | Read of `ScriptureDetectorService.swift` |
| ISC-74 | behavioural | 100 cold launches, compare ordered candidates | identical each run | shell loop over a test binary |
| ISC-77, ISC-80–ISC-82 | unit | normaliser behaviour with and without chapter hints | expected book or nil | XCTest against `BookNameNormaliser` |
| ISC-79, ISC-84 | static | pipeline wiring of provider and validator | both assigned | Read of `DetectionPipeline.swift` |
| ISC-83 | static | early return in `cacheContext` gated on validator | present | Read of `ScriptureDetectorService.swift` |
| ISC-85–ISC-86 | unit | buffer state after an implausible reference | unchanged context | XCTest with a stub validator |
| ISC-87–ISC-92 | unit | excluded words, length floor, exact aliases, 66-book round trip | expected book or nil | XCTest + `Bible.db` book list |
| ISC-93 | static | guard on `verseWasSpoken`/`verseEnd` in the repair function | present | Read of `DetectionPipeline.swift` |
| ISC-93.1 | unit | spoken verse blocks the split, chapter-only permits it, repaired reference is flagged | nil / non-nil / true | XCTest against `reinterpretConcatenatedRef` |
| ISC-94–ISC-100 | unit | repair behaviour on ranges, single digits, non-existent splits | expected reference or nil | XCTest against `reinterpretConcatenatedRef` |
| ISC-101–ISC-102 | unit | verse and range lookup content | exact text and count | XCTest against `BibleService` |
| ISC-103, ISC-113–ISC-114, ISC-118 | data | direct queries against the bundled database | exact counts | `sqlite3 Bible.db` |
| ISC-104–ISC-112, ISC-115–ISC-116 | unit | plausibility, bounds, joins, unknown books, unloaded state | expected boolean or nil | XCTest against `BibleService` |
| ISC-117, ISC-119–ISC-127 | unit/integration | translation switching, gating, attribution, download integrity | expected text and entitlement | XCTest + `sqlite3` + subscription stub |
| ISC-128–ISC-131 | unit | confidence range, exact vs fuzzy ordering, implicit gate | 0.0–1.0, ≥0.6 gate | XCTest against detector |
| ISC-130.1 | unit | per-edit cost against `chapterOnly` headroom | 0.028 < 0.030 | XCTest reading both constants |
| ISC-130.2 | unit | grid figures taken from `parseMatch` output, not recomputed | same ten rows | XCTest driving the detector |
| ISC-132–ISC-137 | unit | threshold defaults, persistence, hold behaviour, reset | documented defaults | XCTest against `DetectionSettings` |
| ISC-138–ISC-149 | unit | buffer mutation, navigation, clamping, display formatting | expected state | XCTest against `BufferManager` |
| ISC-150 | manual | window opens from the menu | distinct window | manual run |
| ISC-151, ISC-153, ISC-155, ISC-157, ISC-159 | unit | existing DivineView tests | assertions pass | `DivineViewTests.swift` |
| ISC-152, ISC-154, ISC-160 | unit | range vs single rendering, `openOnPush` false path | expected strings and tick | XCTest |
| ISC-156, ISC-158, ISC-164–ISC-166 | visual | empty state, contrast, scaling, second display | screenshot comparison | manual run + screenshot |
| ISC-161–ISC-163 | integration | focus behaviour on push vs user request, deminiaturise | app not activated on push | XCTest + AppKit assertions |
| ISC-167–ISC-171 | integration | stage message formatting, auto-advance, failure isolation | expected payload | XCTest with a stubbed `ProPresenterClient` |
| ISC-172–ISC-179 | unit | panic ordering, history preservation, re-entrancy, state reset, shortcuts | expected state | XCTest against `PanicButtonService` |
| ISC-180 | unit | topology gating | keyboard path hidden | XCTest against `ProPresenterSettings` |
| ISC-181–ISC-189 | integration | relaunch persistence and defaulting | values restored | XCTest with a fresh `UserDefaults` suite |
| ISC-190–ISC-191 | performance | utterance-to-card latency over 30 scripted utterances | p50 <2 s, p95 <3.5 s | instrumented timestamps + log analysis |
| ISC-192–ISC-195 | performance | debounce, lookup, render and clear timings | 300 ms / 20 ms / 1 frame / 100 ms | `os_signpost` + Instruments |
| ISC-196–ISC-197 | performance | 60-minute soak in a silent room | <100 MB growth, <15% CPU | Instruments Allocations + Activity Monitor |
| ISC-198–ISC-203 | unit | regression assertions mirroring the five defects | expected nil / preserved range | XCTest |
| ISC-199.1 | unit | prefix-colliding book pairs and repeated-call stability | distinct ids, identical across 50 calls | XCTest against `BibleService.findBookId` |
| ISC-199.2 | behavioural | two tied famous phrases in one transcript, across cold launches | identical match each run | shell loop over a test binary |
| ISC-204 | static | push call sites originate from a user action | 0 automatic callers | `rg` on `pushVerse`/`present` call graph |
| ISC-205 | integration | key window unchanged after a push | operator window stays key | XCTest + AppKit |
| ISC-206 | unit | history intact after panic | counts unchanged | XCTest |
| ISC-207 | static | confidence never referenced in audience views | 0 matches | `rg` on DivineView + stage formatting |
| ISC-208 | static | no audio file write or upload in the capture path | 0 matches | `rg` for file/URLSession writes |
| ISC-209 | integration | full detect-lookup-display cycle with networking disabled | verse displayed | manual run with Wi-Fi off |
| ISC-210 | static | absence of FreeShow/OBS/NDI clients | 0 matching files | `rg` + file listing |
| ISC-211 | unit | phrase-length floor | rejects <5 words | XCTest against `ImplicitReferenceDetector` |
| ISC-212 | integration | premium translation on a Mercy account | gated | XCTest with a subscription stub |
| ISC-213 | static | American spelling scan of user-facing strings | 0 matches | `rg` for a spelling word list |
| ISC-214 | unit | committed line count across a restart | no duplicates | XCTest |
| ISC-215 | unit | detector output book is in the book table | always true | XCTest + `Bible.db` book list |
| ISC-216–ISC-218, ISC-220 | design review | provenance badge, rejection surface, keyboard reach, range fidelity | present and legible | manual UI walkthrough |
| ISC-219 | field | first three detections in a recorded service | 3/3 correct | recorded-audio replay harness |
| ISC-221 | field | legibility at 20 m on a 1080p projector | readable | in-room check |
| ISC-222 | design review | no unsolicited motion in the operator window | 0 animations | manual observation |

## Features

| name | satisfies | depends_on | parallelizable |
|---|---|---|---|
| Restore build health | ISC-1, ISC-2, ISC-3, ISC-4 | — | no |
| Deterministic book normalisation | ISC-73, ISC-74, ISC-75, ISC-76, ISC-77, ISC-198, ISC-199, ISC-199.1, ISC-199.2, ISC-202 | Restore build health | no |
| Chapter-aware disambiguation | ISC-78, ISC-79, ISC-80, ISC-81, ISC-82, ISC-110 | Deterministic book normalisation | no |
| Validated reference context | ISC-70, ISC-83, ISC-84, ISC-85, ISC-86, ISC-201 | Chapter-aware disambiguation | no |
| Range-preserving concatenation repair | ISC-93, ISC-93.1, ISC-94, ISC-95, ISC-96, ISC-97, ISC-98, ISC-99, ISC-100, ISC-200 | Restore build health | yes |
| Detection regression test suite | ISC-8, ISC-37–ISC-60, ISC-87–ISC-92, ISC-203, ISC-215 | Validated reference context | yes |
| Contextual partial resolution tests | ISC-61–ISC-69, ISC-71, ISC-72 | Validated reference context | yes |
| Bible lookup verification | ISC-101–ISC-116 | Restore build health | yes |
| Translation coverage and gating | ISC-117–ISC-127, ISC-212 | Bible lookup verification | yes |
| Transcription session integrity | ISC-20–ISC-36, ISC-214 | Restore build health | yes |
| Audio capture and device robustness | ISC-9–ISC-19 | Restore build health | yes |
| Confidence surface and thresholds | ISC-128–ISC-137, ISC-207, ISC-216 | Detection regression test suite | yes |
| Operator console and buffer behaviour | ISC-138–ISC-149, ISC-206, ISC-222 | Restore build health | yes |
| DivineView presentation correctness | ISC-150–ISC-166, ISC-205, ISC-221 | Restore build health | yes |
| ProPresenter and panic path | ISC-167–ISC-180, ISC-204 | DivineView presentation correctness | no |
| Settings persistence audit | ISC-181–ISC-189 | Restore build health | yes |
| Latency and soak instrumentation | ISC-190–ISC-197 | Detection regression test suite | no |
| Offline and privacy guarantees | ISC-208, ISC-209, ISC-210, ISC-211 | Restore build health | yes |
| British English copy audit | ISC-213 | — | yes |
| Rejection visibility in the operator UI | ISC-217, ISC-218, ISC-219, ISC-220 | Confidence surface and thresholds | no |

## Decisions

- **2026-08-16 — Seeded this ISA retroactively, mid-flight.** Divine Link reached v1.6.2 without a project ISA; the system of record was spread across `PROJECT_STATUS.md`, `docs/FEATURE-MATRIX.md`, the BMAD story files and two Plans documents. This file was written on 2026-08-16 while a concurrent agent was applying the detection fixes described below to `ScriptureDetectorService.swift`, `DetectionPipeline.swift` and `BibleService.swift`. Criteria describing those fixes are therefore split: source-level assertions that could be read directly are marked verified; behavioural assertions requiring a build are pending, because the build is currently broken (see the next entry).

- **2026-08-16 — Build is currently broken by a duplicate declaration.** `BibleService.swift` declares `maxChapter(forBookNamed:)` twice inside `class BibleService`, at lines 452 and 627, with `referenceIsPlausible` and `referenceExists` as near-duplicate siblings. This is an invalid redeclaration and blocks compilation. Recorded rather than fixed: the file is owned by the in-flight agent and this ISA is read-only with respect to `DivineLink/`. Captured as ISC-2.

- **2026-08-16 — refined: the duplicate declaration was a transient mid-write state, not a defect.** The entry above was written while a concurrent agent held `BibleService.swift` open, and it recorded a half-applied edit as though it were the shipped state. At commit `1813b72` the file declares `maxChapter(forBookNamed:)` exactly once, at line 612, alongside a single `referenceExists(_:)` at line 620; the near-duplicate sibling was never committed. What was mistaken for a second declaration is `getMaxChapter(for bookId: Int)` at line 445, a different function taking a book id rather than a name. ISC-2 has been rewritten to assert the single declaration and marked verified. The lesson is narrower than it looks: reading a working tree that another agent is actively writing yields a state that never existed and will never be reproducible, so a source observation is only evidence when the tree is quiescent or the read is pinned to a commit.

- **2026-08-16 — refined: the validator shipped as `referenceExists(_:)`, not `referenceIsPlausible(_:)`.** Criteria ISC-84, ISC-104, ISC-105, ISC-201 and ISC-203 were drafted against the latter name, which appeared in the in-flight tree and did not survive into `1813b72`. The criteria and the ISC-84 verification entry now name `referenceExists`. Behaviour is unchanged — known book, chapter in range, verse at least 1, and no inverted range — and the doc comment still describes it as a plausibility check, which is why the drafted name felt right. Recorded rather than silently corrected, because a criterion that cites a symbol which does not exist cannot fail honestly: it fails as a typo and gets waved through.

- **2026-08-16 — Defect 1: reject ambiguous fuzzy matches rather than resolving them.** `fuzzyCandidates` now iterates `bookMappings.keys.sorted()` and collects every alias tied at the minimum edit distance; `fuzzyMatch` returns nil when those aliases map to more than one canonical book. The rejected alternative was to add a deterministic tiebreak (alphabetical, or shortest alias) — deterministic, but still arbitrary, and arbitrary is exactly the property that put Amos on the screen. Silence beats a stable wrong answer.

- **2026-08-16 — Defect 2: introduced `minimumFuzzyAliasLength = 3`.** Aliases shorter than three characters are now exact-match only. Two-letter aliases such as "am" and "ho" sit within one edit of a large fraction of ordinary English, so they were manufacturing confident false positives. Exact lookup still resolves "Ps" and similar, so nothing legitimate was lost.

- **2026-08-16 — Defect 3: threaded a chapter hint through normalisation.** `normalise(_:chapterHint:)` now filters ambiguous candidates through an injected `chapterCountProvider`, wired in `DetectionPipeline.wireDetectorToBible()` to `BibleService.maxChapter(forBookNamed:)`. Chapter counts were already in the database and already loaded; the fix was to use knowledge the system had rather than acquire new knowledge. Note the honest limit: for chapter 9 the hint disambiguates nothing, because Amos has exactly 9 chapters — the hint only rescues the concatenated case ("chapter 91"), and the ambiguous case still resolves to nil.

- **2026-08-16 — Defect 4: gated all context writes behind validation.** The five call sites that previously wrote `ReferenceBuffer.updateContext` directly now route through a single `cacheContext(for:)` helper that returns early when an injected `referenceValidator` — `BibleService.referenceIsPlausible` — rejects the reference. The alternative of validating inside `ReferenceBuffer` was rejected because the buffer has no business knowing about the Bible database; dependency injection at the detector boundary keeps the buffer a pure state container.

- **2026-08-16 — Defect 5: concatenation repair now refuses to fire over a spoken range.** `reinterpretConcatenatedRef` guards on `verseStart == 1 && verseEnd == nil` and logs the refusal. The alternative — preserving the range while still splitting the chapter — was rejected: if the speaker said both a large chapter number and an explicit range, the parse is untrustworthy in a way a rewrite cannot repair, and rejecting is the honest outcome.

- **2026-08-16 — All five fixes shipped as commit `1813b72`.** The five entries above were written while the work was in flight and described intent; this records the landed state. `1813b72` touched `BibleService.swift`, `DetectionPipeline.swift`, `ScriptureDetectorService.swift` and `.gitignore`, and added `DivineLink/DivineLinkTests/BookMishearingTests.swift` — twelve normaliser tests plus three detection-level regressions, taking the suite to 33 test methods across three files. Every fix landed as designed with one exception, recorded in the next entry. The test file is the material change: the defects were diagnosed by reading source, and source reading cannot distinguish a fix from a plausible-looking edit. Fifteen criteria moved from pending to verified on the strength of those tests; the ones that did not are named in Verification.

- **2026-08-16 — Judgement call: bare "sam" maps to Psalms.** Flagged explicitly because it is the one place where the fix chose a guess over a refusal. "sam" sits one edit from aliases belonging to Amos, James, Lamentations, Psalms and both Samuels, so by the rule established for defect 1 it should resolve to nil. Instead "sam", "sams", "size" and "salms" were promoted to direct Psalms aliases in `bookMappings`, which means they resolve by exact lookup and never reach the ambiguity check at all. The reasoning is about how people actually speak rather than about string distance: a preacher naming Samuel says "first Samuel" or "one Sam", never a bare "sam", because the book number is part of the name. A bare "sam" is therefore far likelier to be a mishearing of "psalms" than a truncation of "Samuel". The cost is accepted and stated plainly — an operator who does say a bare "sam" meaning Samuel will get Psalms, and no chapter hint will save them, since exact aliases are resolved before chapter filtering. That path is deliberately unguarded; if it turns out to occur in the field, the alias must be withdrawn rather than patched with a tiebreak.

- **2026-08-16 — refined: ISC-80 and ISC-81 reworded, ISC-82 dropped, following the alias decision.** All three were drafted on the assumption that "sam" would remain a fuzzy-matched mishearing whose ties the chapter hint would settle. The alias decision above removed that assumption. ISC-80 keeps its assertion — `normalise("sam", chapterHint: 91)` returns "Psalms" — but its stated mechanism was wrong and now names the exact-alias path; the outcome the criterion protects is unchanged, which is why it was reworded rather than replaced. ISC-81 kept its purpose, an unresolvable tie returning nil rather than a guess, but its probe had to move to a case that is genuinely still ambiguous, so it now uses `normalise("a john", chapterHint: 1)`, where chapter 1 exists in all three Johannine epistles. ISC-82 could not be salvaged: it asserted that a bare "sam" returns nil, which the alias decision makes a regression rather than an ideal, so it is tombstoned in place rather than renumbered. Recorded because two of these edits made previously failing criteria passable, and that is precisely the move which needs to be visible to be trusted.

- **2026-08-16 — Fuzzy confidence penalty raised from 0.05 to 0.15 per edit.** A two-edit fuzzy match previously cost 0.10 of reference clarity, which left a guessed book scoring close enough to a spoken one that the operator could not tell them apart on the card. At 0.15, with a floor of 0.4, a fuzzy resolution is visibly less confident than an exact alias. This is the softer half of the defect-1 remedy: rejection handles ambiguity between books, and the penalty handles the case where the candidates agree but the input was still a guess. Chosen over surfacing a separate "matched approximately" flag because the confidence figure is already on screen and already read.

- **2026-08-16 — Deferred: `BibleService.findBookId` still depends on dictionary order.** Its prefix-matching fallback iterates `bookCache`, a Swift `Dictionary`, and returns the first key that prefixes the query or is prefixed by it — the same first-match-wins-over-random-order shape that caused defect 1, in a function now reached on every detection through `maxChapter(forBookNamed:)` and `referenceExists`. It is materially less dangerous than the original, since a book name arriving here has already been normalised, but it is not safe, and ISC-199 stays open with the site named. Not fixed here because this ISA is read-only with respect to `DivineLink/` and a second agent is auditing the same tree.

- **2026-08-16 — DivineView ships before FreeShow.** Per `Plans/Presentation-Outputs-Roadmap.md` §2, owning a display surface outranks adding a third-party integration. FreeShow's REST contract is documented and deliberately parked; Story 8.6 stays open behind Story 8.7.

- **2026-08-16 — DivineView does not take key focus on push.** `requestOpenWindow(reason:)` distinguishes `.userRequested` (activate the app) from `.versePushed` (`orderFrontRegardless()` only). Taking key status on push would break the operator window's Space/Enter/Delete shortcuts and could interrupt ProPresenter's keyboard automation mid-service.

- **2026-08-16 — Panic clears audience surfaces only.** `PanicButtonService.triggerClear()` blanks DivineView and both ProPresenter paths but deliberately leaves `pendingVerses` and `history` intact so the operator can re-send. Recorded because it looks like an omission and is not.

- **2026-08-16 — Audit remediation shipped as commit `adaea2e`.** A cross-vendor audit failed `1813b72` on three critical findings: `findBookId` was still order-dependent, the confidence penalty had been raised without checking it against the acceptance gate, and `reinterpretConcatenatedRef` was private and untested. `adaea2e` addressed all three, added `BibleServiceLookupTests.swift`, `ConfidencePenaltyTests.swift` and `DetectionPipelineTests.swift`, and took the suite from 33 to 56 test methods. Fifteen criteria moved to verified on the strength of it, including the first behavioural closure of the build and test criteria (ISC-1, ISC-3), which every previous reconciliation had inherited rather than observed. The entries below record what the commit changed about this document's own claims, which is the part that would otherwise go unrecorded.

- **2026-08-16 — refined: the fuzzy confidence penalty is 0.07, not the 0.15 recorded above.** The earlier entry raised the penalty from 0.05 to 0.15 on the reasoning that a guessed book should look visibly less confident than a spoken one. That reasoning was sound and the number was not: nobody checked it against the acceptance gate. Clarity carries weight 0.4 in the overall score, so each edit costs 0.4 × penalty overall. The tightest pattern that can reach the gate is `chapterOnly`, which bases at 0.780 against `minimumConfidence` of 0.75 — 0.030 of headroom — so a one-edit book guess survives only while the penalty stays below 0.030 / 0.4 = 0.075. At 0.15 every one-edit `chapterOnly` match scored 0.720 and was silently dropped: "Romans 8" with a single mishearing in the book name would simply not appear, and the operator would read that as a missed cue rather than a refusal. The shipped value is 0.07, giving 0.028 per edit. The order of work is the lesson worth keeping — the full ten-pattern grid was pinned in a test *before* the number was retuned, so the retune had something to fail against; the original change had no grid and therefore no way to be wrong out loud. `ConfidencePenaltyTests.testPenaltyAndGateRemainCompatible` now states the arithmetic as an assertion, so moving either constant fails with the sum spelled out rather than as a distant behavioural surprise.

- **2026-08-16 — refined: "size" and "sames" withdrawn as Psalms aliases.** The alias decision recorded above promoted "sam", "sams", "size" and "salms" to direct Psalms aliases. Two of those four were mistakes of different kinds. "size" is an ordinary English word — "…a size 10." scored 0.780 and put Psalms 10 on the screen with no warning — so it has been dropped and added to `excludedWords` alongside "sizes", barring it by both routes rather than one. "sames" sat one edit from "james" and mapped to Psalms, so a misheard James resolved to Psalms by *exact* match, bypassing the very tie logic that exists to refuse that guess; it has been dropped and left to the fuzzy path, where the ambiguity check can see it. The surviving aliases are "sam", "sams", "salms" and "psams", and the judgement behind them stands unchanged. What the two withdrawals share is that both were added by asking "could this be a mishearing of Psalms?" and neither by asking "what else is this word?" — the alias table is a claim about the whole language, not just about the book being aliased.

- **2026-08-16 — refined: `findBookId` is deterministic, and ISC-199 still does not close.** The deferral recorded above is discharged: `findBookId` now tries an exact match first and otherwise walks `bookCache.keys.sorted()` keeping the longest match, so "judges" resolves to Judges and "jude" to Jude on every launch. `sorted()` on `[String]` is Swift's ordinal Unicode comparison rather than `localizedStandardCompare`, so this survives a differently-configured machine. But ISC-199 asserts a stack-wide property and a second site was found while checking it: `ImplicitReferenceDetector.detect(in:)` iterates `famousVerses`, a `[String: String]`, and `bestMatch(in:)` takes `.first` of the confidence-sorted result. Confidence is `min(min(Float(phrase.count) / 30.0, 0.8) + 0.2, 1.0)`, and the boundary bonus repeats a containment test that has already gated entry, so it is unconditional and every phrase of 24 characters or more scores exactly 1.0 — which is 14 of the 15 phrases long enough to pass `minimumPhraseWords`. Swift's `sorted(by:)` is not stable, so a transcript quoting two famous verses in one debounce window resolves to whichever the dictionary seed happened to place first. ISC-199 has therefore been split rather than closed: ISC-199.1 records the fixed site as verified, ISC-199.2 names the remaining one, and the parent stays open until both are true. Not fixed here because it is a distinct defect with its own tie-break question — whether to prefer the longest matched phrase, or to refuse two simultaneous famous verses the way `fuzzyMatch` refuses two books — and inventing an answer at commit time is what produced the alias mistakes above.

- **2026-08-16 — refined: ISC-93 reworded; `verseStart == 1` replaced by `verseWasSpoken`.** ISC-93 asserted that `reinterpretConcatenatedRef` returns nil when `verseStart != 1` or `verseEnd != nil`, and its verification cited a guard reading `guard ref.verseStart == 1, ref.verseEnd == nil`. That guard no longer exists. `verseStart` defaults to 1 when no verse is heard, so testing it could not distinguish "Amos 91" — a chapter-only utterance that may legitimately be re-read as Amos 9:1 — from "Amos 91 verse 1", where the speaker named the verse and the trailing digit of the chapter is emphatically not it. Splitting the second silently substitutes a different passage. `ScriptureReference` therefore gained `verseWasSpoken`, and the guard is now `!ref.verseWasSpoken, ref.verseEnd == nil`. The field is deliberately excluded from `Equatable`: it is provenance, not identity, and including it would make the same passage compare unequal depending on the utterance that produced it, breaking duplicate suppression and every existing comparison. ISC-93 keeps its number and its purpose and has been reworded to name the shipped mechanism; the new property is pinned separately as ISC-93.1, placed under ISC-93 because the guard is the only reason the field exists. Recorded because a criterion that cites a symbol which is no longer in the code passes review by looking familiar.

- **2026-08-16 — Deferred, with a known tension: `verseExistence` stays hardcoded at 1.0.** Every pattern in `parseMatch` sets `verseExistence = 1.0` rather than asking the validator whether the verse is really there, even though `referenceValidator` is wired and available at that point. Scoring it honestly drops `chapterOnly` to 0.730, below the 0.75 gate, so "James 123" would be refused at the confidence check before `reinterpretConcatenatedRef` ever saw it — the repair path would be dead code for exactly the inputs it was written for. The tension is stated rather than resolved: the confidence model asserts that a verse exists while the validator that could prove it is consulted only for caching, so the figure on the operator's card is confident about something it has not checked. Fixing it properly means rebalancing the base weights so a validated-absent verse can be penalised without starving the repair path, which is a scoring change wanting its own grid and its own commit.

- **2026-08-16 — Deferred: "8 and following" parses as verse 8 alone.** `ScriptureReference` has no representation for an open-ended range, so the trailing words are ignored and the reference is the single verse named. This is pinned as the expected value in `testVerseRangesParseAcrossPhrasings` rather than left to be discovered, and pinning the real behaviour was chosen over asserting an aspiration the model cannot express. It is a genuine gap against the principle that a repair must never discard what the speaker said — the speaker asked for more than one verse and got one — but the honest fix is a range model that can hold "8ff", not a parser change. Recorded so that the passing test is not mistaken for the phrasing working.

## Changelog

- **conjectured:** Fuzzy string matching on book names is a safe convenience — speech recognition mishears, so tolerating a couple of edits recovers references that would otherwise be lost, and the worst case is a near-miss on a similar book.
  **refuted by:** A live service utterance of "the book of Psalms chapter 9, verse 8 to 12" displayed Amos 9:1. Tracing it showed the mishearing "sam" sat at Levenshtein distance 1 from aliases belonging to six different books, and `fuzzyMatch` iterated a Swift `Dictionary` — whose order is randomised per process — returning whichever tied candidate happened to come first. The same audio would have produced a different book on the next launch.
  **learned:** Any non-deterministic tie-break in a recognition path is a correctness bug, not a UX nicety. "Usually right" is not a property a recognition system can have when the operator has no way to tell which instance they are in; a wrong verse in front of a congregation costs more than a missed one, and unlike a miss it produces no signal to act on.
  **criterion now:** Ambiguity must be rejected rather than resolved. `fuzzyMatch` returns nil when tied candidates disagree on the book (ISC-75, ISC-198); no detection code path may depend on dictionary iteration order (ISC-73, ISC-199).

- **conjectured:** Caching the most recent reference is safe, because a reference that was just parsed is by definition the thing the preacher just said, and partial follow-ups ("verse 18") should resolve against it.
  **refuted by:** "Amos 91" — a reference that cannot exist, since Amos has 9 chapters — was written to `ReferenceBuffer` at parse time, before any validation. Every partial reference for the next five minutes resolved against it, so one bad parse corrupted an entire passage sequence rather than a single card.
  **learned:** State that feeds future decisions must be validated before it is written, not when it is read. The cost of bad state is not one wrong answer; it is every answer until the state expires, and an expiry window sized for operator convenience (five minutes) is exactly the wrong size for a corruption window.
  **criterion now:** All context writes route through `cacheContext(for:)` and are gated on `referenceIsPlausible` (ISC-70, ISC-83, ISC-201); an implausible reference leaves the buffer unchanged (ISC-85).

- **conjectured:** A repair heuristic that splits a concatenated number ("Book123" into "Book 1:23") is a pure improvement, because speech recognition genuinely produces that artefact and the split is trivially reversible if wrong.
  **refuted by:** The heuristic fired on "Amos 91:8-12", where a verse range had already been parsed, and hard-coded `verseEnd: nil`. The output was "Amos 9:1" — wrong book, wrong chapter interpretation, and the spoken range silently deleted. The operator saw a plausible-looking single verse with no indication that a range had been requested.
  **learned:** A repair may add interpretation but must never remove information the speaker explicitly supplied. Heuristics that rewrite are only safe where the field they overwrite was empty; the guard belongs on the input, not on the output.
  **criterion now:** `reinterpretConcatenatedRef` returns nil whenever `verseStart != 1` or `verseEnd != nil`, and logs the refusal (ISC-93, ISC-94, ISC-200).

- **conjectured:** Sorting the alias iteration in `fuzzyCandidates` removed the order dependence from the recognition path. The defect was diagnosed at a specific line, the fix was applied at that line, and the tests confirm the same input now yields the same book on every call.
  **refuted by:** Reconciling the shipped commit against ISC-199 — which asserts that *no* code path in the detection stack depends on dictionary order — surfaced `BibleService.findBookId`, whose prefix-matching fallback iterates `bookCache` and returns the first key that matches. It sits downstream of the fix, on the path every detection now takes through `maxChapter(forBookNamed:)` and `referenceExists`, and it was never touched. The determinism tests pass because they exercise the normaliser in isolation with an injected chapter-count provider, so they cannot see it.
  **learned:** A non-determinism audit has to be stack-wide, because the property is not local. Determinism does not compose upward from a fixed function: one order-dependent lookup anywhere downstream reintroduces exactly the failure mode that was removed, and a test that stubs the boundary where the remaining defect lives will report the fix as complete. The instinct to fix at the site of the traced symptom is what left this behind — the trace named one line, and the conjecture quietly narrowed from "the path is deterministic" to "that line is deterministic".
  **criterion now:** ISC-199 stays open with the offending site named in the criterion itself, so it cannot be closed by inspection of the normaliser alone. ISC-74 likewise stays open: in-process repetition is not the multi-launch probe the criterion specifies, and the original defect was invisible within a single process by construction.

- **conjectured:** Threading the spoken chapter through normalisation is sufficient to resolve the reported mishearing, because chapter counts are already in the database and "chapter 91" is impossible for Amos.
  **refuted by:** The hint discriminates only when the chapter actually falls outside some candidate's range. The utterance that caused the incident was "chapter 9" — valid for Amos, Psalms and both Samuels — so the tie survived the filter untouched and the hint rescued only the concatenated reading, "chapter 91". Chapter-aware disambiguation fixed the case that was easy to test and not the case that was reported.
  **learned:** Disambiguation by constraint only helps where the constraint discriminates, and it is worth checking that before treating it as the remedy. Its reach is a property of the data, not of the mechanism: here the mechanism was sound, the wiring correct, and the coverage close to nil for the reported input. The residual ambiguity had to be resolved somewhere else entirely — by promoting the field mishearings to exact aliases and accepting a deliberate, documented mapping, which is a judgement about speech rather than a computation over strings.
  **criterion now:** The chapter hint is asserted only against ties it genuinely settles (ISC-78, ISC-80) and against its own limits, including that it never overrides an exact alias (ISC-81); the mishearings themselves are handled by exact aliases, with the "sam" mapping recorded as a flagged judgement call in Decisions rather than presented as a derivation.

- **conjectured:** `findBookId` was the last order-dependent lookup in the detection stack, so making it deterministic closes ISC-199. The previous reconciliation audited stack-wide rather than at the traced line, found the one site the fix had missed, named it in the criterion, and `adaea2e` fixed exactly that site with tests pinning Judges≠Jude, the Philippian pair, the Johannine set and the Timothy set.
  **refuted by:** Grepping the whole detection stack for dictionary iteration before ticking the box surfaced a third site: `ImplicitReferenceDetector.detect(in:)` walks `famousVerses`, a `[String: String]`, and `bestMatch(in:)` takes `.first` of the result sorted by confidence. The containment test at the call site makes the boundary bonus unconditional, so every phrase of 24 characters or more scores exactly 1.0 — 14 of the 15 phrases long enough to qualify — and `sorted(by:)` is not stable in Swift. A transcript quoting two famous verses in one debounce window therefore resolves to whichever the per-process dictionary seed placed first. It had been there since before the incident, harmless only because nothing had exercised two phrases at once.
  **learned:** A stack-wide property cannot be discharged by fixing the sites you were led to. The first pass fixed where the trace pointed; the second fixed where the audit pointed; both were led by the defect, and each time the conjecture quietly narrowed from "the stack is deterministic" to "the sites I found are deterministic". The only probe that matches the shape of the claim is an exhaustive one — enumerate every dictionary iteration in the stack by type, then discharge each — because the criterion is universally quantified and no amount of tracing can close a universal. The pattern also explains why the site looked safe: order-dependence is only visible where two candidates tie, so every such lookup is latent until the day the input produces a tie, and "no test has hit it" is indistinguishable from "it cannot happen".
  **criterion now:** ISC-199 is split rather than closed. ISC-199.1 records the fixed lookup as verified; ISC-199.2 names the remaining site; the parent stays open and now states its own discharge method — enumerate `Dictionary` iterations across the detection stack — so it cannot be ticked by inspecting any single file.

- **conjectured:** Raising the fuzzy-match confidence penalty from 0.05 to 0.15 makes a guessed book look visibly less confident than a spoken one, which is a presentation improvement with no functional cost.
  **refuted by:** Clarity carries weight 0.4, so the penalty costs 0.4 × 0.15 = 0.060 overall, against 0.030 of headroom for the tightest pattern that can reach the acceptance gate. Every one-edit `chapterOnly` match scored 0.720 against a gate of 0.75 and was dropped. The change did not make those references look less confident; it made them not appear, and a reference that never renders is indistinguishable to the operator from a missed cue.
  **learned:** A number that feeds a threshold is not a presentation parameter, however it is described in the commit that changes it. The defect here was procedural rather than arithmetical — the value was changed before anything pinned what the values were, so there was nothing for the new number to fail against. Pinning the full grid first and retuning second turns the same mistake into a failing test with the sum printed in the message.
  **criterion now:** The shipped penalty is 0.07, and `ConfidencePenaltyTests.testPenaltyAndGateRemainCompatible` asserts the headroom arithmetic directly (ISC-130.1), so moving either the penalty or the gate fails loudly rather than silently narrowing what the detector will admit.

## Verification

Forty-eight ISCs are marked verified. Fifteen were established on 2026-08-16 by direct source reading or by querying the bundled database; fifteen more were added when this ISA was reconciled against commit `1813b72`; the remaining eighteen were added reconciling against `adaea2e`, which brought `BibleServiceLookupTests.swift`, `ConfidencePenaltyTests.swift` and `DetectionPipelineTests.swift`. Each entry names its probe type.

All source citations are pinned to the tree at `adaea2e`. That re-pinning was not cosmetic: `adaea2e` added roughly 250 lines to `ScriptureDetectorService.swift` above the normaliser, so every citation into that file from the previous pass was displaced by 200 to 280 lines and pointed at unrelated code, and the test files were reordered enough that the `BookMishearingTests` line numbers were wrong too — `testShortAliasesAreExactMatchOnly` moved from 88 to 159, `testChapterHintSettlesJohannineEpistles` from 121 to 197. Every citation below has been re-read against the current tree rather than adjusted by an offset. The lesson is recorded rather than merely fixed: a line number is a claim with a shelf life of one commit, so entries that can cite a symbol or a test name do so, and bare line numbers are used only where nothing more stable exists.

Every other ISC in this document is unverified and pending.

- **ISC-1** — behavioural. `xcodebuild -project DivineLink/DivineLink.xcodeproj -scheme DivineLink -destination 'platform=macOS' build` exits 0 on the working tree, with the DivineView sources and the operator rejection row compiled in. First time this criterion has been observed rather than inherited.
- **ISC-2** — static. `rg -c 'func maxChapter\(forBookNamed'` over `BibleService.swift` returns 1; the declaration is at line 638. `getMaxChapter(for bookId: Int)` at line 471 is a distinct function taking a book id, and was what the superseded ISC-2 mistook for a second declaration.
- **ISC-3** — behavioural. `xcodebuild test -scheme DivineLink -destination 'platform=macOS'` reports `** TEST SUCCEEDED **` with 65 test methods passing and zero failures, across eight classes: `BibleServiceLookupTests`, `BookMishearingTests`, `SpokenPsalmsRangeTests`, `ConfidencePenaltyTests`, `DetectionPipelineWiringTests`, `ConcatenatedReferenceRepairTests`, `DivineViewTests` and `NumberedBookDetectionTests`. Every test-backed entry below was additionally read for its logic, so none of them rests on the count alone.
- **ISC-8** — static. `DivineLinkTests/` holds eight test classes across six files covering all four named concerns: normalisation (`BookMishearingTests.swift`, `NumberedBookDetectionTests.swift`), partial resolution (`BookMishearingTests.testPriorAmosContextDoesNotBiasTowardsAmos` at `:376` and the context tests around it), concatenation repair (`DetectionPipelineTests.swift`, class `ConcatenatedReferenceRepairTests` at `:80`) and lookup (`BibleServiceLookupTests.swift`). The two-file state the criterion was written against no longer holds.
- **ISC-70** — static. Repo-wide search returns six `cacheContext(for:` call sites — `ScriptureDetectorService.swift:815`, `:921`, `:1014`, `:1059`, `:1088` and `DetectionPipeline.swift:378` — and exactly one `referenceBuffer.updateContext` call, at `ScriptureDetectorService.swift:1253`, inside the helper. The sixth call site is new in `adaea2e`: the pipeline caches the *corrected* reference after a successful split, which is still routed through the same gate, so the criterion holds with one more caller than when it was written.
- **ISC-73** — static. `ScriptureDetectorService.swift:1598`: `for alias in sortedAliases`, where `sortedAliases` (lines 1580-1585) returns a cached `bookMappings.keys.sorted()` built at line 1582. The cache is new in `adaea2e` and does not weaken the property — the order is computed once from the same sorted call and invalidated by `addMapping`. The locale question is answered explicitly in the doc comment at lines 1571-1577: `sorted()` on `[String]` is Swift's ordinal Unicode comparison, not `localizedStandardCompare`, so the order does not vary by machine.
- **ISC-75** — static. `ScriptureDetectorService.swift:1629-1634`: `let books = Set(candidates.map(\.canonical)); guard books.count == 1 else { … return nil }`. Cross-book ties return nil, with the rejected book list logged.
- **ISC-76** — static. `ScriptureDetectorService.swift:1569`: `private static let minimumFuzzyAliasLength = 3`, enforced at line 1599 by `guard alias.count >= Self.minimumFuzzyAliasLength`.
- **ISC-77** — static, reinforced by unit. The guard at `ScriptureDetectorService.swift:1599` `continue`s past every alias shorter than three characters before any distance is computed, so "am" cannot appear as a matched alias for any input. `BookMishearingTests.testShortAliasesAreExactMatchOnly` (`BookMishearingTests.swift:159`) asserts that no candidate for "amo", "hos", "aim" or "hoe" has an alias under three characters.
- **ISC-78** — static. `ScriptureDetectorService.swift:1549-1558`: when `books.count > 1`, candidates are filtered by `chapterHint <= maxChapter` through `chapterCountProvider`, and the function falls through to `return .rejected(.ambiguous(books:))` at line 1562 when the filter does not leave exactly one book.
- **ISC-79** — static. `DetectionPipeline.swift:69-71`: `detector.bookNormaliser.chapterCountProvider = { [weak self] bookName in self?.bible.maxChapter(forBookNamed: bookName) }`. Behaviourally confirmed by `DetectionPipelineWiringTests.testChapterCountProviderIsWiredAndCorrect` (`DetectionPipelineTests.swift:46`), which unwraps the shipped closure and asserts Psalms 150, Amos 9, Judges 21 and Jude 1 — closing the gap the previous pass noted, that the detector-level tests leave this closure nil.
- **ISC-80** — unit. `BookMishearingTests.testSamIsNeverAmos` (`:38`) asserts `normalise("sam", chapterHint: 91)` and `normalise("sams", chapterHint: 91)` are not Amos; `testPsalmsMishearingsResolveToPsalms` (`:28`) asserts "sam" resolves to "Psalms". The mechanism is the exact-alias return at `ScriptureDetectorService.swift:1512-1513` against the alias declared at line 1351, which precedes all chapter filtering — confirmed independently by `testChapterHintNeverOverridesAnExactAlias` (`:237`), where an impossible chapter 91 leaves "amos" resolving to Amos.
- **ISC-81** — unit. `BookMishearingTests.testChapterHintSettlesJohannineEpistles` (`:197`) injects a provider giving 1 John 5 chapters and 2–3 John one each, then asserts `XCTAssertNil(normaliser.normalise("a john", chapterHint: 1))`. The rejection path is `ScriptureDetectorService.swift:1549-1562`, which falls through to `.rejected(.ambiguous(books:))` when the chapter filter does not leave exactly one book. Re-read against `adaea2e`: the wording still matches the shipped code, and the only change is that the nil now arrives via a `MatchOutcome` carrying the candidate list rather than a bare nil, which is what feeds the operator-facing rejection row.
- **ISC-83** — static. `ScriptureDetectorService.swift:1240-1259`: `cacheContext(for:)` begins `if let validate = referenceValidator, !validate(reference) { … return }` at lines 1241-1251, before calling `referenceBuffer.updateContext` at line 1253. The early return now also publishes an operator-facing rejection (lines 1243-1249) before returning, which does not touch the buffer.
- **ISC-84** — static, reinforced by unit. `DetectionPipeline.swift:64-67`: `detector.referenceValidator = { … return self.bible.referenceExists(reference) }`. The symbol is `referenceExists(_:)`, declared at `BibleService.swift:653`; earlier drafts of this criterion named `referenceIsPlausible(_:)`, which never shipped. `DetectionPipelineWiringTests.testReferenceValidatorIsWiredAndCorrect` (`DetectionPipelineTests.swift:35`) unwraps the shipped closure and asserts it accepts Psalms 91:8-12 and Judges 5:1 and refuses Amos 91.
- **ISC-85** — unit. `BookMishearingTests.testImplausibleReferenceIsNotCachedAsContext` (`:308`) clears the buffer, feeds "Amos 91 verse 1" through the detector and asserts `ReferenceBuffer.shared.currentContext` is nil. Honest limit: the test injects a stub validator rejecting Amos above chapter 9 rather than using `BibleService.referenceExists`, so it proves the gate, not the wiring; the wiring is covered separately by ISC-84.
- **ISC-87** — unit. `BookMishearingTests.testEverydayWordsNeverBecomeBooks` (`:175`) asserts nil for "am", "is", "to", "so", "the" and "and". The criterion's stated example is asserted end to end by `NumberedBookDetectionTests.testIAmFortyDoesNotDetect1Samuel` (`:101`). Source gate at `ScriptureDetectorService.swift:1491` and `:1499`, against the set declared at line 1286.
- **ISC-88** — static, reinforced by unit. `ScriptureDetectorService.swift:1507-1509`: `if lowercased.count <= 2 && bookMappings[lowercased] == nil { return .rejected(.tooShort) }`, before any fuzzy path. Stricter than the criterion requires, since it consults only `bookMappings`; the two-character cases are exercised by `testEverydayWordsNeverBecomeBooks`.
- **ISC-89** — static, reinforced by unit. The length gate at `ScriptureDetectorService.swift:1507` admits a two-character input present in `bookMappings`, and the direct lookup at lines 1512-1513 returns it; "ps" is mapped to Psalms at line 1338. `testShortAliasesAreExactMatchOnly` (`:159`) asserts the equivalent case, `normalise("ho") == "Hosea"`.
- **ISC-90** — static, reinforced by unit. `ScriptureDetectorService.swift:1643-1650` returns true when the trimmed input is present in `bookMappings`, `BibleVocabularyData.sttMishearings` or `BibleVocabularyData.abbreviations`. `testIsExactAliasDistinguishesGuessesFromCertainties` (`:246`) asserts true for "psalms" and "sam", false for "aim" and "a john".
- **ISC-93** — static, reinforced by unit. `DetectionPipeline.swift:332-335`: `guard !ref.verseWasSpoken, ref.verseEnd == nil else { Logger.pipeline.info("Not splitting …"); return nil }`. `ConcatenatedReferenceRepairTests.testSplitIsRefusedWhenASingleVerseWasSpoken` (`DetectionPipelineTests.swift:123`) asserts both directions of the flag on otherwise identical references — `Amos 91` with `verseWasSpoken: true` returns nil, with `false` returns non-nil — which is the pair that could not be written while the guard tested `verseStart`.
- **ISC-93.1** — static, reinforced by unit. `BibleService.swift:97` declares `let verseWasSpoken: Bool`, defaulted to `false` at line 99 so no existing call site changes meaning, and the hand-written `==` at lines 124-129 compares only book, chapter, `verseStart` and `verseEnd`, with the reason stated at lines 120-123. `DetectionPipeline.swift:348` sets it true on the repaired candidate, asserted by `testRepairedReferenceIsMarkedAsHavingASpokenVerse` (`:149`); the guard at line 332 then makes a second split impossible. The parse sites that set it true are `ScriptureDetectorService.swift:537`, `:546`, `:591`, `:909`, `:1004` and `:1156`, each carrying a comment naming the utterance shape that justifies it.
- **ISC-94** — static, reinforced by unit. The guard at `DetectionPipeline.swift:332-335` returns nil for any reference carrying a `verseEnd`, unconditionally, so "Amos 91:8-12" cannot be rewritten. `ConcatenatedReferenceRepairTests.testSplitIsRefusedWhenARangeWasSpoken` (`DetectionPipelineTests.swift:112`) now asserts the literal case directly, which closes the honest limit recorded here by the previous pass — it had only the Psalms path via `BookMishearingTests.testMisheardPsalmsKeepsTheWholeVerseRange` (`:278`), which remains as the end-to-end demonstration.
- **ISC-95** — unit. `testSplitRecoversConcatenatedChapterAndVerse` (`DetectionPipelineTests.swift:99`) feeds `James 123` with no spoken verse through the real pipeline, against the real database, and asserts James 1:23 with a nil `verseEnd`. Honest limit: the criterion names "John123" and the test uses James 123. The split is book-agnostic — the book is copied unchanged at `DetectionPipeline.swift:344` — so the mechanism is proven, but the literal input in the criterion is not asserted.
- **ISC-96** — static. `DetectionPipeline.swift:350`: `if !bible.getVerses(from: candidate).isEmpty { return candidate }`. No other return path in the loop, so a candidate that does not resolve to real verses cannot be accepted.
- **ISC-97** — static, reinforced by unit. The loop at `DetectionPipeline.swift:339-353` falls through to `return nil` at line 354. `testSplitReturnsNilWhenNoCandidateResolves` (`:137`) uses chapter 999, which splits every way into chapter-verse pairs no book has, and asserts nil.
- **ISC-98** — static, reinforced by unit. `DetectionPipeline.swift:338`: `guard chapterStr.count >= 2 else { return nil }`. `testSplitIsRefusedForASingleDigitChapter` (`:143`) asserts nil for Amos 9.
- **ISC-99** — static. `DetectionPipeline.swift:333`: `Logger.pipeline.info("Not splitting \(ref.formatted) — the verse was spoken explicitly")`. The interpolation is `ref.formatted`, so the log line names the reference rather than merely recording that something was refused.
- **ISC-100** — static, reinforced by unit. `DetectionPipeline.swift:343-349` constructs the candidate with `book: ref.book`; no branch substitutes another book. `testSplitRecoversConcatenatedChapterAndVerse` (`:103`) asserts the repaired book is still James.
- **ISC-103** — data. `sqlite3 Bible.db "SELECT b.name, MAX(v.chapter) FROM verses v JOIN books b ON b.id=v.book_id WHERE b.name IN ('Psalms','Amos') GROUP BY b.name;"` returned `Amos|9` and `Psalms|150`.
- **ISC-104** — unit. `BibleServiceLookupTests.testValidReferencesAreAcceptedAndImpossibleOnesRefused` (`:110`) asserts `referenceExists(Amos 91:1)` is false, against the real loaded database. Source: `BibleService.swift:656` bounds the chapter by `bookChapterCounts[bookId]`.
- **ISC-105** — unit. The same test asserts `referenceExists(Psalms 91:8-12)` is true, and separately that Judges 5:1 is accepted — the case that was failing when Jude's single chapter was consulted for Judges.
- **ISC-106** — static. `BibleService.swift:658`: `if let end = reference.verseEnd, end < reference.verseStart { return false }`. No test drives an inverted range; the guard is one line and unconditional.
- **ISC-107** — static. `BibleService.swift:657`: `guard reference.verseStart >= 1 else { return false }`.
- **ISC-129** — unit. `ConfidencePenaltyTests.testConfidenceGridIsPinned` (`:61`) asserts, for all ten patterns, that the distance-0 score exceeds the distance-1 score — `standard` 0.967 against 0.939, `chapterOnly` 0.780 against 0.752, and so on down the table. An exact alias is scored at distance 0 by construction in `parseMatch`.
- **ISC-130** — unit. The same grid asserts distance 2 below distance 1 for every pattern, each step costing 0.028 overall.
- **ISC-130.1** — unit. `ConfidencePenaltyTests.testPenaltyAndGateRemainCompatible` (`:137`) reads `ScriptureDetectorService.bookGuessPenaltyPerEdit` and `minimumConfidence` directly and asserts `0.4 × penalty < 0.780 − minimumConfidence`, printing both sides in the failure message. At the shipped values that is 0.028 < 0.030. Reinforced by `testDistanceOneSurvivesForEveryGatedPattern` (`:91`), which asserts every gated pattern clears `minimumConfidence` at one edit, and by `testClarityFloorIsNotReachedAtTheShippedPenalty` (`:157`), which shows the 0.4 clarity floor is inert at two edits and therefore not silently doing the work.
- **ISC-199.1** — unit. `BibleServiceLookupTests.testPrefixCollidingBooksResolveDistinctly` (`:52`) asserts distinct ids for all twelve prefix-colliding pairs in the canon — Judges/Jude, Philippians/Philemon, the three Johannine boundaries, and the numbered Timothy, Kings, Samuel, Chronicles, Corinthians, Thessalonians and Peter pairs — rather than only the pair that was noticed; `testJudgesAndJudeAreDistinct` (`:42`) keeps the reported case explicit; `testLookupsAreStableAcrossRepeatedCalls` (`:82`) repeats eight probes 50 times each. Source: `BibleService.swift:673-696`, exact match at 677, sorted longest-match fallback at 686-693, with the locale-independence of `sorted()` stated at lines 681-683. `testChapterCountsFollowTheCorrectBook` (`:101`) pins the consequence that made this critical — Judges 21 and Jude 1 rather than one truncating the other.
- **ISC-118** — data. `sqlite3 Bible.db "SELECT translation_id, COUNT(*) FROM verses GROUP BY translation_id;"` returned ASV 31086, BSB 31086, KJV 31102, LSV 31104, WEB 31095.
- **ISC-151** — unit. `DivineViewController.swift:34` sets `isShowingVerse` from a whitespace-trimmed emptiness check; asserted by `DivineViewTests.testBlankTextDoesNotShowVerse`.
- **ISC-153** — unit. `DivineViewController.swift:50`: `guard let current = verse.currentVerse else { return }`; asserted by `DivineViewTests.testPresentOneWithNoVersesLeavesCurrentVerseOnScreen`.
- **ISC-155** — unit. `DivineViewController.swift:59-64` clears all four fields; asserted by `DivineViewTests.testClearEmptiesDivineView` and, through the panic path, by `testPanicClearsDivineView`.
- **ISC-157** — unit. `DivineViewSettings.swift:42-44` writes `divineView.background` on set; asserted by `DivineViewTests.testBackgroundSettingPersists`.
- **ISC-159** — unit. `DivineViewSettings.swift:47-49` and `59-63`: `divineView.openOnPush` persists on set and defaults to true when the key is absent; the false path is asserted by `DivineViewTests.testOpenOnPushDisabledDoesNotRequestWindow`.
- **ISC-198** — static, reinforced by unit. `ScriptureDetectorService.swift:1629-1634`: `fuzzyMatch` builds the candidate book set and returns nil, with a log line, whenever it holds more than one book; the `first` bound at line 1627 is only returned after that guard has established a single book. `BookMishearingTests.testTiedCandidatesAcrossBooksAreRejected` (`:147`) asserts both `fuzzyMatch("aim")` and `normalise("aim")` are nil.
- **ISC-200** — static, reinforced by unit. The guard at `DetectionPipeline.swift:332-335` refuses the rewrite whenever `verseEnd` is set, so the only rewrite path in the detection stack cannot discard a spoken range. `testSplitIsRefusedWhenARangeWasSpoken` (`DetectionPipelineTests.swift:112`) asserts the guard directly on the incident reference; `testMisheardPsalmsKeepsTheWholeVerseRange` (`BookMishearingTests.swift:278`) asserts the range reaches the operator intact end to end, and `testSpokenPsalmsRangeParsesCleanly` (`:293`) asserts the same for the unambiguous utterance.
- **ISC-201** — static, reinforced by unit. `ScriptureDetectorService.swift:1241-1251` returns before writing when `referenceValidator` rejects the reference, and line 1253 is the sole `updateContext` call site in the codebase (ISC-70), so no write can bypass the gate. Behaviourally asserted by `testImplausibleReferenceIsNotCachedAsContext` (`:308`), with the same stub-validator limit noted under ISC-85, and by `testSuccessfulRepairLeavesUsableContext` (`DetectionPipelineTests.swift:158`) from the other side — a *plausible* repaired reference does reach the buffer.
- **ISC-202** — static, reinforced by unit. `ScriptureDetectorService.swift:1569` declares the floor and line 1599 enforces it inside the only candidate-generating loop, so no alias under three characters is reachable as a fuzzy target. `testShortAliasesAreExactMatchOnly` (`:159`) asserts this over four probes chosen to sit near the two-letter aliases.

Explicitly unverified and worth naming, because several of these look settled and are not:

- **ISC-60** — the incident utterance itself, "the book of Psalms chapter 9, verse 8 to 12", still has no assertion. `DetectionPipelineWiringTests.testReportedIncidentThroughProductionWiring` (`DetectionPipelineTests.swift:59`) is close and is a real improvement — it drives "Sam 91 verse 8 to 12" through the shipped pipeline with the real database rather than a stub, and asserts Psalms 91:8-12 with no Amos anywhere in the results — but the utterance it runs is the concatenated reading, which is what the chapter hint rescues. The spoken chapter 9 is the case the hint provably does not settle, so the criterion that names the original failure stays open.
- **ISC-74** — `testFuzzyMatchingIsDeterministic` (`:124`) repeats each probe within a single process, and `BibleServiceLookupTests.testLookupsAreStableAcrossRepeatedCalls` (`:82`) does the same for the lookup. The defect was per-process dictionary seeding, which is invariant inside one launch, so neither test can fail for the reason ISC-74 exists. The criterion specifies 100 cold launches and needs a shell harness over a test binary that does not exist. This is the single most load-bearing gap in the determinism work: every determinism criterion is currently discharged by reading a `sorted()` call rather than by observing repeated launches.
- **ISC-91** — `suggestCorrection` delegates to `fuzzyMatch` and so inherits its rejection of cross-book ties, but the criterion as drafted also admits inputs that resolve by exact alias, where no ambiguity check runs. It needs rewording before it can be honestly probed, and is left pending rather than reworded to fit the code.
- **ISC-130.2** — `ConfidencePenaltyTests` reproduces the scoring formula in its own `overall(_:editDistance:)` helper (`:42-52`) and drives `DetectionConfidence` directly, rather than calling `parseMatch` and reading the confidence off a real `DetectionResult`. It reads the two shipped constants, so a change to either fails the grid, but the ten base triples at lines 27-38 are a hand-copy of the switch in `parseMatch`. If a base weight moves, the grid will agree with itself and disagree with the app. Worth naming because the test file is otherwise the strongest artefact in the commit.
- **ISC-199** — split rather than closed; see ISC-199.2 below and the Decisions entry.
- **ISC-199.2** — `ImplicitReferenceDetector.detect(in:)` (`ImplicitReferenceDetector.swift:24-47`) iterates `famousVerses`, a `[String: String]` declared at `BibleVocabularyData.swift:369`, sorts by confidence at line 46, and `bestMatch(in:)` (`:56-58`) returns `.first` of that. `calculateConfidence` (`:62-70`) gives `min(min(Float(phrase.count) / 30.0, 0.8) + 0.2, 1.0)`, and the boundary bonus at line 67 repeats the `contains` test that already gated entry at line 33, so it is unconditional and every phrase of 24 characters or more scores exactly 1.0 — 14 of the 15 phrases long enough to pass `minimumPhraseWords` (`:12`, five words). `sorted(by:)` is not a stable sort in Swift, so a transcript containing two such phrases resolves by dictionary seed. Not fixed in `adaea2e`; recorded in Decisions with the tie-break question that has to be answered first.
- **ISC-203** — asserts a property of what reaches the screen, not of the normaliser. The confidence penalty is now 0.07 rather than the 0.15 recorded here previously, but the substance is unchanged: a penalty lowers a fuzzy match's score without suppressing it, and no test drives the display layer.
- **ISC-217 and the operator rejection row** — `ScriptureDetectorService` now publishes a `DetectionRejection` (declared at `:13`) on `lastRejection` (`:104`) and `rejectionPublisher` (`:114`), auto-clearing after six seconds via the cancellable task at `:1265-1276`, and `MainView` renders it. The plumbing was read and the auto-clear logic is sound, but **the row has never been observed rendered**. Neither the six-second clear, the non-interactivity, nor the absence of focus theft has been seen in a running app; all three are conclusions from reading the view, and focus theft in particular was a real defect earlier in this feature's development, so reading is a weak probe for it.
- **ISC-190 to ISC-197** — no measurement harness, unchanged. Two performance changes shipped in `adaea2e` that specifically bear on ISC-197's budget of under 15% CPU in a silent room: `sortedAliases` caches the sorted key list rather than rebuilding it on every call, and `fuzzyCandidates` pre-filters by length difference before allocating a Levenshtein matrix (`ScriptureDetectorService.swift:1605`). Both are plainly directionally right and **neither was benchmarked**, before or after. The criterion is no closer to verified than it was; it merely has more untested work behind it.

Beyond those: every audio-capture criterion (ISC-9 to ISC-19) still has no test file, and the wider detection parse surface (ISC-37 to ISC-72) remains covered only by the numbered-book ordinals in `NumberedBookDetectionTests.swift`, the regressions in `BookMishearingTests.swift`, and the two wiring assertions in `DetectionPipelineTests.swift`.
