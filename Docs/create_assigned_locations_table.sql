-- ============================================
-- LOCATION ASSIGNMENT FEATURE - Database Setup
-- ============================================
-- Creates table, indexes, RLS policies, and RPC functions
-- for assigning locations to team members with navigation
-- ============================================

-- ============================================
-- 1. CREATE TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS assigned_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_id UUID NOT NULL REFERENCES operations(id) ON DELETE CASCADE,
    assigned_by_user_id UUID NOT NULL REFERENCES users(id),
    assigned_to_user_id UUID NOT NULL REFERENCES users(id),
    lat DOUBLE PRECISION NOT NULL,
    lon DOUBLE PRECISION NOT NULL,
    label TEXT,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'assigned' CHECK (status IN ('assigned', 'en_route', 'arrived', 'cancelled')),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    acknowledged_at TIMESTAMPTZ,
    arrived_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 2. CREATE INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_assigned_locations_operation 
ON assigned_locations(operation_id);

CREATE INDEX IF NOT EXISTS idx_assigned_locations_assigned_to 
ON assigned_locations(assigned_to_user_id, status);

CREATE INDEX IF NOT EXISTS idx_assigned_locations_status 
ON assigned_locations(operation_id, status);

CREATE INDEX IF NOT EXISTS idx_assigned_locations_active 
ON assigned_locations(operation_id, assigned_to_user_id) 
WHERE status != 'cancelled';

-- ============================================
-- 3. ENABLE RLS
-- ============================================

ALTER TABLE assigned_locations ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 4. CREATE RLS POLICIES
-- ============================================

-- Members can view assignments in their operation
DROP POLICY IF EXISTS "Members can view operation assignments" ON assigned_locations;
CREATE POLICY "Members can view operation assignments"
ON assigned_locations FOR SELECT
USING (
    operation_id IN (
        SELECT om.operation_id 
        FROM operation_members om
        WHERE om.user_id = auth.uid() 
        AND om.left_at IS NULL
    )
);

-- Only case agent can assign locations
DROP POLICY IF EXISTS "Case agent can assign locations" ON assigned_locations;
CREATE POLICY "Case agent can assign locations"
ON assigned_locations FOR INSERT
WITH CHECK (
    operation_id IN (
        SELECT o.id 
        FROM operations o
        WHERE o.case_agent_id = auth.uid()
    )
);

-- Assigned user can update their status
DROP POLICY IF EXISTS "Assigned user can update status" ON assigned_locations;
CREATE POLICY "Assigned user can update status"
ON assigned_locations FOR UPDATE
USING (assigned_to_user_id = auth.uid())
WITH CHECK (assigned_to_user_id = auth.uid());

-- Case agent can update any assignment
DROP POLICY IF EXISTS "Case agent can update assignments" ON assigned_locations;
CREATE POLICY "Case agent can update assignments"
ON assigned_locations FOR UPDATE
USING (
    operation_id IN (
        SELECT o.id 
        FROM operations o
        WHERE o.case_agent_id = auth.uid()
    )
)
WITH CHECK (
    operation_id IN (
        SELECT o.id 
        FROM operations o
        WHERE o.case_agent_id = auth.uid()
    )
);

-- ============================================
-- 5. RPC FUNCTION: Assign Location
-- ============================================

CREATE OR REPLACE FUNCTION rpc_assign_location(
    p_operation_id UUID,
    p_assigned_to_user_id UUID,
    p_lat DOUBLE PRECISION,
    p_lon DOUBLE PRECISION,
    p_label TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_assignment_id UUID;
    v_result JSON;
    v_assignee_callsign TEXT;
    v_assignee_name TEXT;
BEGIN
    -- Check if caller is case agent
    IF NOT EXISTS (
        SELECT 1 FROM operations o
        WHERE o.id = p_operation_id
        AND o.case_agent_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Only case agent can assign locations';
    END IF;
    
    -- Check if assignee is a member
    IF NOT EXISTS (
        SELECT 1 FROM operation_members om
        WHERE om.operation_id = p_operation_id
        AND om.user_id = p_assigned_to_user_id
        AND om.left_at IS NULL
    ) THEN
        RAISE EXCEPTION 'User is not a member of this operation';
    END IF;
    
    -- Get assignee info
    SELECT u.callsign, u.full_name
    INTO v_assignee_callsign, v_assignee_name
    FROM users u
    WHERE u.id = p_assigned_to_user_id;
    
    -- Cancel any existing active assignments for this user
    UPDATE assigned_locations
    SET status = 'cancelled', updated_at = NOW()
    WHERE operation_id = p_operation_id
    AND assigned_to_user_id = p_assigned_to_user_id
    AND status IN ('assigned', 'en_route');
    
    -- Create assignment
    INSERT INTO assigned_locations (
        operation_id,
        assigned_by_user_id,
        assigned_to_user_id,
        lat,
        lon,
        label,
        notes,
        status
    ) VALUES (
        p_operation_id,
        auth.uid(),
        p_assigned_to_user_id,
        p_lat,
        p_lon,
        p_label,
        p_notes,
        'assigned'
    ) RETURNING id INTO v_assignment_id;
    
    -- Return assignment with user info
    SELECT json_build_object(
        'assignment_id', v_assignment_id,
        'assigned_to_callsign', v_assignee_callsign,
        'assigned_to_full_name', v_assignee_name,
        'success', true
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- ============================================
-- 6. RPC FUNCTION: Update Assignment Status
-- ============================================

CREATE OR REPLACE FUNCTION rpc_update_assignment_status(
    p_assignment_id UUID,
    p_status TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Validate status
    IF p_status NOT IN ('assigned', 'en_route', 'arrived', 'cancelled') THEN
        RAISE EXCEPTION 'Invalid status: %', p_status;
    END IF;
    
    -- Check if user is assigned to this location or is case agent
    IF NOT EXISTS (
        SELECT 1 FROM assigned_locations al
        WHERE al.id = p_assignment_id
        AND (
            al.assigned_to_user_id = auth.uid()
            OR al.operation_id IN (
                SELECT o.id FROM operations o
                WHERE o.case_agent_id = auth.uid()
            )
        )
    ) THEN
        RAISE EXCEPTION 'Not authorized to update this assignment';
    END IF;
    
    -- Update status
    UPDATE assigned_locations
    SET 
        status = p_status,
        acknowledged_at = CASE 
            WHEN p_status = 'en_route' AND acknowledged_at IS NULL 
            THEN NOW() 
            ELSE acknowledged_at 
        END,
        arrived_at = CASE 
            WHEN p_status = 'arrived' 
            THEN NOW() 
            ELSE arrived_at 
        END,
        updated_at = NOW()
    WHERE id = p_assignment_id;
    
    RETURN json_build_object('success', true, 'status', p_status);
END;
$$;

-- ============================================
-- 7. RPC FUNCTION: Get Operation Assignments
-- ============================================

CREATE OR REPLACE FUNCTION rpc_get_operation_assignments(
    p_operation_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if user is member
    IF NOT EXISTS (
        SELECT 1 FROM operation_members om
        WHERE om.operation_id = p_operation_id
        AND om.user_id = auth.uid()
        AND om.left_at IS NULL
    ) THEN
        RAISE EXCEPTION 'User not a member of this operation';
    END IF;
    
    RETURN COALESCE((
        SELECT json_agg(
            json_build_object(
                'id', al.id,
                'operation_id', al.operation_id,
                'assigned_by_user_id', al.assigned_by_user_id,
                'assigned_to_user_id', al.assigned_to_user_id,
                'assigned_to_callsign', u.callsign,
                'assigned_to_full_name', u.full_name,
                'lat', al.lat,
                'lon', al.lon,
                'label', al.label,
                'notes', al.notes,
                'status', al.status,
                'assigned_at', al.assigned_at,
                'acknowledged_at', al.acknowledged_at,
                'arrived_at', al.arrived_at
            )
            ORDER BY al.assigned_at DESC
        )
        FROM assigned_locations al
        JOIN users u ON u.id = al.assigned_to_user_id
        WHERE al.operation_id = p_operation_id
        AND al.status != 'cancelled'
    ), '[]'::json);
END;
$$;

-- ============================================
-- 8. RPC FUNCTION: Cancel Assignment
-- ============================================

CREATE OR REPLACE FUNCTION rpc_cancel_assignment(
    p_assignment_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if user is case agent
    IF NOT EXISTS (
        SELECT 1 FROM assigned_locations al
        JOIN operations o ON o.id = al.operation_id
        WHERE al.id = p_assignment_id
        AND o.case_agent_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Only case agent can cancel assignments';
    END IF;
    
    -- Update status to cancelled
    UPDATE assigned_locations
    SET 
        status = 'cancelled',
        updated_at = NOW()
    WHERE id = p_assignment_id;
    
    RETURN json_build_object('success', true);
END;
$$;

-- ============================================
-- 9. VERIFY SETUP
-- ============================================

-- Check table was created
SELECT 'assigned_locations table' as check_name, 
       EXISTS (
           SELECT FROM information_schema.tables 
           WHERE table_schema = 'public' 
           AND table_name = 'assigned_locations'
       ) as exists;

-- Check indexes
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
AND tablename = 'assigned_locations';

-- Check RLS is enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'assigned_locations';

-- Check policies
SELECT policyname, cmd
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'assigned_locations';

-- Check functions
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name LIKE 'rpc_%assignment%'
ORDER BY routine_name;

-- ============================================
-- DONE!
-- ============================================

-- Next steps:
-- 1. Run this SQL in Supabase SQL Editor
-- 2. Verify all checks pass
-- 3. Create Swift models (AssignedLocation)
-- 4. Implement AssignmentService
-- 5. Add UI components

