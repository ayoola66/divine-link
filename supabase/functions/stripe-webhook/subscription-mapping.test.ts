import {
  determineTierFromProductId,
  mapStripeStatus,
  type StripeSubscriptionStatus,
} from "./subscription-mapping.ts";

Deno.test("determineTierFromProductId maps Grace product", () => {
  const tier = determineTierFromProductId("prod_TtV8U5mVO1cecV");
  if (tier !== "grace") {
    throw new Error(`Expected grace, received ${tier}`);
  }
});

Deno.test("determineTierFromProductId maps Love product", () => {
  const tier = determineTierFromProductId("prod_TvU0LGh7zBgIH3");
  if (tier !== "love") {
    throw new Error(`Expected love, received ${tier}`);
  }
});

Deno.test("determineTierFromProductId defaults to grace for unknown product", () => {
  const tier = determineTierFromProductId("prod_unknown");
  if (tier !== "grace") {
    throw new Error(`Expected grace fallback, received ${tier}`);
  }
});

Deno.test("mapStripeStatus maps active/trialing to premium/trial", () => {
  const active = mapStripeStatus("active");
  const trialing = mapStripeStatus("trialing");
  if (active !== "premium") {
    throw new Error(`Expected premium for active, received ${active}`);
  }
  if (trialing !== "trial") {
    throw new Error(`Expected trial for trialing, received ${trialing}`);
  }
});

Deno.test("mapStripeStatus maps past due and cancelled states", () => {
  const pastDue = mapStripeStatus("past_due");
  const cancelled = mapStripeStatus("canceled");
  if (pastDue !== "expired") {
    throw new Error(`Expected expired for past_due, received ${pastDue}`);
  }
  if (cancelled !== "cancelled") {
    throw new Error(`Expected cancelled for canceled, received ${cancelled}`);
  }
});

Deno.test("mapStripeStatus defaults unknown status to free", () => {
  const unknown = mapStripeStatus("incomplete" as StripeSubscriptionStatus);
  if (unknown !== "free") {
    throw new Error(`Expected free fallback, received ${unknown}`);
  }
});
