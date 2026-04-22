# Phase 2: Supabase Backend Setup Guide

This guide explains how to set up the Supabase backend for Divine Link authentication and subscriptions.

## Step 1: Run Database Schema

1. Go to: https://supabase.com/dashboard/project/qzjhjgkvvcamcqpdrgkf/sql

2. Create a new query

3. Copy and paste the entire contents of `supabase-schema.sql`

4. Click **Run**

5. You should see "Success. No rows returned" - this means tables were created

## Step 2: Enable Email OTP Authentication

1. Go to: https://supabase.com/dashboard/project/qzjhjgkvvcamcqpdrgkf/auth/providers

2. Under **Email**, ensure it's enabled

3. Click on **Email** to expand settings

4. Enable **"Confirm email"** = OFF (we use OTP, not confirmation links)

5. Under **Email Templates** → **Magic Link**, customise the template:
   - Subject: `Your Divine Link verification code`
   - Body: Include `{{ .Token }}` which is the 6-digit code

6. Save changes

## Step 3: Configure SMTP (Optional but Recommended)

By default, Supabase uses their built-in email. For production, set up custom SMTP:

1. Go to: https://supabase.com/dashboard/project/qzjhjgkvvcamcqpdrgkf/settings/auth

2. Scroll to **SMTP Settings**

3. Enter your SMTP details (e.g., SendGrid, Mailgun, Postmark)

## Step 4: Deploy Stripe Webhook Function

### 4.1 Install Supabase CLI

```bash
brew install supabase/tap/supabase
```

### 4.2 Login to Supabase

```bash
supabase login
```

### 4.3 Link to Project

```bash
cd "/Users/ayoogunrekun/Projects/Divine Link/Distribution/supabase-functions"
supabase link --project-ref qzjhjgkvvcamcqpdrgkf
```

### 4.4 Set Secrets

Get your Stripe keys from: https://dashboard.stripe.com/apikeys

```bash
# Set Stripe secret key
supabase secrets set STRIPE_SECRET_KEY=sk_live_xxxx

# Set webhook secret (get this after creating webhook in Stripe)
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_xxxx

# Branded post-payment email (Resend)
supabase secrets set RESEND_API_KEY=re_xxxx
supabase secrets set TRANSACTIONAL_FROM_EMAIL=hello@divinelinkapp.com
supabase secrets set TRANSACTIONAL_REPLY_TO=do-not-reply@divinelinkapp.com

# Optional URL overrides
# Download page for ZIP installer
supabase secrets set APP_DOWNLOAD_URL=https://divinelink.netlify.app/download
supabase secrets set WEBSITE_URL=https://divinelink.netlify.app
```

### 4.5 Deploy Function

```bash
supabase functions deploy stripe-webhook --no-verify-jwt
```

### 4.6 Get Function URL

After deployment, your webhook URL will be:

```
https://qzjhjgkvvcamcqpdrgkf.supabase.co/functions/v1/stripe-webhook
```

## Step 5: Configure Stripe Webhook

1. Go to: https://dashboard.stripe.com/webhooks

2. Click **Add endpoint**

3. Enter your Supabase function URL:

   ```
   https://qzjhjgkvvcamcqpdrgkf.supabase.co/functions/v1/stripe-webhook
   ```

4. Select events to listen for:
   - `checkout.session.completed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`

5. Click **Add endpoint**

6. Copy the **Signing secret** (starts with `whsec_`)

7. Set it in Supabase:
   ```bash
   supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_xxxx
   ```

## Step 6: Create Stripe Checkout Link

### Option A: Payment Link (Simplest)

1. Go to: https://dashboard.stripe.com/payment-links

2. Click **Create payment link**

3. Select your Divine Link Premium product

4. Under **After payment** → **Redirect customers**:
   - URL: `https://divinelink.netlify.app/success.html`

5. Copy the payment link URL

6. Update `SubscriptionService.swift`:
   ```swift
   func getCheckoutURL() -> URL? {
       return URL(string: "https://buy.stripe.com/your-link?prefilled_email=\(email)")
   }
   ```

### Option B: Stripe Checkout (More Control)

For custom checkout, you'd create a Supabase Edge Function that creates a Stripe Checkout Session. This gives more control over the flow.

## Step 7: Enable both payment emails

To ensure users get both expected emails:

1. In Stripe Dashboard, enable customer receipt/invoice emails for paid charges.
2. Keep webhook events enabled so Supabase can send the Divine Link branded setup email.
3. Confirm your DNS includes the required sender records for your email provider (SPF/DKIM) for `divinelinkapp.com`.

### Email Behaviour

- Stripe usually sends a receipt for paid charges. For 100% discounted checkouts,
  Stripe may generate a £0.00 invoice and may skip the receipt email.
- Divine Link sends a branded onboarding email from `hello@divinelinkapp.com`.
- Replies are intentionally disabled (`TRANSACTIONAL_REPLY_TO=do-not-reply@divinelinkapp.com`).
- App download links in transactional emails should target `/download` (ZIP download page).

## Step 8: Test the Flow

1. **Build and run** the app in Xcode

2. Click **Sign In** in the app

3. Enter your email, receive OTP code

4. Verify code - you're now logged in!

5. Click **Go Premium** - opens Stripe checkout

6. Complete payment (use test card: `4242 4242 4242 4242`)

7. Webhook fires → Supabase updated → App shows Premium

## Step 9: Run automated billing health check

From project root, run:

```bash
bash "scripts/check-billing-health.sh"
```

This verifies:
- webhook endpoint status + event subscriptions
- all live payment link redirects point to `success.html`
- latest checkout/invoice events have healthy webhook delivery state

## Verification Checklist

- [ ] Database tables created (profiles, subscriptions, devices)
- [ ] Email OTP working (receive codes)
- [ ] User can sign in and out
- [ ] Devices are registered (check devices table)
- [ ] Stripe webhook deployed and receiving events
- [ ] Payment updates subscription status and tier (`premium` + `grace/love`)
- [ ] Divine Link branded setup email is delivered
- [ ] Stripe receipt or £0.00 invoice behaviour matches charged amount
- [ ] App shows no ads for premium users

## Troubleshooting

### OTP Email Not Arriving

1. Check Supabase logs: Auth → Logs
2. Check spam folder
3. Verify SMTP settings if using custom

### Webhook Not Firing

1. Check Stripe webhook logs: Developers → Webhooks → Select endpoint → Logs
2. Verify function is deployed: `supabase functions list`
3. Check Edge Function logs in Supabase Dashboard:
   `Project → Edge Functions → stripe-webhook → Invocations/Logs`

### Webhook Delivery 4xx Mismatches

If Stripe shows delivery failures, use these exact fixes:

- `401` with `Missing authorization header`
  - Cause: JWT verification is still enabled for Stripe webhook calls.
  - Fix: redeploy with JWT verification disabled:
    ```bash
    supabase functions deploy stripe-webhook --no-verify-jwt
    ```

- `400` with `SubtleCryptoProvider cannot be used in a synchronous context`
  - Cause: signature verification used synchronous construction.
  - Fix: use `await stripe.webhooks.constructEventAsync(...)` in the webhook code, then redeploy.

After either fix, go to Stripe event details and click **Resend** for:
- `checkout.session.completed`
- `invoice.payment_succeeded`

### Subscription Not Updating

1. Verify webhook signature secret is correct
2. Check Supabase database for the user's subscription record
3. Ensure email matches between Stripe and Supabase auth

## Database Tables Reference

### profiles

- `id` (UUID) - Links to auth.users
- `email` (TEXT)
- `display_name` (TEXT)

### subscriptions

- `id` (UUID)
- `user_id` (UUID) - Links to profiles
- `status` (TEXT) - lifecycle: free/trial/premium/cancelled/expired
- `tier` (TEXT) - entitlement: mercy/grace/love
- `stripe_customer_id` (TEXT)
- `stripe_subscription_id` (TEXT)
- `current_period_end` (TIMESTAMPTZ)

### Existing Deployments

If your Supabase project was created before tier differentiation, run:

- `Distribution/supabase-tier-migration.sql`

This migration backfills `tier` values and updates status constraints safely.

### devices

- `id` (UUID)
- `user_id` (UUID)
- `device_id` (TEXT) - Hardware UUID
- `device_name` (TEXT)
- `is_active` (BOOLEAN)
