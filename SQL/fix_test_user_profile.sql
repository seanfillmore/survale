-- =====================================================
-- CREATE PROFILE FOR test@test.com
-- =====================================================

-- First, verify the user exists in auth but not in public
SELECT 
    'Users in auth.users but NOT in public.users' as status,
    au.id,
    au.email
FROM auth.users au
WHERE NOT EXISTS (
    SELECT 1 FROM public.users pu WHERE pu.id = au.id
);

-- Create the missing profile
DO $$
DECLARE
    v_user_id uuid := '8da11710-6511-4a82-b290-4e4f874424e9';
    v_email text := 'test@test.com';
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
        RAISE EXCEPTION 'Test Agency and Team not found!';
    END IF;
    
    -- Check if profile already exists
    IF EXISTS (SELECT 1 FROM public.users WHERE id = v_user_id) THEN
        RAISE NOTICE 'ℹ️  Profile already exists for %', v_email;
    ELSE
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
    END IF;
    
END $$;

-- Verify both users now have profiles
SELECT 
    au.email,
    CASE 
        WHEN pu.id IS NOT NULL THEN '✅ Has profile'
        ELSE '❌ Missing profile'
    END as profile_status,
    pu.agency_id,
    pu.team_id
FROM auth.users au
LEFT JOIN public.users pu ON pu.id = au.id
ORDER BY au.created_at DESC;

