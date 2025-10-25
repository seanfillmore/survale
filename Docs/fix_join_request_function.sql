-- Fix ambiguous column reference in rpc_request_join_operation

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
        SELECT 1 FROM operation_members om
        WHERE om.operation_id = rpc_request_join_operation.operation_id
        AND om.user_id = auth.uid()
        AND om.left_at IS NULL
    ) THEN
        RAISE EXCEPTION 'Already a member of this operation';
    END IF;
    
    -- Check if user has pending request
    IF EXISTS (
        SELECT 1 FROM join_requests jr
        WHERE jr.operation_id = rpc_request_join_operation.operation_id
        AND jr.requester_user_id = auth.uid()
        AND jr.status = 'pending'
    ) THEN
        RAISE EXCEPTION 'Join request already pending';
    END IF;
    
    -- Create join request
    INSERT INTO join_requests (operation_id, requester_user_id, status)
    VALUES (rpc_request_join_operation.operation_id, auth.uid(), 'pending')
    RETURNING id INTO request_id;
    
    RETURN json_build_object('request_id', request_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_request_join_operation TO authenticated;

