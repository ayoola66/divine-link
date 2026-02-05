# Epic 6: Implementation & Testing Guide

**Target Version:** v1.2.0  
**Last Updated:** February 2026

This guide provides step-by-step implementation order with detailed testing instructions for each story. These instructions can also serve as user documentation for manual setup.

---

## Prerequisites

Before starting, ensure you have:

### On Your Mac (Development)
- [ ] Xcode installed and working
- [ ] Divine Link project opens without errors
- [ ] Can build and run Divine Link app

### ProPresenter Setup
- [ ] ProPresenter 7+ installed (any version 7.x through 21.x)
- [ ] ProPresenter can launch and display slides
- [ ] Have a test presentation with at least one slide

---

## Implementation Order

| Order | Story | Complexity | Est. Hours | Status |
|-------|-------|------------|------------|--------|
| 1 | 6.1 Panic Button | Small | 2-4 | ✅ **Complete** |
| 2 | 6.2 Confidence Indicator | Medium | 4-8 | ✅ **Complete** |
| 3 | 6.4 WebSocket Messages API | Large | 16-20 | ✅ **Complete** |
| 4 | 6.5 Hybrid Integration Manager | Large | 20-24 | ✅ **Complete** |

---

## Epic 6 Implementation Summary (February 2026)

### Completed Files

**New Files Created:**
- `ProPresenterOutputProtocol.swift` - Protocol, factory, and types for output abstraction
- `Outputs/StageDisplayOutput.swift` - HTTP REST output implementation
- `Outputs/AudienceWebSocketOutput.swift` - WebSocket Messages API implementation
- `Outputs/AudienceKeyboardOutput.swift` - Keyboard automation implementation
- `HybridIntegrationManager.swift` - Central coordinator for all outputs

**Files Modified:**
- `ProPresenterSettings.swift` - Added new output path settings
- `ProPresenterSettingsView.swift` - Added output toggles and connection dashboard
- `ProPresenterClient.swift` - Updated ProPresenterError with new cases
- `PanicButtonService.swift` - Integrated HybridIntegrationManager for multi-path clear

---

## Release Automation

Epic 6 includes a new **automated release workflow** for streamlined versioning and distribution.

### Quick Commands

```bash
# One-time setup (configure notarisation credentials)
./scripts/setup-release.sh

# Release commands
./scripts/release.sh patch     # 1.1.0 → 1.1.1 (bug fixes)
./scripts/release.sh minor     # 1.1.0 → 1.2.0 (new features)
./scripts/release.sh major     # 1.1.0 → 2.0.0 (breaking changes)
./scripts/release.sh beta      # 1.1.0 → 1.2.0-beta.1 (pre-release)
```

### What the Release Script Does

1. **Version Bump** - Automatically increments version in Xcode project
2. **Code Signing** - Signs with Developer ID Application certificate
3. **Notarisation** - Submits to Apple and staples the ticket
4. **ZIP Creation** - Creates distribution archive
5. **Sparkle Signing** - Signs with EdDSA for auto-updates
6. **Appcast Update** - Updates appcast.xml with new version
7. **Ready for Deploy** - Just commit and push to trigger Netlify deployment

### Epic 6 Target Version

- **v1.2.0** - Full release with all Epic 6 features
- **v1.2.0-beta.x** - Beta releases during development

---

# Story 6.1: Panic Button & Clear Screen

## Overview
Add an instant "panic button" that clears all displayed scripture from both Divine Link and ProPresenter with a single keypress.

## Implementation Steps

### Step 1: Add Panic Button Service
Create the core service that handles clearing.

### Step 2: Add Keyboard Shortcut
Register `Cmd+Escape` or `F12` as global shortcut.

### Step 3: Add UI Button
Add visible panic button to the main interface.

### Step 4: Integrate with ProPresenter
Connect to existing ProPresenter client to clear Stage Display.

---

## Testing: Story 6.1

### Test 1.1: UI Button Appears
**Location:** Divine Link App  
**What to do:**
1. Build and run Divine Link in Xcode (`Cmd+R`)
2. Wait for app to launch
3. Look at the main window

**Expected Result:**
- [ ] A "Clear" or "Panic" button is visible
- [ ] Button has a distinct colour (red or orange)
- [ ] Button is easily clickable

**If it fails:**
- Check the MainView.swift file for the button code
- Ensure the button isn't hidden behind other elements

---

### Test 1.2: Button Click Clears Local Display
**Location:** Divine Link App  
**What to do:**
1. Run Divine Link
2. Trigger a scripture detection (speak a verse or use test mode)
3. Wait for scripture to appear in Divine Link's preview
4. Click the Panic Button

**Expected Result:**
- [ ] Scripture text disappears from Divine Link immediately
- [ ] Any "currently displayed" indicator clears
- [ ] Button provides visual feedback (flash, colour change, or animation)

**If it fails:**
- Check PanicButtonService.swift for clearLocalDisplay() method
- Verify the button's action is connected to the service

---

### Test 1.3: Keyboard Shortcut Works
**Location:** Divine Link App (can be in background)  
**What to do:**
1. Run Divine Link
2. Trigger a scripture detection so something is displayed
3. Click away from Divine Link (e.g., click on Finder)
4. Press `Cmd+Escape` (or `F12` depending on implementation)

**Expected Result:**
- [ ] Scripture clears even though Divine Link isn't focused
- [ ] Works from any application
- [ ] No conflict with other system shortcuts

**If it fails:**
- Check that global keyboard shortcut is registered
- Verify Accessibility permissions are granted
- System Preferences → Security & Privacy → Accessibility → Divine Link ✓

---

### Test 1.4: Clears ProPresenter Stage Display (Requires PP)
**Location:** Divine Link App + ProPresenter  
**Setup Required:**

**In ProPresenter:**
1. Launch ProPresenter
2. Go to **Preferences** → **Network**
3. Enable **"Network"** toggle (if not already on)
4. Note the **Port** number (default: 1025)
5. Optionally set a **Password** (or leave blank for local testing)

**In Divine Link:**
1. Go to **Settings** (gear icon or menu)
2. Find **ProPresenter Connection** section
3. Enter:
   - Host: `localhost` (or `127.0.0.1`)
   - Port: `1025` (or your custom port)
   - Password: (leave blank or enter your password)
4. Click **Connect** or **Test Connection**

**What to do:**
1. In ProPresenter, display a slide on Stage Display
2. In Divine Link, trigger a scripture detection
3. Verify the Stage Display shows the scripture message
4. Press the Panic Button (or `Cmd+Escape`)

**Expected Result:**
- [ ] ProPresenter Stage Display message clears
- [ ] Divine Link shows "Cleared" confirmation
- [ ] Both apps return to neutral state

**If it fails:**
- Check ProPresenter → Screens → Stage Display is configured
- Verify Divine Link is connected (Settings should show "Connected")
- Check Console.app for any error messages from Divine Link

---

### Test 1.5: Clears ProPresenter Audience Screen (Requires PP)
**Location:** Divine Link App + ProPresenter  
**Setup Required:**

This test verifies the keyboard automation path (⌘B) clears the Bible view.

**In ProPresenter:**
1. Ensure you have a Bible configured (any translation)
2. Display a verse using ProPresenter's Bible feature
3. The verse should be showing on the Audience screen

**In Divine Link (Accessibility Setup - One Time):**
1. Go to **System Preferences** → **Security & Privacy** → **Privacy** tab
2. Select **Accessibility** in the left sidebar
3. Click the **lock icon** and enter your password
4. Find **Divine Link** in the list and tick the checkbox
5. If Divine Link isn't listed, click **+** and add it from Applications

**What to do:**
1. Ensure a Bible verse is displayed on ProPresenter Audience screen
2. Make sure Divine Link has detected/pushed a verse
3. Press the Panic Button (or `Cmd+Escape`)

**Expected Result:**
- [ ] ProPresenter Audience screen clears the Bible display
- [ ] ProPresenter returns to slides (or black if no slides)
- [ ] This works even if ProPresenter is in the background

**If it fails:**
- Verify Accessibility permissions are granted
- Check that keyboard shortcut `Cmd+B` clears Bible in ProPresenter manually
- Ensure ProPresenter window exists (can be minimised but must be running)

---

### Test 1.6: Visual Feedback and Status
**Location:** Divine Link App  
**What to do:**
1. Press Panic Button multiple times quickly
2. Observe the UI response

**Expected Result:**
- [ ] Button doesn't freeze or become unresponsive
- [ ] Status indicator shows when clearing is in progress
- [ ] Status shows "Cleared" or returns to normal after clearing
- [ ] No duplicate clear commands sent

---

## Story 6.1 Sign-Off Checklist

Before moving to Story 6.2, verify:

- [ ] Panic Button visible in UI
- [ ] Click clears local Divine Link display
- [ ] Keyboard shortcut (`Cmd+Escape`) works globally
- [ ] ProPresenter Stage Display clears (if connected)
- [ ] ProPresenter Audience clears via keyboard automation
- [ ] Visual feedback provided
- [ ] No crashes or freezes

---

# Story 6.2: Detection Confidence Indicator

## Overview
Show operators how confident the AI is about detected verses, so they can intervene if needed.

## Implementation Steps

### Step 1: Add Confidence Scoring
Calculate match confidence based on word matching.

### Step 2: Add Visual Indicator
Show Low/Medium/High confidence with colours.

### Step 3: Add Live Visualiser (Enhanced)
Real-time confidence bar during detection.

---

## Testing: Story 6.2

### Test 2.1: Confidence Levels Display
**Location:** Divine Link App  
**What to do:**
1. Run Divine Link
2. Trigger scripture detection with a clear verse (e.g., "John 3:16")
3. Observe the detected verse display

**Expected Result:**
- [ ] Confidence indicator visible (text, colour, or bar)
- [ ] High confidence verses show green indicator
- [ ] Clear match shows "High" or similar label

---

### Test 2.2: Low Confidence Warning
**Location:** Divine Link App  
**What to do:**
1. Speak a partial or unclear verse reference
2. Example: "something about loving the world" (no specific reference)
3. Observe the detected verse display

**Expected Result:**
- [ ] Low confidence indicator shows (yellow/orange)
- [ ] Visual distinction from high confidence
- [ ] Operator can see this needs verification

---

### Test 2.3: Confidence Threshold Behaviour
**Location:** Divine Link App → Settings  
**What to do:**
1. Go to Settings → Detection section
2. Find "Minimum Confidence" or similar setting
3. Set to "High only"
4. Trigger a low-confidence detection

**Expected Result:**
- [ ] Low confidence verses don't auto-push to ProPresenter
- [ ] They still appear in Divine Link with warning
- [ ] Operator can manually approve and push

---

### Test 2.4: Live Confidence Visualiser (Enhanced Feature)
**Location:** Divine Link App  
**What to do:**
1. Start continuous detection mode
2. Speak slowly and clearly: "The book of John, chapter three, verse sixteen"
3. Watch the UI as you speak

**Expected Result:**
- [ ] Confidence bar/indicator updates in real-time
- [ ] Increases as more words match
- [ ] Visual feedback during speech

---

## Story 6.2 Sign-Off Checklist

Before moving to Story 6.4, verify:

- [ ] Confidence indicator visible on all detected verses
- [ ] Colour coding works (green=high, yellow=medium, red=low)
- [ ] Low confidence verses visually distinct
- [ ] Settings for confidence threshold work
- [ ] Live visualiser updates during detection (if implemented)

---

# Story 6.4: WebSocket Messages API

## Overview
Implement the Factory Pattern for ProPresenter outputs and add WebSocket-based Messages API for Audience screen display.

## Implementation Steps

### Step 1: Create Factory Pattern
ProPresenterOutputFactory with three output types.

### Step 2: Implement AudienceWebSocketOutput
WebSocket connection and messageSend/messageHide.

### Step 3: Update Settings UI
Add toggle for Messages API, template selection.

---

## Testing: Story 6.4

### Test 4.1: Factory Creates Correct Outputs
**Location:** Divine Link App (Unit Test or Debug)  
**What to do:**
1. In Xcode, run unit tests for ProPresenterOutputFactory
2. Or add debug logging to verify output creation

**Expected Result:**
- [ ] Factory creates StageDisplayOutput for .stageDisplay
- [ ] Factory creates AudienceWebSocketOutput for .audienceWebSocket
- [ ] Factory creates AudienceKeyboardOutput for .audienceKeyboard

---

### Test 4.2: WebSocket Connection (Requires PP)
**Location:** Divine Link App + ProPresenter  
**Setup Required:**

**In ProPresenter:**
1. Go to **Preferences** → **Network**
2. Enable **"Network"** toggle
3. Note the Port (default: 1025)
4. Set a **Password** (required for WebSocket authentication)

**In Divine Link:**
1. Go to **Settings** → **ProPresenter**
2. Enter Host, Port, Password
3. Enable **"Use Messages API"** toggle (new setting)

**What to do:**
1. Save settings
2. Check connection status indicator

**Expected Result:**
- [ ] Status shows "WebSocket Connected" or similar
- [ ] No error messages in console
- [ ] Connection indicator is green

**If it fails:**
- Verify password is correct
- Check ProPresenter console for connection attempts
- Ensure port isn't blocked by firewall

---

### Test 4.3: Messages API Sends to Audience (Requires PP + Looks Setup)
**Location:** Divine Link App + ProPresenter  
**Setup Required:**

**In ProPresenter - Create Message Template:**
1. Go to **Messages** in the main toolbar
2. Click **+** to create a new Message
3. Name it "Divine Link Scripture" or similar
4. Add two text boxes:
   - First box: Type `${Reference}` (this will show "John 3:16")
   - Second box: Type `${ScriptureText}` (this will show the verse text)
5. Style the boxes (font, colour, position) to match your church branding
6. Save the Message

**In ProPresenter - Enable Messages in Looks:**
1. Go to **Screens** → **Edit Looks**
2. Select your Audience Look (or create a new one)
3. Find the **Messages** row in the layer list
4. Check the box under your **Audience screen** column
5. Click **"Make Live"** to apply

**In Divine Link:**
1. Settings → ProPresenter → Enable "Use Messages API"
2. Select the message template index (usually 0 for first template)
3. Save settings

**What to do:**
1. Trigger a scripture detection in Divine Link
2. Watch the ProPresenter Audience screen

**Expected Result:**
- [ ] Scripture appears on Audience screen via Messages layer
- [ ] Reference shows in the ${Reference} placeholder
- [ ] Verse text shows in the ${ScriptureText} placeholder
- [ ] Styling matches your Message template design

**If it fails:**
- Check Messages layer is enabled in active Look
- Verify message template has correct placeholders
- Check Divine Link console for WebSocket errors
- Try triggering messageSend manually via API tester

---

### Test 4.4: Message Clears Correctly
**Location:** Divine Link App + ProPresenter  
**What to do:**
1. Display a verse via Messages API (Test 4.3)
2. Trigger a new verse detection
3. Or press Panic Button

**Expected Result:**
- [ ] Previous message clears before new one appears
- [ ] No overlapping text on screen
- [ ] Panic Button clears Messages layer completely

---

### Test 4.5: Tier Gating Works
**Location:** Divine Link App  
**What to do:**
1. Ensure subscription is set to "Mercy" (free tier)
2. Go to Settings → ProPresenter
3. Look for "Use Messages API" option

**Expected Result:**
- [ ] Option is disabled or hidden for Mercy tier
- [ ] Shows message like "Upgrade to Grace for Messages API"
- [ ] Keyboard automation still works

**Then:**
1. Change subscription to "Grace" or "Love" (test mode)
2. Check the same setting

**Expected Result:**
- [ ] "Use Messages API" option is now available
- [ ] Can toggle it on and configure

---

## Story 6.4 Sign-Off Checklist

Before moving to Story 6.5, verify:

- [ ] Factory Pattern creates all three output types
- [ ] WebSocket connects with correct password
- [ ] Messages API displays on Audience screen
- [ ] Message template placeholders work (${Reference}, ${ScriptureText})
- [ ] Messages clear correctly
- [ ] Tier gating restricts free users

---

# Story 6.5: Hybrid Integration Manager

## Overview
Orchestrate all three output paths with automatic fallbacks and connection health monitoring.

## Implementation Steps

### Step 1: Create HybridIntegrationManager
Central coordinator for all outputs.

### Step 2: Implement Path Decision Engine
Choose WebSocket vs Keyboard based on availability.

### Step 3: Add Connection Health Dashboard
Show status of all three paths in Settings.

### Step 4: Add Messages Layer Detection
Check if Looks has Messages layer enabled.

### Step 5: Add Setup Guide UI
Step-by-step guide for ProPresenter setup.

---

## Testing: Story 6.5

### Test 5.1: Connection Dashboard Shows All Paths
**Location:** Divine Link App → Settings  
**What to do:**
1. Go to Settings → ProPresenter section
2. Look for "Connection Status" or "Integration Dashboard"

**Expected Result:**
- [ ] Stage Display (HTTP) status visible
- [ ] Audience API (WebSocket) status visible
- [ ] Keyboard Automation status visible
- [ ] Each shows connected/disconnected state
- [ ] Refresh button updates statuses

---

### Test 5.2: Automatic Path Selection
**Location:** Divine Link App  
**Setup:** Premium tier + WebSocket connected  
**What to do:**
1. Trigger a scripture detection
2. Check which path was used (debug log or status)

**Expected Result:**
- [ ] Uses WebSocket Messages API (preferred for premium)
- [ ] Status shows "Sent via Messages API"

---

### Test 5.3: Automatic Fallback to Keyboard
**Location:** Divine Link App + ProPresenter  
**What to do:**
1. Disconnect WebSocket (disable Network in PP, or enter wrong password)
2. Trigger a scripture detection

**Expected Result:**
- [ ] Divine Link detects WebSocket is unavailable
- [ ] Falls back to Keyboard automation automatically
- [ ] Shows notification: "Using keyboard fallback"
- [ ] Scripture still appears on Audience screen

---

### Test 5.4: Messages Layer Detection
**Location:** Divine Link App + ProPresenter  
**What to do:**
1. In ProPresenter, disable Messages layer in your Audience Look
2. In Divine Link, go to Settings → ProPresenter
3. Click "Check Status" or "Refresh"

**Expected Result:**
- [ ] Shows "Messages layer not enabled"
- [ ] Offers to show Setup Guide
- [ ] Falls back to keyboard automatically

**Then:**
1. In ProPresenter, re-enable Messages layer in Audience Look
2. Click "Check Status" again

**Expected Result:**
- [ ] Shows "Messages layer enabled"
- [ ] Ready indicator turns green

---

### Test 5.5: Setup Guide Flow
**Location:** Divine Link App  
**What to do:**
1. Go to Settings → ProPresenter
2. If Messages layer shows as disabled, click "Show Setup Guide"
3. Follow each step in the guide

**Expected Result:**
- [ ] Guide has clear numbered steps
- [ ] Step 1: Open ProPresenter Screens
- [ ] Step 2: Select Audience Look
- [ ] Step 3: Enable Messages layer
- [ ] Step 4: Create Message template
- [ ] Step 5: Test connection
- [ ] Navigation (Next/Back) works
- [ ] "Done" returns to settings

---

### Test 5.6: Panic Button Clears All Paths
**Location:** Divine Link App + ProPresenter  
**What to do:**
1. Display scripture on both Stage Display and Audience screen
2. Press Panic Button

**Expected Result:**
- [ ] Stage Display clears (HTTP DELETE)
- [ ] Audience screen clears (messageHide or keyboard)
- [ ] Both clear nearly simultaneously
- [ ] Divine Link shows "All cleared"

---

### Test 5.7: Both Outputs Work Together
**Location:** Divine Link App + ProPresenter  
**Setup:** Stage Display enabled + Audience Messages API enabled  
**What to do:**
1. In Settings, enable both Stage Display and Audience output
2. Trigger a scripture detection

**Expected Result:**
- [ ] Scripture appears on Stage Display (confidence monitor)
- [ ] Scripture appears on Audience screen (via Messages API)
- [ ] Both display the same verse
- [ ] Reference and text match on both screens

---

## Story 6.5 Sign-Off Checklist

Final verification for Epic 6:

- [ ] Connection dashboard shows all three paths
- [ ] Path decision engine selects correct output
- [ ] Automatic fallback from WebSocket to Keyboard works
- [ ] Messages layer detection works
- [ ] Setup guide is clear and complete
- [ ] Panic Button clears all paths
- [ ] Both Stage and Audience can display simultaneously

---

# ProPresenter Setup Reference (User Documentation)

This section can be provided to end users for manual setup.

## Enabling Network API

1. Open **ProPresenter**
2. Go to **Preferences** (Cmd+,)
3. Select **Network** tab
4. Toggle **"Network"** to ON
5. Note the **Port** number (default: 1025)
6. Set a **Password** for security (recommended)
7. Click **Save** or close Preferences

## Enabling Messages on Audience Screen

1. Go to **Screens** menu → **Edit Looks**
2. Select your **Audience Look** preset (or click + to create new)
3. In the layer grid, find the **Messages** row
4. Check the box under your **Audience screen** column
5. Click **"Make Live"** to apply immediately

## Creating a Scripture Message Template

1. Go to **Messages** in the main toolbar
2. Click **+** to create a new Message
3. Name it "Divine Link Scripture"
4. Add a text box for the reference:
   - Type: `${Reference}`
   - Position at top of screen
   - Choose your font and size
5. Add a text box for the verse text:
   - Type: `${ScriptureText}`
   - Position below the reference
   - Choose your font and size
6. Style to match your church branding
7. Save the Message

## Connecting Divine Link

1. Open **Divine Link** on your Mac
2. Go to **Settings** → **ProPresenter**
3. Enter:
   - **Host:** `localhost` (same computer) or IP address (different computer)
   - **Port:** Your ProPresenter port (default: 1025)
   - **Password:** Your ProPresenter network password
4. Enable **"Stage Display"** for confidence monitor
5. Enable **"Use Messages API"** for Audience screen (Grace/Love tiers)
6. Select your **Message Template** index (usually 0)
7. Click **Save** and verify connection status shows green

## Troubleshooting

### "Connection Failed"
- Verify ProPresenter is running
- Check port number matches
- Verify password is correct
- Ensure both apps are on same network

### "Messages Not Appearing on Audience"
- Verify Messages layer is enabled in your Audience Look
- Check that the Look is "Live"
- Verify Message template has correct placeholders
- Try displaying a Message manually in ProPresenter first

### "Keyboard Automation Not Working"
- Grant Accessibility permissions to Divine Link
- System Preferences → Security & Privacy → Privacy → Accessibility
- Ensure ProPresenter is running (can be minimised)

---

# Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Feb 2026 | Initial Epic 6 implementation guide |
