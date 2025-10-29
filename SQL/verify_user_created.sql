-- =====================================================
-- VERIFY USER WAS CREATED PROPERLY
-- =====================================================

-- Check auth.users
SELECT 
    'AUTH.USERS' as table_name,
    id,
    email,
    created_at
FROM auth.users
ORDER BY created_at DESC
LIMIT 5;

-- Check public.users
SELECT 
    'PUBLIC.USERS' as table_name,
    id,
    email,
    first_name,
    last_name,
    callsign,
    phone_number,
    agency_id,
    team_id
FROM public.users
ORDER BY created_at DESC
LIMIT 5;

-- Check for mismatches (users in auth but not in public)
SELECT 
    'USERS IN AUTH BUT NOT IN PUBLIC' as issue,
    au.id,
    au.email,
    au.created_at
FROM auth.users au
WHERE NOT EXISTS (
    SELECT 1 FROM public.users pu WHERE pu.id = au.id
);

DO $$
DECLARE
    auth_count int;
    public_count int;
BEGIN
    SELECT COUNT(*) INTO auth_count FROM auth.users;
    SELECT COUNT(*) INTO public_count FROM public.users;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'SUMMARY';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Users in auth.users: %', auth_count;
    RAISE NOTICE 'Users in public.users: %', public_count;
    
    IF auth_count > public_count THEN
        RAISE NOTICE '';
        RAISE NOTICE '⚠️  Mismatch! Some users exist in auth but not in public.users';
        RAISE NOTICE '   This means the signup completed in auth but failed to create';
        RAISE NOTICE '   the profile record in public.users';
    ELSIF auth_count = public_count THEN
        RAISE NOTICE '✅ Counts match!';
    END IF;
    RAISE NOTICE '';
END $$;

