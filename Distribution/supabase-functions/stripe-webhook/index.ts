// Supabase Edge Function: Stripe Webhook Handler
// Deploy with: supabase functions deploy stripe-webhook
//
// Set secrets:
// supabase secrets set STRIPE_SECRET_KEY=sk_live_xxx
// supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_xxx

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@13.10.0'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
})

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? ''

serve(async (req: Request) => {
  const signature = req.headers.get('stripe-signature')
  
  if (!signature) {
    return new Response('No signature', { status: 400 })
  }

  try {
    const body = await req.text()
    const event = stripe.webhooks.constructEvent(body, signature, webhookSecret)
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey)
    
    console.log(`Processing event: ${event.type}`)
    
    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.Checkout.Session
        await handleCheckoutComplete(supabase, session)
        break
      }
      
      case 'customer.subscription.created':
      case 'customer.subscription.updated': {
        const subscription = event.data.object as Stripe.Subscription
        await handleSubscriptionUpdate(supabase, subscription)
        break
      }
      
      case 'customer.subscription.deleted': {
        const subscription = event.data.object as Stripe.Subscription
        await handleSubscriptionCancelled(supabase, subscription)
        break
      }
      
      case 'invoice.payment_succeeded': {
        const invoice = event.data.object as Stripe.Invoice
        await handlePaymentSucceeded(supabase, invoice)
        break
      }
      
      case 'invoice.payment_failed': {
        const invoice = event.data.object as Stripe.Invoice
        await handlePaymentFailed(supabase, invoice)
        break
      }
      
      default:
        console.log(`Unhandled event type: ${event.type}`)
    }
    
    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
    
  } catch (err) {
    console.error('Webhook error:', err)
    return new Response(`Webhook Error: ${err.message}`, { status: 400 })
  }
})

// Handle successful checkout
async function handleCheckoutComplete(supabase: any, session: Stripe.Checkout.Session) {
  const customerEmail = session.customer_email || session.customer_details?.email
  const customerId = session.customer as string
  const subscriptionId = session.subscription as string
  
  if (!customerEmail) {
    console.error('No customer email in session')
    return
  }
  
  console.log(`Checkout complete for: ${customerEmail}`)
  
  // Find user by email
  const { data: users, error: userError } = await supabase
    .from('profiles')
    .select('id')
    .eq('email', customerEmail)
    .limit(1)
  
  if (userError || !users?.length) {
    console.error('User not found:', customerEmail)
    return
  }
  
  const userId = users[0].id
  
  // Get subscription details from Stripe
  const subscription = await stripe.subscriptions.retrieve(subscriptionId)
  
  // Update subscription in database
  const { error: updateError } = await supabase
    .from('subscriptions')
    .update({
      status: 'premium',
      stripe_customer_id: customerId,
      stripe_subscription_id: subscriptionId,
      current_period_start: new Date(subscription.current_period_start * 1000).toISOString(),
      current_period_end: new Date(subscription.current_period_end * 1000).toISOString(),
      cancel_at_period_end: subscription.cancel_at_period_end,
    })
    .eq('user_id', userId)
  
  if (updateError) {
    console.error('Failed to update subscription:', updateError)
  } else {
    console.log(`✅ Subscription activated for user: ${userId}`)
  }
}

// Handle subscription updates
async function handleSubscriptionUpdate(supabase: any, subscription: Stripe.Subscription) {
  const customerId = subscription.customer as string
  
  // Find user by Stripe customer ID
  const { data: subs, error: subError } = await supabase
    .from('subscriptions')
    .select('user_id')
    .eq('stripe_customer_id', customerId)
    .limit(1)
  
  if (subError || !subs?.length) {
    console.log('Subscription not found for customer:', customerId)
    return
  }
  
  const status = mapStripeStatus(subscription.status)
  
  const { error: updateError } = await supabase
    .from('subscriptions')
    .update({
      status,
      current_period_start: new Date(subscription.current_period_start * 1000).toISOString(),
      current_period_end: new Date(subscription.current_period_end * 1000).toISOString(),
      cancel_at_period_end: subscription.cancel_at_period_end,
    })
    .eq('stripe_customer_id', customerId)
  
  if (updateError) {
    console.error('Failed to update subscription:', updateError)
  } else {
    console.log(`✅ Subscription updated: ${status}`)
  }
}

// Handle subscription cancellation
async function handleSubscriptionCancelled(supabase: any, subscription: Stripe.Subscription) {
  const customerId = subscription.customer as string
  
  const { error } = await supabase
    .from('subscriptions')
    .update({
      status: 'cancelled',
      cancel_at_period_end: true,
    })
    .eq('stripe_customer_id', customerId)
  
  if (error) {
    console.error('Failed to cancel subscription:', error)
  } else {
    console.log(`✅ Subscription cancelled for customer: ${customerId}`)
  }
}

// Handle successful payment
async function handlePaymentSucceeded(supabase: any, invoice: Stripe.Invoice) {
  const customerId = invoice.customer as string
  
  // Ensure subscription is active after payment
  const { error } = await supabase
    .from('subscriptions')
    .update({
      status: 'premium',
    })
    .eq('stripe_customer_id', customerId)
  
  if (!error) {
    console.log(`✅ Payment succeeded for customer: ${customerId}`)
  }
}

// Handle failed payment
async function handlePaymentFailed(supabase: any, invoice: Stripe.Invoice) {
  const customerId = invoice.customer as string
  
  // Mark subscription as past due
  const { error } = await supabase
    .from('subscriptions')
    .update({
      status: 'expired',
    })
    .eq('stripe_customer_id', customerId)
  
  if (!error) {
    console.log(`⚠️ Payment failed for customer: ${customerId}`)
  }
}

// Map Stripe subscription status to our status
function mapStripeStatus(stripeStatus: Stripe.Subscription.Status): string {
  switch (stripeStatus) {
    case 'active':
      return 'premium'
    case 'trialing':
      return 'trial'
    case 'past_due':
    case 'unpaid':
      return 'expired'
    case 'canceled':
      return 'cancelled'
    default:
      return 'free'
  }
}
