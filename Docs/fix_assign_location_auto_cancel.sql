-- ============================================================================
-- FIX: Auto-cancel existing active assignments before creating new ones
-- ============================================================================
-- This updates the rpc_assign_location function to automatically cancel
-- any existing active assignments for the user before creating a new one.
-- ============================================================================

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
    
    -- Verify assigned user is a member of the operation
    IF NOT EXISTS (
        SELECT 1 FROM public.operation_members om
        WHERE om.operation_id = rpc_assign_location.operation_id
        AND om.user_id = rpc_assign_location.assigned_to_user_id
        AND om.left_at IS NULL
    ) THEN
        RAISE EXCEPTION 'User is not a member of this operation';
    END IF;
    
    -- Get user details
    SELECT u.full_name, u.callsign
    INTO v_assigned_to_full_name, v_assigned_to_callsign
    FROM public.users u
    WHERE u.id = rpc_assign_location.assigned_to_user_id;
    
    -- Cancel any existing active assignments for this user
    -- Use a subquery to ensure the UPDATE completes before the INSERT
    PERFORM 1 FROM public.assigned_locations al
    WHERE al.assigned_to_user_id = rpc_assign_location.assigned_to_user_id
        AND al.status NOT IN ('cancelled', 'completed')
    FOR UPDATE;
    
    UPDATE public.assigned_locations al
    SET 
        status = 'cancelled',
        updated_at = NOW(),
        completed_at = NOW()
    WHERE al.assigned_to_user_id = rpc_assign_location.assigned_to_user_id
        AND al.status NOT IN ('cancelled', 'completed');
    
    -- Insert new assignment
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
        rpc_assign_location.operation_id,
        auth.uid(),
        rpc_assign_location.assigned_to_user_id,
        rpc_assign_location.lat,
        rpc_assign_location.lon,
        rpc_assign_location.label,
        rpc_assign_location.notes,
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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.rpc_assign_location(UUID, UUID, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT) TO authenticated;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Updated rpc_assign_location to auto-cancel existing active assignments';
    RAISE NOTICE '   Users can now be reassigned without manually cancelling old assignments';
END $$;

