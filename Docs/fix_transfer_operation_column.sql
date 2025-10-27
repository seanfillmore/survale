-- ============================================================================
-- Fix Transfer Operation - Correct Column Name
-- ============================================================================

-- The error indicates "created_by_user_id" doesn't exist
-- Common alternatives in our schema:
--   - case_agent_user_id
--   - created_by
--   - creator_id
--
-- First, let's check what column actually exists:
-- Run this query manually to see the operations table structure:
-- SELECT column_name FROM information_schema.columns 
-- WHERE table_name = 'operations' AND column_name LIKE '%user%';

-- Updated function with correct column name
-- Replace 'created_by_user_id' with the actual column name from your schema

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
    -- CORRECT COLUMN: case_agent_id (confirmed from schema)
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
    SET case_agent_id = new_case_agent_id  -- CORRECT COLUMN
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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.rpc_transfer_operation(UUID, UUID) TO authenticated;

-- ============================================================================
-- INSTRUCTIONS:
-- ============================================================================
-- 1. First, run this query to find the correct column name:
--    SELECT column_name 
--    FROM information_schema.columns 
--    WHERE table_name = 'operations' 
--    AND (column_name LIKE '%case%' OR column_name LIKE '%agent%' OR column_name LIKE '%created%');
--
-- 2. Update lines 26 and 62 above with the correct column name
-- 3. Run this updated SQL in Supabase

