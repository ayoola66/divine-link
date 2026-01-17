# Divine Link - Master Figma Prompt

Copy and paste the entire prompt below into Figma's AI wireframe generator.

---

## THE PROMPT

```
Design a complete macOS desktop application called "Divine Link" - a real-time scripture detection tool for church services. The app listens to sermons, detects Bible references, and lets operators push verses to ProPresenter.

DESIGN SYSTEM:
- Style: Clean, minimal, macOS-native feel
- Primary colour: #2563EB (blue) for active states
- Accent colour: #D4A853 (gold/amber) for pending scripture cards
- Background: #FFFFFF (white) with #F5F5F5 (light grey) for secondary areas
- Text: #1A1A1A (near black) primary, #6B7280 (grey) secondary
- Font: SF Pro or system sans-serif
- Corner radius: 8px for cards, 6px for buttons
- Window size: 480px wide, flexible height
- Include macOS traffic lights (red/yellow/green) on all windows

CREATE THESE SCREENS:

SCREEN 1: MAIN WINDOW - LISTENING STATE
Single window with header bar showing "Divine Link" logo (book with microphone icon), status text "Listening" with green dot indicator, and settings gear icon. Below header: Zone 1 shows live transcription text in grey italic ("...and so when we look at the scriptures, we see that God's love is revealed..."). Zone 2 is an empty state with dashed border, magnifying glass icon, and text "Listening for scriptures...". Zone 3 has three buttons: "Push to ProPresenter" (disabled, grey), "Ignore" (disabled), "Pause" (active). Show keyboard shortcuts under buttons: Enter, Esc, Space.

SCREEN 2: MAIN WINDOW - PENDING VERSE STATE  
Same layout but Zone 2 now shows a scripture card with gold/amber border. Card header: "DETECTED SCRIPTURE (PENDING)" with three-dot menu. Content: Book icon, "Romans 8:28" in bold, verse text in blue "And we know that in all things God works for the good of those who love him, who have been called according to his purpose." and "Berean Standard Bible" as translation. The "Push to ProPresenter" button is now gold/amber and active. Status in header changes to "Pending Verse".

SCREEN 3: MAIN WINDOW - PAUSED STATE
Muted/greyed version of the interface. Status shows "Paused". Zone 2 shows pause icon with "Listening paused" text. The "Pause" button changes to "Resume" with play icon. Other buttons remain disabled.

SCREEN 4: SETTINGS WINDOW - AUDIO TAB
Separate settings window with macOS traffic lights and title "Settings". Three tabs: Audio (selected), ProPresenter, About. Audio section shows: "Audio Input" heading, "Input Device" dropdown showing "Built-in Microphone", info callout "Want to capture system audio? Install BlackHole (free) →" with arrow link. Below: "Test" section with "Input Level" label and audio level meter (gradient from green to yellow to red).

SCREEN 5: SETTINGS WINDOW - PROPRESENTER TAB
Same settings window, ProPresenter tab selected. "Connection" section with "IP Address" text field showing "192.168.1.100" with validation error "Invalid IP address" in red below. "Port" field showing "1025". "Status" section showing green dot with "Connected" text and IP:port, plus "Test Connection" button.

SCREEN 6: SETTINGS WINDOW - ABOUT TAB
Same settings window, About tab selected. Centred content: Large Divine Link logo (book with microphone), "Divine Link" title, "Version 1.0.0", tagline "Real-time scripture detection for ProPresenter", copyright "© 2026 Divine Link".

SCREEN 7: ERROR MODAL - PUSH FAILED
Native macOS alert dialog overlaying darkened background. Amber/yellow warning triangle icon, "Push Failed" title, message "Unable to send to ProPresenter. Check your connection settings." Two buttons: "Dismiss" (secondary) and "Retry" (primary blue).

SCREEN 8: ONBOARDING - AUDIO SETUP WIZARD
Welcome window with "Welcome to Divine Link" title, subtitle "How should Divine Link hear the sermon?". Three selectable cards stacked vertically: 1) Microphone icon, "Use my Mac's microphone", "Simple setup, may pick up room noise". 2) Speaker icon, "Capture system audio" with "RECOMMENDED" badge, "Cleanest audio - requires BlackHole". 3) Sliders icon, "I have a professional audio setup", "Audio interface or mixing desk". Bottom: "Dismiss" and "Retry" buttons, plus "Skip for now →" link.

SCREEN 9: MENU BAR CONTEXT MENU
macOS menu bar dropdown menu. Items: Divine Link logo with "Show Divine Link", separator, "Pause Listening", "Capture system audio" (checked, with RECOMMENDED badge), "I have a professional audio setup" with ⌘I shortcut, separator, "Quit Divine Link" with ⌘Q shortcut.

SCREEN 10: SCRIPTURE CARD COMPONENT STATES
Show three variations of the scripture card component stacked vertically: 1) Gold border, "Romans 8:28", full verse, "Berean Standard Bible", three filled dots (first in queue). 2) Gold border, "Philippians 4:13", "I can do all things through Christ who strengthens me.", "New King James Version", two filled dots one empty (second in queue). 3) Gold border but labelled "(REVIEW)" instead of "(PENDING)", "Psalm 23:1", "The Lord is my shepherd; I shall not want.", "English Standard Version", one filled dot two empty (third in queue).

Make all screens interactive with proper component states, hover effects, and clickable buttons. Group related elements. Use auto-layout where appropriate. Create this as a complete prototype flow.
```

---

## Tips for Using This Prompt

1. **If Figma's AI has a character limit**, try pasting just the Design System + 2-3 screens at a time
2. **The prompt asks for interactive elements** - Figma should create clickable prototypes
3. **After generation**, you can manually link the screens together for a prototype flow

---

## Word Count

The prompt above is approximately **850 words** - most AI design tools can handle this, but if Figma truncates it, let me know and I'll create a shorter version.
