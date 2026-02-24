-- RLS policies for receipt-images Storage bucket (expense receipt attachments).
-- Create the bucket first in Dashboard: Storage > New bucket > name: receipt-images, Public: true.
-- Path format in bucket: {group_id}/{expense_id}/{uuid}.{ext}

-- Allow authenticated users to upload to receipt-images (path: group_id/expense_id/filename)
CREATE POLICY "receipt_images_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'receipt-images'
  AND (storage.foldername(name))[1] IN (
    SELECT group_id::text FROM public.group_members WHERE user_id = auth.uid()
  )
);

-- Allow authenticated users to read objects in groups they belong to
CREATE POLICY "receipt_images_select"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'receipt-images'
  AND (storage.foldername(name))[1] IN (
    SELECT group_id::text FROM public.group_members WHERE user_id = auth.uid()
  )
);
