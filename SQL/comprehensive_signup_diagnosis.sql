-- =====================================================
-- COMPREHENSIVE SIGNUP DIAGNOSIS
-- =====================================================
-- Based on Supabase's common causes checklist
-- =====================================================

DO $$
DECLARE
    trigger_exists boolean;
    agency_team_exists boolean;
    rls_enabled boolean;
    rec RECORD;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'SIGNUP DIAGNOSIS CHECKLIST';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- ====================================================
    -- 1. CHECK FOR SIGNUP TRIGGER
    -- ====================================================
    RAISE NOTICE '1. Checking for signup trigger...';
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.triggers
        WHERE event_object_schema = 'auth'
          AND event_object_table = 'users'
    ) INTO trigger_exists;
    
    IF trigger_exists THEN
        RAISE NOTICE '   ⚠️  TRIGGER EXISTS on auth.users';
        -- Show the trigger
        FOR trigger_exists IN (
            SELECT trigger_name, action_statement
            FROM information_schema.triggers
            WHERE event_object_schema = 'auth'
              AND event_object_table = 'users'
        ) LOOP
            RAISE NOTICE '      Trigger: %', trigger_exists;
        END LOOP;
    ELSE
        RAISE NOTICE '   ❌ NO TRIGGER on auth.users';
        RAISE NOTICE '      This explains why public.users is not created!';
    END IF;
    RAISE NOTICE '';
    
    -- ====================================================
    -- 2. CHECK AGENCY/TEAM NAMES
    -- ====================================================
    RAISE NOTICE '2. Checking Test Agency/Team existence...';
    
    SELECT EXISTS (
        SELECT 1 FROM agencies a
        JOIN teams t ON t.agency_id = a.id
        WHERE a.name = 'Test Agency'
          AND t.name = 'Test Team'
    ) INTO agency_team_exists;
    
    IF agency_team_exists THEN
        RAISE NOTICE '   ✅ Test Agency and Test Team exist';
    ELSE
        RAISE NOTICE '   ❌ Test Agency or Test Team NOT FOUND';
        RAISE NOTICE '      Run setup_test_agency_team.sql first';
    END IF;
    RAISE NOTICE '';
    
    -- ====================================================
    -- 3. CHECK UNIQUE CONSTRAINTS ON public.users
    -- ====================================================
    RAISE NOTICE '3. Checking unique constraints on public.users...';
    
    FOR rec IN (
        SELECT 
            conname as constraint_name,
            pg_get_constraintdef(oid) as definition
        FROM pg_constraint
        WHERE conrelid = 'public.users'::regclass
          AND contype IN ('u', 'p')  -- unique or primary key
    ) LOOP
        RAISE NOTICE '   %: %', rec.constraint_name, rec.definition;
    END LOOP;
    RAISE NOTICE '';
    
    -- ====================================================
    -- 4. CHECK FOR EMAIL DUPLICATES
    -- ====================================================
    RAISE NOTICE '4. Checking for duplicate emails...';
    
    IF EXISTS (
        SELECT email, COUNT(*)
        FROM public.users
        GROUP BY email
        HAVING COUNT(*) > 1
    ) THEN
        RAISE NOTICE '   ⚠️  DUPLICATE EMAILS FOUND:';
        FOR rec IN (
            SELECT email, COUNT(*) as count
            FROM public.users
            GROUP BY email
            HAVING COUNT(*) > 1
        ) LOOP
            RAISE NOTICE '      Email: %, Count: %', rec.email, rec.count;
        END LOOP;
    ELSE
        RAISE NOTICE '   ✅ No duplicate emails in public.users';
    END IF;
    RAISE NOTICE '';
    
    -- ====================================================
    -- 5. CHECK RLS STATUS
    -- ====================================================
    RAISE NOTICE '5. Checking RLS status on public.users...';
    
    SELECT rowsecurity INTO rls_enabled
    FROM pg_tables
    WHERE schemaname = 'public' AND tablename = 'users';
    
    IF rls_enabled THEN
        RAISE NOTICE '   ⚠️  RLS is ENABLED on public.users';
        RAISE NOTICE '      This could block inserts if policies are wrong';
    ELSE
        RAISE NOTICE '   ✅ RLS is DISABLED on public.users';
    END IF;
    RAISE NOTICE '';
    
    -- ====================================================
    -- SUMMARY
    -- ====================================================
    RAISE NOTICE '========================================';
    RAISE NOTICE 'DIAGNOSIS SUMMARY';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Most likely issue:';
    
    IF NOT trigger_exists THEN
        RAISE NOTICE '❌ NO SIGNUP TRIGGER EXISTS!';
        RAISE NOTICE '';
        RAISE NOTICE 'Solution: Create a trigger that automatically creates';
        RAISE NOTICE 'public.users records when auth.users records are created.';
        RAISE NOTICE '';
        RAISE NOTICE 'However, we already tried this and it failed due to';
        RAISE NOTICE 'permission issues. The workaround is to:';
        RAISE NOTICE '1. Let the app create the profile (not a trigger)';
        RAISE NOTICE '2. Use auto_fix_incomplete_signups.sql for any failures';
    END IF;
    RAISE NOTICE '';
    
END $$;

-- Show current trigger on auth.users (if any)
SELECT 
    trigger_name,
    event_manipulation,
    action_statement,
    action_timing
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
  AND event_object_table = 'users';

