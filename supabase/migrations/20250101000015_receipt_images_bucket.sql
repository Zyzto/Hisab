-- Migration 15: Receipt images Storage bucket RLS policies
-- Based on docs/SUPABASE_SETUP.md Migration 15
-- The bucket itself is created via config.toml [storage.buckets.receipt-images]

CREATE POLICY "Authenticated users can upload receipt images"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'receipt-images'
    AND public.is_group_member((storage.foldername(name))[1]::uuid)
  );

CREATE POLICY "Group members can view receipt images"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'receipt-images'
    AND public.is_group_member((storage.foldername(name))[1]::uuid)
  );

CREATE POLICY "Group members can delete receipt images"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'receipt-images'
    AND public.is_group_member((storage.foldername(name))[1]::uuid)
  );
