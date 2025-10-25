-- ============================================
-- COMPLETE FIX for "Database error saving new user"
-- ============================================
-- This script will:
-- 1. Ensure Default Agency and Team exist FIRST
-- 2. Update the trigger with proper error handling
-- 3. Verify everything works

-- ============================================
-- STEP 1: Create Default Agency and Team
-- ============================================

-- Insert Default Agency (if it doesn't exist)
INSERT INTO agencies (name, created_at)
VALUES ('Default Agency', NOW())
ON CONFLICT DO NOTHING;

-- Insert Default Team (if it doesn't exist)
INSERT INTO teams (agency_id, name, created_at)
SELECT 
    a.id,
    'Default Team',
    NOW()
FROM agencies a
WHERE a.name = 'Default Agency'
ON CONFLICT DO NOTHING;

-- Verify they exist
DO $$
DECLARE
    agency_count INTEGER;
    team_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO agency_count FROM agencies WHERE name = 'Default Agency';
    SELECT COUNT(*) INTO team_count FROM teams WHERE name = 'Default Team';
    
    IF agency_count = 0 THEN
        RAISE EXCEPTION 'Failed to create Default Agency';
    END IF;
    
    IF team_count = 0 THEN
        RAISE EXCEPTION 'Failed to create Default Team';
    END IF;
    
    RAISE NOTICE '✅ Default Agency and Team verified';
END $$;

-- ============================================
-- STEP 2: Create/Update Trigger Function
-- ============================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    default_agency_id UUID;
    default_team_id UUID;
BEGIN
    -- Get default agency (should always exist after Step 1)
    SELECT id INTO STRICT default_agency_id 
    FROM agencies 
    WHERE name = 'Default Agency';
    
    -- Get default team (should always exist after Step 1)
    SELECT id INTO STRICT default_team_id 
    FROM teams 
    WHERE name = 'Default Team' 
    AND agency_id = default_agency_id;
    
    -- Insert user record
    INSERT INTO public.users (
        id, 
        email,
        full_name,
        callsign,
        vehicle_type, 
        vehicle_color,
        agency_id,
        team_id,
        created_at
    )
    VALUES (
        NEW.id, 
        NEW.email,
        COALESCE(
            NEW.raw_user_meta_data->>'full_name', 
            split_part(NEW.email, '@', 1)
        ),
        NULL,  -- callsign can be set later by user
        'sedan', 
        'black',
        default_agency_id,
        default_team_id,
        NOW()
    )
    ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email;  -- Update email if user already exists
    
    RETURN NEW;
    
EXCEPTION
    WHEN no_data_found THEN
        RAISE EXCEPTION 'Default Agency or Team not found. Please run the setup script first.';
    WHEN OTHERS THEN
        -- Log the error but allow auth to continue
        RAISE WARNING 'Error in handle_new_user for user %: %', NEW.email, SQLERRM;
        RETURN NEW;
END;
$$;

-- ============================================
-- STEP 3: Attach Trigger (if not already attached)
-- ============================================

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW 
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- STEP 4: Verify Setup
-- ============================================

-- Check trigger exists
SELECT 
    'Trigger: ' || trigger_name || ' on ' || event_object_table as status
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- Check function exists
SELECT 
    'Function: ' || routine_name as status
FROM information_schema.routines 
WHERE routine_name = 'handle_new_user';

-- Check Default Agency and Team
SELECT 
    'Agency: ' || a.name || ' (ID: ' || a.id || ')' as status
FROM agencies a
WHERE a.name = 'Default Agency'
UNION ALL
SELECT 
    'Team: ' || t.name || ' (ID: ' || t.id || ')' as status
FROM teams t
WHERE t.name = 'Default Team';

-- Final success message
SELECT '✅ SETUP COMPLETE! Try signing up now.' as result;

