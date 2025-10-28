-- NUCLEAR FIX: Completely recreate rpc_create_operation with proper enum casting
-- Run this in your Supabase SQL Editor

-- Step 1: Show all current versions
DO $$
BEGIN
    RAISE NOTICE '=== Current versions of rpc_create_operation ===';
END $$;

SELECT 
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments,
    p.oid
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'rpc_create_operation'
  AND n.nspname = 'public';

-- Step 2: Drop ALL versions using dynamic SQL
DO $$
DECLARE
    func_signature text;
BEGIN
    RAISE NOTICE '=== Dropping all versions ===';
    
    FOR func_signature IN 
        SELECT 'public.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')'
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE p.proname = 'rpc_create_operation'
          AND n.nspname = 'public'
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || func_signature || ' CASCADE';
        RAISE NOTICE '   Dropped: %', func_signature;
    END LOOP;
    
    RAISE NOTICE '✅ All versions dropped';
END $$;

-- Step 3: Verify they're gone
DO $$
DECLARE
    func_count integer;
BEGIN
    SELECT COUNT(*) INTO func_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'rpc_create_operation'
      AND n.nspname = 'public';
    
    IF func_count > 0 THEN
        RAISE EXCEPTION '❌ Still have % functions remaining!', func_count;
    ELSE
        RAISE NOTICE '✅ Verified: All functions removed';
    END IF;
END $$;

-- Step 4: Create the NEW version with proper enum casting
CREATE FUNCTION public.rpc_create_operation(
    p_name text,
    p_incident_number text DEFAULT NULL,
    p_is_draft boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_user_id uuid;
    v_team_id uuid;
    v_agency_id uuid;
    v_operation_id uuid;
BEGIN
    -- Get the authenticated user's ID
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Get user's team and agency
    SELECT team_id, agency_id INTO v_team_id, v_agency_id
    FROM public.users
    WHERE id = v_user_id;

    IF v_team_id IS NULL OR v_agency_id IS NULL THEN
        RAISE EXCEPTION 'User must belong to a team and agency';
    END IF;

    -- Generate new operation ID
    v_operation_id := gen_random_uuid();

    -- Insert the operation with proper enum casting
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
        -- CRITICAL: Cast to op_status enum
        CASE 
            WHEN p_is_draft THEN 'draft'::op_status 
            ELSE 'active'::op_status 
        END,
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

    -- Return the new operation ID
    RETURN jsonb_build_object('operation_id', v_operation_id);
END;
$function$;

-- Step 5: Grant permissions
GRANT EXECUTE ON FUNCTION public.rpc_create_operation(text, text, boolean) TO authenticated;

-- Step 6: Force PostgREST to reload schema
NOTIFY pgrst, 'reload schema';

-- Step 7: Verify the new function
DO $$
DECLARE
    func_count integer;
BEGIN
    SELECT COUNT(*) INTO func_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'rpc_create_operation'
      AND n.nspname = 'public';
    
    IF func_count = 1 THEN
        RAISE NOTICE '✅ SUCCESS: New function created';
    ELSE
        RAISE EXCEPTION '❌ Expected 1 function, found %', func_count;
    END IF;
END $$;

-- Show the final version
SELECT 
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'rpc_create_operation'
  AND n.nspname = 'public';

-- Final message
DO $$
BEGIN
    RAISE NOTICE '✅✅✅ ALL DONE! ✅✅✅';
    RAISE NOTICE 'Function rpc_create_operation has been recreated with proper enum casting';
    RAISE NOTICE 'PostgREST schema cache has been refreshed';
    RAISE NOTICE 'Now restart your app and try creating an operation!';
END $$;

