-- =====================================================
-- CLEANUP ALL ORPHANED AUTH RECORDS
-- =====================================================
-- This removes ALL incomplete signup attempts
-- =====================================================

DO $$
DECLARE
    auth_users_count int;
    public_users_count int;
    orphaned_count int;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'BEFORE CLEANUP';
    RAISE NOTICE '========================================';
    
    SELECT COUNT(*) INTO auth_users_count FROM auth.users;
    SELECT COUNT(*) INTO public_users_count FROM public.users;
    
    RAISE NOTICE 'Auth users: %', auth_users_count;
    RAISE NOTICE 'Public users: %', public_users_count;
    RAISE NOTICE '';
    
    -- Count orphaned records
    SELECT COUNT(*) INTO orphaned_count
    FROM auth.users au
    WHERE NOT EXISTS (
        SELECT 1 FROM public.users pu WHERE pu.id = au.id
    );
    
    IF orphaned_count > 0 THEN
        RAISE NOTICE '⚠️  Found % orphaned auth user(s)', orphaned_count;
        RAISE NOTICE '   Cleaning up...';
        RAISE NOTICE '';
        
        -- Step 1: Delete orphaned identities
        DELETE FROM auth.identities
        WHERE user_id IN (
            SELECT au.id FROM auth.users au
            WHERE NOT EXISTS (
                SELECT 1 FROM public.users pu WHERE pu.id = au.id
            )
        );
        
        -- Step 2: Delete orphaned auth users
        DELETE FROM auth.users
        WHERE id NOT IN (
            SELECT id FROM public.users
        );
        
        RAISE NOTICE '✅ Deleted orphaned records';
    ELSE
        RAISE NOTICE '✅ No orphaned records found';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'AFTER CLEANUP';
    RAISE NOTICE '========================================';
    
    SELECT COUNT(*) INTO auth_users_count FROM auth.users;
    
    RAISE NOTICE 'Auth users: %', auth_users_count;
    RAISE NOTICE 'Public users: %', public_users_count;
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Try signing up again now!';
    
END $$;

-- Show remaining users
SELECT 
    au.id,
    au.email,
    au.created_at,
    CASE 
        WHEN pu.id IS NOT NULL THEN '✅ Has profile'
        ELSE '❌ Missing profile'
    END as status
FROM auth.users au
LEFT JOIN public.users pu ON pu.id = au.id
ORDER BY au.created_at DESC;

