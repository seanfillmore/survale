-- ============================================
-- DISABLE RLS FOR MVP TESTING
-- ============================================
-- RLS (Row Level Security) might be blocking reads
-- For MVP, we'll disable it so users can read their own data

-- IMPORTANT: This is for MVP testing only!
-- In production, you'd want proper RLS policies

-- 1. Disable RLS on users table (allows read/write)
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- 2. Disable RLS on other key tables for MVP
ALTER TABLE teams DISABLE ROW LEVEL SECURITY;
ALTER TABLE agencies DISABLE ROW LEVEL SECURITY;
ALTER TABLE operations DISABLE ROW LEVEL SECURITY;
ALTER TABLE operation_members DISABLE ROW LEVEL SECURITY;
ALTER TABLE locations_stream DISABLE ROW LEVEL SECURITY;
ALTER TABLE op_messages DISABLE ROW LEVEL SECURITY;

-- 3. Verify RLS is disabled
SELECT 
    tablename,
    rowsecurity as rls_enabled,
    CASE 
        WHEN rowsecurity = false THEN '✅ Disabled (Good for MVP)'
        ELSE '⚠️ Still enabled'
    END as status
FROM pg_tables
WHERE tablename IN ('users', 'teams', 'agencies', 'operations', 'operation_members', 'locations_stream', 'op_messages')
AND schemaname = 'public';

-- 4. Test if we can now read users
SELECT 
    'Users readable:' as test,
    COUNT(*)::text || ' users found' as result
FROM users;

SELECT '✅ RLS disabled for MVP testing. All users can now read/write data.' as status;

