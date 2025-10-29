-- =====================================================
-- PURGE TEST DATA - SAFE VERSION (Keep Some Users)
-- =====================================================
-- This version allows you to keep specific users/teams if needed
-- =====================================================

BEGIN;

-- =====================================================
-- OPTIONAL: Keep specific users by email
-- =====================================================
-- Uncomment and add emails of users you want to keep:
-- 
-- DO $$
-- DECLARE
--     keep_user_ids UUID[];
-- BEGIN
--     -- Get IDs of users to keep
--     SELECT ARRAY_AGG(id) INTO keep_user_ids
--     FROM auth.users
--     WHERE email IN (
--         'admin@example.com',
--         'your-email@example.com'
--     );
--     
--     -- Store in temp table
--     CREATE TEMP TABLE users_to_keep AS
--     SELECT unnest(keep_user_ids) as user_id;
-- END $$;

-- =====================================================
-- 1. DELETE OPERATION DATA (All operations)
-- =====================================================

-- Delete in correct order (respecting foreign keys)
DELETE FROM op_messages;
DELETE FROM assigned_locations;
DELETE FROM location_history;
DELETE FROM operation_invites;
DELETE FROM join_requests;
DELETE FROM operation_members;
DELETE FROM staging_points;
DELETE FROM op_target_images;
DELETE FROM op_targets;
DELETE FROM operation_templates;
DELETE FROM operations;

RAISE NOTICE '✅ All operation data deleted';

-- =====================================================
-- 2. DELETE USER DATA (All users)
-- =====================================================

DELETE FROM profiles;
DELETE FROM team_members;
DELETE FROM teams;
DELETE FROM agencies;
DELETE FROM auth.users;

RAISE NOTICE '✅ All user data deleted';

-- =====================================================
-- ALTERNATIVE: Keep specific users
-- =====================================================
-- Uncomment this section instead of the above if you want to keep some users:
--
-- -- Delete profiles except for users we're keeping
-- DELETE FROM profiles
-- WHERE user_id NOT IN (SELECT user_id FROM users_to_keep);
-- 
-- -- Delete teams with no remaining members
-- DELETE FROM teams
-- WHERE id NOT IN (
--     SELECT DISTINCT team_id FROM team_members
--     WHERE user_id IN (SELECT user_id FROM users_to_keep)
-- );
-- 
-- -- Delete auth users except ones we're keeping
-- DELETE FROM auth.users
-- WHERE id NOT IN (SELECT user_id FROM users_to_keep);

COMMIT;

-- Verification
SELECT 
    'Total operations' as metric, 
    COUNT(*)::text as count 
FROM operations
UNION ALL
SELECT 'Total users', COUNT(*)::text FROM auth.users
UNION ALL
SELECT 'Total profiles', COUNT(*)::text FROM profiles
UNION ALL
SELECT 'Total teams', COUNT(*)::text FROM teams;

RAISE NOTICE '🎉 Purge complete!';

