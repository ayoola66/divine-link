# Competitor Gap Analysis — Pewbeam

**Date:** 2026-08-12 (v2 — corrects and supersedes the earlier draft, which used the wrong name "Pill Beam"/"PewBean" and carried unverified assumptions)
**Sources used, and how much to trust each:**

| Source | What it is | Trust |
|---|---|---|
| Owner-provided FAQ video transcript | Pewbeam's own promotional Q&A | Primary, but unverified independently — treat specific claims (voice commands, OBS passthrough) as "they said this," not confirmed |
| pewbeam.com (homepage + /pricing) | Their own marketing site, fetched live 2026-08-12 | Marketing claims — real, current, but self-reported |
| ablazehub.org.ng article | Independent Nigerian tech press | Independent, but still summarizing Pewbeam's own claims |
| technext24.com, chatgate.ai, ai2africa.com, X (@pewbeam_ai) | Found via search, some blocked/unfetched | Only summaries available, not fully verified |

Where sources conflict, both numbers are shown below rather than picking one. Nothing here should be read as more certain than "this is what is publicly claimed."

---

## 1. Identity

**Real name: Pewbeam** (not "Pill Beam" — that was a mishearing from the audio transcript; not "PewBean" either). Built by Nigerian developer **Dara Sobaloju**, started as a public build from an August 2025 idea post, launched publicly **March 2026**. First tested at Celebration Church International, Ibadan. A "Pewbeam 2.0" relaunch is referenced on their X account — this may explain some of the pricing inconsistencies below (numbers may have changed between versions and between when the owner's transcript was recorded and now).

---

## 2. What's actually confirmed (multi-source or from their own site)

- **AI Bible verse detection with semantic/paraphrase matching**, not just literal reference parsing — "understands meaning, not just words," matching across the full canon (one source says 31,000+ verses — i.e. the whole Bible, not a curated shortlist). This is the single most important confirmed capability gap (see §4).
- **~80ms verse-display latency** claimed on their site.
- **Animated verse presentations** via something they call "Motion Canvas" — their own built-in display, not obviously a ProPresenter/OBS plug-in on the marketing copy.
- **AI Sermon Notes** with PDF export, and **AI slide generation** — neither of these exist in Divine Link at all. Not something we were tracking before this research.
- **Platform: Windows AND macOS** — confirmed explicitly ("Pewbeam AI is currently available for Windows & Mac OS," ablazehub). This is a real, confirmed gap: Divine Link is Mac-only today.
- **Core tier: "Main + Alternate output (NDI + HDMI)"** and up to 3 devices per licence — confirmed on their own pricing page. This matches your idea below about direct-HDMI output.
- **Offline claim:** their own site states, twice, in near-identical wording across two independent pages: *"Works perfectly without internet"* / *"runs entirely without an internet connection once installed. No cloud dependency. No dropped signals."*

### ⚠️ This contradicts what you told me

You said Pewbeam "needs to be connected online to work properly" because it's "fully AI-based." Their own marketing says the opposite — offline-capable once installed, explicitly pitched at Nigeria's unreliable internet. I can't independently verify either claim (I haven't run their software), but the two claims are in direct conflict, and their side is stated twice, on two different domains, in similar language. **Worth resolving before this shapes any decision** — if you've directly observed it requiring a connection, that lived observation should outweigh their marketing copy; if you were inferring it from "AI-based," that inference doesn't hold given what they publish.

If offline is real, it removes "we work fully offline, they don't" as a differentiator. What likely *doesn't* transfer to them: your on-device claim is backed by a codebase I've read (WhisperKit running locally, no audio-upload code path) — theirs is a homepage sentence I can't inspect the code behind.

---

## 3. Pricing — sources disagree, shown as-is

| Source | Free | Mid tier | Top tier |
|---|---|---|---|
| Your FAQ transcript | 40 min/week | ₦12,000 / $14 — "unlimited transcription per year" | ₦32,000 / $30 — "unlimited, all features" |
| pewbeam.com homepage | — | $14/month | $30/month |
| pewbeam.com/pricing | 60 free min (one-time) | $12/month ($144/year) | $25/month ($300/year), 14-day offline grace period |

Pattern that holds across all three: **free tier + two paid tiers, roughly $12–14 and $25–30**, monthly with an annual discount. The exact numbers, the free-tier limit (40 vs 60 min), and whether "$14" is a monthly or annual figure don't agree — plausibly explained by the 2.0 relaunch changing prices after your transcript was recorded. Don't quote an exact number externally (e.g. on `compare.html`) until you check pewbeam.com/pricing yourself on the day you publish.

---

## 4. Real gaps (confirmed, not assumed)

### 4.1 Production-quality paraphrase/semantic matching across the whole Bible
This is the one that matters most. Pewbeam's own site claims full-corpus semantic search, not a curated list. Divine Link's equivalent — "Love Quote Matching" — is **designed but not built** (see §7, code-verified below). If their claim holds up in real use, this is currently a real, live capability gap, not a future risk.

### 4.2 Windows support
Confirmed (ablazehub). You already know this is Divine Link's weak spot; not urgent per your own note, but now it's a *confirmed* competitor capability, not a guess.

### 4.3 AI Sermon Notes + PDF export, AI slide generation
Not previously on Divine Link's radar at all. Out of scope for this analysis's recommendations, but worth a deliberate "not doing this / doing this later" decision rather than silence.

### 4.4 Voice commands and OBS/ProPresenter passthrough — **transcript-only, not independently confirmed**
Your FAQ transcript describes "next verse / previous verse / give me NLT / change to KJV" voice commands, and connecting output to OBS, ProPresenter, or "a screen interface." None of the three web sources I could fetch mention voice commands, OBS, or ProPresenter at all — their marketing copy reads as "our own display only" (Motion Canvas, NDI+HDMI). This doesn't mean the transcript is wrong — a FAQ video is a legitimate first-party source and marketing homepages routinely omit real features — it means I have one source for this, not two. Treat it as likely true (why would they make it up in an FAQ) but unconfirmed by me independently.

The Divine Link angle on this stays what I found last time: `ScriptureDetectorService.swift` already resolves spoken "next verse"/"previous verse" phrases via `ReferenceBuffer` — the mechanism a voice-command layer needs already exists in the codebase, confirmed by direct code read, independent of anything about Pewbeam.

---

## 5. Your standalone-display idea — this is a real, well-scoped feature, not just a reaction to Pewbeam

What you described: Divine Link gets its own built-in verse display window (own GUI), pushable via direct HDMI-out from the laptop, with OBS as an additional output target alongside the existing ProPresenter Stage/Messages integration. Detections ≥90% confidence auto-push to that display; below 90%, the operator confirms as today.

This is buildable on what already exists:
- **Confidence scoring already exists** (`DetectionResult.confidence`, already used for the Panic Button / confidence UI and the implicit-match gate at `confidence >= 0.6` in `DetectionPipeline.swift`) — a 90% auto-push threshold is a new comparison against a field that's already computed, not new inference.
- **A push target abstraction already exists** in spirit: `ProPresenterClient` (Stage REST + Messages WebSocket) and `KeyboardAutomationService` are already two interchangeable output paths. A third path — "Divine Link's own window" — slots into the same place `Push One`/`Push All` already calls into (`MainView.swift`), it's a new implementation of an existing seam, not a new architecture.
- **OBS** would be new integration work (likely via OBS's WebSocket API to update a text/browser source) — more effort than the built-in-window path, but a well-understood, documented API.

This directly closes §3.3 (standalone-display gap) from the original analysis, and does it in a way that's additive — churches with ProPresenter keep using it, churches with nothing get a first-class option, and HDMI-direct covers churches with just a projector and a laptop.

**Recommendation:** sequence as (1) built-in display window + 90%-confidence auto-push/below-90%-confirm — this is the highest-leverage piece and mostly reuses existing plumbing, (2) HDMI is "free" once the window exists (it's just an external display in a full-screen window, no new code), (3) OBS integration last, since it's genuinely new integration surface and lower urgency than having *any* standalone display at all.

---

## 6. Love Quote Matching — implementation status, checked directly against the code

You asked me to check rather than assume. Here's what's actually true, verified two ways (docs + source):

**Not implemented.** `Plans/Love-Quote-Matching-Plan.md` states status "Roadmapped — not in active development," and I confirmed this against the actual Swift source: the only quote-matching code that exists is `ImplicitReferenceDetector.swift`, which matches against a **static, hardcoded dictionary of exactly 17 phrases** in `BibleVocabularyData.swift` (lines 369–387: things like "for god so loved the world," "the lord is my shepherd," "i am the way the truth and the life," etc.). There is no n-gram index, no FTS5, no full-corpus search anywhere in the codebase — the Phase 1 design in `docs/superpowers/specs/2026-08-06-quote-verse-matching-design.md` has not been started.

### Why "Jesus wept" didn't show up — not a bug, this is exactly what the current code does

Two independent reasons, both confirmed by reading the code:

1. **"Jesus wept" is not in the 17-phrase list.** The hardcoded matcher can only ever fire on those 17 exact phrases (checked case-insensitively as a substring match). Anything else — including this one — produces zero matches, by design.
2. **Even if you added it, it would still be blocked today.** `ImplicitReferenceDetector.swift` has `minimumPhraseWords = 5`, with a comment explaining it's there specifically to stop short fragments from firing false positives. "Jesus wept" is 2 words — it would be filtered out before the dictionary lookup even runs.

This is the exact case your own locked product rules for the *unbuilt* Phase 1 already called out: *"short unique verses allowed (e.g. 'Jesus wept')"* — you (or whoever wrote that spec) already knew this was the hard case, which is precisely why it's handled by real corpus/uniqueness logic in the Phase 1 design rather than the current keyword list. The other quotes you read off your phone that *did* work almost certainly matched one of the 17 entries verbatim (or close enough via substring match); anything not on that list, including short ones, currently cannot match, full stop. Nothing to fix here today — this confirms the current build's known limitation rather than uncovering a new defect.

### Should you build it now, and free or premium?

Not a call I'll make for you, but here's what changed today that should inform it: Pewbeam's own marketing already claims exactly this capability, in production, across the whole Bible, at 80ms. If that claim holds up under real church use, "quote/paraphrase matching" is turning from *your* differentiator-in-waiting into their *headline* feature that you don't yet have. That raises the cost of leaving it parked — every week it stays unbuilt is a week a prospect can compare and find Pewbeam ahead on the one feature they lead with.

On tier placement: the existing locked rule (Love-only, card + confidence %, never auto-push) already reflects your human-in-the-loop positioning and is worth keeping even under competitive pressure — the difference vs Pewbeam wouldn't be "we also detect quotes," it'd be "we detect quotes *and* still won't put something wrong on your screen without you clicking it," which is the same moat as the rest of the app. Free-tier inclusion would blunt that differentiation for paying churches and give away the thing Pewbeam is charging for; premium-gating it protects both the differentiator and the upgrade incentive. If you want a middle path: ship Phase 1 at Love tier as designed, but consider whether Grace should get a capped version (e.g. fewer matches per session) rather than nothing, given Pewbeam doesn't appear to gate this feature by tier at all.

---

## 7. Roadmap (updated)

**Now:**
1. Resolve the offline/online contradiction (§2) — check for yourself rather than carry two conflicting beliefs into marketing or engineering decisions.
2. Built-in standalone display window + 90%/confirm-below threshold (§5, part 1) — highest leverage, most reuse of existing code.
3. Voice-command translation switching (unchanged from prior draft — still a few-days job reusing the existing phrase-detection pipeline).
4. Update `compare.html` with the corrected name and only the claims you're comfortable standing behind publicly (the confirmed ones from §2, not the transcript-only ones from §4.4 until you've verified them).

**Next (1–3 months):**
5. Ship Love Quote Matching Phase 1 — priority raised by this research, see §6.
6. HDMI-out (falls out of #2 for free) and OBS integration (§5, part 3).
7. Operator-facing "next/previous verse" as a live navigation command, not just a new-reference detector.

**Later:**
8. Windows port — now a confirmed gap, not a guess; still your call on timing given the scale of that work.

**Explicitly decide, don't ignore:**
9. AI Sermon Notes / slide generation — new category Pewbeam has that you don't; needs a deliberate "not now" or a spot on the roadmap, not silence.

---

## 8. Open questions

- Direct verification of Pewbeam's offline/online behaviour — resolve the contradiction in §2 before it shapes messaging.
- Voice-command and OBS/ProPresenter-passthrough claims — first-party FAQ only, not independently confirmed.
- Real installed-base numbers ("hundreds of churches") — from tech-press summaries, not verified.
- Exact current pricing — three sources disagree; check pewbeam.com/pricing directly before publishing any number externally.

---

Sources:
- [Pewbeam](https://pewbeam.com/)
- [PewBeam: All you should know about Dara Sobaloju's scripture rendering AI app — MEXC News](https://www.mexc.com/news/975142)
- [Pewbeam AI: Revolutionizing Scripture Projection in Churches — Ablaze Hub](https://ablazehub.org.ng/pewbeam-ai-revolutionizing-scripture-projection-in-churches-what-you-should-know/)
- [Pewbeam — ChatGate](https://chatgate.ai/post/pewbeam)
- [The PewBeam effect — technext24](https://technext24.com/reviews/the-pewbeam-mirroring-fintech-gold-rush/)
