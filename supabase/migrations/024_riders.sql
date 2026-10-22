-- ============================================================
-- Glongnom POS — Migration 024: Riders + Job History (Phase 1)
-- ============================================================
-- Adds an in-house delivery rider directory and an automatic
-- job-acceptance log, backing the new admin page /admin/rider.html.
--
--   riders      — name + contact of each rider you dispatch to.
--   rider_jobs  — one row per delivery handed to a rider. Records
--                 order snapshot, drop-off location, the fee paid to
--                 the rider, and timestamps (assigned / accepted /
--                 delivered). `accept_token` is generated now so a
--                 future public "tap to accept" link (Phase 2) can
--                 stamp accepted_at without a rider login.
--
-- Security mirrors migration 006 (loyalty_ledger):
--   read  → any authenticated user
--   write → staff only (admin / manager / cashier)
--
-- Run in: Supabase Dashboard → SQL Editor → New Query.
-- ============================================================

-- ── riders ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.riders (
  id          uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  name        text        NOT NULL,
  phone       text,
  line_id     text,
  vehicle     text,                       -- e.g. motorcycle plate / model
  is_active   boolean     NOT NULL DEFAULT true,
  note        text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS riders_active_idx ON public.riders(is_active);

-- ── rider_jobs ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.rider_jobs (
  id               uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  rider_id         uuid        REFERENCES public.riders(id) ON DELETE SET NULL,
  order_id         uuid        REFERENCES public.orders(id) ON DELETE SET NULL,

  -- order snapshot (kept even if the order/rider is later deleted)
  order_no         text,
  customer_name    text,
  customer_phone   text,
  delivery_address text,                  -- "สถานที่ส่ง"
  dropoff_label    text,                  -- e.g. dorm/condo name
  distance_km      numeric(6,2),

  rider_fee        numeric(10,2) NOT NULL DEFAULT 0,   -- ค่าส่งที่จ่ายให้ไรเดอร์

  status           text NOT NULL DEFAULT 'assigned'
                     CHECK (status IN ('assigned','accepted','picked_up','delivered','cancelled')),

  -- timestamps
  assigned_at      timestamptz NOT NULL DEFAULT now(),
  accepted_at      timestamptz,           -- เวลาที่ไรเดอร์กดรับงาน
  delivered_at     timestamptz,

  -- Phase 2: public "tap to accept" link identifier (generated now)
  accept_token     text UNIQUE DEFAULT md5(random()::text || clock_timestamp()::text),

  note             text,
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS rider_jobs_rider_idx  ON public.rider_jobs(rider_id);
CREATE INDEX IF NOT EXISTS rider_jobs_order_idx  ON public.rider_jobs(order_id);
CREATE INDEX IF NOT EXISTS rider_jobs_status_idx ON public.rider_jobs(status);
CREATE INDEX IF NOT EXISTS rider_jobs_assigned_idx ON public.rider_jobs(assigned_at DESC);

-- ── RLS ─────────────────────────────────────────────────────
ALTER TABLE public.riders     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rider_jobs ENABLE ROW LEVEL SECURITY;

-- read: any logged-in staff/kitchen user
CREATE POLICY "riders_read" ON public.riders FOR SELECT
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "rider_jobs_read" ON public.rider_jobs FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- write: staff only (admin / manager / cashier)
CREATE POLICY "riders_write" ON public.riders FOR ALL
  USING (EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE id = auth.uid() AND role IN ('admin','manager','cashier')
  ));
CREATE POLICY "rider_jobs_write" ON public.rider_jobs FOR ALL
  USING (EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE id = auth.uid() AND role IN ('admin','manager','cashier')
  ));

-- ------------------------------------------------------------
-- ROLLBACK (uncomment to undo):
--   DROP TABLE IF EXISTS public.rider_jobs;
--   DROP TABLE IF EXISTS public.riders;
-- ------------------------------------------------------------
