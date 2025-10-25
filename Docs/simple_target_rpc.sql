-- ============================================
-- SIMPLIFIED TARGET RPC FUNCTIONS
-- ============================================
-- These work with just the main targets table
-- Target details are stored in a JSON column

-- First, add a data column to targets if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'targets' AND column_name = 'data'
    ) THEN
        ALTER TABLE public.targets ADD COLUMN data JSONB;
    END IF;
END $$;

-- 1. CREATE PERSON TARGET (Simplified)
CREATE OR REPLACE FUNCTION public.rpc_create_person_target(
    operation_id UUID,
    first_name TEXT,
    last_name TEXT,
    phone_number TEXT DEFAULT NULL,
    notes TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_target_id UUID;
BEGIN
    -- Check user is member
    IF NOT EXISTS (
        SELECT 1 FROM operation_members
        WHERE operation_members.operation_id = rpc_create_person_target.operation_id
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this operation';
    END IF;
    
    -- Create target with data in JSONB
    INSERT INTO targets (operation_id, type, created_by, data)
    VALUES (
        rpc_create_person_target.operation_id, 
        'person', 
        auth.uid(),
        jsonb_build_object(
            'first_name', first_name,
            'last_name', last_name,
            'phone_number', phone_number,
            'notes', notes
        )
    )
    RETURNING id INTO new_target_id;
    
    RETURN json_build_object('target_id', new_target_id);
END;
$$;

-- 2. CREATE VEHICLE TARGET (Simplified)
CREATE OR REPLACE FUNCTION public.rpc_create_vehicle_target(
    operation_id UUID,
    make TEXT DEFAULT NULL,
    model TEXT DEFAULT NULL,
    color TEXT DEFAULT NULL,
    plate TEXT DEFAULT NULL,
    notes TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_target_id UUID;
BEGIN
    -- Check user is member
    IF NOT EXISTS (
        SELECT 1 FROM operation_members
        WHERE operation_members.operation_id = rpc_create_vehicle_target.operation_id
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this operation';
    END IF;
    
    -- Create target with data in JSONB
    INSERT INTO targets (operation_id, type, created_by, data)
    VALUES (
        rpc_create_vehicle_target.operation_id, 
        'vehicle', 
        auth.uid(),
        jsonb_build_object(
            'make', make,
            'model', model,
            'color', color,
            'plate', plate,
            'notes', notes
        )
    )
    RETURNING id INTO new_target_id;
    
    RETURN json_build_object('target_id', new_target_id);
END;
$$;

-- 3. CREATE LOCATION TARGET (Simplified with coordinates and label)
CREATE OR REPLACE FUNCTION public.rpc_create_location_target(
    operation_id UUID,
    address TEXT,
    label TEXT DEFAULT NULL,
    city TEXT DEFAULT NULL,
    zip_code TEXT DEFAULT NULL,
    latitude DOUBLE PRECISION DEFAULT NULL,
    longitude DOUBLE PRECISION DEFAULT NULL,
    notes TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_target_id UUID;
    full_address TEXT;
BEGIN
    -- Check user is member
    IF NOT EXISTS (
        SELECT 1 FROM operation_members
        WHERE operation_members.operation_id = rpc_create_location_target.operation_id
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this operation';
    END IF;
    
    -- Build full address
    full_address := address;
    IF city IS NOT NULL THEN
        full_address := full_address || ', ' || city;
    END IF;
    IF zip_code IS NOT NULL THEN
        full_address := full_address || ' ' || zip_code;
    END IF;
    
    -- Create target with data in JSONB including coordinates and custom label
    -- The label is what shows on the map (e.g., "Suspect's Home")
    -- The address is the full street address for reference
    INSERT INTO targets (operation_id, type, created_by, data)
    VALUES (
        rpc_create_location_target.operation_id, 
        'location', 
        auth.uid(),
        jsonb_build_object(
            'label', COALESCE(label, full_address),  -- Use custom label or fallback to address
            'address', full_address,
            'latitude', latitude,
            'longitude', longitude,
            'notes', notes
        )
    )
    RETURNING id INTO new_target_id;
    
    RETURN json_build_object('target_id', new_target_id);
END;
$$;

-- 4. CREATE STAGING POINT (unchanged)
CREATE OR REPLACE FUNCTION public.rpc_create_staging_point(
    operation_id UUID,
    label TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_staging_id UUID;
BEGIN
    -- Check user is case agent or member
    IF NOT EXISTS (
        SELECT 1 FROM operations o
        LEFT JOIN operation_members om ON o.id = om.operation_id
        WHERE o.id = rpc_create_staging_point.operation_id
        AND (o.case_agent_id = auth.uid() OR om.user_id = auth.uid())
    ) THEN
        RAISE EXCEPTION 'User not authorized for this operation';
    END IF;
    
    -- Create staging point with coordinates
    INSERT INTO staging_areas (operation_id, name, lat, lon)
    VALUES (rpc_create_staging_point.operation_id, label, latitude, longitude)
    RETURNING id INTO new_staging_id;
    
    RETURN json_build_object('staging_id', new_staging_id);
END;
$$;

-- 5. FETCH TARGETS (Simplified - reads from JSONB data column)
CREATE OR REPLACE FUNCTION public.rpc_get_operation_targets(
    operation_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
BEGIN
    -- Check user is member
    IF NOT EXISTS (
        SELECT 1 FROM operation_members
        WHERE operation_members.operation_id = rpc_get_operation_targets.operation_id
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this operation';
    END IF;
    
    -- Get targets from JSONB data column
    SELECT json_build_object(
        'targets', COALESCE((
            SELECT json_agg(json_build_object(
                'id', t.id,
                'type', t.type,
                'created_at', t.created_at,
                'person', CASE WHEN t.type = 'person' THEN
                    json_build_object(
                        'first_name', t.data->>'first_name',
                        'last_name', t.data->>'last_name',
                        'phone_number', t.data->>'phone_number',
                        'notes', t.data->>'notes'
                    )
                END,
                'vehicle', CASE WHEN t.type = 'vehicle' THEN
                    json_build_object(
                        'make', t.data->>'make',
                        'model', t.data->>'model',
                        'color', t.data->>'color',
                        'plate', t.data->>'plate',
                        'notes', t.data->>'notes'
                    )
                END,
                'location', CASE WHEN t.type = 'location' THEN
                    json_build_object(
                        'label', t.data->>'label',
                        'address', t.data->>'address',
                        'latitude', (t.data->>'latitude')::double precision,
                        'longitude', (t.data->>'longitude')::double precision,
                        'notes', t.data->>'notes'
                    )
                END
            ))
            FROM targets t
            WHERE t.operation_id = rpc_get_operation_targets.operation_id
        ), '[]'::json),
        'staging', COALESCE((
            SELECT json_agg(json_build_object(
                'id', sa.id,
                'label', sa.name,
                'latitude', sa.lat,
                'longitude', sa.lon
            ))
            FROM staging_areas sa
            WHERE sa.operation_id = rpc_get_operation_targets.operation_id
        ), '[]'::json)
    ) INTO result;
    
    RETURN result;
END;
$$;

-- Verify
-- 6. FETCH ALL ACTIVE OPERATIONS
-- Returns ALL active operations in the system (not just user's)
CREATE OR REPLACE FUNCTION public.rpc_get_all_active_operations()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
BEGIN
    -- Get ALL active operations (anyone can see them)
    SELECT json_agg(
        json_build_object(
            'id', o.id,
            'name', o.name,
            'incident_number', o.incident_number,
            'status', o.status,
            'created_at', o.created_at,
            'started_at', o.started_at,
            'ended_at', o.ended_at,
            'case_agent_id', o.case_agent_id,
            'team_id', o.team_id,
            'agency_id', o.agency_id,
            'is_member', EXISTS (
                SELECT 1 FROM operation_members om
                WHERE om.operation_id = o.id
                AND om.user_id = auth.uid()
                AND om.left_at IS NULL
            )
        ) ORDER BY o.created_at DESC
    )
    INTO result
    FROM operations o
    WHERE o.status = 'active';  -- Only active operations
    
    RETURN COALESCE(result, '[]'::json);
END;
$$;

-- 7. REQUEST TO JOIN OPERATION
CREATE OR REPLACE FUNCTION public.rpc_request_join_operation(
    operation_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    request_id UUID;
BEGIN
    -- Check if user is already a member
    IF EXISTS (
        SELECT 1 FROM operation_members
        WHERE operation_id = $1
        AND user_id = auth.uid()
        AND left_at IS NULL
    ) THEN
        RAISE EXCEPTION 'Already a member of this operation';
    END IF;
    
    -- Check if user has pending request
    IF EXISTS (
        SELECT 1 FROM join_requests
        WHERE operation_id = $1
        AND requester_user_id = auth.uid()
        AND status = 'pending'
    ) THEN
        RAISE EXCEPTION 'Join request already pending';
    END IF;
    
    -- Create join request
    INSERT INTO join_requests (operation_id, requester_user_id, status, created_at)
    VALUES ($1, auth.uid(), 'pending', NOW())
    RETURNING id INTO request_id;
    
    -- TODO: Send notification to operation creator
    
    RETURN json_build_object('request_id', request_id);
END;
$$;

-- 8. ADD MULTIPLE MEMBERS TO OPERATION
-- Adds multiple users to an operation at once (on creation)
-- Also implements "one active operation" constraint by removing users from their previous operation
CREATE OR REPLACE FUNCTION public.rpc_add_operation_members(
    operation_id UUID,
    member_user_ids UUID[]
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    member_id UUID;
    added_count INT := 0;
BEGIN
    -- Only case agent can add members
    IF NOT EXISTS (
        SELECT 1 FROM operations
        WHERE id = $1
        AND case_agent_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Only the case agent can add members';
    END IF;
    
    -- Loop through each member to add
    FOREACH member_id IN ARRAY member_user_ids
    LOOP
        -- Check if user is already a member of THIS operation
        IF EXISTS (
            SELECT 1 FROM operation_members
            WHERE operation_id = $1
            AND user_id = member_id
            AND left_at IS NULL
        ) THEN
            -- Skip if already a member
            CONTINUE;
        END IF;
        
        -- ENFORCE ONE ACTIVE OPERATION CONSTRAINT:
        -- Remove user from any other active operation first
        UPDATE operation_members
        SET left_at = NOW()
        WHERE user_id = member_id
        AND operation_id != $1
        AND left_at IS NULL;
        
        -- Add member to this operation
        INSERT INTO operation_members (operation_id, user_id, role, joined_at)
        VALUES ($1, member_id, 'member', NOW())
        ON CONFLICT (operation_id, user_id) DO UPDATE
        SET left_at = NULL, joined_at = NOW();
        
        added_count := added_count + 1;
        
        -- TODO: Send push notification to member
    END LOOP;
    
    RETURN json_build_object('added_count', added_count);
END;
$$;

-- 9. GET TEAM ROSTER
-- Returns all users in the current user's team with their operation status
CREATE OR REPLACE FUNCTION public.rpc_get_team_roster()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
    user_team_id UUID;
BEGIN
    -- Get current user's team
    SELECT team_id INTO user_team_id
    FROM users
    WHERE id = auth.uid();
    
    IF user_team_id IS NULL THEN
        RAISE EXCEPTION 'User not assigned to team';
    END IF;
    
    -- Get all team members with their operation status
    SELECT json_agg(
        json_build_object(
            'id', u.id,
            'full_name', u.full_name,
            'email', u.email,
            'callsign', u.callsign,
            'in_operation', EXISTS (
                SELECT 1 FROM operation_members om
                JOIN operations o ON om.operation_id = o.id
                WHERE om.user_id = u.id
                AND om.left_at IS NULL
                AND o.status = 'active'
            ),
            'operation_id', (
                SELECT om.operation_id
                FROM operation_members om
                JOIN operations o ON om.operation_id = o.id
                WHERE om.user_id = u.id
                AND om.left_at IS NULL
                AND o.status = 'active'
                LIMIT 1
            )
        ) ORDER BY u.full_name
    )
    INTO result
    FROM users u
    WHERE u.team_id = user_team_id;
    
    RETURN COALESCE(result, '[]'::json);
END;
$$;

-- 10. GET PREVIOUS (ENDED) OPERATIONS
-- Returns operations that have ended that the user was a member of
CREATE OR REPLACE FUNCTION public.rpc_get_previous_operations()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
BEGIN
    -- Get ended operations where user was a member
    SELECT json_agg(
        json_build_object(
            'id', o.id,
            'name', o.name,
            'incident_number', o.incident_number,
            'status', o.status,
            'created_at', o.created_at,
            'started_at', o.started_at,
            'ended_at', o.ended_at,
            'case_agent_id', o.case_agent_id,
            'team_id', o.team_id,
            'agency_id', o.agency_id
        ) ORDER BY o.ended_at DESC NULLS LAST, o.created_at DESC
    )
    INTO result
    FROM operations o
    WHERE o.status = 'ended'
    AND EXISTS (
        SELECT 1 FROM operation_members om
        WHERE om.operation_id = o.id
        AND om.user_id = auth.uid()
    );
    
    RETURN COALESCE(result, '[]'::json);
END;
$$;

-- 11. UPDATE OPERATION DETAILS
-- Allows any member to update operation name and incident number
CREATE OR REPLACE FUNCTION public.rpc_update_operation(
    operation_id UUID,
    name TEXT,
    incident_number TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if user is a member of the operation
    IF NOT EXISTS (
        SELECT 1 FROM operation_members
        WHERE operation_id = $1
        AND user_id = auth.uid()
        AND left_at IS NULL
    ) THEN
        RAISE EXCEPTION 'User not a member of this operation';
    END IF;
    
    -- Update operation details
    UPDATE operations
    SET 
        name = $2,
        incident_number = $3
    WHERE id = $1;
    
    RETURN json_build_object('success', true);
END;
$$;

SELECT '✅ Simplified RPC functions created!' as status;
SELECT 'All target data stored in JSONB column' as note;

