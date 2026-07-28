-- Feedback screenshot uploads (Settings → Send feedback).
-- Bucket is declared in config.toml [storage.buckets.feedback-screenshots].

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'feedback-screenshots',
  'feedback-screenshots',
  true,
  5242880,
  ARRAY['image/png']::text[]
)
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Authenticated users can upload feedback screenshots" ON storage.objects;
DROP POLICY IF EXISTS "Public read feedback screenshots" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete own feedback path uploads" ON storage.objects;

CREATE POLICY "Authenticated users can upload feedback screenshots"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'feedback-screenshots'
    AND (storage.foldername(name))[1] = 'feedback'
  );

CREATE POLICY "Public read feedback screenshots"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'feedback-screenshots');

CREATE POLICY "Authenticated users can delete own feedback path uploads"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'feedback-screenshots'
    AND (storage.foldername(name))[1] = 'feedback'
  );
