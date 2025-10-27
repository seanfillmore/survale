-- Create function to get draft operations for the current user
-- Run this in your Supabase SQL Editor

CREATE OR REPLACE FUNCTION public.rpc_get_draft_operations()
RETURNS TABLE (
    id uuid,
    name text,
    incident_number text,
    created_at timestamptz,
    updated_at timestamptz,
    case_agent_id uuid,
    team_id uuid,
    agency_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
BEGIN
    -- Get the authenticated user's ID
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Return draft operations created by this user
    RETURN QUERY
    SELECT
        o.id,
        o.name,
        o.incident_number,
        o.created_at,
        o.updated_at,
        o.created_by_user_id AS case_agent_id,
        o.team_id,
        o.agency_id
    FROM public.operations o
    WHERE o.is_draft = true
      AND o.created_by_user_id = v_user_id
    ORDER BY o.updated_at DESC NULLS LAST, o.created_at DESC;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.rpc_get_draft_operations() TO authenticated;

