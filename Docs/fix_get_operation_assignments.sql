-- ============================================================================
-- FIX: rpc_get_operation_assignments - Remove GROUP BY Issue
-- ============================================================================
-- The function was incorrectly using json_agg without proper grouping.
-- This fix simplifies the query to return assignments correctly.
-- ============================================================================

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
    
    -- Return assignments with user details
    RETURN (
        SELECT COALESCE(json_agg(row_to_json ORDER BY assigned_at DESC), '[]'::json)
        FROM (
            SELECT
                al.id,
                al.operation_id,
                al.assigned_by_user_id,
                al.assigned_to_user_id,
                al.lat,
                al.lon,
                al.label,
                al.notes,
                al.status,
                al.assigned_at,
                al.acknowledged_at,
                al.updated_at,
                al.arrived_at,
                al.completed_at,
                u_to.full_name AS assigned_to_user_name,
                u_to.callsign AS assigned_to_callsign,
                u_by.full_name AS assigned_by_user_name,
                u_by.callsign AS assigned_by_callsign
            FROM public.assigned_locations al
            LEFT JOIN public.users u_to ON u_to.id = al.assigned_to_user_id
            LEFT JOIN public.users u_by ON u_by.id = al.assigned_by_user_id
            WHERE al.operation_id = rpc_get_operation_assignments.operation_id
                AND al.status NOT IN ('cancelled', 'completed')
            ORDER BY al.assigned_at DESC
        ) AS row_to_json
    );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.rpc_get_operation_assignments(UUID) TO authenticated;

-- Test the function (optional - replace with your actual operation ID)
-- SELECT public.rpc_get_operation_assignments('YOUR-OPERATION-ID-HERE'::uuid);

