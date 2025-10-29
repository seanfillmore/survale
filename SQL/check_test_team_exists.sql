-- =====================================================
-- CHECK IF TEST TEAM EXISTS
-- =====================================================

SELECT 
    a.id as agency_id,
    a.name as agency_name,
    t.id as team_id,
    t.name as team_name
FROM agencies a
LEFT JOIN teams t ON t.agency_id = a.id
WHERE a.name = 'Test Agency';

DO $$
DECLARE
    team_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM teams WHERE name = 'Test Team'
    ) INTO team_exists;
    
    IF team_exists THEN
        RAISE NOTICE '✅ Test Team exists';
    ELSE
        RAISE NOTICE '❌ Test Team does NOT exist!';
        RAISE NOTICE '   Run setup_test_agency_team.sql to create it';
    END IF;
END $$;

