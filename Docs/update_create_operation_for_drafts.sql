-- Update rpc_create_operation to support draft operations
-- Run this in your Supabase SQL Editor

-- Drop the existing function first
DROP FUNCTION IF EXISTS public.rpc_create_operation(text, text);

-- Recreate with is_draft parameter
CREATE OR REPLACE FUNCTION public.rpc_create_operation(
    p_name text,
    p_incident_number text DEFAULT NULL,
    p_is_draft boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_operation_id uuid;
    v_user_id uuid;
    v_team_id uuid;
    v_agency_id uuid;
BEGIN
    -- Get the authenticated user's ID
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Get user's team and agency from users table
    SELECT team_id, agency_id INTO v_team_id, v_agency_id
    FROM public.users
    WHERE id = v_user_id;

    IF v_team_id IS NULL OR v_agency_id IS NULL THEN
        RAISE EXCEPTION 'User must belong to a team and agency';
    END IF;

    -- Generate new operation ID
    v_operation_id := gen_random_uuid();

    -- Insert the operation with draft state if specified
    INSERT INTO public.operations (
        id,
        name,
        incident_number,
        status,
        case_agent_id,
        team_id,
        agency_id,
        started_at,
        is_draft,
        created_at,
        updated_at
    ) VALUES (
        v_operation_id,
        p_name,
        p_incident_number,
        CASE WHEN p_is_draft THEN 'draft' ELSE 'active' END,
        v_user_id,
        v_team_id,
        v_agency_id,
        CASE WHEN p_is_draft THEN NULL ELSE now() END,
        p_is_draft,
        now(),
        now()
    );

    -- Add the creator as a member
    INSERT INTO public.operation_members (
        operation_id,
        user_id,
        role,
        joined_at
    ) VALUES (
        v_operation_id,
        v_user_id,
        'case_agent',
        now()
    );

    -- Return the operation ID
    RETURN jsonb_build_object('operation_id', v_operation_id);
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.rpc_create_operation(text, text, boolean) TO authenticated;

