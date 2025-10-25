-- Debug: Check if targets exist and what their data looks like
-- Run this to see what's in your targets table

-- 1. Check if targets exist
SELECT 
    t.id,
    t.type,
    t.operation_id,
    t.data
FROM targets t
ORDER BY t.created_at DESC
LIMIT 5;

-- 2. Check if the JSONB extraction works
SELECT 
    t.id,
    t.type,
    t.data->>'first_name' as first_name,
    t.data->>'last_name' as last_name,
    t.data->'images' as images_json,
    CASE 
        WHEN jsonb_typeof(t.data->'images') = 'array' THEN jsonb_array_length(t.data->'images')
        ELSE 0
    END as image_count
FROM targets t
WHERE t.type = 'person'
LIMIT 3;

-- 3. Test the RPC function manually (replace with your operation_id)
-- SELECT * FROM rpc_get_operation_targets('your-operation-id-here'::uuid);

