# Divine Link - UI Specification

**Document Type:** Software UI Shape (For AI App Developer)  
**Version:** 1.0  
**Date:** January 2026  
**Author:** coachAOG  
**Status:** Approved

---

> This section defines how the app should **feel and behave**, not just how it looks.

---

## 3.1 Overall UI Philosophy

| Principle | Description |
|-----------|-------------|
| **Single-window application** | No modal dialogs, no floating panels during operation |
| **No nested menus during live use** | Every action is one click or keystroke away |
| **Everything visible at a glance** | Operator never hunts for information |
| **Designed for live pressure environments** | Calm, predictable, zero surprises |

> **Think: mission control, not creative software.**

---

## 3.2 Layout Structure (Top to Bottom)

```
┌─────────────────────────────────────────────────────────────────┐
│  [Logo]          STATUS: Listening              [⚙️ Settings]   │  ← Header Bar
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  "...and as we read in the book of Romans, chapter eight,      │  ← Zone 1:
│   verse twenty-eight, we know that all things work together    │    Listening Feed
│   for good to them that love God..."                           │    (scrolling transcript)
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐   │
│  │         DETECTED SCRIPTURE (PENDING)                     │   │  ← Zone 2:
│  │                                                          │   │    Pending Scripture
│  │  📖  Romans 8:28                                         │   │    (Primary Focus)
│  │                                                          │   │
│  │  "And we know that in all things God works for the      │   │
│  │   good of those who love him, who have been called      │   │
│  │   according to his purpose."                             │   │
│  │                                                          │   │
│  │  Translation: Berean Standard Bible                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   [▶ PUSH TO PROPRESENTER]    [✕ IGNORE]    [⏸ PAUSE]         │  ← Zone 3:
│        (Enter)                  (Esc)        (Space)            │    Actions
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Header Bar

| Position | Element | Notes |
|----------|---------|-------|
| **Left** | Divine Link logo mark | Small, unobtrusive |
| **Centre** | Status text | "Listening", "Paused", "Pending Verse" |
| **Right** | Settings icon (⚙️) | Minimal, single icon |

### Zone 1: Listening Feed (Top)

| Attribute | Specification |
|-----------|---------------|
| **Content** | Live transcription text |
| **Appearance** | Greyed, non-editable |
| **Behaviour** | Scrolls automatically (newest at bottom) |
| **Purpose** | Reassurance, not interaction |
| **Interaction** | None—read-only |

### Zone 2: Pending Scripture (Centre — Primary Focus)

> **This is the heart of the app.**

| Attribute | Specification |
|-----------|---------------|
| **Container** | Card-style with subtle shadow |
| **Background** | Off-white (#F8F8F8 or similar) |
| **Scripture text** | Blue (#2563EB or similar) |
| **Label** | "Detected Scripture (Pending)" |

**Displays:**
- Book name
- Chapter number
- Verse number(s)
- Full scripture text
- Translation name (e.g., "Berean Standard Bible")

> **No auto-push. Ever.**

### Zone 3: Actions (Bottom)

| Button | Appearance | Shortcut | Action |
|--------|------------|----------|--------|
| **Push to ProPresenter** | Large, gold accent (#D4AF37) | `Enter` | Send scripture to PP stage message |
| **Ignore / Clear** | Neutral, secondary | `Esc` | Dismiss pending verse |
| **Pause Listening** | Grey, tertiary | `Space` | Stop transcription temporarily |

**Design notes:**
- Buttons must be large and unmistakable
- Keyboard shortcuts prominently displayed
- Touch-friendly sizing (44pt minimum hit area)

---

## 3.3 States (Very Important)

### Listening State
| Attribute | Specification |
|-----------|---------------|
| **Indicator** | Calm blue (#3B82F6) |
| **Animation** | Subtle pulse only (1s cycle, low opacity) |
| **Feel** | Relaxed alertness |

### Pending Verse State
| Attribute | Specification |
|-----------|---------------|
| **Indicator** | Gold accent border (#D4AF37) |
| **Animation** | None—static card |
| **Behaviour** | Nothing auto-happens |
| **Feel** | Clear call to action, no pressure |

### Paused State
| Attribute | Specification |
|-----------|---------------|
| **Indicator** | Muted grey UI (desaturated) |
| **Behaviour** | Listening fully disabled |
| **Status text** | "Paused" |
| **Feel** | Intentionally dormant |

### Error / Uncertainty State
| Attribute | Specification |
|-----------|---------------|
| **Language** | Neutral, helpful |
| **Colour** | Amber for warnings, red only for critical failures |
| **Behaviour** | No alarming sounds or flashing |
| **Examples** | "ProPresenter connection lost. Reconnecting..." |

---

## 3.4 Operator Control Rules (Non-Negotiable)

These rules are **inviolable constraints** on the application's behaviour:

| Rule | Description |
|------|-------------|
| **1. Never override the operator** | The app suggests; the human decides |
| **2. Never auto-display scripture** | All pushes require explicit approval |
| **3. Manual ProPresenter use must always remain possible** | Divine Link is additive, not exclusive |
| **4. No hidden automation** | Every action the app takes must be visible and understood |
| **5. Graceful degradation** | If Divine Link fails, operators can continue manually |

---

## 3.5 What NOT to Build (Explicit for Developer)

These features are **explicitly out of scope** and must not be implemented:

| Anti-Feature | Reason |
|--------------|--------|
| ❌ Slide editor | Divine Link displays text, not designs slides |
| ❌ AI configuration panels | The AI works invisibly; no tuning knobs |
| ❌ Multi-tab complexity | Single-window, single-purpose |
| ❌ Flashy animations | Distracting in live environments |
| ❌ Hidden automation | Trust requires transparency |
| ❌ Auto-push mode | Violates human-in-the-loop mandate |
| ❌ Theme customisation | One look, consistent, no decisions |
| ❌ Plugin architecture | MVP is focused and complete |

---

## 3.6 Colour Palette (Reference)

| Use | Colour | Hex |
|-----|--------|-----|
| **Primary (Scripture text)** | Blue | #2563EB |
| **Accent (Push button, pending border)** | Gold | #D4AF37 |
| **Listening indicator** | Calm blue | #3B82F6 |
| **Background (main)** | Near-white | #FAFAFA |
| **Background (pending card)** | Off-white | #F8F8F8 |
| **Text (primary)** | Near-black | #1F2937 |
| **Text (secondary)** | Grey | #6B7280 |
| **Paused/disabled** | Muted grey | #9CA3AF |
| **Error (critical only)** | Red | #DC2626 |
| **Warning** | Amber | #F59E0B |

---

## 3.7 Typography (Reference)

| Element | Font | Size | Weight |
|---------|------|------|--------|
| **Scripture text** | SF Pro (system) | 18pt | Regular |
| **Scripture reference** | SF Pro | 24pt | Semibold |
| **Status text** | SF Pro | 14pt | Medium |
| **Transcript** | SF Mono | 13pt | Regular |
| **Buttons** | SF Pro | 16pt | Semibold |

---

## 3.8 Keyboard Shortcuts (Complete)

| Action | Shortcut | Context |
|--------|----------|---------|
| Push to ProPresenter | `Enter` or `⌘+Return` | When verse pending |
| Ignore/Clear | `Esc` | When verse pending |
| Pause/Resume Listening | `Space` | Always |
| Open Settings | `⌘+,` | Always |
| Quit Application | `⌘+Q` | Always |

---

**Document Version:** 1.0  
**Approved By:** coachAOG  
**Next:** Integrate into PRD Section 3
