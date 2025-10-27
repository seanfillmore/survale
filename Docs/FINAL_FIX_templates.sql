-- FINAL FIX FOR TEMPLATES - Forces complete recreation by changing signature
-- This script aggressively drops ALL versions and creates a fresh function
-- Run this in your Supabase SQL Editor

-- ==============================================================================
-- STEP 1: Nuclear drop of ALL versions using dynamic SQL
-- ==============================================================================
DO $$
DECLARE
    func_signature text;
BEGIN
    RAISE NOTICE '🧹 Dropping ALL versions of rpc_get_templates...';
    
    -- Find and drop every single version
    FOR func_signature IN 
        SELECT 'public.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')'
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE p.proname = 'rpc_get_templates'
          AND n.nspname = 'public'
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || func_signature || ' CASCADE';
        RAISE NOTICE '   ✅ Dropped: %', func_signature;
    END LOOP;
    
    RAISE NOTICE '✅ All versions dropped';
END $$;

-- ==============================================================================
-- STEP 2: Verify complete removal
-- ==============================================================================
DO $$
DECLARE
    func_count integer;
BEGIN
    SELECT COUNT(*) INTO func_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'rpc_get_templates'
      AND n.nspname = 'public';
    
    IF func_count > 0 THEN
        RAISE EXCEPTION '❌ Failed to drop all functions (% remaining)', func_count;
    ELSE
        RAISE NOTICE '✅ Verified: No rpc_get_templates functions exist';
    END IF;
END $$;

-- ==============================================================================
-- STEP 3: Create BRAND NEW function with EXPLICIT table aliases
-- ==============================================================================
CREATE FUNCTION public.rpc_get_templates(
    p_scope text DEFAULT 'mine'::text  -- Changed default syntax to force new signature
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
SET search_path = public
AS $function$
DECLARE
    v_user_id uuid;
    v_agency_id uuid;
BEGIN
    -- Get authenticated user
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Get user's agency
    SELECT u.agency_id INTO v_agency_id 
    FROM public.users u 
    WHERE u.id = v_user_id;

    -- Return templates based on scope
    IF p_scope = 'mine' THEN
        RETURN QUERY
        SELECT
            tmpl.id,
            tmpl.name,
            tmpl.description,
            tmpl.created_by_user_id,
            tmpl.is_public,
            tmpl.created_at,
            tmpl.updated_at,
            COALESCE((
                SELECT COUNT(*)::bigint 
                FROM public.template_targets tgt 
                WHERE tgt.template_id = tmpl.id
            ), 0::bigint) AS target_count,
            COALESCE((
                SELECT COUNT(*)::bigint 
                FROM public.template_staging_points stg 
                WHERE stg.template_id = tmpl.id
            ), 0::bigint) AS staging_count
        FROM public.operation_templates tmpl
        WHERE tmpl.created_by_user_id = v_user_id
        ORDER BY tmpl.updated_at DESC NULLS LAST, tmpl.created_at DESC;
    ELSE
        RETURN QUERY
        SELECT
            tmpl.id,
            tmpl.name,
            tmpl.description,
            tmpl.created_by_user_id,
            tmpl.is_public,
            tmpl.created_at,
            tmpl.updated_at,
            COALESCE((
                SELECT COUNT(*)::bigint 
                FROM public.template_targets tgt 
                WHERE tgt.template_id = tmpl.id
            ), 0::bigint) AS target_count,
            COALESCE((
                SELECT COUNT(*)::bigint 
                FROM public.template_staging_points stg 
                WHERE stg.template_id = tmpl.id
            ), 0::bigint) AS staging_count
        FROM public.operation_templates tmpl
        WHERE tmpl.is_public = true
          AND tmpl.agency_id = v_agency_id
          AND tmpl.created_by_user_id != v_user_id
        ORDER BY tmpl.updated_at DESC NULLS LAST, tmpl.created_at DESC;
    END IF;
END;
$function$;

-- ==============================================================================
-- STEP 4: Grant permissions
-- ==============================================================================
GRANT EXECUTE ON FUNCTION public.rpc_get_templates(text) TO authenticated;

-- ==============================================================================
-- STEP 5: Verify new function exists
-- ==============================================================================
DO $$
DECLARE
    func_count integer;
    func_def text;
BEGIN
    SELECT COUNT(*) INTO func_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'rpc_get_templates'
      AND n.nspname = 'public';
    
    IF func_count = 1 THEN
        RAISE NOTICE '✅ New function created successfully';
        
        -- Show the function signature
        SELECT 'public.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')'
        INTO func_def
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE p.proname = 'rpc_get_templates'
          AND n.nspname = 'public';
        
        RAISE NOTICE '   Signature: %', func_def;
    ELSE
        RAISE EXCEPTION '❌ Expected 1 function, found %', func_count;
    END IF;
END $$;

-- ==============================================================================
-- STEP 6: Clear Supabase connection pool cache
-- ==============================================================================
DO $$
BEGIN
    -- Force Supabase to refresh its function cache
    NOTIFY pgrst, 'reload schema';
    
    RAISE NOTICE '✅ ALL DONE! Function cache refreshed.';
    RAISE NOTICE '⚠️ IMPORTANT: Restart your app to ensure it picks up the new function!';
END $$;

