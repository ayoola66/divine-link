// Supabase Edge Function: Stripe Webhook Handler
// Deploy with: supabase functions deploy stripe-webhook --no-verify-jwt
//
// Set secrets:
// supabase secrets set STRIPE_SECRET_KEY=sk_live_xxx
// supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_xxx

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@13.10.0";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";
const resendApiKey = Deno.env.get("RESEND_API_KEY") ?? "";
const transactionalFromEmail =
  Deno.env.get("TRANSACTIONAL_FROM_EMAIL") ?? "hello@divinelinkapp.com";
const transactionalReplyTo =
  Deno.env.get("TRANSACTIONAL_REPLY_TO") ?? "do-not-reply@divinelinkapp.com";
const appDownloadUrl =
  Deno.env.get("APP_DOWNLOAD_URL") ??
  "https://divinelink.netlify.app/releases/DivineLink-latest.zip";
const websiteUrl =
  Deno.env.get("WEBSITE_URL") ?? "https://divinelink.netlify.app";

serve(async (req: Request) => {
  const signature = req.headers.get("stripe-signature");

  if (!signature) {
    return new Response("No signature", { status: 400 });
  }

  try {
    const body = await req.text();
    const event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      webhookSecret,
    );

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    console.log(`Processing event: ${event.type}`);

    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        await handleCheckoutComplete(supabase, session);
        break;
      }

      case "customer.subscription.created":
      case "customer.subscription.updated": {
        const subscription = event.data.object as Stripe.Subscription;
        await handleSubscriptionUpdate(supabase, subscription);
        break;
      }

      case "customer.subscription.deleted": {
        const subscription = event.data.object as Stripe.Subscription;
        await handleSubscriptionCancelled(supabase, subscription);
        break;
      }

      case "invoice.payment_succeeded": {
        const invoice = event.data.object as Stripe.Invoice;
        await handlePaymentSucceeded(supabase, invoice);
        break;
      }

      case "invoice.payment_failed": {
        const invoice = event.data.object as Stripe.Invoice;
        await handlePaymentFailed(supabase, invoice);
        break;
      }

      default:
        console.log(`Unhandled event type: ${event.type}`);
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    console.error("Webhook error:", err);
    return new Response(`Webhook Error: ${err.message}`, { status: 400 });
  }
});

// Handle successful checkout
async function handleCheckoutComplete(
  supabase: any,
  session: Stripe.Checkout.Session,
) {
  const customerEmail =
    session.customer_email || session.customer_details?.email;
  const customerId = session.customer as string;
  const subscriptionId = session.subscription as string;

  if (!customerEmail) {
    console.error("No customer email in session");
    return;
  }

  console.log(`Checkout complete for: ${customerEmail}`);

  // Find user by email
  const { data: users, error: userError } = await supabase
    .from("profiles")
    .select("id")
    .eq("email", customerEmail)
    .limit(1);

  if (userError || !users?.length) {
    console.error("User not found:", customerEmail);
    return;
  }

  const userId = users[0].id;

  // Get subscription details from Stripe
  const subscription = await stripe.subscriptions.retrieve(subscriptionId);

  // Update subscription in database
  const { error: updateError } = await supabase
    .from("subscriptions")
    .update({
      status: "premium",
      stripe_customer_id: customerId,
      stripe_subscription_id: subscriptionId,
      current_period_start: new Date(
        subscription.current_period_start * 1000,
      ).toISOString(),
      current_period_end: new Date(
        subscription.current_period_end * 1000,
      ).toISOString(),
      cancel_at_period_end: subscription.cancel_at_period_end,
    })
    .eq("user_id", userId);

  if (updateError) {
    console.error("Failed to update subscription:", updateError);
  } else {
    console.log(`✅ Subscription activated for user: ${userId}`);
    await sendWelcomeEmail(customerEmail);
  }
}

// Handle subscription updates
async function handleSubscriptionUpdate(
  supabase: any,
  subscription: Stripe.Subscription,
) {
  const customerId = subscription.customer as string;

  // Find user by Stripe customer ID
  const { data: subs, error: subError } = await supabase
    .from("subscriptions")
    .select("user_id")
    .eq("stripe_customer_id", customerId)
    .limit(1);

  if (subError || !subs?.length) {
    console.log("Subscription not found for customer:", customerId);
    return;
  }

  const status = mapStripeStatus(subscription.status);

  const { error: updateError } = await supabase
    .from("subscriptions")
    .update({
      status,
      current_period_start: new Date(
        subscription.current_period_start * 1000,
      ).toISOString(),
      current_period_end: new Date(
        subscription.current_period_end * 1000,
      ).toISOString(),
      cancel_at_period_end: subscription.cancel_at_period_end,
    })
    .eq("stripe_customer_id", customerId);

  if (updateError) {
    console.error("Failed to update subscription:", updateError);
  } else {
    console.log(`✅ Subscription updated: ${status}`);
  }
}

// Handle subscription cancellation
async function handleSubscriptionCancelled(
  supabase: any,
  subscription: Stripe.Subscription,
) {
  const customerId = subscription.customer as string;

  const { error } = await supabase
    .from("subscriptions")
    .update({
      status: "cancelled",
      cancel_at_period_end: true,
    })
    .eq("stripe_customer_id", customerId);

  if (error) {
    console.error("Failed to cancel subscription:", error);
  } else {
    console.log(`✅ Subscription cancelled for customer: ${customerId}`);
  }
}

// Handle successful payment
async function handlePaymentSucceeded(supabase: any, invoice: Stripe.Invoice) {
  const customerId = invoice.customer as string;

  // Ensure subscription is active after payment
  const { error } = await supabase
    .from("subscriptions")
    .update({
      status: "premium",
    })
    .eq("stripe_customer_id", customerId);

  if (!error) {
    console.log(`✅ Payment succeeded for customer: ${customerId}`);
  }
}

// Handle failed payment
async function handlePaymentFailed(supabase: any, invoice: Stripe.Invoice) {
  const customerId = invoice.customer as string;

  // Mark subscription as past due
  const { error } = await supabase
    .from("subscriptions")
    .update({
      status: "expired",
    })
    .eq("stripe_customer_id", customerId);

  if (!error) {
    console.log(`⚠️ Payment failed for customer: ${customerId}`);
  }
}

// Map Stripe subscription status to our status
function mapStripeStatus(stripeStatus: Stripe.Subscription.Status): string {
  switch (stripeStatus) {
    case "active":
      return "premium";
    case "trialing":
      return "trial";
    case "past_due":
    case "unpaid":
      return "expired";
    case "canceled":
      return "cancelled";
    default:
      return "free";
  }
}

async function sendWelcomeEmail(customerEmail: string): Promise<void> {
  if (!resendApiKey) {
    console.warn(
      "RESEND_API_KEY not configured; skipping branded welcome email",
    );
    return;
  }

  const startAppUrl = `${websiteUrl}/success.html`;
  const subject = "Welcome to Divine Link Premium";
  const html = `
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #1f2937;">
      <h2 style="margin-bottom: 12px;">Payment confirmed — your Divine Link subscription is active</h2>
      <p style="margin: 0 0 12px;">Thank you for subscribing to Divine Link.</p>
      <h3 style="margin: 24px 0 8px;">What to do next</h3>
      <ol style="margin: 0 0 16px 20px; padding: 0;">
        <li>Open Divine Link on your Mac.</li>
        <li>Sign in with this email address.</li>
        <li>Go to Settings → Account to confirm your subscription.</li>
      </ol>
      <p style="margin: 0 0 16px;">
        Need the latest installer? <a href="${appDownloadUrl}">Download Divine Link</a>.
      </p>
      <p style="margin: 0 0 12px; font-size: 13px; color: #6b7280;">
        You will also receive a Stripe receipt for this payment.
      </p>
      <p style="margin: 0; font-size: 12px; color: #6b7280;">
        This mailbox is not monitored. Please do not reply to this message.
      </p>
      <p style="margin: 16px 0 0;">
        <a href="${startAppUrl}" style="color: #2563eb;">View post-payment setup page</a>
      </p>
    </div>
  `;

  const text = [
    "Payment confirmed - your Divine Link subscription is active.",
    "",
    "What to do next:",
    "1) Open Divine Link on your Mac.",
    "2) Sign in with this email address.",
    "3) Go to Settings -> Account to confirm your subscription.",
    "",
    `Download latest build: ${appDownloadUrl}`,
    `Post-payment setup page: ${startAppUrl}`,
    "",
    "You will also receive a Stripe receipt for this payment.",
    "This mailbox is not monitored. Please do not reply to this message.",
  ].join("\n");

  try {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: `Divine Link <${transactionalFromEmail}>`,
        to: [customerEmail],
        reply_to: transactionalReplyTo,
        subject,
        html,
        text,
      }),
    });

    if (!response.ok) {
      const details = await response.text();
      console.error("Failed to send branded welcome email:", details);
      return;
    }

    console.log(`✅ Branded welcome email sent to ${customerEmail}`);
  } catch (error) {
    console.error("Error sending branded welcome email:", error);
  }
}
