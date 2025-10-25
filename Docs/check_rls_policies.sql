-- ============================================
-- Check RLS Policies on Users Table
-- ============================================
-- RLS might be blocking the app from reading your user record

-- 1. Check if RLS is enabled on users table
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'users';

-- 2. Check what policies exist on users table
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as command,
    qual as using_expression,
    with_check
FROM pg_policies
WHERE tablename = 'users'
ORDER BY policyname;

-- 3. Test if we can read users table (this simulates what your app does)
SELECT 
    'Can read users table:' as test,
    CASE WHEN COUNT(*) > 0 THEN 'YES ✅' ELSE 'NO ❌' END as result
FROM users;

-- 4. Check auth.users vs public.users count
SELECT 
    'Auth users count:' as metric,
    COUNT(*)::text as count
FROM auth.users
UNION ALL
SELECT 
    'Public users count:' as metric,
    COUNT(*)::text as count
FROM users;

-- 5. Try to read your specific user
-- Replace YOUR_EMAIL_HERE with your actual email
SELECT 
    'Your user record:' as info,
    id::text,
    email,
    team_id::text,
    agency_id::text
FROM users
WHERE email = 'YOUR_EMAIL_HERE';  -- REPLACE THIS

