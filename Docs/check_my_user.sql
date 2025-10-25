-- ============================================
-- Check Your User Record
-- ============================================
-- Run this to see if your user was created properly with team/agency

-- 1. Check auth.users (Supabase Auth)
SELECT 
    'AUTH USER:' as type,
    id,
    email,
    created_at
FROM auth.users
ORDER BY created_at DESC
LIMIT 5;

-- 2. Check public.users (Your app's user table)
SELECT 
    'APP USER:' as type,
    u.id,
    u.email,
    u.full_name,
    u.callsign,
    u.vehicle_type,
    u.vehicle_color,
    u.team_id,
    u.agency_id,
    t.name as team_name,
    a.name as agency_name
FROM users u
LEFT JOIN teams t ON u.team_id = t.id
LEFT JOIN agencies a ON u.agency_id = a.id
ORDER BY u.created_at DESC
LIMIT 5;

-- 3. Check if there are any orphaned auth users (in auth.users but not in public.users)
SELECT 
    'ORPHANED:' as type,
    au.id,
    au.email,
    'Missing from public.users' as issue
FROM auth.users au
LEFT JOIN users u ON au.id = u.id
WHERE u.id IS NULL
ORDER BY au.created_at DESC;

-- 4. If you see your user above but team_id or agency_id is NULL, run this fix:
-- UNCOMMENT and replace YOUR_USER_ID with your actual ID from the query above

-- UPDATE users
-- SET 
--     team_id = (SELECT id FROM teams WHERE name = 'Default Team'),
--     agency_id = (SELECT id FROM agencies WHERE name = 'Default Agency')
-- WHERE id = 'YOUR_USER_ID'
-- AND (team_id IS NULL OR agency_id IS NULL);

