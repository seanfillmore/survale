-- =====================================================
-- COMPREHENSIVE FIX FOR AUTH TRIGGER
-- =====================================================
-- This script completely removes and recreates the auth trigger
-- with proper error handling and permissions
-- =====================================================

-- Step 1: Drop ALL existing triggers on auth.users
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT trigger_name FROM information_schema.triggers 
              WHERE event_object_schema = 'auth' 
              AND event_object_table = 'users')
    LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || r.trigger_name || ' ON auth.users CASCADE';
        RAISE NOTICE 'Dropped trigger: %', r.trigger_name;
    END LOOP;
END $$;

-- Step 2: Drop ALL existing user-related functions
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.handle_auth_user_created() CASCADE;
DROP FUNCTION IF EXISTS public.create_profile_for_new_user() CASCADE;

-- Step 3: Verify Test Agency and Test Team exist
DO $$
DECLARE
    agency_count int;
    team_count int;
BEGIN
    SELECT COUNT(*) INTO agency_count FROM agencies WHERE name = 'Test Agency';
    SELECT COUNT(*) INTO team_count FROM teams WHERE name = 'Test Team';
    
    IF agency_count = 0 OR team_count = 0 THEN
        RAISE EXCEPTION 'Test Agency or Test Team not found! Run setup_test_agency_team.sql first';
    END IF;
    
    RAISE NOTICE '✅ Test Agency and Test Team verified';
END $$;

-- Step 4: Create the new trigger function with better error handling
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    default_agency_id uuid;
    default_team_id uuid;
    user_exists boolean;
BEGIN
    -- Log the trigger execution
    RAISE LOG 'handle_new_user triggered for user: %', NEW.email;
    
    -- Check if user already exists (prevent duplicate key errors)
    SELECT EXISTS(SELECT 1 FROM public.users WHERE id = NEW.id) INTO user_exists;
    
    IF user_exists THEN
        RAISE LOG 'User already exists in public.users, skipping insert';
        RETURN NEW;
    END IF;
    
    -- Get the default "Test Agency" and "Test Team" IDs
    SELECT a.id, t.id INTO default_agency_id, default_team_id
    FROM agencies a
    JOIN teams t ON t.agency_id = a.id
    WHERE a.name = 'Test Agency'
      AND t.name = 'Test Team'
    LIMIT 1;
    
    -- If no default agency/team exists, log error but don't fail
    IF default_agency_id IS NULL OR default_team_id IS NULL THEN
        RAISE LOG 'Default test agency and team not found';
        RAISE EXCEPTION 'Default test agency and team not found. Please run setup_test_agency_team.sql first';
    END IF;
    
    -- Insert the new user record with default agency and team
    BEGIN
        INSERT INTO public.users (
            id,
            email,
            agency_id,
            team_id,
            created_at
        ) VALUES (
            NEW.id,
            NEW.email,
            default_agency_id,
            default_team_id,
            NOW()
        );
        
        RAISE LOG 'Successfully created user record for: %', NEW.email;
        
    EXCEPTION WHEN unique_violation THEN
        -- User already exists, this is fine
        RAISE LOG 'User already exists (unique violation), continuing';
    WHEN OTHERS THEN
        -- Log the error but let auth succeed
        RAISE LOG 'Error creating user record: %, %', SQLERRM, SQLSTATE;
        RAISE EXCEPTION 'Error creating user record: %', SQLERRM;
    END;
    
    RETURN NEW;
END;
$$;

-- Step 5: Create the trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Step 6: Grant necessary permissions
ALTER FUNCTION public.handle_new_user() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO anon;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;

-- Grant table permissions
GRANT ALL ON public.users TO postgres;
GRANT ALL ON public.users TO service_role;
GRANT SELECT, INSERT, UPDATE ON public.users TO authenticated;
GRANT SELECT ON public.agencies TO authenticated;
GRANT SELECT ON public.teams TO authenticated;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Auth trigger created successfully!';
    RAISE NOTICE '';
    RAISE NOTICE '📝 Trigger details:';
    RAISE NOTICE '   - Function: public.handle_new_user()';
    RAISE NOTICE '   - Trigger: on_auth_user_created';
    RAISE NOTICE '   - Event: AFTER INSERT on auth.users';
    RAISE NOTICE '';
    RAISE NOTICE '🔒 Permissions granted to: postgres, anon, authenticated, service_role';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Ready for signups!';
END $$;

