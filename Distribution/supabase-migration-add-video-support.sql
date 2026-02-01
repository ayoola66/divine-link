-- Migration: Add video/GIF support to ads table
-- Date: 2026-02-01
-- Description: Adds video_url and media_type columns to support animated ads

-- Add video_url column (optional)
ALTER TABLE public.ads 
ADD COLUMN IF NOT EXISTS video_url TEXT;

-- Add media_type column with default 'image'
ALTER TABLE public.ads 
ADD COLUMN IF NOT EXISTS media_type TEXT DEFAULT 'image' CHECK (media_type IN ('image', 'video', 'gif'));

-- Update existing rows to have media_type = 'image'
UPDATE public.ads 
SET media_type = 'image' 
WHERE media_type IS NULL;

-- Add comment to columns
COMMENT ON COLUMN public.ads.video_url IS 'Optional: URL to video/GIF file (10-15 seconds, looping)';
COMMENT ON COLUMN public.ads.media_type IS 'Type of media: image (static), video (MP4), or gif (animated GIF)';
