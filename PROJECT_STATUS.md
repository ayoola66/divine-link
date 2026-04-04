# Divine Link - Project Status

Last Updated: 4 April 2026

## Current Version: 1.3.8

## Current Release Snapshot

- **Latest app release**: `v1.3.8` (external device transcription fix)
- **Recent release train**:
  - `v1.3.8` - external device transcription fix (timer/run loop + non-default device init guard)
  - `v1.3.7` - audio device switch fix + BlackHole wording clarity
  - `v1.3.6` - transcription fallback fix + notarised build
- **Distribution**: Sparkle appcast + Netlify release artifacts are active for direct distribution.

> Note: The phase tables below are retained as historical implementation records from the initial rollout and do not represent current live version numbering.

---

## Monetisation Strategy

Divine Link uses a **freemium model**:

| Tier | Price | Features |
|------|-------|----------|
| Free | £0 | Full app functionality + ads |
| Premium | £9.97/month | Ad-free experience |

**Distribution**: Direct sales via website (not App Store initially)

---

## Implementation Phases

### ✅ Phase 1: Sparkle Auto-Updates (COMPLETE)

**Goal**: Enable automatic updates for direct distribution outside App Store

| Task | Status | Notes |
|------|--------|-------|
| Add Sparkle framework | ✅ Done | Via Swift Package Manager |
| Generate EdDSA signing keys | ✅ Done | Private key in Keychain |
| Configure Info.plist | ✅ Done | Feed URL, public key, settings |
| Create SparkleUpdaterController | ✅ Done | `SparkleUpdater.swift` |
| Add "Check for Updates" menu | ✅ Done | ⌘U shortcut |
| Add Updates tab in Settings | ✅ Done | Auto-check toggle, manual check |
| Create appcast.xml template | ✅ Done | `Distribution/netlify-site/appcast.xml` |
| Create landing page | ✅ Done | `Distribution/netlify-site/index.html` |
| Deploy to Netlify | ✅ Done | https://divinelink.netlify.app |
| Link GitHub repo | ✅ Done | Auto-deploys on push |

**Files Created**:
- `DivineLink/App/SparkleUpdater.swift`
- `Distribution/SPARKLE_SETUP.md`
- `Distribution/netlify-site/index.html`
- `Distribution/netlify-site/appcast.xml`
- `Distribution/netlify-site/netlify.toml`

---

### ✅ Phase 2: Supabase Backend (CODE COMPLETE)

**Goal**: User authentication, subscription management, device tracking

| Task | Status | Notes |
|------|--------|-------|
| Create SupabaseConfig | ✅ Done | API keys configured |
| Create database schema | ✅ Done | `supabase-schema.sql` |
| Create AuthService | ✅ Done | Email OTP login |
| Create SubscriptionService | ✅ Done | Premium status sync |
| Create DeviceManager | ✅ Done | 2-device limit |
| Create Login UI | ✅ Done | `AuthViews.swift` |
| Create Account UI | ✅ Done | Device management |
| Update AdManager | ✅ Done | Real subscription integration |
| Add Account tab to Settings | ✅ Done | `SettingsView.swift` |
| Create Stripe webhook | ✅ Done | `stripe-webhook/index.ts` |
| Create setup documentation | ✅ Done | `PHASE2_SETUP.md` |

**Files Created**:
- `DivineLink/Services/SupabaseConfig.swift`
- `DivineLink/Services/AuthService.swift`
- `DivineLink/Services/SubscriptionService.swift`
- `DivineLink/Services/DeviceManager.swift`
- `DivineLink/Features/Auth/AuthViews.swift`
- `Distribution/supabase-schema.sql`
- `Distribution/supabase-functions/stripe-webhook/index.ts`
- `Distribution/PHASE2_SETUP.md`

**Setup Required** (User Actions):
- [ ] Run database schema in Supabase SQL Editor
- [ ] Configure Email OTP in Supabase Auth settings

---

### 🔲 Phase 3: Stripe Integration (PENDING)

**Goal**: Accept payments and update subscription status

| Task | Status | Notes |
|------|--------|-------|
| Create Stripe Payment Link | 🔲 Pending | In Stripe Dashboard |
| Update checkout URL in app | 🔲 Pending | `SubscriptionService.swift` |
| Deploy webhook to Supabase | 🔲 Pending | `supabase functions deploy` |
| Configure webhook in Stripe | 🔲 Pending | Add endpoint URL |
| Set webhook secret | 🔲 Pending | `supabase secrets set` |
| Test payment flow | 🔲 Pending | Use test card |
| Go live | 🔲 Pending | Switch to live keys |

---

### 🔲 Phase 4: Landing Page Polish (PENDING)

**Goal**: Professional landing page with legal pages

| Task | Status | Notes |
|------|--------|-------|
| Terms of Service page | 🔲 Pending | `/terms.html` |
| Privacy Policy page | 🔲 Pending | `/privacy.html` |
| Success page (post-checkout) | 🔲 Pending | `/success.html` |
| Cancel page | 🔲 Pending | `/cancel.html` |
| Improved styling | 🔲 Pending | Better CSS |
| Screenshots/demo | 🔲 Pending | App images |

---

### 🔲 Phase 5: Custom Domain (OPTIONAL)

**Goal**: Use custom subdomain

| Task | Status | Notes |
|------|--------|-------|
| Add CNAME in Duda/DNS | 🔲 Pending | `divinelink.orekunmedia.com` |
| Configure in Netlify | 🔲 Pending | Custom domain settings |
| Update URLs in app | 🔲 Pending | Feed URL, checkout URL |

---

## GitHub Repositories

| Repository | Purpose | Visibility | Status |
|------------|---------|------------|--------|
| Divine Link (main) | App source code | **Private** ✅ | Active |
| divine-link-site | Netlify landing page | **Private** ✅ | Linked to Netlify |

**Note**: Both repos can remain private. Netlify connects via OAuth and doesn't require public access.

**⚠️ CRITICAL:** See [Repository Structure Guide](docs/REPOSITORY_STRUCTURE.md) for which files go to which repository. Always verify before pushing!

---

## Configuration Summary

### Supabase
```
Project URL: https://qzjhjgkvvcamcqpdrgkf.supabase.co
Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Stripe
```
Product ID: prod_TtV8U5mVO1cecV
Price ID: price_1Svi8dDyhT7xGc8kvz7qIrk6
Price: £9.97/month
```

### Sparkle
```
Feed URL: https://divinelink.netlify.app/appcast.xml
Public Key: fbg4DwpGznsP6/scSfKu1hbfIlW0/LgnSRS+fi/4Ciw=
```

---

## Next Steps (Priority Order)

1. **Run database schema** in Supabase (5 min)
2. **Test login flow** in app (5 min)
3. **Create Stripe Payment Link** (10 min)
4. **Deploy webhook** to Supabase (15 min)
5. **Test end-to-end payment** (10 min)
6. **Create first signed release** for Sparkle (20 min)

---

## File Structure

```
Divine Link/
├── DivineLink/                      # Xcode project
│   ├── App/
│   │   ├── DivineLinkApp.swift      # App entry point
│   │   ├── MainView.swift           # Main UI
│   │   ├── SettingsView.swift       # Settings tabs
│   │   └── SparkleUpdater.swift     # Update controller
│   ├── Services/
│   │   ├── SupabaseConfig.swift     # Backend config
│   │   ├── AuthService.swift        # Login/logout
│   │   ├── SubscriptionService.swift # Premium status
│   │   └── DeviceManager.swift      # Device tracking
│   ├── Features/
│   │   ├── Auth/
│   │   │   └── AuthViews.swift      # Login UI
│   │   └── Ads/
│   │       ├── AdManager.swift      # Ad/subscription logic
│   │       └── AdViews.swift        # Ad UI components
│   └── Info.plist                   # Sparkle config
├── Distribution/
│   ├── README.md                    # Distribution overview
│   ├── SPARKLE_SETUP.md             # Phase 1 guide
│   ├── PHASE2_SETUP.md              # Phase 2 guide
│   ├── supabase-schema.sql          # Database tables
│   ├── netlify-site/                # Landing page
│   │   ├── index.html
│   │   ├── appcast.xml
│   │   └── netlify.toml
│   └── supabase-functions/
│       └── stripe-webhook/
│           └── index.ts             # Payment webhook
├── CHANGELOG.md                     # Version history
├── PROJECT_STATUS.md                # This file
└── README.md                        # Project readme
```

---

## Questions & Decisions

| Question | Decision |
|----------|----------|
| App Store vs Direct? | Direct first, App Store later |
| Authentication method? | Email OTP (Supabase built-in) |
| Payment gateway? | Stripe |
| Device limit? | 2 devices per account |
| Offline grace period? | 7 days |
| Auto-update frequency? | Every 24 hours |
| Landing page hosting? | Netlify (free tier) |
| Can repos be private? | ✅ Yes, both can be private |
