-- Diagnostic script to check if locations are being saved to locations_stream table
-- Run this in Supabase SQL Editor

-- ============================================
-- STEP 1: Check if locations_stream table exists and has data
-- ============================================
SELECT 
    COUNT(*) as total_records,
    MIN(ts) as earliest_location,
    MAX(ts) as latest_location
FROM public.locations_stream;

-- ============================================
-- STEP 2: Find your active operations
-- ============================================
SELECT 
    o.id as operation_id,
    o.name as operation_name,
    o.status,
    o.created_at
FROM public.operations o
ORDER BY o.created_at DESC
LIMIT 10;

-- ============================================
-- STEP 3: Check recent locations across all operations (last 10 minutes)
-- Run this to see if ANY locations are being saved
-- ============================================
SELECT 
    ls.id,
    ls.operation_id,
    ls.user_id,
    u.email,
    u.callsign,
    ls.ts as timestamp,
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

-- ============================================
-- STEP 4: Check if there are any members in active operations
-- ============================================
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

-- ============================================
-- STEP 5: Count locations per user for active operations (last hour)
-- ============================================
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

-- ============================================
-- STEP 6: Check for locations from all active operations
-- ============================================
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

-- ============================================
-- STEP 7: Locations for specific operation
-- ============================================
SELECT 
    ls.*,
    u.email,
    u.callsign,
    u.full_name,
    o.name as operation_name
FROM public.locations_stream ls
LEFT JOIN public.users u ON ls.user_id = u.id
LEFT JOIN public.operations o ON ls.operation_id = o.id
WHERE ls.operation_id = 'b1c1ace9-6422-4059-87a3-b49d27f85a3e'::uuid
ORDER BY ls.ts DESC
LIMIT 50;
