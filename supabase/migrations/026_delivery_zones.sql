-- ============================================================
-- Glongnom POS — Migration 026: Address-based delivery zones
-- ============================================================
-- WHY THIS EXISTS
-- Delivery used to be a single flat fee (shops.delivery_fee) applied to
-- every order. We now charge by the customer's dorm/condo, using the
-- rate card in glongnom-dorms.csv.
--
-- Because ALL pricing is authoritative in the database (see migration
-- 021 create_order), the rate card must live here too — not just in the
-- browser. This table is the single source of truth that both the
-- customer app (for the dropdown + live total) and the create_order RPC
-- (for the real charge) read from.
--
-- Run this in: Supabase Dashboard → SQL Editor → New Query.
-- Additive and safe: creates one table + seeds it. Run 027 next.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.delivery_zones (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name         text NOT NULL UNIQUE,          -- dorm/condo name, matches CSV
  customer_pay numeric(10,2) NOT NULL,        -- fee the customer pays (THB)
  is_active    boolean NOT NULL DEFAULT true,  -- hide without deleting
  sort_order   int NOT NULL DEFAULT 0,         -- display order in dropdown
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- ── RLS: public can read (for the dropdown), staff-only writes ──
ALTER TABLE public.delivery_zones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "delivery_zones_public_read" ON public.delivery_zones;
CREATE POLICY "delivery_zones_public_read"
  ON public.delivery_zones FOR SELECT USING (true);

-- current_user_role() is the shared helper defined in migration 001;
-- admin config tables (categories, menus, shops…) all gate on admin/manager.
DROP POLICY IF EXISTS "delivery_zones_admin_write" ON public.delivery_zones;
CREATE POLICY "delivery_zones_admin_write"
  ON public.delivery_zones FOR ALL
  USING      (current_user_role() IN ('admin','manager'))
  WITH CHECK (current_user_role() IN ('admin','manager'));

-- ── Seed from glongnom-dorms.csv (name, customer_pay) ──
-- Re-runnable: ON CONFLICT keeps the fee in sync without duplicating rows.
INSERT INTO public.delivery_zones (name, customer_pay, sort_order) VALUES
  ('Dcondo campus (phase1)',   10,  1),
  ('Dcondo campus (phase2)',   10,  2),
  ('Dcondo dome (phase3)',     10,  3),
  ('Dcondo hideaway (phase4)', 10,  4),
  ('Dcondo shine (phase5)',    10,  5),
  ('18-22 residence',          10,  6),
  ('Haus private',             10,  7),
  ('ยูบ้านสุขสบาย',            10,  8),
  ('Modiz Avantgarde',         10,  9),
  ('Kave AVA',                 10, 10),
  ('Kave TU',                  10, 11),
  ('Kave Wonderland',          10, 12),
  ('เดอะชาญ',                  10, 13),
  ('ซานต้า',                   10, 14),
  ('Hiso Place',               10, 15),
  ('The chic',                 15, 16),
  ('Loft Loft',                15, 17),
  ('Golf view',                15, 18),
  ('Accompark',                15, 19),
  ('TU DOME',                  15, 20),
  ('Keystone',                 15, 21),
  ('Jpark',                    20, 22),
  ('บราวนี่',                  20, 23),
  ('Zoom place',               20, 24),
  ('The campus',               20, 25),
  ('ทรงพิเชษฐ์',               20, 26),
  ('บันยันทรี',                20, 27),
  ('City park',                20, 28),
  ('Inter park',               20, 29),
  ('Modiz Launch',             20, 30),
  ('TwinTown',                 20, 31),
  ('U-house',                  20, 32),
  ('U-plus',                   20, 33),
  ('Skyview',                  20, 34),
  ('Tudio',                    20, 35),
  ('วนารินทร์',                20, 36),
  ('Place of eight',           20, 37),
  ('The wisdom',               20, 38),
  ('Cosy Cozy',                20, 39),
  ('Common TU',                20, 40),
  ('2B Casa',                  20, 41),
  ('Terra residence',          20, 42),
  ('คณะ/อาคารในมธ.',           20, 43),
  ('คณะ/อาคารกลุ่มแพทย์',      20, 44),
  ('หอในมธ. ABCEFM',           20, 45)
ON CONFLICT (name) DO UPDATE
  SET customer_pay = EXCLUDED.customer_pay,
      sort_order   = EXCLUDED.sort_order,
      is_active    = true;
