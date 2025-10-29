-- =====================================================
-- PURGE ALL TEST DATA
-- =====================================================
-- This script deletes ALL data from the database
-- Based on the actual Survale database schema
-- Use with EXTREME CAUTION - this is irreversible!
-- =====================================================
-- Recommended usage:
-- 1. Backup your database first (if needed)
-- 2. Run this in Supabase SQL Editor
-- 3. Verify data is deleted with the verification queries at the end
-- =====================================================

DO $$ 
DECLARE
    row_count integer;
BEGIN
    -- Disable triggers temporarily for faster deletion
    SET LOCAL session_replication_role = 'replica';

    RAISE NOTICE '🔄 Starting database purge...';
    RAISE NOTICE '';

    -- =====================================================
    -- 1. DELETE OPERATION-RELATED DATA (in dependency order)
    -- =====================================================
    
    RAISE NOTICE '📦 Deleting operation-related data...';

    -- Delete proximity alerts
    DELETE FROM proximity_alerts;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from proximity_alerts', row_count;

    -- Delete team presence
    DELETE FROM team_presence;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from team_presence', row_count;

    -- Delete exports
    DELETE FROM exports;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from exports', row_count;

    -- Delete chat messages
    DELETE FROM op_messages;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from op_messages', row_count;

    -- Delete assigned locations
    DELETE FROM assigned_locations;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from assigned_locations', row_count;

    -- Delete location streams and archives
    DELETE FROM locations_stream;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from locations_stream', row_count;

    DELETE FROM locations_archive;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from locations_archive', row_count;

    -- Delete media assets
    DELETE FROM media_assets;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from media_assets', row_count;

    -- Delete operation invites and join requests
    DELETE FROM operation_invites;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from operation_invites', row_count;

    DELETE FROM operation_join_requests;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from operation_join_requests', row_count;

    DELETE FROM join_requests;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from join_requests', row_count;

    -- Delete operation members
    DELETE FROM operation_members;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from operation_members', row_count;

    -- Delete staging areas
    DELETE FROM staging_areas;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from staging_areas', row_count;

    -- Delete target photos
    DELETE FROM target_photos;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from target_photos', row_count;

    -- Delete target details (person, vehicle, location)
    DELETE FROM target_person;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from target_person', row_count;

    DELETE FROM target_vehicle;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from target_vehicle', row_count;

    DELETE FROM target_location;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from target_location', row_count;

    -- Delete targets
    DELETE FROM targets;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from targets', row_count;

    -- =====================================================
    -- 2. DELETE TEMPLATE DATA
    -- =====================================================
    
    RAISE NOTICE '';
    RAISE NOTICE '📋 Deleting template data...';

    -- Delete template staging points
    DELETE FROM template_staging_points;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from template_staging_points', row_count;

    -- Delete template targets
    DELETE FROM template_targets;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from template_targets', row_count;

    -- Delete operation templates
    DELETE FROM operation_templates;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from operation_templates', row_count;

    -- =====================================================
    -- 3. DELETE OPERATIONS
    -- =====================================================
    
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Deleting operations...';

    DELETE FROM operations;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from operations', row_count;

    -- =====================================================
    -- 4. DELETE USER AND TEAM DATA
    -- =====================================================
    
    RAISE NOTICE '';
    RAISE NOTICE '👥 Deleting user and team data...';

    -- Delete users (this will cascade to auth.users via trigger if set up)
    DELETE FROM users;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from users', row_count;

    -- Delete teams
    DELETE FROM teams;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from teams', row_count;

    -- Delete agencies
    DELETE FROM agencies;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from agencies', row_count;

    -- =====================================================
    -- 5. DELETE AUDIT LOG
    -- =====================================================
    
    RAISE NOTICE '';
    RAISE NOTICE '📝 Deleting audit log...';

    DELETE FROM audit_log;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from audit_log', row_count;

    -- =====================================================
    -- 6. DELETE AUTH USERS (Supabase Auth)
    -- =====================================================
    
    RAISE NOTICE '';
    RAISE NOTICE '🔐 Deleting auth users...';

    DELETE FROM auth.users;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % rows from auth.users', row_count;

    -- Re-enable triggers
    SET LOCAL session_replication_role = 'origin';
    
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  NOTE: Storage files (images, videos) are NOT deleted';
    RAISE NOTICE '   To delete storage files, go to Supabase Dashboard → Storage';
    RAISE NOTICE '   Buckets to check: chat-media, target-images, etc.';
    RAISE NOTICE '';
    RAISE NOTICE '🎉 PURGE COMPLETE! Database is now clean for fresh testing.';
END $$;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================
-- Run these after purge to verify everything is deleted

SELECT 
    'operations' as table_name, 
    COUNT(*) as remaining_rows 
FROM operations

UNION ALL SELECT 'targets', COUNT(*) FROM targets
UNION ALL SELECT 'staging_areas', COUNT(*) FROM staging_areas
UNION ALL SELECT 'operation_templates', COUNT(*) FROM operation_templates
UNION ALL SELECT 'template_targets', COUNT(*) FROM template_targets
UNION ALL SELECT 'template_staging_points', COUNT(*) FROM template_staging_points
UNION ALL SELECT 'operation_members', COUNT(*) FROM operation_members
UNION ALL SELECT 'op_messages', COUNT(*) FROM op_messages
UNION ALL SELECT 'assigned_locations', COUNT(*) FROM assigned_locations
UNION ALL SELECT 'locations_stream', COUNT(*) FROM locations_stream
UNION ALL SELECT 'locations_archive', COUNT(*) FROM locations_archive
UNION ALL SELECT 'users', COUNT(*) FROM users
UNION ALL SELECT 'auth.users', COUNT(*) FROM auth.users
UNION ALL SELECT 'teams', COUNT(*) FROM teams
UNION ALL SELECT 'agencies', COUNT(*) FROM agencies
UNION ALL SELECT 'operation_invites', COUNT(*) FROM operation_invites
UNION ALL SELECT 'operation_join_requests', COUNT(*) FROM operation_join_requests
UNION ALL SELECT 'join_requests', COUNT(*) FROM join_requests
UNION ALL SELECT 'media_assets', COUNT(*) FROM media_assets
UNION ALL SELECT 'target_photos', COUNT(*) FROM target_photos
UNION ALL SELECT 'exports', COUNT(*) FROM exports
UNION ALL SELECT 'audit_log', COUNT(*) FROM audit_log
UNION ALL SELECT 'proximity_alerts', COUNT(*) FROM proximity_alerts
UNION ALL SELECT 'team_presence', COUNT(*) FROM team_presence

ORDER BY table_name;
