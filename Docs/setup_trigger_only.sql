-- ============================================
-- Survale Database Setup (Trigger Only)
-- ============================================
-- This script adds ONLY the auto-signup trigger to your existing database
-- Use this if your tables already exist and match the schema

-- ============================================
-- 1. AUTO-SIGNUP TRIGGER
-- ============================================

-- Function to create user record when auth user is created
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    default_agency_id UUID;
    default_team_id UUID;
BEGIN
    -- Get or create default agency
    SELECT id INTO default_agency_id 
    FROM agencies 
    WHERE name = 'Default Agency' 
    LIMIT 1;
    
    IF default_agency_id IS NULL THEN
        INSERT INTO agencies (name) 
        VALUES ('Default Agency') 
        RETURNING id INTO default_agency_id;
    END IF;
    
    -- Get or create default team
    SELECT id INTO default_team_id 
    FROM teams 
    WHERE agency_id = default_agency_id 
    AND name = 'Default Team' 
    LIMIT 1;
    
    IF default_team_id IS NULL THEN
        INSERT INTO teams (agency_id, name) 
        VALUES (default_agency_id, 'Default Team') 
        RETURNING id INTO default_team_id;
    END IF;
    
    -- Insert user record
    INSERT INTO public.users (
        id, 
        email, 
        team_id, 
        agency_id, 
        vehicle_type, 
        vehicle_color
    )
    VALUES (
        NEW.id, 
        NEW.email, 
        default_team_id, 
        default_agency_id, 
        'sedan', 
        'black'
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW 
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 2. ENABLE REALTIME (if not already enabled)
-- ============================================

-- Enable realtime for locations_stream
ALTER PUBLICATION supabase_realtime ADD TABLE locations_stream;

-- Enable realtime for op_messages
ALTER PUBLICATION supabase_realtime ADD TABLE op_messages;

-- ============================================
-- 3. VERIFY SETUP
-- ============================================

-- Check if trigger was created
SELECT 
    trigger_name, 
    event_manipulation, 
    event_object_table 
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- Check if default agency/team exist
SELECT 'Agency:', name FROM agencies WHERE name = 'Default Agency'
UNION ALL
SELECT 'Team:', name FROM teams WHERE name = 'Default Team';

-- Done!
SELECT '✅ Setup complete! New signups will automatically get user records.' as status;

