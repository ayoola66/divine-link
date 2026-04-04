# Direct Distribution Trust & Privacy Checklist

This checklist ensures users who install Divine Link from the website get a smooth macOS installation experience without avoidable Gatekeeper warnings or privacy confusion.

## 1) Sign every release with Developer ID

- Sign the app with a valid **Developer ID Application** certificate.
- Use the same Team ID consistently for every release.
- Do not distribute unsigned or ad-hoc signed builds.

## 2) Notarise every release

- Submit each release archive to Apple notarisation.
- Wait for successful notarisation before publishing.
- Staple the notarisation ticket to the app/ZIP before upload.

## 3) Verify locally before publishing

Run these checks on the final release artifact:

```bash
# Verify signature
codesign --verify --deep --strict --verbose=2 "DivineLink.app"

# Verify Gatekeeper acceptance
spctl --assess --type execute --verbose "DivineLink.app"

# Verify notarisation ticket is stapled
xcrun stapler validate "DivineLink.app"
```

If any check fails, do not publish.

## 4) Keep permission prompts transparent

- Ensure `NSMicrophoneUsageDescription` clearly explains why microphone access is needed.
- Only request permissions when the feature is used.
- Keep Privacy Policy aligned with actual data collection behaviour.

## 5) Publish from trusted channels only

- Host downloads only on official Divine Link channels (Netlify site + known domain).
- Keep release file names and version numbers consistent with `appcast.xml` and `releases.html`.
- Publish checksums for released ZIP files where possible.

## 6) Sparkle update integrity

- Sign update archives with Sparkle signing key.
- Validate `appcast.xml` signatures and lengths match uploaded artifacts.
- Never publish an appcast entry that points to an un-notarised build.

## 7) Release go/no-go gate

Release is **GO** only if all are true:

- [ ] Developer ID signature valid
- [ ] Notarisation succeeded
- [ ] Stapling validated
- [ ] Gatekeeper assessment passes
- [ ] Sparkle appcast entry verified
- [ ] Privacy/Terms pages reflect current behaviour

