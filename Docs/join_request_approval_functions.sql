-- Functions to approve/reject join requests

-- Approve join request and add user to operation
CREATE OR REPLACE FUNCTION public.rpc_approve_join_request(
    request_id UUID,
    operation_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    requester_id UUID;
BEGIN
    -- Check if current user is case agent of the operation
    IF NOT EXISTS (
        SELECT 1 FROM operations o
        WHERE o.id = rpc_approve_join_request.operation_id
        AND o.case_agent_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Only case agent can approve join requests';
    END IF;
    
    -- Get requester user ID
    SELECT jr.requester_user_id INTO requester_id
    FROM join_requests jr
    WHERE jr.id = rpc_approve_join_request.request_id
    AND jr.operation_id = rpc_approve_join_request.operation_id
    AND jr.status = 'pending';
    
    IF requester_id IS NULL THEN
        RAISE EXCEPTION 'Join request not found or already processed';
    END IF;
    
    -- Check if requester is already in another active operation
    IF EXISTS (
        SELECT 1 
        FROM operation_members om
        JOIN operations op ON om.operation_id = op.id
        WHERE om.user_id = requester_id
        AND om.left_at IS NULL
        AND op.status = 'active'
        AND op.id != rpc_approve_join_request.operation_id  -- Exclude current operation
    ) THEN
        RAISE EXCEPTION 'User is already in another active operation';
    END IF;
    
    -- Add user to operation (store operation_id in a variable to avoid ambiguity)
    INSERT INTO operation_members (operation_id, user_id, role)
    VALUES (rpc_approve_join_request.operation_id, requester_id, 'member');
    
    -- Update join request status
    UPDATE join_requests jr
    SET status = 'approved',
        responded_at = now(),
        responded_by = auth.uid()
    WHERE jr.id = rpc_approve_join_request.request_id;
    
    RETURN json_build_object('success', true);
END;
$$;

-- Reject join request
CREATE OR REPLACE FUNCTION public.rpc_reject_join_request(
    request_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if current user is case agent (verified through RLS)
    UPDATE join_requests
    SET status = 'rejected',
        responded_at = now(),
        responded_by = auth.uid()
    WHERE id = rpc_reject_join_request.request_id
    AND status = 'pending';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Join request not found or already processed';
    END IF;
    
    RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_approve_join_request TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_reject_join_request TO authenticated;

