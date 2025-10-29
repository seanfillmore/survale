-- =====================================================
-- CREATE TEST USER WITH AGENCY AND TEAM
-- =====================================================
-- This script creates a complete test user setup:
-- 1. Agency
-- 2. Team
-- 3. User record (linked to the auth.users ID)
-- =====================================================

DO $$
DECLARE
    v_agency_id uuid;
    v_team_id uuid;
    v_user_auth_id uuid;
    v_user_email text;
BEGIN
    -- =====================================================
    -- CONFIGURATION - UPDATE THESE VALUES
    -- =====================================================
    
    -- Get the auth user ID and email from auth.users
    -- Replace 'your-email@example.com' with the actual email you used to sign up
    SELECT id, email INTO v_user_auth_id, v_user_email
    FROM auth.users
    WHERE email = 'test@test.com'  -- ⚠️ CHANGE THIS TO YOUR EMAIL
    LIMIT 1;
    
    IF v_user_auth_id IS NULL THEN
        RAISE EXCEPTION 'Auth user not found! Please sign up first in the app, then run this script.';
    END IF;
    
    RAISE NOTICE '✅ Found auth user: % (ID: %)', v_user_email, v_user_auth_id;
    
    -- =====================================================
    -- 1. CREATE AGENCY (if it doesn't exist)
    -- =====================================================
    
    SELECT id INTO v_agency_id
    FROM agencies
    WHERE name = 'Test Agency'
    LIMIT 1;
    
    IF v_agency_id IS NULL THEN
        INSERT INTO agencies (name)
        VALUES ('Test Agency')
        RETURNING id INTO v_agency_id;
        
        RAISE NOTICE '✅ Created agency: Test Agency (ID: %)', v_agency_id;
    ELSE
        RAISE NOTICE 'ℹ️  Using existing agency: Test Agency (ID: %)', v_agency_id;
    END IF;
    
    -- =====================================================
    -- 2. CREATE TEAM (if it doesn't exist)
    -- =====================================================
    
    SELECT id INTO v_team_id
    FROM teams
    WHERE name = 'Test Team' AND agency_id = v_agency_id
    LIMIT 1;
    
    IF v_team_id IS NULL THEN
        INSERT INTO teams (agency_id, name, active_user_cap_int)
        VALUES (v_agency_id, 'Test Team', 50)
        RETURNING id INTO v_team_id;
        
        RAISE NOTICE '✅ Created team: Test Team (ID: %)', v_team_id;
    ELSE
        RAISE NOTICE 'ℹ️  Using existing team: Test Team (ID: %)', v_team_id;
    END IF;
    
    -- =====================================================
    -- 3. CREATE OR UPDATE USER RECORD
    -- =====================================================
    
    -- Check if user record already exists
    IF EXISTS (SELECT 1 FROM users WHERE id = v_user_auth_id) THEN
        -- Update existing user
        UPDATE users
        SET 
            email = v_user_email,
            first_name = 'Test',
            last_name = 'User',
            full_name = 'Test User',
            callsign = 'ALPHA-1',
            phone_number = '+1-555-0100',
            vehicle_type = 'sedan',
            vehicle_color = 'black',
            agency_id = v_agency_id,
            team_id = v_team_id
        WHERE id = v_user_auth_id;
        
        RAISE NOTICE '✅ Updated existing user record';
    ELSE
        -- Create new user record
        INSERT INTO users (
            id,
            email,
            first_name,
            last_name,
            full_name,
            callsign,
            phone_number,
            vehicle_type,
            vehicle_color,
            agency_id,
            team_id
        ) VALUES (
            v_user_auth_id,
            v_user_email,
            'Test',
            'User',
            'Test User',
            'ALPHA-1',
            '+1-555-0100',
            'sedan',
            'black',
            v_agency_id,
            v_team_id
        );
        
        RAISE NOTICE '✅ Created new user record';
    END IF;
    
    -- =====================================================
    -- VERIFICATION
    -- =====================================================
    
    RAISE NOTICE '';
    RAISE NOTICE '🎉 User setup complete!';
    RAISE NOTICE '   Email: %', v_user_email;
    RAISE NOTICE '   User ID: %', v_user_auth_id;
    RAISE NOTICE '   Agency: Test Agency (ID: %)', v_agency_id;
    RAISE NOTICE '   Team: Test Team (ID: %)', v_team_id;
    RAISE NOTICE '';
    RAISE NOTICE '✅ You should now be able to log in successfully!';
    
END $$;

-- =====================================================
-- VERIFICATION QUERY
-- =====================================================

SELECT 
    u.id,
    u.email,
    u.first_name,
    u.last_name,
    u.callsign,
    u.phone_number,
    u.vehicle_type,
    u.vehicle_color,
    a.name as agency_name,
    t.name as team_name
FROM users u
JOIN agencies a ON u.agency_id = a.id
JOIN teams t ON u.team_id = t.id
ORDER BY u.created_at DESC;

