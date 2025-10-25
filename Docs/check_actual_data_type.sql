-- Check what type the images field actually is in the database

SELECT 
    id,
    type,
    jsonb_typeof(data->'images') as images_type,
    data->'images' as images_value,
    (data->>'images') as images_as_text
FROM targets
WHERE type = 'person' AND data ? 'images'
LIMIT 3;

-- Also check if images is stored as text in data
SELECT 
    id,
    type,
    data
FROM targets
WHERE type = 'person'
LIMIT 2;


