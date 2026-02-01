-- ============================================
-- FIX: Add video_url and media_type to get_all_active_ads function
-- Run this in Supabase SQL Editor to enable video/GIF ads
-- ============================================

-- First, ensure the columns exist in the ads table
-- (these should already exist if you ran the migration)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'ads' AND column_name = 'video_url'
    ) THEN
        ALTER TABLE public.ads ADD COLUMN video_url TEXT;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'ads' AND column_name = 'media_type'
    ) THEN
        ALTER TABLE public.ads ADD COLUMN media_type TEXT DEFAULT 'image';
    END IF;
END $$;

-- DROP the old function first (required when changing return type)
DROP FUNCTION IF EXISTS public.get_all_active_ads();

-- Now create the function with video columns
CREATE OR REPLACE FUNCTION public.get_all_active_ads()
RETURNS TABLE (
    id UUID,
    name TEXT,
    slot TEXT,
    format TEXT,
    image_url TEXT,
    video_url TEXT,
    media_type TEXT,
    click_url TEXT,
    alt_text TEXT,
    priority INTEGER,
    is_enforced BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.name,
        a.slot,
        a.format,
        a.image_url,
        a.video_url,
        a.media_type,
        a.click_url,
        a.alt_text,
        a.priority,
        a.is_enforced
    FROM public.ads a
    WHERE a.is_active = TRUE
      AND (a.start_date IS NULL OR a.start_date <= NOW())
      AND (a.end_date IS NULL OR a.end_date >= NOW())
    ORDER BY a.is_enforced DESC, a.priority DESC, a.slot;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Verify: Check current ads with video/media info
SELECT id, name, media_type, video_url, image_url 
FROM public.ads 
WHERE is_active = true;
