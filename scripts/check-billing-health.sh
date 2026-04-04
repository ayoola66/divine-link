#!/bin/bash
set -euo pipefail

SUCCESS_URL="${SUCCESS_URL:-https://divinelink.netlify.app/success.html}"
WEBHOOK_URL="${WEBHOOK_URL:-https://qzjhjgkvvcamcqpdrgkf.supabase.co/functions/v1/stripe-webhook}"

REQUIRED_EVENTS=(
  "checkout.session.completed"
  "customer.subscription.created"
  "customer.subscription.updated"
  "customer.subscription.deleted"
  "invoice.payment_succeeded"
  "invoice.payment_failed"
)

PAYMENT_LINK_URLS=(
  "https://buy.stripe.com/8x228raJOceGbI50hn5AQ00"
  "https://buy.stripe.com/bJe00jf04emO7rPfch5AQ03"
  "https://buy.stripe.com/7sYbJ14lqemO6nL7JP5AQ01"
  "https://buy.stripe.com/dRmdR98BG2E6eUh4xD5AQ02"
)

failures=0

pass() {
  echo "PASS: $1"
}

warn() {
  echo "WARN: $1"
}

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

require_cmd stripe
require_cmd jq

echo "== Stripe webhook endpoint check =="
webhook_json=$(stripe webhook_endpoints list --live --limit 20)
webhook_match=$(echo "$webhook_json" | jq --arg url "$WEBHOOK_URL" -r '.data[] | select(.url == $url) | @base64' || true)

if [[ -z "${webhook_match}" ]]; then
  fail "Webhook endpoint not found: $WEBHOOK_URL"
else
  webhook_obj=$(echo "$webhook_match" | base64 --decode)
  status=$(echo "$webhook_obj" | jq -r '.status')
  if [[ "$status" == "enabled" ]]; then
    pass "Webhook endpoint is enabled"
  else
    fail "Webhook endpoint status is '$status'"
  fi

  for event in "${REQUIRED_EVENTS[@]}"; do
    has_event=$(echo "$webhook_obj" | jq --arg event "$event" -r '.enabled_events | index($event) != null')
    if [[ "$has_event" == "true" ]]; then
      pass "Webhook event enabled: $event"
    else
      fail "Webhook event missing: $event"
    fi
  done
fi

echo
echo "== Stripe payment link redirect check =="
links_json=$(stripe payment_links list --live --limit 100)

for link_url in "${PAYMENT_LINK_URLS[@]}"; do
  link_obj=$(echo "$links_json" | jq --arg url "$link_url" '.data[] | select(.url == $url)' || true)
  if [[ -z "${link_obj}" ]]; then
    fail "Payment link not found: $link_url"
    continue
  fi

  link_id=$(echo "$link_obj" | jq -r '.id')
  redirect_type=$(echo "$link_obj" | jq -r '.after_completion.type')
  redirect_url=$(echo "$link_obj" | jq -r '.after_completion.redirect.url // ""')

  if [[ "$redirect_type" != "redirect" ]]; then
    fail "$link_id is not set to redirect mode (found '$redirect_type')"
    continue
  fi

  if [[ "$redirect_url" != "$SUCCESS_URL" ]]; then
    fail "$link_id redirect URL mismatch (found '$redirect_url')"
  else
    pass "$link_id redirects to success page"
  fi
done

echo
echo "== Recent event sanity =="
latest_checkout=$(stripe events list --live --type checkout.session.completed --limit 1)
latest_invoice=$(stripe events list --live --type invoice.payment_succeeded --limit 1)

checkout_pending=$(echo "$latest_checkout" | jq -r '.data[0].pending_webhooks')
checkout_amount_total=$(echo "$latest_checkout" | jq -r '.data[0].data.object.amount_total')
checkout_success_url=$(echo "$latest_checkout" | jq -r '.data[0].data.object.success_url')
checkout_id=$(echo "$latest_checkout" | jq -r '.data[0].id')

if [[ "$checkout_pending" == "0" ]]; then
  pass "Latest checkout event pending_webhooks is 0 ($checkout_id)"
else
  warn "Latest checkout event has pending_webhooks=$checkout_pending ($checkout_id)"
fi
echo "INFO: Latest checkout amount_total=${checkout_amount_total}, success_url=${checkout_success_url}"

invoice_pending=$(echo "$latest_invoice" | jq -r '.data[0].pending_webhooks')
invoice_amount_paid=$(echo "$latest_invoice" | jq -r '.data[0].data.object.amount_paid')
invoice_id=$(echo "$latest_invoice" | jq -r '.data[0].id')
invoice_billing_reason=$(echo "$latest_invoice" | jq -r '.data[0].data.object.billing_reason')

if [[ "$invoice_pending" == "0" ]]; then
  pass "Latest invoice event pending_webhooks is 0 ($invoice_id)"
else
  warn "Latest invoice event has pending_webhooks=$invoice_pending ($invoice_id)"
fi
echo "INFO: Latest invoice amount_paid=${invoice_amount_paid}, billing_reason=${invoice_billing_reason}"

echo
if [[ "$failures" -gt 0 ]]; then
  echo "Billing health check finished with $failures failure(s)."
  exit 1
fi

echo "Billing health check passed."
