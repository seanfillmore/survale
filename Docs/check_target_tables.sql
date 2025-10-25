-- Check actual column names in target tables

-- 1. target_person
SELECT 'TARGET_PERSON' as table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'target_person'
ORDER BY ordinal_position;

-- 2. target_vehicle
SELECT 'TARGET_VEHICLE' as table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'target_vehicle'
ORDER BY ordinal_position;

-- 3. target_location
SELECT 'TARGET_LOCATION' as table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'target_location'
ORDER BY ordinal_position;

