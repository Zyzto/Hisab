-- Rename generic expense image columns and add new storage bucket.
-- Keeps legacy receipt bucket/policies so existing URLs remain accessible.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'expenses'
      AND column_name = 'receipt_image_path'
  ) AND NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'expenses'
      AND column_name = 'image_path'
  ) THEN
    EXECUTE 'ALTER TABLE public.expenses RENAME COLUMN receipt_image_path TO image_path';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'expenses'
      AND column_name = 'receipt_image_paths'
  ) AND NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'expenses'
      AND column_name = 'image_paths'
  ) THEN
    EXECUTE 'ALTER TABLE public.expenses RENAME COLUMN receipt_image_paths TO image_paths';
  END IF;
END $$;

-- If both old/new columns exist (partial/manual states), backfill new from old.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'expenses'
      AND column_name = 'receipt_image_path'
  ) AND EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'expenses'
      AND column_name = 'image_path'
  ) THEN
    EXECUTE '
      UPDATE public.expenses
      SET image_path = COALESCE(image_path, receipt_image_path)
      WHERE image_path IS NULL AND receipt_image_path IS NOT NULL
    ';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'expenses'
      AND column_name = 'receipt_image_paths'
  ) AND EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'expenses'
      AND column_name = 'image_paths'
  ) THEN
    EXECUTE '
      UPDATE public.expenses
      SET image_paths = COALESCE(image_paths, receipt_image_paths)
      WHERE image_paths IS NULL AND receipt_image_paths IS NOT NULL
    ';
  END IF;
END $$;

INSERT INTO storage.buckets (id, name, public)
VALUES ('expense-images', 'expense-images', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Authenticated users can upload expense images" ON storage.objects;
DROP POLICY IF EXISTS "Group members can view expense images" ON storage.objects;
DROP POLICY IF EXISTS "Group members can delete expense images" ON storage.objects;

CREATE POLICY "Authenticated users can upload expense images"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'expense-images'
    AND public.is_group_member((storage.foldername(name))[1]::uuid)
  );

CREATE POLICY "Group members can view expense images"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'expense-images'
    AND public.is_group_member((storage.foldername(name))[1]::uuid)
  );

CREATE POLICY "Group members can delete expense images"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'expense-images'
    AND public.is_group_member((storage.foldername(name))[1]::uuid)
  );
