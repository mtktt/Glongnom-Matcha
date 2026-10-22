-- ============================================================
-- 038 — visual_key: drives the live matcha-glass preview on index.html
--
-- Two levels, because the drink's flavour lives on the MENU, while the
-- customer's tweaks live on the CHOICES:
--
--   menus.visual_key                    the glass "recipe", space-separated tokens
--       'matcha'                        → matcha layer on top
--       body:  milk | water | coconut | earlgrey | taro
--       sauce: strawberry | blueberry | caramel | honey | biscoff | oreo
--       e.g. 'matcha milk strawberry'   NULL = no glass, show the menu photo
--
--   option_template_choices.visual_key  what a picked choice changes
--       grade_original | grade_yame
--       milk_oat | milk_cow
--       sweet_0 | sweet_50 | sweet_100 | sweet_150
--       ice_in | ice_side | ice_none
--       matcha_in | matcha_side
--       top_konjac
--
-- Purely cosmetic: nothing in create_order / pricing / BOM reads these.
-- Backfills only rows that are still NULL, so re-running never overwrites
-- keys set later from the admin pages. Existing RLS policies already cover
-- the new columns (public read, admin/manager write).
-- ============================================================

alter table menus                   add column if not exists visual_key text;
alter table option_template_choices add column if not exists visual_key text;

-- ---- Choices: matched by template + choice name ----
update option_template_choices c
set visual_key = v.key
from option_templates t,
     (values
       ('เกรดมัทฉะ',  'Original',        'grade_original'),
       ('เกรดมัทฉะ',  'Yame',            'grade_yame'),
       ('นม',         'โอ๊ต',             'milk_oat'),
       ('นม',         'วัว',              'milk_cow'),
       ('ความหวาน',   '^0%',             'sweet_0'),
       ('ความหวาน',   '^50%',            'sweet_50'),
       ('ความหวาน',   '^100%',           'sweet_100'),
       ('ความหวาน',   '^150%',           'sweet_150'),
       ('น้ำแข็ง',     '^แยกน้ำแข็ง',      'ice_side'),
       ('น้ำแข็ง',     '^ใส่น้ำแข็ง',       'ice_in'),
       ('น้ำแข็ง',     '^ไม่รับน้ำแข็ง',     'ice_none'),
       ('แยกมัทฉะ',   '^แยกมัทฉะ',        'matcha_side'),
       ('แยกมัทฉะ',   '^เทมัทฉะ',         'matcha_in'),
       ('ท้อปปิ้ง',    'บุก',              'top_konjac')
     ) as v(tpl_th, pattern, key)
where c.template_id = t.id
  and t.name_th = v.tpl_th
  and (coalesce(c.name_th, '') ~ v.pattern or c.name ~ v.pattern)
  and c.visual_key is null;

-- ---- Menus: matched by English name ----
update menus m
set visual_key = v.key
from (values
       ('Pure Matcha',                              'matcha water'),
       ('Coconut Matcha',                           'matcha coconut'),
       ('Honey Matcha',                             'matcha water honey'),
       ('Matcha Latte',                             'matcha milk'),
       ('Matcha Earl Grey Latte',                   'matcha earlgrey'),
       ('Biscoff Matcha Latte',                     'matcha milk biscoff'),
       ('Taro Matcha Latte',                        'matcha taro'),
       ('Strawberry Matcha Latte',                  'matcha milk strawberry'),
       ('Blueberry Matcha Latte',                   'matcha milk blueberry'),
       ('Oreo Matcha Latte',                        'matcha milk oreo'),
       ('Honey Matcha Latte',                       'matcha milk honey'),
       ('Caramel Matcha Latte',                     'matcha milk caramel'),
       ('Oat Milk Honey',                           'milk honey'),
       ('Oat Milk Oreo',                            'milk oreo'),
       ('Oat Milk Biscoff',                         'milk biscoff'),
       ('Oat Milk Caramel',                         'milk caramel'),
       ('Blueberry Oat Milk',                       'milk blueberry'),
       ('Strawberry Oat Milk',                      'milk strawberry'),
       ('Earl Grey Milk Tea',                       'earlgrey'),
       ('Combo Set (Beef rice x Coconut matcha)',   'matcha coconut'),
       ('Combo set (Beef rice x Strawberry matcha)','matcha milk strawberry')
     ) as v(name, key)
where m.name = v.name
  and m.visual_key is null;

-- ---- Check: anything a drink template still lacks a key for ----
-- select t.name_th, c.name_th, c.visual_key
-- from option_template_choices c join option_templates t on t.id = c.template_id
-- where t.name_th in ('เกรดมัทฉะ','นม','ความหวาน','น้ำแข็ง','แยกมัทฉะ','ท้อปปิ้ง')
-- order by t.sort_order, c.sort_order;
