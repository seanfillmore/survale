-- =====================================================
-- UNIFIED SIGNUP DIAGNOSIS
-- =====================================================

SELECT 
    '1. Trigger Check' as check_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.triggers
            WHERE event_object_schema = 'auth'
              AND event_object_table = 'users'
        ) THEN '⚠️ TRIGGER EXISTS on auth.users'
        ELSE '❌ NO TRIGGER - This is why profiles are not created!'
    END as status

UNION ALL

SELECT 
    '2. Agency/Team',
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM agencies a
            JOIN teams t ON t.agency_id = a.id
            WHERE a.name = 'Test Agency' AND t.name = 'Test Team'
        ) THEN '✅ Test Agency and Team exist'
        ELSE '❌ NOT FOUND'
    END

UNION ALL

SELECT 
    '3. RLS Status',
    CASE 
        WHEN (SELECT rowsecurity FROM pg_tables WHERE schemaname = 'public' AND tablename = 'users')
        THEN '⚠️ RLS ENABLED on public.users'
        ELSE '✅ RLS DISABLED'
    END

UNION ALL

SELECT 
    '4. Incomplete Signups',
    (
        SELECT COUNT(*)::text || ' users in auth but not in public'
        FROM auth.users au
        WHERE NOT EXISTS (SELECT 1 FROM public.users pu WHERE pu.id = au.id)
    )

UNION ALL

SELECT 
    '5. Email Unique Constraint',
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE conrelid = 'public.users'::regclass
              AND contype = 'u'
              AND conname LIKE '%email%'
        ) THEN '✅ Email has UNIQUE constraint'
        ELSE '❌ No email unique constraint'
    END;

