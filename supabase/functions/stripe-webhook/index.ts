// Supabase Edge Function: Stripe Webhook Handler
// Deploy with: supabase functions deploy stripe-webhook --no-verify-jwt
//
// Set secrets:
// supabase secrets set STRIPE_SECRET_KEY=sk_live_xxx
// supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_xxx

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@13.10.0";
import {
  determineTierFromProductId,
  mapStripeStatus as mapStripeSubscriptionStatus,
  type SubscriptionTier,
} from "./subscription-mapping.ts";

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
    const message = err instanceof Error ? err.message : String(err);
    console.error("Webhook error:", err);
    return new Response(`Webhook Error: ${message}`, { status: 400 });
  }
});

// Handle successful checkout
async function handleCheckoutComplete(
  supabase: any,
  session: Stripe.Checkout.Session,
) {
  const customerId = session.customer as string;
  const fallbackEmail = customerId ? await getCustomerEmail(customerId) : null;
  const customerEmail =
    session.customer_email || session.customer_details?.email || fallbackEmail;
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

  // Get subscription details from Stripe
  const subscription = await stripe.subscriptions.retrieve(subscriptionId, {
    expand: ["items.data.price.product"],
  });
  const tier = determineTier(subscription);
  const status = mapStripeSubscriptionStatus(subscription.status as any);
  const periodEndISO = new Date(subscription.current_period_end * 1000)
    .toISOString();
  const amountPaidCents = session.amount_total ?? null;
  const stripeReceiptExpected = (amountPaidCents ?? 1) > 0;
  const currencyCode = session.currency ?? "gbp";
  const discountApplied = Boolean(
    (session.total_details?.amount_discount ?? 0) > 0,
  );
  let invoiceHostedUrl: string | null = null;
  let invoicePdfUrl: string | null = null;
  const checkoutInvoiceId = typeof session.invoice === "string"
    ? session.invoice
    : null;
  if (checkoutInvoiceId) {
    try {
      const invoice = await stripe.invoices.retrieve(checkoutInvoiceId);
      invoiceHostedUrl = invoice.hosted_invoice_url;
      invoicePdfUrl = invoice.invoice_pdf;
    } catch (error) {
      console.error("Failed to fetch checkout invoice details:", error);
    }
  }

  // Send branded confirmation from confirmed checkout event even if profile lookup fails.
  await sendWelcomeEmail({
    customerEmail,
    tier,
    periodEndISO,
    stripeReceiptExpected,
    amountPaidCents,
    currencyCode,
    discountApplied,
    invoiceHostedUrl,
    invoicePdfUrl,
  });

  if (userError || !users?.length) {
    console.error(
      "User profile not found for checkout email; skipped subscription DB update:",
      customerEmail,
    );
    return;
  }

  const userId = users[0].id;

  // Update subscription in database
  const { error: updateError } = await supabase
    .from("subscriptions")
    .update({
      status,
      tier,
      stripe_customer_id: customerId,
      stripe_subscription_id: subscriptionId,
      current_period_start: new Date(
        subscription.current_period_start * 1000,
      ).toISOString(),
      current_period_end: periodEndISO,
      cancel_at_period_end: subscription.cancel_at_period_end,
    })
    .eq("user_id", userId);

  if (updateError) {
    console.error("Failed to update subscription:", updateError);
  } else {
    console.log(`✅ Subscription activated for user: ${userId}`);
  }
}

// Resolve a subscriptions row for a Stripe customer, falling back to an
// email match when the customer was never linked via checkout.session.completed
// (e.g. a subscription created directly in Stripe — comped/test accounts).
// Never overwrites an existing link to a DIFFERENT customer, and aborts on an
// ambiguous email match rather than guessing which account to grant.
// Escape Postgres LIKE/ILIKE wildcards (% _ \) so a raw email is matched
// literally — an unescaped "_" (a legal, common email character) would
// otherwise match any single character and cause false ambiguous-match
// aborts or, worse, a wrong-account link.
function escapeLikePattern(value: string): string {
  return value.replace(/[\\%_]/g, (char) => `\\${char}`);
}

async function resolveSubscriptionRow(
  supabase: any,
  customerId: string,
): Promise<{ userId: string; alreadyLinked: boolean } | null> {
  const { data: byCustomer, error: byCustomerError } = await supabase
    .from("subscriptions")
    .select("user_id")
    .eq("stripe_customer_id", customerId)
    .limit(1);

  if (byCustomerError) {
    throw new Error(
      `Failed to look up subscription by stripe_customer_id ${customerId}: ${byCustomerError.message}`,
    );
  }
  if (byCustomer?.length) {
    return { userId: byCustomer[0].user_id, alreadyLinked: true };
  }

  const email = await getCustomerEmail(customerId);
  if (!email) return null;
  const normalizedEmail = email.trim().toLowerCase();

  const { data: profiles, error: profilesError } = await supabase
    .from("profiles")
    .select("id")
    .ilike("email", escapeLikePattern(normalizedEmail));

  if (profilesError) {
    throw new Error(
      `Failed to look up profile by email for customer ${customerId}: ${profilesError.message}`,
    );
  }
  if (!profiles?.length) return null;
  if (profiles.length > 1) {
    console.error(
      `Ambiguous email match for "${normalizedEmail}" (${profiles.length} profiles); refusing to link customer ${customerId} to avoid granting the wrong account.`,
    );
    return null;
  }

  const userId = profiles[0].id;

  const { data: subRow, error: subRowError } = await supabase
    .from("subscriptions")
    .select("stripe_customer_id")
    .eq("user_id", userId)
    .limit(1);

  if (subRowError) {
    throw new Error(
      `Failed to look up subscriptions row for user ${userId}: ${subRowError.message}`,
    );
  }
  if (!subRow?.length) return null;

  const existingCustomerId = subRow[0].stripe_customer_id;
  if (existingCustomerId && existingCustomerId !== customerId) {
    console.error(
      `User ${userId} already linked to a different Stripe customer (${existingCustomerId}); refusing to overwrite with ${customerId}.`,
    );
    return null;
  }

  console.log(
    `Linked Stripe customer ${customerId} to user ${userId} via email fallback (no prior checkout.session.completed for this customer).`,
  );
  return { userId, alreadyLinked: false };
}

// Handle subscription updates
async function handleSubscriptionUpdate(
  supabase: any,
  subscription: Stripe.Subscription,
) {
  const customerId = subscription.customer as string;

  const resolved = await resolveSubscriptionRow(supabase, customerId);
  if (!resolved) {
    console.log(
      "Subscription not found for customer (direct link or email fallback):",
      customerId,
    );
    return;
  }

  const status = mapStripeSubscriptionStatus(subscription.status as any);
  let tier: SubscriptionTier | undefined;
  if (subscription.status === "active" || subscription.status === "trialing") {
    // Expanded fetch is needed to access product mapping for tier differentiation.
    const fullSubscription = await stripe.subscriptions.retrieve(
      subscription.id,
      {
        expand: ["items.data.price.product"],
      },
    );
    tier = determineTier(fullSubscription);
  }

  const updatePayload: Record<string, unknown> = {
    status,
    current_period_start: new Date(
      subscription.current_period_start * 1000,
    ).toISOString(),
    current_period_end: new Date(
      subscription.current_period_end * 1000,
    ).toISOString(),
    cancel_at_period_end: subscription.cancel_at_period_end,
  };
  if (tier) updatePayload.tier = tier;
  if (!resolved.alreadyLinked) updatePayload.stripe_customer_id = customerId;

  const { error: updateError } = await supabase
    .from("subscriptions")
    .update(updatePayload)
    .eq("user_id", resolved.userId);

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
  const subscriptionId = invoice.subscription as string | null;
  const billingReason = (invoice as any).billing_reason as string | undefined;
  const invoiceCustomerEmail = (invoice as any).customer_email as string | null;
  let tier: SubscriptionTier | undefined;
  if (subscriptionId) {
    try {
      const subscription = await stripe.subscriptions.retrieve(subscriptionId, {
        expand: ["items.data.price.product"],
      });
      tier = determineTier(subscription);
    } catch (err) {
      console.error("Failed to resolve subscription tier from invoice:", err);
    }
  }

  const resolved = await resolveSubscriptionRow(supabase, customerId);

  if (!resolved) {
    console.log(
      "Subscription not found for customer on payment_succeeded (direct link or email fallback):",
      customerId,
    );
  } else {
    // Ensure subscription is active after payment
    const updatePayload: Record<string, unknown> = {
      status: "premium",
    };
    if (tier) updatePayload.tier = tier;
    if (!resolved.alreadyLinked) updatePayload.stripe_customer_id = customerId;

    const { error } = await supabase
      .from("subscriptions")
      .update(updatePayload)
      .eq("user_id", resolved.userId);

    if (!error) {
      console.log(`✅ Payment succeeded for customer: ${customerId}`);
    } else {
      console.error("Failed to update subscription on payment_succeeded:", error);
    }
  }

  // Fallback: checkout.session.completed can arrive without customer_email.
  // For initial invoices only, use invoice email when Stripe customer has no saved email.
  const shouldAttemptFallbackEmail = Boolean(
    invoiceCustomerEmail &&
      (billingReason === "subscription_create" || billingReason === "manual"),
  );

  if (shouldAttemptFallbackEmail && invoiceCustomerEmail) {
    const customerHasEmail = await stripeCustomerHasEmail(customerId);
    if (!customerHasEmail) {
      await sendWelcomeEmail({
        customerEmail: invoiceCustomerEmail,
        tier: tier ?? "grace",
        periodEndISO: new Date(invoice.period_end * 1000).toISOString(),
        stripeReceiptExpected: invoice.amount_paid > 0,
        amountPaidCents: invoice.amount_paid,
        currencyCode: invoice.currency ?? "gbp",
        discountApplied: Boolean(
          ((invoice as any).total_discount_amounts ?? []).length > 0,
        ),
        invoiceHostedUrl: invoice.hosted_invoice_url,
        invoicePdfUrl: invoice.invoice_pdf,
      });
      console.log(`✅ Sent fallback invoice email to ${invoiceCustomerEmail}`);
    }
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

// Determine subscription tier (grace/love) from Stripe subscription product
function determineTier(subscription: Stripe.Subscription): SubscriptionTier {
  try {
    for (const item of subscription.items.data) {
      const price = item.price;
      const productId =
        typeof price.product === "string"
          ? price.product
          : (price.product as any)?.id;
      const tier = determineTierFromProductId(productId);
      if (tier === "love") return "love";
      if (tier === "grace") return "grace";
    }
  } catch (err) {
    console.error("Error determining tier from subscription:", err);
  }

  // Paid fallback remains Grace for backward compatibility.
  return "grace";
}

type SendWelcomeEmailParams = {
  customerEmail: string;
  tier: SubscriptionTier;
  periodEndISO: string;
  stripeReceiptExpected: boolean;
  amountPaidCents: number | null;
  currencyCode: string;
  discountApplied: boolean;
  invoiceHostedUrl: string | null;
  invoicePdfUrl: string | null;
};

function formatTierName(tier: SubscriptionTier): string {
  if (tier === "love") return "Love (Pro)";
  if (tier === "grace") return "Grace (Premium)";
  return "Mercy (Free)";
}

async function sendWelcomeEmail(params: SendWelcomeEmailParams): Promise<void> {
  if (!resendApiKey) {
    console.warn(
      "RESEND_API_KEY not configured; skipping branded welcome email",
    );
    return;
  }

  const startAppUrl = `${websiteUrl}/success.html`;
  const tierName = formatTierName(params.tier);
  const periodEnd = new Date(params.periodEndISO).toLocaleDateString("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
  const amountPaidText = formatCurrency(
    params.amountPaidCents,
    params.currencyCode,
  );
  const paymentContextLine = params.discountApplied && params.amountPaidCents === 0
    ? "A 100% discount was applied, so no charge was taken today."
    : `Amount charged today: ${amountPaidText}.`;
  const stripeReceiptLine = params.stripeReceiptExpected
    ? "Stripe should send a receipt email for this paid charge."
    : "Stripe may not send a receipt because no charge was taken.";
  const invoiceLine = params.invoiceHostedUrl
    ? `You can view your invoice here: <a href="${params.invoiceHostedUrl}">Open Stripe invoice</a>.`
    : "";
  const invoicePdfLine = params.invoicePdfUrl
    ? `Invoice PDF: <a href="${params.invoicePdfUrl}">Download PDF</a>.`
    : "";
  const textInvoiceLine = params.invoiceHostedUrl
    ? `Invoice link: ${params.invoiceHostedUrl}`
    : "";
  const textInvoicePdfLine = params.invoicePdfUrl
    ? `Invoice PDF: ${params.invoicePdfUrl}`
    : "";

  const subject = `Welcome to Divine Link ${tierName}`;
  const html = `
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #1f2937;">
      <h2 style="margin-bottom: 12px;">Payment confirmed — you are now on ${tierName}</h2>
      <p style="margin: 0 0 12px;">Thank you for subscribing to Divine Link.</p>
      <p style="margin: 0 0 12px;">
        Your subscription is active and your current billing period runs until <strong>${periodEnd}</strong>.
      </p>
      <p style="margin: 0 0 12px;">${paymentContextLine}</p>
      <h3 style="margin: 24px 0 8px;">What to do next</h3>
      <ol style="margin: 0 0 16px 20px; padding: 0;">
        <li>Open Divine Link on your Mac.</li>
        <li>Sign in with this email address.</li>
        <li>Go to Settings → Account to confirm your tier.</li>
      </ol>
      <p style="margin: 0 0 16px;">
        Need the latest installer? <a href="${appDownloadUrl}">Download Divine Link</a>.
      </p>
      <p style="margin: 0 0 8px; font-size: 13px; color: #6b7280;">
        ${stripeReceiptLine}
      </p>
      ${
    invoiceLine
      ? `<p style="margin: 0 0 8px; font-size: 13px; color: #6b7280;">${invoiceLine}</p>`
      : ""
  }
      ${
    invoicePdfLine
      ? `<p style="margin: 0 0 12px; font-size: 13px; color: #6b7280;">${invoicePdfLine}</p>`
      : ""
  }
      <p style="margin: 0; font-size: 12px; color: #6b7280;">
        This mailbox is not monitored. Please do not reply to this message.
      </p>
      <p style="margin: 16px 0 0;">
        <a href="${startAppUrl}" style="color: #2563eb;">View post-payment setup page</a>
      </p>
    </div>
  `;

  const text = [
    `Payment confirmed - you are now on ${tierName}.`,
    "",
    `Your current billing period runs until ${periodEnd}.`,
    paymentContextLine,
    "",
    "What to do next:",
    "1) Open Divine Link on your Mac.",
    "2) Sign in with this email address.",
    "3) Go to Settings -> Account to confirm your tier.",
    "",
    `Download latest build: ${appDownloadUrl}`,
    `Post-payment setup page: ${startAppUrl}`,
    "",
    stripeReceiptLine,
    textInvoiceLine,
    textInvoicePdfLine,
    "This mailbox is not monitored. Please do not reply to this message.",
  ].filter(Boolean).join("\n");

  try {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: `Divine Link <${transactionalFromEmail}>`,
        to: [params.customerEmail],
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

    console.log(`✅ Branded welcome email sent to ${params.customerEmail}`);
  } catch (error) {
    console.error("Error sending branded welcome email:", error);
  }
}

function formatCurrency(
  amountCents: number | null,
  currencyCode: string,
): string {
  if (amountCents === null) return "not available";
  const amount = amountCents / 100;
  const safeCurrency = (currencyCode || "gbp").toUpperCase();
  try {
    return new Intl.NumberFormat("en-GB", {
      style: "currency",
      currency: safeCurrency,
    }).format(amount);
  } catch {
    return `${amount.toFixed(2)} ${safeCurrency}`;
  }
}

async function getCustomerEmail(customerId: string): Promise<string | null> {
  try {
    const customer = await stripe.customers.retrieve(customerId);
    if (typeof customer !== "string" && customer.email) {
      return customer.email;
    }
  } catch (error) {
    console.error("Failed to fetch Stripe customer email fallback:", error);
  }
  return null;
}

async function stripeCustomerHasEmail(customerId: string): Promise<boolean> {
  const email = await getCustomerEmail(customerId);
  return Boolean(email && email.trim().length > 0);
}
