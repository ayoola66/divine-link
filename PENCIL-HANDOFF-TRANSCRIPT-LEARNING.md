# Pencil Handoff: Infinite Transcript + Learning Loop

Use this as the design instruction for `redesign.pen` updates.

## Context
We need the Listen experience to keep all heard words/sentences in one continuous transcript stream so users can revisit older lines, correct misheard words, and teach the app over time.

## Screens to Update
- Screen 01: Listen (FREE Tier)
- Screen 02: Listen (PREMIUM Tier)

## Required UI Additions
1. **Infinite transcript stream**
   - One continuous vertical stream for the active service.
   - Supports long-session scroll up/down.

2. **Scroll behaviour controls**
   - `Auto-scroll` toggle (on/off).
   - `Jump to Live` action when user is not at the latest line.

3. **Inline correction affordance**
   - Keep `Select words to edit` cue near transcript.
   - Selecting a word/phrase opens correction dialog/popover:
     - `Heard` (read-only)
     - `Replace with` (editable)
     - `Cancel` / `Apply`

4. **Post-correction feedback**
   - Corrected word gets a subtle visual state (e.g. highlight or underline).
   - Optional small status note: `Saved to learning`.

## Behaviour Notes for Engineering
- On `Apply`, update transcript immediately and store correction in internal learning DB.
- Suggested learning record fields:
  - `heard_text`
  - `corrected_text`
  - `context_before`
  - `context_after`
  - `translation`
  - `service_id`
  - `timestamp`
  - `pastor_profile_id` (if available)
- Deduplicate repeated corrections and increment frequency count.

## Free vs Premium Rule
- This correction/learning feature exists in **both** Free and Premium.
- Only layout differences remain:
  - Free: includes ad rail + bottom banner
  - Premium: no ads

## Callouts to Place on Pencil Artboards
- `Infinite transcript stream`
- `Auto-scroll + Jump to Live`
- `Select and correct misheard words`
- `Apply -> stored for future recognition`
