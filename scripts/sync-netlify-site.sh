#!/bin/bash
# Sync Distribution/netlify-site files to divine-link-site repository
# Usage: ./scripts/sync-netlify-site.sh "Commit message"

set -e

# Paths
SOURCE_DIR="/Users/ayoogunrekun/Projects/Divine Link/Distribution/netlify-site"
DEST_DIR="/Users/ayoogunrekun/Projects/divine-link-site"

# Colours
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Colour

echo -e "${YELLOW}=== Divine Link Netlify Sync ===${NC}"
echo ""

# Check source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}Error: Source directory not found: $SOURCE_DIR${NC}"
    exit 1
fi

# Check destination directory exists
if [ ! -d "$DEST_DIR" ]; then
    echo -e "${RED}Error: Destination directory not found: $DEST_DIR${NC}"
    echo -e "${YELLOW}Please clone the divine-link-site repo first:${NC}"
    echo "  cd /Users/ayoogunrekun/Projects"
    echo "  git clone https://github.com/ayoola66/divine-link-site.git"
    exit 1
fi

# Get commit message
COMMIT_MSG="${1:-Sync from Divine Link}"

echo -e "${GREEN}1. Pulling latest from divine-link-site...${NC}"
cd "$DEST_DIR"
git pull origin main || echo "Note: Pull failed or nothing to pull"

echo ""
echo -e "${GREEN}2. Copying files from Distribution/netlify-site...${NC}"
cp -Rv "$SOURCE_DIR/"* "$DEST_DIR/"

echo ""
echo -e "${GREEN}3. Checking for changes...${NC}"
cd "$DEST_DIR"
git status

# Check if there are changes
if git diff --quiet && git diff --cached --quiet; then
    echo -e "${YELLOW}No changes to commit.${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}4. Committing changes...${NC}"
git add -A
git commit -m "$COMMIT_MSG"

echo ""
echo -e "${GREEN}5. Pushing to divine-link-site...${NC}"
git push origin main

echo ""
echo -e "${GREEN}=== Sync Complete ===${NC}"
echo -e "Commit: $COMMIT_MSG"
echo -e "Check deployment at: https://app.netlify.com/projects/divinelink"
echo -e "Live site: https://divinelink.netlify.app"
