# Divine Link Epic 8: Settings Window Design Prompt
**For: Figma/Gemini/AI Design Tools**
**Version:** 1.0
**Date:** February 18, 2026

---

## 🎨 SETTINGS WINDOW PROMPT (Copy to Design Tool)

```
Create a modern macOS Settings window for Divine Link that matches the redesigned main window aesthetic.
Use the same design language: YouVersion-inspired clean layout + QuickVerse modern polish + Divine Link gold accents.

TARGET: macOS native preferences window (Big Sur+ style)

---

WINDOW SPECIFICATIONS:

Size: 900px wide × 700px tall
Style: Native macOS window with traffic lights (red/yellow/green)
Title: "Divine Link Settings"
Background: White (#FFFFFF) with subtle gradient
Resizable: Yes (minimum 800×600)

---

LAYOUT STRUCTURE:

┌────────────────────────────────────────────────────────────────┐
│  ● ● ●                Divine Link Settings                  ×  │
├──────────────┬─────────────────────────────────────────────────┤
│              │                                                 │
│  SIDEBAR     │           CONTENT AREA                          │
│  (220px)     │           (Flexible)                            │
│              │                                                 │
│  ┌─────────┐│                                                 │
│  │ Account ││  → Tab content appears here                    │
│  ├─────────┤│                                                 │
│  │ Audio   ││  → Card-based layout                           │
│  ├─────────┤│                                                 │
│  │Detection││  → Modern form controls                        │
│  ├─────────┤│                                                 │
│  │ProPrsnt ││  → Settings groups in cards                    │
│  ├─────────┤│                                                 │
│  │Platform ││  **NEW in Epic 8**                             │
│  ├─────────┤│                                                 │
│  │ Pastors ││                                                 │
│  ├─────────┤│                                                 │
│  │Language ││  **NEW in Epic 8**                             │
│  ├─────────┤│                                                 │
│  │ Display ││                                                 │
│  ├─────────┤│                                                 │
│  │ Updates ││                                                 │
│  ├─────────┤│                                                 │
│  │ History ││                                                 │
│  ├─────────┤│                                                 │
│  │  About  ││                                                 │
│  └─────────┘│                                                 │
└──────────────┴─────────────────────────────────────────────────┘

---

LEFT SIDEBAR (220px):

Background: Light gray (#F9FAFB)
Border Right: 1px solid #E5E7EB
Padding: 16px vertical, 0px horizontal

SIDEBAR ITEMS (Vertical list):

Each item:
- Height: 40px
- Padding: 8px 16px
- Font: SF Pro, 14pt, Medium
- Icon Size: 20×20px (SF Symbols)
- Gap between icon and text: 12px
- Border Radius: 8px (when selected)

Selected State:
- Background: Blue (#3B82F6)
- Text Color: White (#FFFFFF)
- Icon Color: White

Unselected State:
- Background: Transparent
- Text Color: Dark gray (#374151)
- Icon Color: Medium gray (#6B7280)

Hover State (Unselected):
- Background: Light gray (#F3F4F6)

SIDEBAR ITEMS LIST:

1. Account (icon: person.circle)
2. Audio (icon: waveform)
3. Detection (icon: text.magnifyingglass)
4. ProPresenter (icon: display)
5. Platform **NEW** (icon: square.stack.3d.up)
6. Pastors (icon: person.2)
7. Language **NEW** (icon: globe)
8. Display (icon: textformat.size)
9. Updates (icon: arrow.triangle.2.circlepath)
10. History (icon: clock)
11. About (icon: info.circle)

---

CONTENT AREA (Flexible width):

Background: White (#FFFFFF)
Padding: 40px all sides
Overflow: Scroll (if content exceeds height)

CONTENT LAYOUT:
- Title at top (tab name)
- Settings groups in card-based layout
- Each group is a white card with subtle shadow
- Spacing: 24px between cards

---

═══════════════════════════════════════════════════════════════
TAB 1: PLATFORM (NEW - Epic 8 Story 8.6)
═══════════════════════════════════════════════════════════════

This is the key new tab for multi-platform integration.

TITLE:
- Text: "Presentation Platform"
- Font: SF Pro Display, 24pt, Bold
- Color: #1F2937
- Margin Bottom: 24px

CARD 1: PLATFORM SELECTION

Background: White (#FFFFFF)
Border: 1px solid #E5E7EB
Border Radius: 12px
Padding: 24px
Shadow: 0px 2px 8px rgba(0,0,0,0.05)

Header:
- Text: "Select Platform"
- Font: SF Pro, 16pt, Semibold
- Color: #1F2937
- Margin Bottom: 16px

Radio Group (3 options, vertical stack, 16px spacing):

Option 1: ProPresenter
- Radio button (24px, gold when selected #D4AF37)
- Icon: Display icon (32×32px)
- Label: "ProPresenter" (16pt, Bold)
- Sublabel: "Recommended - Full feature support" (13pt, Gray)
- Selected: Gold radio, bold text

Option 2: EasyWorship
- Radio button (24px)
- Icon: Display icon
- Label: "EasyWorship" (16pt, Medium)
- Sublabel: "API integration (requires setup)" (13pt, Gray)

Option 3: FreeShow
- Radio button (24px)
- Icon: Display icon
- Label: "FreeShow" (16pt, Medium)
- Sublabel: "WebSocket connection" (13pt, Gray)

CARD 2: CONNECTION SETTINGS (Conditional - appears after selection)

Background: White (#FFFFFF)
Border: 1px solid #E5E7EB
Border Radius: 12px
Padding: 24px
Shadow: 0px 2px 8px rgba(0,0,0,0.05)
Margin Top: 16px

Header:
- Text: "Connection Settings"
- Font: SF Pro, 16pt, Semibold

Form Fields (2 rows):

Row 1: IP Address
- Label: "IP Address" (14pt, Medium, Gray)
- Input: Text field, white background, border
  - Placeholder: "127.0.0.1"
  - Width: Full width
  - Height: 40px
  - Border Radius: 8px

Row 2: Port
- Label: "Port" (14pt, Medium, Gray)
- Input: Number field
  - Placeholder: "8080"
  - Width: 120px
  - Height: 40px

Row 3: Test Connection Button
- Button: "Test Connection"
- Width: 160px
- Height: 44px
- Background: Blue (#3B82F6)
- Text: White, 14pt, Semibold
- Border Radius: 8px
- Icon: WiFi symbol (left)

Connection Status (appears after test):
- Success: Green dot ● + "Connected" (Green text)
- Failure: Red dot ● + "Connection failed" (Red text)
- Pending: Spinner + "Testing..." (Gray text)

CARD 3: ADVANCED OPTIONS (Collapsed by default)

Disclosure Triangle: "Advanced Options >" (14pt, Blue)

When Expanded:
- Toggle: "Use WebSocket (Premium)"
- Toggle: "Enable keyboard fallback"
- Slider: "Connection timeout" (5-60 seconds)

---

═══════════════════════════════════════════════════════════════
TAB 2: LANGUAGE (NEW - Epic 8 Story 8.5)
═══════════════════════════════════════════════════════════════

TITLE:
- Text: "Language & Region"
- Font: SF Pro Display, 24pt, Bold
- Margin Bottom: 24px

CARD 1: LANGUAGE SELECTION

Background: White (#FFFFFF)
Border: 1px solid #E5E7EB
Border Radius: 12px
Padding: 24px

Header:
- Text: "Interface Language"
- Font: SF Pro, 16pt, Semibold
- Margin Bottom: 16px

Segmented Control (2 options):
- Width: 320px
- Height: 40px
- Options: "UK English" | "US English"
- Selected: Gold background (#D4AF37), white text
- Unselected: Light gray background, dark text
- Border Radius: 8px

CARD 2: REGIONAL SETTINGS

Margin Top: 16px

Header:
- Text: "Regional Format"
- Font: SF Pro, 16pt, Semibold

Preview Section:
- Label: "Date Format Preview"
- UK: "17 February 2026"
- US: "February 17, 2026"
- Font: SF Pro, 14pt, Regular, Gray

---

═══════════════════════════════════════════════════════════════
TAB 3: ACCOUNT (Existing, but modernized)
═══════════════════════════════════════════════════════════════

If Not Signed In:

CARD: SIGN IN PROMPT
- Center-aligned content
- Icon: User circle (64×64px, Gold)
- Title: "Sign In to Divine Link" (20pt, Bold)
- Subtitle: "Access premium features, sync across devices" (14pt, Gray)
- Button: "Sign In" (Gold background, white text, 44px height)

If Signed In:

CARD 1: ACCOUNT INFO
- Avatar: Circular (64×64px)
- Name: Email address (16pt, Bold)
- Plan: "Premium" or "Free" badge (gold or gray)
- Button: "Manage Subscription" (secondary style)
- Button: "Sign Out" (tertiary style)

CARD 2: DEVICE MANAGEMENT
- List of devices with this account
- Device name, last active date
- "Remove" button per device

---

═══════════════════════════════════════════════════════════════
OTHER TABS (Brief specs - use existing patterns)
═══════════════════════════════════════════════════════════════

AUDIO TAB:
- Card: Input device selector (dropdown)
- Card: Audio level threshold slider
- Card: Sample rate settings

DETECTION TAB:
- Card: Detection sensitivity slider
- Card: Confidence threshold settings
- Card: Bible translations (KJV, ASV, WEB checkboxes)

PROPRESENTER TAB:
- Card: Stage Display settings
- Card: Messages API settings
- Card: Connection test

PASTORS TAB:
- List of pastor profiles (card-based)
- Add new pastor button (gold)

DISPLAY TAB:
- Card: Font size slider
- Card: Theme toggle (Light/Dark - not implemented yet)

UPDATES TAB:
- Card: Current version (2.0.0)
- Card: Auto-check toggle
- Button: "Check for Updates Now"

HISTORY TAB:
- List of past services (card-based)
- Search bar at top
- Export buttons

ABOUT TAB:
- Divine Link logo (large, centered)
- Version number
- Developer info
- Links (Support, Website, GitHub)

---

DESIGN PRINCIPLES:

1. CONSISTENCY:
   - Use same colors as main window (Gold #D4AF37, Blue #3B82F6)
   - Same typography (SF Pro family)
   - Same shadows and border radius

2. CARD-BASED LAYOUT:
   - Each settings group in its own card
   - White background, subtle shadow
   - 24px padding, 12px border radius

3. YOUVERSION SIMPLICITY:
   - Clean white space
   - Not cluttered
   - Obvious what each setting does

4. QUICKVERSE POLISH:
   - Modern form controls
   - Subtle animations on interactions
   - Clear visual hierarchy

5. NATIVE MACOS:
   - Standard macOS controls (toggles, sliders, dropdowns)
   - Native window chrome
   - Follows Human Interface Guidelines

---

COLOR PALETTE (Same as main window):

Gold: #D4AF37
Blue: #3B82F6
Near Black: #1F2937
Dark Gray: #374151
Medium Gray: #6B7280
Light Gray: #E5E7EB
Off White: #F9FAFB
White: #FFFFFF

Green (Success): #10B981
Red (Error): #EF4444

---

TYPOGRAPHY (Same as main window):

Tab Title: SF Pro Display, 24pt, Bold
Card Header: SF Pro, 16pt, Semibold
Label: SF Pro, 14pt, Medium
Body Text: SF Pro, 14pt, Regular
Sublabel: SF Pro, 13pt, Regular
Button: SF Pro, 14pt, Semibold

---

SPACING:

Window Padding: 40px
Card Margin: 24px between cards
Card Padding: 24px internal
Form Field Gap: 16px vertical
Label to Input: 8px

---

OUTPUT REQUIREMENTS:

Generate high-fidelity mockups for:
1. Platform tab (main focus - NEW in Epic 8)
2. Language tab (NEW in Epic 8)
3. Account tab (existing, modernized)

Show:
- Native macOS window chrome
- Sidebar with all tabs listed
- Selected tab highlighted in blue
- Content area with card-based settings
- Proper spacing and shadows
- Gold and blue accents throughout

Style: Native macOS Big Sur+ preferences window with YouVersion simplicity
and QuickVerse polish, maintaining Divine Link's gold signature.
```

---

## 📋 SIMPLIFIED VERSION (For Quick Mockups)

```
Create macOS Settings window for Divine Link (900×700px):

LAYOUT:
- Left sidebar (220px): List of 11 tabs (Account, Audio, Detection, ProPresenter,
  Platform [NEW], Pastors, Language [NEW], Display, Updates, History, About)
- Right content area: Card-based settings layout

KEY NEW TABS (Epic 8):

1. PLATFORM TAB (Story 8.6):
   - Radio buttons: ProPresenter, EasyWorship, FreeShow
   - Connection settings: IP, Port, Test button
   - Status indicator (green dot = connected)

2. LANGUAGE TAB (Story 8.5):
   - Segmented control: "UK English" | "US English"
   - Date format preview

STYLE:
- White cards with subtle shadows
- Gold accents (#D4AF37) for selected/primary elements
- Blue (#3B82F6) for active sidebar item
- SF Pro typography
- Native macOS controls

MATCH: Main window design (YouVersion clean + QuickVerse modern)
```

---

## ✅ **Summary**

I've created:

1. ✅ **Technical Specification** (`epic-8-technical-specification.md`)
   - All dimensions, colors, typography from your mockups
   - Developer-ready handoff document
   - 21 sections covering every aspect

2. ✅ **Settings Window Prompt** (`epic-8-settings-window-prompt.md`)
   - Complete design for modernized Settings
   - Focus on 2 NEW tabs: Platform + Language (Epic 8 features)
   - Matches main window aesthetic

---

## 🚀 **Next Steps:**

1. Use the Settings prompt in Figma/Gemini to generate Settings mockups
2. Share the results
3. Final tweaks and we're ready for development!

Your main window design is **production-ready**! The audio meter will be better in code (as you noted), and all specs are documented. 🎉

Want to generate the Settings window now?