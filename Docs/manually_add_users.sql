-- ============================================
-- Manually Add Missing Users
-- ============================================
-- This will add all auth users who are missing from public.users

-- Step 1: See which users need to be added
SELECT 
    au.id,
    au.email,
    'Will be added' as status
FROM auth.users au
LEFT JOIN users u ON au.id = u.id
WHERE u.id IS NULL
ORDER BY au.created_at;

-- Step 2: Add ALL missing users at once
INSERT INTO users (
    id,
    email,
    full_name,
    callsign,
    vehicle_type,
    vehicle_color,
    agency_id,
    team_id,
    created_at
)
SELECT 
    au.id,
    au.email,
    COALESCE(
        au.raw_user_meta_data->>'full_name',
        split_part(au.email, '@', 1)
    ) as full_name,
    NULL as callsign,
    'sedan' as vehicle_type,
    'black' as vehicle_color,
    (SELECT id FROM agencies WHERE name = 'Default Agency') as agency_id,
    (SELECT id FROM teams WHERE name = 'Default Team') as team_id,
    au.created_at
FROM auth.users au
LEFT JOIN users u ON au.id = u.id
WHERE u.id IS NULL;

-- Step 3: Verify all users are now in public.users
SELECT 
    'Total auth users:' as metric,
    COUNT(*) as count
FROM auth.users
UNION ALL
SELECT 
    'Total public users:' as metric,
    COUNT(*) as count
FROM users
UNION ALL
SELECT 
    'Orphaned (should be 0):' as metric,
    COUNT(*) as count
FROM auth.users au
LEFT JOIN users u ON au.id = u.id
WHERE u.id IS NULL;

-- Step 4: Show all your users with team/agency
SELECT 
    u.email,
    u.full_name,
    t.name as team,
    a.name as agency,
    u.created_at
FROM users u
JOIN teams t ON u.team_id = t.id
JOIN agencies a ON u.agency_id = a.id
ORDER BY u.created_at DESC;

