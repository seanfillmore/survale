-- =====================================================
-- CREATE MISSING USER PROFILE
-- =====================================================
-- This creates the public.users record for the user
-- that exists in auth.users but not in public.users
-- =====================================================

DO $$
DECLARE
    v_user_id uuid := '12f34d44-d2a6-4b0a-bed1-244d4a61e699';
    v_email text := 'sean.fillmore@ventura.org';
    v_agency_id uuid;
    v_team_id uuid;
BEGIN
    -- Get the default agency and team
    SELECT a.id, t.id INTO v_agency_id, v_team_id
    FROM agencies a
    JOIN teams t ON t.agency_id = a.id
    WHERE a.name = 'Test Agency'
      AND t.name = 'Test Team'
    LIMIT 1;
    
    IF v_agency_id IS NULL OR v_team_id IS NULL THEN
        RAISE EXCEPTION 'Test Agency and Team not found! Run setup_test_agency_team.sql first';
    END IF;
    
    -- Create the user record
    INSERT INTO public.users (
        id,
        email,
        agency_id,
        team_id,
        created_at
    ) VALUES (
        v_user_id,
        v_email,
        v_agency_id,
        v_team_id,
        NOW()
    );
    
    RAISE NOTICE '✅ Created user profile for %', v_email;
    RAISE NOTICE '   User ID: %', v_user_id;
    RAISE NOTICE '   Agency: %', v_agency_id;
    RAISE NOTICE '   Team: %', v_team_id;
    RAISE NOTICE '';
    RAISE NOTICE '📱 Now try opening Settings in the app';
    RAISE NOTICE '   You can update your profile information there';
    
END $$;

-- Verify it was created
SELECT 
    id,
    email,
    first_name,
    last_name,
    callsign,
    phone_number,
    agency_id,
    team_id
FROM public.users
WHERE id = '12f34d44-d2a6-4b0a-bed1-244d4a61e699';
