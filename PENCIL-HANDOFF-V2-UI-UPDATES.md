# Pencil Handoff: Divine Link v2 UI Updates

Use this document as the single instruction source when updating:

`/Users/ayoogunrekun/Projects/Divine Link/redesign.pen`

## High-Level Goal

Update the existing Divine Link v2 redesign to include every user-facing feature added after the original 15-screen Pencil baseline of 22 April 2026.

Preserve the existing visual language, layout model, Free/Premium distinction, sidebar architecture and screen content unless this handoff explicitly changes them.

Do not redesign from scratch.

## Source of Truth

The current behaviour is represented by the Xcode DerivedData debug build and these project files:

- `REDESIGN-SPEC-v2.0.0.md`
- `PENCIL-HANDOFF-TRANSCRIPT-LEARNING.md`
- `DivineLink/DivineLink/App/MainView.swift`
- `DivineLink/DivineLink/App/SettingsView.swift`
- `DivineLink/DivineLink/Features/Auth/AuthViews.swift`
- `DivineLink/DivineLink/Features/Transcription/WhisperDownloadView.swift`
- `DivineLink/DivineLink/Features/Transcription/TranscriptTextView.swift`

## Required Screen Updates

### Screens 01 and 02: Listen — Free and Premium

Add these controls and states to both Listen screens:

1. **Quick microphone selector**
   - Compact microphone/device pill in the status row.
   - Shows the selected input device.
   - Menu lists available devices, marks the current device and includes Refresh.
   - Switching devices happens without opening Settings.

2. **Global Bible-version selector**
   - Remains in the top status row.
   - Controls the default translation for future detections.

3. **Per-card Bible-version selector**
   - Every detected scripture card has its own version chip/menu.
   - Changing it updates only that card.
   - It must not change the global selector.
   - Show grouped Free and Premium versions where appropriate.
   - Include selected, locked, downloading and unavailable states.

4. **Dynamic scripture cards**
   - Unselected cards use a compact two-line preview.
   - Selected cards expand to show the complete verse text.
   - Multi-verse cards support collapsed and expanded states.
   - Longer translations must expand cleanly without clipping.

5. **Transcript correction and learning**
   - Retain all transcript phrases for the current service in a scrollable stream.
   - Show `Select words to edit`.
   - Selecting text enables a pencil correction affordance.
   - Correction popover contains:
     - `Heard` — read-only original text.
     - `Replace with` — editable corrected text.
     - `Cancel` and `Apply`.
   - After Apply:
     - Update the transcript immediately.
     - Mark corrected text subtly.
     - Show `Saved to learning` feedback.

6. **Transcript scrolling**
   - Add an Auto-scroll on/off control.
   - Show Jump to Live when the operator is away from the latest transcript line.
   - New text must continue arriving while manual scroll position is preserved.

7. **Recognition status**
   - Represent Standard Recognition and Enhanced Recognition clearly.
   - Include loading/standby, ready, fallback and unavailable states.
   - Do not imply that Enhanced Recognition is available on Intel Macs.

8. **Preserve existing operator controls**
   - New Service.
   - Start/Pause.
   - Clear/Panic.
   - Push.
   - Delete.
   - Close.
   - Audio, Speech and Detection status.
   - Confidence indicators and held low-confidence states.

### Screen 06: Onboarding

Extend the existing onboarding sequence:

1. Connect ProPresenter.
2. Choose the default Bible translation.
3. Test the microphone/input device.
4. **Apple-Silicon only:** offer Enhanced Recognition download.

Enhanced Recognition states:

- Download approximately 464 MB.
- Real progress percentage and downloaded-size information.
- Interrupted/failed download.
- Retry.
- Installed.
- Use standard recognition.

Rules:

- Intel users must not see this step.
- Skipping or failing the download must not block app use.
- If dismissed without an explicit decision, the offer may return later.

### Screen 09: Settings — Account

Update the Account screen with:

1. Email and current subscription tier.
2. **Your Details — read-only by default**
   - First name.
   - Last name.
   - Church name.
   - Empty values display `Not set`.
   - Edit button reveals the form.
3. **Edit state**
   - First name, Last name and Church name fields.
   - Save and Cancel.
   - Cancel restores saved values.
   - Save exits edit mode only after success.
   - Show inline success and error feedback.
4. **Billing**
   - Manage Billing button.
   - Explain that Stripe securely manages address, payment methods, invoices and cancellation.
   - Include loading, invalid-session, no-billing-account and retry states.
5. **Registered Devices**
   - Current count and tier limit.
   - Device name.
   - `This device` badge.
   - Last-active information.
   - Empty, loading and limit-reached states.

The app may prefill name information from Stripe, but church name remains app-managed. Editing app profile details must not imply that Stripe billing details are also changed.

### Screen 10: Settings — Audio

Add or confirm:

1. Input-device selector and Refresh.
2. Audio test with live level meter.
3. Clear optional BlackHole guidance.
4. **Enhanced Recognition management**
   - Not installed.
   - Downloading with real progress.
   - Installed.
   - Failed.
   - Retry.
   - Apple-Silicon-only explanation.
   - Standard-recognition fallback.
5. Current recognition-engine status.

An explicit Standard/Enhanced A/B selector is a proposed v2 control, not a currently shipped control. Include it only as a clearly labelled target-state proposal.

### Screen 11: Settings — Detection

Preserve:

- Smart Context Detection.
- Context timeout.
- Confidence indicators.
- Detailed confidence breakdown.
- Hold low-confidence detections.
- Threshold control.
- Optional warning sound.
- Confidence preview.

Numbered-book recognition and reverse-order reference recognition are behavioural improvements and require no new controls.

### Screen 12: Settings — Display

Combine both design and implemented requirements:

- Light, Dark and System theme controls from the original redesign.
- Font-size/accessibility scaling from the current app.
- Live scripture-card preview.
- Ensure large text does not clip cards or settings content.

### New Screen 16: Settings — Bible Versions

Add a dedicated settings screen and navigation item.

Group versions into:

- Included/Free.
- Premium/downloadable.

Each version row may show:

- Bundled.
- Download.
- Downloading percentage.
- Installed.
- Delete.
- Premium locked.
- Upgrade action.
- Failed/retry.
- Attribution information.

The version catalogue must support:

- KJV.
- WEB.
- ASV.
- BSB.
- LSV.
- WEBBE.
- YLT.
- Darby.
- DRA.
- BBE.

The design must scale beyond ten versions without requiring another redesign.

### Settings — About

Add:

- Bible-version attributions.
- Contact Us for eligible paid or previous-paid customers.
- Contact form loading, validation, sent and failure states.

## Navigation Resolution

Use the v2 primary navigation as the canonical location for:

- Listen.
- History.
- Pastors.
- Settings.

Do not duplicate History and Pastors as Settings destinations in the v2 design.

Settings navigation should include:

- Account.
- Audio.
- Detection.
- ProPresenter.
- Display.
- Bible Versions.
- Admin.
- Updates.
- About.

## Free and Premium Behaviour

- Free Listen retains the ad rail and bottom banner.
- Premium Listen remains ad-free.
- Transcript correction and learning are available to both tiers.
- Free users see only available Free Bible versions.
- Premium versions show clear lock/upgrade states for Free users.
- Premium users can download and manage eligible versions.

## Required Component States

For every added control, provide relevant:

- Default.
- Hover.
- Focus.
- Selected.
- Disabled.
- Loading.
- Success.
- Empty.
- Error.
- Offline/fallback.
- Premium locked.

## Do Not Add as Shipped Features

These remain proposals or deferred work:

- Recognition-engine A/B selector.
- iPad-specific interface.
- Licensed NIV, NLT, NKJV, ESV or other unlicensed translations.
- Webhook monitoring and reconciliation controls.
- Website release-management controls.

## Completion Checklist

- [ ] Listen Free contains all new operator controls and card states.
- [ ] Listen Premium contains the same functional controls without ads.
- [ ] Global and per-card translation behaviour are visually distinct.
- [ ] Dynamic scripture-card states are shown.
- [ ] Transcript correction and learning flow is complete.
- [ ] Auto-scroll and Jump to Live states are shown.
- [ ] Enhanced Recognition onboarding and Settings states are shown.
- [ ] Account read-only, Edit, Billing and Registered Devices states are shown.
- [ ] Bible Versions settings screen and navigation are present.
- [ ] Display includes both theme and accessibility controls.
- [ ] History and Pastors are not duplicated under Settings.
- [ ] Free/Premium, Apple-Silicon/Intel and loading/error states are represented.
- [ ] Existing v2 visual language and layout remain consistent.
