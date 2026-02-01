# Ad Layout Improvements

**Date:** February 1, 2026  
**Status:** ✅ Implemented  
**Priority:** Feature Enhancement

---

## Summary

Updated the ad sidebar and banner layout to dynamically adapt based on available ads and window size, with improved default layouts and guaranteed banner display.

---

## Changes Implemented

### 1. ✅ Dynamic Sidebar Layout Based on Window Size

**File:** `DivineLink/DivineLink/Features/Ads/AdViews.swift`

**New Layout Logic:**
- **Default (2 ads):**
  - 3 squares (if no portrait ad available)
  - OR 1 square + 1 portrait (if portrait ad available)
  
- **Stretched Window (3 ads):**
  - 2 squares + 1 portrait (when window height allows and portrait ad available)

**Implementation:**
- Added `GeometryReader` to detect available sidebar height
- Calculates if space allows for 3 ads (2 squares + 1 portrait)
- Dynamically switches between layouts based on:
  - Available ads (squares and portrait)
  - Window height (space calculation)
  - Priority: Portrait ads always prioritised when available

**Code Changes:**
- Added `layout(availableHeight:)` function that calculates optimal layout
- Added new layout cases: `.twoSquaresOnePortrait`, `.oneSquareOnePortrait`, `.portraitOnly`
- Updated `body` to use `GeometryReader` for dynamic sizing

---

### 2. ✅ Banner Always Shows When Ad Available

**Files:**
- `DivineLink/DivineLink/Features/Ads/AdViews.swift`
- `DivineLink/DivineLink/Features/Ads/AdManager.swift`

**Change:**
- Banner ad now always displays when available, regardless of subscription status
- Previously only showed if `shouldShowAds` was true
- Now checks if banner ad exists in `DynamicAdService`

**Implementation:**
- Updated `bottomBannerHeight` in `AdManager` to check for banner ad existence
- Updated `AdContainerView` to always render banner view when height > 0
- Updated `AdBannerView` to show banner ad if available, even for premium users

**Code Changes:**
```swift
// AdManager.swift
var bottomBannerHeight: CGFloat {
    let hasBannerAd = DynamicAdService.shared.bannerAd != nil
    return (shouldShowAds || hasBannerAd) ? 80 : 0
}

// AdContainerView
if adManager.bottomBannerHeight > 0 {
    AdBannerView(slot: .bottomBanner)
        .frame(height: adManager.bottomBannerHeight)
}
```

---

## Layout Priority Logic

### Sidebar Layout Priority (in order):

1. **2 squares + 1 portrait** (if space allows and portrait available)
   - Requires: 2+ square ads, 1 portrait ad, sufficient window height
   - Height check: ~470px minimum (2 squares + portrait + spacing + button)

2. **3 squares** (default when no portrait)
   - Requires: 3+ square ads
   - Default fallback when no portrait ad available

3. **1 square + 1 portrait** (default when portrait available)
   - Requires: 1+ square ads, 1 portrait ad
   - Default when portrait ad exists but window not stretched

4. **Portrait only** (fallback)
   - Requires: 1 portrait ad, no square ads
   - Shows portrait + square placeholder

5. **Squares + portrait placeholder** (fallback)
   - Requires: Square ads available, no portrait ad
   - Shows squares + portrait placeholder

---

## Height Calculation

**Estimated Heights:**
- Square ad: ~133px
- Portrait ad: ~200px
- Spacing between ads: 8px each
- Remove Ads button: ~50px
- Padding (top + bottom): ~20px

**Minimum Height for 3 Ads:**
- 2 squares: 266px
- 1 portrait: 200px
- Spacing (3 gaps): 24px
- Button: 50px
- Padding: 20px
- **Total: ~560px minimum**

**Minimum Height for 2 Ads:**
- 1 square: 133px
- 1 portrait: 200px
- Spacing (2 gaps): 16px
- Button: 50px
- Padding: 20px
- **Total: ~419px minimum**

---

## Testing Recommendations

### Test Scenarios:

1. **Default Window Size:**
   - Should show: 3 squares OR 1 square + 1 portrait
   - Verify correct layout based on available ads

2. **Stretched Window:**
   - Stretch window vertically
   - Should show: 2 squares + 1 portrait (if portrait available and space allows)
   - Verify dynamic switching

3. **Banner Ad Display:**
   - With banner ad available: Should always show
   - Without banner ad: Should show placeholder if `shouldShowAds` is true
   - Premium users: Should still see banner if ad available

4. **Ad Combinations:**
   - Test with: 0 squares, 1 square, 2 squares, 3+ squares
   - Test with: Portrait ad available / not available
   - Test with: Banner ad available / not available

---

## Files Modified

1. **DivineLink/DivineLink/Features/Ads/AdViews.swift**
   - Updated `AdSidebarView` with dynamic layout logic
   - Added `GeometryReader` for window size detection
   - Updated layout enum with new cases
   - Updated `AdContainerView` banner display logic

2. **DivineLink/DivineLink/Features/Ads/AdManager.swift**
   - Updated `bottomBannerHeight` to check for banner ad existence

---

## Expected Behaviour

### Sidebar:
- **Default:** Shows 3 squares OR 1 square + 1 portrait (2 ads total)
- **Stretched:** Shows 2 squares + 1 portrait (3 ads total) when space allows
- **Dynamic:** Automatically adjusts when window is resized

### Banner:
- **Always shows** if banner ad is available
- **Shows placeholder** if no banner ad but ads should be shown
- **Hidden** only if no banner ad AND premium user

---

## Notes

- Layout calculations are conservative (may show 2 ads even when 3 could fit)
- Portrait ads are always prioritised when available
- Window resizing triggers layout recalculation automatically
- Banner ad display is independent of sidebar ad display logic
