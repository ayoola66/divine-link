# THINK notes — Quote → Verse matching (2026-08-06)

## FirstPrinciples
- Hard constraints: local SQLite corpus; ordered token match; integrate DetectionPipeline; Love-only gate; never auto-push ProPresenter from quote path.
- Soft: “7–8 consecutive words” — proxy for uniqueness, not a physics law.
- Soft: “90% = green” — UX threshold; score must be calibrated so unique spans land ≥0.9.
- Assumption to validate: Whisper STT preserves enough consecutive tokens for 7-grams under church acoustics.
- Reconstruct: score = uniqueness(IDF) × span_length × contiguity × STT_stability — not raw word count alone. “Jesus wept” scores ~1.0 because inverse-document-frequency is maximal (appears once).

## SystemsThinking (Iceberg)
- Event: only John 3:16 / Genesis 1:1 fire from quotes.
- Pattern: dictionary maintenance never scales; pastors quote freely.
- Structure: DetectionPipeline → ImplicitReferenceDetector(substring) with no corpus index.
- Mental model (to replace): “famous = detectable.” New model: “unique ordered span = detectable.”
- Archetype risk: Fixes That Fail — expanding famousVerses list forever. Intervention: index the corpus once.
- Balancing loop needed: false positives → distrust → disable. Counter with never-auto-push + IDF gates + cooldown.

## RootCauseAnalysis (5 Whys)
1. Obscure quotes miss → no corpus search.
2. Only famous list → Story 7.2 partial ship.
3. MLX deferred → dictionary stub left as “good enough.”
4. No FTS/n-gram on verses.text → schema is reference-keyed only.
5. Product never required Love quote matching in shipped v1. Root enough: add local inverted index + Love Settings surface.

## ApertureOscillation
- Narrow: QuoteCorpusMatcher service + gram tables in Bible.db.
- Wide: Love Pro differentiator on website, Settings Love-only section, confidence badges reuse DetectionConfidence colours, operator trust.
- Tension: Detection Settings today is Grace+; this feature must be Love-only and must override any “auto” ProPresenter path for quote-sourced cards.

## IterativeDepth lenses (yield)
- Failure: common phrases (“and it came to pass”), STT garble, reading long chapters → flood.
- Stakeholder: operator wants suggest+%; preacher wants zero friction; church wants no wrong slides on screen.
- Temporal: hysteresis across Whisper partials; cooldown; sermon context prior.
- Constraint inversion: if we forbid auto-push entirely for quotes, we can surface more candidates safely.

## BeCreative (Verbalized Sampling — one best)
Hybrid cascade: uniqueness-aware n-gram voting (variable min length 2 when IDF-maximal, else 7–8) → FTS verify → confidence mapped to existing green/yellow/orange → Love Settings. Defer embeddings/MLX to Phase 2.
