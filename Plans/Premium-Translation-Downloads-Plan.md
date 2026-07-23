# Divine Link — Premium Translation Downloads (design, pre-implementation)

> Captured 2026-07-23. A plan to agree BEFORE building. Answers "is this possible?" (yes) and
> breaks the logic down step by step.

## What the owner asked for
- Ship a **light app: only 5 versions bundled** — 3 free (KJV, WEB, ASV) + 2 premium-locked (BSB, LSV).
- The **other 5** (WEBBE, YLT, Darby, DRA, BBE) are **download-only**, fetched over the internet
  **after premium is confirmed**, silently/in the background.
- A **Settings → Bible Versions** screen showing each version's state (like the YouVersion Bible app):
  downloading %, green ✓ when installed, delete button for premium users.
- **Anti-sharing:** rely on periodic online re-validation of premium.
- **Future-proof:** DB/catalog designed so a new licensed version (e.g. NLT) can be added later and
  premium users just download it — **no app update required**.

## Direct answers to the questions
1. **Periodic premium re-validation already exists — it's 7 days.** `DynamicAdService.maxOfflineDays = 7`;
   the app "requires an internet connection at least once every 7 days to verify your licence,"
   after which `connectivityStatus = .offlineExpired` and the app locks. This is the anti-sharing gate.
   (Configurable — we can keep 7 or change it.)
2. **Premium status** comes from `SubscriptionService.fetchSubscription()` → Supabase RPC
   `get_my_subscription` (tiers: mercy=free, grace/love=premium). `isPremium` is already computed and
   observes auth. So "detect premium → act" is a hook we already have.
3. **You cannot be premium without internet** — correct; login + subscription check are online. So
   downloading extra versions on premium confirmation is safe by construction.

## The one hard constraint that shapes the whole design
`BibleService` opens the bundled `Bible.db` **READ-ONLY** (`SQLITE_OPEN_READONLY`). We therefore
**cannot INSERT downloaded verses into the bundled DB.** Downloaded versions must live in separate
files in Application Support. This is actually clean and matches the "download / delete per version"
model — and mirrors exactly what `WhisperModelManager` already does for the speech model.

## Recommended architecture (3 layers)
**A. Catalog (what versions exist) — server-driven.**
- A Supabase `bible_versions` table: `id, name, year, tier(free/premium), is_bundled, download_url,
  file_size, sha256, sort_order, requires_attribution, attribution_text, min_app_version`.
- App fetches this catalog when online (cache locally, like ads). Bundled `translations` table stays
  as the offline seed for the 5 shipped versions.
- **This is what makes NLT-later work with no app update:** add a row + host the file → it appears.

**B. Verse data — bundled + downloaded.**
- Bundled `Bible.db` (read-only): the 5 shipped versions (KJV/WEB/ASV/BSB/LSV) + books + metadata.
- Each downloadable version = its **own small SQLite file** (`WEBBE.sqlite`, ~2 MB) hosted on the
  Netlify site (same place as the app zips) or Supabase Storage. On download it lands in
  `Application Support/DivineLink/bibles/`. `BibleService` **ATTACHes** installed version files and
  routes each verse lookup to the right DB handle. Delete = remove the file.
- Why separate files (not one big writable DB): trivial per-version download/delete, green-check state
  derived from file presence, corruption is isolated, future versions just drop in.

**C. Installed state — derived from disk (no writable metadata DB needed).**
- A version is "installed" iff its file exists in Application Support (same logic as
  `WhisperModelManager.isInstalled`). State machine per version:
  `bundled | notInstalled | downloading(fraction) | installed | failed`.

## New component: `BibleVersionManager` (mirrors `WhisperModelManager`)
- `@Published versions: [VersionState]` — merges catalog + bundled + on-disk installed state.
- `download(id)` / `delete(id)` / `refreshCatalog()`; real byte-progress via URLSession download task.
- On premium confirmation (SubscriptionService.isPremium becomes true, authed, online): auto-enqueue
  background downloads of all premium versions not yet installed. Silent, low priority, resumable.
- Feeds `BibleService` the set of attachable version files.

## Premium gating (currently NOT wired — this adds it)
- Free tier: sees only `tier=free` versions (KJV/WEB/ASV).
- Premium tier: BSB/LSV unlock (already bundled — just ungated) + the 5 downloadable become available.
- Gate = `SubscriptionService.isPremium`. If premium lapses: re-lock premium versions in the picker
  (keep the files; don't delete — re-unlock instantly on renewal). Within the 7-day offline window
  everything keeps working; past it the existing lockout applies.

## Settings → Bible Versions screen (YouVersion-style)
- List every catalog version grouped Free / Premium.
- Per row: name + state — `Bundled ✓`, `Installed ✓` (+ Delete), `Downloading 42%`, `Download` button
  (premium only), or `Premium 🔒` (upsell if free).
- Reuses the `WhisperDownloadView` progress UX we already built.

## BUILD PROGRESS (Option A chosen 2026-07-23)
- ✅ **Data + hosting DONE.** Generated the 5 downloadable premium versions as standalone,
  ATTACH-compatible SQLite files via `_bible_rebuild/phase2_build_version_files.ts` (helloao source,
  **USFM-code book mapping** so canons align — DRA's 7 deuterocanonical books correctly dropped;
  each 66 books, 0 dups, 0 contamination): WEBBE 31,098 · YLT 31,102 · DBY 31,099 · DRA 31,438 ·
  BBE 31,102. Hosted on Netlify `/bibles/*.sqlite` (~5 MB each, immutable cache) + `/bibles/catalog.json`
  manifest (id, tier, verse_count, file_size, sha256, download_url). `.sqlite` header rule added to
  netlify.toml. NOT bundled — initial app stays 5 versions.
- ⏭ **Remaining (Swift app layer):** catalog read/merge → `BibleVersionManager` (download/delete/
  progress, ATTACH routing in BibleService) → premium gating in picker → auto-download on premium →
  Settings→Bible Versions screen → Attribution screen.

## Phased implementation (when approved)
1. **DB/catalog model:** create Supabase `bible_versions` table + seed rows for all 10; add the
   read RPC; app fetches + caches catalog. (Bundled `translations` stays the offline seed.)
2. **Generate + host the 5 downloadable version files** (`phase2_build_version_files.ts` — reuse the
   helloao importer to emit per-version SQLite files; upload to Netlify `/bibles/`). Keep them OUT of
   the app bundle.
3. **`BibleVersionManager`** + `BibleService` ATTACH/routing for installed version files.
4. **Premium gating** in the picker (free vs premium vs locked).
5. **Auto-download on premium confirm** (background, silent, resumable).
6. **Settings → Bible Versions** screen (download/progress/✓/delete).
7. Attribution screen (BSB/LSV/NET etc. credits) — required before public ship.
8. Verify: free user sees 3; premium user auto-gets 10; delete works; offline within 7 days works;
   lapse re-locks; a newly-added catalog row (simulated NLT) appears + downloads with no app update.

## Open decision for the owner (need this before building)
**BSB + LSV are currently BUNDLED (Phase 1) — keep them bundled-but-premium-locked (owner's stated
plan: "5 bundled, 3 free + 2 locked"), OR move them to download-only too (even lighter app, 3 bundled)?**
Recommendation: keep them bundled + locked (matches your description; app is only ~26 MB; and it means
a brand-new premium user has 2 versions instantly while the other 5 download).

## Hosting note
Downloadable version files go on the existing Netlify site (`/bibles/*.sqlite`) — same pattern as the
app zips, free CDN, already wired to deploy. Each ~2 MB; 5 files ≈ ~10 MB total, downloaded only by
premium users. Keeps the initial app at 5 bundled versions.
