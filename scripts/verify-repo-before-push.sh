#!/bin/bash

# Repository Verification Script
# Use this before pushing to ensure you're pushing to the correct repository

set -e

echo "🔍 Repository Verification Checklist"
echo "===================================="
echo ""

# Get current directory
CURRENT_DIR=$(pwd)
echo "Current directory: $CURRENT_DIR"
echo ""

# Check if we're in the main repo
if [[ "$CURRENT_DIR" == *"Divine Link"* ]]; then
    echo "✅ In Divine Link workspace"
else
    echo "⚠️  Not in expected workspace"
fi

# Check for modified files
echo ""
echo "📋 Modified/Staged Files:"
git status --short | head -10
echo ""

# Check for Distribution/netlify-site files
NETLIFY_FILES=$(git status --short | grep "Distribution/netlify-site/" || true)

if [ -n "$NETLIFY_FILES" ]; then
    echo "⚠️  ⚠️  ⚠️  CRITICAL: Files in Distribution/netlify-site/ detected!"
    echo ""
    echo "These files MUST go to: divine-link-site repository"
    echo "NOT to: divine-link repository"
    echo ""
    echo "Files detected:"
    echo "$NETLIFY_FILES"
    echo ""
    echo "❌ DO NOT PUSH THESE TO divine-link REPO!"
    echo "✅ Use clone-and-copy method instead (see docs/REPOSITORY_STRUCTURE.md)"
    exit 1
else
    echo "✅ No Distribution/netlify-site/ files detected"
    echo "✅ Safe to push to divine-link repository"
fi

# Check current remote
echo ""
echo "🌐 Current Git Remote:"
git remote -v | head -2
echo ""

REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")

if [[ "$REMOTE_URL" == *"divine-link-site"* ]]; then
    echo "✅ Remote is divine-link-site (correct for admin files)"
elif [[ "$REMOTE_URL" == *"divine-link.git"* ]]; then
    echo "✅ Remote is divine-link (correct for app code)"
else
    echo "⚠️  Unknown remote URL: $REMOTE_URL"
fi

echo ""
echo "✅ Verification complete"
