-- =====================================================
-- FINAL COMPREHENSIVE DIAGNOSIS
-- =====================================================
-- This will show us EXACTLY what's wrong with auth
-- =====================================================

-- 1. Check if auth.identities table exists and is accessible
DO $$
DECLARE
    identities_exists boolean;
    can_read_identities boolean;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '1. CHECKING AUTH.IDENTITIES TABLE';
    RAISE NOTICE '========================================';
    
    -- Check if table exists
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'auth' 
        AND table_name = 'identities'
    ) INTO identities_exists;
    
    IF identities_exists THEN
        RAISE NOTICE '✅ auth.identities table EXISTS';
        
        -- Try to read from it
        BEGIN
            PERFORM COUNT(*) FROM auth.identities;
            RAISE NOTICE '✅ Can READ from auth.identities';
            can_read_identities := true;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ CANNOT READ from auth.identities: %', SQLERRM;
            can_read_identities := false;
        END;
    ELSE
        RAISE NOTICE '❌ auth.identities table DOES NOT EXIST!';
    END IF;
    
    RAISE NOTICE '';
END $$;

-- 2. Check auth.users table
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '2. CHECKING AUTH.USERS TABLE';
    RAISE NOTICE '========================================';
    
    BEGIN
        PERFORM COUNT(*) FROM auth.users;
        RAISE NOTICE '✅ Can read from auth.users';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ CANNOT read from auth.users: %', SQLERRM;
    END;
    
    RAISE NOTICE '';
END $$;

-- 3. List all tables in auth schema
SELECT 
    '3. ALL TABLES IN AUTH SCHEMA' as section,
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'auth'
ORDER BY table_name;

-- 4. Check for any schema corruption
DO $$
DECLARE
    schema_exists boolean;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '4. CHECKING AUTH SCHEMA';
    RAISE NOTICE '========================================';
    
    SELECT EXISTS (
        SELECT FROM information_schema.schemata 
        WHERE schema_name = 'auth'
    ) INTO schema_exists;
    
    IF schema_exists THEN
        RAISE NOTICE '✅ auth schema exists';
    ELSE
        RAISE NOTICE '❌ auth schema MISSING!';
    END IF;
    
    RAISE NOTICE '';
END $$;

-- 5. Show the exact column structure of auth.identities if it exists
SELECT 
    '5. AUTH.IDENTITIES STRUCTURE' as section,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'auth'
  AND table_name = 'identities'
ORDER BY ordinal_position;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'DIAGNOSIS COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '📋 SUMMARY:';
    RAISE NOTICE 'If you see errors above about not being able to read';
    RAISE NOTICE 'from auth.identities, this is a Supabase configuration';
    RAISE NOTICE 'issue that requires:';
    RAISE NOTICE '';
    RAISE NOTICE '1. Contacting Supabase Support, OR';
    RAISE NOTICE '2. Recreating the project, OR';
    RAISE NOTICE '3. Running a migration to fix auth schema';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  This is NOT something that can be fixed with SQL scripts';
    RAISE NOTICE '   from the SQL Editor - it requires admin/superuser access.';
    RAISE NOTICE '';
END $$;

