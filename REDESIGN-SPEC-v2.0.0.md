# Divine Link — Redesign Specification v2.0.0

> Source of truth for the major UI redesign. Derived from design sessions and `redesign.pen`.
> Current version: **1.3.10** (build 16) → Target: **2.0.0**
> This is a **major version** — full UI overhaul from compact single-window to sidebar-based multi-screen architecture.

---

## 1. Window & Layout Model

### Default Window Size
- **Both free and premium**: 1000px wide default on first launch
- Height: 950px (macOS standard comfortable height)

### Minimum Window Sizes

| Tier | Min Width | Min Height | Rationale |
|------|-----------|------------|-----------|
| **Free** | 1000px | TBD | Ads require their full allocated space — no compression allowed |
| **Premium** | ~600px | TBD | No ads, sidebar can collapse; content area needs ~548px minimum |

- **Free users cannot shrink below the ad-safe minimum.** The right ad sidebar and bottom ad banner must always render at full size. If the user wants a smaller window, they upgrade to premium.
- **Premium users can shrink further** once they pass below the free minimum threshold, because the ad rail and bottom banner are removed entirely.
- This constraint must be enforced in code via `NSWindow.minSize` conditional on subscription tier.

### CRITICAL RULE: Never Shrink Ad Space
Ad banners (right sidebar + bottom banner) are **never** compressed, cropped, or hidden on the free tier. The ad space is sacred. The window minimum enforces this. Premium is the path to a smaller window.

---

## 2. Sidebar Navigation (Slack-Style)

### Expanded State (default on 1000px+)
- Width: **220px** (260px on Settings screens with sub-nav)
- Shows: Brand mark + "Divine Link" text, nav items with icons + labels, plan card at bottom
- Collapse icon: `panel-left-close` (lucide) in sidebar header

### Collapsed State
- Width: **~52px**
- Shows: Brand mark only (no text), nav icons centered (no labels), plan card hidden
- Expand icon: `panel-left-open` (lucide)
- Tooltip on hover for each nav icon

### Behavior
- Toggle via the `panel-left-close` / `panel-left-open` icon already designed in all screens
- State persists across sessions (UserDefaults)
- Sidebar collapse is available to both free and premium users
- On free tier: collapsing sidebar gives more room to the content area, but the ad sidebar stays fixed

---

## 3. Ad Display Rules (Free Tier)

### Right Ad Sidebar
- Width: ~200px (fixed, never shrinks)
- Positioned to the right of the main content area
- Shows dynamic ad inventory (square, portrait, mixed layouts)
- "Remove Ads" button always visible at bottom of ad sidebar

### Bottom Ad Banner
- Full width below the main content area
- Fixed height (~58px as designed in Screen 01)
- Shows banner ad with icon + text

### Where Ads Appear
**Every screen** a free user sees has the right ad sidebar + bottom banner. This includes:
- Listen view (Screen 01 — already designed with ads)
- History view
- Pastor Profiles
- Settings (all sub-screens)
- Paywall (may omit ads since user is already considering upgrade)

### Where Ads Do NOT Appear
- Auth / Login (Screen 05) — pre-authentication, no ads
- Onboarding / First Run (Screen 06) — first impression, no ads
- Premium tier (Screen 02 and all premium equivalents) — ads removed entirely

---

## 4. Screen Inventory (15 Screens)

### Core Application Screens

| # | Screen | Free Ads | Notes |
|---|--------|----------|-------|
| 01 | Listen (FREE Tier) | Yes | Main scripture detection view with ads |
| 02 | Listen (PREMIUM Tier) | No | Clean layout, push-to-ProPresenter |
| 03 | Session History + Detail | Tier-dependent | 3-panel: session list, detail, verse timeline |
| 04 | Settings · ProPresenter | Tier-dependent | Connection config, push behavior, shortcuts |
| 05 | Auth / Login | No | Split layout: blue hero left, form right, Apple/Google SSO |
| 06 | Onboarding (First Run) | No | Stepper: Connect ProPresenter → Pick Translation → Test Mic |
| 07 | Pastor Profiles | Tier-dependent | Pastor list + detail: voice model, accuracy, sessions |
| 08 | Paywall / Upgrade | No | Monthly/Annual/Lifetime pricing, feature comparison |

### Settings Sub-Screens

| # | Screen | Free Ads | Notes |
|---|--------|----------|-------|
| 09 | Settings · Account | Tier-dependent | Profile, church/org, subscription, 2FA, active sessions |
| 10 | Settings · Audio | Tier-dependent | Input source, live meter, noise suppression, transcription engine |
| 11 | Settings · Detection | Tier-dependent | Confidence threshold, translation priority, matching rules, ignore list |
| 12 | Settings · Display | Tier-dependent | Light/Dark/System theme, scripture card preview |
| 13 | Settings · Admin | Tier-dependent | Team members, roles & permissions, recent activity, advanced |
| 14 | Settings · Updates | Tier-dependent | Sparkle channels (Stable/Beta/Nightly), auto-update, release notes |
| 15 | Settings · About | Tier-dependent | App info, resources, credits, Psalm 119:105 |

---

## 5. Navigation Model

### Title Bar (macOS Chrome)
All screens share a consistent macOS-style title bar:
- Traffic lights (close/minimize/fullscreen)
- Navigation context (varies by screen):
  - Listen screens: "Listen" tab label
  - History: Back/forward arrows + "Listen > History" breadcrumb + active dot
  - Settings: "Settings > [Sub-page]" breadcrumb
- Centered app title: "Divine Link — [Context]"

### Sidebar Navigation (Primary)
Persistent across all authenticated screens:
- **Listen** (headphones icon) — main detection view
- **History** (history icon) — session history
- **Pastors** (users icon) — pastor profile management
- **Settings** (settings icon) — all settings

### Settings Sub-Navigation
When in Settings, a secondary nav section appears below the primary nav:
- Account, Audio, Detection, ProPresenter, Display, Admin, Updates, About
- Active item highlighted with blue left border + background

### Plan Card (Sidebar Footer)
- Free: Shows "FREE" badge, email, gold "Upgrade to Premium" button
- Premium: Shows crown "Premium" badge, email, renewal date + "Manage" link

---

## 6. Content Area Layout by Screen Width

### At 1000px (Default — Both Tiers)

**Free:**
```
[Sidebar 220px] [Content ~522px] [Ad Rail ~200px]
[              Bottom Ad Banner 1000px              ]
```

**Premium:**
```
[Sidebar 220px] [Content ~780px]
```

### At 1000px with Collapsed Sidebar

**Free:**
```
[52px] [Content ~690px] [Ad Rail ~200px]
[           Bottom Ad Banner 1000px           ]
```

**Premium:**
```
[52px] [Content ~948px]
```

### Below 1000px (Premium Only)
Premium users can shrink the window. Content area adjusts responsively.
Free users are locked at 1000px minimum — the window won't shrink further.

---

## 7. Design System Tokens

### Typography
- Font: Inter
- Weights: 400 (normal), 500 (medium), 600 (semibold), 700 (bold)
- Scale: 10px (micro labels), 11px (captions), 12px (small), 13px (body), 14px (body large), 15px (subhead), 18-24px (headings)

### Colors
- Primary blue: #2563EB
- Brand gold: #D4AF37
- Text primary: #111827 / #1F2937
- Text secondary: #374151 / #4B5563
- Text tertiary: #6B7280
- Surface: #FAFAFA / #F4F5F8
- Border: #E5E7EB / #E2E8F0
- Active nav bg: #EFF6FF with #2563EB left border
- Premium badge: #FEF3C7 bg, #92400E text, #D4AF37 crown

### Spacing
- Sidebar padding: 14px horizontal, 12px vertical
- Content padding: varies (16-32px)
- Nav item padding: 8-10px vertical, 10-12px horizontal
- Card padding: 12-16px
- Gap between nav items: 2px
- Gap between cards/sections: 12-20px

### Corner Radius
- Window: 12px
- Cards: 8-14px
- Nav items: 6-8px
- Badges: 10px / 999px (pill)
- Buttons: 6-8px

### Icons
- Library: Lucide
- Nav icon size: 16px
- Brand mark: 18-28px (varies by context)

---

## 8. Responsive Behavior Summary

```
Window resize event
  ├─ Is user Premium?
  │   ├─ YES → Allow resize down to ~600px min width
  │   │         Sidebar collapsible to 52px
  │   │         Content area is full width (no ads)
  │   └─ NO (Free) → Enforce 1000px min width
  │                    Right ad sidebar always visible (200px)
  │                    Bottom ad banner always visible
  │                    Sidebar still collapsible to 52px
  │                    Content area adjusts between sidebar and ad rail
  └─ Sidebar toggle
      ├─ Expanded: 220px (260px in Settings)
      └─ Collapsed: 52px icons-only
```

---

## 9. Implementation Notes

### NSWindow Configuration
```swift
// Pseudo-code for window constraints
if subscriptionTier == .free {
    window.minSize = NSSize(width: 1000, height: 700)
} else {
    window.minSize = NSSize(width: 600, height: 500)
}
// Update on subscription change
```

### Sidebar State Persistence
- Store collapsed/expanded state in UserDefaults
- Key: `sidebarCollapsed` (Bool)
- Default: `false` (expanded)

### Ad Layout Contract
- AdSidebarView: fixed 200px width, never hidden on free
- AdBannerView: fixed ~58px height, full width, never hidden on free
- Both removed entirely (not hidden) when premium

---

## 10. Design File Reference
- **Pencil file**: `/Users/ayoogunrekun/Projects/Divine Link/redesign.pen`
- **15 screens** as of 2026-04-22
- All screens at 1400px width in design file (design-time canvas size, not runtime)

---

## 11. Transcript Correction + Learning Loop (NEW REQUIRED BEHAVIOUR)

### Objective
All words/sentences heard during a service must remain available in one continuous transcript stream so users can scroll back at any time, correct misheard words, and feed those corrections into the app's internal learning store.

### UX Requirements (Screens 01 and 02)
- Transcript panel is a **single continuous vertical stream** for the current service session.
- User can **scroll up/down freely** without losing historic transcript content.
- Provide `Auto-scroll` toggle:
  - ON: follows live incoming transcript
  - OFF: preserves manual scroll position while new text continues appending in background
- Provide `Jump to Live` action when user is not at the bottom of the stream.
- Keep `Select words to edit` interaction in the transcript area for both Free and Premium layouts.

### Correction Interaction
- User selects a misheard word/phrase directly in transcript.
- Open correction UI (current popover/dialog pattern is acceptable for v2).
- Fields:
  - `Heard` (read-only original text)
  - `Replace with` (editable corrected text)
- On Apply:
  - Replace transcript text in-session immediately
  - Mark corrected token visually (subtle indicator)
  - Queue correction for learning store write

### Internal Learning Store Requirements
- Every accepted correction writes a structured record to the internal DB for future use.
- Minimum fields:
  - `heard_text`
  - `corrected_text`
  - `context_before`
  - `context_after`
  - `translation`
  - `service_id`
  - `timestamp`
  - `pastor_profile_id` (if available)
  - `source = manual_correction`
- Deduplicate exact repeats and track occurrence count.
- Future transcription/detection passes can consult this store as a soft bias (not blind replacement).

### Performance and Stability
- Transcript rendering should be virtualised/chunked for long sessions.
- Maintain smooth scrolling and editing for extended services.
- Corrections must not block live transcript ingestion.

### Tier Behaviour
- This correction + learning loop is a **core quality feature** and should be available on both Free and Premium tiers.
- Free/Premium differences remain visual/layout/ad-related only.

### Pencil Design Annotation Guidance
When updating `redesign.pen`, add callouts on Listen screens (01 Free, 02 Premium):
1. `Infinite transcript stream`
2. `Auto-scroll toggle + Jump to Live`
3. `Select word/phrase to correct`
4. `Apply correction -> saved to learning DB`

---

## 12. What This Spec Does NOT Cover (Yet)
- Exact free-tier minimum height
- Tablet/iPad layout (macOS only for now)
- Animation/transition specs between screens
- Accessibility audit details
- Dark mode variants (Screen 12 shows theme picker but full dark palette TBD)
- Onboarding flow complete step content (Screen 06 shows step 2 of 3)
- Error states and empty states for each screen
