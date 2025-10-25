-- ============================================
-- Chat Media Storage Bucket Setup
-- ============================================
-- Run this in Supabase SQL Editor to create
-- the storage bucket for chat photos/videos
-- ============================================

-- Create the chat-media storage bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat-media', 'chat-media', true)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- Storage Policies for chat-media bucket
-- ============================================

-- Allow authenticated users to upload to their operation's folder
CREATE POLICY "Users can upload to their operation folder"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'chat-media' AND
  -- Path format: chat-media/{operation_id}/{filename}
  -- Check that user is a member of the operation
  EXISTS (
    SELECT 1 FROM operation_members om
    WHERE om.operation_id::text = (string_to_array(name, '/'))[1]
    AND om.user_id = auth.uid()
    AND om.left_at IS NULL
  )
);

-- Allow authenticated users to view media from operations they're in
CREATE POLICY "Users can view their operation media"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'chat-media' AND
  -- Check that user is a member of the operation
  EXISTS (
    SELECT 1 FROM operation_members om
    WHERE om.operation_id::text = (string_to_array(name, '/'))[1]
    AND om.user_id = auth.uid()
    AND om.left_at IS NULL
  )
);

-- Allow users to delete their own uploaded media
CREATE POLICY "Users can delete their own media"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'chat-media' AND
  owner = auth.uid()
);

-- ============================================
-- Verification
-- ============================================

-- Check bucket was created
SELECT * FROM storage.buckets WHERE id = 'chat-media';

-- Check policies
SELECT 
  schemaname, 
  tablename, 
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage'
AND policyname LIKE '%operation%';

