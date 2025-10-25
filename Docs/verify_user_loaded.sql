-- ============================================
-- Verify Your User Is Loaded Correctly
-- ============================================

-- 1. Check if your user exists in public.users with team/agency
SELECT 
    u.id,
    u.email,
    u.full_name,
    u.team_id,
    u.agency_id,
    t.name as team_name,
    a.name as agency_name,
    CASE 
        WHEN u.team_id IS NULL THEN '❌ NO TEAM'
        WHEN u.agency_id IS NULL THEN '❌ NO AGENCY'
        ELSE '✅ HAS TEAM & AGENCY'
    END as status
FROM users u
LEFT JOIN teams t ON u.team_id = t.id
LEFT JOIN agencies a ON u.agency_id = a.id
ORDER BY u.created_at DESC;

-- 2. Show the exact team/agency IDs you should have
SELECT 
    'Expected Team ID:' as label,
    id::text as value,
    name
FROM teams 
WHERE name = 'MVP Team'
UNION ALL
SELECT 
    'Expected Agency ID:' as label,
    id::text as value,
    name
FROM agencies 
WHERE name = 'MVP Agency';

