#!/bin/bash

#===============================================================================
# Divine Link Release Script
# 
# This script automates the complete release process:
# 1. Bump version numbers
# 2. Build the app with proper code signing
# 3. Create a ZIP for distribution
# 4. Notarise with Apple
# 5. Sign with Sparkle EdDSA
# 6. Update appcast.xml
# 7. Update CHANGELOG
#
# Usage:
#   ./scripts/release.sh [major|minor|patch|beta] [--skip-notarize]
#
# Examples:
#   ./scripts/release.sh patch          # 1.1.0 -> 1.1.1
#   ./scripts/release.sh minor          # 1.1.0 -> 1.2.0
#   ./scripts/release.sh beta           # 1.1.0 -> 1.2.0-beta.1
#   ./scripts/release.sh --skip-notarize  # Skip notarisation (faster for testing)
#
# Prerequisites:
#   - Xcode Command Line Tools
#   - Apple Developer ID Application certificate in Keychain
#   - Notarytool credentials stored (see setup below)
#   - Sparkle EdDSA private key in Keychain
#
# Setup (one-time):
#   xcrun notarytool store-credentials "Divine Link Notarization" \
#     --apple-id YOUR_APPLE_ID \
#     --team-id QVHM976XC5 \
#     --password APP_SPECIFIC_PASSWORD
#
#===============================================================================

set -e  # Exit on any error

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Colour

# Configuration
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_NAME="DivineLink"
SCHEME="DivineLink"
PROJECT_FILE="$PROJECT_ROOT/DivineLink/$PROJECT_NAME.xcodeproj"
BUILD_DIR="$PROJECT_ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/$PROJECT_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/Export"
DISTRIBUTION_DIR="$PROJECT_ROOT/Distribution"
RELEASES_DIR="$DISTRIBUTION_DIR/netlify-site/releases"
APPCAST_FILE="$DISTRIBUTION_DIR/netlify-site/appcast.xml"
CHANGELOG_FILE="$PROJECT_ROOT/CHANGELOG.md"
INFO_PLIST="$PROJECT_ROOT/DivineLink/DivineLink/Info.plist"

# Notarisation profile name (set up with xcrun notarytool store-credentials)
NOTARIZATION_PROFILE="DivineLink-Notary"

# Team ID
TEAM_ID="QVHM976XC5"

# Appcast base URL
APPCAST_BASE_URL="https://divinelink.netlify.app/releases"

# Minimum macOS version
MIN_MACOS_VERSION="14.0"

# Parse arguments
BUMP_TYPE="patch"
SKIP_NOTARIZE=false

for arg in "$@"; do
    case $arg in
        major|minor|patch|beta)
            BUMP_TYPE=$arg
            ;;
        --skip-notarize)
            SKIP_NOTARIZE=true
            ;;
    esac
done

#===============================================================================
# Helper Functions
#===============================================================================

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

get_current_version() {
    # Get version from project.pbxproj
    grep -m1 "MARKETING_VERSION" "$PROJECT_FILE/project.pbxproj" | sed 's/.*= //' | tr -d ';' | tr -d ' '
}

get_current_build() {
    # Get build number from project.pbxproj
    grep -m1 "CURRENT_PROJECT_VERSION" "$PROJECT_FILE/project.pbxproj" | sed 's/.*= //' | tr -d ';' | tr -d ' '
}

bump_version() {
    local current_version=$1
    local bump_type=$2
    
    # Remove any beta suffix for base version
    local base_version=$(echo "$current_version" | sed 's/-beta.*//')
    
    # Parse version components
    local major=$(echo "$base_version" | cut -d. -f1)
    local minor=$(echo "$base_version" | cut -d. -f2)
    local patch=$(echo "$base_version" | cut -d. -f3)
    
    case $bump_type in
        major)
            echo "$((major + 1)).0.0"
            ;;
        minor)
            echo "$major.$((minor + 1)).0"
            ;;
        patch)
            echo "$major.$minor.$((patch + 1))"
            ;;
        beta)
            # Check if already a beta version
            if [[ "$current_version" == *"-beta"* ]]; then
                local beta_num=$(echo "$current_version" | grep -o 'beta\.[0-9]*' | cut -d. -f2)
                echo "$base_version-beta.$((beta_num + 1))"
            else
                # Start new beta based on next minor version
                echo "$major.$((minor + 1)).0-beta.1"
            fi
            ;;
    esac
}

update_version_in_project() {
    local new_version=$1
    local new_build=$2
    
    log_info "Updating project to version $new_version (build $new_build)"
    
    # Update MARKETING_VERSION in project.pbxproj
    sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $new_version;/g" "$PROJECT_FILE/project.pbxproj"
    
    # Update CURRENT_PROJECT_VERSION in project.pbxproj
    sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = $new_build;/g" "$PROJECT_FILE/project.pbxproj"
}

find_sparkle_sign_tool() {
    # Look for Sparkle sign_update tool
    local sparkle_bin=$(find ~/Library/Developer/Xcode/DerivedData -name "sign_update" -path "*Sparkle*" 2>/dev/null | head -1)
    
    if [ -z "$sparkle_bin" ]; then
        # Try common locations
        if [ -f "/usr/local/bin/sign_update" ]; then
            sparkle_bin="/usr/local/bin/sign_update"
        elif [ -f "$PROJECT_ROOT/tools/sign_update" ]; then
            sparkle_bin="$PROJECT_ROOT/tools/sign_update"
        fi
    fi
    
    echo "$sparkle_bin"
}

generate_appcast_item() {
    local version=$1
    local build=$2
    local zip_file=$3
    local signature=$4
    local file_size=$5
    local release_notes=$6
    local pub_date=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")
    
    cat << EOF
        <item>
            <title>Version $version</title>
            <sparkle:version>$build</sparkle:version>
            <sparkle:shortVersionString>$version</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>$MIN_MACOS_VERSION</sparkle:minimumSystemVersion>
            <pubDate>$pub_date</pubDate>
            
            <description><![CDATA[
$release_notes
            ]]></description>
            
            <enclosure 
                url="$APPCAST_BASE_URL/$zip_file"
                length="$file_size"
                type="application/octet-stream"
                sparkle:edSignature="$signature"
            />
        </item>
EOF
}

#===============================================================================
# Main Script
#===============================================================================

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                    Divine Link Release Script                        ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

cd "$PROJECT_ROOT"

#-------------------------------------------------------------------------------
# Step 1: Get current version and calculate new version
#-------------------------------------------------------------------------------
log_step "Step 1: Version Management"

CURRENT_VERSION=$(get_current_version)
CURRENT_BUILD=$(get_current_build)
NEW_VERSION=$(bump_version "$CURRENT_VERSION" "$BUMP_TYPE")
NEW_BUILD=$((CURRENT_BUILD + 1))

log_info "Current version: $CURRENT_VERSION (build $CURRENT_BUILD)"
log_info "New version:     $NEW_VERSION (build $NEW_BUILD)"
log_info "Bump type:       $BUMP_TYPE"

echo ""
read -p "Proceed with version $NEW_VERSION? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warning "Release cancelled"
    exit 1
fi

# Update version in project
update_version_in_project "$NEW_VERSION" "$NEW_BUILD"
log_success "Version updated in project"

#-------------------------------------------------------------------------------
# Step 2: Clean and Build Archive
#-------------------------------------------------------------------------------
log_step "Step 2: Building Archive"

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

log_info "Building archive..."

# Note: We do NOT override CODE_SIGN_IDENTITY here because:
# - The project uses "Automatic Signing"
# - The export step with method=developer-id handles proper signing
# - Overriding causes conflicts with automatic signing
xcodebuild archive \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=macOS" \
    -configuration Release \
    -quiet

if [ ! -d "$ARCHIVE_PATH" ]; then
    log_error "Archive failed - archive not found"
    exit 1
fi

log_success "Archive created successfully"

#-------------------------------------------------------------------------------
# Step 3: Export the App
#-------------------------------------------------------------------------------
log_step "Step 3: Exporting App"

# Create export options plist
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
cat > "$EXPORT_OPTIONS" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
EOF

log_info "Exporting app..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -quiet

APP_PATH="$EXPORT_PATH/$PROJECT_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    log_error "Export failed - app not found"
    exit 1
fi

log_success "App exported successfully"

#-------------------------------------------------------------------------------
# Step 4: Notarise the App (optional)
#-------------------------------------------------------------------------------
if [ "$SKIP_NOTARIZE" = false ]; then
    log_step "Step 4: Notarising with Apple"
    
    # Create a ZIP for notarisation
    NOTARIZE_ZIP="$BUILD_DIR/$PROJECT_NAME-notarize.zip"
    log_info "Creating ZIP for notarisation..."
    ditto -c -k --keepParent "$APP_PATH" "$NOTARIZE_ZIP"
    
    log_info "Submitting to Apple for notarisation..."
    log_info "(This may take several minutes)"
    
    xcrun notarytool submit "$NOTARIZE_ZIP" \
        --keychain-profile "$NOTARIZATION_PROFILE" \
        --wait
    
    log_info "Stapling notarisation ticket to app..."
    xcrun stapler staple "$APP_PATH"
    
    log_success "App notarised and stapled"
else
    log_step "Step 4: Notarisation (SKIPPED)"
    log_warning "Skipping notarisation as requested"
fi

#-------------------------------------------------------------------------------
# Step 5: Create Distribution Packages
#-------------------------------------------------------------------------------
log_step "Step 5: Creating Distribution Packages"

ZIP_FILENAME="$PROJECT_NAME-$NEW_VERSION.zip"
ZIP_PATH="$RELEASES_DIR/$ZIP_FILENAME"

mkdir -p "$RELEASES_DIR"

log_info "Creating distribution ZIP..."
cd "$EXPORT_PATH"
ditto -c -k --sequesterRsrc --keepParent "$PROJECT_NAME.app" "$ZIP_PATH"
cd "$PROJECT_ROOT"

FILE_SIZE=$(stat -f%z "$ZIP_PATH")
log_info "ZIP created: $ZIP_FILENAME ($FILE_SIZE bytes)"

# Also copy to latest
cp "$ZIP_PATH" "$RELEASES_DIR/$PROJECT_NAME-latest.zip"

log_success "Distribution ZIP created"

#-------------------------------------------------------------------------------
# Step 6: Sign with Sparkle EdDSA
#-------------------------------------------------------------------------------
log_step "Step 6: Signing with Sparkle"

SPARKLE_SIGN=$(find_sparkle_sign_tool)

if [ -z "$SPARKLE_SIGN" ] || [ ! -f "$SPARKLE_SIGN" ]; then
    log_warning "Sparkle sign_update tool not found"
    log_info "Please sign manually with:"
    log_info "  ./sign_update '$ZIP_PATH'"
    log_info ""
    read -p "Enter EdDSA signature (or press Enter to skip): " SIGNATURE
else
    log_info "Signing with Sparkle..."
    SIGNATURE=$("$SPARKLE_SIGN" "$ZIP_PATH" 2>/dev/null || echo "")
    
    if [ -z "$SIGNATURE" ]; then
        log_warning "Could not auto-sign. Please sign manually."
        read -p "Enter EdDSA signature: " SIGNATURE
    fi
fi

if [ -n "$SIGNATURE" ]; then
    log_success "Signature obtained"
else
    log_warning "No signature - update will not be verified by Sparkle!"
fi

#-------------------------------------------------------------------------------
# Step 7: Update appcast.xml
#-------------------------------------------------------------------------------
log_step "Step 7: Updating appcast.xml"

# Prepare release notes (prompt user)
echo ""
log_info "Enter release notes for appcast.xml (HTML format)"
log_info "Example: <h2>What's New</h2><ul><li>Feature 1</li></ul>"
log_info "Press Enter twice when done:"
echo ""

RELEASE_NOTES=""
while IFS= read -r line; do
    [ -z "$line" ] && break
    RELEASE_NOTES="${RELEASE_NOTES}${line}
"
done

if [ -z "$RELEASE_NOTES" ]; then
    RELEASE_NOTES="<h2>Version $NEW_VERSION</h2>
                <ul>
                    <li>Bug fixes and improvements</li>
                </ul>"
fi

# Generate new item
NEW_ITEM=$(generate_appcast_item "$NEW_VERSION" "$NEW_BUILD" "$ZIP_FILENAME" "$SIGNATURE" "$FILE_SIZE" "$RELEASE_NOTES")

# Insert into appcast.xml (after <!-- Latest Version -->)
# NOTE: awk -v cannot carry a multi-line value on macOS/BSD awk ("newline in
# string" error). Write the new item to a file and read it with getline so the
# multi-line XML block inserts reliably regardless of awk flavour.
TEMP_APPCAST="$BUILD_DIR/appcast_temp.xml"
ITEM_FILE="$BUILD_DIR/new_item.xml"
printf '%s\n' "$NEW_ITEM" > "$ITEM_FILE"
awk -v item_file="$ITEM_FILE" '
    /<!-- Latest Version -->/ {
        print
        print ""
        while ((getline line < item_file) > 0) print line
        close(item_file)
        next
    }
    { print }
' "$APPCAST_FILE" > "$TEMP_APPCAST"

mv "$TEMP_APPCAST" "$APPCAST_FILE"

log_success "appcast.xml updated"

#-------------------------------------------------------------------------------
# Step 8: Summary
#-------------------------------------------------------------------------------
log_step "Release Complete!"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                         Release Summary                               ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC} Version:    ${CYAN}$NEW_VERSION${NC} (build $NEW_BUILD)"
echo -e "${GREEN}║${NC} ZIP File:   ${CYAN}$ZIP_FILENAME${NC}"
echo -e "${GREEN}║${NC} File Size:  ${CYAN}$FILE_SIZE bytes${NC}"
echo -e "${GREEN}║${NC} Notarised:  ${CYAN}$([ "$SKIP_NOTARIZE" = false ] && echo "Yes" || echo "No")${NC}"
echo -e "${GREEN}║${NC} Signed:     ${CYAN}$([ -n "$SIGNATURE" ] && echo "Yes" || echo "No")${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

log_info "Files created:"
echo "  • $ZIP_PATH"
echo "  • $RELEASES_DIR/$PROJECT_NAME-latest.zip"
echo "  • $APPCAST_FILE (updated)"
echo ""

log_info "Next steps:"
echo "  1. Update CHANGELOG.md with release notes"
echo "  2. Commit changes: git add -A && git commit -m 'Release $NEW_VERSION'"
echo "  3. Tag release: git tag v$NEW_VERSION"
echo "  4. Push to trigger deployment: git push && git push --tags"
echo "  5. Verify at: https://divinelink.netlify.app/appcast.xml"
echo ""

log_success "Done! 🎉"
