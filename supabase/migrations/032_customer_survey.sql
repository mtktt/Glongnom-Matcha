-- Customer survey and public review wall.
CREATE TABLE IF NOT EXISTS public.survey_responses (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_wish       text CHECK (char_length(menu_wish) BETWEEN 1 AND 500),
  delicious_review text CHECK (char_length(delicious_review) BETWEEN 1 AND 1000),
  improvement     text CHECK (char_length(improvement) BETWEEN 1 AND 1000),
  display_name    text CHECK (char_length(display_name) <= 80),
  show_menu_wish  boolean NOT NULL DEFAULT false,
  show_review     boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Safe to re-run when upgrading an existing survey table.
ALTER TABLE public.survey_responses
  ALTER COLUMN menu_wish DROP NOT NULL,
  ALTER COLUMN delicious_review DROP NOT NULL,
  ALTER COLUMN improvement DROP NOT NULL;

DO $$ BEGIN
  ALTER TABLE public.survey_responses ADD CONSTRAINT survey_has_an_answer
    CHECK (num_nonnulls(menu_wish, delicious_review, improvement) >= 1);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS survey_responses_created_idx
  ON public.survey_responses (created_at DESC);

ALTER TABLE public.survey_responses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "survey_public_insert" ON public.survey_responses
  FOR INSERT TO anon, authenticated
  WITH CHECK (
    show_menu_wish = false
    AND show_review = false
  );

-- Anonymous visitors can only read content explicitly approved by the shop.
-- Improvement feedback is still present in the row, but is never rendered publicly.
CREATE POLICY "survey_public_approved_read" ON public.survey_responses
  FOR SELECT TO anon
  USING (show_menu_wish = true OR show_review = true);

CREATE POLICY "survey_staff_read" ON public.survey_responses
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid() AND role IN ('admin', 'manager')
    )
  );

CREATE POLICY "survey_staff_update" ON public.survey_responses
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid() AND role IN ('admin', 'manager')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid() AND role IN ('admin', 'manager')
    )
  );

GRANT INSERT ON public.survey_responses TO anon;
REVOKE SELECT ON public.survey_responses FROM anon;
GRANT SELECT (
  id, menu_wish, delicious_review, display_name,
  show_menu_wish, show_review, created_at
) ON public.survey_responses TO anon;
GRANT INSERT, SELECT, UPDATE ON public.survey_responses TO authenticated;
