-- ============================================
-- FIX: Ambiguous column reference in rpc_publish_location
-- ============================================
-- Error: column reference "operation_id" is ambiguous
-- Fix: Explicitly qualify column references
-- ============================================

CREATE OR REPLACE FUNCTION public.rpc_publish_location(
    operation_id UUID,
    lat DOUBLE PRECISION,
    lon DOUBLE PRECISION,
    accuracy_m DOUBLE PRECISION,
    speed_mps DOUBLE PRECISION DEFAULT NULL,
    heading_deg DOUBLE PRECISION DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check user is member of operation
    -- FIX: Explicitly qualify operation_id references
    IF NOT EXISTS (
        SELECT 1 FROM operation_members om
        WHERE om.operation_id = rpc_publish_location.operation_id
        AND om.user_id = auth.uid()
        AND om.left_at IS NULL
    ) THEN
        RAISE EXCEPTION 'User not a member of this operation';
    END IF;
    
    -- Insert location
    -- FIX: Use function parameter explicitly
    INSERT INTO locations_stream (
        operation_id,
        user_id,
        ts,
        lat,
        lon,
        accuracy_m,
        speed_mps,
        heading_deg
    ) VALUES (
        rpc_publish_location.operation_id,  -- Explicitly use function parameter
        auth.uid(),
        NOW(),
        rpc_publish_location.lat,
        rpc_publish_location.lon,
        rpc_publish_location.accuracy_m,
        rpc_publish_location.speed_mps,
        rpc_publish_location.heading_deg
    );
    
    RETURN json_build_object('success', true);
END;
$$;

-- ============================================
-- VERIFY THE FIX
-- ============================================

-- Test the function (replace with actual operation_id you're testing)
-- SELECT rpc_publish_location(
--     'your-operation-id-here'::uuid,
--     34.0522,
--     -118.2437,
--     10.0,
--     5.5,
--     180.0
-- );

-- ============================================
-- EXPLANATION
-- ============================================

-- The issue was that "operation_id" appeared in two contexts:
-- 1. As a function parameter: rpc_publish_location(operation_id UUID, ...)
-- 2. As a column in operation_members table: WHERE operation_id = ...
--
-- PostgreSQL couldn't determine which one to use, hence "ambiguous"
--
-- Solution: Explicitly qualify references:
-- - Table column: om.operation_id (using table alias)
-- - Function parameter: rpc_publish_location.operation_id
--
-- Also added:
-- - Table alias 'om' for operation_members
-- - Check for left_at IS NULL (only active members)
-- - Explicit function parameter references in INSERT VALUES

