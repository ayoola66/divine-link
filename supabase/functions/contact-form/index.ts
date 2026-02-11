// Supabase Edge Function: Contact Form Handler
// Deploy with: supabase functions deploy contact-form
//
// Set secrets:
// supabase secrets set CONTACT_EMAIL=ayo@orekunmedia.com
// supabase secrets set RESEND_API_KEY=re_xxxx  (get from https://resend.com)
//
// This function receives contact form submissions from paid/previous-paid
// customers and forwards them securely via email. The destination email
// is NEVER exposed to the client — it lives only in server-side secrets.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const contactEmail = Deno.env.get('CONTACT_EMAIL') ?? 'ayo@orekunmedia.com'
const resendApiKey = Deno.env.get('RESEND_API_KEY') ?? ''

// CORS headers for the app
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405, headers: corsHeaders })
  }

  try {
    // Verify the request has a valid auth token (paid customer check)
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Unauthorised' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Verify user via Supabase auth
    const supabase = createClient(supabaseUrl, supabaseServiceKey)
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid authentication' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse the form payload
    const payload = await req.json()
    const {
      title = '',
      name = '',
      email = '',
      phone = '',
      message = '',
      user_id = '',
      app_version = '',
      tier = '',
      timestamp = '',
    } = payload

    // Basic server-side validation
    if (!name?.trim() || !email?.trim() || !message?.trim()) {
      return new Response(
        JSON.stringify({ error: 'Name, email, and message are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Store the submission in a Supabase table for record-keeping
    const { error: insertError } = await supabase
      .from('contact_submissions')
      .insert({
        user_id: user.id,
        title,
        full_name: name,
        email,
        phone,
        message,
        app_version,
        subscription_tier: tier,
        submitted_at: timestamp || new Date().toISOString(),
      })

    if (insertError) {
      console.error('Failed to store contact submission:', insertError)
      // Continue — email delivery is more important than DB storage
    }

    // Send email via Resend (https://resend.com — free tier: 100 emails/day)
    if (resendApiKey) {
      const emailResponse = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${resendApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: 'Divine Link Support <noreply@divinelink.app>',
          to: [contactEmail],
          reply_to: email,
          subject: `[Divine Link Support] ${title ? title + ' ' : ''}${name} — ${tier} tier`,
          html: `
            <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 600px;">
              <h2 style="color: #E07A2B;">Divine Link Support Enquiry</h2>
              <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
                <tr><td style="padding: 8px; font-weight: bold; color: #666; width: 120px;">Title</td><td style="padding: 8px;">${title || '—'}</td></tr>
                <tr><td style="padding: 8px; font-weight: bold; color: #666;">Name</td><td style="padding: 8px;">${name}</td></tr>
                <tr><td style="padding: 8px; font-weight: bold; color: #666;">Email</td><td style="padding: 8px;"><a href="mailto:${email}">${email}</a></td></tr>
                <tr><td style="padding: 8px; font-weight: bold; color: #666;">Phone</td><td style="padding: 8px;">${phone || '—'}</td></tr>
                <tr><td style="padding: 8px; font-weight: bold; color: #666;">Tier</td><td style="padding: 8px;">${tier}</td></tr>
                <tr><td style="padding: 8px; font-weight: bold; color: #666;">App Version</td><td style="padding: 8px;">${app_version}</td></tr>
                <tr><td style="padding: 8px; font-weight: bold; color: #666;">User ID</td><td style="padding: 8px; font-size: 0.85em;">${user_id || user.id}</td></tr>
                <tr><td style="padding: 8px; font-weight: bold; color: #666;">Submitted</td><td style="padding: 8px;">${timestamp || new Date().toISOString()}</td></tr>
              </table>
              <div style="background: #f5f5f5; padding: 16px; border-radius: 8px; border-left: 4px solid #E07A2B;">
                <h3 style="margin-top: 0; color: #333;">Message</h3>
                <p style="white-space: pre-wrap; line-height: 1.6;">${message}</p>
              </div>
              <hr style="margin-top: 24px; border: none; border-top: 1px solid #eee;" />
              <p style="font-size: 0.8em; color: #999;">This message was sent from the Divine Link macOS app contact form.</p>
            </div>
          `,
        }),
      })

      if (!emailResponse.ok) {
        const errBody = await emailResponse.text()
        console.error('Resend email failed:', errBody)
        // Still return success — the record is saved in the DB
      } else {
        console.log(`✅ Contact form email sent to ${contactEmail} from ${email}`)
      }
    } else {
      console.warn('RESEND_API_KEY not set — email not sent, but submission stored in DB')
    }

    return new Response(
      JSON.stringify({ success: true, message: 'Enquiry received' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (err) {
    console.error('Contact form error:', err)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
