# Divine Link Epic 8: REFINED Design Prompt
**Based on: Gemini layout + Current DL elements**
**Version:** 2.0 - Refined
**Date:** February 17, 2026

---

## 🎨 MASTER PROMPT V2 (Copy to Stitch/Gemini)

```
Create a modern macOS native application UI for "Divine Link" scripture detection software.
Base the layout on a wide desktop format (1440x900px), combining the best elements from
the current Divine Link app with modern card-based design inspired by YouVersion and QuickVerse.

CRITICAL: This is a DESKTOP macOS app, not mobile. Use wide desktop proportions.

---

WINDOW STRUCTURE:

Outer Window: 1440px wide x 900px tall
- Native macOS window chrome (red/yellow/green traffic lights)
- Window title: "DivineLink" in system font
- Background: Light gradient (#F9FAFB to #FFFFFF)

---

LAYOUT ZONES (Left to Right):

LEFT SECTION: Main Content Area (1040px wide)
RIGHT SECTION: Ad Sidebar (200px wide, light gray #F5F5F5) - **Free Tier Only**
BOTTOM: Banner Ad Strip (full width, 60px) - **Free Tier Only**

---

MAIN CONTENT AREA STRUCTURE (Top to Bottom):

═══════════════════════════════════════════════════════════════
ZONE 1: HEADER BAR (Height: 60px, Padding: 24px horizontal)
═══════════════════════════════════════════════════════════════

Left Side:
- Divine Link Logo: Circular gold icon (48x48px) with "Divine Link" text beside it
  (Use the circular gold logo from current app)
- Text: "Divine Link" in 18pt Bold, #1F2937

Center:
- Status indicator: "Listening" text with animated blue dot (8px, pulsing)
- Style: 14pt Medium, #6B7280

Right Side:
- Settings gear icon (28x28px, SF Symbol style)
- Color: #6B7280

═══════════════════════════════════════════════════════════════
ZONE 2: AUDIO CONTROL BAR (Height: 48px, Background: White, Border: 1px #E5E7EB)
═══════════════════════════════════════════════════════════════

**This matches the current Divine Link audio control bar**

Horizontal layout with 4 elements (12px spacing):

1. Audio Source Button (Icon: 🎙️ + "Audio" text)
   - Style: Small button, light gray background
   - Size: ~80px wide x 36px height

2. Speech Recognition Button (Icon: 💬 + "Speech" text)
   - Style: Blue background when active
   - Size: ~90px wide x 36px height

3. Bible Version Dropdown (Shows: "KJV ▼")
   - Style: White background, border, dropdown arrow
   - Size: ~100px wide x 36px height

4. Detect Button (Icon: 🔍 + "Detect" text)
   - Style: Light button, secondary style
   - Size: ~90px wide x 36px height

═══════════════════════════════════════════════════════════════
ZONE 3: LIVE TRANSCRIPTION CARD (Height: ~200px, 25% of content)
═══════════════════════════════════════════════════════════════

Card Style:
- Background: Light gray (#F9FAFB)
- Border radius: 12px
- Padding: 24px
- Shadow: 0px 2px 8px rgba(0,0,0,0.05)
- Margin: 16px all sides

Header:
- Text: "Live Transcription" (14pt Medium, #6B7280)

Content:
- Transcript text: "...in all things God works for the good of those who love him,
  who have been called according to his purpose. Romans 8:28. And we know that
  in all things God..."
- Font: SF Mono 13pt, #374151
- Line height: 1.6
- Scrollable content

═══════════════════════════════════════════════════════════════
ZONE 4: PENDING SCRIPTURE CARD (Height: ~320px, 40% of content) **PRIMARY FOCUS**
═══════════════════════════════════════════════════════════════

Card Style:
- Background: White (#FFFFFF)
- Border: 3px solid gold (#D4AF37) **Divine Link signature**
- Border radius: 16px
- Padding: 32px
- Shadow: 0px 4px 20px rgba(212, 175, 55, 0.2) - gold glow
- Margin: 16px horizontal, 8px vertical

Header Section (Top of card):
- Left: Gold badge pill "Detected Scripture" (gold background #D4AF37, white text, 12pt)
- Right: Green confidence badge "High Confidence ● 98% MATCH" (light green bg, dark green text)

Scripture Reference:
- Text: "Romans 8:28"
- Font: SF Pro Display 36pt Bold, #1F2937
- Margin bottom: 16px

Scripture Verse:
- Text: "And we know that in all things God works for the good of those who
  love him, who have been called according to his purpose."
- Font: Georgia (serif) 18pt Regular, #374151
- Line height: 1.7
- Beautiful readable spacing

Translation Info:
- Text: "Berean Standard Bible (12pt, #6B7280)"
- Font: SF Pro 12pt Medium
- Margin top: 16px

Bottom Right Corner:
- Small edit icon (gray)
- Small copy icon (gray)

═══════════════════════════════════════════════════════════════
ZONE 5: ACTION BUTTONS (Height: ~80px, 15% of content)
═══════════════════════════════════════════════════════════════

3 buttons in horizontal row (16px spacing between):

Button 1: "Push to ProPresenter" **PRIMARY ACTION**
- Width: 280px, Height: 56px
- Background: Gold gradient (#D4AF37 to #C19A2E)
- Text: White, 16pt Semibold
- Icon: Right arrow → (white, left of text)
- Border radius: 12px
- Shadow: 0px 4px 12px rgba(212, 175, 55, 0.35)

Button 2: "Ignore" **SECONDARY**
- Width: 160px, Height: 56px
- Background: Light gray (#F3F4F6)
- Text: Dark gray (#374151), 16pt Medium
- Icon: X mark (left of text)
- Border radius: 12px

Button 3: "Pause Listening" **TERTIARY**
- Width: 200px, Height: 56px
- Background: White with 1px border (#E5E7EB)
- Text: Gray (#6B7280), 16pt Medium
- Icon: Pause ⏸ (left of text)
- Border radius: 12px

═══════════════════════════════════════════════════════════════
FLOATING ELEMENT: MANUAL SEARCH FAB (Fixed Position)
═══════════════════════════════════════════════════════════════

- Position: Bottom-right corner (24px from right, 24px from bottom)
- Size: 64x64px circular button
- Background: Blue gradient (#3B82F6 to #2563EB)
- Icon: Magnifying glass 🔍 (white, 28px)
- Shadow: 0px 8px 24px rgba(59, 130, 246, 0.4)
- Hover: Slight scale up (1.05)

---

RIGHT SIDEBAR: AD SPACE (200px wide) **FREE TIER**
═══════════════════════════════════════════════════════════════

Background: Light gray (#F5F5F5)
Padding: 16px

3 Ad Units Stacked Vertically (16px spacing):

Ad Unit 1: 168x168px square
- Placeholder: "Ad Space 1" or sample ad image
- Border: 1px solid #E5E7EB
- Border radius: 8px

Ad Unit 2: 168x168px square
- Placeholder: "Ad Space 2" or sample ad image
- Border: 1px solid #E5E7EB
- Border radius: 8px

Ad Unit 3: 168x280px rectangle (larger)
- Placeholder: "Ad Space 3" or sample ad image
- Border: 1px solid #E5E7EB
- Border radius: 8px

Bottom of Sidebar:
- "Remove Ads" button (full width)
- Blue background (#3B82F6)
- White text, 14pt Semibold
- Height: 44px
- Border radius: 8px

---

BOTTOM BANNER: AD SPACE (Full width x 60px) **FREE TIER**
═══════════════════════════════════════════════════════════════

Background: White
Border top: 1px solid #E5E7EB
Height: 60px

Content:
- Centered text: "Banner Ad Space" or sample banner ad
- Or: 728x60px standard banner ad dimensions

---

COLOR PALETTE (Strict Adherence Required):

PRIMARY:
- Divine Link Gold: #D4AF37 (signature accent)
- Gold Dark: #C19A2E (gradients)
- Blue: #3B82F6 (active states, FAB)
- Blue Dark: #2563EB (gradients)

NEUTRALS:
- Near Black: #1F2937 (primary text)
- Dark Gray: #374151 (body text)
- Medium Gray: #6B7280 (secondary text)
- Light Gray: #E5E7EB (borders)
- Off White: #F9FAFB (backgrounds)
- White: #FFFFFF (cards)

STATUS:
- Green: #10B981 (high confidence)
- Amber: #F59E0B (medium confidence)
- Red: #EF4444 (low confidence)

---

TYPOGRAPHY:

Font Stack: SF Pro (macOS system font)
Serif for verses: Georgia

Text Styles:
- Scripture Reference: 36pt Bold, #1F2937
- Scripture Verse: 18pt Georgia Regular, #374151, Line height 1.7
- Button Text: 16pt Semibold
- Headers: 14pt Medium
- Labels: 12pt Medium

---

SPACING SYSTEM:

Base unit: 8px
- Micro: 4px
- Small: 8px
- Medium: 16px
- Large: 24px
- XLarge: 32px

Card Padding: 32px
Button Height: 56px
Icon Size: 24px (standard), 28px (FAB)

---

VISUAL EFFECTS:

Shadows (Subtle, macOS native):
- Card: 0px 2px 8px rgba(0,0,0,0.05)
- Featured Card: 0px 4px 20px rgba(212,175,55,0.2)
- Gold Button: 0px 4px 12px rgba(212,175,55,0.35)
- FAB: 0px 8px 24px rgba(59,130,246,0.4)

Border Radius:
- Cards: 12px (standard), 16px (featured)
- Buttons: 12px
- Badges: 6px
- FAB: 50% (circular)

Animations:
- Listening pulse: Blue dot, 1.5s cycle, opacity 0.3-1.0
- Button hover: Scale 1.02, 200ms ease-out
- FAB hover: Scale 1.05, 150ms ease-out

---

DESIGN PRINCIPLES:

1. YOUVERSION INSPIRATION:
   - Clean white space
   - Serif font for scripture (Georgia)
   - Content-focused layout
   - Minimal chrome
   - Familiar Bible app patterns

2. QUICKVERSE MODERNITY:
   - Card-based layouts with depth
   - Gradient buttons (gold for primary)
   - Modern shadows and elevation
   - Clean iconography (SF Symbols)

3. DIVINE LINK IDENTITY:
   - Gold accent #D4AF37 is signature (non-negotiable)
   - Mission-control aesthetic (calm, professional)
   - Large operator-friendly buttons (56px height)
   - Human-in-the-loop design (clear approval states)
   - Native macOS feel (not web-like)

4. CURRENT DL ELEMENTS TO PRESERVE:
   - Audio control bar with Audio/Speech/Bible Version/Detect
   - Ad sidebar placement (right side, 200px)
   - Bottom banner ad space
   - Logo and branding

---

LAYOUT PROPORTIONS (Critical for Desktop Feel):

Based on Gemini mockup proportions:
- Header bar: ~7% of height (60px of 900px)
- Audio controls: ~5% of height (48px)
- Live transcript card: ~25% of content area
- Pending scripture card: ~40% of content area (PRIMARY FOCUS)
- Action buttons: ~15% of content area

Horizontal split:
- Main content: 83% width (1040px of 1240px content area)
- Ad sidebar: 17% width (200px)

---

OUTPUT REQUIREMENTS:

Generate a high-fidelity desktop macOS mockup showing:

1. ✅ Wide desktop format (1440x900px), NOT mobile
2. ✅ Native macOS window chrome (traffic lights)
3. ✅ Divine Link circular gold logo (top-left)
4. ✅ Audio control bar with 4 buttons (Audio, Speech, KJV dropdown, Detect)
5. ✅ Live transcription card (light gray, subtle)
6. ✅ Featured scripture card (white, gold 3px border, glow shadow)
7. ✅ Romans 8:28 as example verse
8. ✅ 3 action buttons (Push to ProPresenter in gold gradient, Ignore, Pause)
9. ✅ Blue circular FAB (bottom-right, search icon)
10. ✅ Right sidebar with 3 ad placeholders + "Remove Ads" button
11. ✅ Bottom banner ad space (60px height)
12. ✅ All exact colors from palette (#D4AF37 gold, #3B82F6 blue)
13. ✅ Proper shadows and depth
14. ✅ Desktop proportions (wide, spacious, not cramped)

STYLE: Modern macOS Big Sur+ native app with YouVersion's clean aesthetic and
QuickVerse's polished card-based design, maintaining Divine Link's gold signature.
```

---

## 🎯 SIMPLIFIED VERSION (If Above is Too Detailed)

```
Create a wide desktop macOS app UI (1440x900px) for Divine Link scripture software.

LAYOUT:
- Left: Main content (1040px) with header, audio controls bar, live transcript card,
  featured scripture card (Romans 8:28 with GOLD border #D4AF37), and 3 action buttons
- Right: Ad sidebar (200px) with 3 ad placeholders
- Bottom: Banner ad (60px)

KEY ELEMENTS:
1. Header: Divine Link logo (circular gold) + "Listening" status + settings icon
2. Audio bar: 4 buttons (Audio, Speech, "KJV ▼" dropdown, Detect) - same as current app
3. Transcript card: Light gray (#F9FAFB), shows live text
4. Scripture card: WHITE with 3px GOLD border (#D4AF37), large verse text, confidence badge
5. Buttons: "Push to ProPresenter" (gold gradient), "Ignore" (gray), "Pause" (white)
6. FAB: Blue circular search button (bottom-right)

COLORS:
- Gold: #D4AF37 (main accent)
- Blue: #3B82F6 (active states)
- Gray scale: #1F2937, #374151, #6B7280, #E5E7EB, #F9FAFB, #FFFFFF

STYLE: YouVersion clean + QuickVerse modern cards + Native macOS + Desktop proportions
```

---

## 📊 COMPARISON TO WHAT YOU SHOWED ME:

**What Works (Keep from Gemini version):**
- ✅ Wide desktop layout (not narrow/mobile)
- ✅ Good card proportions
- ✅ Spacing annotations (24px, 16px)
- ✅ Overall structure

**What to Add:**
- ➕ Your circular gold logo (from current app)
- ➕ Audio control bar (Audio/Speech/KJV/Detect buttons)
- ➕ Ad sidebar on right (200px)
- ➕ Bottom banner ad space
- ➕ Manual search FAB (blue circle, bottom-right)
- ➕ More polish (shadows, gradients)

**What to Avoid (From Stitch versions):**
- ❌ Too narrow/mobile proportions
- ❌ Missing audio controls
- ❌ Generic logos

---

## 🚀 NEXT STEPS:

1. **Copy the Master Prompt V2** above into Stitch or Gemini
2. **Share the output** with me
3. **I'll provide refinements** to get it perfect
4. **Iterate 1-2 more times** until it matches the Epic 8 vision

The Gemini version was close - we just need to add your specific UI elements and refine the polish!

Ready to see what this refined prompt produces? 🎨
