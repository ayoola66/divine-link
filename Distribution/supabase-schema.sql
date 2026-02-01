-- Divine Link Database Schema
-- Run this in Supabase SQL Editor: https://supabase.com/dashboard/project/qzjhjgkvvcamcqpdrgkf/sql

-- ============================================
-- 1. PROFILES TABLE
-- Extends Supabase auth.users with app-specific data
-- ============================================

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    display_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Users can only read/update their own profile
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email)
    VALUES (NEW.id, NEW.email);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 2. SUBSCRIPTIONS TABLE
-- Tracks user subscription status
-- ============================================

CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'free' CHECK (status IN ('free', 'trial', 'premium', 'cancelled', 'expired')),
    stripe_customer_id TEXT,
    stripe_subscription_id TEXT,
    current_period_start TIMESTAMPTZ,
    current_period_end TIMESTAMPTZ,
    cancel_at_period_end BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

-- Enable Row Level Security
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- Users can only view their own subscription
CREATE POLICY "Users can view own subscription" ON public.subscriptions
    FOR SELECT USING (auth.uid() = user_id);

-- Auto-create free subscription on profile creation
CREATE OR REPLACE FUNCTION public.handle_new_profile()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.subscriptions (user_id, status)
    VALUES (NEW.id, 'free');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_profile_created ON public.profiles;
CREATE TRIGGER on_profile_created
    AFTER INSERT ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_profile();

-- ============================================
-- 3. DEVICES TABLE
-- Tracks registered devices (max 2 per account)
-- ============================================

CREATE TABLE IF NOT EXISTS public.devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    device_name TEXT,
    device_model TEXT,
    os_version TEXT,
    app_version TEXT,
    last_active_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(user_id, device_id)
);

-- Enable Row Level Security
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;

-- Users can view and manage their own devices
CREATE POLICY "Users can view own devices" ON public.devices
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own devices" ON public.devices
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own devices" ON public.devices
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own devices" ON public.devices
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- 4. HELPER FUNCTIONS
-- ============================================

-- Get active device count for a user
CREATE OR REPLACE FUNCTION public.get_active_device_count(p_user_id UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::INTEGER
        FROM public.devices
        WHERE user_id = p_user_id AND is_active = TRUE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check if user can register new device (max 2)
CREATE OR REPLACE FUNCTION public.can_register_device(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (
        SELECT COUNT(*) < 2
        FROM public.devices
        WHERE user_id = p_user_id AND is_active = TRUE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get subscription status for current user
CREATE OR REPLACE FUNCTION public.get_my_subscription()
RETURNS TABLE (
    status TEXT,
    is_premium BOOLEAN,
    period_end TIMESTAMPTZ,
    device_count INTEGER,
    max_devices INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.status,
        (s.status = 'premium' OR s.status = 'trial') AS is_premium,
        s.current_period_end AS period_end,
        public.get_active_device_count(auth.uid()) AS device_count,
        2 AS max_devices
    FROM public.subscriptions s
    WHERE s.user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 5. INDEXES FOR PERFORMANCE
-- ============================================

CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON public.subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_stripe_customer ON public.subscriptions(stripe_customer_id);
CREATE INDEX IF NOT EXISTS idx_devices_user_id ON public.devices(user_id);
CREATE INDEX IF NOT EXISTS idx_devices_device_id ON public.devices(device_id);

-- ============================================
-- 6. UPDATED_AT TRIGGER
-- ============================================

CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS profiles_updated_at ON public.profiles;
CREATE TRIGGER profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS subscriptions_updated_at ON public.subscriptions;
CREATE TRIGGER subscriptions_updated_at
    BEFORE UPDATE ON public.subscriptions
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================
-- 7. DYNAMIC ADS TABLE
-- For serving affiliate/house ads to free users
-- ============================================

CREATE TABLE IF NOT EXISTS public.ads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Ad identification
    name TEXT NOT NULL,
    slot TEXT NOT NULL CHECK (slot IN ('sidebar_top', 'sidebar_middle', 'sidebar_bottom', 'bottom_banner')),
    
    -- Content
    image_url TEXT NOT NULL,           -- URL to ad image (hosted on your CDN/storage)
    click_url TEXT NOT NULL,           -- Affiliate link or destination URL
    alt_text TEXT,                     -- Accessibility text
    
    -- Targeting & Scheduling
    is_active BOOLEAN DEFAULT TRUE,
    priority INTEGER DEFAULT 0,        -- Higher = shown more often
    start_date TIMESTAMPTZ,            -- Optional: when to start showing
    end_date TIMESTAMPTZ,              -- Optional: when to stop showing
    
    -- Tracking
    impressions INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security (public read for active ads)
ALTER TABLE public.ads ENABLE ROW LEVEL SECURITY;

-- Anyone can read active ads (no auth required for ad serving)
CREATE POLICY "Anyone can view active ads" ON public.ads
    FOR SELECT USING (
        is_active = TRUE 
        AND (start_date IS NULL OR start_date <= NOW())
        AND (end_date IS NULL OR end_date >= NOW())
    );

-- Create index for efficient ad queries
CREATE INDEX IF NOT EXISTS idx_ads_slot_active ON public.ads(slot, is_active, priority DESC);
CREATE INDEX IF NOT EXISTS idx_ads_dates ON public.ads(start_date, end_date);

-- Trigger to update updated_at
DROP TRIGGER IF EXISTS ads_updated_at ON public.ads;
CREATE TRIGGER ads_updated_at
    BEFORE UPDATE ON public.ads
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================
-- 8. APP HEARTBEAT TABLE
-- Tracks last online check for connectivity enforcement
-- ============================================

CREATE TABLE IF NOT EXISTS public.app_heartbeats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL UNIQUE,
    last_seen_at TIMESTAMPTZ DEFAULT NOW(),
    app_version TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Anyone can upsert heartbeat (no auth required)
ALTER TABLE public.app_heartbeats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can insert heartbeat" ON public.app_heartbeats
    FOR INSERT WITH CHECK (TRUE);

CREATE POLICY "Anyone can update own heartbeat" ON public.app_heartbeats
    FOR UPDATE USING (TRUE);

CREATE POLICY "Anyone can view own heartbeat" ON public.app_heartbeats
    FOR SELECT USING (TRUE);

-- Function to get active ads for a slot
CREATE OR REPLACE FUNCTION public.get_ads_for_slot(p_slot TEXT)
RETURNS TABLE (
    id UUID,
    name TEXT,
    image_url TEXT,
    click_url TEXT,
    alt_text TEXT,
    priority INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.name,
        a.image_url,
        a.click_url,
        a.alt_text,
        a.priority
    FROM public.ads a
    WHERE a.slot = p_slot
      AND a.is_active = TRUE
      AND (a.start_date IS NULL OR a.start_date <= NOW())
      AND (a.end_date IS NULL OR a.end_date >= NOW())
    ORDER BY a.priority DESC, RANDOM()
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to record ad impression
CREATE OR REPLACE FUNCTION public.record_ad_impression(p_ad_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.ads 
    SET impressions = impressions + 1
    WHERE id = p_ad_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to record ad click
CREATE OR REPLACE FUNCTION public.record_ad_click(p_ad_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.ads 
    SET clicks = clicks + 1
    WHERE id = p_ad_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 9. APP SETTINGS TABLE
-- For storing admin password hash and other settings
-- ============================================

CREATE TABLE IF NOT EXISTS public.app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS but allow public read/write for settings
-- In production, you'd want more restrictive policies
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read settings" ON public.app_settings
    FOR SELECT USING (TRUE);

CREATE POLICY "Anyone can insert settings" ON public.app_settings
    FOR INSERT WITH CHECK (TRUE);

CREATE POLICY "Anyone can update settings" ON public.app_settings
    FOR UPDATE USING (TRUE);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS app_settings_updated_at ON public.app_settings;
CREATE TRIGGER app_settings_updated_at
    BEFORE UPDATE ON public.app_settings
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================
-- 10. FUNCTION TO GET RANDOM AD FOR ROTATION
-- Returns a random active ad for a given slot
-- ============================================

CREATE OR REPLACE FUNCTION public.get_random_ad_for_slot(p_slot TEXT)
RETURNS TABLE (
    id UUID,
    name TEXT,
    image_url TEXT,
    click_url TEXT,
    alt_text TEXT,
    priority INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.name,
        a.image_url,
        a.click_url,
        a.alt_text,
        a.priority
    FROM public.ads a
    WHERE a.slot = p_slot
      AND a.is_active = TRUE
      AND (a.start_date IS NULL OR a.start_date <= NOW())
      AND (a.end_date IS NULL OR a.end_date >= NOW())
    ORDER BY RANDOM()
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 11. FUNCTION TO GET ALL ACTIVE ADS
-- Returns all active ads for the app to cache
-- ============================================

CREATE OR REPLACE FUNCTION public.get_all_active_ads()
RETURNS TABLE (
    id UUID,
    name TEXT,
    slot TEXT,
    image_url TEXT,
    click_url TEXT,
    alt_text TEXT,
    priority INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.name,
        a.slot,
        a.image_url,
        a.click_url,
        a.alt_text,
        a.priority
    FROM public.ads a
    WHERE a.is_active = TRUE
      AND (a.start_date IS NULL OR a.start_date <= NOW())
      AND (a.end_date IS NULL OR a.end_date >= NOW())
    ORDER BY a.slot, a.priority DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
