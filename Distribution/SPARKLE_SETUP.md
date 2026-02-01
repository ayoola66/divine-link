# Sparkle Auto-Update Setup Guide

This guide explains how to set up and use Sparkle for Divine Link updates.

## Step 1: Add Sparkle Package to Xcode

1. Open `DivineLink.xcodeproj` in Xcode
2. Go to **File → Add Package Dependencies...**
3. Enter: `https://github.com/sparkle-project/Sparkle`
4. Click **Add Package**
5. When prompted, add `Sparkle` to the `DivineLink` target
6. Build the project to verify it works

## Step 2: Create a GitHub Repository for Releases

1. Create a new repository: `divine-link-releases`
   - Can be public or private
   - If private, you'll need to host appcast.xml elsewhere

2. Enable GitHub Pages:
   - Settings → Pages → Source: Deploy from branch (main)
   - This lets you access appcast.xml at a raw URL

## Step 3: Generate EdDSA Signing Key

Sparkle 2 uses EdDSA signatures to verify updates are from you.

```bash
# Navigate to Sparkle's tools
cd ~/Library/Developer/Xcode/DerivedData/DivineLink-*/SourcePackages/artifacts/sparkle/Sparkle/bin

# Generate a new signing key (save this securely!)
./generate_keys

# This outputs:
# - Private key: Save to your keychain or secure location
# - Public key: Add to Info.plist as SUPublicEDKey
```

**IMPORTANT**: Never commit your private key! Store it in:
- macOS Keychain
- 1Password/Bitwarden
- Environment variable in CI

## Step 4: Update Info.plist with Public Key

After generating keys, update `Info.plist`:

```xml
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY_HERE</string>
```

## Step 5: Create a Release

### 5.1 Archive the App

1. In Xcode: **Product → Archive**
2. In Organizer: **Distribute App → Copy App**
3. Save `DivineLink.app` to a folder

### 5.2 Create ZIP

```bash
cd /path/to/folder/containing/app
zip -r DivineLink-1.0.2.zip DivineLink.app
```

### 5.3 Sign the ZIP

```bash
# Navigate to Sparkle tools
cd ~/Library/Developer/Xcode/DerivedData/DivineLink-*/SourcePackages/artifacts/sparkle/Sparkle/bin

# Sign the archive
./sign_update /path/to/DivineLink-1.0.2.zip

# This outputs an EdDSA signature - copy it!
```

### 5.4 Update appcast.xml

1. Open `Distribution/appcast.xml`
2. Add a new `<item>` entry with:
   - `sparkle:version`: The build number
   - `sparkle:shortVersionString`: The marketing version (1.0.2)
   - `url`: Link to the ZIP on GitHub
   - `sparkle:edSignature`: The signature from step 5.3
   - `length`: File size in bytes

### 5.5 Upload to GitHub

1. Create a new Release: `v1.0.2`
2. Upload `DivineLink-1.0.2.zip` as an asset
3. Update `appcast.xml` with the download URL
4. Commit and push `appcast.xml` to the repository

## Step 6: Verify It Works

1. Build and run the previous version of the app
2. App should detect the new version
3. Click "Check for Updates" to test manually

## Directory Structure

```
divine-link-releases/
├── appcast.xml          ← Sparkle checks this for updates
└── releases/
    ├── DivineLink-1.0.0.zip
    ├── DivineLink-1.0.1.zip
    └── DivineLink-1.0.2.zip
```

## Automated Releases (Optional)

You can automate releases with GitHub Actions:

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      
      - name: Build and Archive
        run: |
          xcodebuild archive \
            -project DivineLink.xcodeproj \
            -scheme DivineLink \
            -archivePath build/DivineLink.xcarchive
      
      - name: Export App
        run: |
          xcodebuild -exportArchive \
            -archivePath build/DivineLink.xcarchive \
            -exportPath build/ \
            -exportOptionsPlist ExportOptions.plist
      
      - name: Create ZIP
        run: |
          cd build
          zip -r DivineLink-${{ github.ref_name }}.zip DivineLink.app
      
      - name: Sign Update
        run: |
          # Sign with private key from secrets
          echo "${{ secrets.SPARKLE_PRIVATE_KEY }}" | ./sign_update build/DivineLink-*.zip
      
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: build/DivineLink-*.zip
```

## Troubleshooting

### "Check for Updates" is disabled
- Sparkle package may not be added correctly
- Check Xcode → Package Dependencies

### No update shown
- Verify appcast.xml is accessible at the URL in Info.plist
- Check version numbers match

### Signature verification failed
- Regenerate keys and update both private key and Info.plist public key
- Re-sign the ZIP file

### App crashes on update
- Ensure the ZIP contains `DivineLink.app` at the root level
- Check console logs for Sparkle errors

## URLs Reference

| Item | URL |
|------|-----|
| Appcast (update feed) | https://divinelink.netlify.app/appcast.xml |
| Landing page | https://divinelink.netlify.app |
| Release downloads | https://divinelink.netlify.app/releases/ |
| GitHub repo (site) | https://github.com/ayoola66/divine-link-site (private) |

## Current Status (as of 26 Jan 2026)

| Task | Status |
|------|--------|
| Sparkle package added | ✅ Complete |
| EdDSA keys generated | ✅ Complete |
| Info.plist configured | ✅ Complete |
| SparkleUpdaterController | ✅ Complete |
| Menu item added | ✅ Complete |
| Settings tab added | ✅ Complete |
| Landing page deployed | ✅ Complete |
| Netlify linked to GitHub | ✅ Complete |
| First signed release | 🔲 Pending |

## Security Notes

1. **Never commit your private signing key**
2. **Always sign updates** - Sparkle will reject unsigned updates
3. **Use HTTPS** for all URLs
4. **Keep previous versions** for rollback capability
