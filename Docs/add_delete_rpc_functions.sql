-- Add RPC functions for deleting targets and staging points
-- This allows editing operations by removing items

-- 1. DELETE TARGET
CREATE OR REPLACE FUNCTION public.rpc_delete_target(
    target_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check user is member of the operation
    IF NOT EXISTS (
        SELECT 1 FROM targets t
        JOIN operation_members om ON t.operation_id = om.operation_id
        WHERE t.id = rpc_delete_target.target_id
        AND om.user_id = auth.uid()
        AND om.left_at IS NULL
    ) THEN
        RAISE EXCEPTION 'User not a member of this operation';
    END IF;
    
    -- Delete the target
    DELETE FROM targets
    WHERE id = rpc_delete_target.target_id;
    
    RETURN json_build_object('success', true);
END;
$$;

-- 2. DELETE STAGING POINT
CREATE OR REPLACE FUNCTION public.rpc_delete_staging_point(
    staging_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check user is member of the operation
    IF NOT EXISTS (
        SELECT 1 FROM staging_areas sa
        JOIN operation_members om ON sa.operation_id = om.operation_id
        WHERE sa.id = rpc_delete_staging_point.staging_id
        AND om.user_id = auth.uid()
        AND om.left_at IS NULL
    ) THEN
        RAISE EXCEPTION 'User not a member of this operation';
    END IF;
    
    -- Delete the staging point
    DELETE FROM staging_areas
    WHERE id = rpc_delete_staging_point.staging_id;
    
    RETURN json_build_object('success', true);
END;
$$;

SELECT 'Delete RPC functions created!' as status;

