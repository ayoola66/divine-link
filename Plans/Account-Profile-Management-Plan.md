# Divine Link — Account / Profile Management (scoped, pre-build)

> Captured 2026-07-26. Feasibility + plan for letting logged-in users edit their details.
> Owner asked to "look into it; if complicated, roadmap it." Nothing built yet.

## Current state (verified in code)
- Auth = Supabase email OTP. `AuthUser` has only `id` + `email` (no name). Names would live in
  Supabase **`user_metadata`** (no DB schema change needed).
- `AuthSession` (contains `AuthUser`) is **JSON-encoded into the keychain** (`saveSession`) — so
  adding name fields to `AuthUser` needs BOTH `init(from:)` AND `encode(to:)` to round-trip cleanly,
  or login persistence breaks. (This is why name-editing is "small" but not "trivial".)
- Subscription data already includes **`stripe_customer_id`** — the key needed for Stripe's billing
  portal (we don't have to look it up).
- Billing today = Stripe **Checkout payment links** (`buy.stripe.com/...`) opened via NSWorkspace.
  There is **no** Customer Portal integration yet.

## Feature 1 — First / last name editing  🟢 SMALL (no owner action)
- **AuthService**: add `updateProfile(firstName:lastName:)` → PATCH `/auth/v1/user` with
  `{ "data": { "first_name": ..., "last_name": ... } }` (writes user_metadata).
- **AuthUser**: decode `user_metadata.first_name/last_name` (custom Codable init + encode, since it's
  keychain-persisted). Refresh currentUser after update.
- **AccountView**: an "Edit Profile" section — two TextFields (first/last) + Save, shows current values.
- Risk: low, but touches the keychain-persisted model — test login persists after the change.
- **Ready to build on the owner's word.**

## Feature 2 — Manage billing (address, card, invoices, cancel)  🟡 MODERATE (needs owner Stripe key)
- The correct, PCI-safe way is **Stripe Customer Portal** (Stripe-hosted). We already have the
  customer id, so:
  - **New Netlify function** `stripe-portal.mjs`: `POST { customerId }` → verify the caller (reuse the
    admin-style token or the user's Supabase JWT), then
    `stripe.billingPortal.sessions.create({ customer, return_url })` → return the URL.
  - **App**: premium users get a "Manage Billing" button (in Account settings) that calls the function
    with `subscription.stripeCustomerId` and opens the returned URL.
  - Solves billing ADDRESS + payment method + invoices + cancel/renew, all in one.
- **Owner actions:** add `STRIPE_SECRET_KEY` as a Netlify env var; enable + configure the Customer
  Portal in the Stripe dashboard (what customers may edit).
- Risk: low-moderate; standard Stripe pattern. Recommend doing this if self-service billing is wanted —
  it's more valuable than just an address field.

## Feature 3 — Change account email in-app  🟠 FIDDLIEST (lower value)
- PATCH `/auth/v1/user` with `{ "email": newEmail }` → Supabase sends a confirmation (dual-email) →
  user enters a code to confirm. Depends on the **"Change Email"** template being code-based
  (`{{ .Token }}`) — same class of Supabase-template dependency that already bit us twice.
- Owner said email change "matters less". **Recommend: roadmap / defer.**

## Recommendation
- **Build now:** Feature 1 (names) — clean, self-contained, no dependencies.
- **Build if wanted:** Feature 2 (Stripe portal) — I write function + button; owner adds Stripe key +
  enables the portal. Proper way to solve the billing-address ask.
- **Defer:** Feature 3 (email change).
- All of this is INDEPENDENT of shipping 1.6.0 — can come before or after.
