# Divine Link Epic 8: Visual Design Prompt
**For: AI Design Tools (Google Stitch, v0, Figma AI, etc.)**
**Version:** 1.0
**Date:** February 17, 2026

---

## Master Prompt (Copy/Paste to Design Tool)

```
Create a modern macOS application UI design for "Divine Link", a church scripture detection app.
The design should combine YouVersion's clean, familiar Bible app aesthetic with QuickVerse's
modern card-based layouts and gradient accents, while maintaining Divine Link's unique identity.

TARGET PLATFORM: macOS native app (Big Sur+ design language)
RESOLUTION: 1280x800px minimum window size
DESIGN SYSTEM: Native macOS with SwiftUI components

---

LAYOUT STRUCTURE (Top to Bottom):

1. HEADER BAR (Height: 60px)
   - Background: White (#FFFFFF) with subtle bottom border (1px, #E5E7EB)
   - Left: Divine Link logo (40x40px circular icon with gold accent)
   - Center: Status text "Listening" with subtle pulse animation (small blue dot indicator)
   - Right: Settings gear icon (SF Symbols style, 24x24px)
   - Style: Clean, minimal, macOS native

2. MAIN CONTENT AREA (Flexible height)
   Layout: 3 distinct zones in vertical stack

   ZONE 1: LISTENING FEED CARD (Top, ~25% height)
   - Card with rounded corners (12px radius)
   - Background: Light gray (#F9FAFB)
   - Subtle shadow: 0px 2px 8px rgba(0,0,0,0.05)
   - Header: "Live Transcription" in medium weight
   - Content: Scrolling transcript text in monospace font
   - Style: Muted, non-interactive, YouVersion-inspired card

   ZONE 2: PENDING SCRIPTURE CARD (Center, ~40% height) **PRIMARY FOCUS**
   - Large card with prominent rounded corners (16px radius)
   - Background: White (#FFFFFF)
   - Border: 2px solid gold (#D4AF37) - Divine Link signature accent
   - Shadow: 0px 4px 16px rgba(212, 175, 55, 0.15) - gold glow effect
   - Padding: 32px all sides

   Card Contents:
   - Header: "Detected Scripture" badge (small pill, gold background, white text)
   - Reference: "Romans 8:28" in large, bold text (32pt, #1F2937)
   - Verse Text: Full scripture in readable serif font (18pt, #374151)
   - Translation Label: "Berean Standard Bible" in small gray text (12pt, #6B7280)
   - Confidence Indicator: Small badge "High Confidence" with green dot
   - Style: YouVersion-inspired clean typography with QuickVerse card depth

   ZONE 3: ACTION BUTTONS (Bottom, ~15% height)
   - 3 large buttons in horizontal layout
   - Spacing: 16px between buttons
   - Height: 56px each (touch-friendly)

   Button 1: "Push to ProPresenter" (PRIMARY)
   - Background: Linear gradient gold (#D4AF37 to #C19A2E)
   - Text: White, bold, 16pt
   - Icon: Right-pointing arrow (SF Symbol)
   - Corner radius: 12px
   - Shadow: 0px 4px 12px rgba(212, 175, 55, 0.3)
   - Hover state: Slightly darker gradient

   Button 2: "Ignore" (SECONDARY)
   - Background: Light gray (#F3F4F6)
   - Text: Dark gray (#374151), medium, 16pt
   - Icon: X mark (SF Symbol)
   - Corner radius: 12px
   - No shadow

   Button 3: "Pause Listening" (TERTIARY)
   - Background: White with 1px border (#E5E7EB)
   - Text: Gray (#6B7280), medium, 16pt
   - Icon: Pause symbol (SF Symbol)
   - Corner radius: 12px
   - No shadow

3. FLOATING ACTION BUTTON (Bottom-right, Fixed Position)
   - Circular button (56x56px)
   - Background: Blue gradient (#3B82F6 to #2563EB)
   - Icon: Search/magnifying glass (white, SF Symbol)
   - Shadow: 0px 6px 20px rgba(59, 130, 246, 0.4)
   - Position: 24px from right, 24px from bottom
   - Purpose: Manual scripture search (new in Epic 8)

---

COLOR PALETTE:

PRIMARY COLORS:
- Divine Link Gold: #D4AF37 (primary accent, buttons, highlights)
- Gold Dark: #C19A2E (button gradients, hover states)
- Blue: #3B82F6 (listening indicator, search FAB)
- Blue Dark: #2563EB (gradients)

NEUTRALS:
- Near Black: #1F2937 (primary text)
- Dark Gray: #374151 (secondary text)
- Medium Gray: #6B7280 (tertiary text, labels)
- Light Gray: #E5E7EB (borders, dividers)
- Off-White: #F9FAFB (card backgrounds)
- White: #FFFFFF (main background, cards)

STATUS COLORS:
- Success Green: #10B981 (high confidence)
- Warning Amber: #F59E0B (medium confidence)
- Error Red: #EF4444 (low confidence, critical only)

---

TYPOGRAPHY:

Font Family: SF Pro (macOS system font)
- Headers: SF Pro Display
- Body: SF Pro Text
- Code/Transcript: SF Mono

Text Styles:
- Scripture Reference: 32pt, Bold (700), #1F2937
- Scripture Verse: 18pt, Regular (400), #374151, Line height 1.6
- Button Text: 16pt, Semibold (600)
- Status Text: 14pt, Medium (500)
- Labels: 12pt, Medium (500), #6B7280
- Transcript: 13pt, SF Mono Regular

---

SPACING & LAYOUT:

Margins: 24px all sides
Card Padding: 32px internal
Element Spacing: 16px between major components
Button Spacing: 16px horizontal gap
Corner Radius: 12px standard, 16px for featured cards

---

VISUAL EFFECTS:

Shadows:
- Card elevation: 0px 2px 8px rgba(0,0,0,0.05)
- Featured card: 0px 4px 16px rgba(212,175,55,0.15)
- Buttons: 0px 4px 12px rgba(212,175,55,0.3)
- FAB: 0px 6px 20px rgba(59,130,246,0.4)

Animations:
- Listening pulse: Subtle blue dot, 1s cycle, opacity 0.4-1.0
- Button hover: Scale 1.02, 200ms ease
- Card appearance: Fade in + slide up, 300ms ease-out

---

DESIGN INSPIRATION REFERENCES:

YOUVERSION STYLE (Apply these principles):
- Clean, uncluttered white space
- Readable serif font for scripture text
- Simple card-based verse display
- Minimal chrome, content-focused
- Familiar Bible app patterns

QUICKVERSE STYLE (Apply these principles):
- Modern gradient accents
- Card-based layouts with depth (shadows)
- Clear SF Symbols iconography
- Contemporary color transitions
- Subtle animations on interaction

DIVINE LINK IDENTITY (Maintain these):
- Gold accent color (#D4AF37) as signature
- Mission-control aesthetic (calm, professional)
- Operator-first design (large buttons, clear states)
- Native macOS feel (not web-like)

---

UI STATES TO SHOW:

STATE 1: Listening (Default)
- Listening feed shows live transcript
- Pending scripture card visible with verse
- All 3 action buttons enabled
- Blue pulse indicator active in header

STATE 2: Paused
- Header shows "Paused" status
- UI slightly desaturated (reduce opacity to 0.7)
- Action buttons disabled except "Resume"

STATE 3: Manual Search Open
- Modal/sheet slides in from right (400px wide)
- Search bar at top with autocomplete
- Results list below (verse cards)
- Maintains main window visibility (semi-transparent overlay)

---

ACCESSIBILITY:

- Button minimum size: 44x44pt (macOS touch targets)
- Text contrast: WCAG AA compliant (4.5:1 minimum)
- Focus indicators: 2px blue outline for keyboard navigation
- Icon labels: Text labels visible on hover

---

MICRO-INTERACTIONS:

- Button press: Scale down 0.98, 100ms
- Card hover: Subtle lift (shadow increase), 200ms
- Search input focus: Border glow (blue), 150ms
- Confidence badge: Gentle pulse on detection

---

DIMENSIONS:

Window:
- Minimum: 1280x800px
- Preferred: 1440x900px
- Aspect ratio: 16:10

Components:
- Header bar: Full width x 60px
- Card corner radius: 16px (featured), 12px (standard)
- Button height: 56px
- FAB diameter: 56px
- Icon size: 24x24px (standard), 20x20px (small)

---

OUTPUT FORMAT:

Please generate:
1. Main window in "Listening" state with pending verse
2. High-fidelity mockup with all colors, shadows, and typography applied
3. Show the manual search FAB in bottom-right corner
4. Include realistic scripture text (Romans 8:28)
5. Native macOS window chrome (traffic lights, title bar)
```

---

## Additional Prompts for Specific Views

### PROMPT 2: Manual Search Interface

```
Create a modal sheet for Divine Link's manual scripture search feature, sliding in from right side:

DIMENSIONS: 400px wide x full height
BACKGROUND: White (#FFFFFF)
SHADOW: Left edge shadow for depth

LAYOUT (Top to Bottom):

1. HEADER (Height: 60px)
   - Text: "Search Scripture" (20pt, Bold)
   - Right: Close button (X icon, 24x24px)
   - Border bottom: 1px #E5E7EB

2. SEARCH BAR (Height: 48px, Margin: 16px)
   - Input field with rounded corners (8px)
   - Placeholder: "John 3:16 or 'love your neighbor'"
   - Left icon: Magnifying glass (SF Symbol)
   - Border: 1px #E5E7EB, focus state: 2px blue
   - Autocomplete dropdown below

3. BIBLE VERSION SELECTOR (Height: 40px, Margin: 16px)
   - Segmented control: KJV | ASV | WEB
   - Selected: Gold background (#D4AF37), white text
   - Unselected: Light gray (#F9FAFB), dark text

4. RESULTS LIST (Scrollable)
   - Each result: Compact card (120px height)
   - Reference header (14pt, Bold)
   - Verse preview (13pt, 2 lines, ellipsis)
   - Right: "Send" button (small, gold)
   - Divider: 1px #F3F4F6 between items

5. QUICK ACTIONS (Bottom, Fixed)
   - "Copy" and "Send to ProPresenter" buttons
   - Small size (40px height)
   - Horizontal layout with 8px gap

STYLE: YouVersion-inspired list view with QuickVerse modern buttons
```

---

### PROMPT 3: Service Session Management View

```
Create a timeline view for Divine Link's service session management:

LAYOUT: Full-width sheet (modal) overlaying main window

HEADER:
- Title: "Service History" (24pt, Bold)
- Right: "New Session" button (gold, rounded)
- Close button (X, top-left)

CONTENT AREA:
- Left sidebar (300px): List of service dates
  - Each item: Card with date, pastor name, verse count
  - Selected: Gold border (2px), white background
  - Unselected: Light gray background

- Main area (flex): Selected session details
  - Header: Service metadata (date, pastor, sermon title)
  - Scripture list: Card grid (2 columns)
  - Each scripture: Mini card with reference + verse preview
  - Footer: Export buttons (PDF, Markdown, Text)

STYLE: Calendar/timeline app aesthetic (Apple Calendar-inspired)
- Clean white background
- Card-based layout
- Gold accents for selected state
```

---

### PROMPT 4: Settings Panel (Multi-Platform Integration)

```
Create a settings tab for Divine Link's presentation platform selection:

LAYOUT: Standard macOS preferences panel (700px wide)

CONTENT:
1. SECTION HEADER: "Presentation Platform" (18pt, Bold)

2. PLATFORM SELECTOR (Radio buttons, large)
   - Option 1: ProPresenter (icon + text)
   - Option 2: EasyWorship (icon + text)
   - Option 3: FreeShow (icon + text)
   - Selected: Gold radio button, bold text

3. CONNECTION SETTINGS (Per platform)
   - IP Address input field
   - Port number input field
   - Test Connection button (blue)
   - Status indicator: Green dot = Connected

4. ADVANCED OPTIONS (Collapsed by default)
   - Checkbox: "Use WebSocket (Premium)" with info icon
   - Checkbox: "Enable keyboard fallback"
   - Slider: Connection timeout (5-60 seconds)

STYLE: Native macOS preferences (System Settings-inspired)
- Left-aligned labels, right-aligned inputs
- Blue accent for active elements
- Toggle switches for boolean options
```

---

### PROMPT 5: Language Localization Toggle

```
Create a compact language selector for Divine Link's header or settings:

DESIGN 1: Segmented Control (Header bar)
- Size: 120px wide x 32px height
- Options: UK | US (flags optional)
- Selected: Gold background, white text
- Position: Top-right corner, near settings icon

DESIGN 2: Dropdown Menu (Settings panel)
- Label: "Language & Region"
- Dropdown: UK English, US English
- Below: Preview text showing date format example
  - UK: "17 February 2026"
  - US: "February 17, 2026"

STYLE: Native macOS control with gold accent for selection
```

---

## Design Tool Tips

### If using Google Stitch or similar AI tools:

1. **Start with the Master Prompt** for the main window
2. **Reference specific color codes** (don't let it choose different colors)
3. **Specify "macOS native"** to avoid web-app styling
4. **Request "Big Sur+ design language"** for modern macOS look
5. **Emphasize "YouVersion clean + QuickVerse modern"** in every prompt
6. **Mention "gold accent #D4AF37"** repeatedly to maintain identity

### Iteration Tips:

**If it's too flat:** Add "more depth with subtle shadows and card elevation"
**If it's too busy:** Add "reduce visual noise, increase white space"
**If colors are wrong:** Restate "strict color palette: gold #D4AF37, blue #3B82F6"
**If typography is off:** Specify "SF Pro system font, specific sizes: 32pt, 18pt, 16pt"

---

## Refinement Prompts

### To make it more YouVersion-like:
```
"Simplify the design further. More white space, less chrome. Focus on making the
scripture text the hero element. Use a serif font for verse text (Georgia or similar).
Reduce button prominence - make them secondary to the content."
```

### To make it more QuickVerse-like:
```
"Add more modern polish. Increase gradient usage (subtle). Add micro-shadows to cards.
Make buttons more prominent with depth. Use more SF Symbols iconography. Add subtle
animations to interactive elements."
```

### To strengthen Divine Link identity:
```
"Emphasize the gold accent color (#D4AF37) more prominently. Make the primary action
button use a gold gradient. Add a subtle gold glow around the featured scripture card.
Ensure the logo and gold color create a memorable brand impression."
```

---

## Validation Checklist

After generating designs, verify:

✅ **Color Accuracy:**
- [ ] Gold is #D4AF37 (not yellow/orange)
- [ ] Blue is #3B82F6 (not too dark/light)
- [ ] Neutrals are gray-scale (not warm/cool tints)

✅ **Typography:**
- [ ] SF Pro font family used
- [ ] Scripture text is 18pt minimum
- [ ] Button text is 16pt
- [ ] Proper font weights (Regular, Medium, Semibold, Bold)

✅ **Spacing:**
- [ ] Cards have 32px internal padding
- [ ] 16px gaps between major elements
- [ ] 24px margins from window edges
- [ ] Buttons are 56px height minimum

✅ **Identity:**
- [ ] Gold accent is prominent and memorable
- [ ] Feels like macOS native (not web app)
- [ ] YouVersion cleanliness + QuickVerse modernity balanced
- [ ] Operator-first design (large buttons, clear states)

✅ **Functionality:**
- [ ] Primary action (Push to ProPresenter) is most prominent
- [ ] Pending scripture card is visual focal point
- [ ] Manual search FAB is discoverable
- [ ] All states (listening, paused, search) are clear

---

**Created:** February 17, 2026
**Owner:** coachAOG
**Purpose:** Epic 8 UI/UX wireframe generation
**Tools:** Google Stitch, v0, Figma AI, or any AI design platform
