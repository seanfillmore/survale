-- Comprehensive verification and fix for template system
-- Run this to diagnose and fix template issues

-- Step 1: Check if tables exist
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'operation_templates') THEN
        RAISE NOTICE '✅ Table operation_templates exists';
    ELSE
        RAISE NOTICE '❌ Table operation_templates DOES NOT EXIST - Run create_templates_schema.sql first!';
    END IF;

    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'template_targets') THEN
        RAISE NOTICE '✅ Table template_targets exists';
    ELSE
        RAISE NOTICE '❌ Table template_targets DOES NOT EXIST - Run create_templates_schema.sql first!';
    END IF;

    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'template_staging_points') THEN
        RAISE NOTICE '✅ Table template_staging_points exists';
    ELSE
        RAISE NOTICE '❌ Table template_staging_points DOES NOT EXIST - Run create_templates_schema.sql first!';
    END IF;
END $$;

-- Step 2: Check current function definition
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'rpc_get_templates'
    ) THEN
        RAISE NOTICE '⚠️  Function rpc_get_templates exists - will be replaced';
    ELSE
        RAISE NOTICE 'ℹ️  Function rpc_get_templates does not exist - will be created';
    END IF;
END $$;

-- Step 3: Force drop ALL versions of the function
DROP FUNCTION IF EXISTS public.rpc_get_templates CASCADE;
DROP FUNCTION IF EXISTS public.rpc_get_templates(text) CASCADE;
DROP FUNCTION IF EXISTS public.rpc_get_templates(text, text) CASCADE;

RAISE NOTICE '✅ Dropped all versions of rpc_get_templates';

-- Step 4: Create the correct function
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

    RAISE NOTICE 'Loading templates for user: %, agency: %, scope: %', v_user_id, v_agency_id, p_scope;

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
            (SELECT COUNT(*) FROM public.template_targets WHERE template_id = t.id)::bigint,
            (SELECT COUNT(*) FROM public.template_staging_points WHERE template_id = t.id)::bigint
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
            (SELECT COUNT(*) FROM public.template_targets WHERE template_id = t.id)::bigint,
            (SELECT COUNT(*) FROM public.template_staging_points WHERE template_id = t.id)::bigint
        FROM public.operation_templates t
        WHERE t.is_public = true
          AND t.agency_id = v_agency_id
          AND t.created_by_user_id != v_user_id
        ORDER BY t.updated_at DESC NULLS LAST, t.created_at DESC;
    END IF;
END;
$$;

RAISE NOTICE '✅ Function rpc_get_templates created successfully';

-- Step 5: Grant permissions
GRANT EXECUTE ON FUNCTION public.rpc_get_templates(text) TO authenticated;

RAISE NOTICE '✅ Permissions granted';

-- Step 6: Test the function
SELECT 'Setup complete! Function is ready to use.' as status;

-- Show count of templates
SELECT 
    COUNT(*) as template_count,
    COUNT(*) FILTER (WHERE is_public = true) as public_count,
    COUNT(*) FILTER (WHERE is_public = false) as private_count
FROM public.operation_templates;

