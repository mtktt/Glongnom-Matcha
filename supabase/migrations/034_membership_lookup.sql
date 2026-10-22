-- ============================================================
-- Glongnom POS — Migration 034: Public membership lookup
-- ============================================================
-- WHY
-- membership.html is a PUBLIC page (anon key). Migration 022 removed the
-- permissive `using (true)` SELECT policies from orders / order_items, and
-- customers + loyalty_ledger only allow reads for `auth.uid() IS NOT NULL`.
-- So anon cannot — and must not — query those tables directly.
--
-- This adds ONE narrow SECURITY DEFINER function that takes a phone number
-- and returns exactly that customer's card data, order history and loyalty
-- ledger. Nothing else in those tables is reachable. Same pattern as
-- create_order() from migration 021.
--
-- ⚠️ PRIVACY NOTE
-- The phone number is the only credential. Anyone who knows a customer's
-- phone number can see that customer's name, points and order history.
-- That is acceptable for a small shop loyalty card, but it does mean the
-- endpoint is enumerable. If that ever matters, gate it behind an OTP
-- (Supabase phone auth) and switch the lookup to auth.uid().
-- ============================================================

-- ── Speed up the normalised-phone lookups ──
CREATE INDEX IF NOT EXISTS customers_phone_digits_idx
  ON public.customers ((regexp_replace(COALESCE(phone, ''), '\D', '', 'g')));

CREATE INDEX IF NOT EXISTS orders_customer_phone_digits_idx
  ON public.orders ((regexp_replace(COALESCE(customer_phone, ''), '\D', '', 'g')));

-- ── The lookup ──
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
  -- 1. Normalise + validate. Same rule as the ordering app: 0XXXXXXXXX.
  v_digits := regexp_replace(COALESCE(p_phone, ''), '\D', '', 'g');

  IF v_digits !~ '^0\d{9}$' THEN
    RETURN jsonb_build_object('found', false, 'reason', 'INVALID_PHONE');
  END IF;

  -- 2. Find the member. Compare on digits so stored values with spaces
  --    or dashes still match.
  SELECT * INTO v_customer
    FROM customers
   WHERE regexp_replace(COALESCE(phone, ''), '\D', '', 'g') = v_digits
   ORDER BY created_at
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false, 'reason', 'NOT_FOUND');
  END IF;

  -- 3. Collect their orders. Match on customer_id OR the phone snapshot —
  --    orders placed before the customer_id fix (Phase 3 bug #1) have a
  --    null customer_id but still carry customer_phone.
  SELECT array_agg(id) INTO v_order_ids
    FROM orders
   WHERE customer_id = v_customer.id
      OR regexp_replace(COALESCE(customer_phone, ''), '\D', '', 'g') = v_digits;

  v_order_ids := COALESCE(v_order_ids, ARRAY[]::uuid[]);

  -- 4. Totals exclude cancelled orders.
  SELECT COUNT(*), COALESCE(SUM(total_price), 0)
    INTO v_total_orders, v_total_spent
    FROM orders
   WHERE id = ANY(v_order_ids)
     AND status <> 'cancelled';

  -- 5. Recent order history (newest first, capped).
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

  -- 6. Loyalty ledger (newest first, capped).
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
      'tier',         COALESCE(v_customer.tier, 'bronze'),
      'points',       COALESCE(v_customer.loyalty_points, 0)
    ),
    'summary', jsonb_build_object(
      'total_orders', v_total_orders,
      'total_spent',  v_total_spent
    ),
    'orders', v_orders,
    'ledger', v_ledger
  );
END;
$$;

-- Only the narrow function is exposed — never the underlying tables.
REVOKE ALL ON FUNCTION public.get_membership(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_membership(text) TO anon, authenticated;
