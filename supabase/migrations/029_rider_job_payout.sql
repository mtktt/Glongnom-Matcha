-- ============================================================
-- Glongnom POS — Migration 029: Rider payout tracking on jobs
-- ============================================================
-- Adds a manual "have we paid this rider their wage yet?" flag to each
-- delivery job, so admin/rider.html → "ประวัติการรับงาน" can mark each
-- job paid/unpaid and total the outstanding wages.
--
-- This is internal bookkeeping between the shop and its riders — it is
-- deliberately NOT exposed through the public rider RPCs (get_rider_job
-- etc.), so riders never see payout state.
--
-- Run in: Supabase Dashboard → SQL Editor → New Query.
-- ============================================================

ALTER TABLE public.rider_jobs
  ADD COLUMN IF NOT EXISTS rider_paid    boolean     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS rider_paid_at timestamptz;

-- Helpful when filtering the payout view by unpaid jobs.
CREATE INDEX IF NOT EXISTS rider_jobs_rider_paid_idx ON public.rider_jobs(rider_paid);

-- ------------------------------------------------------------
-- ROLLBACK (uncomment to undo):
--   DROP INDEX IF EXISTS public.rider_jobs_rider_paid_idx;
--   ALTER TABLE public.rider_jobs DROP COLUMN IF EXISTS rider_paid_at;
--   ALTER TABLE public.rider_jobs DROP COLUMN IF EXISTS rider_paid;
-- ------------------------------------------------------------
