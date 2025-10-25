-- Check the actual schema of op_messages table
SELECT 
    column_name,
    data_type,
    udt_name,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'op_messages'
ORDER BY ordinal_position;

-- Check if there's an enum type for media
SELECT 
    t.typname as enum_name,
    e.enumlabel as enum_value
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid  
WHERE t.typname LIKE '%media%'
ORDER BY e.enumsortorder;


