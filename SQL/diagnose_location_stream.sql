-- Diagnostic script to check if locations are being saved to locations_stream table
-- Run this in Supabase SQL Editor

-- 1. Check if locations_stream table exists and has data
SELECT 
    COUNT(*) as total_records,
    MIN(ts) as earliest_location,
    MAX(ts) as latest_location
FROM public.locations_stream;

-- 2. Check locations for a specific operation (replace with your operation ID)
-- Look in your app for the operation ID first, or run query below to find it
SELECT 
    o.id as operation_id,
    o.name as operation_name,
    o.status,
    o.created_at
FROM public.operations o
ORDER BY o.created_at DESC
LIMIT 10;

-- 3. After you have the operation ID, run this to see locations for that operation:
-- (Replace 'YOUR_OPERATION_ID' with actual operation ID from query above)
SELECT 
    ls.*,
    u.email,
    u.callsign,
    u.full_name
FROM public.locations_stream ls
LEFT JOIN public.users u ON ls.user_id = u.id
WHERE ls.operation_id = 'YOUR_OPERATION_ID'::uuid
ORDER BY ls.ts DESC
LIMIT 50;

-- 4. Check for locations from all active operations
SELECT 
    o.name as operation_name,
    COUNT(ls.id) as location_count,
    MIN(ls.ts) as first_location,
    MAX(ls.ts) as last_location
FROM public.operations o
LEFT JOIN public.locations_stream ls ON o.id = ls.operation_id
WHERE o.status = 'active'
GROUP BY o.id, o.name
ORDER BY o.created_at DESC;

-- 5. Check recent locations across all operations (last 10 minutes)
SELECT 
    ls.id,
    ls.operation_id,
    ls.user_id,
    u.email,
    u.callsign,
    ls.ts,
    ls.lat,
    ls.lon,
    ls.accuracy_m,
    ls.speed_mps,
    ls.heading_deg,
    o.name as operation_name
FROM public.locations_stream ls
LEFT JOIN public.users u ON ls.user_id = u.id
LEFT JOIN public.operations o ON ls.operation_id = o.id
WHERE ls.ts > NOW() - INTERVAL '10 minutes'
ORDER BY ls.ts DESC;

-- 6. Check if there are any members in the operation
SELECT 
    o.id as operation_id,
    o.name as operation_name,
    u.email,
    u.callsign,
    u.full_name,
    om.role,
    om.joined_at
FROM public.operations o
JOIN public.operation_members om ON o.id = om.operation_id
LEFT JOIN public.users u ON om.user_id = u.id
WHERE o.status = 'active'
  AND om.left_at IS NULL
ORDER BY o.created_at DESC, om.joined_at;

-- 7. Count locations per user for active operations
SELECT 
    u.email,
    u.callsign,
    COUNT(ls.id) as location_count,
    MAX(ls.ts) as last_location_time
FROM public.locations_stream ls
JOIN public.users u ON ls.user_id = u.id
JOIN public.operations o ON ls.operation_id = o.id
WHERE o.status = 'active'
  AND ls.ts > NOW() - INTERVAL '1 hour'
GROUP BY u.id, u.email, u.callsign
ORDER BY location_count DESC;
