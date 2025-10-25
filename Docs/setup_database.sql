-- ============================================
-- Survale Database Setup Script
-- Run this in your Supabase SQL Editor
-- ============================================

-- ============================================
-- 1. CREATE TABLES
-- ============================================

-- Agencies Table
CREATE TABLE IF NOT EXISTS public.agencies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Teams Table
CREATE TABLE IF NOT EXISTS public.teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id UUID NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Users Table
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    team_id UUID NOT NULL REFERENCES teams(id),
    agency_id UUID NOT NULL REFERENCES agencies(id),
    callsign TEXT,
    vehicle_type TEXT NOT NULL DEFAULT 'sedan',
    vehicle_color TEXT NOT NULL DEFAULT 'black',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Operations Table
CREATE TABLE IF NOT EXISTS public.operations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id UUID NOT NULL REFERENCES agencies(id),
    team_id UUID NOT NULL REFERENCES teams(id),
    case_agent_id UUID NOT NULL REFERENCES users(id),  -- Changed from 'created_by_user_id'
    incident_number TEXT,
    name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft',  -- Changed from 'state'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,  -- Changed from 'starts_at'
    ended_at TIMESTAMPTZ,    -- Changed from 'ends_at'
    join_code TEXT UNIQUE    -- Made optional (nullable) - will add via separate migration if needed
);

-- Operation Members Table
CREATE TABLE IF NOT EXISTS public.operation_members (
    operation_id UUID NOT NULL REFERENCES operations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    role TEXT NOT NULL CHECK (role = ANY (ARRAY['case_agent'::text, 'member'::text])),
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    PRIMARY KEY (operation_id, user_id)  -- Composite primary key, no separate id column
);

-- Locations Stream Table (for real-time location tracking)
CREATE TABLE IF NOT EXISTS public.locations_stream (
    id BIGSERIAL PRIMARY KEY,  -- Changed from UUID to match your schema
    operation_id UUID NOT NULL REFERENCES operations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),  -- Changed from 'timestamp'
    lat DOUBLE PRECISION NOT NULL,          -- Changed from 'latitude'
    lon DOUBLE PRECISION NOT NULL,          -- Changed from 'longitude'
    accuracy_m DOUBLE PRECISION,            -- Changed from 'accuracy'
    speed_mps DOUBLE PRECISION,             -- Changed from 'speed'
    heading_deg DOUBLE PRECISION            -- Changed from 'heading'
);

-- Messages Table (for chat)
CREATE TABLE IF NOT EXISTS public.op_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_id UUID NOT NULL REFERENCES operations(id) ON DELETE CASCADE,
    sender_user_id UUID NOT NULL REFERENCES users(id),  -- Changed from 'user_id'
    body_text TEXT,                                      -- Changed from 'content'
    media_path TEXT,
    media_type TEXT NOT NULL DEFAULT 'text',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Targets Tables
CREATE TABLE IF NOT EXISTS public.targets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_id UUID NOT NULL REFERENCES operations(id) ON DELETE CASCADE,
    kind TEXT NOT NULL,
    label TEXT NOT NULL,
    notes TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    address TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Staging Areas Table
CREATE TABLE IF NOT EXISTS public.staging_areas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_id UUID NOT NULL REFERENCES operations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 2. ENABLE ROW LEVEL SECURITY
-- ============================================

ALTER TABLE agencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE operations ENABLE ROW LEVEL SECURITY;
ALTER TABLE operation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE locations_stream ENABLE ROW LEVEL SECURITY;
ALTER TABLE op_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE staging_areas ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 3. CREATE RLS POLICIES
-- ============================================

-- Agencies: Users can view their own agency
DROP POLICY IF EXISTS "Users can view own agency" ON agencies;
CREATE POLICY "Users can view own agency"
ON agencies FOR SELECT
USING (id IN (SELECT agency_id FROM users WHERE id = auth.uid()));

-- Teams: Users can view their own team
DROP POLICY IF EXISTS "Users can view own team" ON teams;
CREATE POLICY "Users can view own team"
ON teams FOR SELECT
USING (id IN (SELECT team_id FROM users WHERE id = auth.uid()));

-- Users: Can view team members
DROP POLICY IF EXISTS "Users can view team members" ON users;
CREATE POLICY "Users can view team members"
ON users FOR SELECT
USING (team_id IN (SELECT team_id FROM users WHERE id = auth.uid()));

-- Users: Can update own record
DROP POLICY IF EXISTS "Users can update own record" ON users;
CREATE POLICY "Users can update own record"
ON users FOR UPDATE
USING (id = auth.uid());

-- Operations: Users can view operations they're members of
DROP POLICY IF EXISTS "Users can view operations" ON operations;
CREATE POLICY "Users can view operations"
ON operations FOR SELECT
USING (
    id IN (
        SELECT operation_id FROM operation_members WHERE user_id = auth.uid()
    )
    OR case_agent_id = auth.uid()  -- Changed from 'created_by_user_id'
);

-- Operation Members: Can view members of their operations
DROP POLICY IF EXISTS "Users can view operation members" ON operation_members;
CREATE POLICY "Users can view operation members"
ON operation_members FOR SELECT
USING (
    operation_id IN (
        SELECT operation_id FROM operation_members WHERE user_id = auth.uid()
    )
);

-- Locations: Operation members can view and insert
DROP POLICY IF EXISTS "Operation members can view locations" ON locations_stream;
CREATE POLICY "Operation members can view locations"
ON locations_stream FOR SELECT
USING (
    operation_id IN (
        SELECT operation_id FROM operation_members WHERE user_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Operation members can insert locations" ON locations_stream;
CREATE POLICY "Operation members can insert locations"
ON locations_stream FOR INSERT
WITH CHECK (user_id = auth.uid());

-- Messages: Operation members can view and insert
DROP POLICY IF EXISTS "Operation members can view messages" ON op_messages;
CREATE POLICY "Operation members can view messages"
ON op_messages FOR SELECT
USING (
    operation_id IN (
        SELECT operation_id FROM operation_members WHERE user_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Operation members can insert messages" ON op_messages;
CREATE POLICY "Operation members can insert messages"
ON op_messages FOR INSERT
WITH CHECK (
    sender_user_id = auth.uid() AND  -- Changed from 'user_id'
    operation_id IN (
        SELECT operation_id FROM operation_members WHERE user_id = auth.uid()
    )
);

-- Targets: Operation members can view
DROP POLICY IF EXISTS "Operation members can view targets" ON targets;
CREATE POLICY "Operation members can view targets"
ON targets FOR SELECT
USING (
    operation_id IN (
        SELECT operation_id FROM operation_members WHERE user_id = auth.uid()
    )
);

-- Staging Areas: Operation members can view
DROP POLICY IF EXISTS "Operation members can view staging areas" ON staging_areas;
CREATE POLICY "Operation members can view staging areas"
ON staging_areas FOR SELECT
USING (
    operation_id IN (
        SELECT operation_id FROM operation_members WHERE user_id = auth.uid()
    )
);

-- ============================================
-- 4. ENABLE REALTIME
-- ============================================

-- Enable realtime for locations and messages
ALTER PUBLICATION supabase_realtime ADD TABLE locations_stream;
ALTER PUBLICATION supabase_realtime ADD TABLE op_messages;

-- ============================================
-- 5. CREATE TRIGGER FOR AUTO USER CREATION
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
    INSERT INTO public.users (id, email, team_id, agency_id, vehicle_type, vehicle_color)
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
-- 6. INSERT TEST DATA (OPTIONAL - for existing users)
-- ============================================

-- If you already have auth users, manually add them to the users table
-- Replace 'YOUR_AUTH_USER_ID' with your actual user ID from Supabase Auth

-- Get your user ID by running: SELECT id, email FROM auth.users;

-- Example:
-- INSERT INTO users (id, email, team_id, agency_id, vehicle_type, vehicle_color)
-- SELECT 
--     'YOUR_AUTH_USER_ID'::UUID,
--     'your@email.com',
--     teams.id,
--     agencies.id,
--     'sedan',
--     'black'
-- FROM agencies, teams
-- WHERE agencies.name = 'Default Agency' AND teams.name = 'Default Team';

-- ============================================
-- 7. VERIFICATION QUERIES
-- ============================================

-- Check if tables were created
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- Check if RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public';

-- Check agencies and teams
SELECT * FROM agencies;
SELECT * FROM teams;

-- Check your user record (run after you log in)
-- SELECT * FROM users WHERE id = auth.uid();

-- ============================================
-- DONE! 
-- ============================================
-- 
-- Next Steps:
-- 1. Run this entire script in Supabase SQL Editor
-- 2. Restart your app
-- 3. Log in
-- 4. You should see: "✅ User found: your@email.com"
-- 5. Try creating an operation - it should work!
--
-- ============================================

