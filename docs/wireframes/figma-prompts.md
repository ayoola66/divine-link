# Divine Link - Figma AI Prompts

**Purpose:** Copy-paste these prompts into Figma's AI wireframe generator (⌘+K → Generate) or the Cursor AI for Figma plugin.

---

## How to Use

1. Open Figma
2. Create a new frame (480×520 for main window, 480×320 for settings)
3. Press ⌘+K (Mac) or Ctrl+K (Windows)
4. Type "Generate" or select "Generate with AI"
5. Paste the prompt below
6. Refine the output

---

## Prompt 1: Main Window - Listening State

```
Design a macOS menu bar popover window for "Divine Link" - a scripture detection app.

Dimensions: 480px × 520px
Style: Clean, minimal, macOS native feel. Think "mission control" not "creative software".

Layout (top to bottom):

HEADER (48px height):
- Left: Small app logo icon (book symbol)
- Center: Status text "Listening" in grey
- Right: Small green connection dot, then settings gear icon

ZONE 1 - Transcript (80px height):
- Grey background panel with rounded corners
- Scrolling transcript text in SF Mono 13pt, grey color
- Sample text: "...and so when we look at the scriptures, we see that God's love is revealed..."
- Auto-scrolls, non-editable appearance

ZONE 2 - Empty State (expanding to fill):
- Centered content
- Light magnifying glass icon (muted)
- Italic text below: "Listening for scriptures..."
- Dashed border, very subtle

ZONE 3 - Actions (80px height):
- Three buttons in a row with spacing
- "Push to ProPresenter" button (disabled/greyed out)
- "Ignore" button (disabled/greyed out)  
- "Pause" button (active, grey background)
- Each button shows keyboard shortcut below label (Enter, Esc, Space)
- Buttons should be large, 44px minimum height

Colors:
- Background: System window background
- Disabled buttons: #E5E7EB
- Active button: #F3F4F6
- Blue accent: #2563EB
- Gold accent: #D4AF37
```

---

## Prompt 2: Main Window - Pending Verse State

```
Design a macOS menu bar popover for "Divine Link" showing a detected Bible verse.

Dimensions: 480px × 520px
Style: Clean, professional, calm under pressure.

Layout:

HEADER (48px):
- Left: Book icon logo
- Center: "Pending Verse" status (text changed from "Listening")
- Right: Green dot, settings icon

ZONE 1 - Transcript (80px):
- Same as before, scrolling grey text
- Shows: "...turn with me to the book of Romans, chapter eight, verse twenty-eight..."

ZONE 2 - Scripture Card (main focus):
- Card with off-white background (#F8F8F8)
- GOLD BORDER (2px solid #D4AF37) - this is important!
- Rounded corners (12px)
- Padding: 16px

Card contents:
- Label at top: "DETECTED SCRIPTURE (PENDING)" in small caps, grey
- Three small dots on right showing confidence (●●●)
- Book icon + "Romans 8:28" in 24pt semibold
- Scripture text in blue (#2563EB), 18pt:
  "And we know that in all things God works for the good of those who love him, who have been called according to his purpose."
- Translation label at bottom: "Berean Standard Bible" in italic grey

ZONE 3 - Actions (80px):
- "Push to ProPresenter" now has GOLD background (#D4AF37), white text
- "Ignore" button active (neutral styling)
- "Pause" button active (grey)
- All three buttons enabled

The gold button should clearly stand out as the primary action.
```

---

## Prompt 3: Main Window - Paused State

```
Design the paused state for "Divine Link" macOS app.

Same layout as the Listening state but with these changes:

VISUAL TREATMENT:
- Entire UI should appear desaturated (30% saturation)
- Muted grey tones throughout
- Less contrast
- Feel: intentionally dormant

SPECIFIC CHANGES:
- Header status: "Paused"
- Zone 1 transcript: frozen, more faded
- Zone 2: Shows pause icon and "Listening paused" text
- Zone 3: "Pause" button now says "Resume" with play icon
- Push and Ignore buttons disabled (greyed)

The overall impression should be that the app is intentionally quiet/inactive.
```

---

## Prompt 4: Settings - Audio Tab

```
Design a settings window for a macOS app.

Dimensions: 480px × 320px
Style: Native macOS settings appearance, grouped form style

TAB BAR at top:
- Three tabs: "Audio" (selected), "ProPresenter", "About"
- Use icons: microphone, TV, info circle

CONTENT for Audio tab:

Section: "Audio Input"
- Dropdown/picker labeled "Input Device"
- Shows "Built-in Microphone" as current selection
- Below: Info box with blue info icon
  Text: "Want to capture system audio?"
  Link: "Install BlackHole (free)" with arrow

Section: "Test"
- Label: "Input Level"
- Horizontal audio level meter bar (animated would be nice)
- Shows current input volume

Use native macOS form styling with grouped sections.
```

---

## Prompt 5: Settings - ProPresenter Tab

```
Design ProPresenter connection settings for a macOS app.

Dimensions: 480px × 320px
Same tab bar as Audio settings

CONTENT for ProPresenter tab:

Section: "Connection"
- Text field: "IP Address" with placeholder "192.168.1.100"
- Text field: "Port" with value "1025" (smaller width)

Section: "Status"
- Left side: Status indicator
  - Green circle + "Connected" text
  - Below: "192.168.1.100:1025" in small grey text
- Right side: "Test Connection" button

The status indicator should clearly show connection health.
Validation error state: Red text below IP field if invalid.
```

---

## Prompt 6: Settings - About Tab

```
Design an About tab for a macOS settings window.

Dimensions: 480px × 320px
Same tab bar

CONTENT centered vertically:
- App icon (book symbol, 80×80)
- "Divine Link" in title size, semibold
- "Version 1.0.0" in small grey text
- Spacer
- "Real-time scripture detection for ProPresenter" in body text, grey
- Spacer
- "© 2026 Divine Link" at bottom in small text

Simple, clean, professional.
```

---

## Prompt 7: Error - Push Failed Modal

```
Design an error modal/dialog for a macOS app.

Style: Native macOS alert appearance

Content:
- Warning triangle icon (amber/orange)
- Title: "Push Failed"
- Message: "Unable to send to ProPresenter. Check your connection settings."
- Two buttons at bottom:
  - "Dismiss" (secondary, left)
  - "Retry" (primary, right)

The modal should appear over a dimmed background overlay.
Size: approximately 320×200
```

---

## Prompt 8: Onboarding - Audio Setup Wizard

```
Design a first-run setup wizard for audio configuration.

Dimensions: 480px × 400px
Style: Welcoming, clear, not overwhelming

Content:

Title area:
- "Welcome to Divine Link" heading

Question:
- "How should Divine Link hear the sermon?"

Three option cards (stacked vertically):

1. Card with microphone icon:
   - "Use my Mac's microphone"
   - Subtext: "Simple setup, may pick up room noise"

2. Card with speaker icon (recommended badge):
   - "Capture system audio"
   - Subtext: "Cleanest audio - requires BlackHole"

3. Card with mixer/sliders icon:
   - "I have a professional audio setup"
   - Subtext: "Audio interface or mixing desk"

Each card should be selectable (like radio options).

Bottom right: "Skip for now →" link
```

---

## Prompt 9: Menu Bar Icon Context Menu

```
Design a macOS menu bar context menu (right-click menu).

Style: Standard macOS menu appearance

Menu items:
1. "Show Divine Link" (with app icon)
2. Separator line
3. "Pause Listening" (or "Resume Listening")
4. Separator line
5. "Settings..." (with ⌘, shortcut)
6. Separator line
7. "Quit Divine Link" (with ⌘Q shortcut)

Standard macOS menu styling with proper spacing and separators.
```

---

## Prompt 10: Component - Scripture Card

```
Design a reusable scripture card component.

Dimensions: Full width, auto height
Background: Off-white (#F8F8F8)
Border: 2px solid gold (#D4AF37)
Corner radius: 12px
Padding: 16px

Contents from top to bottom:

Row 1:
- Left: "DETECTED SCRIPTURE (PENDING)" label in small caps, grey, letterspacing
- Right: Three dots for confidence (●●○ for medium, ●●● for high)

Row 2 (with spacing):
- Book icon (📖)
- Reference text "Romans 8:28" in 24pt semibold

Row 3:
- Scripture text in blue (#2563EB), 18pt, multiple lines okay
- "And we know that in all things God works for the good of those who love him, who have been called according to his purpose."

Row 4:
- Translation: "Berean Standard Bible" in 12pt italic grey

This card is the heart of the app - make it beautiful but calm.
```

---

## Design System Values for Figma

When setting up your Figma file, create these as variables/styles:

### Colors
```
divine-blue: #2563EB
divine-gold: #D4AF37
calm-blue: #3B82F6
off-white: #F8F8F8
near-black: #1F2937
grey-text: #6B7280
muted-grey: #9CA3AF
success-green: #22C55E
error-red: #DC2626
warning-amber: #F59E0B
```

### Text Styles
```
scripture-text: SF Pro, 18pt, Regular
scripture-ref: SF Pro, 24pt, Semibold
status-text: SF Pro, 14pt, Medium
transcript: SF Mono, 13pt, Regular
button-label: SF Pro, 16pt, Semibold
caption: SF Pro, 12pt, Regular
```

### Effects
```
card-shadow: 0px 2px 4px rgba(0,0,0,0.1)
gold-border: 2px solid #D4AF37
```
