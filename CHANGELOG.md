# Changelog

All notable changes to Divine Link will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.6.2] - 2026-08-05

### Added

- **ProPresenter Setup: Same Machine vs. Two Machines topology (Premium)**: Added an explicit topology setting so Divine Link knows whether ProPresenter runs on this Mac or a separate one on the network. Two Machines mode (Premium-gated) is for large events where cabling between machines isn't practical — it offers only the two genuinely networked output paths (Stage Display HTTP, Messages API WebSocket) and hides Keyboard Automation entirely, since keyboard automation is local keystroke simulation and cannot reach an app on a different Mac under any circumstances. Selecting Two Machines without Premium shows the upgrade prompt instead of changing the setting.

### Fixed

- **ProPresenter Configuration docs**: Corrected a stale default port reference (was documented as 1025, actual shipped default is 50233 for ProPresenter 7) and clarified that Accessibility/Keyboard Automation only applies in Same Machine setups.

### Technical

- `ProPresenterSettings.swift`: Added `ProPresenterTopology` enum and persisted `topology` setting; added `effectiveTopology` (clamps to Same Machine unless Premium-entitled) and `effectiveKeyboardAutomationEnabled` (always false outside Same Machine) as the single source of truth for output selection.
- `HybridIntegrationManager.swift`, `ProPresenterOutputProtocol.swift`: All output-selection call sites (`enabledOutputTypes`, `getOutputsInPriorityOrder`, `tryFallback`, `getEnabledOutputs`) now read `effectiveKeyboardAutomationEnabled` instead of the raw toggle. Added a reactive binding on `SubscriptionService`/`AuthService` `objectWillChange` so entitlement changes (login/logout, premium lapse/renew, launch-time resolution) trigger a reconfigure rather than leaving the output set stale.
- `ProPresenterSettingsView.swift`: Added the "ProPresenter Setup" segmented control and topology-aware connection/Keyboard Automation copy.
- `redesign.pen`: Added the ProPresenter Setup control to Screen 04 and its state variants (Default, Selected, Premium-locked) to the off-canvas Interaction & State Coverage board.
- Reviewed by Forge — confirmed no other call site reads the raw `keyboardAutomationEnabled` toggle for output selection, and identified the entitlement-reactivity gap that the `objectWillChange` binding above resolves.

---

## [1.3.8] - 2026-03-15

### Fixed

- **External audio-device transcription stall (critical)**: Resolved a restart scheduling bug where the speech recogniser callback fired on a background thread and `scheduleRestart()` created a `Timer` on a non-spinning background run loop. This could leave transcription permanently stalled after device-switch gaps. Callback handling is now marshalled to the main queue so restart timers reliably fire.
- **Non-default input device initialisation edge case**: Initialised `AVAudioEngine` `inputNode` before `AudioUnitSetProperty` for non-default devices to avoid nil `audioUnit` scenarios during configuration.

### Technical

- `TranscriptionService.swift`: Wrapped recognition callback work in `DispatchQueue.main.async` to ensure timer scheduling occurs on the main run loop.
- `AudioCaptureService.swift`: Added explicit `inputNode` initialisation before applying AudioUnit properties for external/non-default devices.
- Updated packaged release artifacts and Sparkle appcast for `v1.3.8`.

---

## [1.3.7] - 2026-03-15

### Fixed

- **Audio device switch silence regression**: Removed `audioEngine.reset()` inside `recreateAudioEngine()`. The reset call was corrupting Core Audio HAL state after input-device changes, causing newly created engines to return silent buffers.

### Changed

- **BlackHole wording clarity**: Updated settings copy to explain BlackHole is optional and only needed when capturing audio from another app on the same Mac.

### Technical

- `AudioCaptureService.swift`: Removed HAL-corrupting reset path during audio engine recreation.
- `SettingsView.swift`: Updated user-facing copy for BlackHole configuration guidance.
- Updated packaged release artifacts and Sparkle appcast for `v1.3.7`.

---

## [1.3.6] - 2026-03-15

### Fixed

- **Transcription fallback when on-device model unavailable**: Fixed silent transcription failure mode where audio remained active but no text appeared. `requiresOnDeviceRecognition` now checks `supportsOnDeviceRecognition` and falls back to server-based recognition when on-device models are unavailable.

### Technical

- `TranscriptionService.swift`: Added robust capability check and fallback path for devices/environments lacking on-device speech model support.
- Updated packaged release artifacts and Sparkle appcast for `v1.3.6`.

---

## [1.3.5] - 2026-02-11

### Fixed

- **Silent audio capture (critical)**: Removed `audioEngine.reset()` from the `stop()` method. This call was corrupting the Core Audio HAL state, causing all subsequent captures to deliver zero-filled (silent) buffers — even after engine recreation. This was the root cause of the non-functioning audio meter and detection.
- **Race condition at startup**: The device observer and pipeline startup were both calling `setInputDevice()`, causing rapid stop/start cycles that destabilised Core Audio. Added debounce (300ms) to the device observer and skip-if-already-configured logic in the pipeline.
- **Multi-channel USB audio interfaces**: Devices such as the Focusrite Vocaster Two (14 channels) always had channel 0 read, which may be a mix/monitor bus rather than the physical microphone. Now scans all channels to find the one with the highest RMS.
- **Settings disconnected from pipeline**: `AudioSettingsTab` created its own `AudioDeviceManager` and `AudioCaptureService` instances, completely disconnected from the detection pipeline. `AudioDeviceManager` is now a shared singleton.
- **Spacebar shortcut bypassed permission check**: The space key could toggle capture even when microphone permission was denied. Now correctly gated.
- **Pipeline ran without permission**: Audio capture could start and process silent buffers when microphone permission was denied. Added a permission gate in `start()` that blocks capture unless authorised.

### Added

- **Automatic silent-start recovery**: If the first 15 audio buffers are all silent (indicating a corrupted HAL), the engine is automatically recreated and restarted once.
- **Clickable "No Permission" indicator**: The red "No Permission" status dot now opens System Settings directly to the Microphone privacy pane when clicked.
- **Detailed audio diagnostics**: First-buffer logging now reports per-channel RMS for all channels, making it easy to identify which channel carries audio on multi-channel devices.
- **Microphone permission logging**: Permission status (authorised, denied, not determined, restricted) is now explicitly logged at startup with guidance when denied.

### Technical

- `AudioCaptureService.swift`: Removed `reset()` from `stop()`; added permission gate in `start()`; added `performSilentStartRecovery()`; `convertToOptimalFormat()` scans all channels for best RMS; added `openMicrophonePrivacySettings()`; exposed `currentDeviceID` as `private(set)`.
- `DetectionPipeline.swift`: Added `.debounce(for: .milliseconds(300))` to device observer; `start()` skips redundant `setInputDevice` when observer already configured it; added `CoreAudio` import and device ID lookup helper.
- `AudioDeviceManager.swift`: Added `static let shared` singleton for app-wide consistency.
- `SettingsView.swift`: `AudioSettingsTab` uses `AudioDeviceManager.shared` via `@ObservedObject`; "Test Audio" button only toggles if capture actually started.
- `MainView.swift`: Spacebar shortcut gated by `hasPermission`; "No Permission" indicator is now a clickable button.

---

## [1.3.4] - 2026-02-10

### Fixed

- **In-app updates (Sparkle sandbox)**: Resolved "An error occurred while launching the installer" when updating from within the app. Sandboxed builds now have `SUEnableInstallerLauncherService` enabled in Info.plist and the required mach-lookup entitlements (`com.ORekunMedia.DivineLink-spks`, `-spki`) so Sparkle’s Installer XPC Service can run and install updates.

### Technical

- `Info.plist`: Added `SUEnableInstallerLauncherService` = YES.
- `DivineLink.entitlements`: Added `com.apple.security.temporary-exception.mach-lookup.global-name` for Sparkle XPC services.

---

## [1.3.3] - 2026-02-07

### Security & State Fixes

- **Admin Tab Security**: Admin tab now only visible when user is both signed in AND an administrator. Completely hidden for unauthenticated users — airtight logic with no room for cached state leakage.
- **Premium State Enforcement**: Premium features, settings, and UI elements strictly gated behind authentication. Cached subscription data from previous sessions can no longer leak through when not signed in.
- **Reactive Auth Synchronisation**: `SubscriptionService` and `AdManager` now reactively observe `AuthService.$isAuthenticated` via Combine. When a session expires or user signs out, all premium/admin/subscription state resets instantly.
- **Cache Hygiene**: Stale subscription data is now fully cleared from `UserDefaults` on sign-out or session expiry (`removeObject(forKey:)` for cached status, tier, last check, and has-been-paid keys), preventing privileged state from persisting across launches.

### Changed

- `SettingsView.swift`: Admin tab visibility now requires `authService.isAuthenticated && subscriptionService.isAdmin`.
- `SubscriptionService.swift`: Added `observeAuthState()` Combine observer; `loadCachedStatus()` clears cache when not authenticated; `canUsePremiumFeatures` has auth guard; `resetForSignOut()` fully clears all cached state.
- `AdManager.swift`: Added auth state observer; `init()` only loads cached status when authenticated; clears cached `subscriptionStatus` on sign-out.
- `PremiumFeatureGate.swift`: `isPremium` computed property now requires `AuthService.shared.isAuthenticated` before checking subscription status.

---

## [1.3.1] - 2026-02-07

### Added

- **Admin Debug: Simulate Free**: When testing as an admin, Developer Options “Debug: Reset to Free” now correctly shows the free-tier experience (grey tint and ads sidebar). “Debug: Set Premium” restores admin behaviour. Uses `SubscriptionService.debugSimulateFreeMode` so ads and tint follow the simulated state.

### Changed

- **Settings window (Epic 7.1 refinements)**:
  - Settings window is now resizable (drag edges/corners) via `SettingsWindowResizeEnabler`.
  - Single collapse/expand control: system title-bar button toggles between expanded (icons + labels) and icon-only sidebar; sidebar is never fully hidden.
  - Icon-only sidebar width reduced to 44pt for a slimmer strip.
- **Subscription tint (Epic 7.2 refinements)**:
  - Main window tint is always grey when not signed in. Cached tier from a previous session is no longer applied when unauthenticated.
  - `SubscriptionService.loadCachedStatus()` returns early with Mercy (grey) when `!AuthService.shared.isAuthenticated`.
  - `resetForSignOut()` clears subscription state and `debugSimulateFreeMode` so tint and ads update immediately after sign-out.

### Technical

- `SettingsView.swift`: Resize enabler, single collapse behaviour (columnVisibility intercept), 44pt icon-only width.
- `MainView.swift`: Grey tint when not signed in and when `subscriptionService.debugSimulateFreeMode`.
- `SubscriptionService.swift`: `debugSimulateFreeMode`, `loadCachedStatus()` auth guard, `canUsePremiumFeatures` debug override, `resetForSignOut()` clears debug flag.
- `AdViews.swift`: Debug buttons set/clear `SubscriptionService.shared.debugSimulateFreeMode`.
- `docs/epic-7-implementation-guide.md`: Post-implementation refinements and version history.
- `docs/FEATURE-MATRIX.md`: v1.3.2 section updated with Settings and subscription refinements.

---

## [1.3.0] - 2026-02-06

### Added

- **Reference Buffer (Stateful Detection)**: Context-aware scripture detection
  - Remembers previous book/chapter context during sermon
  - "Verse 18" after "John 3:16" correctly resolves to "John 3:18"
  - Handles partial references like "verses 5-7" using last mentioned book/chapter
  - Handles inverted verbal patterns ("verse 31 of Romans eight")
  - Configurable context timeout (default: 5 minutes)
- **Premium Feature Gating**: Detection Settings now require Grace or Love subscription
  - Smart Context Detection settings gated
  - Confidence Display settings gated
  - Low Confidence Handling settings gated
  - Features visible but disabled for free users with "Upgrade" button
- **Pastor Profile Limits**: Tier-based profile limits enforced
  - Mercy (Free): 0 profiles
  - Grace (Premium): 2 profiles maximum
  - Love (Pro): 5 profiles maximum
  - UI clearly displays current count and limit
  - Upgrade prompts when limit reached
- **Modern PaywallView Redesign**: Enhanced subscription upgrade experience
  - Tier comparison section (Grace vs Love)
  - Explicit pastor profile limits displayed (2 vs 5)
  - Device limits clearly stated (2 vs 5)
  - Stripe payment integration (browser-based checkout)
  - Modern card-based UI with tier benefits

### Changed

- **SubscriptionService**: Enhanced tier tracking system
  - Added `SubscriptionTier` enum (mercy, grace, love)
  - Added `currentTier` published property
  - Added `pastorProfileLimit` computed property
  - Updated `APISubscriptionStatus` to include `.grace` and `.love` cases
  - Tier-based feature gating throughout app
- **PastorProfilesView**: Enhanced with tier-based limits
  - Displays current profile count vs limit
  - Shows current tier name
  - Conditional "Add Pastor" button (disabled at limit)
  - Upgrade prompts for free users and at-limit users
- **SettingsView**: Detection Settings tab now premium-gated
  - Entire `DetectionSettingsTab` wrapped with `PremiumFeatureGate`
  - Free users see settings but cannot interact
  - Upgrade button prominently displayed
- **PaywallView**: Complete redesign with tier comparison
  - Header updated: "Choose Grace or Love tier"
  - New tier comparison section with side-by-side cards
  - Explicit feature limits displayed (pastor profiles, devices)
  - Plan selector relabelled as "Choose billing"
  - Premium benefit cards updated with tier-specific limits

### Technical

- Added `ReferenceBuffer.swift` - Stateful context management
- Added `PremiumFeatureGate.swift` - View modifier for feature gating
- Updated `SubscriptionService.swift` with tier enum and limits
- Updated `PastorProfilesView.swift` with limit enforcement
- Updated `SettingsView.swift` with detection settings gating
- Updated `AdViews.swift` (PaywallView) with tier comparison UI
- Updated marketing website (`index.html`) with correct profile limits

### Documentation

- Created `docs/FEATURE-MATRIX.md` - Comprehensive feature matrix (source of truth)
- Updated `Divine-Link-Context.md` with:
  - Pastor profile limits (0/2/5)
  - Detection Settings premium gating
  - Payment method (Stripe)
  - Reference Buffer feature details
  - Updated version to 1.3.0
- Updated `CHANGELOG.md` with all recent changes

### Pending

- ⏳ **AI-Powered Implicit Detection** (Story 7.2): MLX/Phi-3 integration for implicit references

---

## [1.2.0] - 2026-02-05

### Added

- **Panic Button (Clear Screen)**: Instantly clear all displayed scripture from ProPresenter with a single keypress
  - Keyboard shortcut: ⌘⇧C (Command + Shift + C)
  - Works for both Stage Display and Audience Display
  - Clears ProPresenter messages without affecting Divine Link's verse history
- **Detection Confidence Indicator**: Visual feedback showing recognition confidence
  - Real-time confidence levels displayed for each detected verse
  - Colour-coded indicators: green (high), amber (medium), red (low)
  - Helps identify when to manually verify scripture references
- **WebSocket Messages API**: New ProPresenter integration method
  - Direct WebSocket connection to ProPresenter's Messages API
  - Faster, more reliable scripture display than keyboard automation
  - Automatic reconnection on connection loss
- **Hybrid Integration Manager**: Intelligent multi-path ProPresenter communication
  - Stage Display (HTTP): Original network API integration
  - Audience Display (WebSocket): New Messages API integration
  - Audience Display (Keyboard): Fallback keyboard automation
  - Auto-fallback: If primary method fails, automatically tries alternatives
  - Premium feature: Multiple output paths require Grace or Love subscription
- **Connection Dashboard**: Visual status for all ProPresenter output paths
  - Real-time connection status indicators
  - Test buttons for each output method
  - Clear status indicators (connected/disconnected/error)
- **Output Path Settings**: Granular control over ProPresenter integration
  - Enable/disable individual output methods
  - Configure auto-fallback behaviour
  - Premium gating for advanced features

### Changed

- **ProPresenter Settings**: Redesigned settings panel with new output path controls
  - Added toggles for each integration method
  - Added connection dashboard section
  - Premium badge on advanced features
- **Clear Button Behaviour**: Now only clears ProPresenter displays
  - No longer clears Divine Link's local scripture history
  - Preserves detected verses for reference during service

### Technical

- Added `ProPresenterOutputProtocol.swift` - Protocol and factory for output abstraction
- Added `StageDisplayOutput.swift` - HTTP REST output implementation
- Added `AudienceWebSocketOutput.swift` - WebSocket Messages API implementation  
- Added `AudienceKeyboardOutput.swift` - Keyboard automation implementation
- Added `HybridIntegrationManager.swift` - Central coordinator for all outputs
- Updated `ProPresenterSettings.swift` with new output path settings
- Updated `ProPresenterSettingsView.swift` with output toggles and connection dashboard
- Updated `ProPresenterClient.swift` with expanded error handling
- Updated `PanicButtonService.swift` to use HybridIntegrationManager for multi-path clear
- Added App Category (Utilities) to Info.plist
- Fixed SQLite string binding using SQLITE_TRANSIENT
- Fixed build warnings for deprecated APIs and actor isolation

## [1.1.0] - 2026-02-01

### Added

- **Video & GIF Ad Support**: Ads now support animated content
  - YouTube video embeds (including Shorts) with auto-loop and muted playback
  - Animated GIF support with smooth looping
  - Direct MP4 video file support
  - Automatic fallback to static image if video fails
  - Privacy-enhanced YouTube embedding (youtube-nocookie.com)
  - Minimised YouTube branding where possible
- **Dynamic Ad System**: Complete backend-served advertisement system
  - Admin dashboard at `/admin.html` for managing ads
  - Support for three ad formats: Square (1:1), Portrait (9:16), Banner (728×90)
  - Real-time ad updates without app restart (15-minute refresh)
  - Automatic ad rotation every 5 minutes
  - Ad enforcement system to pin specific ads
  - Local caching for offline support (7-day grace period)
  - Click and impression tracking
  - Always-visible ad titles with transparent overlay
- **Admin Dashboard**: Password-protected web interface
  - Live preview mirroring exact app layout
  - Create/edit/delete ads with visual preview
  - Statistics dashboard (views, clicks, CTR)
  - Enforce/release ads with visual indicators
  - Active ads summary showing counts per format
- **Smart Ad Layout**: Dynamic sidebar layout based on available ads
  - Default: 1 square placeholder + 1 portrait placeholder
  - With ads: Automatically adjusts (1-3 squares + portrait if available)
  - Blue "Remove Ads" button always visible at bottom
  - Banner ad space at bottom (full width)
- **User Authentication**: Email OTP (one-time password) login system
  - Sign in with email verification code
  - Secure session storage in Keychain
  - Account management in Settings
- **Device Management**: Track and manage registered devices
  - Maximum 2 devices per account
  - View and remove devices from Settings
  - Automatic device registration on login
- **Subscription Backend**: Supabase integration for subscription management
  - Real-time subscription status sync
  - Offline grace period (7 days)
  - Stripe payment integration ready
- **Account Settings Tab**: New tab in Settings for account management
  - Sign in/out functionality
  - Device management
  - Subscription status display

### Changed

- **Ad Display Logic**: Replaced placeholder system with dynamic Supabase-served ads
  - Ads fetched from Supabase database
  - Format-based ad matching (square/portrait/banner)
  - No ad repetition unless multiple ads exist in database
- **Sidebar Layout**: Intelligent layout based on available ad formats
  - Shows portrait placeholder when no portrait ad exists
  - Automatically hides portrait slot when 3+ square ads present
  - "Remove Ads" button styled with blue background, white text

### Technical

- Added `VideoPlayerView` component with URL type detection (YouTube/GIF/MP4)
- Added `YouTubeWebView` for embedding YouTube videos via WKWebView with HTML injection
- Added `GIFWebView` for animated GIF display via WKWebView
- Added YouTube video ID extraction supporting multiple URL formats (watch, shorts, embed, youtu.be)
- Updated `get_all_active_ads()` RPC function to include `video_url` and `media_type` columns
- Added `NSAllowsArbitraryLoadsInWebContent` to Info.plist for web content loading
- Updated admin.html with video preview support and improved layout
- Admin form now uses side-by-side layout for compact design
- Added `DynamicAdService` singleton for ad management
- Added `DynamicAd` model with format, video URL, and media type support
- Added `AdFormat` enum (square, portrait, banner) with aspect ratios
- Added `SingleAdView` and `AdPlaceholderView` components
- Added `PortraitPlaceholderView` for empty portrait slots
- Created `ads` table in Supabase with RLS policies
- Created `record_ad_event()` RPC function for tracking
- Added automatic server refresh timer (15 minutes)
- Added ad rotation timer (5 minutes)
- Added local JSON caching system
- Added favicon to website pages

## [1.0.2] - 2026-01-31

### Added

- **Sparkle Auto-Updates**: Automatic update checking and installation
  - Check for Updates in app menu (⌘U)
  - Updates tab in Settings for configuration
  - Automatic background checks every 24 hours
  - EdDSA signed updates for security
- **Ad-Supported Free Version**: App now supports advertisements for free users
  - Right sidebar with 2-3 ad slots (1:1 square or 9:16 portrait format)
  - Bottom banner ad across the full width
  - Premium subscription option to remove all ads
- **Premium Subscription**: New subscription management in Settings
  - Premium tab in Settings for managing subscription
  - Upgrade to Premium to remove advertisements
  - Trial period support
  - Restore purchases functionality
- **Subscription Settings Tab**: Dedicated tab for subscription management

### Changed

- **Default Font Size**: Changed from Small to Medium for better readability
  - New users now start with Medium (Level 2) font size
  - Users can reduce to Small (Level 1) if preferred
- **Window Size**: Adjusted minimum/ideal sizes to accommodate ad layout
  - Free version: Wider window to fit sidebar ads
  - Premium version: Original compact layout

### Improved

- **Scripture Detection Validation**: Added stricter validation for verse numbers
  - Reject verse numbers above 176 (longest chapter is Psalm 119)
  - Reject invalid verse ranges (start > end)
  - Log suspicious high chapter numbers for review
  - Reject verse ranges spanning more than 30 verses (unusual)

### Technical

- Added Sparkle framework for auto-updates
- Added SparkleUpdaterController for update management
- Added AdManager for subscription and ad state management
- Added AdContainerView, AdSidebarView, AdBannerView components
- Subscription state persisted to UserDefaults
- Placeholder ad slots ready for ad network integration

## [1.0.1] - 2026-01-27

### Added

- **Accessibility Settings**: New Display settings tab with font size scaling (5 levels)
  - Level 1: Default size
  - Level 2: Medium (+2 points)
  - Level 3: Large (+4 points)
  - Level 4: Extra Large (+6 points)
  - Level 5: Maximum (+8 points)
- **ProPresenter Audience Push**: Push verses directly to ProPresenter's Audience screen via native Bible feature
  - Automatically clicks Bible toolbar button to switch to Bible view
  - Types scripture reference into search field
  - Presses Enter to display on Audience screen
- **Window Resizability**: Main window can now be freely resized by dragging edges/corners
- **Dynamic Version Display**: About tab now reads version from app bundle
- **Build Number Display**: Shows build number in About tab

### Improved

- **Scripture Detection**: Better handling of numbered book prefixes (e.g., "1 Timothy")
  - Fixed issue where "1 to" was incorrectly matching to "1 Timothy"
- **ProPresenter Integration**: More robust keyboard automation
  - Clicks Bible button first to ensure correct view
  - Improved search field focus detection
  - Fallback mechanisms for accessibility API limitations

### Fixed

- Fixed AXValue and AXUIElement type casting issues in macOS Accessibility APIs
- Fixed `kAXSearchFieldRole` reference (using string literal instead)
- Improved scripture parser to reject excluded words with number prefixes

## [1.0.0] - 2026-01-17

### Added

- Initial release of Divine Link
- **Live Speech-to-Text**: Real-time transcription of spoken words
- **Scripture Detection**: Automatic detection of Bible verse references
  - Supports multiple formats: "John 3:16", "John chapter 3 verse 16", spoken numbers
  - Fuzzy matching for misheard book names
- **Multi-Verse Support**: Detects and displays verse ranges (e.g., John 3:16-18)
- **Bible Database**: Built-in KJV, ASV, and WEB translations
- **ProPresenter Stage Integration**: Push verses to ProPresenter Stage screen via Network API
- **Pastor Profiles**: Save and load pastor-specific speech corrections
- **Service Sessions**: Track scriptures by service with auto-archival
- **Audio Level Monitoring**: Visual audio level indicator with peak detection
- **Transcript Editing**: Manual correction of misheard transcripts
- **BlackHole Support**: System audio capture for stream monitoring
- **Menu Bar Quick Access**: Quick access icon in macOS menu bar
- **Settings Panels**:
  - Audio input configuration
  - ProPresenter connection settings
  - Pastor profile management
  - Service history browser

---

## Version Numbering

Divine Link follows [Semantic Versioning](https://semver.org/):

- **MAJOR.MINOR.PATCH** (e.g., 1.0.1)
- **MAJOR**: Breaking changes or major feature overhauls
- **MINOR**: New features, backwards compatible
- **PATCH**: Bug fixes and minor improvements

## Release Notes Format

Each release includes:

- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Features to be removed in future
- **Removed**: Features removed in this release
- **Fixed**: Bug fixes
- **Security**: Security-related changes
