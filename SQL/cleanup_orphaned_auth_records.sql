-- =====================================================
-- CLEANUP ORPHANED AUTH RECORDS
-- =====================================================
-- This removes incomplete/failed signup attempts
-- without requiring special permissions
-- =====================================================

-- Check current state
DO $$
DECLARE
    users_count int;
    identities_count int;
    public_users_count int;
    orphaned_auth_users int;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CURRENT STATE';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    SELECT COUNT(*) INTO users_count FROM auth.users;
    SELECT COUNT(*) INTO identities_count FROM auth.identities;
    SELECT COUNT(*) INTO public_users_count FROM public.users;
    
    RAISE NOTICE 'Auth Users (auth.users): %', users_count;
    RAISE NOTICE 'Auth Identities (auth.identities): %', identities_count;
    RAISE NOTICE 'Public Users (public.users): %', public_users_count;
    RAISE NOTICE '';
    
    -- Check for orphaned auth users (users in auth.users but not in public.users)
    SELECT COUNT(*) INTO orphaned_auth_users
    FROM auth.users au
    WHERE NOT EXISTS (
        SELECT 1 FROM public.users pu WHERE pu.id = au.id
    );
    
    IF orphaned_auth_users > 0 THEN
        RAISE NOTICE '⚠️  Found % orphaned auth users (failed signups)', orphaned_auth_users;
        RAISE NOTICE '   These will be deleted...';
        RAISE NOTICE '';
        
        -- Delete orphaned identities first (foreign key constraint)
        DELETE FROM auth.identities
        WHERE user_id IN (
            SELECT au.id FROM auth.users au
            WHERE NOT EXISTS (
                SELECT 1 FROM public.users pu WHERE pu.id = au.id
            )
        );
        
        -- Delete orphaned auth users
        DELETE FROM auth.users
        WHERE id NOT IN (
            SELECT id FROM public.users
        );
        
        RAISE NOTICE '✅ Deleted orphaned auth records';
    ELSE
        RAISE NOTICE '✅ No orphaned auth users found';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CLEANUP COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- Show updated counts
    SELECT COUNT(*) INTO users_count FROM auth.users;
    SELECT COUNT(*) INTO identities_count FROM auth.identities;
    
    RAISE NOTICE 'After cleanup:';
    RAISE NOTICE '  Auth Users: %', users_count;
    RAISE NOTICE '  Auth Identities: %', identities_count;
    RAISE NOTICE '  Public Users: %', public_users_count;
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Try signing up now!';
    
END $$;

