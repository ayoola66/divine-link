-- ============================================
-- Migration: Add Video/GIF Support to Ads Table
-- Date: 2026-02-01
-- Description: Adds video_url and media_type columns for animated ads
-- Safe to run multiple times (idempotent)
-- ============================================

-- Check and add video_url column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ads' 
        AND column_name = 'video_url'
    ) THEN
        ALTER TABLE public.ads ADD COLUMN video_url TEXT;
        RAISE NOTICE 'Added video_url column';
    ELSE
        RAISE NOTICE 'video_url column already exists';
    END IF;
END $$;

-- Check and add media_type column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ads' 
        AND column_name = 'media_type'
    ) THEN
        ALTER TABLE public.ads ADD COLUMN media_type TEXT DEFAULT 'image';
        RAISE NOTICE 'Added media_type column';
    ELSE
        RAISE NOTICE 'media_type column already exists';
    END IF;
END $$;

-- Add check constraint for media_type if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.constraint_column_usage 
        WHERE table_schema = 'public' 
        AND table_name = 'ads' 
        AND constraint_name = 'ads_media_type_check'
    ) THEN
        ALTER TABLE public.ads 
        ADD CONSTRAINT ads_media_type_check 
        CHECK (media_type IN ('image', 'video', 'gif'));
        RAISE NOTICE 'Added media_type check constraint';
    ELSE
        RAISE NOTICE 'media_type check constraint already exists';
    END IF;
END $$;

-- Update existing rows to have media_type = 'image' if NULL
UPDATE public.ads 
SET media_type = 'image' 
WHERE media_type IS NULL;

-- Add comments to columns
COMMENT ON COLUMN public.ads.video_url IS 'Optional: URL to video/GIF file (10-15 seconds, looping)';
COMMENT ON COLUMN public.ads.media_type IS 'Type of media: image (static), video (MP4), or gif (animated GIF)';

-- Success message
DO $$ 
BEGIN
    RAISE NOTICE 'Migration completed successfully!';
    RAISE NOTICE 'video_url and media_type columns are now available for ads.';
END $$;
