-- Category rework: "Rice" becomes "Salmon", and a new "Sourdough" category is added.
-- Renaming in place keeps the existing category_id, so menu items already filed
-- under Rice stay attached (re-file them from the admin Menu page if needed).
UPDATE public.categories
SET name    = 'Salmon',
    name_th = 'แซลมอน'
WHERE name = 'Rice'
  AND shop_id IN (SELECT id FROM public.shops WHERE branch_code = 'GLN-01');

-- New category, ordered right after Salmon. Guarded so re-running is safe.
INSERT INTO public.categories (shop_id, name, name_th, sort_order, is_active)
SELECT s.id, 'Sourdough', 'ซาวร์โดว์', 4, true
FROM public.shops s
WHERE s.branch_code = 'GLN-01'
  AND NOT EXISTS (
    SELECT 1 FROM public.categories c
    WHERE c.shop_id = s.id AND c.name = 'Sourdough'
  );
