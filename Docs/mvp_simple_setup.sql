-- ============================================
-- MVP SIMPLE SETUP - No Teams/Agencies Required
-- ============================================
-- This creates a simplified trigger for MVP testing
-- All users get a single default team/agency automatically

-- STEP 1: Create ONE default agency and team for MVP
INSERT INTO agencies (name, created_at)
VALUES ('MVP Agency', NOW())
ON CONFLICT DO NOTHING;

INSERT INTO teams (agency_id, name, created_at)
SELECT 
    a.id,
    'MVP Team',
    NOW()
FROM agencies a
WHERE a.name = 'MVP Agency'
ON CONFLICT DO NOTHING;

-- Verify they exist
SELECT 'Agency Created:' as status, id, name FROM agencies WHERE name = 'MVP Agency'
UNION ALL
SELECT 'Team Created:' as status, id, name FROM teams WHERE name = 'MVP Team';

-- STEP 2: Simple trigger - just adds users to MVP Team
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    mvp_agency_id UUID;
    mvp_team_id UUID;
BEGIN
    -- Get the single MVP agency/team
    SELECT id INTO mvp_agency_id FROM agencies WHERE name = 'MVP Agency';
    SELECT id INTO mvp_team_id FROM teams WHERE name = 'MVP Team';
    
    -- If they don't exist, something is wrong
    IF mvp_agency_id IS NULL OR mvp_team_id IS NULL THEN
        RAISE WARNING 'MVP Agency or Team not found. Run setup script first.';
        RETURN NEW;
    END IF;
    
    -- Insert user record
    INSERT INTO public.users (
        id, 
        email,
        full_name,
        agency_id,
        team_id,
        vehicle_type,
        vehicle_color,
        created_at
    )
    VALUES (
        NEW.id, 
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        mvp_agency_id,
        mvp_team_id,
        'sedan',
        'black',
        NOW()
    )
    ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email;
    
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error adding user %: %', NEW.email, SQLERRM;
        RETURN NEW;
END;
$$;

-- STEP 3: Attach trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW 
    EXECUTE FUNCTION public.handle_new_user();

-- STEP 4: Add all existing orphaned users to MVP Team
INSERT INTO users (
    id, email, full_name, agency_id, team_id, 
    vehicle_type, vehicle_color, created_at
)
SELECT 
    au.id,
    au.email,
    COALESCE(au.raw_user_meta_data->>'full_name', split_part(au.email, '@', 1)),
    (SELECT id FROM agencies WHERE name = 'MVP Agency'),
    (SELECT id FROM teams WHERE name = 'MVP Team'),
    'sedan',
    'black',
    au.created_at
FROM auth.users au
LEFT JOIN users u ON au.id = u.id
WHERE u.id IS NULL;

-- STEP 5: Update existing users who might have NULL team/agency
UPDATE users
SET 
    agency_id = (SELECT id FROM agencies WHERE name = 'MVP Agency'),
    team_id = (SELECT id FROM teams WHERE name = 'MVP Team')
WHERE agency_id IS NULL OR team_id IS NULL;

-- STEP 6: Verify everything worked
SELECT '✅ SETUP COMPLETE!' as status;

SELECT 
    'Auth Users:' as metric,
    COUNT(*) as count
FROM auth.users
UNION ALL
SELECT 
    'Public Users:' as metric,
    COUNT(*) as count
FROM users
UNION ALL
SELECT 
    'Orphaned (should be 0):' as metric,
    COUNT(*) as count
FROM auth.users au
LEFT JOIN users u ON au.id = u.id
WHERE u.id IS NULL;

-- Show all users in MVP Team
SELECT 
    u.email,
    u.full_name,
    u.vehicle_type,
    u.vehicle_color,
    t.name as team,
    a.name as agency,
    u.created_at
FROM users u
JOIN teams t ON u.team_id = t.id
JOIN agencies a ON u.agency_id = a.id
ORDER BY u.created_at;

SELECT '🚀 All users are now in MVP Team! Ready to test.' as result;

