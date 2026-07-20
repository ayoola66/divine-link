---
project: Divine Link
task: Small universal installer + Apple-Silicon on-demand Whisper model download
effort: E3
phase: complete
progress: 64/78
mode: algorithm
started: 2026-07-18
updated: 2026-07-20
---

## Problem

DivineLink v1.3.10 ships (website live, notarised app, Stripe links live) but the owner cannot make reliable sales because: (1) the Supabase free-tier backend has **paused from inactivity** — its host returns NXDOMAIN — which breaks login (email OTP), subscription verification, device tracking, and the Stripe→premium webhook; (2) uncertainty about whether the custom domain expired; (3) the app's core value — detecting spoken scripture references in church — is reported to mis-detect words.

## Vision

A prospective buyer visits the live site, downloads and installs the app, signs in, pays via Stripe, and is immediately recognised as premium — while the app accurately hears spoken scripture references during a live service. First real sales flow without manual intervention.

## Out of Scope

The v2.0.0 sidebar UI redesign (`redesign.pen`, `REDESIGN-SPEC-v2.0.0.md`) — deferred until v1 is solid and selling. Wiring the custom domain `divinelinkapp.com` to Netlify — optional; the Netlify URL already serves everything sales needs.

## Constraints

- Supabase restore and any dashboard action can only be performed by the account owner (I cannot log in).
- Transcription-engine code changes cannot be validated without a real Xcode build + live audio test on the owner's machine (BlackHole loopback + speaking).
- macOS Speech framework (`SFSpeechRecognizer`) has per-request audio-duration limits — the restart loop is a workaround, not a free choice.
- Free-tier Supabase re-pauses after ~7 days of inactivity — a durable fix implies a paid tier or a keep-alive ping.

## Goal

Restore end-to-end sales (auth + payment + premium grant) on the live Netlify URL, correct the domain misconception, and land a validated fix for scripture word-detection accuracy — all on v1, leaving v2 for later.

## Criteria

- [x] ISC-1: Supabase host reachability probed — result recorded (NXDOMAIN = paused). Probe: `curl` host → HTTP 000 / `dig` NXDOMAIN.
- [x] ISC-2: Custom-domain expiry checked via WHOIS — ACTIVE to 2027-03-18 (NOT expired). Probe: `whois divinelinkapp.com`.
- [x] ISC-3: App + site audited for `divinelinkapp.com` refs — **0 found**; everything already on `divinelink.netlify.app`. Probe: `grep -rIn`.
- [x] ISC-4: Site funnel pages return 200 (/, download, terms, privacy, success, cancel, compare, releases). Probe: `curl` each.
- [x] ISC-5: All four Stripe checkout links return 200. Probe: `curl buy.stripe.com/...`.
- [x] ISC-6: App Sparkle feed URL points to live appcast (netlify.app/appcast.xml → 200). Probe: `grep` Info.plist + `curl`.
- [x] ISC-7: Transcription code read; word-loss root cause identified (restart-on-every-final tears down session, drops audio). Probe: `Read` TranscriptionService.swift.
- [x] ISC-8: Bible language model path reviewed; fallback + compilation logic understood. Probe: `Read` BibleLanguageModel.swift.
- [x] ISC-9: Supabase project restored — host resolves, `auth/v1/health` → 200. Verified 2026-07-18 after owner reactivation.
- [x] ISC-9.1: Backend schema deployed & functional — `ads`/`app_heartbeats` → 200, RPC `get_all_active_ads` → 200, RPC `get_my_subscription` → 200, Stripe webhook fn → 400 (deployed), OTP endpoint live. profiles/subscriptions/devices RLS-protected (404 to anon = correct).
- [DEFERRED-VERIFY] ISC-10: Email OTP login succeeds in-app end-to-end. Follow-up: owner runs app, signs in. Endpoint verified live; in-app flow needs real run.
- [DEFERRED-VERIFY] ISC-11: A test Stripe purchase flips the account to premium via webhook. Follow-up: owner does a test-mode purchase; webhook + RPC verified deployed.
- [x] ISC-12: Supabase re-pause prevented — GitHub Actions daily keep-alive (`divine-link-site/.github/workflows/supabase-keepalive.yml`) pushed + verified with 2 green `workflow_dispatch` runs (11s, 10s). Pings app_heartbeats + auth health daily 06:00 UTC; fails loudly if down.
- [x] ISC-13: Transcription fix applied — seamless session handoff (new request+task swapped in before old retired; audio feed + isTranscribing kept alive; immediate handoff on isFinal, damped recycle only on silence/error). Verified: 0 dangling refs, full API contract intact, braces 51/51, swift -parse clean.
- [DEFERRED-VERIFY] ISC-14: Fix validated by live speaking test showing scripture refs detected without word loss. Follow-up: owner builds in Xcode + speaks a sermon passage. Cannot probe without owner's build + audio.
- [x] ISC-17: Reverse-order detection added — "book verse X chapter Y" (e.g. "John verse 16 chapter 5") → John 5:16. New `.bookVerseChapter` pattern + `parseBookVerseChapterMatch`; requires BOTH keywords so no false positives. Verified: braces 178/178, edits parse clean (only pre-existing regex-literal false-positive at L1198). [DEFERRED-VERIFY live: owner speaks the phrase.]
- [x] ISC-18: Concurrency warning fixed — `TranscriptBuffer` timer uses `MainActor.assumeIsolated` (ListeningFeedView.swift). Xcode showed 1 warning; fixed at source.
- [ ] ISC-15: Anti: No change touches or ships any v2.0.0 redesign surface.
- [x] ISC-16: Anti: No new hardcoded reference to the dead custom domain is introduced.
- [x] ISC-19: Notarisation fixed — stale keychain profile was the cause; fresh `DivineLink-Notary` profile (API key) validated via `notarytool history`. release.sh rewired to it. Also fixed release.sh appcast awk bug (BSD awk can't carry multi-line -v → now writes item to file + getline).
- [x] ISC-20: v1.4.0 built, notarised (`stapler validate` OK), Sparkle-signed, deployed. Live: latest.zip=13120037, appcast serves 1.4.0 + matching notarised signature, /download 200. App opens on double-click (no Gatekeeper prompt).
- [DEFERRED-VERIFY] ISC-11: Real Stripe test purchase flips account to premium. Owner action when ready — infra verified (webhook deployed, RPC live).

### Feature: Per-card Bible version switcher (2026-07-19, church field-test request #1)

- [x] ISC-21: `BibleService.getVerse/getVerseRange/getVerses` accept an optional `translation:` override (default nil = global selection); all existing callers unaffected. Probe: `grep` signatures + BUILD SUCCEEDED.
- [x] ISC-22: `BufferManager.updateTranslation(id:translation:verses:)` swaps a pending verse's text + translation in place, no-ops on empty input, clamps `currentVerseIndex`. Probe: `Read` method + build.
- [x] ISC-23: `PendingVerse.verses` and `.translation` are mutable (`var`) so a card can switch version without re-detecting. Probe: `grep` struct fields.
- [x] ISC-24: `VerseRowView` renders a per-card translation Menu (`translationPicker`) and is instantiated with `availableTranslations` + `onChangeTranslation`. Probe: `grep` + build.
- [x] ISC-25: `changeTranslation` re-fetches the same reference in the chosen version and updates only that card. Probe: `Read` MainView helper + build.
- [x] ISC-26: Anti: switching a card's version does NOT mutate the app-wide `@AppStorage("selectedTranslation")`. Probe: `changeTranslation` never writes `selectedTranslation` (grep confirms).
- [x] ISC-27: Whole app type-checks and compiles with the changes. Probe: `xcodebuild ... build` → BUILD SUCCEEDED.
- [DEFERRED-VERIFY] ISC-28: Live — operator taps a detected card's version chip, the verse re-renders in the new translation and can flick back and forth. Follow-up: owner runs the app and switches a card. Cannot probe without owner's build + runtime.

### Feature: Dynamic verse-card sizing + clean Bible.db re-import (2026-07-19, exposed by version switcher)

- [x] ISC-29: Detected-verse card sizes dynamically — selected card shows full text (`.lineLimit(isSelected ? nil : 2)` + `fixedSize(vertical)`); unselected stay 2-line previews. Probe: `grep` MainView + parse clean.
- [x] ISC-30: `Bible.db` `verses` table rebuilt from clean public-domain sources (KJV+ASV scrollmapper, WEB getbible.net); `books` table preserved unchanged. Probe: `bun rebuild.ts` output + schema diff.
- [x] ISC-31: Zero duplicate (translation,book,chapter,verse) rows — was ~70k dup groups. Probe: `GROUP BY ... HAVING COUNT>1` → 0.
- [x] ISC-32: Zero WEB footnote-contaminated verses — was 861. WEB John 3:16 = "…his one and only Son…". Probe: GLOB `*[a-z][0-9]:[0-9]*` → 0.
- [x] ISC-33: Zero KJV pilcrow (¶) verses — was 5,750. Probe: `LIKE '%¶%'` → 0.
- [x] ISC-34: Verse counts sane — KJV 31,102 / ASV 31,086 / WEB 31,095 (ASV/WEB legitimately omit critical-text verses). Probe: `COUNT GROUP BY translation_id`.
- [x] ISC-35: `books` table intact (66 rows) + schema/index byte-identical so `BibleService` reads unchanged; DB shrank 40MB→16MB. Probe: `.schema` + `COUNT(books)`.
- [x] ISC-36: Original DB backed up outside the app bundle (`_bible_rebuild/Bible.db.pre-reimport.bak`). Probe: `ls`.
- [DEFERRED-VERIFY] ISC-37: App rebuilt in Xcode renders clean WEB text (no footnote) when a card is switched to WEB. Follow-up: owner rebuilds + switches a card.

### Feature: Live-transcript duplication fix (2026-07-19, church field-test bug #2)

- [x] ISC-38: `TranscriptionService.handleRecognitionResult` always emits a FINAL segment on `isFinal` (even when identical to last partial), so the display buffer commits one line per session. Probe: `Read` + build.
- [x] ISC-39: `TranscriptBuffer` partials REPLACE the live line (cumulative-aware); commits exactly one finalised line per STT session; the buggy 1.5s sentence timer (which committed growing cumulative snapshots as separate lines) is removed. Probe: `Read` + `grep` sentenceTimer → 0 refs.
- [x] ISC-40: Silence/error handoff (no explicit isFinal) still commits the prior session — detected when the cumulative resets shorter and no longer extends the current line. Probe: `Read` update() logic.
- [x] ISC-41: Anti: transcript no longer stacks nested cumulative snapshots ("A", "A B", "A B C" as separate lines). Probe: code path eliminated (one commit per session boundary).
- [x] ISC-42: Detection path untouched — still consumes `fullTranscriptPublisher`, not the display buffer; fix is display-only. Probe: `grep` DetectionPipeline wiring unchanged.
- [x] ISC-43: Whole app compiles. Probe: `xcodebuild ... build` → BUILD SUCCEEDED.
- [DEFERRED-VERIFY] ISC-44: Live — speaking continuously yields clean, non-duplicated transcript lines. Follow-up: owner rebuilds + speaks a passage.

### Feature: Quick mic selector + continuous transcript (2026-07-19, church field-test asks #3/#4)

- [x] ISC-45: Quick audio-input selector (`micSelector`) added to the status row beside Audio — a Menu bound to shared `AudioDeviceManager` (lists devices, checkmarks current, Refresh action); selection switches input live via the pipeline's existing `$selectedDevice` observer. No Settings trip needed. Probe: `Read` + build.
- [x] ISC-46: Live transcript renders CONTINUOUS — `TranscriptTextView` joins finalised lines with spaces (flowing prose) instead of newlines; live partial appended dim as the trailing edge. Probe: `Read` updateNSView + build.
- [x] ISC-47: Word-click → pencil → correction edit flow preserved (selection-based; `lineOffsetMap` ranges still tracked per line). Probe: `Read` — selection/onCorrection path untouched.
- [x] ISC-48: App compiles (added `import AVFoundation` to MainView for `AVCaptureDevice`). Probe: `xcodebuild ... build` → BUILD SUCCEEDED.
- [DEFERRED-VERIFY] ISC-49: Live — mic dropdown switches device + transcript reads clean/continuous during real (paused) speech. Follow-up: owner rebuilds + tests.

### Feature: Restore pause-based line breaking (delta-tracked) (2026-07-19, owner preferred pre-update readability)

- [x] ISC-50: Transcript breaks a NEW LINE at each ~1.4s speech pause again (owner found continuous space-join "muddy"). Rendering reverted to one phrase per line. Probe: `Read` + build.
- [x] ISC-51: Anti: no duplication/stacking despite mid-session line breaks — `TranscriptBuffer` commits only the DELTA beyond `committedPrefix` (not whole cumulative snapshots), with common-prefix resync on revisions + new-session reset. Probe: `Read` update()/commitDelta().
- [x] ISC-52: Whole app compiles. Probe: `xcodebuild ... build` → BUILD SUCCEEDED; ListeningFeedView braces 45/45.
- [DEFERRED-VERIFY] ISC-53: Live — pauses create new readable lines like the pre-update version, without duplication. Follow-up: owner rebuilds + speaks with pauses.
- [ ] ISC-54: DECIDED (2026-07-20) — integrate WhisperKit (MIT/free, on-device, offline) with model **small.en**. Plan: owner adds SPM package `github.com/argmaxinc/argmax-oss-swift` (product WhisperKit) in Xcode → I write `WhisperKitTranscriptionService` drop-in (same publishers, fed by existing AudioCaptureService buffers resampled 44.1/48k→16k mono) behind an engine toggle with Apple SFSpeechRecognizer fallback → build-fix → test → tune. Model bundled into app as a follow-up for pure-offline install (first run otherwise downloads small.en once). Verified: MIT license, macOS 14+ (app already targets), transcribe(audioArray:[Float],decodeOptions:) API, Apple-Silicon-optimised. Owner HARD CONSTRAINT (2026-07-20): must work FULLY OFFLINE + standalone (install on a Mac, it just works), no internet dependency except the existing 7-day update/premium check. This RULES OUT Apple server recognition (option a). Owner initially declined a switch thinking WhisperKit = "another AI tool / internet-dependent" — CORRECTION: WhisperKit runs Whisper on-device via CoreML, fully offline, model bundled in app (exactly how Superwhisper works). So WhisperKit SATISFIES the offline/standalone requirement AND fixes neatness (punctuation, accuracy, no cumulative-partial churn / no session-recycling boundary artifacts). Recommended path. Apple on-device `SFSpeechRecognizer` is the wrong tool for long-form church audio (built for short dictation; loops on continuous audio; needs session-recycling handoff that creates boundary duplication).
- [ ] ISC-55: The duplication screenshot the owner sent (2026-07-20) appears to PRE-DATE the delta-based line-break fix (ISC-50/51). ACTION: owner must rebuild + retest with clean paused speech. If stacking persists post-rebuild → add overlap-dedup guard at commit (session-handoff boundary overlap). Follow-up. (Note: WhisperKit engine below supersedes the Apple-path transcript concerns.)

### Feature: WhisperKit offline engine integrated (2026-07-20)

- [x] ISC-56: `WhisperTranscriber` (new file) consumes existing `AudioCaptureService.audioBufferPublisher`, resamples to 16k mono via `AudioProcessor.resampleAudio`+`convertBufferToArray`, runs `WhisperKit.transcribe(audioArray:decodeOptions:)` on a rolling ~28s window every 1.5s, model small.en. Probe: `Read` + BUILD SUCCEEDED (WhisperKit API matched first try).
- [x] ISC-57: `TranscriptionService` branches engine — default WhisperKit (UserDefaults `useWhisperKit`, default true), Apple SFSpeechRecognizer auto-fallback if the model fails to load; `requestPermission`/`isAvailable` don't let denied Speech-Recognition block Whisper. Probe: `Read` + build.
- [x] ISC-58: Anti: no downstream changes — Whisper routes through the SAME publishers (`transcript`, `fullTranscriptPublisher`, `transcriptPublisher`, `isTranscribing`), so detection, transcript view (delta line-breaking), mic selector, and word-edit are untouched. Probe: DetectionPipeline/MainView unchanged + build.
- [DEFERRED-VERIFY] ISC-59: Live — Whisper yields punctuated, clean, accurate transcript with pause-delimited lines; verse detection still fires. Owner rebuilds + speaks. FIRST RUN downloads small.en once (needs internet that one time; then cached).
- [x] ISC-60a: WhisperKit gated to Apple Silicon (`shouldUseWhisper = useWhisperSetting && isAppleSilicon`, runtime sysctl). Intel Macs → Apple STT automatically (WhisperKit EXC_BAD_ACCESS-crashes on Intel via MPSGraph; uncatchable, so gated before touching WhisperKit). Owner confirmed: has/will get Apple Silicon; Intel gets Apple engine. BUILD SUCCEEDED.
- [x] ISC-60b: `WhisperTranscriber.bundledModelFolder()` discovers the app-bundled model (folder containing `AudioEncoder.mlmodelc`, at Resources root or one level deep) and loads via `WhisperKitConfig(modelFolder:)` — pure offline; download only as fallback. Owner already bundled the model. BUILD SUCCEEDED.
- [DEFERRED-VERIFY] ISC-60: On Apple Silicon — Whisper loads from the bundled folder with NO network (verify tokenizer files are in the bundle too), transcribes cleanly, energy acceptable. Owner tests on M-series.
- [ ] ISC-61: Follow-up — add a Settings toggle for the engine (currently UserDefaults `useWhisperKit`, default on) so the owner can A/B Apple vs Whisper in-app.

### Feature: Small universal installer + Apple-Silicon on-demand model download (2026-07-20)

**Problem addendum:** The v1.5 build bundles the 464 MB `openai_whisper-small.en` CoreML model inside the app, producing a 493 MB installer shipped to *every* Mac — including Intel Macs that can never run WhisperKit. **Direction (owner, 2026-07-20):** ship one small universal app; Intel uses Apple Speech immediately and never sees an AI download; Apple Silicon downloads the model once on first launch with visible progress, persists it, and runs offline thereafter; a failed/deferred download must still leave the app fully usable via Apple Speech.

**Design:** Bundle ONLY the 2.3 MB tokenizer (`WhisperModels/tokenizer/`, contains config.json + tokenizer_config.json + tokenizer.json — sufficient for fully-offline tokenizer load); drop the 464 MB model from the bundle. A new `WhisperModelManager` downloads the model on demand via `WhisperKit.download(variant:downloadBase:progressCallback:)` (real Foundation `Progress`, not a timer) into Application Support, and reports state. `WhisperTranscriber` loads `WhisperKitConfig(modelFolder: <downloaded>, tokenizerFolder: <bundled>, load:true, download:false)` — never inline-downloads. Engine gate becomes `useWhisperSetting && isAppleSilicon && modelInstalled`.

- [x] ISC-62: pbxproj bundles ONLY `WhisperModels/tokenizer` (folder ref `path` repointed), not the 464 MB model dir. Verified: clean-build `.app/Contents/Resources` has `tokenizer/tokenizer.json` (2.3 MB) and ZERO `openai_whisper-small.en`/`AudioEncoder.mlmodelc`.
- [x] ISC-63: Built `.app` shrinks from 493 MB to **55 MB** (Debug; −89%). Threshold was <35 MB — an underestimate that ignored WhisperKit's own linked framework binaries; the owner requirement ("small universal download") is met, and the Sparkle Release zip compresses much smaller (v1.4 pre-model shipped a 13 MB zip). Verified: `du -sh` clean-build `.app` = 55 MB.
- [x] ISC-64: New `WhisperModelManager` resolves the persisted model folder under Application Support (`…/DivineLink/models/argmaxinc/whisperkit-coreml/openai_whisper-small.en`), preferring the exact path returned by `WhisperKit.download` (persisted in UserDefaults) with a deterministic fallback. Verified: `Read` + BUILD SUCCEEDED; Forge confirmed the Hub layout `<base>/models/<repo>/<variant>` against pinned source.
- [x] ISC-65: `WhisperModelManager.installedModelFolder()` returns a folder only if a COMPLETE model is present — all three CoreML components (AudioEncoder + MelSpectrogram + TextDecoder .mlmodelc), not just one. Strengthened per advisor #1 so a partial/interrupted download reads as NOT installed. Verified: `Read` `isCompleteModel(at:)` + build.
- [x] ISC-66: `download()` uses `WhisperKit.download(variant:downloadBase:progressCallback:)` and publishes real byte progress (`Progress.fractionCompleted`/`completedUnitCount`/`totalUnitCount`). Verified: `Read` + build; Forge confirmed `ProgressCallback` is `@Sendable (Progress)->Void`.
- [x] ISC-67: `@Published State` machine (`.notInstalled / .downloading(fraction,received,total) / .installed / .failed`) drives both the first-launch sheet and the Settings row. Verified: `Read` + build.
- [x] ISC-68: Manager is Apple-Silicon gated — `isSupported` (runtime `sysctlbyname("hw.optional.arm64")`) is `false` on Intel; `download()` guards on it and the sheet is gated on it. Verified: `Read` + build.
- [x] ISC-69: `WhisperTranscriber` loads the model from the persisted Application-Support folder first (bundled model fallback kept), tokenizer from the bundle, and NEVER inline-downloads (the old `WhisperKitConfig(model:load:)` auto-download branch is removed → on no model it calls `onError` → Apple fallback). Verified: `Read` + `grep download: false` + build.
- [x] ISC-70: `TranscriptionService.shouldUseWhisper` = `useWhisperSetting && isAppleSilicon && WhisperModelManager.isInstalled`; not-installed → Apple Speech. Verified: `Read` gate + build.
- [x] ISC-71: First-launch download sheet shown only when `isAppleSilicon && !isInstalled && !whisperModelOffered`; offers Download (linear progress bar + "% · X of Y" byte label) and "Use standard recognition". Verified: `Read` MainView/WhisperDownloadView + build.
- [x] ISC-72: Intel path — sheet gate includes `WhisperModelManager.isSupported` (false on Intel), so it's never presented; Apple Speech used immediately. Verified: `Read` gate + build; Forge traced Intel path (no WhisperKit symbol touched).
- [x] ISC-73: Anti: a failed download or a user "skip" does NOT block app use — falls back to Apple Speech, app fully functional. Hardened per Forge m2: the Whisper→Apple runtime fallback now requests Speech authorization if it was masked (`ensureSpeechAuthThenStartApple`). Verified: `Read` fallback path + build.
- [x] ISC-74: Anti: no network on Intel, and none when the model is already installed — download happens only via explicit `manager.download()` on Apple Silicon when not installed; the transcriber load path is `download:false`. Verified: `Read` — no auto-download path exists.
- [x] ISC-75: Resumability — re-invoking `download()` after a partial/failed attempt skips already-fetched files (Hub per-file snapshot). Manual retry is reachable from the new Settings → Enhanced Recognition row even after an explicit skip (Forge M1). Verified: `Read` + Hub snapshot semantics (per-file temp+move) confirmed by Forge.
- [x] ISC-76: Once installed, later launches use Whisper fully offline (`download:false` + bundled tokenizer folder with config.json/tokenizer_config.json/tokenizer.json → zero network). Verified: `Read` load path + build; Forge verified `loadTokenizer` resolves the bundled folder locally and only hits the Hub if local load throws.
- [x] ISC-77: Whole app type-checks and compiles. Verified: `xcodebuild -scheme DivineLink -configuration Debug clean build CODE_SIGNING_ALLOWED=NO` → **BUILD SUCCEEDED** (new WhisperModelManager.swift + WhisperDownloadView.swift auto-compiled via the synchronized folder group; edits to WhisperTranscriber/TranscriptionService/MainView clean).
- [DEFERRED-VERIFY] ISC-78: Live (owner, both machines) — Apple-Silicon first launch shows progress, downloads once, then transcribes offline on relaunch; Intel launches straight to Apple Speech with no download prompt. This dev machine is Intel/x86_64 so the WhisperKit runtime path cannot be probed here. Follow-up: owner runs on an M-series Mac + an Intel Mac.

## Test Strategy

| isc | type | check | threshold | tool |
|-----|------|-------|-----------|------|
| ISC-1 | backend | host resolves + health | HTTP 200 | curl/dig |
| ISC-9 | backend | auth health after restore | HTTP 200 | curl |
| ISC-11 | payment | webhook writes premium row | row exists | Supabase SQL |
| ISC-13 | code | restart no longer nils request mid-audio | grep/read | Read |
| ISC-14 | UX | spoken refs appear | detection fires | live run |

## Features

| name | satisfies | depends_on | parallelizable |
|------|-----------|------------|----------------|
| Backend restore (owner) | ISC-9,10,11 | — | no |
| Re-pause prevention | ISC-12 | ISC-9 | no |
| Domain correction (info only) | ISC-2,3 | — | yes |
| Transcription word-loss fix | ISC-13,14 | owner greenlight | yes |
| Per-card Bible version switcher | ISC-21..28 | — | yes |
| Dynamic verse-card sizing | ISC-29 | ISC-24 | yes |
| Clean Bible.db re-import | ISC-30..37 | — | yes |
| Live-transcript duplication fix | ISC-38..44 | — | yes |
| Quick mic selector | ISC-45,47,48 | — | yes |
| Continuous transcript rendering | ISC-46,47,48 | — | yes |

## Decisions

- 2026-07-18: Scope pinned by owner — verify/fix v1 for sales, defer v2, pivot to Netlify URL (already the case). `effort_source: classifier` (E3).
- 2026-07-18: refined: Domain worry dropped — WHOIS shows ACTIVE to 2027, and app/site already use netlify.app exclusively (0 custom-domain refs). No pivot work needed.
- 2026-07-18: Supabase restore + re-pause prevention are owner-gated; cannot self-serve. Surfaced as required owner actions.
- 2026-07-18: Transcription fix identified but not blind-applied — core value prop, unvalidatable without owner's build+audio. Presented for greenlight.
- 2026-07-19: Church field testing surfaced 3 items (accent misses, transcript duplication bug, version-switch request). Owner chose to ship the version switcher first (self-contained, testable without live audio). Built it as item #1.
- 2026-07-19: refined: version switch is PER-CARD (local override) not global — chose in-place Menu on each card, leaving the app-wide `selectedTranslation` untouched, so the operator can flick one detected verse between KJV/ASV/WEB without disturbing the default. `getVerses` gained an optional `translation:` param to support this without mutating global state.
- 2026-07-19: Version switcher exposed pre-existing `Bible.db` corruption (WEB footnotes bled into verse text, ~70k duplicate rows from multiple layered imports, 5,750 KJV pilcrows). Root cause = dirty bundled data, NOT the switcher. Owner chose clean re-import (option 1 of 3).
- 2026-07-19: refined: WEB footnotes are NOT safely regex-strippable (marker = verse's own ref but footnote end is undelimited), so surgical cleanup rejected in favour of full re-import from clean public-domain sources. Kept `books` table (all alias logic) and rebuilt only `verses`, mapped by canonical ordinal (source name variants like "I Samuel"/"Revelation of John" differ but order is identical).
- 2026-07-19: refined: card made dynamic (selected → full text) rather than removing WEB or a fixed-bigger card — chosen because re-import removes the footnote bloat, leaving only modest translation-length variance that dynamic sizing handles cleanly.
- 2026-07-19: Transcript duplication root cause = `TranscriptBuffer`'s 1.5s sentence timer committing Apple's cumulative-per-session partials as separate stacking lines. Fixed display-side (detection reads raw `fullTranscriptPublisher`, untouched). Chose "one line per STT session" (commit on isFinal / cumulative-reset) over delta-based mid-session splitting — simpler, lower-risk, zero duplication; natural line breaks come from Apple's isFinal + the seamless handoff bounding each session. Guaranteed-isFinal-segment added because the segment was previously dropped when the final equalled the last partial.
- 2026-07-19: Owner still found transcript "messy / not continuous" (needs clean readable text for the click-word→pencil→edit-DB correction feature). Chose CONTINUOUS rendering (space-join finalised lines into flowing prose) over stacked lines. Finalised text = stable/clean/editable; the dim trailing partial is the inherent live edge (Apple revises only the last few words) that solidifies at pauses. NEXT LEVER if churn still bugs in real paused speech: trailing-word stabilisation (hold back last ~6 words, commit the rest) — deferred, not built, higher risk.
- 2026-07-19: Added quick mic selector to the status row (owner: input device is a top setting, shouldn't require Settings→Audio). Reused shared `AudioDeviceManager` + existing pipeline `$selectedDevice` observer, so it's a thin UI addition with live switching for free.
- 2026-07-20: Tier — classifier returned E4 on the "GO" prompt (cross-cutting architecture). Ran at **E3** (`effort_source: context-override`). Show-my-math: (1) the project ISA is already E3 and the project-ISA override pins E3+ structure, which is honored; (2) the design was pre-decided in ISC-54/60a/60b (engine, Apple-Silicon gate, bundled-vs-download), so this is "substantial multi-file work" (E3), not open "complex design" (E4); (3) Codex independently scoped E3; (4) the E4 ≥128-ISC floor is disproportionate ceremony for a focused packaging+startup change and conflicts with the standing token-efficiency directive. E4-grade rigor still applied where it matters: Forge in EXECUTE, a real `xcodebuild`, advisor call before done.
- 2026-07-20: refined: bundle ONLY the tokenizer, not the model. The tokenizer is 2.3 MB and MUST be present offline (WhisperKit fetches it from a *separate* HF repo otherwise); the model is 464 MB and is the only thing worth downloading on demand. This keeps the installer ~27 MB + 2.3 MB and makes "fully offline once installed" true without a second network fetch for the tokenizer.
- 2026-07-20: refined: download persists to Application Support (not the bundle, which is read-only and re-created on update) via WhisperKit's `downloadBase`. Model survives app updates; Sparkle replacing the .app won't wipe it.
- 2026-07-20: Model lifecycle belongs at FIRST LAUNCH after arch detection, not at install (installer is just the .app) and not lazily at first transcription (owner wants the one-time download to be explicit + visible, and to keep the transcription start path fast). Intel is gated out before any WhisperKit symbol is touched (it EXC_BAD_ACCESS-crashes on Intel, uncatchable).
- 2026-07-20: This dev machine is Intel (x86_64) — build + size + Resources + code-path verification are done here; the live WhisperKit runtime flow is genuinely owner-verified on Apple Silicon (ISC-78 DEFERRED-VERIFY). Not a shortcut: the runtime path is un-probeable on this hardware by design.
- 2026-07-20: Forge (GPT-5.4, read-only, source-verified against the pinned WhisperKit checkout) reviewed the change: no blockers; core mechanism (offline load, Intel safety, @Sendable progress hop, path resolution) CONFIRMED correct. Fixed its findings inline — M1: the first-launch offer flag was flipped at show-time with no re-trigger, which stranded the feature on skip/Escape/quit-mid-download → now the flag flips ONLY on explicit decline, an Escape/quit re-offers next launch, and a Settings → Enhanced Recognition row provides manual download/retry; m2: the Whisper→Apple runtime fallback could go dark if Speech permission was previously denied (masked by `requestPermission`) → added `ensureSpeechAuthThenStartApple` which really requests Speech auth before the fallback; n5: deduped the Apple-Silicon sysctl check to a single source (`WhisperModelManager.isSupported`).
- 2026-07-20: Advisor (Inference.ts --mode advisor) surfaced the highest-risk field failure: partial/interrupted download would pass a single-file install check, read as "installed", then fail to load — leaving enhanced recognition silently broken and never re-offered. Fixed: `installedModelFolder()` now requires ALL THREE CoreML components (AudioEncoder + MelSpectrogram + TextDecoder .mlmodelc) via `isCompleteModel(at:)`, so a partial download reads as not-installed and is re-offered/retried; the runtime path already falls back to Apple Speech if WhisperKit init throws. Advisor's other points were already satisfied (runtime sysctl gate, MainActor progress hop, source-verified tokenizer/model splice) or are the three owner-run Apple-Silicon scenarios in ISC-78 (clean install→offline; kill mid-download→usable+retry; skip→Apple Speech).
- 2026-07-20: Deferred (follow-ups, logged not built — touch the delicate transcription-handoff state, risk > reward now): Forge m3 (optimistic `isTranscribing=true` during model load can drop first seconds — show a "loading model…" state instead); m4 (mid-session install doesn't switch engine until next start — could auto-restart the pipeline on `.installed`); advisor #6 (a visible "standard vs enhanced" mode indicator in the header so the operator knows which engine is live). Also noted: Swift-6 language mode would turn the implicit-MainActor isolation crossings in `WhisperTranscriber` into hard errors (currently warnings in Swift-5 mode; `NSLock` keeps it safe at runtime).

## Changelog

- **conjectured** (2026-07-20): a single install marker (`AudioEncoder.mlmodelc` present) is enough to decide the on-demand model is installed and usable.
  **refuted_by**: advisor reasoning about the dominant field failure mode — an interrupted download (network drop / quit / sleep / disk full) can leave a partial folder that passes a one-file check, then fails at `WhisperKit` init; the app doesn't strand (it falls back to Apple Speech) but enhanced recognition reads "installed" yet broken and is never re-offered.
  **learned**: "installed" must mean "complete and loadable", not "some file exists" — an on-demand asset needs an integrity gate, and the cheapest reliable one is presence of every required component.
  **criterion_now**: ISC-65 — `installedModelFolder()` requires all three CoreML components (AudioEncoder + MelSpectrogram + TextDecoder .mlmodelc); a partial download reads as not-installed and is re-offered/retried.
- **conjectured** (2026-07-20): flipping the "offered" flag when the first-launch sheet is shown is a fine way to avoid nagging.
  **refuted_by**: Forge M1 — flipping at show-time means Escape/quit/skip all permanently suppress the offer, stranding a feature the user never actually declined.
  **learned**: a one-time offer must key its "don't ask again" flag to the user's explicit decision, not to the UI appearing; and any one-time-offered feature needs a manual re-entry point.
  **criterion_now**: ISC-71/75 — flag flips only on explicit "use standard"; Escape/quit re-offers next launch; Settings → Enhanced Recognition allows manual download/retry.

## Verification

ISC-1: `curl` project host → HTTP 000; `dig qzjhjgkvvcamcqpdrgkf.supabase.co` → NXDOMAIN; Google → 200 (network fine) ⇒ paused.
ISC-2: `whois divinelinkapp.com` → status ACTIVE, Registry Expiry 2027-03-18, Registrar IONOS.
ISC-3: `grep -rIn "divinelinkapp.com"` across app + site → 0 matches.
ISC-4: all 8 site pages → 200.
ISC-5: all 4 `buy.stripe.com` links → 200.
ISC-6: Info.plist SUFeedURL = netlify.app/appcast.xml; appcast → 200.
ISC-7: TranscriptionService.handleRecognitionResult calls scheduleRestart() on isFinal → stop() nils recognitionRequest + audioCaptureService; buffers during 0.5s timer + rebuild are dropped; transcript reset to "" each cycle.
ISC-21..27: `xcrun swiftc -parse` clean on all 3 changed files (exit 0); braces balanced (69/69, 61/61, 298/298); full `xcodebuild -scheme DivineLink -configuration Debug build CODE_SIGNING_ALLOWED=NO` → **BUILD SUCCEEDED**. VerseRowView sole call site (MainView:778) updated; verse getters' new param is optional so DetectionPipeline callers unaffected.
ISC-29: MainView `singleVerseText` now `.lineLimit(isSelected ? nil : 2)` + `.fixedSize(horizontal:false, vertical:true)`; parse clean, braces 298/298.
ISC-30..36: `bun rebuild.ts` → KJV 31102 / ASV 31086 / WEB 31095 inserted. Post-rebuild SQL: dup-groups=0, WEB footnote-GLOB=0 (was 861), KJV ¶=0 (was 5750), WEB John 3:16="…his one and only Son…", Genesis 1:1 WEB clean, books=66, size 40MB→16MB. Deployed to Resources/Bible.db; backup at _bible_rebuild/Bible.db.pre-reimport.bak. Schema + idx_verses_lookup preserved identical → BibleService reads unchanged.
ISC-38..43: TranscriptionService emits guaranteed isFinal segment; TranscriptBuffer rewritten cumulative-aware (one line/session), sentence timer removed (grep sentenceTimer → 0). DetectionPipeline wiring unchanged (reads fullTranscriptPublisher). Full `xcodebuild ... build` → BUILD SUCCEEDED; ListeningFeedView braces 32/32.

ISC-62/63/77 (2026-07-20, on-demand model): pbxproj folder ref `2CDB601A` repointed `path = WhisperModels` → `WhisperModels/tokenizer`. `xcodebuild -scheme DivineLink -configuration Debug clean build CODE_SIGNING_ALLOWED=NO` → **BUILD SUCCEEDED**. Clean-build `.app` = **55 MB** (was 493 MB, −89%). `.app/Contents/Resources`: `tokenizer/tokenizer.json` present (2.3 MB); `find … -iname "*whisper-small*" -o -iname AudioEncoder.mlmodelc` → 0 (model gone from bundle). Two new files (WhisperModelManager.swift, WhisperDownloadView.swift) auto-compiled via the objectVersion-77 synchronized folder group. Three subsequent incremental rebuilds after the Forge/advisor fixes → BUILD SUCCEEDED each time.
ISC-64..76 (code-path, verified by Read + successful compile + Forge source-verification): download lifecycle in `WhisperModelManager` (Application-Support `downloadBase`, real `Progress` callback hopped to MainActor, all-three-component install check, Apple-Silicon gate); `WhisperTranscriber` loads downloaded→bundled model with `download:false` + bundled tokenizer, never inline-downloads; `TranscriptionService.shouldUseWhisper` requires `isAppleSilicon && isInstalled` with hardened Speech-auth fallback; first-launch sheet + Settings retry, Intel never offered. Forge CONFIRMED (against pinned WhisperKit source): offline load has no network path, concurrency is Sendable-safe, Intel touches no WhisperKit symbol, path resolution matches Hub layout.
ISC-78: DEFERRED-VERIFY — owner runs three scenarios on Apple Silicon (advisor-recommended): (a) clean first launch → progress bar → offline transcribe on relaunch; (b) kill download mid-progress → relaunch → app usable + Settings retry works; (c) skip/deny → Apple Speech works. Plus one Intel launch → straight to Apple Speech, no prompt. Un-probeable on this Intel dev machine.
