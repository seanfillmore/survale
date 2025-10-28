-- Emergency fix for rpc_get_templates function
-- Run this if you're still getting "column reference 'id' is ambiguous" error
-- This will forcibly drop and recreate the function

-- Force drop the old function (CASCADE removes dependencies)
DROP FUNCTION IF EXISTS public.rpc_get_templates CASCADE;
DROP FUNCTION IF EXISTS public.rpc_get_templates(text) CASCADE;

-- Recreate with the fixed implementation using subqueries
CREATE FUNCTION public.rpc_get_templates(
    p_scope text DEFAULT 'mine'
)
RETURNS TABLE (
    id uuid,
    name text,
    description text,
    created_by_user_id uuid,
    is_public boolean,
    created_at timestamptz,
    updated_at timestamptz,
    target_count bigint,
    staging_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
    v_agency_id uuid;
BEGIN
    -- Get the authenticated user's ID
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Get user's agency
    SELECT agency_id INTO v_agency_id
    FROM public.users
    WHERE id = v_user_id;

    -- Return templates based on scope
    IF p_scope = 'mine' THEN
        -- Return only user's own templates
        RETURN QUERY
        SELECT
            t.id,
            t.name,
            t.description,
            t.created_by_user_id,
            t.is_public,
            t.created_at,
            t.updated_at,
            (SELECT COUNT(*) FROM public.template_targets WHERE template_id = t.id)::bigint as target_count,
            (SELECT COUNT(*) FROM public.template_staging_points WHERE template_id = t.id)::bigint as staging_count
        FROM public.operation_templates t
        WHERE t.created_by_user_id = v_user_id
        ORDER BY t.updated_at DESC NULLS LAST, t.created_at DESC;
    ELSE
        -- Return agency-wide public templates (excluding user's own)
        RETURN QUERY
        SELECT
            t.id,
            t.name,
            t.description,
            t.created_by_user_id,
            t.is_public,
            t.created_at,
            t.updated_at,
            (SELECT COUNT(*) FROM public.template_targets WHERE template_id = t.id)::bigint as target_count,
            (SELECT COUNT(*) FROM public.template_staging_points WHERE template_id = t.id)::bigint as staging_count
        FROM public.operation_templates t
        WHERE t.is_public = true
          AND t.agency_id = v_agency_id
          AND t.created_by_user_id != v_user_id
        ORDER BY t.updated_at DESC NULLS LAST, t.created_at DESC;
    END IF;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.rpc_get_templates(text) TO authenticated;

-- Verify the function was created
SELECT 'Function rpc_get_templates created successfully!' as status;

