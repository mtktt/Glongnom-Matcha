-- Keep the live menu image paths aligned with the files shipped in /assets.
-- Browser-facing URLs must use forward slashes, including when edited on Windows.
UPDATE public.menus
SET image_url = CASE name
  WHEN 'Grilled Beef Rice Bowl'
    THEN 'assets/grilled-beef-rice.jpg'
  WHEN 'Combo Set (Beef rice x Coconut matcha)'
    THEN 'assets/beef-rice-w-coconut.jpg'
  WHEN 'Combo set (Beef rice x Strawberry matcha)'
    THEN 'assets/beef-rice-w-strawberry.jpg'
END
WHERE name IN (
  'Grilled Beef Rice Bowl',
  'Combo Set (Beef rice x Coconut matcha)',
  'Combo set (Beef rice x Strawberry matcha)'
);
