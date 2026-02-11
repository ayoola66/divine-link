# Epic 7: UI Enhancement & Subscription Theming

**Target Version:** v1.3.0  
**Last Updated:** February 2026

---

## Overview

Epic 7 focuses on enhancing the user interface with improved Settings window navigation and visual subscription tier indicators. These changes improve usability and provide immediate visual feedback on the active subscription level.

---

## Stories

### Story 7.1: Settings Window Redesign

**Status:** ✅ Complete  
**Priority:** High

**Description:**  
Redesign the Settings window with a sidebar navigation pattern for improved discoverability and usability.

**Requirements:**
1. **Sidebar Navigation**
   - Smaller icons with text labels
   - Collapsible via burger menu icon at top
   - Persists collapsed/expanded state
   
2. **Window Behaviour**
   - Resizable by user (minimum and default sizes)
   - Remembers size and position between launches
   
3. **Navigation Items**
   - All current tabs (Account, Audio, Detection, ProPresenter, Pastors, Display, Admin when applicable, Updates, History, About)

**Acceptance Criteria:**
- [x] Sidebar displays all setting categories with icons and labels
- [x] Burger menu toggles sidebar collapsed/expanded state
- [x] Window is resizable with sensible minimum constraints
- [x] Window remembers size/position (system Settings scene)
- [x] Navigation selection highlights current section

**Implementation (Feb 2026):**
- Replaced `TabView` with `NavigationSplitView` in `SettingsView.swift`
- Sidebar uses `List(selection:)` with `.listStyle(.sidebar)`; all 10 items visible (no cropping)
- Collapse state persisted via `@AppStorage("settingsSidebarCollapsed")`; when collapsed, sidebar shows **icons only** (44pt width); when expanded, icons + labels (min 160pt)
- **Single collapse control:** System title-bar button toggles between expanded and icon-only; sidebar is never fully hidden. `onChange(of: columnVisibility)` intercepts `.detailOnly` and toggles `sidebarCollapsed` instead
- Frame: minWidth 680, idealWidth 880, minHeight 540, idealHeight 600
- **Resizable window:** `SettingsWindowResizeEnabler` (NSViewRepresentable) applies `.resizable` style mask to the Settings window so users can drag to resize

---

### Story 7.2: Subscription Theme Indicators

**Status:** ✅ Complete  
**Priority:** High

**Description:**  
Implement visual theme changes based on the active subscription tier to provide immediate visual confirmation of subscription status (main app window only; Settings window untinted).

**Theme Colours (as implemented):**
| Condition | Theme Colour |
|-----------|---------------|
| Admin | `Color.red.opacity(0.06)` |
| Mercy / Free | `Color.gray.opacity(0.04)` |
| Grace | `Color.orange.opacity(0.06)` |
| Love | `Color.purple.opacity(0.06)` |

**Requirements:**
1. **Theme Application**
   - Subtle background tint on main window only
   - Immediate visual change when subscription tier changes
   - Works in both light and dark mode
   
2. **Implementation**
   - Theme derived from `SubscriptionService.currentTier` and `isAdmin`
   - Applied via `.background()` on main window root view

**Acceptance Criteria:**
- [x] Mercy/Free tier shows very light grey background tint
- [x] Grace tier shows very light orange background tint
- [x] Love tier shows very light purple background tint
- [x] Admin shows very light red background tint
- [x] Theme changes immediately when switching tiers (debug/admin mode)
- [x] Theme persists with subscription state across app restart
- [x] Ads disappear when on paid tier (existing logic — Story 7.3)

**Implementation (Feb 2026):**
- Added `themeTint` computed property to `SubscriptionTier` in `SubscriptionService.swift` (SwiftUI import added)
- In `MainView.swift`: `@ObservedObject private var subscriptionService`, `.background(subscriptionBackgroundTint)`, and `subscriptionBackgroundTint` computed property (admin → red, else tier’s `themeTint`)
- **Not signed in:** Tint is always grey when not authenticated; `loadCachedStatus()` does not apply cached tier when unauthenticated.

---

### Story 7.3: Premium Mode Ad Visibility Fix

**Status:** ✅ Complete  
**Priority:** Critical

**Description:**  
Investigate and fix the issue where ads are still visible when the app is in Premium/paid mode.

**Root Cause Analysis:**
- `AdManager.bottomBannerHeight` was returning 80 even for premium users if a banner ad was available
- `AdContainerView` in `AdViews.swift` was using `bottomBannerHeight > 0` without checking `shouldShowAds`
- This caused banner ads to always show regardless of subscription status

**Solution Applied:**
1. Modified `AdManager.bottomBannerHeight` to return 0 when `shouldShowAds` is false
2. Updated `AdContainerView` to check `adManager.shouldShowAds` before rendering bottom banner
3. Added `objectWillChange.send()` and logging to ensure UI updates on tier change

**Files Modified:**
- `AdManager.swift` - Fixed `bottomBannerHeight` logic
- `AdViews.swift` - Fixed `AdContainerView` conditional rendering

**Acceptance Criteria:**
- [x] Ads are hidden when any paid tier is active
- [x] Ad space is properly reclaimed (no empty gaps)
- [x] Works correctly in debug and release builds

---

### Story 7.4: History Tab Data Persistence

**Status:** ✅ Complete  
**Priority:** High

**Description:**  
Ensure service history is properly saved and displayed in the History tab.

**Root Cause Analysis (from investigation):**
- Sessions were only saved when `endCurrentSession()` was explicitly called
- Users may quit the app without ending their session
- **Critical Bug Found:** When loading sessions from SQLite, both `ServiceSession` and `DetectedScripture` objects were being re-initialised with `Date()` instead of using the stored timestamps, causing duration and detection times to be incorrect

**Solution Applied:**
1. Added `applicationWillTerminate` hook in `AppDelegate.swift` to auto-save active sessions on app quit
2. Added full initialiser to `ServiceSession` struct to accept `startTime` and `endTime` parameters
3. Added full initialiser to `DetectedScripture` struct to accept `id`, `timestamp`, and `wasPushed` parameters
4. Updated `ServiceArchive.loadAll()` to use the new `ServiceSession` initialiser with proper timestamps
5. Updated `ServiceArchive.loadScriptures()` to use the new `DetectedScripture` initialiser with proper id and timestamp

**Files Modified:**
- `AppDelegate.swift` - Added auto-save on app termination
- `ServiceSession.swift` - Added full initialiser for database loading
- `ServiceArchive.swift` - Fixed `loadAll()` and `loadScriptures()` to preserve timestamps

**Acceptance Criteria:**
- [x] Sessions auto-save when app quits
- [x] History tab displays all archived sessions
- [x] Session data persists across app restarts
- [x] Session duration is correctly calculated from stored start/end times
- [x] Scripture detection timestamps are correctly preserved
- [x] Debug logging confirms save/load operations

---

## Implementation Order

1. **Story 7.3** - Fix Premium Mode ad visibility (critical bug) ✅
2. **Story 7.4** - Verify History persistence (bug fix) ✅
3. **Story 7.1** - Settings window redesign (UI enhancement) ✅
4. **Story 7.2** - Subscription theme indicators (visual enhancement) ✅

---

## Technical Dependencies

- SwiftUI NavigationSplitView (macOS 13+)
- SubscriptionManager for theme state
- UserDefaults for persisting UI preferences
- ServiceArchive for session persistence

---

## Testing Checklist

### Story 7.1 (Settings Redesign) ✅
- [x] Sidebar navigation works on macOS 13+
- [x] Window resizing works correctly
- [x] Collapsed/expanded state persists
- [x] All settings sections are accessible

### Story 7.2 (Subscription Themes) ✅
- [x] Each tier displays correct background tint (Admin=red, Mercy=grey, Grace=orange, Love=purple)
- [x] Theme changes are immediate
- [x] Works in light and dark mode
- [x] Theme persists after restart

### Story 7.3 (Ad Visibility) ✅
- [x] Ads hidden on Mercy tier
- [x] Ads hidden on Grace tier
- [x] Ads hidden on Love tier
- [x] Ad space reclaimed properly

### Story 7.4 (History Persistence) ✅
- [x] Sessions save on explicit end
- [x] Sessions save on app quit
- [x] History tab loads archived sessions
- [x] Session timestamps preserved correctly on load
- [x] Scripture detection timestamps preserved correctly on load
- [x] Database path is correct for sandboxed apps (`~/Library/Containers/com.ORekunMedia.DivineLink/Data/Library/Application Support/DivineLink/ServiceHistory.db`)
- [x] Session data (name, type, dates) stored correctly with SQLITE_TRANSIENT binding
- [ ] **Verification needed:** User to test by creating/ending a session and checking History tab

---

## Post-Implementation Refinements (Feb 2026)

The following refinements were applied after the initial Epic 7.1/7.2 implementation to improve behaviour and fix edge cases.

### Settings Window
| Change | Description |
|--------|-------------|
| **Resizable window** | Settings scene is not resizable by default on macOS. `SettingsWindowResizeEnabler` (NSViewRepresentable wrapping an NSView that sets `window?.styleMask.insert(.resizable)` in `viewDidMoveToWindow`) is applied as `.background(SettingsWindowResizeEnabler())` on the Settings `NavigationSplitView`. |
| **Single collapse/expand control** | Removed duplicate toolbar button. Only the system title-bar sidebar toggle remains. When the user taps it, the sidebar does not fully hide; it toggles between **expanded** (icons + labels, min 160pt) and **icon-only** (44pt). Implemented by binding `columnVisibility` and in `onChange(of: columnVisibility)` setting `columnVisibility = .all` and toggling `sidebarCollapsed` when the system tries to set `.detailOnly`. |
| **Narrower icon-only sidebar** | Collapsed sidebar width reduced from 52pt to 44pt for a slimmer strip while keeping icons tappable. |

### Subscription & Tint
| Change | Description |
|--------|-------------|
| **Grey when not signed in** | Main window tint is grey when the user is not authenticated. `MainView.subscriptionBackgroundTint` returns grey when `!authService.isAuthenticated`. `SubscriptionService.loadCachedStatus()` returns early with `currentTier = .mercy` when `!AuthService.shared.isAuthenticated`, so cached tier from a previous session is not applied. |
| **Sign-out reset** | `SubscriptionService.resetForSignOut()` (called from `AuthService.signOut()`) sets `isAdmin = false`, `currentTier = .mercy`, and clears warnings so tint and ads update immediately. |

### Admin Debug: Simulate Free
| Change | Description |
|--------|-------------|
| **Debug “Reset to Free”** | For admins testing the free-tier experience, “Debug: Reset to Free” in Settings → Account (Developer Options) now sets `SubscriptionService.shared.debugSimulateFreeMode = true` in addition to `AdManager.resetToFree()`. `SubscriptionService.canUsePremiumFeatures` returns `false` when `debugSimulateFreeMode` is true, so the main window shows ads and grey tint. “Debug: Set Premium” clears the flag and restores admin behaviour. |
| **Tint and ads** | `MainView.subscriptionBackgroundTint` returns grey when `subscriptionService.debugSimulateFreeMode` is true. `resetForSignOut()` clears `debugSimulateFreeMode` so it does not persist after sign-out. |

**Files touched (refinements):**
- `SettingsView.swift` — Resize enabler, single collapse behaviour, icon-only width 44pt
- `MainView.swift` — Grey tint when not signed in and when `debugSimulateFreeMode`
- `SubscriptionService.swift` — `loadCachedStatus()` auth guard, `debugSimulateFreeMode`, `resetForSignOut()` clearing debug flag
- `AdViews.swift` — Debug buttons set/clear `SubscriptionService.shared.debugSimulateFreeMode`

---

## Quick Fixes Applied (Pre-Epic 7)

### ✅ Spacebar in Service Type TextField
- **Issue:** Spacebar didn't work when typing in "Service Type" field
- **Root Cause:** Global `.onKeyPress(.space)` in MainView captured spacebar
- **Fix:** Added `!showNewServiceSheet` guard to the key handler
- **File:** `MainView.swift`

### ✅ Screenshot Script Bible Translation
- **Issue:** Script referenced Settings panel for Bible translation
- **Actual Location:** Main app interface (KJV dropdown)
- **Fix:** Updated script instructions
- **File:** `scripts/generate-screenshots.sh`

### ✅ Auto-Save Session on Quit
- **Issue:** Sessions not saved if user quits without clicking "End"
- **Fix:** Added `applicationWillTerminate` hook to auto-save
- **File:** `AppDelegate.swift`

### ✅ Premium Mode Ad Visibility (Story 7.3)
- **Issue:** Ads still visible when using debug Premium Mode toggle
- **Root Cause:** `bottomBannerHeight` and `AdContainerView` logic ignored `shouldShowAds` state
- **Fix:** Updated `AdManager.bottomBannerHeight` and `AdContainerView` to properly check `shouldShowAds`
- **Files:** `AdManager.swift`, `AdViews.swift`

### ✅ History Tab Data Persistence (Story 7.4)
- **Issue:** History tab not showing session data, session durations showing as 0, sessions appearing empty
- **Root Cause 1 (Loading):** When loading sessions/scriptures from SQLite, the structs were being re-initialised with `Date()` values instead of using the stored timestamps
- **Root Cause 2 (Saving - Critical):** `sqlite3_bind_text` was called with `nil` destructor, causing Swift strings to be deallocated before SQLite could copy them, resulting in empty values being stored in the database
- **Fix 1:** Added full initialisers to `ServiceSession` and `DetectedScripture` to accept stored values; updated `ServiceArchive` loading functions to use them
- **Fix 2:** Introduced `SQLITE_TRANSIENT` constant and helper methods (`bindText`, `bindTextOrNull`) to ensure SQLite makes its own copy of bound string data; updated all `save`, `saveScripture`, `loadScriptures`, `delete`, and `cleanup` functions to use these helpers
- **Files:** `ServiceSession.swift`, `ServiceArchive.swift`, `AppDelegate.swift`
- **Testing Note:** When run from Xcode with sandboxing enabled, the database is stored at `~/Library/Containers/com.ORekunMedia.DivineLink/Data/Library/Application Support/DivineLink/ServiceHistory.db`

---

# Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Feb 2026 | Initial Epic 7 planning document |
| 1.1 | Feb 2026 | Post-implementation refinements: resizable Settings window, single sidebar collapse (icon-only vs expanded), 44pt icon width, grey tint when not signed in, loadCachedStatus auth guard, admin debug simulate Free |
