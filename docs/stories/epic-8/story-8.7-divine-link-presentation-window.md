# Story 8.7: Divine Link Presentation Window

**Story ID:** 8.7  
**Epic:** 8 — UX/UI Modernisation & Platform Expansion  
**Priority:** P0 (build before Story 8.6 FreeShow)  
**Complexity:** Small–Medium  
**Estimated Effort:** 3–5 hours for MVP; 1 further day for polish  
**Target Version:** v1.7.0  
**Status:** In progress — DivineView MVP wired (window, black/white, Push, Panic)  
**Spec:** [`Plans/Presentation-Outputs-Roadmap.md`](../../../Plans/Presentation-Outputs-Roadmap.md)

---

## Story

**As a** church media operator without ProPresenter  
**I want** Divine Link to show the confirmed verse on its own simple presentation window  
**So that** I can put scripture on a projector or second display without another presenter app

---

## Acceptance Criteria

1. Window → Presentation Display opens a dedicated window (not the operator console).
2. Background is Black or White, chosen in Settings, persisted across launches.
3. Push One / Push All write reference + verse text + translation onto that window.
4. Panic / Clear empties the window.
5. Existing ProPresenter push is unchanged when the operator is still targeting ProPresenter.
6. Empty window shows no leftover verse text.
7. British English copy only.

---

## Technical Notes

- Add `PresentationDisplayController` + `PresentationDisplayView`.
- Hook from `PushActionCoordinator` and `PanicButtonService`.
- Reuse `ScriptureDisplayData.audienceDisplayText` (no confidence % on the audience surface).
- Do not refactor `HybridIntegrationManager` in this story.

## Out of Scope

FreeShow, EasyWorship, NDI, OBS, auto-push, themes, output-protocol rewrite.
