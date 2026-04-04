export type SubscriptionTier = "mercy" | "grace" | "love";
export type SubscriptionStatus =
  | "free"
  | "trial"
  | "premium"
  | "cancelled"
  | "expired";

export type StripeSubscriptionStatus =
  | "incomplete"
  | "incomplete_expired"
  | "trialing"
  | "active"
  | "past_due"
  | "canceled"
  | "unpaid"
  | "paused";

export const STRIPE_PRODUCT_IDS = {
  grace: "prod_TtV8U5mVO1cecV",
  love: "prod_TvU0LGh7zBgIH3",
} as const;

export function determineTierFromProductId(productId: string | null | undefined): SubscriptionTier {
  if (!productId) return "grace";
  if (productId === STRIPE_PRODUCT_IDS.love) return "love";
  if (productId === STRIPE_PRODUCT_IDS.grace) return "grace";
  // Backward-compatible paid fallback.
  return "grace";
}

export function mapStripeStatus(stripeStatus: StripeSubscriptionStatus): SubscriptionStatus {
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
