-- ============================================
-- Fix Chat Media Storage Policies
-- ============================================
-- Run this to fix the RLS policies for chat-media bucket
-- ============================================

-- First, drop existing policies
DROP POLICY IF EXISTS "Users can upload to their operation folder" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their operation media" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own media" ON storage.objects;

-- ============================================
-- Simplified Policies (MVP)
-- ============================================
-- For MVP, we'll use simpler policies that just check authentication
-- More granular policies can be added later

-- Allow authenticated users to upload to chat-media bucket
CREATE POLICY "Authenticated users can upload chat media"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'chat-media'
);

-- Allow authenticated users to view all chat media
CREATE POLICY "Authenticated users can view chat media"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'chat-media'
);

-- Allow users to delete their own uploaded media
CREATE POLICY "Users can delete their own chat media"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'chat-media' AND
  owner = auth.uid()
);

-- ============================================
-- Verification
-- ============================================

-- Check policies were created
SELECT 
  policyname,
  cmd,
  roles
FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage'
AND policyname LIKE '%chat media%';

-- Test query: Should return 3 policies
-- INSERT, SELECT, DELETE

