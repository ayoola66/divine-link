# Divine Link — iPad (Personal) App Ideas

> Captured 2026-07-22. A parking doc to revisit and reconsider. Not a commitment — thinking.

## Why iPad is easy (vs Windows)
Same Apple ecosystem: SwiftUI, `SFSpeechRecognizer`, **WhisperKit (runs on iPad Neural Engine)**, AVFoundation, Supabase, Bible.db, detection engine — all come across. It's a **moderate port (weeks), not a rewrite.** Windows would be a ground-up rebuild (no SwiftUI, no WhisperKit; would need whisper.cpp + new UI + WASAPI audio).

## The make-or-break: AUDIO INPUT
iOS **cannot** capture system audio / loopback (BlackHole) / arbitrary input devices — **mic only**, or a USB-C audio interface plugged into the iPad. On Mac we pipe the sound-desk/mixer feed in; on iPad it's room-mic (lower quality) OR a USB-C interface off the desk. **Decide this before building** — it determines whether iPad quality matches Mac.

## Decision made: DROP ProPresenter for iPad
Personal use case, no ProPresenter (too complicated, and keyboard-automation is impossible on iOS anyway).

## The value-prop worry ("why not just use Google/ChatGPT?")
Google/ChatGPT are **pull** (you notice → stop → type → read, and you've missed the next sentence). Divine Link is **push**: passive, hands-free, real-time — the verse is already on screen.
**Reframe for personal use:** it's NOT "look up a verse" (a Bible app half-does that). The real product is the **automatic verse trail** → at the end of the service you have a complete, timestamped, tappable, **shareable record of every scripture the preacher referenced**, without writing anything down. Reframe from "AV-desk operator tool" → **"personal study companion that builds your sermon notes as you listen."** That's the thing Google/ChatGPT structurally can't be.

## DROP for the personal iPad build
- All ProPresenter (client, settings, outputs: stage display / audience WebSocket / audience keyboard, hybrid integration, push coordinator)
- Keyboard automation + Panic button (F12/⌘-Esc) — impossible on iOS anyway
- Per-pastor profiles + per-speaker speech corrections (multi-speaker operator feature)
- Transcript word-click → pencil → edit-DB correction flow (operator precision)
- Elaborate audio device manager / mic selector → collapse to a simple "Listen" toggle
- Ads + the whole ad system (feels wrong in a personal devotional app; App Store makes it awkward) → monetise as clean paid/freemium App Store app instead
- Sparkle, device tracking, 7-day offline lockout, Stripe web checkout → replaced by App Store + IAP

## KEEP — this IS the app now
- Real-time transcription (WhisperKit on-device + Apple Speech fallback)
- Scripture detection engine + Bible.db + version switcher
- Live detected-verse feed
- **Session history → reframed as first-class "Sermon Notes"** (reviewable, annotatable, exportable/shareable as PDF/text/Notes) — make this a destination, not a buried archive

## UI/UX rethink for iPad + personal
- Calm, glanceable: big readable verse, minimal chrome, one obvious "Listen" control
- Two moments, two screens: *during* = live feed scrolling as verses land; *after* = sermon-notes summary to read/annotate/share
- Personal touches: tap verse → full passage + context; add highlight / one-line note; favourite
- Orientation: landscape on a stand, portrait held; keep-screen-awake while listening
- Be honest in-UI that it's hearing the room; use a USB-C interface if attached

## App Store / monetisation implications
- Distribution = App Store / TestFlight (simpler than notarise+Sparkle)
- **Digital subscriptions must use Apple IAP** (~30%, or 15% small-business program) — materially changes the monetisation maths vs the Mac Stripe model
- Lean toward premium **features** (audio, cross-refs, extra translations you're licensed for, offline packs) rather than paywalling copyrighted Bible text you'd need rights to (see Bible-versions note)

## The honest gut-check before building
Decide: **"my personal tool"** (weekend-scoped joy project, build lean) vs **"a product for congregants"** (validate with a couple of real users FIRST — test the reaction to the *sermon-notes* hook specifically, and the room-audio quality — before investing weeks).

## Related open thread
Bible translations: want ~10 versions (3 free + 7 premium). Copyright reality + which are legally includable — see separate notes / conversation 2026-07-22. Short version: KJV/ASV/WEB/**BSB**/LSV/YLT/Darby/WEBBE/BBE/DRA are public-domain/free-license (can bundle now); NIV/NLT/NKJV/ESV/NASB/CSB/MSG are copyrighted (need licensing, and can't simply be paywalled by us).
