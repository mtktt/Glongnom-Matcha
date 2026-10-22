-- ============================================================
-- Glongnom POS — Migration 035: Tier follows lifetime spend
-- ============================================================
-- WHY
-- Until now customers.tier was derived from loyalty_points (migrations 006
-- and 009): bronze 0-299, silver 300-999, gold 1000+.
--
-- That breaks as soon as points become spendable. Points are a CURRENCY —
-- redeeming a reward deducts them — so a Gold member who cashes in 500
-- points would silently be demoted to Silver. Status must not be refundable.
--
-- Tier now follows LIFETIME SPEND, which only ever grows:
--
--     Bronze     0 - 1,499 baht
--     Silver 1,500 - 2,999 baht
--     Gold   3,000+       baht
--
-- Points keep working exactly as before (floor(total / 10) per order) and
-- are now purely the reward currency.
--
-- Run AFTER 034.
-- ============================================================

-- ── 1. Cache the lifetime spend on the customer row ──
ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS lifetime_spend numeric(12,2) DEFAULT 0;

-- ── 2. The single place the thresholds live ──
-- Keep in sync with RULES.tiers in membership.html.
CREATE OR REPLACE FUNCTION public.tier_for_spend(p_spend numeric)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN COALESCE(p_spend, 0) >= 3000 THEN 'gold'
    WHEN COALESCE(p_spend, 0) >= 1500 THEN 'silver'
    ELSE 'bronze'
  END;
$$;

-- ── 3. Recompute one customer's spend + tier from their orders ──
-- Matches on customer_id OR the phone snapshot, same as get_membership, so
-- pre-Phase-3 orders with a null customer_id still count toward the tier.
CREATE OR REPLACE FUNCTION public.recalc_customer_tier(p_customer_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_digits text;
  v_spend  numeric;
BEGIN
  IF p_customer_id IS NULL THEN RETURN; END IF;

  SELECT regexp_replace(COALESCE(phone, ''), '\D', '', 'g')
    INTO v_digits
    FROM customers WHERE id = p_customer_id;

  IF NOT FOUND THEN RETURN; END IF;

  SELECT COALESCE(SUM(total_price), 0)
    INTO v_spend
    FROM orders
   WHERE status <> 'cancelled'
     AND (customer_id = p_customer_id
          OR (v_digits <> '' AND regexp_replace(COALESCE(customer_phone, ''), '\D', '', 'g') = v_digits));

  UPDATE customers
     SET lifetime_spend = v_spend,
         tier           = tier_for_spend(v_spend)
   WHERE id = p_customer_id;
END;
$$;

-- ── 4. Accrual: points unchanged, tier now recalculated from spend ──
-- The tier recalc sits OUTSIDE the idempotency guard on purpose. A repeat
-- call (or a call for an order too small to earn a point) must still refresh
-- the tier, otherwise spend and tier drift apart.
CREATE OR REPLACE FUNCTION public.accrue_loyalty_for_order(p_order_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_customer_id uuid;
  v_total       numeric;
  v_points      integer;
BEGIN
  SELECT customer_id, total_price
    INTO v_customer_id, v_total
    FROM orders
   WHERE id = p_order_id;

  IF v_customer_id IS NULL THEN RETURN; END IF;

  -- Points — idempotent per order, unchanged from migration 009.
  IF NOT EXISTS (
    SELECT 1 FROM loyalty_ledger WHERE order_id = p_order_id AND reason = 'order'
  ) THEN
    v_points := FLOOR(v_total / 10)::integer;
    IF v_points > 0 THEN
      INSERT INTO loyalty_ledger (customer_id, order_id, delta, reason)
      VALUES (v_customer_id, p_order_id, v_points, 'order');

      UPDATE customers
         SET loyalty_points = loyalty_points + v_points
       WHERE id = v_customer_id;
    END IF;
  END IF;

  PERFORM recalc_customer_tier(v_customer_id);
END;
$$;

-- ── 5. Manual point adjustment no longer touches tier ──
-- This is the whole point of the migration: burning points on a reward
-- must leave the member's status alone.
CREATE OR REPLACE FUNCTION public.adjust_loyalty_points(
  p_customer_id uuid,
  p_delta       integer,
  p_reason      text,
  p_note        text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  INSERT INTO loyalty_ledger (customer_id, delta, reason, note)
  VALUES (p_customer_id, p_delta, p_reason, p_note);

  UPDATE customers
     SET loyalty_points = GREATEST(0, loyalty_points + p_delta)
   WHERE id = p_customer_id;
  -- tier deliberately NOT recalculated here.
END;
$$;

-- ── 6. Backfill every existing customer ──
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT id FROM customers LOOP
    PERFORM recalc_customer_tier(r.id);
  END LOOP;
END $$;

-- ── 7. get_membership now reports the spend-based tier ──
-- Supersedes the version in migration 034. Only the 'tier' value and the
-- added lifetime_spend field differ; everything else is identical.
CREATE OR REPLACE FUNCTION public.get_membership(p_phone text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_digits       text;
  v_customer     customers%ROWTYPE;
  v_order_ids    uuid[];
  v_total_orders integer := 0;
  v_total_spent  numeric := 0;
  v_orders       jsonb;
  v_ledger       jsonb;
BEGIN
  v_digits := regexp_replace(COALESCE(p_phone, ''), '\D', '', 'g');

  IF v_digits !~ '^0\d{9}$' THEN
    RETURN jsonb_build_object('found', false, 'reason', 'INVALID_PHONE');
  END IF;

  SELECT * INTO v_customer
    FROM customers
   WHERE regexp_replace(COALESCE(phone, ''), '\D', '', 'g') = v_digits
   ORDER BY created_at
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false, 'reason', 'NOT_FOUND');
  END IF;

  SELECT array_agg(id) INTO v_order_ids
    FROM orders
   WHERE customer_id = v_customer.id
      OR regexp_replace(COALESCE(customer_phone, ''), '\D', '', 'g') = v_digits;

  v_order_ids := COALESCE(v_order_ids, ARRAY[]::uuid[]);

  SELECT COUNT(*), COALESCE(SUM(total_price), 0)
    INTO v_total_orders, v_total_spent
    FROM orders
   WHERE id = ANY(v_order_ids)
     AND status <> 'cancelled';

  SELECT COALESCE(jsonb_agg(s.j ORDER BY s.ord DESC), '[]'::jsonb)
    INTO v_orders
    FROM (
      SELECT o.created_at AS ord,
             jsonb_build_object(
               'order_no',        o.order_no,
               'created_at',      o.created_at,
               'status',          o.status,
               'payment_status',  o.payment_status,
               'subtotal',        o.subtotal,
               'discount_amount', o.discount_amount,
               'delivery_fee',    o.delivery_fee,
               'total_price',     o.total_price,
               'points_earned',   COALESCE((
                 SELECT SUM(l.delta) FROM loyalty_ledger l WHERE l.order_id = o.id
               ), 0),
               'items',           COALESCE((
                 SELECT jsonb_agg(jsonb_build_object('name', oi.menu_name, 'qty', oi.qty)
                                  ORDER BY oi.created_at)
                   FROM order_items oi WHERE oi.order_id = o.id
               ), '[]'::jsonb)
             ) AS j
        FROM orders o
       WHERE o.id = ANY(v_order_ids)
       ORDER BY o.created_at DESC
       LIMIT 50
    ) s;

  SELECT COALESCE(jsonb_agg(
           jsonb_build_object(
             'created_at', l.created_at,
             'delta',      l.delta,
             'reason',     l.reason,
             'note',       l.note,
             'order_no',   o.order_no
           ) ORDER BY l.created_at DESC), '[]'::jsonb)
    INTO v_ledger
    FROM (
      SELECT * FROM loyalty_ledger
       WHERE customer_id = v_customer.id
       ORDER BY created_at DESC
       LIMIT 50
    ) l
    LEFT JOIN orders o ON o.id = l.order_id;

  RETURN jsonb_build_object(
    'found', true,
    'customer', jsonb_build_object(
      'name',         COALESCE(NULLIF(btrim(v_customer.name), ''), 'Member'),
      'phone',        v_customer.phone,
      'member_since', v_customer.created_at,
      -- Derived from the same total the page displays, so the card badge and
      -- the spend tile can never disagree.
      'tier',         tier_for_spend(v_total_spent),
      'points',       COALESCE(v_customer.loyalty_points, 0)
    ),
    'summary', jsonb_build_object(
      'total_orders',   v_total_orders,
      'total_spent',    v_total_spent,
      'lifetime_spend', COALESCE(v_customer.lifetime_spend, 0)
    ),
    'orders', v_orders,
    'ledger', v_ledger
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_membership(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_membership(text) TO anon, authenticated;
