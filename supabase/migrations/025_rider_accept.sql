-- ============================================================
-- Glongnom POS — Migration 025: Rider self-accept flow (Phase 2)
-- ============================================================
-- Public "tap to accept" workflow for a broadcast delivery link:
--
--   1. Staff clicks "Copy to rider" on an order → an OPEN rider_job
--      is created and a link /r.html?job=<accept_token> is copied.
--   2. Staff pastes the link into the rider LINE group.
--   3. A registered rider opens it and taps "รับงาน".
--   4. First rider to accept wins (atomic claim). Others see it taken.
--   5. The accepting rider updates status (picked_up → delivered),
--      each stamped automatically.
--
-- Rider identity WITHOUT a login: each rider has a secret `claim_token`.
-- Their device remembers it (via a one-time personal link
-- /r.html?setup=<claim_token>). Every accept/status call carries that
-- token, so the server always knows exactly which registered rider
-- acted — and rejects anyone whose token isn't a registered rider.
--
-- All public actions go through SECURITY DEFINER RPCs (like
-- create_order in 021) — the anon key never writes these tables
-- directly. Every RPC is gated on knowing a 128-bit token.
--
-- Run in: Supabase Dashboard → SQL Editor → New Query.
-- ============================================================

-- ── riders: secret per-rider identity token ─────────────────
ALTER TABLE public.riders
  ADD COLUMN IF NOT EXISTS claim_token text;

UPDATE public.riders
   SET claim_token = md5(random()::text || clock_timestamp()::text || id::text)
 WHERE claim_token IS NULL;

ALTER TABLE public.riders
  ALTER COLUMN claim_token SET DEFAULT md5(random()::text || clock_timestamp()::text);

CREATE UNIQUE INDEX IF NOT EXISTS riders_claim_token_idx ON public.riders(claim_token);

-- ── rider_jobs: add 'open' status + pickup timestamp ────────
ALTER TABLE public.rider_jobs
  ADD COLUMN IF NOT EXISTS picked_up_at timestamptz;

ALTER TABLE public.rider_jobs DROP CONSTRAINT IF EXISTS rider_jobs_status_check;
ALTER TABLE public.rider_jobs ADD CONSTRAINT rider_jobs_status_check
  CHECK (status IN ('open','assigned','accepted','picked_up','delivered','cancelled'));

-- ============================================================
-- RPC 1 — resolve a rider identity from their secret token.
-- Used by the setup link and the manual "enter code" fallback.
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_rider_identity(p_claim_token text)
RETURNS TABLE(rider_id uuid, rider_name text)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT id, name
  FROM public.riders
  WHERE claim_token = p_claim_token AND is_active = true;
$$;
GRANT EXECUTE ON FUNCTION public.get_rider_identity(text) TO anon, authenticated;

-- ============================================================
-- RPC 2 — minimal job info for the rider (need-to-know only).
-- Deliberately excludes pricing/payment internals.
-- ============================================================
-- DROP first: adding columns changes the return type (CREATE OR REPLACE can't).
DROP FUNCTION IF EXISTS public.get_rider_job(text);
CREATE FUNCTION public.get_rider_job(p_accept_token text)
RETURNS TABLE(
  order_no         text,
  customer_name    text,
  customer_phone   text,
  delivery_address text,
  dropoff_label    text,
  distance_km      numeric,
  rider_fee        numeric,
  status           text,
  accepted_rider   text,
  assigned_at      timestamptz,
  accepted_at      timestamptz,
  picked_up_at     timestamptz,
  delivered_at     timestamptz,
  note             text,
  items            jsonb          -- [{name, qty}, …] from the linked order
)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT j.order_no, j.customer_name, j.customer_phone,
         j.delivery_address, j.dropoff_label, j.distance_km,
         j.rider_fee, j.status,
         r.name, j.assigned_at, j.accepted_at, j.picked_up_at, j.delivered_at, j.note,
         (SELECT jsonb_agg(jsonb_build_object('name', oi.menu_name, 'qty', oi.qty) ORDER BY oi.created_at)
            FROM public.order_items oi WHERE oi.order_id = j.order_id) AS items
  FROM public.rider_jobs j
  LEFT JOIN public.riders r ON r.id = j.rider_id
  WHERE j.accept_token = p_accept_token;
$$;
GRANT EXECUTE ON FUNCTION public.get_rider_job(text) TO anon, authenticated;

-- ============================================================
-- RPC 3 — atomic claim. Only a registered active rider may claim,
-- and only if the job is still OPEN. First writer wins.
-- ============================================================
CREATE OR REPLACE FUNCTION public.claim_rider_job(p_accept_token text, p_claim_token text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rider   public.riders%rowtype;
  v_job     public.rider_jobs%rowtype;
  v_updated int;
BEGIN
  SELECT * INTO v_rider FROM public.riders
    WHERE claim_token = p_claim_token AND is_active = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_registered');
  END IF;

  SELECT * INTO v_job FROM public.rider_jobs WHERE accept_token = p_accept_token;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'job_not_found');
  END IF;

  -- Atomic: succeeds only while status is still 'open'. A concurrent
  -- second claim serializes on the row and then sees status <> 'open'.
  UPDATE public.rider_jobs
     SET rider_id = v_rider.id, status = 'accepted', accepted_at = now()
   WHERE accept_token = p_accept_token AND status = 'open';
  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    SELECT * INTO v_job FROM public.rider_jobs WHERE accept_token = p_accept_token;
    RETURN jsonb_build_object(
      'ok', false,
      'error', CASE WHEN v_job.rider_id = v_rider.id THEN 'already_yours' ELSE 'already_taken' END,
      'status', v_job.status,
      'taken_by', (SELECT name FROM public.riders WHERE id = v_job.rider_id)
    );
  END IF;

  RETURN jsonb_build_object('ok', true, 'rider_name', v_rider.name);
END;
$$;
GRANT EXECUTE ON FUNCTION public.claim_rider_job(text, text) TO anon, authenticated;

-- ============================================================
-- RPC 4 — status update by the rider who owns the job.
-- Allowed transitions: picked_up, delivered.
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_rider_job_status(
  p_accept_token text, p_claim_token text, p_status text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rider public.riders%rowtype;
  v_job   public.rider_jobs%rowtype;
BEGIN
  IF p_status NOT IN ('picked_up','delivered') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'bad_status');
  END IF;

  SELECT * INTO v_rider FROM public.riders
    WHERE claim_token = p_claim_token AND is_active = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_registered');
  END IF;

  SELECT * INTO v_job FROM public.rider_jobs WHERE accept_token = p_accept_token;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'job_not_found');
  END IF;

  -- Only the rider who accepted the job may advance it.
  IF v_job.rider_id IS DISTINCT FROM v_rider.id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_your_job');
  END IF;

  UPDATE public.rider_jobs
     SET status       = p_status,
         picked_up_at = CASE WHEN p_status = 'picked_up' THEN COALESCE(picked_up_at, now()) ELSE picked_up_at END,
         delivered_at = CASE WHEN p_status = 'delivered' THEN now() ELSE delivered_at END
   WHERE accept_token = p_accept_token;

  RETURN jsonb_build_object('ok', true, 'status', p_status);
END;
$$;
GRANT EXECUTE ON FUNCTION public.update_rider_job_status(text, text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- ROLLBACK (uncomment to undo):
--   DROP FUNCTION IF EXISTS public.update_rider_job_status(text,text,text);
--   DROP FUNCTION IF EXISTS public.claim_rider_job(text,text);
--   DROP FUNCTION IF EXISTS public.get_rider_job(text);
--   DROP FUNCTION IF EXISTS public.get_rider_identity(text);
--   ALTER TABLE public.rider_jobs DROP CONSTRAINT IF EXISTS rider_jobs_status_check;
--   ALTER TABLE public.rider_jobs ADD CONSTRAINT rider_jobs_status_check
--     CHECK (status IN ('assigned','accepted','picked_up','delivered','cancelled'));
--   ALTER TABLE public.rider_jobs DROP COLUMN IF EXISTS picked_up_at;
--   DROP INDEX IF EXISTS public.riders_claim_token_idx;
--   ALTER TABLE public.riders DROP COLUMN IF EXISTS claim_token;
-- ------------------------------------------------------------
