-- Fix duplicate rpc_save_operation_as_template functions
-- Run this in your Supabase SQL Editor

-- Drop ALL versions of the function
DROP FUNCTION IF EXISTS public.rpc_save_operation_as_template(text, text, uuid, boolean, jsonb, jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.rpc_save_operation_as_template(text, text, boolean, jsonb, jsonb) CASCADE;

-- Recreate the CORRECT version with address support
CREATE OR REPLACE FUNCTION public.rpc_save_operation_as_template(
    p_name text,
    p_description text DEFAULT NULL,
    p_is_public boolean DEFAULT false,
    p_targets jsonb DEFAULT '[]'::jsonb,
    p_staging jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
    v_team_id uuid;
    v_agency_id uuid;
    v_template_id uuid;
    v_target jsonb;
    v_staging_point jsonb;
BEGIN
    -- Get authenticated user
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

    -- Create template
    INSERT INTO public.operation_templates (
        name,
        description,
        created_by_user_id,
        team_id,
        agency_id,
        is_public,
        created_at,
        updated_at
    ) VALUES (
        p_name,
        p_description,
        v_user_id,
        v_team_id,
        v_agency_id,
        p_is_public,
        now(),
        now()
    ) RETURNING id INTO v_template_id;

    -- Insert targets
    FOR v_target IN SELECT * FROM jsonb_array_elements(p_targets)
    LOOP
        INSERT INTO public.template_targets (
            template_id,
            kind,
            person_first_name,
            person_last_name,
            phone,
            vehicle_make,
            vehicle_model,
            vehicle_color,
            license_plate,
            location_name,
            location_address,
            location_lat,
            location_lng
        ) VALUES (
            v_template_id,
            v_target->>'kind',
            v_target->>'person_first_name',
            v_target->>'person_last_name',
            v_target->>'phone',
            v_target->>'vehicle_make',
            v_target->>'vehicle_model',
            v_target->>'vehicle_color',
            v_target->>'license_plate',
            v_target->>'location_name',
            v_target->>'location_address',
            (v_target->>'location_lat')::double precision,
            (v_target->>'location_lng')::double precision
        );
    END LOOP;

    -- Insert staging points (WITH address support)
    FOR v_staging_point IN SELECT * FROM jsonb_array_elements(p_staging)
    LOOP
        INSERT INTO public.template_staging_points (
            template_id,
            label,
            address,
            latitude,
            longitude
        ) VALUES (
            v_template_id,
            v_staging_point->>'label',
            v_staging_point->>'address',
            (v_staging_point->>'latitude')::double precision,
            (v_staging_point->>'longitude')::double precision
        );
    END LOOP;

    RETURN jsonb_build_object('template_id', v_template_id);
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.rpc_save_operation_as_template(text, text, boolean, jsonb, jsonb) TO authenticated;

-- Verify there's only one version
SELECT 
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'rpc_save_operation_as_template'
  AND n.nspname = 'public';

-- Should return only 1 row with: rpc_save_operation_as_template(p_name text, p_description text, p_is_public boolean, p_targets jsonb, p_staging jsonb)

