-- Divine Link: Subscription Tier Migration
-- Run this in Supabase SQL Editor for existing projects.

BEGIN;

-- 1) Add explicit entitlement tier column (if missing)
ALTER TABLE public.subscriptions
ADD COLUMN IF NOT EXISTS tier TEXT;

-- 2) Backfill tier from legacy status values
UPDATE public.subscriptions
SET tier = CASE
    WHEN status = 'love' THEN 'love'
    WHEN status IN ('premium', 'grace', 'trial') THEN 'grace'
    ELSE 'mercy'
END
WHERE tier IS NULL;

-- 3) Enforce tier constraints/default
ALTER TABLE public.subscriptions
ALTER COLUMN tier SET DEFAULT 'mercy',
ALTER COLUMN tier SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'subscriptions_tier_check'
    ) THEN
        ALTER TABLE public.subscriptions
        ADD CONSTRAINT subscriptions_tier_check
        CHECK (tier IN ('mercy', 'grace', 'love'));
    END IF;
END $$;

-- 4) Expand status constraint for legacy compatibility (grace/love rows)
DO $$
DECLARE
    old_check_name text;
BEGIN
    -- First, explicitly remove the canonical constraint name if it already exists.
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.subscriptions'::regclass
          AND conname = 'subscriptions_status_check'
    ) THEN
        ALTER TABLE public.subscriptions DROP CONSTRAINT subscriptions_status_check;
    END IF;

    -- Then remove any legacy status-check constraint under a different name.
    SELECT conname
    INTO old_check_name
    FROM pg_constraint
    WHERE conrelid = 'public.subscriptions'::regclass
      AND contype = 'c'
      AND conname <> 'subscriptions_tier_check'
      AND pg_get_constraintdef(oid) ILIKE '%status%';

    IF old_check_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE public.subscriptions DROP CONSTRAINT %I', old_check_name);
    END IF;

    ALTER TABLE public.subscriptions
    ADD CONSTRAINT subscriptions_status_check
    CHECK (status IN ('free', 'trial', 'premium', 'cancelled', 'expired', 'grace', 'love'));
END $$;

COMMIT;
