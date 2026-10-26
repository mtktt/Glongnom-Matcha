-- New "Merchandise" category and its first product: Glongnom Clicker (79 THB).
-- The customer page matches categories by lower-cased name, so the tab in
-- index.html uses data-cat="merchandise". Both inserts are guarded so
-- re-running is safe. No option templates or BOM rows — it's a plain item.
INSERT INTO public.categories (shop_id, name, name_th, sort_order, is_active)
SELECT s.id, 'Merchandise', 'ของที่ระลึก', 5, true
FROM public.shops s
WHERE s.branch_code = 'GLN-01'
  AND NOT EXISTS (
    SELECT 1 FROM public.categories c
    WHERE c.shop_id = s.id AND c.name = 'Merchandise'
  );

INSERT INTO public.menus
  (shop_id, category_id, name, name_th, description, description_th,
   base_price, image_url, is_active, sort_order, is_preorder)
SELECT s.id, c.id, 'Glongnom Clicker', 'Glongnom Clicker',
       'Limited edition • blue switch', 'ลิมิเต็ดอิดิชั่น • สวิตช์สีฟ้า',
       79, 'assets/clicker.jpg', true, 1, false
FROM public.shops s
JOIN public.categories c ON c.shop_id = s.id AND c.name = 'Merchandise'
WHERE s.branch_code = 'GLN-01'
  AND NOT EXISTS (
    SELECT 1 FROM public.menus m
    WHERE m.shop_id = s.id AND m.name = 'Glongnom Clicker'
  );
