# Divine Link — Multi-Translation Build Plan (target: 10 versions)

> Captured 2026-07-22. A plan to review before building. Goal: 3 free + 7 premium translations,
> legally, without breaking the app's offline-first ethos. Revisit and adjust.

## Guiding rules (non-negotiable)
1. **Only public-domain / freely-licensed text may be bundled or self-distributed.** Copyrighted
   text (NIV/NLT/NKJV/ESV/NASB/CSB/MSG) needs a licence — and usually can't be self-paywalled.
2. **Free-to-users ≠ free-to-reproduce.** Copyright governs reproduction, not price.
3. Respect per-version **attribution** requirements (BSB, NET, etc.).
4. Keep the base app small — premium/extra versions can be **on-demand download packs**
   (reuse the WhisperKit on-demand model pattern), not bundled bloat.

## Target line-up (all legal to ship without a licence)
Free (3): **KJV**, **WEB** (modern-ish), **ASV** — already in the app.
Premium (7, public domain / free-licence): **BSB** (Berean — modern, NIV-like readability),
**LSV** (Literal Standard, modern), **WEBBE** (British WEB), **YLT** (Young's Literal),
**Darby**, **DRA** (Douay-Rheims, Catholic), **BBE** (Basic English).
→ 10 total, 0 licensing cost, 0 legal risk. BSB is the free "NIV substitute".
Deferred (licensed, needs $ + contract, Phase 3 only): NIV, NLT, NKJV, ESV.

## Current state (what we're extending)
- `DivineLink/Resources/Bible.db` (SQLite): `verses` (translation_id, book, chapter, verse, text)
  + `books` (66 rows, alias logic). Clean-rebuilt for KJV/ASV/WEB (~31k verses each, 16 MB).
- `BibleService.getVerse/getVerseRange/getVerses(translation:)` — already takes a translation override.
- Per-card switcher built (`VerseRowView.translationPicker`, `MainView.changeTranslation`),
  global default `@AppStorage("selectedTranslation")`, hardcoded `availableTranslations = ["KJV","ASV","WEB"]`.
- Rebuild pipeline: `_bible_rebuild/rebuild.ts` (bun:sqlite) — imports + normalises + verifies.

## Phase 0 — Data model (do first)
Add a **`translations` metadata table** (stop hardcoding the list):
`id (abbrev PK), name, language, year, is_public_domain (bool), is_premium (bool),
requires_attribution (bool), attribution_text, source_url, verse_count, installed (bool)`.
- App reads available versions from this table (filtered by free/premium + installed), not a hardcoded array.
- `verses.translation_id` FKs to `translations.id`.
- Lets premium/downloadable packs register themselves without code changes.

## Phase 1 — Add modern PD versions to the bundle (BSB, LSV)
Biggest readability win, zero cost.
1. Extend `_bible_rebuild/rebuild.ts` to pull **BSB** + **LSV** from clean sources
   (berean.bible / getbible.net v2 / wldeh JSON), mapped by canonical book ordinal (reuse existing mapping).
2. **Normalise** (we hit this before): strip footnote markers, pilcrows (¶), bracket artefacts;
   verify no contamination (the WEB-footnote bug — GLOB check).
3. Import into `verses`; register rows in `translations`. Keep `books` untouched.
4. **Verify**: per-translation `COUNT` sane (~31k), 0 dup (translation,book,chapter,verse),
   0 footnote/pilcrow, spot-check John 3:16 + Gen 1:1 + Ps 23 per version.
5. App: `availableTranslations` → dynamic from `translations` table; switcher UI scales (scrollable menu).

## Phase 2 — Premium PD pack (WEBBE, YLT, Darby, DRA, BBE)
Same pipeline. Decision: **bundle vs download pack.**
- 10 translations ≈ ~45–55 MB in Bible.db. Bundling is simplest (still small).
- OR keep free 3 bundled + premium 7 as an **on-demand download pack** (reuse WhisperKit-style
  `download → Application Support → register installed=true`), keeping the base app lean and giving
  premium a tangible "unlock". Recommended if going App Store (smaller initial download).
- Gate premium versions behind the existing premium check (`SubscriptionService`/`AdManager`).

## Phase 3 — Licensed modern versions (NIV/NLT/NKJV/ESV) — LATER, only if revenue justifies
- Path A: **API.Bible** (scripture.api.bible, ABS) — per-publisher approval, online fetch (breaks
  pure-offline for those versions; cache what's licensed to cache).
- Path B: direct publisher licence (Biblica/Tyndale/Thomas Nelson) — cost + contract + usage rules
  (often no-charge or revenue-share; can't simply paywall).
- ESV API + NET Bible API are the friendlier stepping stones (NET is modern + permission-friendly).
- Do NOT attempt to bundle these; treat as a business/legal workstream, not a code task.

## App-side changes (all phases)
- Dynamic version list from `translations` (free vs premium vs installed).
- Version switcher UI that scales to 10 (grouped: Free / Premium; lock icon on premium if not subscribed).
- Default-translation picker in Settings.
- Attribution screen (Settings → About → Bible Versions) listing required credits (BSB, NET, etc.).
- If download packs: a "Manage Bible Versions" screen (download/remove), mirroring the enhanced-recognition download UX.

## Verification checklist (per version, before ship)
- [ ] Verse count within expected range; no missing/extra books
- [ ] 0 duplicate (translation,book,chapter,verse)
- [ ] 0 footnote/pilcrow/bracket contamination (GLOB + LIKE checks)
- [ ] John 3:16, Genesis 1:1, Psalm 23:1 render clean
- [ ] Reads correctly via `BibleService.getVerses(translation:)`
- [ ] Per-card switcher flips live; global default respected
- [ ] Attribution present where required
- [ ] App build succeeds; DB size acceptable

## Data sources (bookmark)
- PD databases: `scrollmapper/bible_databases`, `getbible.net` v2, `wldeh/bible-api` (GitHub),
  `berinaniesh/bible-databases`, berean.bible (BSB), `openscriptures` (LSV).
- Licensed APIs: `scripture.api.bible` (API.Bible), `api.esv.org` (ESV), NET Bible API (labs.bible.org).

## Recommended sequence
Phase 0 (model) → Phase 1 (BSB + LSV, the big readability win, free/legal) → ship + gauge reaction →
Phase 2 (premium PD pack, decide bundle vs download) → Phase 3 (licensed, only if the numbers justify).
Net: reach a strong **10-version app with zero licensing spend**; NIV/NLT/NKJV become a paid upgrade
to pursue later, not a blocker now.
