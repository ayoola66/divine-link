# Divine Link Epic 8: Technical Specification
**Document Type:** Developer Handoff Specification
**Version:** 1.0 - Production Ready
**Date:** February 18, 2026
**Based on:** Final Gemini/Figma mockups

---

## 1. Window Specifications

### Main Window
- **Default Size:** 1440px (W) × 900px (H)
- **Minimum Size:** 1024px (W) × 768px (H)
- **Maximum Size:** Unlimited (responsive)
- **Window Style:** Native macOS with traffic lights (red/yellow/green)
- **Background:** Gradient from #F9FAFB to #FFFFFF
- **Resizable:** Yes (all components responsive)

### Layout Split (Free Tier)
- **Main Content Area:** 1040px width (72% of window)
- **Ad Sidebar:** 200px width (14% of window)
- **Gap between:** 0px (Ad sidebar starts immediately after content)
- **Bottom Banner:** 60px height, full width

### Layout (Premium Tier)
- **Main Content Area:** Full width minus margins
- **Ad Sidebar:** Hidden/Collapsed
- **Bottom Banner:** Hidden/Collapsed

---

## 2. Header Bar

### Dimensions
- **Height:** 60px
- **Horizontal Padding:** 24px left/right
- **Background:** White (#FFFFFF)
- **Bottom Border:** 1px solid #E5E7EB

### Components

#### Logo Section (Left)
- **Logo:** Circular gold icon, 48px × 48px
- **Logo Color:** Gold #D4AF37 with subtle gradient
- **Logo Style:** Circular with concentric rings or abstract pattern
- **Text:** "Divine Link" beside logo
  - Font: SF Pro Display, 18pt, Bold (700)
  - Color: #1F2937
  - Spacing: 12px gap from logo

#### Status Indicator (Center)
- **Text:** "Listening" or "Paused"
- **Font:** SF Pro, 14pt, Medium (500)
- **Color:** #6B7280
- **Blue Dot:** 8px diameter, #3B82F6
  - Animation: Pulse from opacity 0.3 to 1.0, 1.5s cycle, infinite
  - Position: 8px left of "Listening" text

#### Settings Icon (Right)
- **Icon:** Gear/cog (SF Symbol: gear)
- **Size:** 28px × 28px
- **Color:** #6B7280
- **Hover:** Scale 1.1, opacity 0.8, 150ms ease

---

## 3. Audio Control Bar

### Dimensions
- **Height:** 48px
- **Background:** White (#FFFFFF)
- **Border:** 1px solid #E5E7EB (all sides)
- **Border Radius:** 8px
- **Margin:** 16px horizontal, 12px top
- **Layout:** Flexbox, horizontal, equal spacing

### Components (5 elements, flex distribution)

#### 1. Audio Button
- **Width:** Flex: 1 (minimum 100px)
- **Height:** 36px
- **Icon:** 🎙️ Microphone (SF Symbol: mic.fill)
- **Text:** "Audio"
- **Font:** SF Pro, 14pt, Medium
- **Background:** White (#FFFFFF)
- **Border:** 1px solid #E5E7EB
- **Border Radius:** 6px
- **Hover:** Background #F9FAFB

#### 2. Speech Button (Active)
- **Width:** Flex: 1 (minimum 100px)
- **Height:** 36px
- **Icon:** 💬 Speech bubble (SF Symbol: message.fill)
- **Text:** "Speech"
- **Font:** SF Pro, 14pt, Medium
- **Background:** Blue #3B82F6 (when active)
- **Text Color:** White (when active)
- **Border:** None (when active)
- **Border Radius:** 6px
- **Inactive State:** Same as Audio button

#### 3. Bible Version Dropdown
- **Width:** Flex: 1 (minimum 120px)
- **Height:** 36px
- **Text:** "KJV ▼" (or selected version)
- **Font:** SF Pro, 14pt, Medium
- **Background:** White (#FFFFFF)
- **Border:** 1px solid #E5E7EB
- **Border Radius:** 6px
- **Dropdown Arrow:** SF Symbol: chevron.down
- **Hover:** Background #F9FAFB

#### 4. Detect Button
- **Width:** Flex: 1 (minimum 100px)
- **Height:** 36px
- **Icon:** 🔍 Magnifying glass (SF Symbol: magnifyingglass)
- **Text:** "Detect"
- **Font:** SF Pro, 14pt, Medium
- **Background:** Light gray (#F3F4F6)
- **Border:** 1px solid #E5E7EB
- **Border Radius:** 6px
- **Hover:** Background #E5E7EB

#### 5. Audio Level Meter
- **Width:** Flex: 1 (minimum 140px, maximum 200px)
- **Height:** 36px
- **Background:** Dark gray (#2D3748)
- **Border Radius:** 6px
- **Padding:** 6px horizontal

**Meter Bars:**
- **Count:** 8 vertical bars
- **Bar Width:** 8px each
- **Bar Height:** 24px (full height)
- **Gap:** 4px between bars
- **Inactive Color:** #4A5568 (dark gray)
- **Active Colors:** Gradient
  - Bars 1-4: Green #10B981
  - Bars 5-6: Yellow #F59E0B
  - Bars 7-8: Red #EF4444
- **Animation:** Bars light up from left to right based on audio level
- **Update Rate:** 60fps (smooth real-time)

**Spacing between all buttons:** 12px gap

---

## 4. Live Transcription Card

### Dimensions
- **Height:** ~200px (25% of content area, flexible)
- **Margin:** 16px horizontal, 16px top
- **Padding:** 24px all sides
- **Border Radius:** 12px

### Style
- **Background:** Light gray (#F9FAFB)
- **Border:** None
- **Shadow:** 0px 2px 8px rgba(0, 0, 0, 0.05)

### Header
- **Text:** "Live Transcription"
- **Font:** SF Pro, 14pt, Medium (500)
- **Color:** #6B7280
- **Margin Bottom:** 12px

### Content Area
- **Font:** SF Mono, 13pt, Regular (400)
- **Color:** #374151
- **Line Height:** 1.6
- **Overflow:** Scroll (auto-scroll to bottom)
- **Max Height:** 160px
- **Scrollbar:** macOS native (thin, auto-hide)

### Sample Text
```
...in all things God works for the good of those who love him,
who have been called according to his purpose. Romans 8:28.
And we know that in all things God...
```

---

## 5. Pending Scripture Card (PRIMARY FOCUS)

### Dimensions
- **Height:** ~320px (40% of content area, flexible)
- **Margin:** 8px horizontal, 16px vertical
- **Padding:** 32px all sides
- **Border Radius:** 16px

### Style
- **Background:** White (#FFFFFF)
- **Border:** 3px solid Gold (#D4AF37)
- **Shadow:** 0px 4px 20px rgba(212, 175, 55, 0.2) - gold glow effect

### Header Section (Top)
**Left Badge:**
- **Text:** "Detected Scripture"
- **Background:** Gold #D4AF37
- **Text Color:** White (#FFFFFF)
- **Font:** SF Pro, 12pt, Semibold (600)
- **Padding:** 6px 12px
- **Border Radius:** 6px

**Right Badge:**
- **Text:** "High Confidence ● 98% MATCH"
- **Background:** Light green (#D1FAE5)
- **Text Color:** Dark green (#047857)
- **Dot Color:** Green #10B981
- **Font:** SF Pro, 12pt, Semibold (600)
- **Padding:** 6px 12px
- **Border Radius:** 6px

**Badge Spacing:** Space-between (flexbox)

### Scripture Reference
- **Text:** "Romans 8:28" (example)
- **Font:** SF Pro Display, 36pt, Bold (700)
- **Color:** Near Black (#1F2937)
- **Margin:** 16px top, 16px bottom
- **Line Height:** 1.2

### Scripture Verse Text
- **Font:** Georgia (serif), 18pt, Regular (400)
- **Color:** Dark gray (#374151)
- **Line Height:** 1.7
- **Margin:** 0px
- **Text Alignment:** Left
- **Max Lines:** 5-6 lines before wrapping

**Sample:**
```
"And we know that in all things God works for the good of those
who love him, who have been called according to his purpose."
```

### Translation Info
- **Text:** "Berean Standard Bible (12pt, #6B7280)" (example)
- **Font:** SF Pro, 12pt, Medium (500)
- **Color:** Medium gray (#6B7280)
- **Margin:** 16px top

### Action Icons (Bottom Right)
- **Edit Icon:** SF Symbol: pencil, 18px, #6B7280
- **Copy Icon:** SF Symbol: doc.on.doc, 18px, #6B7280
- **Spacing:** 12px gap between icons
- **Hover:** Opacity 0.6, 150ms ease

---

## 6. Action Buttons

### Layout
- **Container Height:** ~80px (15% of content area)
- **Margin:** 16px horizontal, 16px bottom
- **Layout:** Flexbox, horizontal
- **Gap:** 16px between buttons
- **Alignment:** Left-aligned (not centered)

### Button 1: "Push to ProPresenter" (PRIMARY)
- **Width:** 280px
- **Height:** 56px
- **Background:** Gold gradient
  - Start: #D4AF37
  - End: #C19A2E
  - Direction: Linear, left to right
- **Text:** "Push to ProPresenter"
- **Font:** SF Pro, 16pt, Semibold (600)
- **Text Color:** White (#FFFFFF)
- **Icon:** → Right arrow (SF Symbol: arrow.right)
- **Icon Position:** Right side of text (8px gap)
- **Border Radius:** 12px
- **Shadow:** 0px 4px 12px rgba(212, 175, 55, 0.35)
- **Hover:** Slightly darker gradient, scale 1.02, 200ms ease
- **Active (Click):** Scale 0.98, 100ms ease

### Button 2: "Ignore" (SECONDARY)
- **Width:** 160px
- **Height:** 56px
- **Background:** Light gray (#F3F4F6)
- **Text:** "Ignore"
- **Font:** SF Pro, 16pt, Medium (500)
- **Text Color:** Dark gray (#374151)
- **Icon:** ✕ X mark (SF Symbol: xmark)
- **Icon Position:** Left side of text (8px gap)
- **Border Radius:** 12px
- **Border:** None
- **Shadow:** None
- **Hover:** Background #E5E7EB, 150ms ease

### Button 3: "Pause Listening" (TERTIARY)
- **Width:** 200px
- **Height:** 56px
- **Background:** White (#FFFFFF)
- **Border:** 1px solid #E5E7EB
- **Text:** "Pause Listening"
- **Font:** SF Pro, 16pt, Medium (500)
- **Text Color:** Gray (#6B7280)
- **Icon:** ⏸ Pause (SF Symbol: pause.fill)
- **Icon Position:** Left side of text (8px gap)
- **Border Radius:** 12px
- **Shadow:** None
- **Hover:** Background #F9FAFB, 150ms ease

---

## 7. Floating Action Button (FAB)

### Dimensions & Position
- **Size:** 64px × 64px (circular)
- **Position:** Fixed, bottom-right
- **Offset:** 24px from right edge, 24px from bottom edge
- **Z-Index:** 1000 (always on top)

### Style
- **Background:** Blue gradient
  - Start: #3B82F6
  - End: #2563EB
  - Direction: Linear, top to bottom
- **Icon:** 🔍 Magnifying glass (SF Symbol: magnifyingglass)
- **Icon Size:** 28px
- **Icon Color:** White (#FFFFFF)
- **Border Radius:** 50% (circular)
- **Shadow:** 0px 8px 24px rgba(59, 130, 246, 0.4)
- **Hover:** Scale 1.08, shadow increases to 0.5 opacity, 150ms ease
- **Active (Click):** Scale 0.95, 100ms ease

### Behavior
- **On Click:** Opens Manual Scripture Search modal/sheet
- **On Hover:** Tooltip appears ("Search Scripture")

---

## 8. Ad Sidebar (Free Tier Only)

### Dimensions
- **Width:** 200px (fixed)
- **Height:** Full window height minus header
- **Background:** Light gray (#F5F5F5)
- **Padding:** 16px all sides
- **Position:** Right side of window

### Layout
- **3 Ad Units:** Stacked vertically
- **Spacing:** 16px gap between units

### Ad Unit 1
- **Size:** 168px × 168px (square)
- **Background:** White (#FFFFFF)
- **Border:** 1px solid #E5E7EB
- **Border Radius:** 8px
- **Content:** "Ad Space 1" placeholder or actual ad image

### Ad Unit 2
- **Size:** 168px × 168px (square)
- **Background:** White (#FFFFFF)
- **Border:** 1px solid #E5E7EB
- **Border Radius:** 8px
- **Content:** "Ad Space 2" placeholder or actual ad image

### Ad Unit 3
- **Size:** 168px × 280px (rectangle, taller)
- **Background:** White (#FFFFFF)
- **Border:** 1px solid #E5E7EB
- **Border Radius:** 8px
- **Content:** "Ad Space 3" placeholder or actual ad image

### "Remove Ads" Button (Bottom)
- **Width:** 168px (full sidebar width minus padding)
- **Height:** 44px
- **Background:** Blue #3B82F6
- **Text:** "Remove Ads"
- **Font:** SF Pro, 14pt, Semibold (600)
- **Text Color:** White (#FFFFFF)
- **Border Radius:** 8px
- **Margin Top:** Auto (pushed to bottom)
- **Hover:** Background #2563EB, 150ms ease
- **Action:** Opens subscription/payment flow

---

## 9. Bottom Banner Ad (Free Tier Only)

### Dimensions
- **Width:** Full window width
- **Height:** 60px
- **Background:** White (#FFFFFF)
- **Border Top:** 1px solid #E5E7EB

### Content
- **Standard Size:** 728px × 60px (IAB standard banner)
- **Alignment:** Center-aligned horizontally
- **Placeholder Text:** "Banner Ad Space (728x60)" or actual ad content

### Behavior
- **Position:** Fixed at bottom of window
- **Z-Index:** 900 (below FAB)
- **Responsive:** Scales down proportionally if window width < 800px

---

## 10. Color Palette (Exact Hex Codes)

### Primary Colors
```
Divine Link Gold:   #D4AF37  RGB(212, 175, 55)
Gold Dark (Gradient): #C19A2E  RGB(193, 154, 46)
Blue:               #3B82F6  RGB(59, 130, 246)
Blue Dark (Gradient): #2563EB  RGB(37, 99, 235)
```

### Neutrals
```
Near Black:         #1F2937  RGB(31, 41, 55)
Dark Gray:          #374151  RGB(55, 65, 81)
Medium Gray:        #6B7280  RGB(107, 114, 128)
Light Gray:         #E5E7EB  RGB(229, 231, 235)
Off White:          #F9FAFB  RGB(249, 250, 251)
White:              #FFFFFF  RGB(255, 255, 255)
```

### Status Colors
```
Success Green:      #10B981  RGB(16, 185, 129)
Warning Amber:      #F59E0B  RGB(245, 158, 11)
Error Red:          #EF4444  RGB(239, 68, 68)
```

### Backgrounds
```
Main Gradient Start: #F9FAFB
Main Gradient End:   #FFFFFF
Card Background:     #FFFFFF
Transcript Card:     #F9FAFB
Ad Sidebar:          #F5F5F5
```

---

## 11. Typography System

### Font Stack
```css
Primary: -apple-system, SF Pro, system-ui
Serif (Verses): Georgia, Times, serif
Monospace (Transcript): SF Mono, Monaco, monospace
```

### Type Scale

| Element | Font | Size | Weight | Line Height | Color |
|---------|------|------|--------|-------------|-------|
| Scripture Reference | SF Pro Display | 36pt | Bold (700) | 1.2 | #1F2937 |
| Scripture Verse | Georgia | 18pt | Regular (400) | 1.7 | #374151 |
| Header Text | SF Pro | 18pt | Bold (700) | 1.3 | #1F2937 |
| Button Text | SF Pro | 16pt | Semibold (600) | 1.2 | Varies |
| Body Text | SF Pro | 14pt | Medium (500) | 1.5 | #374151 |
| Label Text | SF Pro | 12pt | Medium (500) | 1.4 | #6B7280 |
| Transcript | SF Mono | 13pt | Regular (400) | 1.6 | #374151 |

---

## 12. Spacing System

### Base Unit: 4px

```
Micro:   4px   (icon gaps, tight spacing)
Small:   8px   (component internal padding)
Medium:  12px  (between related elements)
Base:    16px  (standard gap, card margins)
Large:   24px  (section spacing, outer margins)
XLarge:  32px  (card internal padding, major sections)
```

### Component Spacing
- **Card Padding:** 32px (XLarge)
- **Card Margin:** 16px (Base)
- **Button Gap:** 16px (Base)
- **Element Gap:** 12px (Medium)
- **Window Padding:** 24px (Large)

---

## 13. Shadows & Elevation

### Shadow Layers
```css
/* Level 1: Subtle card elevation */
box-shadow: 0px 2px 8px rgba(0, 0, 0, 0.05);

/* Level 2: Featured card (scripture) */
box-shadow: 0px 4px 20px rgba(212, 175, 55, 0.2);

/* Level 3: Primary button */
box-shadow: 0px 4px 12px rgba(212, 175, 55, 0.35);

/* Level 4: FAB (floating) */
box-shadow: 0px 8px 24px rgba(59, 130, 246, 0.4);
```

---

## 14. Border Radius System

```
Small:    6px  (badges, small buttons)
Medium:   8px  (audio bar, ad units)
Standard: 12px (cards, buttons)
Large:    16px (featured scripture card)
Circle:   50%  (FAB, avatar elements)
```

---

## 15. Animation & Transitions

### Timing Functions
```
Ease Out: cubic-bezier(0.25, 0.46, 0.45, 0.94)
Ease In Out: cubic-bezier(0.42, 0, 0.58, 1)
Spring: cubic-bezier(0.68, -0.55, 0.265, 1.55)
```

### Duration Scale
```
Fast:    100ms  (click feedback)
Normal:  150ms  (hover states)
Medium:  200ms  (button transitions)
Slow:    300ms  (card appearances)
```

### Animations

**Listening Pulse (Blue Dot):**
```css
@keyframes pulse {
  0%, 100% { opacity: 0.3; }
  50% { opacity: 1.0; }
}
animation: pulse 1.5s cubic-bezier(0.42, 0, 0.58, 1) infinite;
```

**Button Hover:**
```css
transform: scale(1.02);
transition: transform 200ms ease-out;
```

**FAB Hover:**
```css
transform: scale(1.08);
box-shadow: 0px 8px 24px rgba(59, 130, 246, 0.5);
transition: all 150ms ease-out;
```

---

## 16. Responsive Breakpoints

### Window Sizes

| Breakpoint | Width | Behavior |
|------------|-------|----------|
| **Large** | ≥ 1440px | Default design, all elements visible |
| **Medium** | 1024px - 1439px | Slight compression, maintain layout |
| **Small** | 768px - 1023px | Audio buttons become icon-only |
| **Minimum** | 1024px | Below this, scrollbars appear |

### Responsive Behavior

**At < 1200px:**
- Audio bar buttons reduce to icons only
- Scripture card text size reduces to 16pt
- Ad sidebar remains fixed 200px

**At < 1024px:**
- Minimum window size enforced
- Horizontal scrollbar appears if needed

---

## 17. State Management

### UI States

**Listening (Active):**
- Blue dot pulsing
- Status: "Listening"
- Audio meter active (bars animating)
- Speech button: Blue background
- All buttons enabled

**Paused:**
- Status: "Paused"
- Blue dot static (no pulse)
- Audio meter inactive (gray bars)
- Speech button: Gray background
- Only "Resume" button enabled

**Scripture Detected:**
- Pending scripture card appears
- Gold border glows
- Confidence badge shows
- Action buttons enabled

**No Scripture:**
- Pending scripture card shows placeholder
- "Listening for scripture references..." text
- Magnifying glass icon in center

---

## 18. Accessibility (WCAG 2.1 AA)

### Color Contrast Ratios
- **Text on White:** #1F2937 = 14.2:1 (AAA)
- **Text on Gold:** White text = 4.8:1 (AA)
- **Labels on White:** #6B7280 = 5.1:1 (AA)
- **Blue Button:** White text = 8.6:1 (AAA)

### Focus Indicators
- **Keyboard Focus:** 2px blue outline (#3B82F6)
- **Focus Offset:** 2px
- **Tab Order:** Logical (header → audio bar → buttons → FAB)

### Button Sizes
- **Minimum Target:** 44px × 44px (WCAG AAA)
- **All Buttons:** 56px height (exceeds minimum)
- **FAB:** 64px diameter (exceeds minimum)

---

## 19. Assets Required

### Icons (SF Symbols - macOS Native)
```
gear (settings)
mic.fill (audio)
message.fill (speech)
chevron.down (dropdown)
magnifyingglass (search/detect)
arrow.right (push button)
xmark (ignore)
pause.fill (pause)
doc.on.doc (copy)
pencil (edit)
```

### Logo
- **Format:** SVG or PNG (2x, 3x for retina)
- **Size:** 48px × 48px @ 1x
- **Circular gold icon** with abstract/geometric pattern
- **Color:** Gold #D4AF37 with subtle gradient

### Placeholder Images
- **Ad Units:** 168×168, 168×280 (PNG or JPG)
- **Banner:** 728×60 (PNG or JPG)

---

## 20. Implementation Notes

### SwiftUI Components
```
MainWindowView
├── HeaderBarView
│   ├── LogoView
│   ├── StatusIndicatorView
│   └── SettingsButtonView
├── AudioControlBar
│   ├── AudioButton
│   ├── SpeechButton
│   ├── BibleVersionPicker
│   ├── DetectButton
│   └── AudioLevelMeter
├── LiveTranscriptionCard
├── PendingScriptureCard
│   ├── ConfidenceBadge
│   ├── ScriptureReferenceText
│   ├── ScriptureVerseText
│   └── TranslationLabel
├── ActionButtonBar
│   ├── PushButton (Primary)
│   ├── IgnoreButton (Secondary)
│   └── PauseButton (Tertiary)
└── SearchFAB
```

### Data Models
```swift
struct ScriptureDetection {
    let reference: String       // "Romans 8:28"
    let verse: String          // Full verse text
    let translation: String    // "Berean Standard Bible"
    let confidence: Double     // 0.98 (98%)
    let timestamp: Date
}
```

---

## 21. Performance Targets

### Rendering
- **60 FPS:** Smooth animations and transitions
- **Audio Meter:** Real-time updates (60Hz minimum)
- **Window Resize:** Fluid, no jank

### Memory
- **Idle:** < 150MB RAM
- **Active (Listening):** < 300MB RAM

### Latency
- **Detection to Display:** < 500ms
- **Button Click Response:** < 50ms
- **Window Resize:** Instant (< 16ms per frame)

---

**Document Status:** ✅ Complete and Ready for Development
**Next Steps:** Settings window design, then individual story technical specs
**Owner:** coachAOG
**Approved:** February 18, 2026
