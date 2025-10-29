-- =====================================================
-- AUTO-FIX INCOMPLETE SIGNUPS
-- =====================================================
-- Run this script after any failed signup to automatically
-- create the missing public.users profiles
-- =====================================================

DO $$
DECLARE
    v_agency_id uuid;
    v_team_id uuid;
    v_record RECORD;
    v_count int := 0;
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
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'AUTO-FIXING INCOMPLETE SIGNUPS';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- Find all auth users without public.users profiles
    FOR v_record IN (
        SELECT au.id, au.email
        FROM auth.users au
        WHERE NOT EXISTS (
            SELECT 1 FROM public.users pu WHERE pu.id = au.id
        )
    ) LOOP
        -- Create the missing profile
        INSERT INTO public.users (
            id,
            email,
            agency_id,
            team_id,
            created_at
        ) VALUES (
            v_record.id,
            v_record.email,
            v_agency_id,
            v_team_id,
            NOW()
        );
        
        v_count := v_count + 1;
        RAISE NOTICE '✅ Created profile for: % (ID: %)', v_record.email, v_record.id;
    END LOOP;
    
    RAISE NOTICE '';
    IF v_count = 0 THEN
        RAISE NOTICE '✅ No incomplete signups found - all users have profiles!';
    ELSE
        RAISE NOTICE '✅ Fixed % incomplete signup(s)', v_count;
    END IF;
    RAISE NOTICE '';
    
END $$;

-- Show all users and their status
SELECT 
    au.email,
    CASE 
        WHEN pu.id IS NOT NULL THEN '✅ Complete'
        ELSE '❌ Incomplete'
    END as signup_status,
    au.created_at
FROM auth.users au
LEFT JOIN public.users pu ON pu.id = au.id
ORDER BY au.created_at DESC;

