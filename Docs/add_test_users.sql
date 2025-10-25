-- Add Test Users to Your Team
-- This helps test the team member selection feature

-- Get your current team ID
DO $$
DECLARE
    my_team_id UUID;
    my_agency_id UUID;
BEGIN
    -- Get your team and agency
    SELECT team_id, agency_id INTO my_team_id, my_agency_id
    FROM users
    WHERE id = auth.uid();
    
    IF my_team_id IS NULL THEN
        RAISE EXCEPTION 'Current user not assigned to team';
    END IF;
    
    -- Add 3 test users to your team
    INSERT INTO users (id, email, full_name, badge_number, team_id, agency_id)
    VALUES
        (gen_random_uuid(), 'officer1@test.com', 'John Smith', 'BADGE001', my_team_id, my_agency_id),
        (gen_random_uuid(), 'officer2@test.com', 'Jane Doe', 'BADGE002', my_team_id, my_agency_id),
        (gen_random_uuid(), 'officer3@test.com', 'Mike Johnson', 'BADGE003', my_team_id, my_agency_id)
    ON CONFLICT (email) DO UPDATE
    SET team_id = my_team_id, agency_id = my_agency_id;
    
    RAISE NOTICE 'Added 3 test users to your team (%)!', my_team_id;
END $$;

-- Verify the users were added
SELECT 
    u.full_name,
    u.email,
    u.badge_number,
    t.name as team_name
FROM users u
JOIN teams t ON u.team_id = t.id
WHERE u.team_id = (SELECT team_id FROM users WHERE id = auth.uid())
ORDER BY u.full_name;

