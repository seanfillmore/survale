-- =====================================================
-- COMPREHENSIVE DIAGNOSIS OF AUTH ISSUE
-- =====================================================

-- 1. Check ALL triggers on auth.users
SELECT 
    'TRIGGERS ON auth.users' as check_type,
    trigger_name,
    event_manipulation,
    action_statement,
    action_timing
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
  AND event_object_table = 'users';

-- 2. Check ALL functions that might be called
SELECT 
    'USER-RELATED FUNCTIONS' as check_type,
    routine_schema,
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_name LIKE '%user%'
   OR routine_name LIKE '%auth%'
   OR routine_name LIKE '%profile%'
ORDER BY routine_schema, routine_name;

-- 3. Check for Supabase Auth hooks (these are special)
SELECT 
    'AUTH HOOKS' as check_type,
    id,
    hook_table_id,
    hook_name,
    created_at
FROM supabase_functions.hooks
WHERE hook_table_id IN (
    SELECT id FROM supabase_functions.tables WHERE name = 'users'
)
UNION ALL
SELECT 
    'ALL AUTH HOOKS' as check_type,
    id::text,
    hook_table_id::text,
    hook_name,
    created_at
FROM supabase_functions.hooks;

-- 4. Check RLS on users table
SELECT 
    'RLS STATUS' as check_type,
    schemaname,
    tablename,
    CASE WHEN rowsecurity THEN 'ENABLED' ELSE 'DISABLED' END as rls_status
FROM pg_tables
WHERE tablename = 'users'
  AND schemaname = 'public';

-- 5. Check for any policies
SELECT 
    'RLS POLICIES' as check_type,
    policyname,
    permissive,
    roles::text,
    cmd::text
FROM pg_policies
WHERE tablename = 'users'
  AND schemaname = 'public';

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'DIAGNOSIS COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Look for:';
    RAISE NOTICE '  - Any triggers on auth.users';
    RAISE NOTICE '  - Any auth hooks';
    RAISE NOTICE '  - RLS policies that might block inserts';
    RAISE NOTICE '';
END $$;

