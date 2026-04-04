# Divine Link - Distribution & Deployment

This folder contains everything needed to distribute Divine Link outside the Mac App Store.

## Overview

Divine Link uses a **direct sales model** with:
- **Sparkle** for auto-updates
- **Supabase** for authentication & subscription management
- **Stripe** for payments
- **Netlify** for hosting (landing page + update feed)

## Folder Structure

```
Distribution/
├── README.md                    # This file
├── SPARKLE_SETUP.md             # Phase 1: Sparkle auto-update setup
├── PHASE2_SETUP.md              # Phase 2: Supabase backend setup
├── AD_SYSTEM.md                 # Dynamic ad system documentation
├── DIRECT_DISTRIBUTION_TRUST.md # Website install trust & privacy checklist
├── supabase-schema.sql          # Database schema for Supabase
├── supabase-tier-migration.sql  # Migration for tier differentiation
├── netlify-site/                # Landing page files
│   ├── index.html               # Landing page
│   ├── admin.html               # Ad management dashboard
│   ├── appcast.xml              # Sparkle update feed
│   ├── netlify.toml             # Netlify configuration
│   └── releases/                # App release ZIPs
└── supabase-functions/          # Supabase Edge Functions
    └── stripe-webhook/          # Stripe payment webhook
        └── index.ts
```

## Implementation Phases

### ✅ Phase 1: Sparkle Auto-Updates (COMPLETE)
- Sparkle framework integrated into app
- EdDSA signing keys generated
- Update checking from menu and Settings
- Appcast.xml hosted on Netlify
- See: [SPARKLE_SETUP.md](./SPARKLE_SETUP.md)

### ✅ Phase 2: Supabase Backend (CODE COMPLETE)
- Email OTP authentication
- Subscription status tracking
- Device management (2-device limit)
- Login/Account UI in app
- Database schema ready
- Stripe webhook function ready
- See: [PHASE2_SETUP.md](./PHASE2_SETUP.md)

### ✅ Dynamic Ad System (COMPLETE)
- Backend-served advertisements from Supabase
- Admin dashboard for ad management (`/admin.html`)
- Support for Square, Portrait, and Banner ad formats
- Automatic ad rotation and real-time updates
- Click and impression tracking
- Ad enforcement system
- See: [AD_SYSTEM.md](./AD_SYSTEM.md)

### 🔲 Phase 3: Stripe Integration (PENDING)
- Create Stripe Payment Link
- Deploy webhook to Supabase
- Test payment flow end-to-end

### 🔲 Phase 4: Landing Page Polish (PENDING)
- Add Terms of Service page
- Add Privacy Policy page
- Add success/cancel pages for checkout
- Style improvements

### 🔲 Phase 5: DNS Setup (OPTIONAL)
- Custom domain (e.g., divinelink.orekunmedia.com)
- SSL certificate (automatic via Netlify)

## Quick Links

| Resource | URL |
|----------|-----|
| Landing Page | https://divinelink.netlify.app |
| Admin Dashboard | https://divinelink.netlify.app/admin.html |
| Appcast Feed | https://divinelink.netlify.app/appcast.xml |
| Supabase Dashboard | https://supabase.com/dashboard/project/qzjhjgkvvcamcqpdrgkf |
| Stripe Dashboard | https://dashboard.stripe.com |
| Netlify Dashboard | https://app.netlify.com |

## Key Configuration

### Supabase
- Project URL: `https://qzjhjgkvvcamcqpdrgkf.supabase.co`
- Anon Key: (in `SupabaseConfig.swift`)
- Existing deployments should run `Distribution/supabase-tier-migration.sql`
  to enable explicit tier differentiation (Mercy/Grace/Love).

### Stripe
- Product ID: `prod_TtV8U5mVO1cecV`
- Price ID: `price_1Svi8dDyhT7xGc8kvz7qIrk6`
- Price: £9.97/month

### Sparkle
- Feed URL: `https://divinelink.netlify.app/appcast.xml`
- Public Key: `fbg4DwpGznsP6/scSfKu1hbfIlW0/LgnSRS+fi/4Ciw=`

## Release Workflow

1. **Archive** app in Xcode (Product → Archive)
2. **Export** as "Developer ID" signed app
3. **Notarise** release with Apple and staple ticket
4. **Verify** signature + Gatekeeper + stapled ticket
5. **Zip** the .app bundle
6. **Sign** with Sparkle: `./sign_update DivineLink-X.X.X.zip`
7. **Update** appcast.xml with signature and length
8. **Upload** ZIP to `netlify-site/releases/`
9. **Push** to GitHub → Netlify auto-deploys
10. **Users** receive update notification!

For the full trust/privacy release gate, see:
- [Direct Distribution Trust & Privacy Checklist](./DIRECT_DISTRIBUTION_TRUST.md)

## GitHub Repositories

| Repo | Purpose | Visibility |
|------|---------|------------|
| Divine Link (main) | App source code | Private ✅ |
| divine-link-site | Netlify landing page | Private ✅ |

Both can be private - Netlify connects via OAuth and doesn't require public access.

**⚠️ IMPORTANT:** See [Repository Structure Guide](../../docs/REPOSITORY_STRUCTURE.md) for details on which files go to which repository.
