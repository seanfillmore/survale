-- ============================================
-- Fix Your User Record Manually
-- ============================================
-- Use this if your user exists but isn't assigned to a team/agency

-- STEP 1: Find your user ID
-- Run this first and copy your ID
SELECT 
    id,
    email,
    team_id,
    agency_id
FROM users
WHERE email = 'YOUR_EMAIL_HERE';  -- Replace with your email

-- STEP 2: Update your user with team/agency
-- Replace YOUR_USER_ID with the ID from Step 1
UPDATE users
SET 
    team_id = (SELECT id FROM teams WHERE name = 'Default Team'),
    agency_id = (SELECT id FROM agencies WHERE name = 'Default Agency'),
    vehicle_type = COALESCE(vehicle_type, 'sedan'),
    vehicle_color = COALESCE(vehicle_color, 'black')
WHERE id = 'YOUR_USER_ID';  -- Replace with your ID from Step 1

-- STEP 3: Verify the fix
SELECT 
    u.id,
    u.email,
    u.team_id,
    u.agency_id,
    t.name as team_name,
    a.name as agency_name
FROM users u
LEFT JOIN teams t ON u.team_id = t.id
LEFT JOIN agencies a ON u.agency_id = a.id
WHERE u.email = 'YOUR_EMAIL_HERE';  -- Replace with your email

-- Should now show:
-- team_name: Default Team
-- agency_name: Default Agency

