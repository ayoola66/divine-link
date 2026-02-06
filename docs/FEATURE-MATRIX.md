# Divine Link - Feature Matrix

**Last Updated:** 5 February 2026  
**Version:** 1.3.0  
**Status:** Source of Truth Document

---

## Purpose

This document serves as the **definitive source of truth** for:
- Feature listings for marketing/ad copy
- Tier restrictions and limits
- Premium feature gating
- Developer/AI agent reference
- Update planning and changelog generation

---

## Subscription Tiers Overview

| Tier | Price (Monthly) | Price (Annual) | Pastor Profiles | Devices | Detection Settings |
|------|----------------|----------------|-----------------|----------|-------------------|
| **Mercy** (Free) | £0 | £0 | 0 | 1 | ✗ |
| **Grace** (Premium) | £9.99 | £79.99 (save 33%) | 2 | 2 | ✓ |
| **Love** (Pro) | £19.99 | £149.99 (save 37%) | 5 | 5 | ✓ |

---

## Complete Feature Matrix

### Core Detection Features

| Feature | Mercy | Grace | Love | Notes |
|---------|-------|-------|------|-------|
| **Live Speech Detection** | ✓ | ✓ | ✓ | Real-time transcription |
| **Scripture Detection Algorithm** | ✓ | ✓ | ✓ | Full pattern matching |
| **Standard Format Detection** | ✓ | ✓ | ✓ | "John 3:16" |
| **Verbal Format Detection** | ✓ | ✓ | ✓ | "John chapter 3 verse 16" |
| **Spoken Numbers** | ✓ | ✓ | ✓ | "John three sixteen" |
| **Verse Ranges** | ✓ | ✓ | ✓ | "John 3:16-18" |
| **Chapter Only** | ✓ | ✓ | ✓ | "John chapter 3" |
| **Inverted Verbal** | ✓ | ✓ | ✓ | "verse 31 of Romans eight" |
| **Reference Buffer (Stateful)** | ✗ | ✓ | ✓ | Context-aware partial references |
| **Implicit Detection (AI)** | ✗ | ✗ | ✓ | Coming in v1.3.0 |

### Detection Settings

| Feature | Mercy | Grace | Love | Notes |
|---------|-------|-------|------|-------|
| **Smart Context Detection** | ✗ | ✓ | ✓ | Reference buffer settings |
| **Confidence Display** | ✗ | ✓ | ✓ | Visual confidence indicators |
| **Low Confidence Handling** | ✗ | ✓ | ✓ | Options for uncertain detections |
| **Context Timeout Configuration** | ✗ | ✓ | ✓ | Default: 5 minutes |

### Bible Translations

| Feature | Mercy | Grace | Love | Notes |
|---------|-------|-------|------|-------|
| **KJV (King James Version)** | ✓ | ✓ | ✓ | Default translation |
| **Additional Translations** | ✗ | ✓ | ✓ | ESV, NIV, NASB, NLT, NKJV, etc. |
| **Per-Pastor Translation** | ✗ | ✓ | ✓ | Saved in pastor profiles |

### ProPresenter Integration

| Feature | Mercy | Grace | Love | Notes |
|---------|-------|-------|------|-------|
| **Stage Screen Push (REST API)** | ✓ | ✓ | ✓ | HTTP API integration |
| **Audience Screen (Keyboard)** | ✗ | ✓ | ✓ | Accessibility automation |
| **Audience Screen (Messages API)** | ✗ | ✓ | ✓ | WebSocket integration (recommended) |
| **Hybrid Integration Manager** | ✗ | ✓ | ✓ | Multi-path output routing |
| **Connection Dashboard** | ✗ | ✓ | ✓ | Visual status indicators |
| **Panic Button (Clear Screen)** | ✓ | ✓ | ✓ | ⌘⇧C or F12 |

### Pastor Profiles

| Feature | Mercy | Grace | Love | Notes |
|---------|-------|-------|------|-------|
| **Profile Creation** | ✗ | ✓ (2 max) | ✓ (5 max) | Tier-based limits |
| **Per-Pastor Translation** | ✗ | ✓ | ✓ | Saved preferences |
| **Speech Corrections** | ✗ | ✓ | ✓ | Custom mappings |
| **Quick Profile Switching** | ✗ | ✓ | ✓ | During service |

### Session Management

| Feature | Mercy | Grace | Love | Notes |
|---------|-------|-------|------|-------|
| **Sessions Per Month** | 8 | Unlimited | Unlimited | Free tier limit |
| **Detections Per Session** | Unlimited | Unlimited | Unlimited | No limit |
| **Session History** | ✗ | ✗ | ✓ | View past services |
| **Session Export** | ✗ | ✗ | ✓ | Export data |

### User Experience

| Feature | Mercy | Grace | Love | Notes |
|---------|-------|-------|------|-------|
| **Multi-Verse Display** | ✓ | ✓ | ✓ | Verse ranges |
| **Verse Navigation** | ✓ | ✓ | ✓ | ◀ ▶ buttons |
| **Push One vs Push All** | ✓ | ✓ | ✓ | Selective sending |
| **Audio Level Monitoring** | ✓ | ✓ | ✓ | Visual indicator |
| **Transcript Editing** | ✓ | ✓ | ✓ | Manual corrections |
| **Menu Bar Quick Access** | ✓ | ✓ | ✓ | macOS integration |

### Advertising & Monetisation

| Feature | Mercy | Grace | Love | Notes |
|---------|-------|-------|------|-------|
| **Sidebar Advertisements** | ✓ | ✗ | ✗ | Free tier only |
| **Banner Advertisements** | ✓ | ✗ | ✗ | Bottom banner |
| **Video Ad Support** | ✓ | ✗ | ✗ | YouTube/GIF/MP4 |
| **Ad-Free Experience** | ✗ | ✓ | ✓ | No ads |

### Account & Subscription

| Feature | Mercy | Grace | Love | Notes |
|---------|-------|-------|------|-------|
| **Email OTP Login** | ✓ | ✓ | ✓ | Account creation |
| **Device Management** | ✓ (1) | ✓ (2) | ✓ (5) | Tier-based limits |
| **Subscription Sync** | ✓ | ✓ | ✓ | Real-time via Supabase |
| **Offline Grace Period** | ✓ | ✓ | ✓ | 7 days |
| **Stripe Payment** | ✗ | ✓ | ✓ | Browser-based checkout |

### Support & Updates

| Feature | Mercy | Grace | Love | Notes |
|---------|-------|-------|------|-------|
| **Email Support** | ✓ | ✓ | ✓ | Basic support |
| **Priority Support** | ✗ | ✗ | ✓ | Faster response |
| **Auto-Updates (Sparkle)** | ✓ | ✓ | ✓ | Background updates |
| **Early Access Features** | ✗ | ✗ | ✓ | Beta features |

### Advanced Features (Future)

| Feature | Mercy | Grace | Love | Notes |
|---------|-------|-------|------|-------|
| **Auto-Advance Slideshow** | ✗ | ✗ | ✓ | Planned |
| **Church Site Licence** | ✗ | ✗ | ✓ | Planned |
| **AI Implicit Detection** | ✗ | ✗ | ✓ | v1.3.0 (Story 7.2) |

---

## Premium Feature Gating

### Features Gated Behind Premium (Grace/Love)

1. **Detection Settings**
   - Smart Context Detection
   - Confidence Display
   - Low Confidence Handling
   - Context Timeout Configuration

2. **Pastor Profiles**
   - Profile creation (Grace: 2, Love: 5)
   - Per-pastor translations
   - Speech corrections

3. **ProPresenter Advanced Integration**
   - Messages API (WebSocket)
   - Hybrid Integration Manager
   - Connection Dashboard

4. **Bible Translations**
   - All translations except KJV

5. **Session Management**
   - Unlimited sessions (Mercy: 8/month)
   - Session history (Love only)
   - Session export (Love only)

6. **Account Features**
   - Multiple devices (Grace: 2, Love: 5)
   - Ad-free experience

### UI Gating Implementation

- **PremiumFeatureGate View Modifier:** Wraps premium features
- **Visual State:** Features visible but greyed out/disabled
- **Upgrade Button:** Prominent "Upgrade" button in gated sections
- **PaywallView:** Modern tier comparison modal
- **Stripe Integration:** Browser-based payment flow

---

## Payment & Subscription Details

### Payment Method
- **Provider:** Stripe
- **Flow:** Browser-based checkout (opens in default browser)
- **Billing:** Monthly or Annual (annual saves 33-37%)
- **Currency:** GBP (£)

### Subscription Management
- **Backend:** Supabase
- **Sync:** Real-time subscription status
- **Offline:** 7-day grace period
- **Device Limits:** Enforced per tier

### Upgrade Flow
1. User clicks "Upgrade" button
2. PaywallView displays tier comparison
3. User selects billing period (monthly/annual)
4. Stripe Checkout opens in browser
5. Payment processed via Stripe
6. Subscription status synced to Supabase
7. App features unlocked immediately

---

## Version History & Feature Tracking

### v1.3.0 (Current - Unreleased)
- ✅ Reference Buffer (Stateful Detection) - Story 7.1
- ✅ Premium Paywall UX Upgrade
- ✅ Detection Settings Premium Gating
- ✅ Pastor Profile Limits Enforcement (0/2/5)
- ✅ PaywallView Tier Comparison Redesign
- ⏳ AI-Powered Implicit Detection - Story 7.2 (Pending)

### v1.2.0 (Released)
- ✅ Panic Button (Clear Screen)
- ✅ Detection Confidence Indicator
- ✅ WebSocket Messages API
- ✅ Hybrid Integration Manager
- ✅ Connection Dashboard

### v1.1.0 (Released)
- ✅ Dynamic Ad System
- ✅ Premium Subscription
- ✅ Video Ad Support
- ✅ User Authentication
- ✅ Device Management

---

## Marketing Copy Guidelines

### For Ad Copy & Website
- **Emphasise:** "Free forever" for Mercy tier
- **Highlight:** Pastor profile limits (2 for Grace, 5 for Love)
- **Feature:** Detection Settings as premium benefit
- **Mention:** Stripe payment (no App Store commission = better value)

### For App Store
- **Focus:** Core detection features available in free tier
- **Differentiate:** Clear value proposition for Grace vs Love
- **Highlight:** Unlimited sessions for premium tiers
- **Emphasise:** Ad-free experience for premium

---

## Developer Notes

### Key Files for Feature Gating
- `SubscriptionService.swift` - Tier tracking and limits
- `PremiumFeatureGate.swift` - View modifier for gating
- `PaywallView.swift` - Upgrade UI with tier comparison
- `PastorProfilesView.swift` - Profile limit enforcement
- `SettingsView.swift` - Detection Settings gating

### Tier Enum Structure
```swift
enum SubscriptionTier {
    case mercy  // Free: 0 profiles, 1 device
    case grace  // Premium: 2 profiles, 2 devices
    case love   // Pro: 5 profiles, 5 devices
}
```

### Feature Check Pattern
```swift
if subscriptionService.currentTier != .mercy {
    // Premium feature available
}
```

---

## Change Log Template

When adding new features, update:
1. This feature matrix
2. `Divine-Link-Context.md` (Section 4: Subscription Tiers)
3. `CHANGELOG.md` (with version entry)
4. `app-store-copy.md` (if App Store relevant)
5. Marketing website (`index.html`)

---

**This document is the authoritative source for all feature listings and tier restrictions.**
