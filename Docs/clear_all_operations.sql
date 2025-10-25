-- Clear All Operations from Database
-- WARNING: This will permanently delete all operations and related data!
-- Use with caution, especially in production.

-- Step 1: Delete related data first (due to foreign key constraints)

-- Delete join requests
DELETE FROM join_requests WHERE operation_id IN (SELECT id FROM operations);

-- Delete operation invites
DELETE FROM operation_invites WHERE operation_id IN (SELECT id FROM operations);

-- Delete chat messages
DELETE FROM op_messages WHERE operation_id IN (SELECT id FROM operations);

-- Delete location tracking data
DELETE FROM locations_stream WHERE operation_id IN (SELECT id FROM operations);

-- Delete targets
DELETE FROM targets WHERE operation_id IN (SELECT id FROM operations);

-- Delete staging points/areas
DELETE FROM staging_areas WHERE operation_id IN (SELECT id FROM operations);

-- Delete operation members
DELETE FROM operation_members WHERE operation_id IN (SELECT id FROM operations);

-- Step 2: Delete operations themselves
DELETE FROM operations;

-- Step 3: Verify deletion
SELECT 'All operations cleared!' as status;

-- Check counts (should all be 0)
SELECT 
    (SELECT COUNT(*) FROM operations) as operations_count,
    (SELECT COUNT(*) FROM operation_members) as members_count,
    (SELECT COUNT(*) FROM targets) as targets_count,
    (SELECT COUNT(*) FROM staging_areas) as staging_count,
    (SELECT COUNT(*) FROM join_requests) as requests_count,
    (SELECT COUNT(*) FROM op_messages) as messages_count,
    (SELECT COUNT(*) FROM locations_stream) as locations_count;

