-- Test what the images look like when extracted
-- Run this to see the raw output format

SELECT 
    t.id,
    t.type,
    t.data->'images' as images_raw,
    (t.data->'images')::text as images_text,
    jsonb_typeof(t.data->'images') as images_type
FROM targets t
WHERE t.type = 'location'
LIMIT 1;

-- Test if we can parse it correctly in a json_build_object
SELECT json_build_object(
    'test', 'value',
    'images', (t.data->'images')::jsonb
)
FROM targets t
WHERE t.type = 'location' AND jsonb_typeof(t.data->'images') = 'array'
LIMIT 1;


