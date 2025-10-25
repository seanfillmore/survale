-- Check Your Teams and Agencies
-- Run this first to see what teams exist

-- 1. List all agencies
SELECT '=== AGENCIES ===' as section;
SELECT id, name, created_at
FROM agencies
ORDER BY name;

-- 2. List all teams
SELECT '=== TEAMS ===' as section;
SELECT t.id, t.name, a.name as agency_name, t.created_at
FROM teams t
LEFT JOIN agencies a ON t.agency_id = a.id
ORDER BY t.name;

-- 3. List all users
SELECT '=== USERS ===' as section;
SELECT 
    u.id,
    u.email,
    u.full_name,
    t.name as team_name,
    a.name as agency_name
FROM users u
LEFT JOIN teams t ON u.team_id = t.id
LEFT JOIN agencies a ON u.agency_id = a.id
ORDER BY u.full_name;

-- 4. Count by team
SELECT '=== USER COUNT BY TEAM ===' as section;
SELECT 
    t.name as team_name,
    COUNT(u.id) as user_count
FROM teams t
LEFT JOIN users u ON u.team_id = t.id
GROUP BY t.id, t.name
ORDER BY user_count DESC, t.name;

