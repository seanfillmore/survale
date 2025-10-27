-- ============================================================================
-- Transfer Operation and Leave Operation RPC Functions
-- ============================================================================

-- Function: Transfer operation to a new case agent
CREATE OR REPLACE FUNCTION public.rpc_transfer_operation(
    operation_id UUID,
    new_case_agent_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_case_agent_id UUID;
BEGIN
    -- Get current case agent
    SELECT case_agent_id INTO v_current_case_agent_id
    FROM public.operations
    WHERE id = operation_id
    AND status = 'active';
    
    IF v_current_case_agent_id IS NULL THEN
        RAISE EXCEPTION 'Operation not found or not active';
    END IF;
    
    -- Verify caller is the current case agent
    IF v_current_case_agent_id != auth.uid() THEN
        RAISE EXCEPTION 'Only the case agent can transfer the operation';
    END IF;
    
    -- Verify new case agent is a member of the operation
    IF NOT EXISTS (
        SELECT 1 FROM public.operation_members
        WHERE operation_members.operation_id = rpc_transfer_operation.operation_id
        AND user_id = new_case_agent_id
        AND left_at IS NULL
    ) THEN
        RAISE EXCEPTION 'New case agent must be a member of the operation';
    END IF;
    
    -- Update operation to new case agent
    UPDATE public.operations
    SET case_agent_id = new_case_agent_id
    WHERE id = operation_id;
    
    -- Send notification message to all members
    INSERT INTO public.op_messages (operation_id, sender_user_id, body_text, media_type)
    SELECT 
        operation_id,
        auth.uid(),
        (SELECT COALESCE(callsign, email, id::text) FROM public.users WHERE id = auth.uid()) || ' has transferred the operation to ' || (SELECT COALESCE(callsign, email, id::text) FROM public.users WHERE id = new_case_agent_id),
        'text';
    
    RAISE NOTICE 'Operation transferred successfully';
END;
$$;

-- Function: Leave an operation
CREATE OR REPLACE FUNCTION public.rpc_leave_operation(
    operation_id UUID,
    user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_callsign TEXT;
    v_user_email TEXT;
    v_user_display TEXT;
BEGIN
    -- Verify caller is the user leaving
    IF user_id != auth.uid() THEN
        RAISE EXCEPTION 'You can only leave for yourself';
    END IF;
    
    -- Verify user is a member of the operation
    IF NOT EXISTS (
        SELECT 1 FROM public.operation_members
        WHERE operation_members.operation_id = rpc_leave_operation.operation_id
        AND operation_members.user_id = rpc_leave_operation.user_id
        AND left_at IS NULL
    ) THEN
        RAISE EXCEPTION 'User is not a member of this operation';
    END IF;
    
    -- Get user display name
    SELECT callsign, email INTO v_user_callsign, v_user_email
    FROM public.users
    WHERE id = user_id;
    
    v_user_display := COALESCE(v_user_callsign, v_user_email, user_id::text);
    
    -- Mark user as left
    UPDATE public.operation_members
    SET left_at = NOW()
    WHERE operation_members.operation_id = rpc_leave_operation.operation_id
    AND operation_members.user_id = rpc_leave_operation.user_id;
    
    -- Send notification message to all remaining members
    INSERT INTO public.op_messages (operation_id, sender_user_id, body_text, media_type)
    VALUES (
        operation_id,
        user_id,
        v_user_display || ' has left the operation',
        'text'
    );
    
    RAISE NOTICE 'User left operation successfully';
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.rpc_transfer_operation(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_leave_operation(UUID, UUID) TO authenticated;

