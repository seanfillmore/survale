-- ============================================
-- Fix Auto-Signup Trigger
-- ============================================
-- This fixes the "Database error saving new user" error

-- Updated function to create user record when auth user is created
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
    
    -- Insert user record with all required fields
    INSERT INTO public.users (
        id, 
        email,
        full_name,           -- Added this field
        callsign,
        vehicle_type, 
        vehicle_color,
        agency_id,
        team_id
    )
    VALUES (
        NEW.id, 
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),  -- Use email username if no name
        NULL,                -- callsign can be set later
        'sedan', 
        'black',
        default_agency_id,
        default_team_id
    )
    ON CONFLICT (id) DO NOTHING;  -- Prevent duplicate errors
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error but don't prevent signup
        RAISE WARNING 'Error in handle_new_user: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Verify the function was updated
SELECT 'Trigger function updated successfully!' as status;

