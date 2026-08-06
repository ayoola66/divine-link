# Design: Real-Time Bible Quote → Verse Matching (Love Tier)

**Date:** 2026-08-06  
**Status:** Approved approach — **roadmapped / not building now**  
**Tracked in:** `Divine-Link-Context.md` §10 · `PROJECT_STATUS.md` · `docs/FEATURE-MATRIX.md`  
**Version target:** Future Love release (can land before or with v2 UI redesign)  
**Approach:** Uniqueness-aware n-gram index + FTS5 verify (Approach 1)  
**Tier:** Love only  

---

## 1. Problem

Divine Link already detects spoken *references* (e.g. “John chapter three verse sixteen”) via `ScriptureDetectorService`. For *unannounced quotes*, it only matches a hard-coded dictionary of ~17 famous phrases in `BibleVocabularyData.famousVerses` via exact substring in `ImplicitReferenceDetector`.

Pastors routinely quote scripture without citing book/chapter — including obscure verses. Those quotes are invisible to the app today. Story 7.2 envisioned corpus + MLX matching as a Love feature; only the famous-phrase stub shipped.

## 2. Goals

1. While listening, if the transcript contains an ordered span of words that uniquely (or near-uniquely) identifies a verse in the installed Bible corpus, surface that verse on a pending verse card with a confidence percentage.
2. Never auto-push quote matches to ProPresenter — operator always clicks to push.
3. Ship as a **Love-only** capability so it remains a clear Pro differentiator on the website and in-app.
4. Remain fully local (no cloud LLM / remote Bible API for matching).
5. Reuse existing confidence UI (green / yellow / orange) with a **90%** high-confidence mark for quote matches.

## 3. Non-Goals (Phase 1)

- Heavy paraphrase matching (“the Lord looks after me like a shepherd”) — Phase 2 embeddings / MLX
- Anaphora (“the verse we just read”) — Phase 3 / remaining Story 7.2
- Rewriting explicit reference detection
- Auto-push to Audience / Stage from quote path
- Expanding Grace or Mercy with this feature

## 4. Product Rules (locked)

| Rule | Value |
|------|--------|
| Default action | Show on verse card as suggestion |
| ProPresenter | Never auto-push from quote-sourced detections |
| High confidence (green) | ≥ **90%** |
| Below 90% | Still show card; operator confirms before push |
| Preferred span | **7–8** consecutive content words for ordinary matches |
| Short unique verses | Allowed (e.g. “Jesus wept”) when span uniqueness (IDF) is maximal |
| Subscription | **Love only** |
| Offline | Required |

## 5. Architecture

### 5.1 Pipeline placement

```
AudioCapture → Transcription (WhisperKit / Apple STT)
  → DetectionPipeline.processTranscript()
       ├─ 1. Explicit ScriptureDetectorService          (all tiers)
       ├─ 2. Famous-phrase ImplicitReferenceDetector    (fast path; keep)
       └─ 3. QuoteCorpusMatcher  ← NEW (Love only)
            → PendingVerse card (sourceType: .quotedScripture)
            → NEVER auto-route to ProPresenter
```

If an explicit reference is already found for the same transcript span, skip quote matching for that span.

### 5.2 Offline index (shipped / built into Bible.db)

Per entitled translation (start with operator’s selected translation; optionally index free KJV+WEB+ASV for all Love users; premium BSB/LSV only if entitled):

| Table | Purpose |
|-------|---------|
| `verse_grams` | `(gram_hash INTEGER, verse_id INTEGER, translation_id INTEGER, span_start INTEGER)` |
| `gram_stats` | `(gram_hash INTEGER, verse_count INTEGER, idf REAL)` |
| `verses_fts` | FTS5 virtual table over `verses.text` for phrase/`NEAR` verify |

Build once offline (import script). Runtime loads hot gram maps into memory (~tens of MB for 1–2 translations).

**N-gram sizes:** store **2-grams through 8-grams**. Short grams exist so unique micro-verses can fire; long grams drive ordinary sermon quotes.

### 5.3 Runtime algorithm

1. **Normalise** transcript slice: lowercase, strip punctuation, optional archaic map (`thee`→`you`, `-eth`→`-s`), apply pastor speech corrections.
2. **Rolling window** of last ~16 tokens, stride 1.
3. For each window position, hash n-grams (n = 2…8) and look up `verse_grams`.
4. **Vote** with IDF weights: rare grams contribute more; grams appearing in hundreds of verses contribute near zero.
5. **Uniqueness gate:** prefer candidates whose decisive grams hit ≤ 3 verses; reject if only high-frequency grams match.
6. **Length / uniqueness rule:**
   - If best span has **maximal uniqueness** (e.g. single-verse hit) → allow n ≥ 2 (“Jesus wept”).
   - Else require contiguous match length ≥ **7** (configurable 7–8).
7. **Verify** top candidates with FTS5 phrase or `NEAR` + contiguous LCS alignment against verse text.
8. **Hysteresis:** require the same `verse_id` to win on ≥ 2 consecutive Whisper partials before emitting a card.
9. **Cooldown:** do not re-emit the same verse within ~60s.
10. **Sermon context prior (optional setting):** boost verses in book/chapter of last operator-confirmed reference.
11. **Score → %** (see §6) and attach `DetectionConfidence` with quote-specific weights.
12. Emit `PendingVerse` with badge **Quote** + percentage; push only on operator click.

### 5.4 Latency budget

| Stage | Target |
|-------|--------|
| Gram vote + verify | &lt; 50 ms on Apple Silicon |
| End-to-end (incl. STT) | Dominated by Whisper (~0.5–2 s) — unchanged |

Run matcher on a serial background queue; read DB via pool (GRDB or existing SQLite access pattern).

## 6. Confidence scoring

Reuse `DetectionConfidence` colours and card chrome. For **quote-sourced** detections, calibrate `overall` so that:

| Band | % | Colour | Meaning |
|------|---|--------|---------|
| Strong match | ≥ 90 | Green | Unique / near-unique contiguous span verified |
| Likely | 55–89 | Yellow | Good vote + FTS verify; operator should glance |
| Uncertain | emit threshold–54 | Orange | Shown only if above emit floor; verify carefully |

**Suggested score composition (quote path):**

```
score =
  0.45 * uniqueness      # inverse of candidate-set size / IDF mass
+ 0.25 * spanLengthNorm  # 2→low unless unique; 7–8→high
+ 0.20 * contiguity      # LCS / ordered overlap with verse text
+ 0.10 * stability       # survived hysteresis (2+ partials)
```

Clamp to 0…1. Map to percentage for UI.  
**Do not** use the legacy famous-phrase length heuristic as the sole score.

**Policy:** Quote-sourced cards **ignore** any Detection Setting that would “auto” send high-confidence items to ProPresenter. Quote path is always suggest-only.

## 7. Settings UX (Love only)

Location: **Settings → Detection** (v2 Screen 11), below Smart Context.

### Visibility

| Tier | Behaviour |
|------|-----------|
| Mercy | Section hidden or locked paywall → Love |
| Grace | Locked with copy: “Spoken quote detection is a Love feature” + upgrade CTA |
| Love | Full controls enabled |

Grace already has Detection Settings (`premiumGated`); quote matching uses a **stricter** `loveGated` (or equivalent) check.

### Controls

| Control | Default | Notes |
|---------|---------|-------|
| Enable spoken quote detection | On | Master toggle |
| Minimum match strength (emit floor) | ~55% | Below this, no card |
| High-confidence mark | **90%** | Green tag threshold for quotes |
| Preferred span length | 8 (range 7–8) | Soft preference; uniqueness can override downward |
| Prefer active sermon context | On | Boost last confirmed book/chapter |
| Show “Quote” badge on cards | On | Distinguish from spoken references |

**Footer (British English):**  
*Spoken quotes appear as suggestions with a confidence percentage. They never push to ProPresenter until you click.*

### Card chrome

- Badge: `Quote` (or `Suggested quote`)
- Confidence chip: `92%` green / `70%` yellow / `48%` orange
- Same push / dismiss affordances as today
- Optional hover breakdown (reuse `showConfidenceBreakdown`)

## 8. Website / marketing (Love column)

Add to compare / pricing (Love only), e.g.:

- **Spoken quote detection** — recognises scripture when it’s quoted without a reference, not only famous lines like John 3:16
- Tagline option: *“Hear the quote. Show the verse.”*

Do **not** claim paraphrase AI until Phase 2 ships.

## 9. Integration with existing code

| Component | Change |
|-----------|--------|
| `DetectionPipeline.swift` | After famous detector, if Love + enabled → `QuoteCorpusMatcher` |
| `ImplicitReferenceDetector.swift` | Keep as Stage-0; optional later fold into corpus |
| `BibleVocabularyData.famousVerses` | Retain for fast path / eval baselines |
| `DetectionSettings.swift` | New Love-only keys (§7) |
| `SettingsView.swift` / v2 Detection screen | New section + `loveGated` |
| `DetectionConfidence.swift` | Quote factory / weights; green band 0.9 for quotes |
| `BufferManager` / `PendingVerse` | `sourceType` / badge; block auto-push for quotes |
| `SubscriptionService` | Gate: Love only |
| `Bible.db` + rebuild scripts | Gram + FTS tables |
| `docs/FEATURE-MATRIX.md` | Love row for quote matching |
| Story 7.2 | Update status / split Phase 1 corpus vs Phase 2 MLX |

## 10. False-positive controls

1. IDF down-weight of ubiquitous phrases (“and it came to pass”)
2. Candidate cardinality gate (decisive grams ≤ 3 verses)
3. Contiguity / FTS verify
4. Hysteresis (2 partials)
5. Per-verse cooldown (~60s)
6. Never auto-push
7. Optional sermon-context boost (reduces wrong-book collisions)
8. Operator dismiss + emit-floor slider

## 11. Evaluation plan

| Set | Size | Purpose |
|-----|------|---------|
| Famous positives | ≥ 17 | Regression: John 3:16 etc. still resolve via corpus path |
| Obscure unique 7–8-grams | ≥ 50 | True positives without dictionary |
| Short unique | “Jesus wept” + peers | Uniqueness override |
| Negatives | ≥ 50 sermon-like non-quotes | False-positive rate |
| STT-noisy variants | subset of positives | Robustness |
| Cross-translation | KJV vs BSB wording | Entitlement-aware |

**Targets (initial):**

- Unique 7–8-gram recall ≥ 90% on clean text
- False cards per hour of typical sermon audio: track &amp; tune; prefer precision over recall while never auto-pushing

## 12. Phased roadmap

| Phase | Scope | Love value |
|-------|--------|------------|
| **1** | N-gram + IDF + FTS, Settings, cards, website copy, never auto-push | Unique quote→verse |
| **2** | On-device embeddings for paraphrase | “as Scripture says…” soft quotes |
| **3** | Anaphora + history (“verse we just read”) via MLX / context | Full Story 7.2 |

## 13. Risks

| Risk | Mitigation |
|------|------------|
| STT drops/garbles words | N-gram voting (not single exact phrase); pastor corrections |
| Operator distrust from false cards | Never auto-push; IDF; hysteresis; cooldown; slider |
| Index size / memory | Start with 1–2 translations; document MB budget |
| Confusion with Grace Detection Settings | Explicit Love lock + footer copy |
| Over-promising AI on website | Market Phase 1 accurately |

## 14. Open implementation notes (not blockers)

- Exact GRDB vs raw SQLite for FTS5 — follow existing `BibleService` patterns
- Whether famous dictionary remains permanently or becomes a seed for eval only
- Precise cooldown / window sizes — tune against eval set

## 15. Approval record

- **2026-08-06:** Principal approved Approach 1 (n-gram + FTS), Love-only exclusivity, card + % confidence, never auto-push, ≥90% green, 7–8 word preference with uniqueness override for short unique verses.

---

## Related docs

- `Plans/Love-Quote-Matching-Plan.md` — implementation-oriented summary
- `Plans/quote-matching-think-notes.md` — Algorithm THINK notes
- `docs/stories/epic-7/story-7.2-implicit-detection.md` — prior story
- `docs/FEATURE-MATRIX.md` — tier matrix
- `REDESIGN-SPEC-v2.0.0.md` § Settings · Detection — v2 screen home for controls
