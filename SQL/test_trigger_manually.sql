-- =====================================================
-- TEST THE TRIGGER MANUALLY
-- =====================================================
-- This script tests if the trigger function works correctly
-- by simulating what happens during signup
-- =====================================================

DO $$
DECLARE
    test_user_id uuid := gen_random_uuid();
    test_email text := 'test-trigger@example.com';
    default_agency_id uuid;
    default_team_id uuid;
BEGIN
    RAISE NOTICE '🧪 Testing trigger function...';
    RAISE NOTICE '';
    
    -- Step 1: Check if Test Agency and Test Team exist
    RAISE NOTICE '📋 Step 1: Checking for Test Agency and Test Team...';
    
    SELECT a.id, t.id INTO default_agency_id, default_team_id
    FROM agencies a
    JOIN teams t ON t.agency_id = a.id
    WHERE a.name = 'Test Agency'
      AND t.name = 'Test Team'
    LIMIT 1;
    
    IF default_agency_id IS NULL OR default_team_id IS NULL THEN
        RAISE NOTICE '❌ FAILED: Test Agency and/or Test Team not found!';
        RAISE NOTICE '   Run setup_test_agency_team.sql first';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ Found Test Agency: %', default_agency_id;
    RAISE NOTICE '✅ Found Test Team: %', default_team_id;
    RAISE NOTICE '';
    
    -- Step 2: Test creating a user record (what the trigger does)
    RAISE NOTICE '📋 Step 2: Testing user record creation...';
    
    BEGIN
        INSERT INTO public.users (
            id,
            email,
            agency_id,
            team_id,
            created_at
        ) VALUES (
            test_user_id,
            test_email,
            default_agency_id,
            default_team_id,
            NOW()
        );
        
        RAISE NOTICE '✅ User record created successfully';
        RAISE NOTICE '   User ID: %', test_user_id;
        RAISE NOTICE '   Email: %', test_email;
        RAISE NOTICE '';
        
        -- Clean up test user
        DELETE FROM public.users WHERE id = test_user_id;
        RAISE NOTICE '🧹 Test user cleaned up';
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ FAILED to create user record!';
        RAISE NOTICE '   Error: %', SQLERRM;
        RAISE NOTICE '   Detail: %', SQLSTATE;
        RETURN;
    END;
    
    RAISE NOTICE '';
    RAISE NOTICE '🎉 All tests passed! The trigger should work correctly.';
    
END $$;

-- Also check the current trigger
SELECT 
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
  AND event_object_table = 'users'
  AND trigger_name = 'on_auth_user_created';

