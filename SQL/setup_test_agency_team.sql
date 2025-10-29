-- =====================================================
-- SETUP DEFAULT TEST AGENCY AND TEAM
-- =====================================================
-- This creates a default agency and team that new users
-- can be assigned to during signup for testing purposes
-- =====================================================

DO $$
DECLARE
    v_agency_id uuid;
    v_team_id uuid;
BEGIN
    -- =====================================================
    -- 1. CREATE DEFAULT TEST AGENCY
    -- =====================================================
    
    SELECT id INTO v_agency_id
    FROM agencies
    WHERE name = 'Test Agency'
    LIMIT 1;
    
    IF v_agency_id IS NULL THEN
        INSERT INTO agencies (name)
        VALUES ('Test Agency')
        RETURNING id INTO v_agency_id;
        
        RAISE NOTICE '✅ Created agency: Test Agency';
        RAISE NOTICE '   ID: %', v_agency_id;
    ELSE
        RAISE NOTICE 'ℹ️  Agency already exists: Test Agency';
        RAISE NOTICE '   ID: %', v_agency_id;
    END IF;
    
    -- =====================================================
    -- 2. CREATE DEFAULT TEST TEAM
    -- =====================================================
    
    SELECT id INTO v_team_id
    FROM teams
    WHERE name = 'Test Team' AND agency_id = v_agency_id
    LIMIT 1;
    
    IF v_team_id IS NULL THEN
        INSERT INTO teams (agency_id, name, active_user_cap_int)
        VALUES (v_agency_id, 'Test Team', 100)
        RETURNING id INTO v_team_id;
        
        RAISE NOTICE '✅ Created team: Test Team';
        RAISE NOTICE '   ID: %', v_team_id;
        RAISE NOTICE '   Capacity: 100 active users';
    ELSE
        RAISE NOTICE 'ℹ️  Team already exists: Test Team';
        RAISE NOTICE '   ID: %', v_team_id;
    END IF;
    
    -- =====================================================
    -- 3. SUMMARY
    -- =====================================================
    
    RAISE NOTICE '';
    RAISE NOTICE '🎉 Setup complete!';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Default Test Setup:';
    RAISE NOTICE '   Agency: Test Agency (ID: %)', v_agency_id;
    RAISE NOTICE '   Team: Test Team (ID: %)', v_team_id;
    RAISE NOTICE '';
    RAISE NOTICE '✅ New users will be assigned to this agency and team during signup';
    
END $$;

-- =====================================================
-- VERIFICATION
-- =====================================================

SELECT 
    a.id as agency_id,
    a.name as agency_name,
    t.id as team_id,
    t.name as team_name,
    t.active_user_cap_int as team_capacity,
    COUNT(u.id) as current_members
FROM agencies a
LEFT JOIN teams t ON t.agency_id = a.id
LEFT JOIN users u ON u.team_id = t.id
WHERE a.name = 'Test Agency'
GROUP BY a.id, a.name, t.id, t.name, t.active_user_cap_int;

