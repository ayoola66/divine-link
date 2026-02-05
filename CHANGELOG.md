# Changelog

All notable changes to Divine Link will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - UNRELEASED

### Added

- **Reference Buffer (Stateful Detection)**: Context-aware scripture detection
  - Remembers previous book/chapter context during sermon
  - "Verse 18" after "John 3:16" correctly resolves to "John 3:18"
  - Handles partial references like "verses 5-7" using last mentioned book/chapter
  - Configurable context timeout (default: 5 minutes)
- **AI-Powered Implicit Detection**: Detect scripture references without explicit citations
  - Detects famous verse quotes (e.g., "I can do all things through Christ...")
  - Handles contextual references ("the verse we just read")
  - Local AI processing using Apple MLX Framework (no cloud costs)
  - Uses quantised Phi-3-mini model for efficiency
- **Pastor Profiles**: Personalised settings per speaker ✅ (Already implemented)
  - Create and switch between pastor profiles
  - Per-pastor preferred Bible translation
  - Speech pattern learning for improved recognition
  - Quick profile switching during services

### Changed

- **Detection Pipeline**: Enhanced to support stateful context and implicit references
- **Settings Panel**: Added Pastor Profiles management section

### Technical

- Added `ReferenceBuffer.swift` - Stateful context management
- Enhanced `ImplicitReferenceDetector.swift` with MLX AI integration
- Added `PastorProfilesView.swift` - Profile management UI
- Added `SpeechCorrectionService.swift` - Per-pastor speech learning
- Updated `ScriptureDetectorService.swift` with context buffer support

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
