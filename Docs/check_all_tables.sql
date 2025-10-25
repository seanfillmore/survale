-- Check all relevant table schemas to see actual column names

-- 1. Check staging_areas table
SELECT 'STAGING_AREAS' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'staging_areas'
ORDER BY ordinal_position;

-- 2. Check targets table
SELECT 'TARGETS' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'targets'
ORDER BY ordinal_position;

-- 3. Check target_person table
SELECT 'TARGET_PERSON' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'target_person'
ORDER BY ordinal_position;

-- 4. Check target_vehicle table
SELECT 'TARGET_VEHICLE' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'target_vehicle'
ORDER BY ordinal_position;

-- 5. Check target_location table
SELECT 'TARGET_LOCATION' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'target_location'
ORDER BY ordinal_position;

