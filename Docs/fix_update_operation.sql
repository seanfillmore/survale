-- Fix ambiguous column reference in rpc_update_operation
-- The issue is that both 'operations' and 'operation_members' tables have 'operation_id'
-- We need to explicitly qualify which table we're referring to

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
    -- FIX: Explicitly qualify operation_id with table name
    IF NOT EXISTS (
        SELECT 1 FROM operation_members om
        WHERE om.operation_id = rpc_update_operation.operation_id
        AND om.user_id = auth.uid()
        AND om.left_at IS NULL
    ) THEN
        RAISE EXCEPTION 'User not a member of this operation';
    END IF;
    
    -- Update operation details
    -- FIX: Use function parameter explicitly
    UPDATE operations o
    SET 
        name = rpc_update_operation.name,
        incident_number = rpc_update_operation.incident_number
    WHERE o.id = rpc_update_operation.operation_id;
    
    RETURN json_build_object('success', true);
END;
$$;

SELECT 'rpc_update_operation fixed!' as status;

