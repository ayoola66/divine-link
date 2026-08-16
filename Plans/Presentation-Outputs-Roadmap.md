# Presentation Outputs Roadmap — Divine Link GUI, FreeShow, ProPresenter

**Date:** 16 August 2026  
**Status:** DivineView MVP coded (16 Aug 2026) — FreeShow still next  
**Related:** Story 8.7 (new), Story 8.6 (FreeShow / EasyWorship), Pewbeam gap analysis §5

---

## 1. What we are building

Divine Link becomes a **three-target scripture pusher**, not a ProPresenter-only accessory.

| Target | Who it is for | What Divine Link sends |
|--------|----------------|------------------------|
| **Divine Link Presentation Window** | Churches with a laptop + projector / HDMI, no ProPresenter | Verse text + reference onto our own full-screen window |
| **FreeShow** | Churches that already replaced ProPresenter with FreeShow | `start_scripture` (reference) via FreeShow’s REST / WebSocket API |
| **ProPresenter** | Existing Divine Link churches | Stage / Messages / Keyboard — already shipped |

The operator still confirms (human-in-the-loop). Panic Button clears whichever targets are live.

---

## 2. Why this order

Pewbeam already ships its own display. Churches on FreeShow are a real market Divine Link cannot reach today. The highest-leverage piece is **owning a surface**, not another integration.

1. **Divine Link Presentation Window first** — no third-party API, reuses Push One / Push All / Panic, HDMI is “put this window on the other display and full-screen it.”
2. **Output picker second** — Settings: Divine Link / ProPresenter / FreeShow (one primary target to start; multi-target later).
3. **FreeShow third** — documented API (`POST http://localhost:5506` with `{ "action": "start_scripture", "reference": "John 3:16" }`, plus `clear_slide` / `clear_all`). Easier than EasyWorship.
4. **EasyWorship last** — still Story 8.6 research-spike territory; do not block FreeShow on it.

---

## 3. Phase A — Divine Link Presentation Window (tonight-shaped MVP)

**Goal:** Push a confirmed verse onto a simple Divine Link window that can sit on a second display.

### In scope for the first cut

- Separate SwiftUI window: “Presentation Display”
- Background: **Black** or **White** (persisted)
- Text: verse body + reference + translation abbreviation
- Type colour: white on black, black on white
- Menu: **Window → Presentation Display** (and a button on the main operator view)
- Push One / Push All also write this window when the target is Divine Link (or when “also show locally” is on)
- Panic / Clear empties the window
- Empty state: quiet background, no leftover verse
- Operator can drag the window to the projector display and use macOS full screen / green zoom

### Out of scope for the first cut

- Themes, motion, images, NDI, OBS
- Auto-push at 90% confidence (add after the window exists)
- FreeShow / output-protocol rewrite
- Multi-verse slideshow animation
- Windows port

### How it plugs into today’s code

Push already funnels through `PushActionCoordinator` → `ProPresenterClient`. The first cut adds a `PresentationDisplayController` (owns the window + current `ScriptureDisplayData`) and calls it from the same coordinator. Do **not** wait for a full `PresentationOutputProtocol` rewrite to ship the window.

`ScriptureDisplayData` already has `audienceDisplayText` (clean, no confidence). Use that.

### Tonight feasibility

**Yes — a thin window is a tonight job** if we keep it stupid-simple.

| Piece | Effort | Notes |
|-------|--------|--------|
| New `PresentationDisplayView` + `NSWindow` | 1–2 h | Standard SwiftUI `Window` / `WindowGroup` on macOS 13+ |
| Black / white toggle in Settings | 30–45 min | `UserDefaults` / `AppStorage` |
| Hook Push + Panic | 45–90 min | `PushActionCoordinator` + `PanicButtonService` |
| Second-display / full-screen polish | 30–60 min | Optional tonight; HDMI works if the operator full-screens manually |
| **Total** | **~3–5 hours** | Working MVP, not a productised look |

**Not tonight:** FreeShow client, platform radio group, 90% auto-push, output abstraction refactor.

Risk if we rush the refactor tonight: we break ProPresenter push. Keep PP path untouched; add a parallel write to the local window.

---

## 4. Phase B — Output target picker

Settings → Presentation:

1. Divine Link Presentation Window (default for new installs? **No** — keep ProPresenter as default for existing users; new users can pick DL Window)
2. ProPresenter (current behaviour)
3. FreeShow (disabled until Phase C)

Panic always clears the active target. Later: “also mirror to Divine Link window” so PP churches can preview locally.

---

## 5. Phase C — FreeShow

FreeShow is the right second platform (name match, churches already using it instead of ProPresenter, public API).

**Confirmed API (freeshow.app/api):**

- Enable WebSocket / REST in FreeShow → Connections
- REST: `POST http://<ip>:5506` body `{ "action": "start_scripture", "reference": "John 3:16" }`
- Also: `scripture_next`, `scripture_previous`, `clear_slide`, `clear_all`
- WebSocket: port **5505** (Socket.IO `data` emit) — use REST first; it is simpler from Swift

**Divine Link work:**

- `FreeShowClient.swift` — URLSession POST, test-connection, clear
- Settings: IP (default `127.0.0.1`), REST port `5506`
- Map our `PendingVerse.displayReference` into FreeShow’s `reference` string
- FreeShow renders with **its** Bible + theme — we send the reference, not styled pixels

**Effort:** 1–2 days after Phase A, including a live test against a running FreeShow install. Story 8.6 already estimated 24–32 hours because it bundled EasyWorship + a full protocol layer. FreeShow-only is smaller.

**Research still needed before coding Phase C:** confirm `start_scripture` uses FreeShow’s installed translation (not ours), and how numbered books (`1 John 3:16`) must be formatted.

---

## 6. Phase D — Shared output protocol (only after two targets work)

Then extract what Story 8.6 already specified:

```text
PresentationOutputProtocol
  connect / disconnect / sendScripture / clearScripture / testConnection

DivineLinkDisplayClient
ProPresenterClient          (existing, adapted)
FreeShowClient
```

Do not start here. Two working targets teach the protocol; a protocol with one target is theatre.

---

## 7. Product rules

| Rule | Value |
|------|--------|
| Operator confirm | Required for all three targets (same as today) |
| Auto-push | Not in Phase A; later, ≥90% confidence → DL Window only, never PP/FreeShow without a setting |
| Panic | Clears the active target(s) |
| Offline | DL Window is fully local; FreeShow/PP need the other app on the LAN |
| Tier | DL Window: all tiers (this is how Free/Mercy churches present without PP). FreeShow: all tiers (parity with PP Stage). Keep Messages API Premium as today. |
| Language | British English in the UI |

---

## 8. Suggested versions

| Version | Ship |
|---------|------|
| **v1.7.0** | Phase A — Divine Link Presentation Window + black/white |
| **v1.8.0** | Phase B picker + Phase C FreeShow REST |
| **v2.0.0** | Protocol cleanup, EasyWorship spike, optional OBS / 90% auto-push |

---

## 9. Open decisions (do not block Phase A)

1. Default target for brand-new installs: ProPresenter (safer for current users) vs Divine Link Window (better for FreeShow-era churches).
2. Whether Push can hit **two** targets at once (DL Window + PP) in v1.7, or only one.
3. Love-only quote matching still never auto-pushes — even to the DL Window — until that rule is deliberately changed.
