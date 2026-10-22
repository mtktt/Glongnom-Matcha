-- ============================================================
-- Glongnom POS — Migration 027: Delivery fee by dorm in create_order
-- ============================================================
-- WHY THIS EXISTS
-- Migration 021 charged a single flat fee (shops.delivery_fee) on every
-- order. Migration 026 introduced per-dorm rates (delivery_zones). This
-- replaces the flat lookup inside create_order with a zone lookup keyed
-- on the customer's chosen dorm.
--
-- The dorm is now a REQUIRED, validated field: the RPC rejects any dorm
-- that isn't an active row in delivery_zones. That is what stops a
-- hand-crafted browser payload from claiming a fake/cheaper zone — the
-- same defense-in-depth already used for menu items and option choices.
--
-- PAYLOAD SHAPE (jsonb) — note the new customer.dorm:
--   {
--     "customer": { "name": "...", "phone": "0xxxxxxxxx",
--                   "dorm": "Kave TU", "address": "ตึก A ห้อง 302" },
--     "items": [ { "menu_id": "uuid", "qty": 2, "note": "less ice",
--                  "choice_ids": ["uuid"] } ]
--   }
--
-- Run this in: Supabase Dashboard → SQL Editor → New Query.
-- Run AFTER 026 (it depends on the delivery_zones table).
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_order(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  -- shop / customer
  v_shop            shops%ROWTYPE;
  v_today           date := (now() AT TIME ZONE 'Asia/Bangkok')::date;
  v_name            text;
  v_phone           text;
  v_address         text;
  v_dorm            text;
  v_delivery_fee    numeric;          -- looked up from delivery_zones
  v_customer_id     uuid;

  -- order header
  v_order_id        uuid;
  v_order_no        text;

  -- per-item working vars
  v_item            jsonb;
  v_menu_id         uuid;
  v_qty             int;
  v_note            text;
  v_base_price      numeric;
  v_menu_name       text;
  v_menu_active     boolean;
  v_eff_base        numeric;
  v_opt_sum         numeric;
  v_unit_price      numeric;
  v_order_item_id   uuid;

  -- option working vars
  v_choice_id       uuid;
  v_add_price       numeric;
  v_group_name      text;
  v_choice_name     text;

  -- promo working vars
  v_promo           promotions%ROWTYPE;
  v_bundle_menu_ids uuid[];
  v_bundle_sum      numeric;
  v_first_price     numeric;
  v_mid             uuid;
  v_applied_bundle  uuid := NULL;

  -- running totals
  v_subtotal        numeric := 0;
  v_item_discount   numeric := 0;
  v_bundle_discount numeric := 0;
  v_total           numeric;

  -- bookkeeping for bundle matching
  v_menu_ids_in_order uuid[] := '{}';
  v_items_out       jsonb := '[]'::jsonb;
BEGIN
  -- ── 1. Load shop + guard "shop closed" ──────────────────────
  SELECT * INTO v_shop FROM shops ORDER BY created_at LIMIT 1;
  IF v_shop.id IS NULL THEN
    RAISE EXCEPTION 'NO_SHOP_CONFIGURED';
  END IF;
  IF v_shop.is_open IS NOT TRUE THEN
    RAISE EXCEPTION 'SHOP_CLOSED';
  END IF;

  -- ── 2. Validate customer fields ─────────────────────────────
  v_name    := btrim(COALESCE(p_payload #>> '{customer,name}', ''));
  v_phone   := btrim(COALESCE(p_payload #>> '{customer,phone}', ''));
  v_address := btrim(COALESCE(p_payload #>> '{customer,address}', ''));
  v_dorm    := btrim(COALESCE(p_payload #>> '{customer,dorm}', ''));

  IF v_name = '' OR v_address = '' THEN
    RAISE EXCEPTION 'MISSING_CUSTOMER_FIELDS';
  END IF;
  -- phone must be 0 followed by 9 digits (matches client validatePhone)
  IF v_phone !~ '^0\d{9}$' THEN
    RAISE EXCEPTION 'INVALID_PHONE';
  END IF;

  -- ── 2b. Resolve delivery fee from the chosen dorm ───────────
  -- Dorm is required and must be an active delivery_zones row. This is
  -- the authoritative fee — the browser's number is never trusted.
  IF v_dorm = '' THEN
    RAISE EXCEPTION 'MISSING_DELIVERY_ZONE';
  END IF;
  SELECT customer_pay INTO v_delivery_fee
  FROM delivery_zones
  WHERE name = v_dorm AND is_active;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'INVALID_DELIVERY_ZONE: %', v_dorm;
  END IF;

  -- ── 3. Validate cart not empty ──────────────────────────────
  IF p_payload->'items' IS NULL
     OR jsonb_typeof(p_payload->'items') <> 'array'
     OR jsonb_array_length(p_payload->'items') = 0 THEN
    RAISE EXCEPTION 'EMPTY_CART';
  END IF;

  -- ── 4. Upsert customer ──────────────────────────────────────
  INSERT INTO customers (name, phone, address)
  VALUES (v_name, v_phone, v_address)
  ON CONFLICT (phone) DO UPDATE
    SET name = EXCLUDED.name, address = EXCLUDED.address
  RETURNING id INTO v_customer_id;

  -- ── 5. Create order shell (totals filled in step 8) ─────────
  INSERT INTO orders (
    shop_id, customer_id, customer_name, customer_phone, customer_address,
    order_type, status, payment_status,
    subtotal, discount_amount, delivery_fee, total_price
  ) VALUES (
    v_shop.id, v_customer_id, v_name, v_phone, v_address,
    'delivery', 'new', 'pending',
    0, 0, v_delivery_fee, 0
  )
  RETURNING id, order_no INTO v_order_id, v_order_no;

  -- ── 6. Pass 1 — price every item from authoritative sources ──
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_payload->'items')
  LOOP
    v_menu_id := (v_item->>'menu_id')::uuid;
    v_qty     := COALESCE((v_item->>'qty')::int, 0);
    v_note    := NULLIF(btrim(COALESCE(v_item->>'note', '')), '');

    IF v_qty < 1 THEN
      RAISE EXCEPTION 'INVALID_QTY';
    END IF;

    SELECT base_price, COALESCE(name_th, name), is_active
    INTO v_base_price, v_menu_name, v_menu_active
    FROM menus
    WHERE id = v_menu_id AND shop_id = v_shop.id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'INVALID_MENU_ITEM: %', v_menu_id;
    END IF;
    IF v_menu_active IS NOT TRUE THEN
      RAISE EXCEPTION 'MENU_ITEM_SOLD_OUT: %', v_menu_name;
    END IF;

    v_eff_base := v_base_price;
    SELECT * INTO v_promo
    FROM promotions p
    WHERE p.promo_type = 'item_discount'
      AND p.is_active
      AND (p.start_date IS NULL OR p.start_date <= v_today)
      AND (p.end_date   IS NULL OR p.end_date   >= v_today)
      AND EXISTS (
        SELECT 1 FROM promotion_items pi
        WHERE pi.promotion_id = p.id AND pi.menu_id = v_menu_id
      )
    ORDER BY p.created_at
    LIMIT 1;

    IF FOUND THEN
      IF v_promo.discount_type = 'percentage' THEN
        v_eff_base := GREATEST(0, round(v_base_price * (1 - v_promo.discount_value / 100)));
      ELSE
        v_eff_base := GREATEST(0, v_base_price - v_promo.discount_value);
      END IF;
    END IF;

    INSERT INTO order_items (order_id, menu_id, menu_name, qty, unit_price, note)
    VALUES (v_order_id, v_menu_id, v_menu_name, v_qty, 0, v_note)
    RETURNING id INTO v_order_item_id;

    v_opt_sum := 0;
    IF v_item->'choice_ids' IS NOT NULL
       AND jsonb_typeof(v_item->'choice_ids') = 'array' THEN
      FOR v_choice_id IN
        SELECT value::uuid FROM jsonb_array_elements_text(v_item->'choice_ids')
      LOOP
        SELECT otc.additional_price,
               COALESCE(ot.name_th, ot.name),
               COALESCE(otc.name_th, otc.name)
        INTO v_add_price, v_group_name, v_choice_name
        FROM option_template_choices otc
        JOIN option_templates ot       ON ot.id  = otc.template_id
        JOIN menu_option_templates mot ON mot.template_id = ot.id
                                       AND mot.menu_id = v_menu_id
        WHERE otc.id = v_choice_id;

        IF NOT FOUND THEN
          RAISE EXCEPTION 'INVALID_OPTION_FOR_MENU: choice % on menu %',
            v_choice_id, v_menu_name;
        END IF;

        INSERT INTO order_item_options
          (order_item_id, choice_id, group_name, choice_name, additional_price)
        VALUES
          (v_order_item_id, v_choice_id, v_group_name, v_choice_name, v_add_price);

        v_opt_sum := v_opt_sum + COALESCE(v_add_price, 0);
      END LOOP;
    END IF;

    v_unit_price := v_eff_base + v_opt_sum;
    UPDATE order_items SET unit_price = v_unit_price WHERE id = v_order_item_id;

    v_subtotal      := v_subtotal      + (v_base_price + v_opt_sum) * v_qty;
    v_item_discount := v_item_discount + (v_base_price - v_eff_base) * v_qty;

    v_menu_ids_in_order := v_menu_ids_in_order || v_menu_id;
    v_items_out := v_items_out || jsonb_build_object(
      'menu_id', v_menu_id, 'unit_price', v_unit_price
    );
  END LOOP;

  -- ── 7. Pass 2 — bundle promos ───────────────────────────────
  FOR v_promo IN
    SELECT * FROM promotions p
    WHERE p.promo_type = 'bundle'
      AND p.is_active
      AND (p.start_date IS NULL OR p.start_date <= v_today)
      AND (p.end_date   IS NULL OR p.end_date   >= v_today)
  LOOP
    SELECT array_agg(menu_id) INTO v_bundle_menu_ids
    FROM promotion_items WHERE promotion_id = v_promo.id;

    IF v_bundle_menu_ids IS NULL
       OR NOT (v_bundle_menu_ids <@ v_menu_ids_in_order) THEN
      CONTINUE;
    END IF;

    v_bundle_sum := 0;
    FOREACH v_mid IN ARRAY v_bundle_menu_ids LOOP
      SELECT (e->>'unit_price')::numeric INTO v_first_price
      FROM jsonb_array_elements(v_items_out) WITH ORDINALITY AS t(e, ord)
      WHERE (e->>'menu_id')::uuid = v_mid
      ORDER BY ord
      LIMIT 1;
      v_bundle_sum := v_bundle_sum + COALESCE(v_first_price, 0);
    END LOOP;

    v_bundle_discount := v_bundle_discount
                       + GREATEST(0, v_bundle_sum - v_promo.bundle_price);
    IF v_applied_bundle IS NULL THEN
      v_applied_bundle := v_promo.id;
    END IF;
  END LOOP;

  -- ── 8. Finalize header totals ───────────────────────────────
  v_total := v_subtotal - (v_item_discount + v_bundle_discount) + v_delivery_fee;
  IF v_total < 0 THEN v_total := 0; END IF;

  UPDATE orders SET
    subtotal        = v_subtotal,
    discount_amount = v_item_discount + v_bundle_discount,
    delivery_fee    = v_delivery_fee,
    total_price     = v_total,
    promotion_id    = v_applied_bundle
  WHERE id = v_order_id;

  -- ── 9. Return the authoritative result to the browser ───────
  RETURN jsonb_build_object(
    'order_id',        v_order_id,
    'order_no',        v_order_no,
    'subtotal',        v_subtotal,
    'discount_amount', v_item_discount + v_bundle_discount,
    'delivery_fee',    v_delivery_fee,
    'total_price',     v_total
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_order(jsonb) TO anon, authenticated;
