-- Check the ACTUAL columns in your staging_areas table
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'staging_areas'
ORDER BY ordinal_position;

-- Also show a sample row if any exist
SELECT * FROM staging_areas LIMIT 1;

