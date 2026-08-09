-- Allow customers to answer any one or more survey questions.
ALTER TABLE public.survey_responses
  ALTER COLUMN menu_wish DROP NOT NULL,
  ALTER COLUMN delicious_review DROP NOT NULL,
  ALTER COLUMN improvement DROP NOT NULL;

DO $$ BEGIN
  ALTER TABLE public.survey_responses ADD CONSTRAINT survey_has_an_answer
    CHECK (num_nonnulls(menu_wish, delicious_review, improvement) >= 1);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
