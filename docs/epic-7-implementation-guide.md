# Epic 7: UI Enhancement & Subscription Theming

**Target Version:** v1.3.0  
**Last Updated:** February 2026

---

## Overview

Epic 7 focuses on enhancing the user interface with improved Settings window navigation and visual subscription tier indicators. These changes improve usability and provide immediate visual feedback on the active subscription level.

---

## Stories

### Story 7.1: Settings Window Redesign

**Status:** 📋 Planned  
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
   - ProPresenter Connection
   - Audio Settings
   - Bible Settings
   - Subscription/Premium
   - Service History
   - About/Support

**Acceptance Criteria:**
- [ ] Sidebar displays all setting categories with icons and labels
- [ ] Burger menu toggles sidebar collapsed/expanded state
- [ ] Window is resizable with sensible minimum constraints
- [ ] Window remembers size/position (using UserDefaults)
- [ ] Navigation selection highlights current section

**Technical Notes:**
- Use `NavigationSplitView` or custom sidebar implementation
- Store sidebar state in UserDefaults
- Use `NSWindow` delegate for saving window frame

---

### Story 7.2: Subscription Theme Indicators

**Status:** 📋 Planned  
**Priority:** High

**Description:**  
Implement visual theme changes based on the active subscription tier to provide immediate visual confirmation of subscription status.

**Theme Colours:**
| Tier | Theme Colour | Description |
|------|--------------|-------------|
| Free | Default (no tint) | Standard system appearance |
| Mercy | Very light red | `Color.red.opacity(0.05)` or similar |
| Grace | Very light blue | `Color.blue.opacity(0.05)` or similar |
| Love | White/light purple | `Color.purple.opacity(0.03)` or plain white |

**Requirements:**
1. **Theme Application**
   - Subtle background tint across the entire app
   - Immediate visual change when subscription tier changes
   - Works in both light and dark mode
   
2. **Implementation**
   - Theme state managed by SubscriptionManager
   - Applied via environment or preference key
   - Consistent across all windows (Main, Settings)

**Acceptance Criteria:**
- [ ] Free tier shows default appearance (no tint)
- [ ] Mercy tier shows very light red background tint
- [ ] Grace tier shows very light blue background tint  
- [ ] Love tier shows white or very light purple tint
- [ ] Theme changes immediately when switching tiers (debug mode)
- [ ] Theme persists across app restart
- [ ] Ads disappear when on paid tier (verify existing logic)

**Technical Notes:**
- Create `SubscriptionTheme` enum with associated colours
- Apply via `.background()` modifier on root view
- Consider using `Color.accentColor` for controls

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

1. **Story 7.3** - Fix Premium Mode ad visibility (critical bug)
2. **Story 7.4** - Verify History persistence (bug fix)
3. **Story 7.1** - Settings window redesign (UI enhancement)
4. **Story 7.2** - Subscription theme indicators (visual enhancement)

---

## Technical Dependencies

- SwiftUI NavigationSplitView (macOS 13+)
- SubscriptionManager for theme state
- UserDefaults for persisting UI preferences
- ServiceArchive for session persistence

---

## Testing Checklist

### Story 7.1 (Settings Redesign)
- [ ] Sidebar navigation works on macOS 13+
- [ ] Window resizing works correctly
- [ ] Collapsed/expanded state persists
- [ ] All settings sections are accessible

### Story 7.2 (Subscription Themes)
- [ ] Each tier displays correct background tint
- [ ] Theme changes are immediate
- [ ] Works in light and dark mode
- [ ] Theme persists after restart

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
