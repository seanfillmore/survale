-- ============================================================================
-- SURVALE - Location Assignment Feature Database Setup
-- ============================================================================
-- This script sets up all database objects needed for the location assignment
-- feature. Run this in your Supabase SQL Editor.
--
-- Features:
-- 1. assigned_locations table with full schema
-- 2. Row Level Security (RLS) policies
-- 3. RPC functions for assignment operations
-- 4. Indexes for performance
-- ============================================================================

-- ============================================================================
-- STEP 1: Create the assigned_locations table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.assigned_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_id UUID NOT NULL REFERENCES public.operations(id) ON DELETE CASCADE,
    assigned_by_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    assigned_to_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    lat DOUBLE PRECISION NOT NULL,
    lon DOUBLE PRECISION NOT NULL,
    label TEXT,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'assigned' CHECK (status IN ('assigned', 'en_route', 'arrived', 'cancelled')),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    acknowledged_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    arrived_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    
    -- Constraints
    CONSTRAINT valid_coordinates CHECK (
        lat >= -90 AND lat <= 90 AND
        lon >= -180 AND lon <= 180
    ),
    CONSTRAINT valid_timestamps CHECK (
        acknowledged_at IS NULL OR acknowledged_at >= assigned_at
    ),
    CONSTRAINT valid_completion CHECK (
        completed_at IS NULL OR completed_at >= assigned_at
    )
);

-- Add comments for documentation
COMMENT ON TABLE public.assigned_locations IS 'Stores location assignments from case agents to team members';
COMMENT ON COLUMN public.assigned_locations.status IS 'assigned: newly assigned, en_route: acknowledged and traveling, arrived: reached location, cancelled: assignment cancelled';

-- ============================================================================
-- STEP 2: Create indexes for performance
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_assigned_locations_operation 
    ON public.assigned_locations(operation_id);

CREATE INDEX IF NOT EXISTS idx_assigned_locations_assigned_to 
    ON public.assigned_locations(assigned_to_user_id);

CREATE INDEX IF NOT EXISTS idx_assigned_locations_status 
    ON public.assigned_locations(status) 
    WHERE status IN ('assigned', 'en_route');

CREATE INDEX IF NOT EXISTS idx_assigned_locations_assigned_at 
    ON public.assigned_locations(assigned_at DESC);

-- ============================================================================
-- STEP 3: Enable Row Level Security (RLS)
-- ============================================================================

ALTER TABLE public.assigned_locations ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 4: Create RLS Policies
-- ============================================================================

-- Policy: Operation members can view assignments in their operations
CREATE POLICY "Users can view assignments in their operations"
    ON public.assigned_locations
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.operation_members om
            WHERE om.operation_id = assigned_locations.operation_id
            AND om.user_id = auth.uid()
            AND om.left_at IS NULL
        )
    );

-- Policy: Case agents can insert assignments
CREATE POLICY "Case agents can create assignments"
    ON public.assigned_locations
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.operations o
            WHERE o.id = assigned_locations.operation_id
            AND o.case_agent_id = auth.uid()
            AND o.status = 'active'
        )
        AND assigned_by_user_id = auth.uid()
    );

-- Policy: Case agents and assigned users can update assignments
CREATE POLICY "Case agents and assigned users can update assignments"
    ON public.assigned_locations
    FOR UPDATE
    USING (
        -- Case agent of the operation
        EXISTS (
            SELECT 1 FROM public.operations o
            WHERE o.id = assigned_locations.operation_id
            AND o.case_agent_id = auth.uid()
        )
        OR
        -- User assigned to this location
        assigned_to_user_id = auth.uid()
    );

-- Policy: Case agents can delete/cancel assignments
CREATE POLICY "Case agents can delete assignments"
    ON public.assigned_locations
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.operations o
            WHERE o.id = assigned_locations.operation_id
            AND o.case_agent_id = auth.uid()
        )
    );

-- ============================================================================
-- STEP 5: Create RPC Functions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Function: Assign a location to a team member
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_assign_location(
    operation_id UUID,
    assigned_to_user_id UUID,
    lat DOUBLE PRECISION,
    lon DOUBLE PRECISION,
    label TEXT DEFAULT NULL,
    notes TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_assignment_id UUID;
    v_assigned_to_full_name TEXT;
    v_assigned_to_callsign TEXT;
BEGIN
    -- Verify caller is the case agent
    IF NOT EXISTS (
        SELECT 1 FROM public.operations
        WHERE id = operation_id
        AND case_agent_id = auth.uid()
        AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'Only the case agent can assign locations';
    END IF;
    
    -- Verify assigned user is an active member
    IF NOT EXISTS (
        SELECT 1 FROM public.operation_members
        WHERE operation_members.operation_id = rpc_assign_location.operation_id
        AND user_id = assigned_to_user_id
        AND left_at IS NULL
    ) THEN
        RAISE EXCEPTION 'User is not an active member of this operation';
    END IF;
    
    -- Get user details for response
    SELECT full_name, callsign 
    INTO v_assigned_to_full_name, v_assigned_to_callsign
    FROM public.users
    WHERE id = assigned_to_user_id;
    
    -- Create assignment
    INSERT INTO public.assigned_locations (
        operation_id,
        assigned_by_user_id,
        assigned_to_user_id,
        lat,
        lon,
        label,
        notes,
        status
    ) VALUES (
        operation_id,
        auth.uid(),
        assigned_to_user_id,
        lat,
        lon,
        label,
        notes,
        'assigned'
    )
    RETURNING id INTO v_assignment_id;
    
    RETURN json_build_object(
        'assignment_id', v_assignment_id,
        'status', 'assigned',
        'assigned_to_full_name', v_assigned_to_full_name,
        'assigned_to_callsign', v_assigned_to_callsign
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- Function: Update assignment status
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_update_assignment_status(
    assignment_id UUID,
    new_status TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_status TEXT;
    v_assigned_to_user_id UUID;
BEGIN
    -- Get current status and assigned user
    SELECT status, assigned_to_user_id
    INTO v_current_status, v_assigned_to_user_id
    FROM public.assigned_locations
    WHERE id = assignment_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Assignment not found';
    END IF;
    
    -- Only assigned user can update status (or case agent)
    IF v_assigned_to_user_id != auth.uid() AND NOT EXISTS (
        SELECT 1 FROM public.assigned_locations al
        JOIN public.operations o ON o.id = al.operation_id
        WHERE al.id = assignment_id
        AND o.case_agent_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Only the assigned user or case agent can update status';
    END IF;
    
    -- Validate status transition
    IF new_status NOT IN ('assigned', 'en_route', 'arrived', 'cancelled') THEN
        RAISE EXCEPTION 'Invalid status: %', new_status;
    END IF;
    
    -- Update status with appropriate timestamps
    UPDATE public.assigned_locations
    SET 
        status = new_status,
        updated_at = NOW(),
        acknowledged_at = CASE 
            WHEN new_status = 'en_route' AND acknowledged_at IS NULL THEN NOW()
            ELSE acknowledged_at
        END,
        arrived_at = CASE 
            WHEN new_status = 'arrived' AND arrived_at IS NULL THEN NOW()
            ELSE arrived_at
        END,
        completed_at = CASE 
            WHEN new_status IN ('arrived', 'cancelled') AND completed_at IS NULL THEN NOW()
            ELSE completed_at
        END
    WHERE id = assignment_id;
    
    RETURN json_build_object(
        'assignment_id', assignment_id,
        'status', new_status,
        'updated_at', NOW(),
        'completed_at', CASE 
            WHEN new_status IN ('arrived', 'cancelled') THEN NOW()
            ELSE NULL
        END
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- Function: Get all assignments for an operation
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_get_operation_assignments(
    operation_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Verify user is a member of the operation
    IF NOT EXISTS (
        SELECT 1 FROM public.operation_members
        WHERE operation_members.operation_id = rpc_get_operation_assignments.operation_id
        AND user_id = auth.uid()
        AND left_at IS NULL
    ) THEN
        RAISE EXCEPTION 'User is not a member of this operation';
    END IF;
    
    RETURN (
        SELECT COALESCE(json_agg(
            json_build_object(
                'id', al.id,
                'operation_id', al.operation_id,
                'assigned_by_user_id', al.assigned_by_user_id,
                'assigned_to_user_id', al.assigned_to_user_id,
                'lat', al.lat,
                'lon', al.lon,
                'label', al.label,
                'notes', al.notes,
                'status', al.status,
                'assigned_at', al.assigned_at,
                'acknowledged_at', al.acknowledged_at,
                'updated_at', al.updated_at,
                'arrived_at', al.arrived_at,
                'completed_at', al.completed_at,
                'assigned_to_full_name', u_to.full_name,
                'assigned_to_callsign', u_to.callsign,
                'assigned_by_full_name', u_by.full_name,
                'assigned_by_callsign', u_by.callsign
            )
        ), '[]'::json)
        FROM public.assigned_locations al
        LEFT JOIN public.users u_to ON u_to.id = al.assigned_to_user_id
        LEFT JOIN public.users u_by ON u_by.id = al.assigned_by_user_id
        WHERE al.operation_id = rpc_get_operation_assignments.operation_id
        ORDER BY al.assigned_at DESC
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- Function: Cancel an assignment
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_cancel_assignment(
    assignment_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Verify user is the case agent
    IF NOT EXISTS (
        SELECT 1 FROM public.assigned_locations al
        JOIN public.operations o ON o.id = al.operation_id
        WHERE al.id = assignment_id
        AND o.case_agent_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Only the case agent can cancel assignments';
    END IF;
    
    -- Update to cancelled status
    UPDATE public.assigned_locations
    SET 
        status = 'cancelled',
        updated_at = NOW(),
        completed_at = NOW()
    WHERE id = assignment_id;
    
    RETURN json_build_object(
        'assignment_id', assignment_id,
        'status', 'cancelled',
        'cancelled_at', NOW()
    );
END;
$$;

-- ============================================================================
-- STEP 6: Grant necessary permissions
-- ============================================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON public.assigned_locations TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_assign_location TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_update_assignment_status TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_operation_assignments TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_cancel_assignment TO authenticated;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- Run these to verify the setup:

-- Check table exists
-- SELECT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'assigned_locations');

-- Check RLS is enabled
-- SELECT relrowsecurity FROM pg_class WHERE relname = 'assigned_locations';

-- Check policies
-- SELECT * FROM pg_policies WHERE tablename = 'assigned_locations';

-- Check functions
-- SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name LIKE 'rpc_%assignment%';

-- ============================================================================
-- COMPLETE!
-- ============================================================================
-- All database objects for the location assignment feature are now created.
-- You can now test the feature in the iOS app.
-- ============================================================================

