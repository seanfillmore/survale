-- ============================================
-- Diagnose Signup Error
-- ============================================
-- Run this to find out what's causing "Database error saving new user"

-- 1. Check if trigger function exists
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_name = 'handle_new_user';

-- 2. Check if trigger is attached
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created';

-- 3. Check users table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'users'
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 4. Check for NOT NULL constraints
SELECT 
    column_name,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'users'
AND table_schema = 'public'
AND is_nullable = 'NO'
ORDER BY ordinal_position;

-- 5. Check if Default Agency and Team exist
SELECT 'Agency:', id, name FROM agencies WHERE name = 'Default Agency'
UNION ALL
SELECT 'Team:', id, name FROM teams WHERE name = 'Default Team';

-- 6. Test if we can manually insert a user (this will help identify the exact issue)
-- Comment: Try this with a test UUID to see what error we get
-- DO $$
-- DECLARE
--     test_id UUID := gen_random_uuid();
-- BEGIN
--     INSERT INTO users (id, email, agency_id, team_id, vehicle_type, vehicle_color)
--     VALUES (
--         test_id,
--         'test@example.com',
--         (SELECT id FROM agencies WHERE name = 'Default Agency'),
--         (SELECT id FROM teams WHERE name = 'Default Team'),
--         'sedan',
--         'black'
--     );
--     RAISE NOTICE 'Test insert successful!';
--     -- Clean up test
--     DELETE FROM users WHERE id = test_id;
-- END $$;

-- 7. Check for foreign key constraints
SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
AND tc.table_name = 'users';

