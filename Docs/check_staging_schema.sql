-- Check the actual columns in staging_areas table
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'staging_areas'
ORDER BY ordinal_position;

