-- ============================================
-- Debug Trigger Issues
-- ============================================

-- Check if trigger exists and is enabled
SELECT 
    trigger_name,
    event_object_table,
    action_timing,
    event_manipulation,
    action_statement,
    action_orientation
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created';

-- Check the actual function code
SELECT 
    routine_name,
    routine_definition
FROM information_schema.routines
WHERE routine_name = 'handle_new_user';

-- Check if Default Agency and Team still exist
SELECT 
    'Default Agency exists:' as check,
    CASE WHEN COUNT(*) > 0 THEN 'YES ✅' ELSE 'NO ❌' END as result
FROM agencies 
WHERE name = 'Default Agency'
UNION ALL
SELECT 
    'Default Team exists:' as check,
    CASE WHEN COUNT(*) > 0 THEN 'YES ✅' ELSE 'NO ❌' END as result
FROM teams 
WHERE name = 'Default Team';

-- Test if we can manually insert a user (to check for constraint issues)
DO $$
DECLARE
    test_id UUID := gen_random_uuid();
    test_email TEXT := 'test_' || test_id::text || '@example.com';
    def_agency UUID;
    def_team UUID;
BEGIN
    -- Get default IDs
    SELECT id INTO def_agency FROM agencies WHERE name = 'Default Agency';
    SELECT id INTO def_team FROM teams WHERE name = 'Default Team';
    
    IF def_agency IS NULL THEN
        RAISE EXCEPTION 'Default Agency not found!';
    END IF;
    
    IF def_team IS NULL THEN
        RAISE EXCEPTION 'Default Team not found!';
    END IF;
    
    -- Try to insert
    INSERT INTO users (
        id,
        email,
        full_name,
        agency_id,
        team_id,
        vehicle_type,
        vehicle_color
    ) VALUES (
        test_id,
        test_email,
        'Test User',
        def_agency,
        def_team,
        'sedan',
        'black'
    );
    
    RAISE NOTICE 'Manual insert test: SUCCESS ✅';
    
    -- Clean up
    DELETE FROM users WHERE id = test_id;
    RAISE NOTICE 'Test user cleaned up';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Manual insert test FAILED: %', SQLERRM;
END $$;

