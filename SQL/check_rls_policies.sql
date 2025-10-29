-- =====================================================
-- CHECK RLS POLICIES ON USERS TABLE
-- =====================================================
-- Row Level Security policies might be blocking the trigger
-- =====================================================

-- Check if RLS is enabled on users table
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'users'
  AND schemaname = 'public';

-- Check existing policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as command,
    qual as using_expression,
    with_check as with_check_expression
FROM pg_policies
WHERE tablename = 'users'
  AND schemaname = 'public';

-- Suggest fix
DO $$
DECLARE
    rls_enabled boolean;
BEGIN
    SELECT rowsecurity INTO rls_enabled
    FROM pg_tables
    WHERE tablename = 'users' AND schemaname = 'public';
    
    RAISE NOTICE '';
    IF rls_enabled THEN
        RAISE NOTICE '⚠️  RLS is ENABLED on public.users table';
        RAISE NOTICE '';
        RAISE NOTICE '🔧 This might be blocking the trigger!';
        RAISE NOTICE '';
        RAISE NOTICE '💡 Solutions:';
        RAISE NOTICE '   1. Disable RLS: ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;';
        RAISE NOTICE '   2. Add policy for service role: CREATE POLICY "Service role can insert" ...';
        RAISE NOTICE '   3. Make trigger use service_role context';
    ELSE
        RAISE NOTICE '✅ RLS is DISABLED on public.users table';
        RAISE NOTICE '   The trigger should be able to insert freely';
    END IF;
    RAISE NOTICE '';
END $$;

