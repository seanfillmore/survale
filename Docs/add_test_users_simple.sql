-- Add Test Users to Your Team - Simple Version
-- Works without authentication context

-- Step 1: Find the MVP Team and Agency
-- (Adjust if you have a different team name)
DO $$
DECLARE
    mvp_team_id UUID;
    mvp_agency_id UUID;
BEGIN
    -- Get the MVP Team ID (or any team you want to add users to)
    SELECT id INTO mvp_team_id
    FROM teams
    WHERE name = 'MVP Team'
    LIMIT 1;
    
    IF mvp_team_id IS NULL THEN
        RAISE EXCEPTION 'MVP Team not found. Please check your teams table.';
    END IF;
    
    -- Get the MVP Agency ID
    SELECT id INTO mvp_agency_id
    FROM agencies
    WHERE name = 'MVP Agency'
    LIMIT 1;
    
    IF mvp_agency_id IS NULL THEN
        RAISE EXCEPTION 'MVP Agency not found. Please check your agencies table.';
    END IF;
    
    -- Add 3 test users to the team
    INSERT INTO users (id, email, full_name, team_id, agency_id, created_at)
    VALUES
        (gen_random_uuid(), 'officer1@test.com', 'John Smith', mvp_team_id, mvp_agency_id, NOW()),
        (gen_random_uuid(), 'officer2@test.com', 'Jane Doe', mvp_team_id, mvp_agency_id, NOW()),
        (gen_random_uuid(), 'officer3@test.com', 'Mike Johnson', mvp_team_id, mvp_agency_id, NOW())
    ON CONFLICT (email) DO UPDATE
    SET 
        team_id = EXCLUDED.team_id,
        agency_id = EXCLUDED.agency_id,
        full_name = EXCLUDED.full_name;
    
    RAISE NOTICE 'Successfully added 3 test users to MVP Team!';
END $$;

-- Step 2: Verify the users were added
SELECT 
    u.id,
    u.full_name,
    u.email,
    t.name as team_name,
    a.name as agency_name
FROM users u
LEFT JOIN teams t ON u.team_id = t.id
LEFT JOIN agencies a ON u.agency_id = a.id
ORDER BY u.full_name;

