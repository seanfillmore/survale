-- =====================================================
-- FIX AUTH IDENTITIES TABLE ACCESS
-- =====================================================
-- The error "unable to find user from email identity for duplicates"
-- means Supabase Auth can't properly query the auth.identities table
-- =====================================================

-- Check if auth.identities exists and has proper structure
SELECT 
    table_schema,
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'auth'
  AND table_name = 'identities'
ORDER BY ordinal_position;

-- Grant necessary permissions on auth schema tables
-- The auth service needs to be able to query these

GRANT USAGE ON SCHEMA auth TO postgres, anon, authenticated, service_role;
GRANT SELECT ON auth.users TO postgres, anon, authenticated, service_role;
GRANT SELECT ON auth.identities TO postgres, anon, authenticated, service_role;

-- Ensure the auth.users table has the email column indexed for fast lookups
CREATE INDEX IF NOT EXISTS idx_auth_users_email ON auth.users(email);
CREATE INDEX IF NOT EXISTS idx_auth_identities_user_id ON auth.identities(user_id);

-- Check if there are any orphaned records
DO $$
DECLARE
    users_count int;
    identities_count int;
    orphaned_identities int;
BEGIN
    SELECT COUNT(*) INTO users_count FROM auth.users;
    SELECT COUNT(*) INTO identities_count FROM auth.identities;
    
    SELECT COUNT(*) INTO orphaned_identities
    FROM auth.identities i
    WHERE NOT EXISTS (
        SELECT 1 FROM auth.users u WHERE u.id = i.user_id
    );
    
    RAISE NOTICE 'Auth Users: %', users_count;
    RAISE NOTICE 'Auth Identities: %', identities_count;
    RAISE NOTICE 'Orphaned Identities: %', orphaned_identities;
    
    IF orphaned_identities > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '⚠️  Found % orphaned identity records', orphaned_identities;
        RAISE NOTICE '   These should be cleaned up:';
        RAISE NOTICE '   DELETE FROM auth.identities WHERE user_id NOT IN (SELECT id FROM auth.users);';
    END IF;
END $$;

-- Clean up any orphaned identities (identities without corresponding users)
DELETE FROM auth.identities
WHERE user_id NOT IN (SELECT id FROM auth.users);

-- Clean up any orphaned users or identities from failed signups
-- (users created in auth.users but not in public.users)
DO $$
DECLARE
    orphaned_auth_users int;
BEGIN
    SELECT COUNT(*) INTO orphaned_auth_users
    FROM auth.users au
    WHERE NOT EXISTS (
        SELECT 1 FROM public.users pu WHERE pu.id = au.id
    );
    
    IF orphaned_auth_users > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '⚠️  Found % auth users without public.users records', orphaned_auth_users;
        RAISE NOTICE '   These are from failed signups and will be cleaned up';
        
        -- Delete orphaned auth identities first
        DELETE FROM auth.identities
        WHERE user_id IN (
            SELECT au.id FROM auth.users au
            WHERE NOT EXISTS (
                SELECT 1 FROM public.users pu WHERE pu.id = au.id
            )
        );
        
        -- Delete orphaned auth users
        DELETE FROM auth.users
        WHERE id IN (
            SELECT au.id FROM auth.users au
            WHERE NOT EXISTS (
                SELECT 1 FROM public.users pu WHERE pu.id = au.id
            )
        );
        
        RAISE NOTICE '✅ Cleaned up orphaned auth records';
    END IF;
END $$;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'AUTH IDENTITIES FIX COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Permissions granted on auth schema';
    RAISE NOTICE '✅ Indexes created for faster lookups';
    RAISE NOTICE '✅ Orphaned records cleaned up';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Try signing up again now';
    RAISE NOTICE '';
END $$;

