-- Simple test to see what format images come out in
SELECT 
    json_build_object(
        'test_array', '[1,2,3]'::json,
        'test_direct', (SELECT json_agg(x) FROM (VALUES (1), (2), (3)) as t(x))
    );

-- Test with actual target data
SELECT 
    t.id,
    t.type,
    t.data->'images' as images_jsonb,
    (t.data->'images')::json as images_json,
    json_build_object(
        'id', t.id,
        'images_direct', t.data->'images',
        'images_cast', (t.data->'images')::json
    ) as result
FROM targets t
WHERE t.type = 'location' AND t.data->'images' IS NOT NULL
LIMIT 1;


