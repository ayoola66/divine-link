# Repository Structure & Git Workflow

## ⚠️ CRITICAL: Two Separate Repositories

**🚨 VERY IMPORTANT: Always verify you're pushing to the correct repository!**

This project uses **TWO separate GitHub repositories** for different purposes. **Mistakes here will break deployments.**

**Before EVERY push:**
1. Check file location
2. Verify remote URL (`git remote -v`)
3. Confirm with user which repo you're pushing to
4. Use clone-and-copy method for `Distribution/netlify-site/` files

---

## Repository Overview

| Repository | URL | Purpose | What Goes Here |
|------------|-----|---------|----------------|
| **divine-link** | `https://github.com/ayoola66/divine-link.git` | **App Source Code** | Swift files, Xcode project, app logic |
| **divine-link-site** | `https://github.com/ayoola66/divine-link-site.git` | **Netlify Website** | Admin dashboard, landing pages, appcast |

---

## What Goes Where

### ✅ Push to `divine-link` Repository

**Location in workspace:** Root directory (`/Users/ayoogunrekun/Projects/Divine Link/`)

**Files that belong here:**
- ✅ All Swift source files (`DivineLink/DivineLink/**/*.swift`)
- ✅ Xcode project files (`DivineLink/DivineLink.xcodeproj/`)
- ✅ App resources (`DivineLink/DivineLink/Assets.xcassets/`, `Info.plist`)
- ✅ Documentation (`docs/`, `README.md`, `CHANGELOG.md`)
- ✅ Database schemas (`Distribution/supabase-schema.sql`, `Distribution/supabase-migration-*.sql`)
- ✅ Project configuration files (`.gitignore`, `netlify.toml`)

**Git commands:**
```bash
cd "/Users/ayoogunrekun/Projects/Divine Link"
git add .
git commit -m "Description"
git push origin main
```

---

### ✅ Push to `divine-link-site` Repository

**Location in workspace:** `Distribution/netlify-site/` directory

**Files that belong here:**
- ✅ `admin.html` - Ad Manager dashboard
- ✅ `index.html` - Landing page
- ✅ `appcast.xml` - Sparkle update feed
- ✅ `privacy.html`, `terms.html`, `success.html`, `cancel.html`
- ✅ `netlify.toml` - Netlify configuration
- ✅ `releases/` - App release ZIP files
- ✅ Any other static website files

**⚠️ IMPORTANT:** This directory is a **separate git repository** that syncs to `divine-link-site`.

**Git commands:**
```bash
# Option 1: Direct push (if Distribution/netlify-site is a git repo)
cd "/Users/ayoogunrekun/Projects/Divine Link/Distribution/netlify-site"
git add .
git commit -m "Description"
git push origin main

# Option 2: Clone and copy (recommended for safety)
cd /tmp
git clone https://github.com/ayoola66/divine-link-site.git temp-site
cp "/Users/ayoogunrekun/Projects/Divine Link/Distribution/netlify-site/admin.html" temp-site/
cd temp-site
git add admin.html
git commit -m "Description"
git push
rm -rf temp-site
```

---

## Workflow Rules

### 🚨 CRITICAL RULES

1. **Always check file location before pushing:**
   - Files in `Distribution/netlify-site/` → Push to `divine-link-site`
   - All other files → Push to `divine-link`

2. **When modifying admin.html or other website files:**
   - Make changes in `Distribution/netlify-site/`
   - **ALWAYS** push to `divine-link-site` repository
   - Netlify auto-deploys from `divine-link-site` repo

3. **When modifying Swift files or app code:**
   - Make changes in `DivineLink/` or root
   - **ALWAYS** push to `divine-link` repository

4. **Database migrations:**
   - SQL files stay in `divine-link` repo (documentation)
   - Run migrations manually in Supabase SQL editor

---

## Quick Reference

### Common Scenarios

#### Scenario 1: Updating Admin Dashboard
```bash
# 1. Edit Distribution/netlify-site/admin.html
# 2. Push to divine-link-site repo
cd /tmp
git clone https://github.com/ayoola66/divine-link-site.git temp
cp "/Users/ayoogunrekun/Projects/Divine Link/Distribution/netlify-site/admin.html" temp/
cd temp && git add admin.html && git commit -m "Update admin" && git push
rm -rf temp
```

#### Scenario 2: Updating App Code
```bash
# 1. Edit Swift files in DivineLink/
# 2. Push to divine-link repo
cd "/Users/ayoogunrekun/Projects/Divine Link"
git add DivineLink/
git commit -m "Update app feature"
git push origin main
```

#### Scenario 3: Updating Both (App + Website)
```bash
# Push app changes
cd "/Users/ayoogunrekun/Projects/Divine Link"
git add DivineLink/
git commit -m "App changes"
git push origin main

# Push website changes
cd /tmp
git clone https://github.com/ayoola66/divine-link-site.git temp
cp "/Users/ayoogunrekun/Projects/Divine Link/Distribution/netlify-site/admin.html" temp/
cd temp && git add admin.html && git commit -m "Website changes" && git push
rm -rf temp
```

---

## Verification Checklist

**⚠️ MANDATORY: Run this checklist BEFORE EVERY PUSH**

Before pushing, verify:

- [ ] **File location checked** - Is this file in `Distribution/netlify-site/`?
- [ ] **Correct repository identified** - Which repo should this go to?
- [ ] **Remote URL verified** - Run `git remote -v` and confirm the URL matches target repo
- [ ] **Changes committed** - Are all changes staged and committed?
- [ ] **User notified** - Show user which repo you're pushing to before executing

### Quick Verification Commands

```bash
# Check which files are modified
git status --short

# Verify remote URL
git remote -v

# For Distribution/netlify-site files, ALWAYS use:
cd /tmp
git clone https://github.com/ayoola66/divine-link-site.git temp
# ... copy files and push from temp directory
```

### Verification Script

Run the verification script before pushing:
```bash
./scripts/verify-repo-before-push.sh
```

---

## Netlify Deployment

- **Admin Site:** https://divinelink.netlify.app/admin.html
- **Deploys from:** `divine-link-site` repository `main` branch
- **Auto-deploy:** Enabled (pushes to `main` trigger deployment)

---

## Troubleshooting

### "Pushed to wrong repo"
1. Check which repo received the changes
2. If admin.html went to `divine-link`: Copy to `divine-link-site` and push
3. If Swift files went to `divine-link-site`: Copy to `divine-link` and push

### "Changes not showing on Netlify"
1. Verify push went to `divine-link-site` repo
2. Check Netlify deployment logs
3. Wait 1-2 minutes for auto-deploy

### "Git subtree push failed"
- Use the clone-and-copy method instead (more reliable)

---

## Repository URLs

- **divine-link:** `https://github.com/ayoola66/divine-link.git`
- **divine-link-site:** `https://github.com/ayoola66/divine-link-site.git`
- **Netlify Site:** `https://divinelink.netlify.app`

---

**Last Updated:** 2026-02-01  
**Maintained by:** Development Team
