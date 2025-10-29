-- =====================================================
-- FIX AUTH TRIGGER FOR USER CREATION
-- =====================================================
-- This script creates/replaces the trigger that automatically
-- creates a user record when someone signs up
-- =====================================================

-- First, drop any existing trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Drop the old function if it exists
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- Create the new trigger function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    default_agency_id uuid;
    default_team_id uuid;
BEGIN
    -- Get the default "Test Agency" and "Test Team" IDs
    SELECT a.id, t.id INTO default_agency_id, default_team_id
    FROM agencies a
    JOIN teams t ON t.agency_id = a.id
    WHERE a.name = 'Test Agency'
      AND t.name = 'Test Team'
    LIMIT 1;
    
    -- If no default agency/team exists, raise an error
    IF default_agency_id IS NULL OR default_team_id IS NULL THEN
        RAISE EXCEPTION 'Default test agency and team not found. Please run setup_test_agency_team.sql first';
    END IF;
    
    -- Insert the new user record with default agency and team
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
    
    RETURN NEW;
END;
$$;

-- Create the trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;

DO $$
BEGIN
    RAISE NOTICE '✅ Auth trigger created successfully!';
    RAISE NOTICE '';
    RAISE NOTICE '📝 How it works:';
    RAISE NOTICE '   1. User signs up in Supabase Auth';
    RAISE NOTICE '   2. Trigger automatically creates user record in public.users';
    RAISE NOTICE '   3. User is assigned to "Test Agency" and "Test Team"';
    RAISE NOTICE '   4. App can then update additional profile info (name, callsign, etc.)';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  Make sure you run setup_test_agency_team.sql first!';
END $$;

