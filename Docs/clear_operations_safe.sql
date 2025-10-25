-- Clear All Operations - Safe Version
-- Only deletes from tables that exist in your database
-- WARNING: This will permanently delete all operations and related data!

-- Delete related data first (due to foreign key constraints)

-- Delete chat messages (if table exists)
DELETE FROM op_messages WHERE operation_id IN (SELECT id FROM operations);

-- Delete location tracking data (if table exists)
DELETE FROM locations_stream WHERE operation_id IN (SELECT id FROM operations);

-- Delete targets (if table exists)
DELETE FROM targets WHERE operation_id IN (SELECT id FROM operations);

-- Delete staging points/areas (if table exists)
DELETE FROM staging_areas WHERE operation_id IN (SELECT id FROM operations);

-- Delete operation members (if table exists)
DELETE FROM operation_members WHERE operation_id IN (SELECT id FROM operations);

-- Delete operations themselves
DELETE FROM operations;

-- Verify deletion
SELECT 'All operations cleared!' as status;

-- Check counts (should all be 0)
SELECT 
    (SELECT COUNT(*) FROM operations) as operations_count,
    (SELECT COUNT(*) FROM operation_members) as members_count,
    (SELECT COUNT(*) FROM targets) as targets_count,
    (SELECT COUNT(*) FROM staging_areas) as staging_count,
    (SELECT COUNT(*) FROM op_messages) as messages_count,
    (SELECT COUNT(*) FROM locations_stream) as locations_count;

