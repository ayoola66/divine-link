#!/bin/bash

#===============================================================================
# Divine Link Release Setup Script
# 
# This script sets up the required credentials for automated releases:
# 1. Apple notarisation credentials (stored in Keychain)
# 2. Verifies code signing certificates
# 3. Locates Sparkle signing tool
#
# Run this ONCE before using release.sh
#
# Usage:
#   ./scripts/setup-release.sh
#
# Requirements:
#   - Apple Developer account with Developer ID Application certificate
#   - App-specific password from appleid.apple.com
#
#===============================================================================

set -e

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_step() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}▶ $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║              Divine Link Release Setup                               ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

#-------------------------------------------------------------------------------
# Step 1: Check for Developer ID certificate
#-------------------------------------------------------------------------------
log_step "Step 1: Checking Code Signing Certificates"

echo ""
log_info "Looking for Developer ID Application certificate..."

CERT_COUNT=$(security find-identity -v -p codesigning | grep "Developer ID Application" | wc -l | tr -d ' ')

if [ "$CERT_COUNT" -gt 0 ]; then
    log_success "Found Developer ID Application certificate(s):"
    security find-identity -v -p codesigning | grep "Developer ID Application"
else
    log_error "No Developer ID Application certificate found!"
    echo ""
    log_info "To fix this:"
    echo "  1. Open Xcode → Settings → Accounts"
    echo "  2. Select your Apple ID"
    echo "  3. Click 'Manage Certificates'"
    echo "  4. Click '+' and choose 'Developer ID Application'"
    echo "  5. Download and install the certificate"
    exit 1
fi

#-------------------------------------------------------------------------------
# Step 2: Set up notarisation credentials
#-------------------------------------------------------------------------------
log_step "Step 2: Setting Up Notarisation Credentials"

echo ""
log_info "Notarisation requires credentials stored in your Keychain."
log_info "You'll need:"
echo "  • Your Apple ID email"
echo "  • Your Team ID (QVHM976XC5)"
echo "  • An app-specific password from https://appleid.apple.com"
echo ""

# Check if credentials already exist
if xcrun notarytool history --keychain-profile "Divine Link Notarization" 2>/dev/null | head -1 | grep -q "Successfully"; then
    log_success "Notarisation credentials already configured!"
else
    log_warning "Notarisation credentials not found"
    echo ""
    read -p "Would you like to set up notarisation credentials now? (y/n) " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        log_info "Setting up credentials..."
        log_info "You'll be prompted for your Apple ID, Team ID, and app-specific password."
        echo ""
        
        xcrun notarytool store-credentials "Divine Link Notarization" \
            --team-id "QVHM976XC5"
        
        log_success "Notarisation credentials stored!"
    else
        log_warning "Skipping notarisation setup"
        log_info "You can set this up later with:"
        echo ""
        echo "  xcrun notarytool store-credentials 'Divine Link Notarization' \\"
        echo "    --apple-id YOUR_APPLE_ID \\"
        echo "    --team-id QVHM976XC5 \\"
        echo "    --password APP_SPECIFIC_PASSWORD"
        echo ""
    fi
fi

#-------------------------------------------------------------------------------
# Step 3: Locate Sparkle signing tool
#-------------------------------------------------------------------------------
log_step "Step 3: Locating Sparkle Signing Tool"

SPARKLE_SIGN=$(find ~/Library/Developer/Xcode/DerivedData -name "sign_update" -path "*Sparkle*" 2>/dev/null | head -1)

if [ -n "$SPARKLE_SIGN" ] && [ -f "$SPARKLE_SIGN" ]; then
    log_success "Sparkle sign_update found:"
    echo "  $SPARKLE_SIGN"
else
    log_warning "Sparkle sign_update not found in DerivedData"
    log_info "This is normal if you haven't built the project recently."
    echo ""
    log_info "To make sign_update available:"
    echo "  1. Open the project in Xcode"
    echo "  2. Build the project (⌘B)"
    echo "  3. The Sparkle tools will be in DerivedData"
    echo ""
    log_info "Alternatively, you can download Sparkle and copy the tools:"
    echo "  https://github.com/sparkle-project/Sparkle/releases"
fi

#-------------------------------------------------------------------------------
# Step 4: Verify EdDSA public key in Info.plist
#-------------------------------------------------------------------------------
log_step "Step 4: Checking Sparkle Public Key"

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INFO_PLIST="$PROJECT_ROOT/DivineLink/DivineLink/Info.plist"

if [ -f "$INFO_PLIST" ]; then
    if grep -q "SUPublicEDKey" "$INFO_PLIST"; then
        log_success "SUPublicEDKey found in Info.plist"
    else
        log_warning "SUPublicEDKey not found in Info.plist"
        log_info "You need to add your Sparkle EdDSA public key to Info.plist"
    fi
else
    log_warning "Info.plist not found"
fi

#-------------------------------------------------------------------------------
# Summary
#-------------------------------------------------------------------------------
log_step "Setup Complete!"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                         Setup Summary                                 ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC} Code Signing:     ${CYAN}$([ "$CERT_COUNT" -gt 0 ] && echo "✅ Ready" || echo "❌ Not configured")${NC}"
echo -e "${GREEN}║${NC} Notarisation:     ${CYAN}$(xcrun notarytool history --keychain-profile "Divine Link Notarization" 2>/dev/null | head -1 | grep -q "Successfully" && echo "✅ Ready" || echo "⚠️  Not configured")${NC}"
echo -e "${GREEN}║${NC} Sparkle Signing:  ${CYAN}$([ -n "$SPARKLE_SIGN" ] && echo "✅ Ready" || echo "⚠️  Build project first")${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

log_info "You're now ready to use the release script:"
echo ""
echo "  ./scripts/release.sh patch     # For bug fix releases (1.1.0 → 1.1.1)"
echo "  ./scripts/release.sh minor     # For feature releases (1.1.0 → 1.2.0)"
echo "  ./scripts/release.sh major     # For major releases (1.1.0 → 2.0.0)"
echo ""

log_success "Done! 🎉"
