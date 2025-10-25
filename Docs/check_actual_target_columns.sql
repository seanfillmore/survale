-- Check actual columns in target tables

-- Check targets table
SELECT 'TARGETS TABLE' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'targets'
ORDER BY ordinal_position;

-- Check if target detail tables exist
SELECT 'TARGET DETAIL TABLES' as info;
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name LIKE 'target_%'
ORDER BY table_name;

-- If target_person exists, show its columns
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'target_person'
    ) THEN
        RAISE NOTICE 'target_person columns:';
    END IF;
END $$;

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'target_person'
ORDER BY ordinal_position;

-- Show sample data if any
SELECT * FROM targets LIMIT 1;

