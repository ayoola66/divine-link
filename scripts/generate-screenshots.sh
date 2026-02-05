#!/bin/bash
#
# generate-screenshots.sh
# Divine Link App Store Screenshot Generator
#
# This script captures screenshots of Divine Link for the Mac App Store.
# Run this with the app open and configured with sample data.
#
# Usage: ./scripts/generate-screenshots.sh
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_ROOT/Distribution/screenshots"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SCREENSHOT_DIR="$OUTPUT_DIR/$TIMESTAMP"

# App Store screenshot sizes (width x height)
# Using 2880x1800 (Retina) as the standard for high-quality captures
SCREENSHOT_DELAY=1  # seconds to wait before each capture

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║         Divine Link Screenshot Generator                      ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Create output directory
mkdir -p "$SCREENSHOT_DIR"
echo -e "${GREEN}✓${NC} Created screenshot directory: $SCREENSHOT_DIR"
echo ""

# Check if Divine Link is running
if ! pgrep -x "Divine Link" > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC} Divine Link is not running."
    echo "   Please launch Divine Link and set it up with:"
    echo "   - A sample detected verse visible"
    echo "   - ProPresenter connection configured"
    echo "   - Audio device selected"
    echo ""
    read -p "Press Enter when Divine Link is running and ready..."
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "SCREENSHOT CAPTURE GUIDE"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "This script will guide you through capturing each screenshot."
echo "Before each capture, set up the app as described."
echo ""
echo -e "${BLUE}Tip:${NC} For best results, use a clean desktop background."
echo ""

# Function to capture a screenshot
capture_screenshot() {
    local name=$1
    local description=$2
    local filename="$SCREENSHOT_DIR/${name}.png"
    
    echo "───────────────────────────────────────────────────────────────"
    echo -e "${BLUE}Screenshot ${name}:${NC} $description"
    echo "───────────────────────────────────────────────────────────────"
    echo ""
    echo "Set up the app as described, then press Enter to capture."
    echo -e "${YELLOW}Or type 'skip' to skip this screenshot.${NC}"
    echo ""
    read -p "> " response
    
    if [[ "$response" == "skip" ]]; then
        echo -e "${YELLOW}⏭${NC} Skipped: $name"
        echo ""
        return
    fi
    
    echo "Capturing in $SCREENSHOT_DELAY second(s)..."
    sleep $SCREENSHOT_DELAY
    
    # Capture the frontmost window
    screencapture -wo "$filename"
    
    if [[ -f "$filename" ]]; then
        echo -e "${GREEN}✓${NC} Saved: $filename"
        
        # Get dimensions
        dimensions=$(sips -g pixelWidth -g pixelHeight "$filename" 2>/dev/null | tail -2 | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
        echo "   Dimensions: $dimensions"
    else
        echo -e "${RED}✗${NC} Failed to capture screenshot"
    fi
    echo ""
}

# Function to capture entire screen (for menu bar shots)
capture_fullscreen() {
    local name=$1
    local description=$2
    local filename="$SCREENSHOT_DIR/${name}.png"
    
    echo "───────────────────────────────────────────────────────────────"
    echo -e "${BLUE}Screenshot ${name}:${NC} $description"
    echo "───────────────────────────────────────────────────────────────"
    echo ""
    echo "Set up the screen as described, then press Enter to capture."
    echo -e "${YELLOW}Or type 'skip' to skip this screenshot.${NC}"
    echo ""
    read -p "> " response
    
    if [[ "$response" == "skip" ]]; then
        echo -e "${YELLOW}⏭${NC} Skipped: $name"
        echo ""
        return
    fi
    
    echo "Capturing in $SCREENSHOT_DELAY second(s)..."
    sleep $SCREENSHOT_DELAY
    
    # Capture full screen
    screencapture "$filename"
    
    if [[ -f "$filename" ]]; then
        echo -e "${GREEN}✓${NC} Saved: $filename"
        dimensions=$(sips -g pixelWidth -g pixelHeight "$filename" 2>/dev/null | tail -2 | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
        echo "   Dimensions: $dimensions"
    else
        echo -e "${RED}✗${NC} Failed to capture screenshot"
    fi
    echo ""
}

# Function to capture interactive region
capture_region() {
    local name=$1
    local description=$2
    local filename="$SCREENSHOT_DIR/${name}.png"
    
    echo "───────────────────────────────────────────────────────────────"
    echo -e "${BLUE}Screenshot ${name}:${NC} $description"
    echo "───────────────────────────────────────────────────────────────"
    echo ""
    echo "You'll be able to select a region after pressing Enter."
    echo -e "${YELLOW}Or type 'skip' to skip this screenshot.${NC}"
    echo ""
    read -p "> " response
    
    if [[ "$response" == "skip" ]]; then
        echo -e "${YELLOW}⏭${NC} Skipped: $name"
        echo ""
        return
    fi
    
    echo "Select the region to capture..."
    
    # Capture selected region
    screencapture -is "$filename"
    
    if [[ -f "$filename" ]]; then
        echo -e "${GREEN}✓${NC} Saved: $filename"
        dimensions=$(sips -g pixelWidth -g pixelHeight "$filename" 2>/dev/null | tail -2 | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
        echo "   Dimensions: $dimensions"
    else
        echo -e "${RED}✗${NC} Capture cancelled or failed"
    fi
    echo ""
}

echo "═══════════════════════════════════════════════════════════════"
echo "BEGINNING SCREENSHOT CAPTURE"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Screenshot 1: Main Interface with Detected Verse
capture_screenshot "01_main_interface" \
"Main interface with a detected Bible verse visible.
   
   SETUP:
   • Divine Link main window in focus
   • At least one verse detected and displayed
   • Confidence indicator visible (Story 6.2)
   • Clean, typical usage state"

# Screenshot 2: Live Detection Moment
capture_screenshot "02_live_detection" \
"Live detection moment showing real-time transcription.
   
   SETUP:
   • Main window with audio active (meter moving)
   • Partial transcription visible
   • A verse being detected or just detected
   • Show the 'listening' state"

# Screenshot 3: ProPresenter Connected
capture_screenshot "03_propresenter_connected" \
"ProPresenter integration showing connected status.
   
   SETUP:
   • Main window or status bar showing 'Connected'
   • Recently sent verse visible
   • Green connection indicator"

# Screenshot 4: Settings - Audio
capture_screenshot "04_settings_audio" \
"Audio settings panel.
   
   SETUP:
   • Settings window open
   • Audio/Input Device section visible
   • Show microphone selection dropdown
   • Audio level meter visible if possible"

# Screenshot 5: Settings - ProPresenter
capture_screenshot "05_settings_propresenter" \
"ProPresenter settings panel.
   
   SETUP:
   • Settings window open
   • ProPresenter connection section visible
   • Show host/port configuration
   • Connection status visible"

# Screenshot 6: Bible Translation (Main Interface)
capture_screenshot "06_bible_translation" \
"Bible translation selection.
   
   SETUP:
   • Main app window visible (NOT Settings)
   • Click the Bible translation dropdown (e.g., 'KJV' button)
   • Show the dropdown open with available translations (KJV, ASV, WEB)"

# Screenshot 7: Service History
capture_screenshot "07_service_history" \
"Service history browser.
   
   SETUP:
   • History view/panel open
   • Show past services with dates
   • Multiple verses listed
   • If available, show service duration"

# Screenshot 8: Panic Button
capture_screenshot "08_panic_button" \
"Panic Button feature (Story 6.1).
   
   SETUP:
   • Show the panic/clear button
   • If possible, show before/after state
   • Keyboard shortcut visible (F12 or ⌘+Esc)"

# Screenshot 9: Menu Bar Access
capture_fullscreen "09_menu_bar" \
"Menu bar integration.
   
   SETUP:
   • Click Divine Link menu bar icon
   • Show dropdown menu open
   • Quick access options visible
   • Full screen capture for context"

# Screenshot 10: Feature Highlight (Region)
capture_region "10_feature_detail" \
"Optional: Capture any specific feature detail.
   
   SETUP:
   • Select a specific feature to highlight
   • Could be confidence meter, verse display, etc.
   • This allows you to select exactly what to capture"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "SCREENSHOT CAPTURE COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Count captured files
captured=$(ls -1 "$SCREENSHOT_DIR"/*.png 2>/dev/null | wc -l | tr -d ' ')

echo -e "${GREEN}✓${NC} Captured $captured screenshot(s)"
echo ""
echo "Screenshots saved to:"
echo "  $SCREENSHOT_DIR"
echo ""

# List all captured screenshots
if [[ $captured -gt 0 ]]; then
    echo "Captured files:"
    for f in "$SCREENSHOT_DIR"/*.png; do
        if [[ -f "$f" ]]; then
            size=$(ls -lh "$f" | awk '{print $5}')
            dims=$(sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null | tail -2 | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
            echo "  • $(basename "$f") ($dims, $size)"
        fi
    done
    echo ""
fi

# App Store requirements reminder
echo "───────────────────────────────────────────────────────────────"
echo "APP STORE REQUIREMENTS"
echo "───────────────────────────────────────────────────────────────"
echo ""
echo "Mac App Store accepts these screenshot sizes:"
echo "  • 1280 × 800 pixels"
echo "  • 1440 × 900 pixels"
echo "  • 2560 × 1600 pixels"
echo "  • 2880 × 1800 pixels (Retina)"
echo ""
echo "You need 1-10 screenshots. Apple recommends at least 3."
echo ""

# Offer to resize
echo "───────────────────────────────────────────────────────────────"
echo "RESIZE OPTIONS"
echo "───────────────────────────────────────────────────────────────"
echo ""
echo "Would you like to create App Store-sized copies?"
echo ""
echo "  1) 2880 × 1800 (Retina - recommended)"
echo "  2) 1440 × 900 (Standard)"
echo "  3) Skip resizing"
echo ""
read -p "Select option (1/2/3): " resize_option

if [[ "$resize_option" == "1" ]]; then
    RESIZE_DIR="$SCREENSHOT_DIR/appstore_2880x1800"
    mkdir -p "$RESIZE_DIR"
    TARGET_W=2880
    TARGET_H=1800
    
    echo ""
    echo "Resizing to ${TARGET_W}x${TARGET_H}..."
    
    for f in "$SCREENSHOT_DIR"/*.png; do
        if [[ -f "$f" ]]; then
            basename=$(basename "$f")
            output="$RESIZE_DIR/$basename"
            
            # Resize maintaining aspect ratio, then crop/extend to exact size
            sips -z $TARGET_H $TARGET_W "$f" --out "$output" 2>/dev/null || \
            sips --resampleHeightWidth $TARGET_H $TARGET_W "$f" --out "$output" 2>/dev/null
            
            echo "  ✓ $basename"
        fi
    done
    
    echo ""
    echo -e "${GREEN}✓${NC} Resized screenshots saved to:"
    echo "  $RESIZE_DIR"
    
elif [[ "$resize_option" == "2" ]]; then
    RESIZE_DIR="$SCREENSHOT_DIR/appstore_1440x900"
    mkdir -p "$RESIZE_DIR"
    TARGET_W=1440
    TARGET_H=900
    
    echo ""
    echo "Resizing to ${TARGET_W}x${TARGET_H}..."
    
    for f in "$SCREENSHOT_DIR"/*.png; do
        if [[ -f "$f" ]]; then
            basename=$(basename "$f")
            output="$RESIZE_DIR/$basename"
            
            sips --resampleHeightWidth $TARGET_H $TARGET_W "$f" --out "$output" 2>/dev/null
            
            echo "  ✓ $basename"
        fi
    done
    
    echo ""
    echo -e "${GREEN}✓${NC} Resized screenshots saved to:"
    echo "  $RESIZE_DIR"
fi

echo ""
echo "───────────────────────────────────────────────────────────────"
echo "NEXT STEPS"
echo "───────────────────────────────────────────────────────────────"
echo ""
echo "1. Open App Store Connect"
echo "   https://appstoreconnect.apple.com"
echo ""
echo "2. Navigate to your app's 'App Store' tab"
echo ""
echo "3. Under 'Mac App Screenshots', upload your screenshots"
echo ""
echo "4. Add the copy from:"
echo "   Distribution/app-store-copy.md"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
