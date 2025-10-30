-- Fix rpc_get_team_roster to construct full_name from first_name and last_name
-- This handles users created before the auth trigger was fixed

-- Drop existing function
DROP FUNCTION IF EXISTS rpc_get_team_roster();

-- Recreate function with full_name construction
CREATE OR REPLACE FUNCTION rpc_get_team_roster()
RETURNS TABLE (
    id uuid,
    full_name text,
    email text,
    callsign text,
    in_operation boolean,
    operation_id uuid
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id uuid;
    v_team_id uuid;
BEGIN
    -- Get current user's ID and team
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    
    -- Get user's team_id
    SELECT users.team_id INTO v_team_id
    FROM users
    WHERE users.id = v_user_id;
    
    IF v_team_id IS NULL THEN
        RAISE EXCEPTION 'User not assigned to a team';
    END IF;
    
    -- Return all team members with constructed full_name
    RETURN QUERY
    SELECT 
        u.id,
        -- Construct full_name from first_name and last_name if full_name is NULL
        COALESCE(
            NULLIF(TRIM(u.full_name), ''),  -- Use full_name if not empty
            TRIM(CONCAT(u.first_name, ' ', u.last_name)),  -- Construct from first + last
            u.email  -- Final fallback to email
        ) AS full_name,
        u.email,
        u.callsign,
        -- Check if user is in an active operation
        EXISTS (
            SELECT 1 
            FROM operation_members om
            JOIN operations o ON om.operation_id = o.id
            WHERE om.user_id = u.id 
            AND o.status = 'active'
        ) AS in_operation,
        -- Get their current operation ID if they're in one
        (
            SELECT om.operation_id
            FROM operation_members om
            JOIN operations o ON om.operation_id = o.id
            WHERE om.user_id = u.id 
            AND o.status = 'active'
            LIMIT 1
        ) AS operation_id
    FROM users u
    WHERE u.team_id = v_team_id
    ORDER BY u.first_name, u.last_name, u.email;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION rpc_get_team_roster() TO authenticated;

-- Test the function (optional - will show results if run in SQL editor)
-- SELECT * FROM rpc_get_team_roster();

