#!/bin/bash
#
# generate-screenshots.sh
# Divine Link Screenshot Generator (v2 — Marketing & App Store)
#
# Captures screenshots of Divine Link for website, social media (Epic 9),
# and Mac App Store listing. Run with the app open and configured.
#
# Usage: ./scripts/generate-screenshots.sh
#
# Output: docs/wireframes/app-screenshots/<timestamp>/
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="$PROJECT_ROOT/docs/wireframes/app-screenshots/$TIMESTAMP"
SCREENSHOT_DELAY=2

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

clear
echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║      Divine Link Screenshot Generator v2.0                   ║${NC}"
echo -e "${BOLD}║      Marketing • Website • App Store                         ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${DIM}Output: $OUTPUT_DIR${NC}"
echo ""

mkdir -p "$OUTPUT_DIR"

# Check if Divine Link is running
if ! pgrep -x "Divine Link" > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠  Divine Link is not running.${NC}"
    echo ""
    echo "   Please launch Divine Link and ensure:"
    echo "   • You are signed in (for full feature access)"
    echo "   • ProPresenter connection is configured"
    echo "   • Audio device is selected"
    echo "   • At least one past service exists in history"
    echo "   • At least one pastor profile exists"
    echo ""
    read -p "   Press Enter when Divine Link is ready..."
fi

# Capture counters
TOTAL=0
CAPTURED=0
SKIPPED=0

# ─── Capture Functions ───

capture_window() {
    local name=$1
    local description=$2
    local filename="$OUTPUT_DIR/${name}.png"
    TOTAL=$((TOTAL + 1))

    echo ""
    echo -e "  ${BLUE}[$TOTAL]${NC} ${BOLD}$name${NC}"
    echo -e "  ${DIM}$description${NC}"
    echo ""
    echo -e "  ${YELLOW}Enter${NC} = capture window  |  ${YELLOW}skip${NC} = skip  |  ${YELLOW}quit${NC} = stop"
    read -p "  > " response

    if [[ "$response" == "quit" ]]; then
        echo -e "\n  ${RED}Stopping early.${NC}"
        print_summary
        exit 0
    fi
    if [[ "$response" == "skip" ]]; then
        echo -e "  ${DIM}⏭  Skipped${NC}"
        SKIPPED=$((SKIPPED + 1))
        return
    fi

    echo -e "  Capturing in ${SCREENSHOT_DELAY}s..."
    sleep $SCREENSHOT_DELAY
    screencapture -wo "$filename"

    if [[ -f "$filename" ]]; then
        dims=$(sips -g pixelWidth -g pixelHeight "$filename" 2>/dev/null | tail -2 | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
        echo -e "  ${GREEN}✓${NC} Saved ($dims)"
        CAPTURED=$((CAPTURED + 1))
    else
        echo -e "  ${RED}✗${NC} Capture failed or cancelled"
    fi
}

capture_fullscreen() {
    local name=$1
    local description=$2
    local filename="$OUTPUT_DIR/${name}.png"
    TOTAL=$((TOTAL + 1))

    echo ""
    echo -e "  ${CYAN}[$TOTAL]${NC} ${BOLD}$name${NC} ${DIM}(full screen)${NC}"
    echo -e "  ${DIM}$description${NC}"
    echo ""
    echo -e "  ${YELLOW}Enter${NC} = capture screen  |  ${YELLOW}skip${NC} = skip  |  ${YELLOW}quit${NC} = stop"
    read -p "  > " response

    if [[ "$response" == "quit" ]]; then
        echo -e "\n  ${RED}Stopping early.${NC}"
        print_summary
        exit 0
    fi
    if [[ "$response" == "skip" ]]; then
        echo -e "  ${DIM}⏭  Skipped${NC}"
        SKIPPED=$((SKIPPED + 1))
        return
    fi

    echo -e "  Capturing in ${SCREENSHOT_DELAY}s..."
    sleep $SCREENSHOT_DELAY
    screencapture "$filename"

    if [[ -f "$filename" ]]; then
        dims=$(sips -g pixelWidth -g pixelHeight "$filename" 2>/dev/null | tail -2 | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
        echo -e "  ${GREEN}✓${NC} Saved ($dims)"
        CAPTURED=$((CAPTURED + 1))
    else
        echo -e "  ${RED}✗${NC} Capture failed or cancelled"
    fi
}

capture_region() {
    local name=$1
    local description=$2
    local filename="$OUTPUT_DIR/${name}.png"
    TOTAL=$((TOTAL + 1))

    echo ""
    echo -e "  ${CYAN}[$TOTAL]${NC} ${BOLD}$name${NC} ${DIM}(select region)${NC}"
    echo -e "  ${DIM}$description${NC}"
    echo ""
    echo -e "  ${YELLOW}Enter${NC} = select region  |  ${YELLOW}skip${NC} = skip  |  ${YELLOW}quit${NC} = stop"
    read -p "  > " response

    if [[ "$response" == "quit" ]]; then
        echo -e "\n  ${RED}Stopping early.${NC}"
        print_summary
        exit 0
    fi
    if [[ "$response" == "skip" ]]; then
        echo -e "  ${DIM}⏭  Skipped${NC}"
        SKIPPED=$((SKIPPED + 1))
        return
    fi

    echo -e "  Draw a rectangle around the area to capture..."
    screencapture -is "$filename"

    if [[ -f "$filename" ]]; then
        dims=$(sips -g pixelWidth -g pixelHeight "$filename" 2>/dev/null | tail -2 | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
        echo -e "  ${GREEN}✓${NC} Saved ($dims)"
        CAPTURED=$((CAPTURED + 1))
    else
        echo -e "  ${RED}✗${NC} Capture cancelled"
    fi
}

section_header() {
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  $1${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_summary() {
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  COMPLETE${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}✓ Captured:${NC} $CAPTURED"
    echo -e "  ${YELLOW}⏭ Skipped:${NC}  $SKIPPED"
    echo -e "  Total:     $TOTAL"
    echo ""
    echo -e "  ${BOLD}Saved to:${NC}"
    echo -e "  $OUTPUT_DIR"
    echo ""

    if [[ $CAPTURED -gt 0 ]]; then
        echo -e "  ${BOLD}Files:${NC}"
        for f in "$OUTPUT_DIR"/*.png; do
            if [[ -f "$f" ]]; then
                size=$(ls -lh "$f" | awk '{print $5}')
                dims=$(sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null | tail -2 | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
                echo -e "  • $(basename "$f")  ${DIM}($dims, $size)${NC}"
            fi
        done
        echo ""
    fi
}


# ═══════════════════════════════════════════════════════════════
#  SECTION 1: HERO SHOTS (Best for website homepage & marketing)
# ═══════════════════════════════════════════════════════════════

section_header "SECTION 1: HERO SHOTS — Website & Social Media"

capture_window "01-hero-listening" \
"Main window in LISTENING state — clean, ready to detect.
   SETUP: Start a session, audio active (green mic indicator),
   no verses detected yet. Shows the app in its 'ready' state."

capture_window "02-hero-verse-detected" \
"THE MONEY SHOT — A Bible verse has just been detected.
   SETUP: Have at least one verse detected and visible in the list.
   Show a high-confidence verse (e.g. John 3:16) with the
   confidence indicator visible. Verse should be selected/highlighted."

capture_window "03-hero-verse-pushed" \
"Verse successfully pushed to ProPresenter — green success state.
   SETUP: Push a verse to ProPresenter so the row shows the green
   checkmark / 'Pushed' indicator. Shows the complete workflow."

capture_window "04-hero-multiple-verses" \
"Multiple verses detected during a session.
   SETUP: Have 3-5 verses detected and visible in the scrollable list.
   Mix of pushed and pending verses. Shows real-world usage."

capture_window "05-hero-multi-verse-expanded" \
"Multi-verse reference expanded (e.g. Romans 8:28-30).
   SETUP: Detect a verse range. Expand the row to show all individual
   verses with the current verse highlighted in gold."

capture_window "06-hero-premium-clean" \
"Premium/paid view with NO ADS — clean, wide interface.
   SETUP: Ensure you are on Grace or Love tier (no ad sidebar).
   Show with at least one verse detected. The 'full-width' experience."


# ═══════════════════════════════════════════════════════════════
#  SECTION 2: FREE VS PREMIUM COMPARISON
# ═══════════════════════════════════════════════════════════════

section_header "SECTION 2: FREE vs PREMIUM — Upgrade Motivation"

capture_window "07-free-tier-with-ads" \
"Free (Mercy) tier showing the ad sidebar.
   SETUP: If possible, switch to free tier or show the ad sidebar
   visible on the right side. Demonstrates what free users see."

capture_window "08-paywall-sheet" \
"Subscription paywall / upgrade prompt.
   SETUP: Trigger the paywall sheet (click 'Upgrade' or try a
   premium feature). Show the Grace/Love tier comparison with
   Monthly/Yearly toggle and benefits grid."


# ═══════════════════════════════════════════════════════════════
#  SECTION 3: KEY FEATURES (for feature spotlight content)
# ═══════════════════════════════════════════════════════════════

section_header "SECTION 3: KEY FEATURES — Feature Spotlights"

capture_window "09-feature-panic-button" \
"Panic Button — the safety net for live services.
   SETUP: Show the red 'Clear' panic button in the main window.
   If possible, show it in its idle (red) state with the keyboard
   shortcut hint visible."

capture_window "10-feature-panic-cleared" \
"Panic Button ACTIVATED — green 'Cleared' overlay.
   SETUP: Click the panic button so the green 'Cleared' overlay
   or feedback appears. Shows it working."

capture_window "11-feature-confidence-indicators" \
"Confidence indicators on detected verses.
   SETUP: Show verses with different confidence levels if possible
   (high=green, medium=yellow, low=orange). Or show a single verse
   with its confidence badge clearly visible."

capture_window "12-feature-translation-dropdown" \
"Bible translation selector dropdown.
   SETUP: Click the Bible translation button to show the dropdown
   open with available translations (KJV, ASV, WEB, etc.) and a
   checkmark on the currently selected one."

capture_window "13-feature-transcript-editing" \
"Transcript editing / manual correction.
   SETUP: Show the transcript field in editable mode with 'Detect'
   and 'Cancel' buttons visible. Demonstrates manual override."

capture_window "14-feature-verse-hover-actions" \
"Verse row hover state showing action buttons.
   SETUP: Hover over a detected verse row so the action buttons
   appear (push, copy, dismiss, etc.). Shows the interaction model."


# ═══════════════════════════════════════════════════════════════
#  SECTION 4: SETTINGS & CONFIGURATION
# ═══════════════════════════════════════════════════════════════

section_header "SECTION 4: SETTINGS — Setup & Configuration"

capture_window "15-settings-account-signed-in" \
"Settings > Account tab — signed in state.
   SETUP: Open Settings, go to Account tab. Show profile info,
   subscription badge/tier, and devices list."

capture_window "16-settings-audio" \
"Settings > Audio tab — microphone configuration.
   SETUP: Open Settings, go to Audio tab. Show the device picker
   dropdown, audio level meter, and BlackHole status if applicable."

capture_window "17-settings-audio-testing" \
"Settings > Audio tab — level meter ACTIVE during test.
   SETUP: On the Audio tab, click 'Test Audio' so the level bar
   is animated/moving. Shows real-time audio monitoring."

capture_window "18-settings-propresenter" \
"Settings > ProPresenter tab — connection configured.
   SETUP: Open Settings, go to ProPresenter tab. Show IP/port
   fields filled in and connection status (ideally green/connected)."

capture_window "19-settings-propresenter-dashboard" \
"Settings > ProPresenter — connection dashboard detail.
   SETUP: On the ProPresenter tab, show the status indicators for
   each output type (Stage Display, Messages API, Keyboard Automation)."

capture_window "20-settings-detection" \
"Settings > Detection tab — confidence & context settings.
   SETUP: Open Settings, go to Detection tab. Show context buffer
   settings, confidence indicator toggles, and the confidence preview
   showing high/medium/low examples."

capture_window "21-settings-display" \
"Settings > Display tab — font and appearance.
   SETUP: Open Settings, go to Display tab. Show the font size
   slider and any appearance options."

capture_window "22-settings-panic-button" \
"Settings > ProPresenter — Panic Button configuration.
   SETUP: On the ProPresenter tab, scroll to or show the Panic Button
   settings section with shortcuts and feedback toggles."


# ═══════════════════════════════════════════════════════════════
#  SECTION 5: PASTOR PROFILES
# ═══════════════════════════════════════════════════════════════

section_header "SECTION 5: PASTOR PROFILES — Personalisation"

capture_window "23-pastors-list" \
"Settings > Pastors tab — list of pastor profiles.
   SETUP: Open Settings, go to Pastors tab. Show 2+ pastor profiles
   in the list with learning indicators visible."

capture_window "24-pastors-add-sheet" \
"Add Pastor sheet — creating a new profile.
   SETUP: Click 'Add Pastor' to show the sheet with name field
   and info box about speech learning."

capture_window "25-pastors-speech-corrections" \
"Speech corrections list for a pastor.
   SETUP: Open a pastor's speech corrections. Show several
   corrections listed (e.g. 'genesis' → 'Genesis') sorted by usage."

capture_window "26-pastors-add-correction" \
"Add correction sheet — 'Heard' and 'Corrected' fields.
   SETUP: Click 'Add Correction' within a pastor's corrections.
   Show the input fields with example text."


# ═══════════════════════════════════════════════════════════════
#  SECTION 6: SERVICE HISTORY
# ═══════════════════════════════════════════════════════════════

section_header "SECTION 6: SERVICE HISTORY — Session Management"

capture_window "27-history-sessions-list" \
"Settings > History tab — sessions grouped by month.
   SETUP: Open Settings, go to History tab. Show several past
   sessions with dates, names, and scripture counts."

capture_window "28-history-session-detail" \
"Service detail view — full session info with scriptures.
   SETUP: Click on a past session to open the detail view. Show
   the scriptures list with push status and session stats."

capture_window "29-history-export-menu" \
"Service export context menu.
   SETUP: Right-click on a session row to show the context menu
   with View Details, Export JSON, Export CSV, Delete options."


# ═══════════════════════════════════════════════════════════════
#  SECTION 7: AUTHENTICATION & ONBOARDING
# ═══════════════════════════════════════════════════════════════

section_header "SECTION 7: AUTHENTICATION & ONBOARDING"

capture_window "30-auth-login-email" \
"Login sheet — email entry step.
   SETUP: Sign out and trigger the login flow. Show the email
   input field with 'Continue' button and terms/privacy links."

capture_window "31-auth-login-otp" \
"Login sheet — OTP verification step.
   SETUP: Enter an email and proceed to the 6-digit code entry
   screen. Show the code fields and 'Verify' button."

capture_window "32-auth-account-view" \
"Account view sheet — profile, subscription, devices.
   SETUP: Click on your profile/account to show the account sheet
   with profile header, subscription badge, and devices list."


# ═══════════════════════════════════════════════════════════════
#  SECTION 8: MENU BAR & SYSTEM INTEGRATION
# ═══════════════════════════════════════════════════════════════

section_header "SECTION 8: MENU BAR & SYSTEM INTEGRATION"

capture_fullscreen "33-menubar-icon" \
"Menu bar icon in the macOS status bar.
   SETUP: Ensure Divine Link's book icon is visible in the menu bar.
   Full screen capture for context."

capture_fullscreen "34-menubar-context-menu" \
"Menu bar context menu open.
   SETUP: Right-click (or click) the Divine Link menu bar icon to
   show the dropdown menu with Show, Settings, Quit options."

capture_window "35-settings-about" \
"Settings > About tab — app info and storage stats.
   SETUP: Open Settings, go to About tab. Show app version,
   storage statistics, and contact/support section."

capture_window "36-settings-updates" \
"Settings > Updates tab — auto-update configuration.
   SETUP: Open Settings, go to Updates tab. Show auto-update
   toggles and 'Check for Updates' button."


# ═══════════════════════════════════════════════════════════════
#  SECTION 9: SUPPORT & CONTACT
# ═══════════════════════════════════════════════════════════════

section_header "SECTION 9: SUPPORT & CONTACT"

capture_window "37-contact-form" \
"Contact Us form — in-app support for premium users.
   SETUP: Open the Contact Us form (from About tab or wherever
   it's accessible). Show the title picker, name, email, phone,
   message fields, and consent checkbox."


# ═══════════════════════════════════════════════════════════════
#  SECTION 10: STATUS INDICATORS (close-up details)
# ═══════════════════════════════════════════════════════════════

section_header "SECTION 10: STATUS INDICATORS — Close-up Details"

capture_region "38-detail-status-pills" \
"Status indicator pills (Audio, Speech, Detect, Connection).
   SETUP: Select just the status row area of the main window
   showing the coloured pills for each subsystem."

capture_region "39-detail-connection-status" \
"ProPresenter connection indicator close-up.
   SETUP: Select just the ProPresenter connection status area
   showing green 'Connected' or the connection dashboard."

capture_region "40-detail-verse-card" \
"Single verse card / scripture display close-up.
   SETUP: Select just one detected verse card showing the
   reference, text, confidence badge, and action buttons."


# ═══════════════════════════════════════════════════════════════
#  SECTION 11: ADMIN (if applicable)
# ═══════════════════════════════════════════════════════════════

section_header "SECTION 11: ADMIN — Subscription Management"

capture_window "41-settings-admin" \
"Settings > Admin tab — subscription management (admin only).
   SETUP: If you have admin access, open Settings > Admin tab.
   Skip if not applicable or not visible."


# ═══════════════════════════════════════════════════════════════
#  SECTION 12: BONUS / CREATIVE SHOTS
# ═══════════════════════════════════════════════════════════════

section_header "SECTION 12: BONUS — Creative & Contextual Shots"

capture_fullscreen "42-bonus-full-desktop" \
"Full desktop with Divine Link running alongside ProPresenter.
   SETUP: Arrange Divine Link and ProPresenter side-by-side on
   your desktop. Shows the real workflow context."

capture_region "43-bonus-custom-detail" \
"Any other feature or detail you want to highlight.
   SETUP: Select any area of the app that looks interesting
   or showcases a feature not yet captured."


# ═══════════════════════════════════════════════════════════════
#  SUMMARY
# ═══════════════════════════════════════════════════════════════

print_summary

echo -e "  ${BOLD}Usage suggestions:${NC}"
echo ""
echo "  ${GREEN}Website / Marketing (Epic 9):${NC}"
echo "    01-06 (hero shots), 09-14 (features), 23-26 (pastors)"
echo ""
echo "  ${GREEN}App Store listing:${NC}"
echo "    02, 03, 04, 06, 18, 23, 27 (best of each category)"
echo ""
echo "  ${GREEN}Social media content:${NC}"
echo "    02, 05, 09, 10, 11, 12, 38-40 (detail close-ups)"
echo ""
echo "  ${GREEN}Comparison / upgrade motivation:${NC}"
echo "    07, 08 (free vs premium)"
echo ""
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
