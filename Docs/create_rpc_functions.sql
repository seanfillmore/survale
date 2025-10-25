-- ============================================
-- CREATE RPC FUNCTIONS FOR MVP
-- ============================================
-- These are the functions your app calls to interact with the database

-- 1. CREATE OPERATION
CREATE OR REPLACE FUNCTION public.rpc_create_operation(
    name TEXT,
    incident_number TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_operation_id UUID;
    user_team_id UUID;
    user_agency_id UUID;
BEGIN
    -- Get current user's team and agency
    SELECT team_id, agency_id INTO user_team_id, user_agency_id
    FROM users
    WHERE id = auth.uid();
    
    IF user_team_id IS NULL OR user_agency_id IS NULL THEN
        RAISE EXCEPTION 'User not assigned to team/agency';
    END IF;
    
    -- Create operation
    INSERT INTO operations (
        id,
        name,
        incident_number,
        agency_id,
        team_id,
        case_agent_id,
        status,
        created_at
    )
    VALUES (
        gen_random_uuid(),
        name,
        incident_number,
        user_agency_id,
        user_team_id,
        auth.uid(),
        'active',  -- Operations are active by default (no draft state)
        NOW()
    )
    RETURNING id INTO new_operation_id;
    
    -- Add creator as a member with case_agent role
    INSERT INTO operation_members (
        operation_id,
        user_id,
        role,
        joined_at
    )
    VALUES (
        new_operation_id,
        auth.uid(),
        'case_agent',
        NOW()
    );
    
    -- Return the operation ID
    RETURN json_build_object('operation_id', new_operation_id);
END;
$$;

-- 2. START OPERATION
CREATE OR REPLACE FUNCTION public.rpc_start_operation(
    operation_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Only case agent can start operation
    IF NOT EXISTS (
        SELECT 1 FROM operations
        WHERE id = operation_id
        AND case_agent_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Only case agent can start operation';
    END IF;
    
    -- Update operation status
    UPDATE operations
    SET 
        status = 'active',
        started_at = NOW()
    WHERE id = operation_id;
    
    RETURN json_build_object('success', true);
END;
$$;

-- 3. END OPERATION
CREATE OR REPLACE FUNCTION public.rpc_end_operation(
    operation_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Only case agent can end operation
    IF NOT EXISTS (
        SELECT 1 FROM operations
        WHERE id = operation_id
        AND case_agent_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Only case agent can end operation';
    END IF;
    
    -- Update operation status
    UPDATE operations
    SET 
        status = 'ended',
        ended_at = NOW()
    WHERE id = operation_id;
    
    RETURN json_build_object('success', true);
END;
$$;

-- 4. PUBLISH LOCATION
CREATE OR REPLACE FUNCTION public.rpc_publish_location(
    operation_id UUID,
    lat DOUBLE PRECISION,
    lon DOUBLE PRECISION,
    accuracy_m DOUBLE PRECISION,
    speed_mps DOUBLE PRECISION DEFAULT NULL,
    heading_deg DOUBLE PRECISION DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check user is member of operation
    IF NOT EXISTS (
        SELECT 1 FROM operation_members
        WHERE operation_id = rpc_publish_location.operation_id
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this operation';
    END IF;
    
    -- Insert location
    INSERT INTO locations_stream (
        operation_id,
        user_id,
        ts,
        lat,
        lon,
        accuracy_m,
        speed_mps,
        heading_deg
    )
    VALUES (
        rpc_publish_location.operation_id,
        auth.uid(),
        NOW(),
        lat,
        lon,
        accuracy_m,
        speed_mps,
        heading_deg
    );
    
    RETURN json_build_object('success', true);
END;
$$;

-- 5. INVITE USER
CREATE OR REPLACE FUNCTION public.rpc_invite_user(
    operation_id UUID,
    invitee_user_id UUID,
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '24 hours')
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Only case agent can invite
    IF NOT EXISTS (
        SELECT 1 FROM operations
        WHERE id = operation_id
        AND case_agent_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Only case agent can invite users';
    END IF;
    
    -- Create invite
    INSERT INTO operation_invites (
        operation_id,
        invitee_user_id,
        status,
        expires_at,
        created_at
    )
    VALUES (
        operation_id,
        invitee_user_id,
        'pending',
        expires_at,
        NOW()
    );
    
    RETURN json_build_object('success', true);
END;
$$;

-- 6. ACCEPT INVITE
CREATE OR REPLACE FUNCTION public.rpc_accept_invite(
    invite_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    inv_operation_id UUID;
BEGIN
    -- Get operation_id from invite
    SELECT operation_id INTO inv_operation_id
    FROM operation_invites
    WHERE id = invite_id
    AND invitee_user_id = auth.uid()
    AND status = 'pending';
    
    IF inv_operation_id IS NULL THEN
        RAISE EXCEPTION 'Invite not found or already processed';
    END IF;
    
    -- Add user as member
    INSERT INTO operation_members (
        operation_id,
        user_id,
        role,
        joined_at
    )
    VALUES (
        inv_operation_id,
        auth.uid(),
        'member',
        NOW()
    )
    ON CONFLICT DO NOTHING;
    
    -- Update invite status
    UPDATE operation_invites
    SET status = 'accepted'
    WHERE id = invite_id;
    
    RETURN json_build_object('success', true, 'operation_id', inv_operation_id);
END;
$$;

-- Verify functions were created
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name LIKE 'rpc_%'
ORDER BY routine_name;

SELECT '✅ All RPC functions created! Your app can now create operations.' as status;

