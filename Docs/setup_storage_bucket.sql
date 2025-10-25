-- Setup Supabase Storage Bucket for Target Images
-- Run this in your Supabase SQL Editor

-- 1. Create storage bucket for target images
INSERT INTO storage.buckets (id, name, public)
VALUES ('target-images', 'target-images', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Enable public access (for viewing images in the app)
-- This allows anyone with the URL to view images
-- For production, you might want to make this private and use signed URLs

-- 3. Create storage policy for authenticated users to upload
CREATE POLICY "Authenticated users can upload target images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'target-images' AND
    auth.role() = 'authenticated'
);

-- 4. Create storage policy for authenticated users to update
CREATE POLICY "Authenticated users can update their target images"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'target-images')
WITH CHECK (bucket_id = 'target-images');

-- 5. Create storage policy for authenticated users to delete
CREATE POLICY "Authenticated users can delete target images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'target-images');

-- 6. Allow public read access (anyone can view)
CREATE POLICY "Public can view target images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'target-images');

-- Done! Now you can upload images to the 'target-images' bucket
SELECT 'Storage bucket created successfully!' as status;

