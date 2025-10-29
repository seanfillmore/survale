-- =====================================================
-- QUICK SIGNUP DIAGNOSIS
-- =====================================================

-- 1. Check for trigger on auth.users
SELECT 
    'Trigger Check' as test,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.triggers
            WHERE event_object_schema = 'auth'
              AND event_object_table = 'users'
        ) THEN '⚠️ TRIGGER EXISTS'
        ELSE '❌ NO TRIGGER (explains missing profiles!)'
    END as result;

-- 2. Check Test Agency/Team
SELECT 
    'Agency/Team Check' as test,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM agencies a
            JOIN teams t ON t.agency_id = a.id
            WHERE a.name = 'Test Agency'
              AND t.name = 'Test Team'
        ) THEN '✅ Test Agency and Team exist'
        ELSE '❌ Test Agency or Team NOT FOUND'
    END as result;

-- 3. Check RLS status
SELECT 
    'RLS Check' as test,
    CASE 
        WHEN rowsecurity THEN '⚠️ RLS ENABLED'
        ELSE '✅ RLS DISABLED'
    END as result
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'users';

-- 4. List unique constraints
SELECT 
    'Unique Constraints' as test,
    conname as constraint_name,
    pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'public.users'::regclass
  AND contype IN ('u', 'p');

-- 5. Check for incomplete signups
SELECT 
    'Incomplete Signups' as test,
    COUNT(*) as count,
    CASE 
        WHEN COUNT(*) > 0 THEN '⚠️ Users in auth but not in public'
        ELSE '✅ No incomplete signups'
    END as result
FROM auth.users au
WHERE NOT EXISTS (
    SELECT 1 FROM public.users pu WHERE pu.id = au.id
);

